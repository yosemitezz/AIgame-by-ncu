extends Node2D

signal hud_updated(state: Dictionary)
signal boss_phase_changed(phase: String)
signal warning_issued(kind: String, at: Vector2, duration: float)
signal vfx_requested(kind: String, at: Vector2, direction: Vector2, power: float)
signal animation_event(actor: Node, state: String, frame: int, facing: int)
signal parry_contacted(defender: Node, source: Node, contact: Vector2, kind: String)

const Player = preload("res://actors/player.gd")
const Enemy = preload("res://actors/enemy.gd")
const Projectile = preload("res://combat/projectile.gd")
const Boss = preload("res://combat/boss.gd")
const Score = preload("res://audio/music_director.gd")
const Level = preload("res://levels/bellkeep.gd")
const HUD = preload("res://ui/hud.gd")
const Pixels = preload("res://assets/art/pixel_actor.gd")
const FxLayer = preload("res://vfx/fx_layer.gd")
const MotionBlur = preload("res://vfx/motion_blur.gd")
const Impact = preload("res://combat/impact_feedback.gd")
const CombatVFX = preload("res://presentation/combat_vfx.gd")
## Effects owned by the gradient layer (vfx/fx_layer.gd) AND mirrored to the pixel-frame layer
## (presentation/combat_vfx.gd) so its crisp sprite cores sit under the colour. Everything else
## (dash ghosts, dust, pickups, warnings) is drawn once, by one owner, to avoid doubled effects.
const PIXEL_CORE_FX: Array[String] = ["slash", "enemy_slash", "parry", "blade_parry", "projectile_parry", "guard_break", "hit", "hurt", "impact", "parry_ready"]

var player: CharacterBody2D
var boss: CharacterBody2D
var music: Node
var level: Node2D
var impact: Node
var effects: Node2D
var _attack_hits: Dictionary = {}
var parry_feedback_count: int = 0
var last_parry_kind: String = ""
var last_parry_contact: Vector2 = Vector2.ZERO
var _parry_notice_time: float = 0.0
var _parry_event_frame: int = -1
var _parry_event_sources: Dictionary = {}
var checkpoint: Vector2 = Level.SPAWN
var score: int = 0
var story_safe: bool = false
var outcome: String = ""
var checkpoint_active: bool = false
var elite_defeated: bool = false
var boss_started: bool = false
var _collected: Dictionary = {}
var _camera: Camera2D
var _hud: Control
var _elite_gate: StaticBody2D
var _arena_gate: StaticBody2D
var _particles: Array[Dictionary] = []
var _strokes: Array[Dictionary] = []
var _warnings: Array[Dictionary] = []
var _announcement: String = ""
var _announcement_time: float = 0.0
var _clock: float = 0.0
var _trauma: float = 0.0
var _hud_clock: float = 0.0
var _ending_clock: float = 0.0
var _paused: bool = false
var _reloading: bool = false
var _zone: int = 0
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    _rng.seed = 424242
    _setup_input()
    checkpoint_active = bool(get_tree().get_meta("bellkeep_checkpoint", false))
    elite_defeated = bool(get_tree().get_meta("bellkeep_elite", false))
    _collected = get_tree().get_meta("bellkeep_shards", {}).duplicate()
    score = _collected.size()
    if checkpoint_active:
        checkpoint = Vector2(2500, 280) if elite_defeated else Level.CHECKPOINT
    level = Level.new()
    level.process_mode = Node.PROCESS_MODE_PAUSABLE
    add_child(level)
    level.setup(self)
    # Presentation-only combat VFX: reads vfx_requested / warning_issued, never touches gameplay.
    var fx := FxLayer.new()
    fx.name = "FxLayer"
    fx.process_mode = Node.PROCESS_MODE_PAUSABLE
    add_child(fx)
    fx.setup(self)
    player = Player.new()
    player.process_mode = Node.PROCESS_MODE_PAUSABLE
    player.configure(self)
    player.position = checkpoint
    player.z_index = 3
    player.died.connect(_on_player_died)
    add_child(player)
    _camera = Camera2D.new()
    _camera.position = Vector2(clampf(player.position.x, 320, Level.LEVEL_END - 320), 180)
    _camera.position_smoothing_enabled = false
    add_child(_camera)
    _camera.make_current()
    music = Score.new()
    music.process_mode = Node.PROCESS_MODE_PAUSABLE
    add_child(music)
    music.configure(self)
    impact = Impact.new()
    impact.process_mode = Node.PROCESS_MODE_PAUSABLE
    add_child(impact)
    impact.configure(self)
    effects = CombatVFX.new()
    effects.process_mode = Node.PROCESS_MODE_PAUSABLE
    add_child(effects)
    effects.configure(self)
    # Screen-space impact blur (presentation only, layer 20, below the HUD).
    var blur := MotionBlur.new()
    blur.name = "MotionBlur"
    blur.process_mode = Node.PROCESS_MODE_PAUSABLE
    add_child(blur)
    blur.setup(self)
    for entry: Dictionary in Level.ENEMIES:
        if entry["kind"] == "elite" and elite_defeated:
            continue
        if checkpoint_active and entry["at"].x < Level.CHECKPOINT.x:
            continue
        spawn_enemy(entry["kind"], entry["at"])
    if not elite_defeated:
        _elite_gate = _make_gate(2580)
    var canvas := CanvasLayer.new()
    canvas.layer = 30
    add_child(canvas)
    _hud = HUD.new()
    canvas.add_child(_hud)
    _hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    hud_updated.connect(_hud.update_state)
    announce("Voice: You are awake. Trust your hands; the rest will return.", 5.0)
    _refresh_hud()

func _setup_input() -> void:
    _bind("move_left", [KEY_A, KEY_LEFT])
    _bind("move_right", [KEY_D, KEY_RIGHT])
    _bind("jump", [KEY_SPACE, KEY_W, KEY_UP])
    _bind("dash", [KEY_SHIFT, KEY_L])
    _bind("attack", [KEY_J, KEY_Z])
    _bind("parry", [KEY_K, KEY_X])
    _bind("crouch", [KEY_S, KEY_DOWN])
    var mouse := InputEventMouseButton.new()
    mouse.button_index = MOUSE_BUTTON_LEFT
    InputMap.action_add_event("attack", mouse)

func _bind(action: String, keys: Array) -> void:
    if not InputMap.has_action(action):
        InputMap.add_action(action)
    InputMap.action_erase_events(action)
    for key: int in keys:
        var event := InputEventKey.new()
        event.physical_keycode = key
        InputMap.action_add_event(action, event)

func spawn_enemy(kind: String, at: Vector2) -> Node2D:
    var enemy := Enemy.new()
    enemy.process_mode = Node.PROCESS_MODE_PAUSABLE
    enemy.configure(self, kind, at)
    enemy.z_index = 2
    add_child(enemy)
    return enemy

func _make_gate(x: float) -> StaticBody2D:
    var gate := StaticBody2D.new()
    gate.collision_layer = 1
    gate.collision_mask = 0
    gate.position = Vector2(x, 180)
    var collider := CollisionShape2D.new()
    var shape := RectangleShape2D.new()
    shape.size = Vector2(12, 240)
    collider.shape = shape
    gate.add_child(collider)
    add_child(gate)
    return gate

func _physics_process(_delta: float) -> void:
    if _paused or not is_instance_valid(player) or outcome != "":
        return
    player.position.x = clampf(player.position.x, 12, Level.LEVEL_END - 20)
    if player.position.y > 460:
        damage_player(1, player.position + Vector2(0, 50))
        if not player.dead:
            player.position = checkpoint
            player.velocity = Vector2.ZERO
            player.invuln = 1.0
            announce("Voice: A fall is not the end. The shrine remembers.", 3.0)
    if not checkpoint_active and player.position.x >= Level.CHECKPOINT.x:
        checkpoint_active = true
        checkpoint = Level.CHECKPOINT
        get_tree().set_meta("bellkeep_checkpoint", true)
        player.health = player.max_health
        player.health_changed.emit(player.health, player.max_health)
        emit_fx("checkpoint", checkpoint + Vector2(0, -20), Vector2.UP, 2.0)
        announce("EMBER SHRINE  /  Health restored. R returns here.", 4.0)
    for i: int in Level.SHARDS.size():
        if _collected.has(i):
            continue
        if (player.position - Vector2(0, 16)).distance_to(Level.SHARDS[i]) < 24:
            _collected[i] = true
            score = _collected.size()
            get_tree().set_meta("bellkeep_shards", _collected.duplicate())
            emit_fx("pickup", Level.SHARDS[i], Vector2.UP, 0.8)
    _zone = 0
    for i: int in Level.ZONES.size():
        if player.position.x >= float(Level.ZONES[i]["x"]):
            _zone = i
    if elite_defeated and not boss_started and player.position.x >= Level.BOSS_TRIGGER_X:
        _start_boss()

func _process(delta: float) -> void:
    if _paused:
        return
    _clock += delta
    _parry_notice_time = maxf(0, _parry_notice_time - delta)
    _announcement_time = maxf(0, _announcement_time - delta)
    if is_instance_valid(player):
        var wanted: float = clampf(player.position.x + float(player.facing) * 45.0, 320, Level.LEVEL_END - 320)
        _camera.position.x = roundf(lerpf(_camera.position.x, wanted, 1.0 - exp(-delta * 5.0)))
        _camera.offset = impact.sample_camera(delta) if is_instance_valid(impact) else Vector2.ZERO
        _camera.zoom = Vector2.ONE * (impact.sample_zoom(delta) if is_instance_valid(impact) else 1.0)
    if outcome == "victory":
        _ending_clock += delta
    _hud_clock += delta
    if _hud_clock > 0.05:
        _hud_clock = 0
        _refresh_hud()
    queue_redraw()

## Vertical tolerance of a strike (was 28). Matches the taller swing effects and the longer hero.
const HERO_HIT_HALF_HEIGHT: int = 40

func hero_attack(source: Node2D, damage: int, reach: float, combo_index: int) -> void:
    if story_safe or outcome != "":
        return
    var source_id: int = source.get_instance_id()
    var serial: int = int(source.attack_serial)
    if not _attack_hits.has(source_id) or int(_attack_hits[source_id]["serial"]) != serial:
        _attack_hits[source_id] = {"serial": serial, "targets": {}}
    var hits: Dictionary = _attack_hits[source_id]["targets"]
    var origin: Vector2 = source.global_position + Vector2(0, -18)
    for enemy: Node in get_tree().get_nodes_in_group("enemies"):
        if not is_instance_valid(enemy) or bool(enemy.dead) or hits.has(enemy.get_instance_id()):
            continue
        var target: Vector2 = enemy.global_position + Vector2(0, -28 if enemy == boss else -16)
        var difference: Vector2 = target - origin
        var radius: float = 19 if enemy == boss else 10
        if absf(difference.x) <= reach + radius and difference.x * float(source.facing) >= -9 and absf(difference.y) <= (HERO_HIT_HALF_HEIGHT + 14 if enemy == boss else HERO_HIT_HALF_HEIGHT):
            var before: int = int(enemy.health)
            enemy.receive_hit(damage, source.global_position)
            if int(enemy.health) < before:
                hits[enemy.get_instance_id()] = true
                if source.has_method("confirm_attack_hit"):
                    source.confirm_attack_hit()
                request_impact(source, enemy, combo_index == 3)
                if enemy != boss and enemy.has_method("react") and not bool(enemy.dead):
                    # Light cut shoves, second cut stuns, finisher (or any airborne cut) launches.
                    enemy.react("launch" if combo_index == 3 else ("stun" if combo_index == 2 else "knockback"), source.global_position)
            elif enemy == boss:
                # A sealed phase can clang once per swing without repeated contact spam.
                hits[enemy.get_instance_id()] = true

func damage_player(amount: int, origin: Vector2) -> void:
    if story_safe or outcome != "" or not is_instance_valid(player):
        return
    if player.receive_hit(amount, origin):
        request_impact(null, player)

func spawn_projectile(at: Vector2, velocity: Vector2, friendly: bool = false) -> Node2D:
    var projectile := Projectile.new()
    projectile.process_mode = Node.PROCESS_MODE_PAUSABLE
    projectile.configure(self, at, velocity, friendly)
    add_child(projectile)
    if get_tree().get_nodes_in_group("projectiles").size() > 180:
        var oldest: Node = get_tree().get_first_node_in_group("projectiles")
        if oldest != projectile:
            oldest.clear()
    return projectile

func set_story_safe(value: bool) -> void:
    story_safe = value
    if value:
        for projectile: Node in get_tree().get_nodes_in_group("projectiles"):
            projectile.clear()
        if is_instance_valid(effects):
            effects.clear_hostile()
        if is_instance_valid(impact):
            impact.clear()
        if is_instance_valid(player):
            player.combat_freeze = 0
        if is_instance_valid(boss):
            boss.combat_freeze = 0
        _parry_notice_time = 0
        last_parry_kind = ""
        _parry_event_sources.clear()
        if is_instance_valid(_camera):
            _camera.offset = Vector2.ZERO
        _warnings.clear()
        _strokes.clear()

func _start_boss() -> void:
    boss_started = true
    _arena_gate = _make_gate(2625)
    _make_gate(3365)
    boss = Boss.new()
    boss.process_mode = Node.PROCESS_MODE_PAUSABLE
    boss.z_index = 2
    add_child(boss)
    boss.configure(self, Level.BOSS_POSITION)
    boss.start_encounter()

func on_enemy_defeated(enemy: Node2D) -> void:
    if enemy.kind == "elite":
        elite_defeated = true
        checkpoint = Vector2(2500, 280)
        get_tree().set_meta("bellkeep_elite", true)
        if is_instance_valid(_elite_gate):
            _elite_gate.queue_free()
            _elite_gate = null
        player.health = player.max_health
        player.health_changed.emit(player.health, player.max_health)
        announce("The seal breaks. Health restored; the threshold is remembered.", 4.0)
    else:
        emit_fx("pickup", enemy.position + Vector2(0, -16), Vector2.UP, 0.35)

func on_boss_phase(phase: String) -> void:
    boss_phase_changed.emit(phase)
    if phase == "rest":
        set_story_safe(true)
    _refresh_hud()

func on_boss_defeated() -> void:
    if outcome != "":
        return
    outcome = "victory"
    _ending_clock = 0
    set_story_safe(true)
    music.stop_score()
    player.velocity = Vector2.ZERO
    player.set_physics_process(false)
    announce("Voice: You did well. Stay still. It is almost over.", 4.0)
    emit_fx("burst", boss.position + Vector2(0, -32), Vector2.UP, 3.0)

func _on_player_died() -> void:
    outcome = "defeat"
    set_story_safe(true)
    music.stop_score()
    _refresh_hud()

func announce(text: String, seconds: float = 3.0) -> void:
    _announcement = text
    _announcement_time = seconds

func _record_warning(kind: String, at: Vector2, duration: float) -> void:
    if not story_safe:
        _warnings.append({"kind": kind, "at": at, "life": duration, "max": duration})

func emit_fx(kind: String, at: Vector2, direction: Vector2 = Vector2.ZERO, power: float = 1.0) -> void:
    vfx_requested.emit(kind, at, direction, power)
    # Gradient visuals come from vfx/fx_layer.gd via vfx_requested above; camera shake and hit-stop
    # belong to the impact controller below.
    if is_instance_valid(effects) and kind in PIXEL_CORE_FX:
        effects.emit_effect(kind, at, direction, power)
    if is_instance_valid(impact):
        if kind == "slash":
            impact.play_action("swing")
        elif kind in ["dash_start", "enemy_dash"]:
            impact.play_action("dash")
        elif kind in ["stun", "launch", "air_jump", "hurt"]:
            impact.play_action(kind)

func on_parry_contact(defender: Node, source: Node, contact: Vector2, kind: String) -> void:
    if story_safe or _paused or get_tree().paused or outcome != "" or not is_instance_valid(defender) or not is_instance_valid(source):
        return
    var physics_frame: int = Engine.get_physics_frames()
    if physics_frame != _parry_event_frame:
        _parry_event_frame = physics_frame
        _parry_event_sources.clear()
    var key: String = "%d:%d" % [defender.get_instance_id(), source.get_instance_id()]
    if _parry_event_sources.has(key):
        return
    _parry_event_sources[key] = true
    parry_feedback_count += 1
    last_parry_kind = kind
    last_parry_contact = contact
    _parry_notice_time = 0.7 if kind == "guard_break" else 0.4
    var direction := Vector2(float(defender.facing), 0)
    var effect_kind: String = "guard_break" if kind == "guard_break" else ("projectile_parry" if kind == "projectile" else "blade_parry")
    emit_fx(effect_kind, contact, direction, 1.5 if kind == "guard_break" else 1.0)
    if is_instance_valid(impact):
        impact.request(defender, source, kind == "guard_break", true, "break" if kind == "guard_break" else ("reflect" if kind == "projectile" else ""))
    parry_contacted.emit(defender, source, contact, kind)

func request_impact(source: Node, target: Node, heavy: bool = false, parry: bool = false) -> void:
    if is_instance_valid(impact):
        impact.request(source, target, heavy, parry)

func _refresh_hud() -> void:
    if not is_instance_valid(player):
        return
    var zone: Dictionary = Level.ZONES[_zone]
    hud_updated.emit({"hp": player.health, "max_hp": player.max_health, "shards": score, "total_shards": Level.SHARDS.size(), "zone": zone["title"], "hint": zone["hint"], "boss_hp": boss.health if is_instance_valid(boss) else -1, "boss_max": boss.max_health if is_instance_valid(boss) else 0, "phase": boss.phase if is_instance_valid(boss) else "", "beat": music.total_beats if is_instance_valid(music) else 0, "section": music.current_section if is_instance_valid(music) else "", "outcome": outcome, "narration": _announcement if _announcement_time > 0 else "", "safe": story_safe, "paused": _paused, "ending": _ending_clock, "progress": player.position.x / Level.LEVEL_END, "boss_guard": boss.guard_posture if is_instance_valid(boss) else 0, "boss_guard_max": boss.guard_max if is_instance_valid(boss) else 3, "reaction": boss.reaction_state if is_instance_valid(boss) else "", "parry_notice": last_parry_kind if _parry_notice_time > 0 else ""})

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo:
        if event.physical_keycode == KEY_ESCAPE:
            _paused = not _paused
            get_tree().paused = _paused
            _refresh_hud()
        elif event.physical_keycode == KEY_R:
            _reload(false)
        elif event.physical_keycode == KEY_F5:
            _reload(true)
        elif event.physical_keycode == KEY_F2:
            impact.reduced_motion = not impact.reduced_motion
            announce("Camera impact OFF" if impact.reduced_motion else "Camera impact ON", 2.0)
        elif event.physical_keycode == KEY_M:
            AudioServer.set_bus_mute(0, not AudioServer.is_bus_mute(0))

func _reload(full: bool) -> void:
    if _reloading:
        return
    _reloading = true
    get_tree().paused = false
    if full:
        for key: String in ["bellkeep_checkpoint", "bellkeep_elite", "bellkeep_shards"]:
            if get_tree().has_meta(key):
                get_tree().remove_meta(key)
    get_tree().call_deferred("reload_current_scene")

func _draw() -> void:
    for i: int in Level.SHARDS.size():
        if _collected.has(i):
            continue
        var at: Vector2 = Level.SHARDS[i] + Vector2(0, roundf(sin(_clock * 3 + i) * 2))
        draw_colored_polygon(PackedVector2Array([at + Vector2(0, -5), at + Vector2(4, 0), at + Vector2(0, 5), at + Vector2(-4, 0)]), Color("72ece2"))
        draw_rect(Rect2(at - Vector2.ONE, Vector2(2, 2)), Color("f2f6d6"))
    for gate: StaticBody2D in [_elite_gate, _arena_gate]:
        if is_instance_valid(gate):
            var at: Vector2 = gate.position
            for y: int in range(-115, 120, 12):
                draw_rect(Rect2(at + Vector2(-3, y), Vector2(6, 7)), Color("e9bb68"))
    if outcome == "victory" and _ending_clock > 1.8:
        # An unidentified shadow and an interrupted memory; no identity is asserted.
        var at: Vector2 = player.position + Vector2(-player.facing * 28, 0)
        draw_rect(Rect2(at + Vector2(-6, -29), Vector2(13, 29)), Color("0b0c18"))
        draw_rect(Rect2(at + Vector2(-4, -39), Vector2(9, 11)), Color("0b0c18"))
        if _ending_clock < 2.12:
            draw_line(at + Vector2(4, -19), player.position + Vector2(12, -18), Color("ef7678"), 2)

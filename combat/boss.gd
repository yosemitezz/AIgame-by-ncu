extends CharacterBody2D
## Bellkeeper: readable beat-led windups, pursuit, repositioning and projectile patterns.

const FriendDirector = preload("res://combat/friend_rhythm/battle_director.gd")
const FriendSlots = preload("res://combat/friend_rhythm/boss_move_slots.gd")
const FriendPlanner = preload("res://combat/friend_rhythm/boss_attack_planner.gd")
const FriendLasers = preload("res://combat/friend_rhythm/laser_formation_planner.gd")
const FriendPatterns = preload("res://combat/friend_rhythm/projectile_patterns.gd")
const BossHazard = preload("res://combat/boss_hazard.gd")
const PLAN_ARENA: Rect2 = Rect2(2660.0, 40.0, 670.0, 290.0)
const LASER_ARENA: Rect2 = Rect2(2660.0, 40.0, 670.0, 260.0)
const Pixels = preload("res://assets/art/pixel_actor.gd")
const ARENA_LEFT: float = 2660.0
const ARENA_RIGHT: float = 3330.0
# Original tuning starting points, not measurements taken from reference footage.
const NORMAL_RECOIL_TIME: float = 0.12
const NORMAL_RECOVER_TIME: float = 0.12
const ARMORED_RECOIL_TIME: float = 0.12
const ARMORED_CHAIN_GAP: float = 0.42
const GUARD_BREAK_TIME: float = 0.90
const GUARD_RECOVER_TIME: float = 0.18
const POSTURE_RESET_LOCK: float = 0.45

var friend_director: RefCounted = FriendDirector.new()
var friend_slots: Node
var _full_seen_generation: int = -1
var authored_skipped_actions: int = 0
var hazard_generation: int = 0
var _cube_rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _cube_launch_count: int = 0
var authored_trace: Array[Dictionary] = []
var authored_last_pattern: String = ""
var authored_pattern_count: int = 0
var authored_action_count: int = 0
var _authored_document: Dictionary = {}
var _authored_ready: bool = false
var _section_origin_beat: int = 0
var _section_origin_score: float = 0.0
var _loop_origin_score: float = 0.0
var _authored_cycle: int = 0
var _authored_loop_beats: int = 16
var _authored_actions: Array[Dictionary] = []
var _authored_dash: Dictionary = {}
var _prepared_plans: Dictionary = {}
var _source_strikes: Dictionary = {}
var _warning_geometry: Dictionary = {}
var _authored_pose: String = ""
var _authored_pose_elapsed: float = 0.0
var _authored_pose_duration: float = 0.0
var _release_elapsed: float = -1.0
var _present_strike: int = 0
var _death_elapsed: float = 0.0
var _warning_elapsed: float = 0.0
var _warning_duration: float = 0.0
var _windup_duration: float = 0.0
var _locked_target: Vector2 = Vector2.ZERO
var game: Node
var max_health: int = 48
var health: int = 48
var phase: String = "fixed"
var dead: bool = false
var facing: int = -1
var animation_state: String = "idle"
var frame: int = 0
var combat_freeze: float = 0.0
var attack_serial: int = 0
var contact_token: int = 0
var attack_parryable: bool = true
var attack_armored: bool = false
var guard_posture: int = 0
var guard_max: int = 3
var reaction_state: String = "none"
var reaction_progress: float = 0.0
# Rendering reads this before the hit-cooldown fallback. Counter-hit flashes must
# not obscure the open guard or weapon rebound poses.
var impact_flash: float:
    get:
        return hurt_flash if reaction_state == "none" else 0.0
var hurt_flash: float = 0.0
var _last_pattern: String = ""
var _active: bool = false
var _animation_clock: float = 0.0
var _hurt_timer: float = 0.0
var _stagger_timer: float = 0.0
var _windup_timer: float = 0.0
var _recovery_timer: float = 0.0
var _charge_timer: float = 0.0
var _pending_attack: String = ""
var _attack_count: int = 0
var _contact_resolved: bool = false
var _phase_requested: bool = false
var _seal_announced: bool = false
var _aim: Vector2 = Vector2.LEFT
var _last_state: String = ""
var _last_frame: int = -1
var _last_facing: int = 0
var _reaction_elapsed: float = 0.0
var _reaction_duration: float = 0.0
var _reaction_blocks_attacks: bool = false
var _posture_lockout: float = 0.0
var _combo_pending: bool = false
var _combo_timer: float = 0.0
var _resolved_contacts: Dictionary = {}

func configure(p_game: Node, at: Vector2) -> void:
    game = p_game
    global_position = at
    collision_layer = 0
    collision_mask = 1
    floor_snap_length = 5.0
    var shape := RectangleShape2D.new()
    shape.size = Vector2(26, 46)
    var collider := CollisionShape2D.new()
    collider.position = Vector2(0, -23)
    collider.shape = shape
    add_child(collider)
    add_to_group("enemies")
    if is_instance_valid(game.music):
        game.music.beat.connect(_on_beat)
        game.music.section_changed.connect(_on_section)
        if game.music.has_signal("transport_changed"):
            game.music.transport_changed.connect(_on_transport_changed)
    _cube_rng.randomize()
    _configure_authored()

func start_encounter() -> void:
    if dead or _active:
        return
    _active = true
    game.announce("BELLKEEPER  /  Read the gold windup. Parry the contact.", 4.0)
    game.music.start_score()

func receive_hit(amount: int, origin: Vector2) -> void:
    if dead or not _active or game.story_safe or _hurt_timer > 0.0:
        return
    var next_health: int = maxi(0, health - maxi(0, amount))
    if phase == "fixed" or phase == "random":
        # The musical seal keeps phase progression intact even under an overkill hit.
        # Round down to the same integer threshold tested by the music request gate.
        var sealed_health: int = maxi(1, int(floor(float(max_health) * game.music.advance_health_ratio)))
        health = maxi(sealed_health, next_health)
        if phase == "fixed" and health == sealed_health and not _seal_announced:
            _seal_announced = true
            game.announce("A phrase-seal holds at half strength. Follow the bell to break it.", 3.0)
    else:
        health = next_health
    _hurt_timer = 0.09
    hurt_flash = 0.11
    game.emit_fx("hit", global_position + Vector2(0, -28), (global_position - origin).normalized(), 1.1)
    _request_phase_if_ready()
    if health <= 0:
        _die()

func _request_phase_if_ready() -> void:
    if phase == "random" and not _phase_requested and float(health) <= float(max_health) * game.music.advance_health_ratio:
        _phase_requested = true
        game.music.request_advance()
        if not _seal_announced:
            _seal_announced = true
            game.announce("The phrase-seal holds. Silence comes at the next phrase boundary.", 3.0)

func _on_section(section: String) -> void:
    phase = section
    if not _uses_full_song() or section == "rest":
        _cancel_all_attacks()
    _recovery_timer = 0.3
    velocity.x = 0.0
    if section == "rest":
        combat_freeze = 0.0
        hurt_flash = 0.0
        _stagger_timer = 0.0
        guard_posture = 0
        _posture_lockout = 0.0
        _clear_reaction()
    _load_authored_section(section)
    game.on_boss_phase(section)
    match section:
        "random":
            _request_phase_if_ready()
        "rest":
            game.announce("Breathe. Your name is gone; your hands still remember.", 4.0)
        "final":
            game.announce("The seal is open. Keep moving; turn its light against it.", 3.0)

func _on_beat(index: int) -> void:
    if dead or not _active or game.story_safe or phase == "rest" or not _authored_ready or not bool(game.music.running):
        return
    if _uses_full_song():
        _dispatch_full_chart()
        return
    # This value is the exact event timestamp, not a replacement frame clock.
    # Sub-beat actions/hazards read MusicDirector.get_score_time() exclusively.
    _dispatch_authored_clock(float(index - _section_origin_beat) * game.music.seconds_per_beat(), true)

func _begin_attack(attack: String) -> void:
    if dead or game.story_safe or _reaction_blocks_attacks or _posture_lockout > 0.0:
        return
    _invalidate_authored()
    attack_serial += 1
    _resolved_contacts.clear()
    contact_token = attack_serial * 8
    attack_parryable = attack in ["slash", "armored_slash"]
    # Armor and parryability are independent: the armored double cut can be
    # parried; the charging armor cannot. Neither changes projectile reflection.
    attack_armored = attack in ["armored_slash", "charge"]
    _combo_pending = false
    _combo_timer = 0.0
    _pending_attack = attack
    _windup_timer = game.music.seconds_per_beat() * 0.8
    _windup_duration = _windup_timer
    _release_elapsed = -1.0
    _present_strike = 0
    _locked_target = game.player.global_position
    var toward: Vector2 = game.player.global_position + Vector2(0, -14) - global_position - Vector2(0, -25)
    facing = 1 if toward.x >= 0.0 else -1
    _aim = toward.normalized()
    _contact_resolved = false
    var warning_at: Vector2 = global_position + Vector2(facing * 35, -22)
    if attack == "rain":
        warning_at = Vector2(game.player.global_position.x, 120)
    var warning_kind: String = "unblockable_charge" if attack == "charge" else attack
    if game.has_signal("warning_issued"):
        game.emit_signal("warning_issued", warning_kind, warning_at, _windup_timer)
    game.emit_fx("unblockable_charge" if attack == "charge" else "telegraph", warning_at, Vector2(facing, 0), 1.0)

func set_impact_freeze(seconds: float) -> void:
    combat_freeze = maxf(combat_freeze, clampf(seconds, 0, 0.07))

func _physics_process(delta: float) -> void:
    if get_tree().paused or game.get("_paused") == true:
        return
    if game.get("outcome") != null and str(game.get("outcome")) != "":
        _cancel_all_attacks()
        velocity = Vector2.ZERO
        # Victory stops gameplay immediately, but the death animation still
        # receives local presentation time. No action or collision is advanced.
        if dead:
            _death_elapsed += delta
            animation_state = "dead"
            frame = clampi(int(_death_elapsed / 0.6 * 5.999), 0, 5)
            _publish_animation()
        return
    if _uses_full_song() and _active and not game.story_safe and bool(game.music.running):
        _dispatch_full_chart()
        _advance_authored_actions(float(game.music.get_score_time()))
    hurt_flash = maxf(0.0, hurt_flash - delta)
    _posture_lockout = maxf(0.0, _posture_lockout - delta)
    if game.story_safe:
        # Safety takes priority over local hit-stop and every delayed contact.
        _cancel_all_attacks()
        _clear_reaction()
        guard_posture = 0
        _posture_lockout = 0.0
        _stagger_timer = 0.0
        hurt_flash = 0.0
        combat_freeze = 0.0
    elif combat_freeze > 0.0 and not dead:
        combat_freeze = maxf(0.0, combat_freeze - delta)
        queue_redraw()
        return
    _animation_clock += delta
    _authored_pose_elapsed += delta
    _warning_elapsed += delta
    if _release_elapsed >= 0.0:
        _release_elapsed += delta
    if dead:
        _death_elapsed += delta
    elif _active and not game.story_safe and _authored_ready and bool(game.music.running) and game.music.has_method("get_score_time"):
        var score: float = float(game.music.get_score_time())
        if _uses_full_song():
            _dispatch_full_chart()
        else:
            _dispatch_authored_clock(maxf(0.0, score - _section_origin_score), false)
        _prepare_upcoming(score)
        _advance_authored_actions(score)
    _hurt_timer = maxf(0.0, _hurt_timer - delta)
    _stagger_timer = maxf(0.0, _stagger_timer - delta)
    _recovery_timer = maxf(0.0, _recovery_timer - delta)
    _advance_reaction(delta)
    if _combo_pending and not _reaction_blocks_attacks and not dead and not game.story_safe:
        _combo_timer = maxf(0.0, _combo_timer - delta)
        if _combo_timer <= 0.0:
            _release_combo_contact()
    if dead:
        velocity.x = move_toward(velocity.x, 0.0, delta * 500.0)
        animation_state = "dead"
    elif not _active or game.story_safe:
        velocity.x = 0.0
        animation_state = "idle"
    elif _reaction_blocks_attacks:
        velocity.x = move_toward(velocity.x, 0.0, delta * 400.0)
        animation_state = reaction_state
    elif _stagger_timer > 0.0:
        velocity.x = move_toward(velocity.x, 0.0, delta * 1000.0)
        animation_state = "hurt"
    elif not _authored_dash.is_empty():
        _advance_authored_dash(float(game.music.get_score_time()))
        if not _authored_dash.is_empty():
            velocity.x = 0.0
            animation_state = "dash"
        elif _reaction_blocks_attacks:
            animation_state = reaction_state
    elif _windup_timer > 0.0:
        _windup_timer = maxf(0.0, _windup_timer - delta)
        velocity.x = move_toward(velocity.x, 0.0, delta * 1000.0)
        animation_state = "windup"
        if _windup_timer <= 0.0:
            _release_attack()
    elif _charge_timer > 0.0:
        _charge_timer = maxf(0.0, _charge_timer - delta)
        velocity.x = facing * 430.0
        animation_state = "dash"
        _try_melee_contact(50.0, false, true, contact_token)
    elif _combo_pending:
        velocity.x = 0.0
        animation_state = "windup"
    elif _recovery_timer > 0.0:
        velocity.x = move_toward(velocity.x, 0.0, delta * 800.0)
        animation_state = "attack"
    else:
        var distance: float = game.player.global_position.x - global_position.x
        facing = 1 if distance >= 0.0 else -1
        velocity.x = facing * (85.0 if phase == "final" else 62.0) if absf(distance) > 54.0 else 0.0
        if is_on_wall() and is_on_floor():
            velocity.y = -290.0
        animation_state = "run" if absf(velocity.x) > 1.0 else "idle"
    if not is_on_floor():
        velocity.y = minf(velocity.y + 950.0 * delta, 650.0)
    move_and_slide()
    global_position.x = clampf(global_position.x, ARENA_LEFT, ARENA_RIGHT)
    if reaction_state != "none" and not dead:
        animation_state = reaction_state
        frame = clampi(int(reaction_progress * 3.999), 0, 3)
    else:
        if _hurt_timer > 0.0 and not dead and _authored_dash.is_empty() and not (_release_elapsed >= 0.0 and _release_elapsed < 0.10):
            animation_state = "hurt"
        frame = int(_animation_clock * 12.0) % 6
    _publish_animation()

func _publish_animation() -> void:
    if is_instance_valid(game) and game.has_signal("animation_event") and (animation_state != _last_state or frame != _last_frame or facing != _last_facing):
        _last_state = animation_state
        _last_frame = frame
        _last_facing = facing
        game.emit_signal("animation_event", self, animation_state, frame, facing)
    queue_redraw()

func _release_attack() -> void:
    if dead or game.story_safe or _stagger_timer > 0.0 or _reaction_blocks_attacks or _posture_lockout > 0.0:
        _cancel_all_attacks()
        return
    var source: Vector2 = global_position + Vector2(0, -26)
    var attack: String = _pending_attack
    _pending_attack = ""
    _windup_timer = 0.0
    if attack.is_empty():
        return
    _recovery_timer = 0.24
    _release_elapsed = 0.0
    _present_strike = 1
    match attack:
        "slash":
            _try_melee_contact(78.0, true, false, contact_token)
            if not _reaction_blocks_attacks:
                game.emit_fx("enemy_slash", source + Vector2(facing * 20, 0), Vector2(facing, 0), 1.4)
        "armored_slash":
            # Schedule before contact, so a third parry can cancel the whole chain.
            _combo_pending = true
            _combo_timer = ARMORED_CHAIN_GAP
            _try_melee_contact(78.0, true, true, contact_token)
            if _combo_pending and game.has_signal("warning_issued"):
                game.emit_signal("warning_issued", "armored_slash", source + Vector2(facing * 35, 0), ARMORED_CHAIN_GAP)
            if not _reaction_blocks_attacks:
                game.emit_fx("enemy_slash", source + Vector2(facing * 20, 0), Vector2(facing, 0), 1.5)
        "charge":
            _charge_timer = 0.30
            velocity.y = -95.0
            game.emit_fx("enemy_dash", source, Vector2(facing, 0), 1.3)
        "fan":
            var count: int = 7 if phase == "final" else 5
            for i: int in count:
                var offset: float = lerpf(-0.5, 0.5, float(i) / float(count - 1))
                game.spawn_projectile(source, _aim.rotated(offset) * 118.0)
        "ring":
            var count: int = 12 if phase == "final" else 10
            for i: int in count:
                # A clear upward gap prevents a solid unbroken wall of projectiles.
                if i == count / 4:
                    continue
                var angle: float = TAU * float(i) / float(count)
                game.spawn_projectile(source, Vector2.from_angle(angle) * 100.0)
        "rain":
            var middle: float = clampf(game.player.global_position.x, ARENA_LEFT + 80, ARENA_RIGHT - 80)
            for i: int in 5:
                var offset: float = float(i - 2) * 48.0
                # Deliberate central safe lane; lateral drift makes the shower readable.
                if i == 2:
                    continue
                game.spawn_projectile(Vector2(middle + offset, 112), Vector2(-facing * 12.0, 130.0))

func _release_combo_contact() -> void:
    if not _combo_pending or dead or game.story_safe or _reaction_blocks_attacks or _posture_lockout > 0.0:
        return
    _combo_pending = false
    _combo_timer = 0.0
    _release_elapsed = 0.0
    _present_strike = 2
    contact_token = attack_serial * 8 + 1
    _contact_resolved = false
    _recovery_timer = 0.24
    _try_melee_contact(78.0, true, true, contact_token)
    if not _reaction_blocks_attacks:
        game.emit_fx("enemy_slash", global_position + Vector2(facing * 20, -26), Vector2(facing, 0), 1.5)

func _try_melee_contact(reach: float, parryable: bool = true, armored: bool = false, token: int = -1) -> void:
    if _contact_resolved or game.story_safe or dead or _reaction_blocks_attacks or _posture_lockout > 0.0:
        return
    var actual_token: int = contact_token if token < 0 else token
    if actual_token != contact_token or _resolved_contacts.has(actual_token):
        return
    var difference: Vector2 = game.player.global_position + Vector2(0, -14) - (global_position + Vector2(0, -24))
    if absf(difference.x) > reach or absf(difference.y) > 43.0 or difference.x * facing < -22.0:
        return
    _contact_resolved = true
    _resolved_contacts[actual_token] = true
    # The weapon reaches the player's front edge. The defender independently
    # verifies its facing and current input window before awarding any success.
    var contact_side: float = signf(global_position.x - game.player.global_position.x)
    if is_zero_approx(contact_side):
        contact_side = float(-facing)
    var contact: Vector2 = game.player.global_position + Vector2(contact_side * minf(18.0, absf(difference.x) * 0.5), -18)
    var would_break: bool = guard_posture + 1 >= guard_max
    var accepted: bool = false
    if parryable and game.player.parry_timer > 0.0:
        accepted = game.player.parry_success(self, contact, "guard_break" if would_break else "melee", actual_token)
    if accepted:
        guard_posture = mini(guard_max, guard_posture + 1)
        hurt_flash = 0.0
        if would_break:
            _cancel_contact_sequence()
            velocity.x = -facing * 44.0
            _start_reaction("guard_break", GUARD_BREAK_TIME, true)
        elif armored:
            # Armor accepts the clash and posture, but retains the later contact.
            _start_reaction("parry_recoil", ARMORED_RECOIL_TIME, false)
        else:
            _cancel_contact_sequence()
            velocity.x = -facing * 70.0
            _start_reaction("parry_recoil", NORMAL_RECOIL_TIME, true)
    else:
        game.damage_player(1, global_position)

func _cancel_contact_sequence() -> void:
    if not _uses_full_song():
        _cancel_all_attacks()
        return
    var serial: int = int(contact_token / 8)
    var retained: Array[Dictionary] = []
    for action: Dictionary in _authored_actions:
        if int(action["source_serial"]) == serial and str(action["type"]) not in ["ring", "fan", "side_spray"]:
            _trace_skipped("contact_cancel_" + str(action["type"]), str(action["source_pattern"]), float(game.music.get_score_time()))
        else:
            retained.append(action)
    _authored_actions = retained
    _authored_dash.clear()
    _pending_attack = ""
    _windup_timer = 0.0
    _charge_timer = 0.0
    _recovery_timer = 0.0
    _combo_pending = false
    _combo_timer = 0.0
    _contact_resolved = true
    _warning_geometry.clear()
    _release_elapsed = -1.0
    attack_parryable = false
    attack_armored = false

func _stale_window() -> float:
    var configured: Variant = game.music.get("timeline")
    return clampf(float(configured.get("stale_action_seconds", 0.20)), 0.02, 0.50) if configured is Dictionary else 0.20

func _cancel_all_attacks() -> void:
    _invalidate_authored()
    _release_elapsed = -1.0
    _present_strike = 0
    _pending_attack = ""
    _windup_timer = 0.0
    _charge_timer = 0.0
    _recovery_timer = 0.0
    _combo_pending = false
    _combo_timer = 0.0
    _contact_resolved = true
    attack_parryable = false
    attack_armored = false

func _start_reaction(state: String, duration: float, blocks_attacks: bool) -> void:
    reaction_state = state
    reaction_progress = 0.0
    _reaction_elapsed = 0.0
    _reaction_duration = duration
    _reaction_blocks_attacks = blocks_attacks
    animation_state = state
    frame = 0
    _publish_animation()

func _clear_reaction() -> void:
    reaction_state = "none"
    reaction_progress = 0.0
    _reaction_elapsed = 0.0
    _reaction_duration = 0.0
    _reaction_blocks_attacks = false

func _advance_reaction(delta: float) -> void:
    var remaining: float = maxf(0.0, delta)
    while remaining > 0.000001 and reaction_state != "none":
        var consumed: float = minf(remaining, maxf(0.0, _reaction_duration - _reaction_elapsed))
        _reaction_elapsed += consumed
        remaining -= consumed
        reaction_progress = clampf(_reaction_elapsed / maxf(0.001, _reaction_duration), 0.0, 1.0)
        if _reaction_elapsed < _reaction_duration - 0.000001:
            break
        if reaction_state == "guard_break":
            guard_posture = 0
            _posture_lockout = POSTURE_RESET_LOCK
            _start_reaction("guard_recover", GUARD_RECOVER_TIME, true)
        elif reaction_state == "parry_recoil" and _reaction_blocks_attacks:
            _start_reaction("parry_recover", NORMAL_RECOVER_TIME, true)
        else:
            _clear_reaction()

func _die() -> void:
    if dead:
        return
    dead = true
    _active = false
    _cancel_all_attacks()
    _clear_reaction()
    guard_posture = 0
    game.music.stop_score()
    game.emit_fx("boss_defeat", global_position + Vector2(0, -28), Vector2.ZERO, 2.0)
    game.on_boss_defeated()


# MIT friend PR1/PR3 integration: scheduling/geometry are source-derived;
# main health, physical contact, reactions and MusicDirector remain authoritative.
func _configure_authored() -> void:
    var file: FileAccess = FileAccess.open("res://data/main_boss_chart.json", FileAccess.READ)
    if file == null:
        return
    var parsed: Variant = JSON.parse_string(file.get_as_text())
    if not parsed is Dictionary:
        return
    _authored_document = parsed
    friend_slots = FriendSlots.new()
    add_child(friend_slots)
    _authored_ready = friend_slots.load_config("res://data/authored_boss_moves.json")
    friend_director.event_dispatched.connect(_on_authored_event)
    if _uses_full_song():
        var status: Dictionary = game.music.get_full_song_status()
        _authored_ready = _authored_ready and friend_director.load_source_file(str(status["chart_path"]), float(game.music.bpm), float(status["offset_ms"]))

func _uses_full_song() -> bool:
    return is_instance_valid(game) and is_instance_valid(game.music) and game.music.has_method("is_full_song") and game.music.is_full_song()

func _on_transport_changed(generation: int, _chart_time: float) -> void:
    if not _uses_full_song():
        return
    _cancel_all_attacks()
    _full_seen_generation = generation
    _loop_origin_score = float(game.music.get_score_time()) - float(game.music.get_chart_time())
    _authored_cycle = maxi(0, generation - 1)
    if _authored_ready and not dead and phase != "rest":
        friend_director.restart_at(float(game.music.get_chart_time()))

func _dispatch_full_chart() -> void:
    if dead or not _active or game.story_safe or phase == "rest" or not _authored_ready:
        return
    var generation: int = int(game.music.get_transport_generation())
    if generation != _full_seen_generation:
        _on_transport_changed(generation, float(game.music.get_chart_time()))
    _loop_origin_score = float(game.music.get_score_time()) - float(game.music.get_chart_time())
    if not friend_director.running:
        if _reaction_blocks_attacks or _posture_lockout > 0.0 or combat_freeze > 0.0:
            return
        friend_director.restart_at(float(game.music.get_chart_time()))
    friend_director.advance_to(float(game.music.get_chart_time()))

func _trace_skipped(kind: String, pattern: String, score: float) -> void:
    authored_trace.append({"pattern": pattern, "type": "skipped_stale_" + kind, "serial": attack_serial, "time": score})
    if authored_trace.size() > 96:
        authored_trace.pop_front()

func _load_authored_section(section: String) -> void:
    if _uses_full_song():
        _full_seen_generation = int(game.music.get_transport_generation())
        _loop_origin_score = float(game.music.get_score_time()) - float(game.music.get_chart_time())
        _authored_cycle = maxi(0, _full_seen_generation - 1)
        if _authored_ready and section != "rest" and not friend_director.running:
            friend_director.restart_at(float(game.music.get_chart_time()))
        return
    _section_origin_beat = int(game.music.total_beats)
    _section_origin_score = float(_section_origin_beat) * game.music.seconds_per_beat()
    _loop_origin_score = _section_origin_score
    _authored_cycle = 0
    if not _authored_ready or section == "rest":
        return
    var document: Dictionary = _authored_document.get("sections", {}).get(section, {})
    if document.is_empty():
        return
    _authored_loop_beats = maxi(1, int(document.get("loop_beats", 16)))
    if friend_director.load_document(document, float(game.music.bpm)):
        friend_director.restart_at()

func _dispatch_authored_clock(elapsed: float, on_beat: bool) -> void:
    if dead or game.story_safe or phase == "rest" or not _authored_ready:
        return
    var duration: float = float(_authored_loop_beats) * game.music.seconds_per_beat()
    var cycle: int = int(floor(maxf(0.0, elapsed) / duration + 0.000001))
    var local: float = maxf(0.0, elapsed - float(cycle) * duration)
    if cycle != _authored_cycle:
        _invalidate_authored()
        _authored_cycle = cycle
        _loop_origin_score = _section_origin_score + float(cycle) * duration
        var document: Dictionary = _authored_document["sections"][phase]
        friend_director.load_document(document, float(game.music.bpm))
        friend_director.restart_at(local)
    if not friend_director.running:
        if _reaction_blocks_attacks or _posture_lockout > 0.0 or combat_freeze > 0.0:
            return
        friend_director.restart_at(local)
    # Fixed cue starts are emitted by beat callbacks only. Continuous processing
    # still advances existing cube/laser geometry through its own music getter.
    if on_beat or phase != "fixed":
        friend_director.advance_to(local)

func _on_authored_event(event: Dictionary, version: int) -> void:
    if version != friend_director.generation or dead or game.story_safe or (not _uses_full_song() and (_reaction_blocks_attacks or _posture_lockout > 0.0 or combat_freeze > 0.0)):
        return
    if _uses_full_song() and int(game.music.get_transport_generation()) != _full_seen_generation:
        return
    var payload: Dictionary = event["payload"]
    match str(event["type"]):
        "action_phrase":
            if _uses_full_song() or phase == "random" or phase == "final":
                var pattern: Dictionary = _pattern_for_phrase(payload)
                var key: int = int(payload["index"])
                if _uses_full_song():
                    var actions: Array = (pattern.get("parameters", {}) as Dictionary).get("actions", pattern.get("actions", []))
                    var last_beat: float = 0.0
                    for action: Dictionary in actions:
                        last_beat = maxf(last_beat, float(action.get("beat", 0.0)))
                    if float(game.music.get_chart_time()) > float(payload["start_time"]) + last_beat * game.music.seconds_per_beat() + _stale_window():
                        _prepared_plans.erase(key)
                        authored_skipped_actions += 1
                        _trace_skipped("phrase", str(pattern.get("pattern_id", "")), float(game.music.get_score_time()))
                        return
                var prepared: Dictionary = _prepared_plans.get(key, {})
                _prepared_plans.erase(key)
                _begin_authored_pattern(pattern, _loop_origin_score + float(payload["start_time"]), Vector2.INF, prepared)
        "fixed_attack":
            _spawn_authored_cube(payload)
        "laser_formation":
            _spawn_authored_formation(payload)

func _pattern_for_phrase(phrase: Dictionary) -> Dictionary:
    var sequence: int = int(phrase["sequence_index"])
    if (str(phrase.get("mode", "basic")) == "fast" if _uses_full_song() else phase == "final"):
        var pattern: Dictionary = friend_slots.get_fast_pattern(sequence)
        pattern["pattern_id"] = friend_slots.fast_cycle[posmod(sequence, friend_slots.fast_cycle.size())]
        return pattern
    return friend_slots.get_normal_pattern(sequence)

func _prepare_upcoming(score: float) -> void:
    if (not _uses_full_song() and phase not in ["random", "final"]) or phase == "rest" or _reaction_blocks_attacks or _posture_lockout > 0.0:
        return
    for phrase: Dictionary in friend_director.chart.action_phrases:
        var start: float = _loop_origin_score + float(phrase["start_time"])
        var key: int = int(phrase["index"])
        if start <= score + 0.000001 or start - score > game.music.seconds_per_beat() * 0.8 or _prepared_plans.has(key):
            continue
        var pattern: Dictionary = _pattern_for_phrase(phrase)
        var target: Vector2 = game.player.global_position
        var plan: Dictionary = FriendPlanner.build_plan(pattern, start, game.music.seconds_per_beat(), global_position, target, PLAN_ARENA)
        _prepared_plans[key] = plan
        _warning_elapsed = 0.0
        _warning_duration = maxf(0.001, start - score)
        _warning_geometry = {"kind": "authored_path", "pattern": str(pattern.get("pattern_id", "")), "from": global_position, "to": target, "locked_target": target, "start_time": score, "damage_time": start}

func _begin_authored_pattern(pattern: Dictionary, start_score_time: float, locked_target: Vector2 = Vector2.INF, prepared: Dictionary = {}) -> bool:
    if dead or game.story_safe or (not _uses_full_song() and (_reaction_blocks_attacks or _posture_lockout > 0.0)) or pattern.is_empty() or (pattern.has("enabled") and not bool(pattern["enabled"])):
        return false
    var target: Vector2 = game.player.global_position if not locked_target.is_finite() else locked_target
    var plan: Dictionary = prepared.duplicate(true) if not prepared.is_empty() else FriendPlanner.build_plan(pattern, start_score_time, game.music.seconds_per_beat(), global_position, target, PLAN_ARENA)
    if (plan["actions"] as Array).is_empty():
        return false
    attack_serial += 1
    _authored_dash.clear()
    for resolved: int in _resolved_contacts.keys():
        if resolved < (attack_serial - 16) * 8:
            _resolved_contacts.erase(resolved)
    _source_strikes[attack_serial] = 0
    authored_last_pattern = str(plan["pattern_id"])
    authored_pattern_count += 1
    _locked_target = plan["locked_player"]
    # Queue source actions without doing collision in the music callback. At a
    # shared boundary an old ring@4 sorts before the next teleport@0.
    for index: int in (plan["actions"] as Array).size():
        var action: Dictionary = plan["actions"][index].duplicate(true)
        if str(action.get("type", "")) == "aim":
            var aim_duration: float = game.music.seconds_per_beat() * 2.0
            for next_index: int in range(index + 1, (plan["actions"] as Array).size()):
                var next_action: Dictionary = plan["actions"][next_index]
                if str(next_action.get("type", "")) == "dash":
                    aim_duration = maxf(0.001, float(next_action["time"]) - float(action["time"]))
                    break
            action["telegraph_duration"] = aim_duration
        action["source_serial"] = attack_serial
        action["source_pattern"] = authored_last_pattern
        action["source_index"] = index
        action["source_locked_target"] = _locked_target
        action["generation"] = hazard_generation
        if _authored_actions.size() < 96:
            _authored_actions.append(action)
        else:
            authored_skipped_actions += 1
            _trace_skipped("queue_capacity", authored_last_pattern, float(game.music.get_score_time()))
    _authored_actions.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
        if is_equal_approx(float(a["time"]), float(b["time"])):
            if int(a["source_serial"]) == int(b["source_serial"]):
                return int(a["source_index"]) < int(b["source_index"])
            return int(a["source_serial"]) < int(b["source_serial"])
        return float(a["time"]) < float(b["time"]))
    _warning_geometry.clear()
    return true

func _advance_authored_actions(score: float) -> void:
    if game.story_safe or dead:
        return
    var blocked: bool = _reaction_blocks_attacks or _posture_lockout > 0.0 or combat_freeze > 0.0
    if blocked and not _uses_full_song():
        return
    var deferred: Array[Dictionary] = []
    var attempts: int = 0
    var version: int = hazard_generation
    while not _authored_actions.is_empty() and attempts < 24 and version == hazard_generation:
        var action: Dictionary = _authored_actions[0]
        if float(action["time"]) > score + 0.000001:
            break
        _authored_actions.pop_front()
        attempts += 1
        if int(action["generation"]) != version:
            continue
        if score - float(action["time"]) > _stale_window():
            authored_skipped_actions += 1
            _trace_skipped("action_" + str(action["type"]), str(action["source_pattern"]), score)
            continue
        if blocked and str(action["type"]) not in ["ring", "fan", "side_spray"]:
            deferred.append(action)
            continue
        _execute_authored_action(action, score)
    _authored_actions.append_array(deferred)
    if not deferred.is_empty():
        _authored_actions.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
            if is_equal_approx(float(a["time"]), float(b["time"])):
                if int(a["source_serial"]) == int(b["source_serial"]):
                    return int(a["source_index"]) < int(b["source_index"])
                return int(a["source_serial"]) < int(b["source_serial"])
            return float(a["time"]) < float(b["time"]))

func _execute_authored_action(action: Dictionary, score: float) -> void:
    var kind: String = str(action["type"])
    var pattern: String = str(action["source_pattern"])
    var serial: int = int(action["source_serial"])
    var target: Vector2 = action.get("resolved_target", global_position)
    authored_action_count += 1
    authored_trace.append({"pattern": pattern, "type": kind, "serial": serial, "time": score})
    if authored_trace.size() > 96:
        authored_trace.pop_front()
    match kind:
        "aim":
            _warning_elapsed = 0.0
            _warning_duration = float(action.get("telegraph_duration", game.music.seconds_per_beat() * 2.0))
            _warning_geometry = {"kind": "authored_path", "pattern": pattern, "from": global_position, "to": Vector2(target.x, global_position.y), "locked_target": action["source_locked_target"], "start_time": score, "damage_time": score + _warning_duration}
            _set_authored_pose("draw", _warning_duration)
        "teleport", "center":
            var old: Vector2 = global_position
            var x: float = PLAN_ARENA.get_center().x if kind == "center" else target.x
            global_position.x = clampf(x, ARENA_LEFT + 30.0, ARENA_RIGHT - 30.0)
            velocity = Vector2.ZERO
            game.emit_fx("enemy_dash", old + Vector2(0, -24), Vector2(signf(global_position.x - old.x), 0), 0.9)
            _set_authored_pose("shift", 0.20)
        "dash":
            var duration: float = maxf(0.08, float(action.get("duration_beats", 1.0)) * game.music.seconds_per_beat())
            var to: Vector2 = Vector2(clampf(target.x, ARENA_LEFT + 30.0, ARENA_RIGHT - 30.0), global_position.y)
            facing = 1 if to.x >= global_position.x else -1
            contact_token = serial * 8 + int(action["source_index"])
            _contact_resolved = false
            attack_parryable = pattern != "charge_dash_ring"
            attack_armored = pattern != "fan_then_dash"
            _source_strikes[serial] = int(_source_strikes.get(serial, 0)) + 1
            _present_strike = mini(2, int(_source_strikes[serial]))
            _release_elapsed = 0.0
            _authored_dash = {"from": global_position, "to": to, "start_time": float(action["time"]), "end_time": float(action["time"]) + duration, "parryable": attack_parryable, "armored": attack_armored, "token": contact_token}
            _warning_geometry.clear()
            game.emit_fx("enemy_dash", global_position + Vector2(0, -26), Vector2(facing, 0), 1.0)
        "ring", "fan", "side_spray":
            var shots: Array[Dictionary] = FriendPatterns.vectors(kind, action, global_position + Vector2(0, -26), (action["source_locked_target"] as Vector2) + Vector2(0, -13))
            for shot: Dictionary in shots:
                var style: String = "elite_rune" if kind == "ring" else ("wisp_seed" if kind == "side_spray" else "sentry_shard")
                var projectile: Node2D = game.spawn_projectile(shot["position"], shot["velocity"], false, style)
                if is_instance_valid(projectile):
                    projectile.set("lifetime", float(shot["ttl_seconds"]))
                    projectile.set_meta("boss_source", get_instance_id())
                else:
                    _trace_skipped("projectile_capacity", pattern, score)
            _set_authored_pose("cast", 0.24)

func _advance_authored_dash(score: float) -> void:
    if _authored_dash.is_empty():
        return
    var dash: Dictionary = _authored_dash.duplicate()
    var duration: float = maxf(0.001, float(dash["end_time"]) - float(dash["start_time"]))
    var progress: float = clampf((score - float(dash["start_time"])) / duration, 0.0, 1.0)
    global_position = (dash["from"] as Vector2).lerp(dash["to"], progress)
    _try_melee_contact(78.0 if bool(dash["parryable"]) else 50.0, bool(dash["parryable"]), bool(dash["armored"]), int(dash["token"]))
    if not _authored_dash.is_empty() and progress >= 1.0:
        _authored_dash.clear()
        _set_authored_pose("recover", 0.18)

func _spawn_authored_cube(event: Dictionary) -> void:
    if not game.has_method("spawn_boss_hazard"):
        return
    if not bool(friend_slots.get_fixed_pattern().get("enabled", false)):
        return
    var occurrence: int = _cube_launch_count
    _cube_launch_count += 1
    var diamond: bool = _cube_rng.randi_range(0, 1) == 1
    var plan: Dictionary = FriendPlanner.build_fixed_cube(friend_slots.get_fixed_pattern()["parameters"], _loop_origin_score + float(event["time"]), game.music.seconds_per_beat(), global_position + Vector2(0, -30), LASER_ARENA, occurrence, diamond)
    if _uses_full_song() and float(plan["damage_time"]) - float(game.music.get_score_time()) < float(game.music.timeline.get("minimum_remaining_warning_seconds", 0.15)):
        _trace_skipped("cube", "fixed_1", float(game.music.get_score_time()))
        return
    var hazard: Node2D = BossHazard.new()
    hazard.configure_cube(game, self, plan, LASER_ARENA, hazard_generation)
    if game.spawn_boss_hazard(hazard):
        attack_serial += 1
        authored_last_pattern = "cube_plus" if bool(plan["diamond"]) else "cube_x"
        authored_pattern_count += 1
        _set_authored_pose("cast", game.music.seconds_per_beat() * 0.8)
    else:
        _trace_skipped("hazard_capacity", "fixed_1", float(game.music.get_score_time()))

func _spawn_authored_formation(event: Dictionary) -> void:
    if not game.has_method("spawn_boss_hazard"):
        return
    var formation: Dictionary = event.duplicate(true)
    formation["occurrence"] = int(event.get("occurrence", 0)) + _authored_cycle * (1 if _uses_full_song() else maxi(1, int(ceil(float(friend_director.chart.laser_formations.size()) / 4.0))))
    var lines: Array[Dictionary] = FriendLasers.build_lines(formation, friend_slots.get_laser_formations(), LASER_ARENA)
    for line: Dictionary in lines:
        for key: String in ["warning_time", "damage_time", "active_until"]:
            line[key] = float(line[key]) + _loop_origin_score
    if _uses_full_song():
        var future: Array[Dictionary] = []
        for line: Dictionary in lines:
            var now: float = float(game.music.get_score_time())
            var warning_lateness: float = now - float(line["warning_time"])
            # Source-authored short warnings remain intact at normal cadence.
            # The minimum remaining lead is only a stale-frame recovery policy.
            if warning_lateness <= _stale_window() or float(line["damage_time"]) - now >= float(game.music.timeline.get("minimum_remaining_warning_seconds", 0.15)):
                future.append(line)
            else:
                _trace_skipped("laser_line", str(formation["pattern"]), float(game.music.get_score_time()))
        lines = future
        if lines.is_empty():
            return
    var hazard: Node2D = BossHazard.new()
    hazard.configure_lines(game, self, lines, LASER_ARENA, hazard_generation, str(formation["pattern"]))
    if not game.spawn_boss_hazard(hazard):
        _trace_skipped("hazard_capacity", str(formation["pattern"]), float(game.music.get_score_time()))

func _invalidate_authored() -> void:
    hazard_generation += 1
    friend_director.invalidate()
    _authored_actions.clear()
    _authored_dash.clear()
    _prepared_plans.clear()
    _source_strikes.clear()
    _warning_geometry.clear()
    _authored_pose = ""
    if is_instance_valid(game) and game.has_method("clear_boss_hazards"):
        game.clear_boss_hazards()

func _set_authored_pose(state: String, duration: float) -> void:
    _authored_pose = state
    _authored_pose_elapsed = 0.0
    _authored_pose_duration = maxf(0.001, duration)

func get_authored_status() -> Dictionary:
    return {"section": phase, "pattern": authored_last_pattern, "serial": attack_serial, "queued_actions": _authored_actions.size(), "dash_active": not _authored_dash.is_empty(), "cycle": _authored_cycle, "hazard_generation": hazard_generation, "pattern_count": authored_pattern_count, "action_count": authored_action_count, "skipped_actions": authored_skipped_actions, "full_song": _uses_full_song(), "transport_generation": _full_seen_generation, "trace": authored_trace.duplicate(true)}

func get_warning_geometry(kind: String = "") -> Dictionary:
    if _warning_geometry.is_empty() or (not kind.is_empty() and str(_warning_geometry.get("kind", "")) != kind):
        return {}
    return _warning_geometry.duplicate(true)

func get_presentation_pose() -> Dictionary:
    var state: String = "idle"
    var progress: float = 0.0
    if dead:
        state = "dead"
        progress = clampf(_death_elapsed / 0.6, 0.0, 1.0)
    elif reaction_state != "none":
        state = "armored_recoil" if reaction_state == "parry_recoil" and not _reaction_blocks_attacks else reaction_state
        progress = reaction_progress
    elif not _authored_dash.is_empty():
        state = "cut_b" if _present_strike >= 2 else "cut_a"
        progress = clampf(_release_elapsed / 0.18, 0.0, 1.0)
    elif _windup_timer > 0.0:
        state = "draw" if _pending_attack in ["slash", "armored_slash", "charge"] else "cast"
        progress = clampf(1.0 - _windup_timer / maxf(0.001, _windup_duration), 0.0, 1.0)
    elif _charge_timer > 0.0 or (_release_elapsed >= 0.0 and _release_elapsed < 0.10):
        state = "cut_b" if _present_strike >= 2 else "cut_a"
        progress = clampf(_release_elapsed / 0.10, 0.0, 1.0)
    elif _combo_pending:
        state = "draw"
        progress = clampf(1.0 - _combo_timer / ARMORED_CHAIN_GAP, 0.0, 1.0)
    elif not _authored_pose.is_empty() and _authored_pose_elapsed < _authored_pose_duration:
        state = _authored_pose
        progress = clampf(_authored_pose_elapsed / _authored_pose_duration, 0.0, 1.0)
    elif _recovery_timer > 0.0:
        state = "recover"
        progress = clampf(1.0 - _recovery_timer / 0.24, 0.0, 1.0)
    elif _hurt_timer > 0.0:
        state = "hurt"
        progress = clampf(1.0 - _hurt_timer / 0.09, 0.0, 1.0)
    elif not _warning_geometry.is_empty():
        state = "draw"
        progress = clampf(_warning_elapsed / maxf(0.001, _warning_duration), 0.0, 1.0)
    elif absf(velocity.x) > 1.0:
        state = "approach"
        progress = fmod(_animation_clock * 3.0, 1.0)
    return {"state": state, "progress": progress, "strike": _present_strike, "armored": attack_armored, "contact_serial": contact_token}

func _draw() -> void:
    Pixels.paint(self, "boss", animation_state, frame, facing)
    if not _warning_geometry.is_empty() and str(_warning_geometry.get("kind", "")) == "authored_path":
        var from: Vector2 = (_warning_geometry["from"] as Vector2) - global_position + Vector2(0, -18)
        var to: Vector2 = (_warning_geometry["to"] as Vector2) - global_position + Vector2(0, -18)
        var ink: Color = Color("ff967f") if str(_warning_geometry.get("pattern", "")) == "charge_dash_ring" else Color("ffd779")
        draw_line(from.round(), to.round(), Color(ink, 0.55), 1.0, false)
        draw_rect(Rect2(to.round() - Vector2(3, 3), Vector2(6, 6)), ink, false, 1.0)
    if _windup_timer > 0.0 or _combo_pending:
        var gold := Color("ff967f") if not attack_parryable and _pending_attack == "charge" else Color("ffd779")
        var direction: int = facing
        for i: int in 5:
            draw_rect(Rect2(Vector2(direction * (26 + i * 6), -25), Vector2(3, 3)), gold)
        draw_rect(Rect2(-24, -65, 48, 2), Color("72554c"))
        var remaining: float = _combo_timer if _combo_pending else _windup_timer
        var duration: float = ARMORED_CHAIN_GAP if _combo_pending else game.music.seconds_per_beat() * 0.8
        var progress: float = 1.0 - remaining / maxf(0.01, duration)
        draw_rect(Rect2(-24, -65, 48.0 * progress, 2), gold)

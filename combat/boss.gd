extends CharacterBody2D
## Bellkeeper: readable beat-led windups, pursuit, repositioning and projectile patterns.

const Pixels = preload("res://assets/art/pixel_actor.gd")
const ARENA_LEFT: float = 2660.0
const ARENA_RIGHT: float = 3330.0

var game: Node
var max_health: int = 48
var health: int = 48
var phase: String = "fixed"
var dead: bool = false
var facing: int = -1
var animation_state: String = "idle"
var frame: int = 0
var combat_freeze: float = 0.0
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
    if section == "rest":
        combat_freeze = 0
        hurt_flash = 0
    _pending_attack = ""
    _windup_timer = 0.0
    _charge_timer = 0.0
    _recovery_timer = 0.3
    _contact_resolved = true
    velocity.x = 0.0
    game.on_boss_phase(section)
    match section:
        "random":
            _request_phase_if_ready()
        "rest":
            game.announce("Breathe. Your name is gone; your hands still remember.", 4.0)
        "final":
            game.announce("The seal is open. Keep moving; turn its light against it.", 3.0)

func _on_beat(index: int) -> void:
    if dead or not _active or game.story_safe or _stagger_timer > 0.0:
        return
    if _windup_timer > 0.0 or _charge_timer > 0.0 or _recovery_timer > 0.0:
        return
    if index % 2 != 0:
        return
    var fixed_patterns: Array[String] = ["slash", "fan", "charge", "ring"]
    var patterns: Array[String] = ["slash", "fan", "charge", "rain", "ring"]
    var attack: String
    if phase == "fixed":
        attack = fixed_patterns[_attack_count % fixed_patterns.size()]
    elif phase == "random":
        var choices: Array[String] = []
        for candidate: String in patterns:
            if candidate != _last_pattern:
                choices.append(candidate)
        attack = choices[randi_range(0, choices.size() - 1)]
    else:
        attack = patterns[_attack_count % patterns.size()]
    _last_pattern = attack
    _attack_count += 1
    _begin_attack(attack)

func _begin_attack(attack: String) -> void:
    _pending_attack = attack
    _windup_timer = game.music.seconds_per_beat() * 0.8
    var toward: Vector2 = game.player.global_position + Vector2(0, -14) - global_position - Vector2(0, -25)
    facing = 1 if toward.x >= 0.0 else -1
    _aim = toward.normalized()
    _contact_resolved = false
    var warning_at: Vector2 = global_position + Vector2(facing * 35, -22)
    if attack == "rain":
        warning_at = Vector2(game.player.global_position.x, 120)
    if game.has_signal("warning_issued"):
        game.emit_signal("warning_issued", attack, warning_at, _windup_timer)
    game.emit_fx("telegraph", warning_at, Vector2(facing, 0), 1.0)

func set_impact_freeze(seconds: float) -> void:
    combat_freeze = maxf(combat_freeze, clampf(seconds, 0, 0.07))

func _physics_process(delta: float) -> void:
    hurt_flash = maxf(0, hurt_flash - delta)
    if game.story_safe:
        combat_freeze = 0
    elif combat_freeze > 0 and not dead:
        combat_freeze = maxf(0, combat_freeze - delta)
        queue_redraw()
        return
    _animation_clock += delta
    _hurt_timer = maxf(0.0, _hurt_timer - delta)
    _stagger_timer = maxf(0.0, _stagger_timer - delta)
    _recovery_timer = maxf(0.0, _recovery_timer - delta)
    if dead:
        velocity.x = move_toward(velocity.x, 0.0, delta * 500.0)
        animation_state = "dead"
    elif not _active or game.story_safe:
        velocity.x = 0.0
        animation_state = "idle"
    elif _stagger_timer > 0.0:
        velocity.x = move_toward(velocity.x, 0.0, delta * 1000.0)
        animation_state = "hurt"
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
        _try_melee_contact(50.0)
    elif _recovery_timer > 0.0:
        velocity.x = move_toward(velocity.x, 0.0, delta * 800.0)
        animation_state = "attack"
    else:
        var distance: float = game.player.global_position.x - global_position.x
        facing = 1 if distance >= 0.0 else -1
        # Pursuit keeps the fight mobile; a brief jump crosses player and arena platforms.
        velocity.x = facing * (85.0 if phase == "final" else 62.0) if absf(distance) > 54.0 else 0.0
        if is_on_wall() and is_on_floor():
            velocity.y = -290.0
        animation_state = "run" if absf(velocity.x) > 1.0 else "idle"
    if not is_on_floor():
        velocity.y = minf(velocity.y + 950.0 * delta, 650.0)
    move_and_slide()
    global_position.x = clampf(global_position.x, ARENA_LEFT, ARENA_RIGHT)
    if _hurt_timer > 0.0 and not dead:
        animation_state = "hurt"
    frame = int(_animation_clock * 12.0) % 6
    if is_instance_valid(game) and game.has_signal("animation_event") and (animation_state != _last_state or frame != _last_frame or facing != _last_facing):
        _last_state = animation_state
        _last_frame = frame
        _last_facing = facing
        game.emit_signal("animation_event", self, animation_state, frame, facing)
    queue_redraw()

func _release_attack() -> void:
    if dead or game.story_safe or _stagger_timer > 0.0:
        _pending_attack = ""
        return
    var source: Vector2 = global_position + Vector2(0, -26)
    var attack: String = _pending_attack
    _pending_attack = ""
    _recovery_timer = 0.24
    match attack:
        "slash":
            _try_melee_contact(78.0)
            game.emit_fx("enemy_slash", source + Vector2(facing * 20, 0), Vector2(facing, 0), 1.4)
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

func _try_melee_contact(reach: float) -> void:
    if _contact_resolved or game.story_safe or dead:
        return
    var difference: Vector2 = game.player.global_position + Vector2(0, -14) - (global_position + Vector2(0, -24))
    if absf(difference.x) > reach or absf(difference.y) > 43.0 or difference.x * facing < -22.0:
        return
    _contact_resolved = true
    if game.player.parry_timer > 0.0:
        game.player.parry_success(self)
        _stagger_timer = 0.7
        _charge_timer = 0.0
        _pending_attack = ""
        _windup_timer = 0.0
        velocity.x = -facing * 100.0
        receive_hit(3, game.player.global_position)
    else:
        game.damage_player(1, global_position)

func _die() -> void:
    if dead:
        return
    dead = true
    _active = false
    _pending_attack = ""
    _windup_timer = 0.0
    _charge_timer = 0.0
    game.music.stop_score()
    game.emit_fx("boss_defeat", global_position + Vector2(0, -28), Vector2.ZERO, 2.0)
    game.on_boss_defeated()

func _draw() -> void:
    Pixels.paint(self, "boss", animation_state, frame, facing)
    if _windup_timer > 0.0:
        var gold := Color("ffd779")
        var direction: int = facing
        for i: int in 5:
            draw_rect(Rect2(Vector2(direction * (26 + i * 6), -25), Vector2(3, 3)), gold)
        draw_rect(Rect2(-24, -65, 48, 2), Color("72554c"))
        var progress: float = 1.0 - _windup_timer / maxf(0.01, game.music.seconds_per_beat() * 0.8)
        draw_rect(Rect2(-24, -65, 48.0 * progress, 2), gold)

extends CharacterBody2D
## Bellkeeper: readable beat-led windups, pursuit, repositioning and projectile patterns.

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
    game.on_boss_phase(section)
    match section:
        "random":
            _request_phase_if_ready()
        "rest":
            game.announce("Breathe. Your name is gone; your hands still remember.", 4.0)
        "final":
            game.announce("The seal is open. Keep moving; turn its light against it.", 3.0)

func _on_beat(index: int) -> void:
    if dead or not _active or game.story_safe or _stagger_timer > 0.0 or _reaction_blocks_attacks or _posture_lockout > 0.0:
        return
    if _windup_timer > 0.0 or _charge_timer > 0.0 or _recovery_timer > 0.0 or _combo_pending:
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
        var final_patterns: Array[String] = ["armored_slash", "fan", "charge", "rain", "ring"]
        attack = final_patterns[_attack_count % final_patterns.size()]
    _last_pattern = attack
    _attack_count += 1
    _begin_attack(attack)

func _begin_attack(attack: String) -> void:
    if dead or game.story_safe or _reaction_blocks_attacks or _posture_lockout > 0.0:
        return
    attack_serial += 1
    contact_token = attack_serial * 8
    attack_parryable = attack in ["slash", "armored_slash"]
    # Armor and parryability are independent: the armored double cut can be
    # parried; the charging armor cannot. Neither changes projectile reflection.
    attack_armored = attack in ["armored_slash", "charge"]
    _combo_pending = false
    _combo_timer = 0.0
    _pending_attack = attack
    _windup_timer = game.music.seconds_per_beat() * 0.8
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
        if _hurt_timer > 0.0 and not dead:
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
            _cancel_all_attacks()
            velocity.x = -facing * 44.0
            _start_reaction("guard_break", GUARD_BREAK_TIME, true)
        elif armored:
            # Armor accepts the clash and posture, but retains the later contact.
            _start_reaction("parry_recoil", ARMORED_RECOIL_TIME, false)
        else:
            _cancel_all_attacks()
            velocity.x = -facing * 70.0
            _start_reaction("parry_recoil", NORMAL_RECOIL_TIME, true)
    else:
        game.damage_player(1, global_position)

func _cancel_all_attacks() -> void:
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

func _draw() -> void:
    Pixels.paint(self, "boss", animation_state, frame, facing)
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

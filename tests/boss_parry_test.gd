extends SceneTree
## Bounded contact/state tests only. No playthrough and no global time changes.
const Boss = preload("res://combat/boss.gd")
const Player = preload("res://actors/player.gd")
const Music = preload("res://audio/music_director.gd")

class ContactGame extends Node2D:
    signal warning_issued(kind: String, at: Vector2, duration: float)
    signal animation_event(actor: Node, state: String, frame: int, facing: int)
    var player: Node2D
    var boss: Node2D
    var music: Node
    var story_safe: bool = false
    var _paused: bool = false
    var contact_count: int = 0
    var damage_calls: int = 0
    var projectile_count: int = 0
    var kinds: Array[String] = []
    var warnings: Array[String] = []
    var fx: Array[String] = []
    func set_story_safe(value: bool) -> void:
        story_safe = value
    func announce(_text: String, _seconds: float = 3.0) -> void:
        pass
    func on_boss_phase(_phase: String) -> void:
        pass
    func on_boss_defeated() -> void:
        pass
    func emit_fx(kind: String, _at: Vector2, _direction: Vector2 = Vector2.ZERO, _power: float = 1.0) -> void:
        fx.append(kind)
    func damage_player(amount: int, origin: Vector2) -> void:
        damage_calls += 1
        player.receive_hit(amount, origin)
    func hero_attack(_source: Node2D, _damage: int, _reach: float, _combo: int) -> void:
        pass
    func spawn_projectile(_at: Vector2, _velocity: Vector2, _friendly: bool = false) -> Node2D:
        projectile_count += 1
        return null
    func on_parry_contact(defender: Node, source: Node, _at: Vector2, kind: String) -> void:
        contact_count += 1
        kinds.append(kind)
        defender.set_impact_freeze(0.06)
        source.set_impact_freeze(0.06)

var passed: int = 0
var failed: int = 0

func _initialize() -> void:
    call_deferred("run")

func check(value: bool, label: String) -> void:
    if value:
        passed += 1
        print("PASS ", label)
    else:
        failed += 1
        push_error("FAIL " + label)

func arm_player(game: ContactGame, direction: int = 1) -> void:
    game.player.revive(Vector2(2960, 300))
    game.player.invuln = 0.0
    game.player.facing = direction
    check(game.player._start_parry(), "fresh genuine player parry window opens")

func reset_contact(game: ContactGame) -> void:
    game.music.stop_score()
    game.story_safe = true
    game.boss._on_section("rest")
    game.story_safe = false
    game.boss._on_section("final")
    game.boss._recovery_timer = 0.0
    game.boss._hurt_timer = 0.0
    game.boss.health = game.boss.max_health
    game.boss.position = Vector2(3000, 300)
    game.boss.velocity = Vector2.ZERO
    game.boss._active = true
    game.boss.dead = false
    game.player.revive(Vector2(2960, 300))
    game.player.invuln = 0.0
    game.player.facing = 1

func run() -> void:
    for action: String in ["move_left", "move_right", "jump", "dash", "attack", "parry"]:
        if not InputMap.has_action(action):
            InputMap.add_action(action)
    var game := ContactGame.new()
    game.visible = false
    root.add_child(game)
    game.warning_issued.connect(func(kind: String, _at: Vector2, _duration: float) -> void: game.warnings.append(kind))
    var floor_body := StaticBody2D.new()
    floor_body.position = Vector2(3000, 310)
    var floor_shape := CollisionShape2D.new()
    var rectangle := RectangleShape2D.new()
    rectangle.size = Vector2(900, 20)
    floor_shape.shape = rectangle
    floor_body.add_child(floor_shape)
    game.add_child(floor_body)
    game.player = Player.new()
    game.player.configure(game)
    game.add_child(game.player)
    game.player.set_physics_process(false)
    game.music = Music.new()
    game.add_child(game.music)
    game.music.configure(game)
    game.music.set_process(false)
    game.boss = Boss.new()
    game.add_child(game.boss)
    game.boss.configure(game, Vector2(3000, 300))
    game.boss.set_physics_process(false)
    game.boss._active = true

    reset_contact(game)
    arm_player(game)
    game.player.parry_timer = 0.0
    var before: int = game.contact_count
    game.boss._begin_attack("slash")
    game.boss._release_attack()
    check(game.contact_count == before and game.boss.guard_posture == 0 and game.player.health == 7, "expired input window takes contact damage without posture reward")

    reset_contact(game)
    arm_player(game, -1)
    before = game.contact_count
    game.boss._begin_attack("slash")
    game.boss._release_attack()
    check(game.contact_count == before and game.boss.guard_posture == 0 and game.player.health == 7, "facing away rejects a rear weapon contact")

    reset_contact(game)
    arm_player(game)
    game.player.position.x = 2800
    before = game.contact_count
    game.boss._begin_attack("slash")
    game.boss._release_attack()
    check(game.contact_count == before and game.boss.guard_posture == 0 and game.player.health == 8, "out-of-reach press cannot create a fake parry")

    reset_contact(game)
    arm_player(game)
    before = game.contact_count
    var damage_before: int = game.damage_calls
    game.boss._begin_attack("slash")
    var serial: int = game.boss.attack_serial
    var token: int = game.boss.contact_token
    game.boss._release_attack()
    check(game.contact_count == before + 1 and game.boss.guard_posture == 1 and game.player.health == 8, "ordinary real slash contact awards one posture pip and prevents its damage")
    check(game.boss.reaction_state == "parry_recoil" and game.boss._reaction_blocks_attacks, "ordinary parry starts interrupting weapon recoil")
    check(game.boss._pending_attack.is_empty() and game.boss._windup_timer == 0.0 and game.boss._charge_timer == 0.0 and not game.boss._combo_pending, "ordinary parry cancels every delayed damage path")
    check(absf(game.boss.velocity.x) <= 70.0 and game.boss.velocity.y == 0.0, "ordinary recoil is a small backward step without launch")
    game.boss._release_attack()
    game.boss._release_combo_contact()
    check(game.damage_calls == damage_before, "canceled ordinary attack cannot leave delayed damage")
    game.boss._advance_reaction(0.12)
    check(game.boss.reaction_state == "parry_recover" and game.boss.reaction_progress >= 0.0 and game.boss.reaction_progress <= 1.0, "ordinary recoil transitions to its own normalized recovery stage")
    game.boss._advance_reaction(0.12)
    check(game.boss.reaction_state == "none", "ordinary recoil and recovery finish in 240ms")
    arm_player(game)
    game.boss._contact_resolved = false
    for _i: int in 5:
        game.boss._try_melee_contact(78.0, true, false, token)
    check(game.contact_count == before + 1 and game.boss.guard_posture == 1 and game.boss.attack_serial == serial, "same Boss token cannot be farmed even in a fresh defender window")

    reset_contact(game)
    arm_player(game)
    game.boss._begin_attack("charge")
    check(not game.boss.attack_parryable and game.boss.attack_armored and game.warnings.back() == "unblockable_charge", "charge armor is explicitly unparryable and issues the coral warning kind")
    before = game.contact_count
    game.boss._release_attack()
    game.boss._physics_process(0.01)
    check(game.contact_count == before and game.boss.guard_posture == 0 and game.player.health == 7, "genuine charge contact cannot be parried")

    reset_contact(game)
    arm_player(game)
    before = game.contact_count
    game.boss._begin_attack("armored_slash")
    check(game.boss.attack_parryable and game.boss.attack_armored, "armored slash separates armor from parryability")
    serial = game.boss.attack_serial
    token = game.boss.contact_token
    game.boss._release_attack()
    check(game.contact_count == before + 1 and game.boss.guard_posture == 1 and game.boss._combo_pending, "first armored parry prevents that contact and retains later combo")
    check(game.boss.reaction_state == "parry_recoil" and not game.boss._reaction_blocks_attacks, "non-breaking armored parry shows recoil without locking the combo")
    game.boss._contact_resolved = false
    game.boss._try_melee_contact(78.0, true, true, token)
    check(game.contact_count == before + 1 and game.boss.guard_posture == 1, "duplicate armored contact cannot add posture twice")
    game.player._clear_parry()
    game.player.invuln = 0.0
    game.boss.combat_freeze = 0.0
    game.boss._physics_process(game.boss.ARMORED_CHAIN_GAP)
    check(game.boss.attack_serial == serial and game.boss.contact_token != token and not game.boss._combo_pending, "armored follow-up uses a second unique contact under the same attack")
    check(game.player.health == 7 and game.contact_count == before + 1, "parrying first armored cut does not erase the second cut damage")

    reset_contact(game)
    arm_player(game)
    before = game.contact_count
    game.boss._begin_attack("armored_slash")
    game.boss._release_attack()
    game.boss.combat_freeze = 0.0
    game.boss._advance_reaction(0.12)
    arm_player(game)
    game.boss._release_combo_contact()
    check(game.contact_count == before + 2 and game.boss.guard_posture == 2 and game.boss.reaction_state != "guard_break", "distinct armored segments can each add one posture pip")
    game.boss.combat_freeze = 0.0
    game.boss._advance_reaction(0.12)
    game.boss._recovery_timer = 0.0
    arm_player(game)
    game.boss._begin_attack("armored_slash")
    game.boss._release_attack()
    check(game.boss.guard_posture == game.boss.guard_max and game.boss.reaction_state == "guard_break" and game.kinds.back() == "guard_break", "third accepted contact determines break feedback before the reward callback")
    check(not game.boss._combo_pending and game.boss._pending_attack.is_empty() and game.boss._charge_timer == 0.0, "guard break forcibly cancels all armored follow-ups")
    serial = game.boss.attack_serial
    before = game.contact_count
    game.boss._on_beat(100)
    game.boss._begin_attack("fan")
    game.boss._release_combo_contact()
    check(game.boss.attack_serial == serial and game.contact_count == before, "broken guard cannot start attacks or award repeated parries")
    var hp: int = game.boss.health
    game.boss._hurt_timer = 0.0
    game.boss.receive_hit(2, game.player.global_position)
    game.boss.combat_freeze = 0.0
    game.boss._physics_process(0.0)
    check(game.boss.health == hp - 2 and game.boss.animation_state == "guard_break" and game.boss.impact_flash == 0.0, "counter-hit deals damage without replacing guard-break pose with hit flash")
    game.boss._advance_reaction(0.45)
    check(is_equal_approx(game.boss.reaction_progress, 0.5), "guard-break motion progress follows the actual reaction clock")
    game.boss._advance_reaction(0.45)
    check(game.boss.reaction_state == "guard_recover" and game.boss.guard_posture == 0 and game.boss._posture_lockout > 0.0, "900ms break opens recovery and safely clears accumulated posture")
    game.boss._advance_reaction(0.18)
    game.boss._begin_attack("slash")
    check(game.boss.reaction_state == "none" and game.boss.attack_serial == serial, "posture reset lockout prevents an immediate reward loop after recovery")
    game.boss._physics_process(game.boss.POSTURE_RESET_LOCK + 0.01)
    arm_player(game)
    game.boss._begin_attack("slash")
    game.boss._release_attack()
    check(game.boss.guard_posture == 1 and game.boss.reaction_state == "parry_recoil", "next valid attack starts a fresh posture cycle after lockout")

    reset_contact(game)
    game.boss._begin_attack("armored_slash")
    game.boss._combo_pending = true
    game.boss._combo_timer = 0.1
    game.boss.guard_posture = 2
    game.boss._start_reaction("guard_break", 0.9, true)
    game.boss.combat_freeze = 0.07
    game.boss._charge_timer = 0.2
    game.story_safe = true
    game.boss._on_section("rest")
    before = game.contact_count
    damage_before = game.damage_calls
    game.boss._release_attack()
    game.boss._release_combo_contact()
    game.boss._try_melee_contact(78.0)
    check(game.boss.guard_posture == 0 and game.boss.reaction_state == "none" and game.boss.combat_freeze == 0.0 and not game.boss._combo_pending, "rest clears old posture, reactions, local hold and armored combo")
    check(game.boss._pending_attack.is_empty() and game.boss._charge_timer == 0.0 and game.contact_count == before and game.damage_calls == damage_before, "rest rejects every old contact and delayed release")

    reset_contact(game)
    game.music.start_score()
    game.boss.set_impact_freeze(0.07)
    game.boss._start_reaction("guard_break", 0.9, true)
    game.boss._physics_process(0.01)
    game.music._process(game.music.seconds_per_beat() * 1.1)
    check(game.music.total_beats == 1 and is_equal_approx(Engine.time_scale, 1.0) and not paused, "music beat clock advances during actor-local parry hold")
    check(game.boss.reaction_progress == 0.0, "local hold freezes the physical reaction pose only")
    game.music.stop_score()

    reset_contact(game)
    game.boss._on_section("fixed")
    game.boss._recovery_timer = 0.0
    serial = game.boss.attack_serial
    game.boss._physics_process(0.01)
    game.boss._on_beat(3)
    check(game.boss.attack_serial == serial, "free pursuit and off-beat signals never begin a new fixed attack")
    game.boss._on_beat(4)
    check(game.boss.attack_serial == serial + 1 and game.boss._windup_timer > 0.0, "new fixed attack windup still starts on the musical beat")
    game.music.stop_score()
    game.queue_free()
    await process_frame
    print("Boss parry: %d passed, %d failed" % [passed, failed])
    quit(1 if failed > 0 else 0)

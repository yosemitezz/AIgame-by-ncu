extends SceneTree
## Real raw key edges and bounded physics fixtures; physical Shift mapping is covered by the root's separate test.
const Player = preload("res://actors/player.gd")
const Tracker = preload("res://combat/double_tap_tracker.gd")
const KEYS: Dictionary = {"move_left": KEY_A, "move_right": KEY_D, "climb_up": KEY_W, "climb_down": KEY_S}
var passed: int = 0
var failed: int = 0
var player: CharacterBody2D
var arena: FixtureGame
var level: FixtureLevel
var finished: bool = false

class FixtureLevel extends Node:
    var chain: bool = false
    func climb_at(feet: Vector2) -> Dictionary:
        var rect: Rect2 = Rect2(-12.0, 100.0, 24.0, 200.0)
        return {"rect": rect, "kind": "chain", "id": "input_chain"} if chain and rect.grow(0.01).has_point(feet) else {}
    func water_at(_feet: Vector2) -> bool:
        return false

class FixtureGame extends Node2D:
    signal animation_event(actor: Node, state: String, frame: int, facing: int)
    var story_safe: bool = false
    var _paused: bool = false
    var level: Node
    var effects: Dictionary = {}
    var parries: int = 0
    func hero_attack(_source: Node2D, _damage: int, _reach: float, _combo: int) -> void:
        pass
    func emit_fx(kind: String, _at: Vector2, _direction: Vector2, _power: float) -> void:
        effects[kind] = int(effects.get(kind, 0)) + 1
    func on_parry_contact(_defender: Node, _source: Node, _at: Vector2, _kind: String) -> void:
        parries += 1

func check(ok: bool, label: String) -> void:
    if ok:
        passed += 1
        print("PASS ", label)
    else:
        failed += 1
        push_error("FAIL " + label + " [pos=%s v=%s dash=%.3f dir=%s inv=%.3f phase=%s]" % [player.global_position, player.velocity, player.dash_timer, player.dash_direction, player.invuln, player.attack_phase] if is_instance_valid(player) else "FAIL " + label)

func raw(action: String, pressed: bool, echo: bool = false) -> void:
    raw_key(KEYS[action], pressed, echo)

func raw_key(code: int, pressed: bool, echo: bool = false) -> void:
    var event: InputEventKey = InputEventKey.new()
    event.physical_keycode = code
    event.keycode = code
    event.pressed = pressed
    event.echo = echo
    Input.parse_input_event(event)
    # Synthetic events are buffered; dispatch them before manual physics sampling.
    Input.flush_buffered_events()

func release_all() -> void:
    for action: String in KEYS:
        raw(action, false)
    raw_key(KEY_LEFT, false)
    raw_key(KEY_UP, false)
    for action: String in ["attack", "parry", "jump", "dash", "crouch"]:
        Input.action_release(action)

func reset(at: Vector2 = Vector2(0.0, 200.0)) -> void:
    release_all()
    arena.story_safe = false
    arena._paused = false
    level.chain = false
    player.revive(at)
    player.invuln = 0.0
    player.facing = 1
    arena.effects.clear()

func tick(count: int = 1) -> void:
    for index: int in range(count):
        await physics_frame
        player._physics_process(1.0 / 60.0)

func double_tap(action: String) -> void:
    raw(action, true)
    raw(action, false)
    await tick()
    raw(action, true)
    await tick()
    raw(action, false)

func body(at: Vector2, size: Vector2, one_way: bool = false) -> void:
    var obstacle: StaticBody2D = StaticBody2D.new()
    var collider: CollisionShape2D = CollisionShape2D.new()
    var shape: RectangleShape2D = RectangleShape2D.new()
    shape.size = size
    collider.shape = shape
    collider.one_way_collision = one_way
    obstacle.position = at
    obstacle.add_child(collider)
    arena.add_child(obstacle)

func _initialize() -> void:
    call_deferred("run")

func run() -> void:
    var watchdog: SceneTreeTimer = create_timer(15.0)
    watchdog.timeout.connect(func() -> void:
        if not finished:
            push_error("FAIL friend-controls bounded fixture timeout")
            quit(1))
    for action: String in ["move_left", "move_right", "climb_up", "climb_down", "attack", "parry", "jump", "dash", "crouch"]:
        if not InputMap.has_action(action):
            InputMap.add_action(action)
        if KEYS.has(action):
            var event: InputEventKey = InputEventKey.new()
            event.physical_keycode = KEYS[action]
            InputMap.action_add_event(action, event)
    for alias_action: String in ["move_left", "climb_up"]:
        var alias_event: InputEventKey = InputEventKey.new()
        alias_event.physical_keycode = KEY_LEFT if alias_action == "move_left" else KEY_UP
        InputMap.action_add_event(alias_action, alias_event)
    arena = FixtureGame.new()
    root.add_child(arena)
    level = FixtureLevel.new()
    arena.add_child(level)
    arena.level = level
    body(Vector2(0.0, 312.0), Vector2(3000.0, 24.0))
    body(Vector2(106.0, 200.0), Vector2(12.0, 200.0))
    body(Vector2(300.0, 225.0), Vector2(100.0, 10.0), true)
    body(Vector2(600.0, 85.0), Vector2(100.0, 10.0))
    player = Player.new()
    player.configure(arena)
    arena.add_child(player)
    player.set_physics_process(false)
    reset()
    await tick()
    var tracker: RefCounted = Tracker.new(0.25)
    check(not tracker.register_press(&"left", 0.0) and not tracker.register_press(&"right", 0.1) and tracker.register_press(&"left", 0.25), "source tracker keeps direction histories independent and includes .25 boundary")
    check(not tracker.register_press(&"right", 0.351), "source tracker rejects a pair beyond .25")
    tracker.reset()
    check(not tracker.register_press(&"left", 0.4), "source reset clears previous tap candidates")
    reset()
    raw("move_right", true)
    await tick()
    for repeat_index: int in range(6):
        raw("move_right", true, true)
        await tick()
    check(player.dash_timer == 0.0 and int(arena.effects.get("dash_start", 0)) == 0, "held direction and OS echo never become a second tap")
    raw("move_right", false)
    await tick()
    raw("move_right", true)
    await tick()
    check(player.dash_timer > 0.0 and int(arena.effects.get("dash_start", 0)) == 1, "release then a real second press starts exactly one dash")
    for action: String in ["move_left", "climb_up"]:
        reset()
        var alias_code: int = KEY_LEFT if action == "move_left" else KEY_UP
        raw(action, true)
        await tick()
        raw_key(alias_code, true)
        await tick()
        check(player.dash_timer == 0.0 and int(arena.effects.get("dash_start", 0)) == 0, "held direction plus physical alias is not a double tap: " + action)
        raw(action, false)
        await tick()
        raw(action, true)
        await tick()
        check(player.dash_timer == 0.0, "repressing one key while alias remains held is not a fresh direction edge: " + action)
        raw(action, false)
        raw_key(alias_code, false)
        await tick()
        raw(action, true)
        await tick()
        check(player.dash_timer > 0.0 and player.dash_direction == Player.DIRECTION_TAPS[action], "whole-direction release then repress completes its genuine pair: " + action)
    for action: String in KEYS:
        reset()
        await double_tap(action)
        check(player.dash_timer > 0.0 and player.dash_direction == Player.DIRECTION_TAPS[action], "raw double tap starts cardinal " + action)
        check(player.velocity.is_equal_approx(Player.DIRECTION_TAPS[action] * 420.0), "cardinal direction has original side-view speed " + action)
    reset()
    # Both real press edges occur before any physics sampling, while the key ends held.
    raw("move_left", true)
    raw("move_left", false)
    raw("move_left", true)
    await tick()
    check(player.dash_timer > 0.0 and player.dash_direction == Vector2.LEFT, "release-repress between physics samples cannot lose the second edge")
    reset()
    raw("move_left", true)
    raw("move_left", false)
    await tick()
    raw("move_left", true)
    raw("move_left", false)
    await tick()
    check(player.dash_timer > 0.0 and player.dash_direction == Vector2.LEFT, "complete press-release taps ending between samples are both recorded")
    reset()
    raw("move_left", true)
    raw("move_left", false)
    raw("move_right", true)
    raw("move_right", false)
    raw("move_left", true)
    await tick()
    check(player.dash_direction == Vector2.LEFT and player.dash_timer > 0.0, "interleaved A-D-A preserves the independent A history")
    reset()
    check(player._start_dash(0.0, Vector2.UP), "source dash timing fixture starts")
    check(is_equal_approx(player.dash_timer, 0.17) and is_equal_approx(player.invuln, 0.23) and is_equal_approx(player._dash_cooldowns[Vector2.UP], 0.42), "movement .17, immunity .23 and per-axis cooldown .42 match source")
    var inv_before: float = player.invuln
    check(not player._start_dash(1.0, Vector2.RIGHT) and player.dash_direction == Vector2.UP and player.invuln == inv_before, "active dodge cannot cancel into another direction or refresh immunity")
    await tick(12)
    check(player.dash_timer == 0.0 and not player._start_dash(0.0, Vector2.UP), "same-direction cooldown outlasts its movement")
    check(player._start_dash(1.0, Vector2.RIGHT), "different direction is available after active movement ends")
    check(player._dash_cooldowns[Vector2.UP] > 0.0 and player._dash_cooldowns[Vector2.RIGHT] >= 0.419, "new direction does not overwrite another direction cooldown")
    reset()
    player._start_dash(1.0, Vector2.RIGHT)
    await tick(11)
    check(player.dash_timer == 0.0 and player.invuln > 0.0 and player.invuln <= 0.061, "source immunity retains its short tail after movement")
    var hp: int = player.health
    check(not player.receive_hit(1, Vector2(-20.0, 200.0)) and player.health == hp, "actual damage is rejected during immunity tail")
    await tick(4)
    check(player.invuln == 0.0 and player.receive_hit(1, Vector2(-20.0, 200.0)) and player.health == hp - 1, "actual damage resumes after source immunity expires")
    reset()
    raw("move_right", true)
    raw("move_right", false)
    await tick(17)
    raw("move_right", true)
    await tick()
    check(player.dash_timer == 0.0, "pausable physics time expires a tap beyond .25 seconds")
    for mode: String in ["explicit_pause_reset", "paused", "rest", "death", "revive"]:
        reset()
        raw("move_right", true)
        raw("move_right", false)
        await tick()
        match mode:
            "explicit_pause_reset": player.reset_direction_taps()
            "paused":
                arena._paused = true
                player._physics_process(0.1)
                arena._paused = false
            "rest":
                arena.story_safe = true
                player._physics_process(0.0)
                arena.story_safe = false
            "death":
                player.receive_hit(99, Vector2(-20.0, 200.0))
                player.revive(Vector2(0.0, 200.0))
                player.invuln = 0.0
            "revive":
                player.revive(Vector2(0.0, 200.0))
                player.invuln = 0.0
        raw("move_right", true)
        await tick()
        check(player.dash_timer == 0.0 and player._dash_buffer == 0.0, "tap candidates clear on " + mode)
    reset()
    player.set_impact_freeze(0.08)
    raw("move_right", true)
    raw("move_right", false)
    raw("move_right", true)
    var held_at: Vector2 = player.global_position
    await tick(2)
    check(player.combat_freeze > 0.0 and player._dash_buffer > 0.0 and player.global_position.is_equal_approx(held_at), "raw double tap is buffered during local hold without moving")
    await tick(5)
    check(player.dash_timer > 0.0 and player.dash_direction == Vector2.RIGHT, "hit-stop releases the same buffered direction into dash authority")
    reset()
    player._start_attack()
    raw("move_right", true)
    raw("move_right", false)
    raw("move_right", true)
    await tick()
    check(player.attack_phase == "windup" and player.dash_timer == 0.0 and player._dash_buffer > 0.0, "double tap cannot bypass attack windup commitment")
    player._advance_attack(Player.COMBO_WINDUP[0] + 0.01)
    check(not player._start_dash(1.0, Vector2.RIGHT), "unconfirmed active swing still rejects a dodge cancel")
    player.confirm_attack_hit()
    player._advance_attack(Player.CONFIRM_CANCEL_DELAY)
    check(player._start_dash(1.0, Vector2.RIGHT), "confirmed active window keeps the existing dodge cancel")
    reset(Vector2(0.0, 220.0))
    level.chain = true
    raw("climb_up", true)
    await tick()
    check(player.climbing and player.dash_timer == 0.0, "single W still grips and climbs")
    raw("climb_up", false)
    raw("climb_up", true)
    await tick()
    check(not player.climbing and player.dash_direction == Vector2.UP and player.velocity.y < -419.0, "second W detaches the chain into upward dodge")
    reset(Vector2(0.0, 300.0))
    await tick(3)
    raw("climb_down", true)
    await tick()
    check(player.crouching and player.dash_timer == 0.0, "single S retains grounded crouch")
    raw("climb_down", false)
    raw("climb_down", true)
    await tick(2)
    check(player.dash_direction == Vector2.DOWN and player.dash_timer > 0.0 and player.global_position.y <= 300.5, "downward dodge respects solid ground")
    reset(Vector2(300.0, 210.0))
    await tick(12)
    await double_tap("climb_down")
    await tick(2)
    check(player.dash_direction == Vector2.DOWN and player.global_position.y <= 220.5 and player.global_position.y >= 219.0, "downward dodge cannot drop through a one-way platform")
    reset(Vector2(600.0, 120.0))
    await double_tap("climb_up")
    await tick(3)
    check(player.global_position.y >= 115.5 and player.collision_mask == 1, "upward dodge collides with ceiling without disabling mask")
    reset(Vector2(80.0, 300.0))
    await tick(2)
    await double_tap("move_right")
    await tick(3)
    check(player.global_position.x <= 93.1 and player.collision_mask == 1, "horizontal dodge cannot teleport through a wall")
    reset()
    check(player._start_parry(), "logical parry still opens the original contact controller")
    var foe: Node2D = Node2D.new()
    foe.position = player.position + Vector2(24.0, 0.0)
    arena.add_child(foe)
    check(player.parry_success(foe, player.position + Vector2(12.0, -18.0), "melee", 1) and arena.parries == 1, "new input retains the single real contact parry callback")
    check(Engine.time_scale == 1.0 and Player.INFINITE_AIR_JUMPS, "new controls preserve global time and infinite air jumps")
    release_all()
    arena.free()
    finished = true
    print("FRIEND_CONTROLS_TEST: %d passed, %d failed" % [passed, failed])
    quit(1 if failed > 0 else 0)

extends SceneTree
## Bounded real-scene collision/ownership/lifetime fixtures, no playthrough.
var passed: int = 0
var failed: int = 0
var game: Node
class Dummy extends Node2D:
    var health: int = 100
    var dead: bool = false
    var calls: int = 0
    func receive_hit(amount: int, _origin: Vector2) -> void:
        health -= amount
        calls += 1
    func react(_kind: String, _origin: Vector2) -> void: pass
    func set_impact_freeze(_seconds: float) -> void: pass
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
    if ok: passed += 1; print("PASS ", label)
    else: failed += 1; push_error("FAIL " + label)
func dummy_at(at: Vector2) -> Dummy:
    var target: Dummy = Dummy.new()
    game.add_child(target)
    target.global_position = at
    target.add_to_group("enemies")
    return target
func prepare(at: Vector2) -> void:
    game.set_story_safe(false)
    game.outcome = ""
    game.player.dead = false
    game.player._cancel_attack()
    game.player.combat_freeze = 0.0
    game.player.set_weapon("heavy")
    game.player.global_position = at
    game.player.facing = 1
    game.player.combo = 3
    game.player.attack_phase = "active"
    game.player.attack_serial += 1
func cast() -> Node2D:
    var wave: Node2D = game.spawn_sword_wave(game.player, game.player.attack_serial)
    if is_instance_valid(wave): wave.set_physics_process(false)
    return wave
func clear_waves() -> void:
    game.clear_sword_waves()
func run() -> void:
    game = load("res://main.tscn").instantiate()
    root.add_child(game)
    current_scene = game
    await process_frame
    game.set_process(false)
    game.set_physics_process(false)
    game.player.set_physics_process(false)
    game.music.set_process(false)
    for actor: Node in get_nodes_in_group("enemies"): actor.set_physics_process(false)
    var origin: Vector2 = Vector2(5000, 200)
    prepare(origin)
    var target: Dummy = dummy_at(origin + Vector2(50, 0))
    var impact_before: int = game.impact.impact_count
    var wave: Node2D = cast()
    check(is_instance_valid(wave) and wave.damage == 2 and wave.weapon == "heavy", "heavy finisher casts independently owned damaging wave")
    check(game.spawn_sword_wave(game.player, game.player.attack_serial) == null, "one attack serial cannot emit twice")
    check(game.impact.impact_count == impact_before, "release into air creates no impact/shake")
    game.player._cancel_attack()
    game.player.set_weapon("light")
    wave._physics_process(0.10)
    wave._physics_process(0.02)
    check(target.calls == 1 and target.health == 98, "swept wave hits each target once across overlapping frames")
    check(wave.damage == 2 and wave.weapon == "heavy", "later equipment change cannot alter released wave")
    check(game.impact.impact_count == impact_before + 1, "confirmed wave contact owns exactly one impact bundle")
    check(is_equal_approx(game.player.combat_freeze, 0.0), "remote energy impact does not freeze current player attack")
    check(is_equal_approx(Engine.time_scale, 1.0) and not paused, "wave never modifies music/global time")
    clear_waves()
    target.free()
    for hz: int in [15,30,60,144]:
        prepare(origin)
        target = dummy_at(origin + Vector2(125, 0))
        wave = cast()
        for step: int in int(ceil(0.40 * hz)):
            if is_instance_valid(wave) and not wave._cleared: wave._physics_process(1.0 / hz)
        check(target.calls == 1 and target.health == 98, "wave collision is single-hit at %dHz" % hz)
        clear_waves()
        target.free()
        await process_frame
    prepare(origin)
    var wall: StaticBody2D = StaticBody2D.new()
    var collider: CollisionShape2D = CollisionShape2D.new()
    var wall_shape: RectangleShape2D = RectangleShape2D.new()
    wall_shape.size = Vector2(8, 120)
    collider.shape = wall_shape
    wall.add_child(collider)
    wall.collision_layer = 1
    game.add_child(wall)
    wall.position = origin + Vector2(80, -30)
    target = dummy_at(origin + Vector2(110, 0))
    await physics_frame
    wave = cast()
    wave._physics_process(0.25)
    check(wave._cleared and target.calls == 0, "body-swept wall blocks wave and enemy behind wall even on a long frame")
    target.free()
    wall.free()
    await physics_frame
    prepare(origin)
    var shot_count: int = get_nodes_in_group("projectiles").size()
    for index: int in 3:
        game.player.attack_serial += 1
        cast()
    game.player.attack_serial += 1
    check(cast() == null and get_nodes_in_group("hero_waves").size() == 3, "independent live wave budget is bounded")
    check(get_nodes_in_group("projectiles").size() == shot_count, "waves cannot evict or consume friend-chart shots")
    clear_waves()
    await process_frame
    prepare(origin)
    wave = cast()
    var previous: Vector2 = wave.global_position
    paused = true
    wave._physics_process(0.30)
    check(wave.age == 0.0 and wave.global_position == previous, "pause freezes wave lifetime and motion")
    paused = false
    game.set_story_safe(true)
    check(wave._cleared and get_nodes_in_group("hero_waves").is_empty(), "narrative rest immediately clears energy")
    check(cast() == null, "safe section forbids a new energy release")
    await process_frame
    prepare(origin)
    wave = cast()
    game.player.dead = true
    wave._physics_process(0.01)
    check(wave._cleared, "owner death clears pending wave without damage")
    await process_frame
    prepare(origin)
    wave = cast()
    game._mount_room("boss")
    check(wave._cleared and get_nodes_in_group("hero_waves").is_empty(), "room transport removes outgoing wave before encounter prepares")
    await process_frame
    prepare(Vector2(2850, 300))
    wave = cast()
    wave._physics_process(0.80)
    check(wave._cleared and wave.age <= wave.lifetime + 0.000001, "wave lifetime is bounded on a long frame")
    game.set_story_safe(true)
    game.queue_free()
    await process_frame
    print("Sword wave: %d passed, %d failed" % [passed,failed])
    quit(1 if failed else 0)
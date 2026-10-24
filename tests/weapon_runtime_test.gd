extends SceneTree
## Actual root hit authority and weapon-specific impact contracts, not playtesting.
const Profile = preload("res://combat/attack_profile.gd")
var passed: int = 0
var failed: int = 0
var game: Node
class Dummy extends Node2D:
    var health: int = 100
    var dead: bool = false
    var calls: int = 0
    var combat_freeze: float = 0.0
    func receive_hit(amount: int, _origin: Vector2) -> void:
        health -= amount
        calls += 1
    func react(_kind: String, _origin: Vector2) -> void: pass
    func set_impact_freeze(seconds: float) -> void: combat_freeze = maxf(combat_freeze,seconds)
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
    if ok: passed += 1; print("PASS ",label)
    else: failed += 1; push_error("FAIL " + label)
func at(point: Vector2) -> Dummy:
    var target: Dummy = Dummy.new()
    game.add_child(target)
    target.global_position = point
    target.add_to_group("enemies")
    return target
func attack(weapon: String, combo: int, position: Vector2) -> void:
    game.player._cancel_attack()
    game.player.combat_freeze = 0.0
    game.player.set_weapon(weapon)
    game.player.global_position = position
    game.player.facing = 1
    game.player.combo = combo
    game.player.attack_phase = "active"
    game.player.attack_serial += 1
    game.player.attack_sweep_from = Profile.contact_start()
    game.player.attack_sweep_to = 1.0
    game.player.attack_previous_position = position
    game.impact.clear()
func run() -> void:
    game = load("res://main.tscn").instantiate()
    root.add_child(game)
    current_scene = game
    await process_frame
    game.set_process(false)
    game.set_physics_process(false)
    game.music.set_process(false)
    game.player.set_physics_process(false)
    for actor: Node in get_nodes_in_group("enemies"): actor.set_physics_process(false)
    var origin: Vector2 = Vector2(5000,200)
    var holds: Array[float] = []
    for wid: String in ["light","heavy","great"]:
        var front: Dummy = at(origin+Vector2(60,0))
        var back: Dummy = at(origin+Vector2(-60,0))
        attack(wid,1,origin)
        var impact_before: int = game.impact.impact_count
        for frame: int in 8:
            game.hero_attack(game.player,Profile.damage(1),Profile.radii(1).x,1)
        check(front.calls == 1 and front.health == 100-Profile.damage(1), "%s actual melee authority damages forward target only once per attack" % wid)
        check(back.calls == (1 if wid == "great" else 0), "%s rear contact follows actual weapon mode" % wid)
        check(game.impact.impact_count == impact_before+(2 if wid == "great" else 1), "%s exactly one impact per accepted target" % wid)
        holds.append(game.player.combat_freeze)
        check(not paused and is_equal_approx(Engine.time_scale,1.0), "%s actor hold never changes global music clock" % wid)
        front.free()
        back.free()
        attack(wid,1,origin)
        impact_before = game.impact.impact_count
        game.hero_attack(game.player,Profile.damage(1),Profile.radii(1).x,1)
        check(game.impact.impact_count == impact_before and game.player.combat_freeze == 0.0 and game.impact._kick == Vector2.ZERO, "%s whiff produces no shake or hitstop" % wid)
    check(holds[0] < holds[1] and holds[1] < holds[2] and holds[2] <= 0.12, "three weapons have distinct bounded confirmed-hit holds %.3f/%.3f/%.3f" % holds)
    attack("light",3,origin)
    var passed_target: Dummy = at(origin+Vector2(20,0))
    game.player.global_position += Vector2(140,0)
    game.player.attack_previous_position = origin
    for frame: int in 8: game.hero_attack(game.player,Profile.damage(3),Profile.radii(3).x,3)
    check(passed_target.calls == 1, "drill hits passed target through actual translated sweep once")
    check(game.player._lunge_timer == 0.0 or game.player._recoil_time == 0.0, "drill confirmation does not force a backwards recoil")
    passed_target.free()
    for hz: int in [15,30,60,144]:
        attack("light",3,origin)
        var near: Dummy = at(origin+Vector2(70,0))
        var far: Dummy = at(origin+Vector2(210,0))
        var last: Vector2 = origin
        for tick: int in int(ceil(0.32 * hz)):
            var progress: float = minf(1.0, float(tick+1)/(0.32*hz))
            game.player.global_position = origin+Vector2(177.7*progress,0)
            game.player.attack_previous_position = last
            game.player.attack_sweep_from = maxf(Profile.contact_start(),progress-1.0/(0.32*hz))
            game.player.attack_sweep_to = maxf(Profile.contact_start(),progress)
            game.hero_attack(game.player,Profile.damage(3),Profile.radii(3).x,3)
            last = game.player.global_position
        check(near.calls == 1 and far.calls == 1, "drill actual damage stays once per target at %dHz" % hz)
        near.free()
        far.free()
    attack("great",2,origin)
    var back_repeat: Dummy = at(origin+Vector2(-70,0))
    game.hero_attack(game.player,Profile.damage(2),Profile.radii(2).x,2)
    game.hero_attack(game.player,Profile.damage(2),Profile.radii(2).x,2)
    check(back_repeat.calls == 1, "circular full sweep never repeats damage during same spin")
    game.player.attack_serial += 1
    game.hero_attack(game.player,Profile.damage(2),Profile.radii(2).x,2)
    check(back_repeat.calls == 2, "a new circular strike can damage the rear target again")
    back_repeat.free()
    attack("great",2,origin)
    var far_target: Dummy = at(origin+Vector2(-Profile.radii(2).x-12,0))
    game.hero_attack(game.player,Profile.damage(2),Profile.radii(2).x,2)
    check(far_target.calls == 0, "roundcut respects its rear radius instead of infinite back hit")
    far_target.free()
    attack("heavy",1,origin)
    var target: Dummy = at(origin+Vector2(60,0))
    var health_before: int = target.health
    game._paused = true
    game.hero_attack(game.player,Profile.damage(1),Profile.radii(1).x,1)
    game._paused = false
    check(target.health == health_before, "pause rejects manual late contact")
    game.set_story_safe(true)
    game.hero_attack(game.player,Profile.damage(1),Profile.radii(1).x,1)
    check(target.health == health_before, "narrative safety rejects all three-weapon contact")
    target.free()
    game.queue_free()
    await process_frame
    print("Weapon runtime: %d passed, %d failed" % [passed,failed])
    quit(1 if failed else 0)
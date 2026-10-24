extends SceneTree
## Bounded FSM/geometry fixtures; no input playback or level playthrough.
const Enemy = preload("res://actors/enemy.gd")
const Level = preload("res://levels/bellkeep.gd")
var passed: int = 0
var failed: int = 0
var game: CastGame
var actors: Array[Node] = []
class Hero extends Node2D:
    var dead: bool = false
    var facing: int = -1
    var health: int = 8
    var guarded: bool = false
    var parries: int = 0
    func parry_success(_source: Node,_at: Vector2,_kind: String,_token: int) -> bool:
        parries += 1
        return guarded
class Terrain extends Node:
    func room_at(at: Vector2) -> Dictionary:
        if at.y > 400: return {"id":"crypt"}
        if at.y < 100: return {"id":"archive"}
        return {}
class Shot extends Node2D:
    var friendly: bool = false
    var lifetime: float = 6.0
    var velocity: Vector2
    var style: String
    var cleared: bool = false
    func _ready() -> void: add_to_group("projectiles")
    func clear() -> void:
        cleared = true
        remove_from_group("projectiles")
        queue_free()
class CastGame extends Node2D:
    signal animation_event(actor: Node,state: String,frame: int,facing: int)
    signal warning_issued(kind: String,at: Vector2,duration: float)
    var player: Hero
    var level: Terrain
    var story_safe: bool = false
    var _paused: bool = false
    var outcome: String = ""
    var reject: bool = false
    var attempts: int = 0
    var damage: int = 0
    var deaths: int = 0
    var shots: Array[Dictionary] = []
    func emit_fx(_kind: String,_at: Vector2,_direction: Vector2,_power: float) -> void: pass
    func on_enemy_defeated(_who: Node) -> void: deaths += 1
    func damage_player(amount: int,_origin: Vector2) -> void:
        damage += 1
        player.health -= amount
    func spawn_projectile(at: Vector2,motion: Vector2,friendly: bool=false,style: String="default") -> Node2D:
        attempts += 1
        if reject or get_tree().get_nodes_in_group("projectiles").size() >= 180: return null
        var shot: Shot = Shot.new()
        shot.position = at
        shot.velocity = motion
        shot.friendly = friendly
        shot.style = style
        add_child(shot)
        shots.append({"at":at,"motion":motion,"style":style,"node":shot})
        return shot
func check(value: bool,label: String) -> void:
    if value: passed += 1
    else:
        failed += 1
        push_error("ENEMY CAST FAIL: "+label)
func _initialize() -> void: call_deferred("run")
func make_actor(kind: String,at: Vector2=Vector2(0,300)) -> CharacterBody2D:
    var actor: CharacterBody2D = Enemy.new()
    actor.configure(game,kind,at)
    game.add_child(actor)
    actor.set_physics_process(false)
    actor.hide()
    actor.facing = 1
    actors.append(actor)
    return actor
func reset_fixture() -> void:
    for actor: Node in actors:
        if is_instance_valid(actor): actor.queue_free()
    actors.clear()
    for shot: Node in get_nodes_in_group("projectiles"):
        if is_instance_valid(shot): shot.clear()
    await process_frame
    game.story_safe = false
    game._paused = false
    game.outcome = ""
    game.reject = false
    game.attempts = 0
    game.damage = 0
    game.shots.clear()
    game.player.position = Vector2(200,300)
    game.player.dead = false
    game.player.health = 8
    game.player.guarded = false
    game.player.parries = 0
func run() -> void:
    game = CastGame.new()
    root.add_child(game)
    game.player = Hero.new()
    game.add_child(game.player)
    game.level = Terrain.new()
    game.add_child(game.level)
    await reset_fixture()
    check_roster()
    for kind: String in Enemy.KINDS:
        var actor: CharacterBody2D = make_actor(kind)
        check(actor.max_health == int(Enemy.CASTS[kind]["hp"]),kind+" health configured")
        actor.react("stun",Vector2(-20,300))
        check(actor.reaction == "stun" and actor._stun > 0,kind+" retains stun")
        actor.react("launch",Vector2(-20,300))
        check(actor.reaction == "launch" and actor.velocity.y < 0,kind+" retains launch")
        actor.react("knockback",Vector2(-20,300))
        check(actor.reaction == "knockback" and actor.velocity.x > 0,kind+" retains knockback")
    await reset_fixture()
    await check_fans()
    await check_bat()
    await check_melee()
    await check_caps()
    await check_gates_and_director()
    await check_pause_resume_lane()
    await reset_fixture()
    game.queue_free()
    await process_frame
    print("Main enemy cast: %d passed, %d failed" % [passed,failed])
    quit(1 if failed else 0)
func check_roster() -> void:
    var kinds: Dictionary = {}
    var elites: int = 0
    check(Level.ENEMIES.size() == 11,"eleven enemies spread through the level")
    for entry: Dictionary in Level.ENEMIES:
        kinds[entry["kind"]] = true
        if entry["kind"] == "elite": elites += 1
        check(entry.has("patrol") and entry["patrol"].has_area(),"every authored enemy has a patrol room")
    check(kinds.size() == 6,"six actual enemy kinds")
    check(elites == 1,"exactly one progression elite")
func check_fans() -> void:
    var wisp: CharacterBody2D = make_actor("wisp")
    check(wisp._begin_attack(),"wisp starts a valid cast")
    wisp._execute_attack()
    check(game.shots.size() == 1,"wisp first seed only")
    wisp._advance_cast(0.27)
    check(game.shots.size() == 1,"wisp delayed beads do not release early")
    wisp._advance_cast(0.02)
    check(game.shots.size() == 3,"wisp finite second layer")
    await reset_fixture()
    var lantern: CharacterBody2D = make_actor("lantern")
    check(lantern._begin_attack(),"lantern starts")
    lantern._sync_animation()
    check(lantern.animation_state == "windup" and lantern.frame == 0,"windup starts at actual frame zero")
    lantern._advance_cast(0.36)
    lantern._sync_animation()
    check(lantern.frame == 2 and absf(lantern.cast_progress-0.5) < 0.01,"windup progress drives four frames")
    lantern._execute_attack()
    check(game.shots.size() == 4,"lantern first fan four shots")
    lantern._advance_cast(0.33)
    check(game.shots.size() == 4,"offbeat fan respects delay")
    lantern._advance_cast(0.02)
    check(game.shots.size() == 8,"lantern second fan finite")
    var aim: Vector2 = (Vector2(200,286)-Vector2(8,284)).normalized()
    for shot: Dictionary in game.shots:
        check(absf(rad_to_deg(aim.angle_to(shot["motion"]))) >= 27.9,"fan preserves central safe lane")
    for index in range(30): lantern._advance_cast(0.1)
    check(game.shots.size() == 8 and lantern._layers.is_empty(),"finished fan never duplicates")
    await reset_fixture()
func check_bat() -> void:
    var bat: CharacterBody2D = make_actor("bat")
    check(bat._begin_attack(),"bat starts")
    bat._execute_attack()
    check(game.shots.size() == 1,"bat creates one slow head")
    var seed: Shot = game.shots[0]["node"]
    seed.position += seed.velocity*0.3
    bat._advance_cast(0.31)
    check(seed.cleared and game.shots.size() == 5,"live head turns into four petals")
    await reset_fixture()
    bat = make_actor("bat")
    bat._begin_attack()
    bat._execute_attack()
    seed = game.shots[0]["node"]
    seed.friendly = true
    bat._advance_cast(0.31)
    check(game.shots.size() == 1 and not seed.cleared,"reflected seed survives and never blooms")
    bat._cancel_cast(true)
    check(not seed.cleared,"cast cancellation protects reflected friendly")
    await reset_fixture()
    bat = make_actor("bat")
    bat._begin_attack()
    bat._execute_attack()
    seed = game.shots[0]["node"]
    seed.clear()
    bat._advance_cast(0.31)
    check(game.shots.size() == 1,"wall-cleared seed never blooms")
    await reset_fixture()
func check_melee() -> void:
    game.player.position = Vector2(60,300)
    game.player.guarded = true
    var jailer: CharacterBody2D = make_actor("jailer")
    jailer._begin_attack()
    var serial: int = jailer.attack_serial
    jailer._execute_attack()
    jailer._execute_attack()
    jailer._check_melee_contact()
    check(game.player.parries == 1 and game.damage == 0,"jailer sweep parries once per token")
    check(jailer._stagger >= 0.7 and jailer.health == 5,"accepted jailer clash recoils")
    jailer._stagger = 0
    jailer._hurt_flash = 0
    game.player.guarded = false
    jailer._begin_attack()
    jailer._execute_attack()
    jailer._check_melee_contact()
    check(jailer.attack_serial > serial and game.damage == 1,"next sweep damages once with new serial")
    await reset_fixture()
func check_caps() -> void:
    var lantern: CharacterBody2D = make_actor("lantern")
    for index in range(20): lantern._spawn_shot(Vector2(8,284),Vector2.RIGHT*100,"lantern_fan")
    check(lantern._source_count() == 12 and game.attempts == 12,"per-source hostile cap enforced")
    await reset_fixture()
    for index in range(180):
        var shot: Shot = Shot.new()
        game.add_child(shot)
    lantern = make_actor("lantern")
    lantern._begin_attack()
    lantern._execute_attack()
    lantern._advance_cast(0.4)
    for index in range(50): lantern._advance_cast(0.1)
    check(game.shots.is_empty() and game.attempts == 8,"181st rejection consumes exactly eight finite attempts")
    check(lantern._layers.is_empty() and lantern.cast_phase == "none","capacity rejection never traps cast")
    await reset_fixture()
func check_gates_and_director() -> void:
    var lantern: CharacterBody2D = make_actor("lantern")
    game.player.position.y = 500
    check(not lantern._begin_attack(),"vertical room prevents basement crossfire")
    game.player.position.y = 300
    lantern.patrol_bounds = Rect2(-20,190,100,134)
    check(not lantern._begin_attack(),"patrol bounds prevent remote chase/cast")
    lantern.patrol_bounds = Rect2()
    var wall: StaticBody2D = StaticBody2D.new()
    var collider: CollisionShape2D = CollisionShape2D.new()
    var shape: RectangleShape2D = RectangleShape2D.new()
    shape.size = Vector2(12,80)
    collider.shape = shape
    wall.position = Vector2(100,286)
    wall.add_child(collider)
    game.add_child(wall)
    await physics_frame
    check(not lantern._begin_attack(),"world geometry blocks cast line of sight")
    wall.queue_free()
    await physics_frame
    var bat: CharacterBody2D = make_actor("bat",Vector2(20,300))
    check(lantern._begin_attack() and not bat._begin_attack(),"one blocking cast owns director lane")
    lantern.receive_hit(1,Vector2(-20,300))
    check(bat._begin_attack(),"hit interruption releases director")
    bat._lane_remaining = 0.001
    bat._tick_lane(0.01)
    lantern._stagger = 0
    lantern._hurt_flash = 0
    check(lantern._begin_attack(),"expired lease cannot lock later casts")
    lantern._die()
    check(bat._begin_attack(),"owner death releases director")
    bat._execute_attack()
    game.story_safe = true
    bat._physics_process(0.01)
    check(bat.cast_phase == "none" and bat._layers.is_empty() and bat._source_count() == 0,"rest cancels delayed layers and owned hostiles")
    game.story_safe = false
    var camera: Camera2D = Camera2D.new()
    camera.position = Vector2(3000,300)
    game.add_child(camera)
    camera.make_current()
    await process_frame
    check(not bat._on_screen() and not bat._begin_attack(),"offscreen enemies cannot start casts")
    camera.queue_free()
    await process_frame

func check_pause_resume_lane() -> void:
    await reset_fixture()
    var lantern: CharacterBody2D = make_actor("lantern")
    var bat: CharacterBody2D = make_actor("bat",Vector2(20,300))
    check(lantern._begin_attack(),"pause fixture acquires director")
    lantern._execute_attack()
    var remaining: float = lantern._lane_remaining
    var serial: int = lantern.attack_serial
    var elapsed: float = lantern._release_elapsed
    check(lantern._source_count() == 4,"pause fixture contains live first fan")
    # Deliberately pass a huge elapsed value through the isolated lease seam
    # while paused. It represents arbitrary menu/wall time, not active physics;
    # no real sleep and no input playback are needed to reproduce the invariant.
    paused = true
    for repeat in range(3):
        lantern._physics_process(12.0)
        lantern._tick_lane(12.0)
    check(is_equal_approx(lantern._lane_remaining,remaining),"long and repeated pause cannot consume lease")
    check(lantern.cast_phase == "release" and lantern.attack_serial == serial and is_equal_approx(lantern._release_elapsed,elapsed),"paused cast and serial remain frozen")
    check(lantern._source_count() == 4 and game.attempts == 4,"pause neither clears existing shots nor emits delayed fan")
    check(not bat._claim_lane(3.0),"paused director cannot transfer ownership")
    paused = false
    lantern._physics_process(0.01)
    check(lantern.cast_phase == "release" and lantern._source_count() == 4 and lantern._lane_remaining > 0,"first resume tick preserves cast and live shots")
    check(not bat._begin_attack(),"resume preserves the existing lane owner")
    lantern._advance_cast(0.34)
    check(lantern._source_count() == 8 and game.attempts == 8,"resumed cast continues its delayed second fan")
    lantern._advance_cast(0.2)
    lantern._advance_cast(0.7)
    lantern._tick_lane(4.0)
    check(lantern.cast_phase == "none" and lantern._source_count() == 0 and bat._begin_attack(),"active physics expiry eventually releases director")
    await reset_fixture()
    lantern = make_actor("lantern")
    lantern._begin_attack()
    lantern._execute_attack()
    remaining = lantern._lane_remaining
    game._paused = true
    lantern._physics_process(20.0)
    lantern._tick_lane(20.0)
    check(lantern._source_count() == 4 and is_equal_approx(lantern._lane_remaining,remaining),"root menu pause flag also freezes lease independently")
    game._paused = false
    lantern._physics_process(0.01)
    check(lantern.cast_phase == "release" and lantern._source_count() == 4,"menu resume does not erase a live volley")
    await reset_fixture()

extends SceneTree
## Static real-terrain/short physics fixtures, not a gameplay run or input replay.
const Level = preload("res://levels/boss_chamber.gd")
const Dungeon = preload("res://levels/bellkeep.gd")
const STEP: float = 1.0/60.0
const ARENA_LEFT: float = 2660.0
const ARENA_RIGHT: float = 3330.0
const BOSS_SIZE: Vector2 = Vector2(26,46)
const LANDINGS: Array[Dictionary] = [
    {"id":"left","rect":Rect2(2690,252,94,12),"at":Vector2(2737,252),"safe_x":Vector2(2705,2769)},
    {"id":"middle","rect":Rect2(2834,210,104,12),"at":Vector2(2886,210),"safe_x":Vector2(2849,2923)},
    {"id":"right","rect":Rect2(3124,252,100,12),"at":Vector2(3174,252),"safe_x":Vector2(3139,3209)},
]
class StaticScore extends Node:
    signal beat(index: int)
    signal section_changed(section: String)
    signal transport_changed(generation: int, chart_time: float)
    var bpm: float = 112.0
    var advance_health_ratio: float = 0.5
    var running: bool = true
    var total_beats: int = 0
    var now: float = 0.0
    var timeline: Dictionary = {}
    func get_score_time() -> float: return now
    func get_chart_time() -> float: return now
    func seconds_per_beat() -> float: return 60.0/bpm
    func is_full_song() -> bool: return false
    func start_score() -> void: running = true
    func stop_score() -> void: running = false
    func request_advance() -> void: pass

class StaticHero extends Node2D:
    var dead: bool = false
    var health: int = 8
    var parry_timer: float = 0.0
    var facing: int = -1
    func parry_success(_enemy: Node, _at: Vector2, _kind: String, _token: int) -> bool: return false

class NavigationGame extends Node2D:
    var player: Node2D
    var music: Node
    var room_id: String = "boss"
    var boss: Node2D
    var story_safe: bool = false
    var _paused: bool = false
    var outcome: String = ""
    var damage_events: int = 0
    func announce(_message: String, _seconds: float) -> void: pass
    func emit_fx(_kind: String, _at: Vector2, _direction: Vector2, _strength: float = 1.0) -> void: pass
    func on_boss_phase(section: String) -> void: story_safe = section == "rest"
    func on_boss_defeated() -> void: outcome = "won"
    func clear_boss_hazards() -> void: pass
    func damage_player(_amount: int, _at: Vector2) -> void: damage_events += 1
    func spawn_projectile(_at: Vector2, _velocity: Vector2, _friendly: bool = false, _style: String = "") -> Node2D: return null
    func spawn_boss_hazard(hazard: Node2D) -> bool:
        hazard.free()
        return false

var passed: int = 0
var failed: int = 0
var finished: bool = false
var level: Node2D
var fixture: Node2D

func check(ok: bool,label: String) -> void:
    if ok:
        passed += 1
        print("PASS ",label)
    else:
        failed += 1
        push_error("BOSS NAV FAIL: "+label)

func _initialize() -> void:
    call_deferred("run")
    call_deferred("watchdog")

func watchdog() -> void:
    create_timer(35.0,true,false,true).timeout.connect(func() -> void:
        if not finished:
            push_error("BOSS NAV FAIL: bounded static fixture timeout")
            quit(1))

func static_rect(rect: Rect2,name: String) -> StaticBody2D:
    var body: StaticBody2D = StaticBody2D.new()
    body.name = name
    body.position = rect.get_center()
    body.collision_layer = 1
    body.collision_mask = 0
    var collision: CollisionShape2D = CollisionShape2D.new()
    var shape: RectangleShape2D = RectangleShape2D.new()
    shape.size = rect.size
    collision.shape = shape
    body.add_child(collision)
    fixture.add_child(body)
    return body

func probe_body(at: Vector2) -> CharacterBody2D:
    var body: CharacterBody2D = CharacterBody2D.new()
    body.position = at
    body.collision_layer = 0
    body.collision_mask = 1
    body.floor_snap_length = 5.0
    var collision: CollisionShape2D = CollisionShape2D.new()
    var shape: RectangleShape2D = RectangleShape2D.new()
    shape.size = BOSS_SIZE
    collision.shape = shape
    collision.position = Vector2(0,-23)
    body.add_child(collision)
    fixture.add_child(body)
    return body

func check_terrain() -> void:
    check(Level.PLATFORMS.has(Rect2(2580,300,840,120)),"Boss floor is the actual uninterrupted solid deck")
    for at: Vector2 in [Vector2(2660,299),Vector2(3330,299)]:
        var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(at,at+Vector2(0,8),1)
        var hit: Dictionary = fixture.get_world_2d().direct_space_state.intersect_ray(query)
        check(not hit.is_empty() and absf(float(hit["position"].y)-300.0) < 0.1,"real floor supports logical boundary "+str(at.x))
    for item: Dictionary in LANDINGS:
        check(Level.PLATFORMS.has(item["rect"]),"actual platform retained "+str(item["id"]))
        var found: bool = false
        for child: Node in level.get_children():
            if child is StaticBody2D and child.position == (item["rect"] as Rect2).get_center():
                var shape: CollisionShape2D = child.get_child(0)
                found = shape.one_way_collision and is_equal_approx(shape.one_way_collision_margin,4.0)
        check(found,"12px platform is real one-way collision "+str(item["id"]))
    for chain: Dictionary in Dungeon.CLIMBABLES:
        check((chain["rect"] as Rect2).end.x < ARENA_LEFT,"no phantom climb chain inside Boss arena")

func check_platform_landings() -> void:
    for item: Dictionary in LANDINGS:
        var target: Vector2 = item["at"]
        var body: CharacterBody2D = probe_body(target+Vector2(0,-24))
        var landed: bool = false
        for tick in range(45):
            await physics_frame
            body.velocity.y += 950.0*STEP
            body.move_and_slide()
            if body.is_on_floor():
                landed = true
                break
        check(landed and absf(body.position.y-target.y) < 0.5,"real26x46 body falls onto "+str(item["id"]))
        check(body.position.x-BOSS_SIZE.x*0.5 >= (item["rect"] as Rect2).position.x and body.position.x+BOSS_SIZE.x*0.5 <= (item["rect"] as Rect2).end.x,"entire body is supported on "+str(item["id"]))
        body.queue_free()
        await physics_frame

func check_wall_collision() -> void:
    var wall: StaticBody2D = static_rect(Rect2(3000,180,12,120),"InternalProbeWall")
    var body: CharacterBody2D = probe_body(Vector2(2960,300))
    for tick in range(24):
        await physics_frame
        body.velocity = Vector2(250,40)
        body.move_and_slide()
    check(body.position.x <= 2987.1 and body.is_on_wall(),"actual body collision stops before an internal wall")
    check(body.position.y <= 300.5,"wall collision preserves floor support")
    body.queue_free()
    wall.queue_free()
    await physics_frame

func fresh_boss(at: Vector2,target: Vector2) -> NavigationGame:
    var game: NavigationGame = NavigationGame.new()
    fixture.add_child(game)
    game.music = StaticScore.new()
    game.add_child(game.music)
    game.player = StaticHero.new()
    game.player.position = target
    game.add_child(game.player)
    var script: Script = load("res://combat/boss.gd")
    game.boss = script.new()
    game.add_child(game.boss)
    game.boss.configure(game,at)
    game.boss.set_process(false)
    game.boss.set_physics_process(false)
    game.boss.set_duel_enabled(false)
    game.boss.start_encounter()
    return game

func physics_tick(game: NavigationGame) -> void:
    await physics_frame
    game.music.now += STEP
    game.boss._physics_process(STEP)

func dispose_game(game: NavigationGame) -> void:
    game.queue_free()
    await physics_frame

func check_runtime() -> void:
    var script: Script = load("res://combat/boss.gd")
    if script == null or not script.can_instantiate():
        check(false,"shipping Boss script loads for navigation fixtures")
        return
    var api_probe: Node = script.new()
    var ready: bool = api_probe.has_method("get_navigation_status") and api_probe.has_method("set_duel_enabled")
    check(ready,"shipping Boss exposes navigation status and optional-duel switch")
    api_probe.free()
    if not ready: return
    await check_boss_pursuit()
    await check_boss_platforms()
    await check_boss_vertical_middle_platform()
    await check_boss_middle_platform_descent()
    await check_boss_bounds_and_wall()
    await check_boss_cleanup()
    await check_infinite_flight()

func check_boss_pursuit() -> void:
    var game: NavigationGame = fresh_boss(Vector2(2940,300),Vector2(3070,300))
    var original_gap: float = absf(game.player.position.x-game.boss.position.x)
    for tick in range(24): await physics_tick(game)
    check(absf(game.player.position.x-game.boss.position.x) < original_gap-25.0,"actual Boss physics pursues a same-height target")
    check(game.boss.is_on_floor() and absf(game.boss.position.y-300.0) < 0.5,"same-height pursuit retains real floor support")
    check(int(game.boss.get_navigation_status().get("extra_attacks",-1)) == 0,"navigation-only switch suppresses optional melee without disabling pursuit")
    await dispose_game(game)

func check_boss_platforms() -> void:
    var starts: Array[Vector2] = [Vector2(2675,300),Vector2(2760,252),Vector2(3090,300)]
    for index in range(LANDINGS.size()):
        var item: Dictionary = LANDINGS[index]
        var game: NavigationGame = fresh_boss(starts[index],item["at"])
        var jumped: bool = false
        var landed: bool = false
        for tick in range(130):
            await physics_tick(game)
            jumped = jumped or game.boss.velocity.y < -1.0
            var safe: Vector2 = item["safe_x"]
            if game.boss.is_on_floor() and absf(game.boss.position.y-(item["at"] as Vector2).y) < 0.5 and game.boss.position.x >= safe.x and game.boss.position.x <= safe.y:
                landed = true
                break
        check(jumped,"actual Boss begins a physical jump toward "+str(item["id"]))
        check(landed,"actual Boss reaches supported platform landing "+str(item["id"]))
        check(game.boss.position.x >= ARENA_LEFT and game.boss.position.x <= ARENA_RIGHT,"platform pursuit remains inside arena "+str(item["id"]))
        await dispose_game(game)

func check_boss_vertical_middle_platform() -> void:
    # Regression: a wide landing ray must not mistake the overhead one-way
    # platform for the support immediately underneath the Boss's feet.
    var game: NavigationGame = fresh_boss(Vector2(2886,300),Vector2(2886,210))
    await physics_frame
    var foot_ray: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(Vector2(2886,299),Vector2(2886,307),1,[game.boss.get_rid()])
    var floor_hit: Dictionary = fixture.get_world_2d().direct_space_state.intersect_ray(foot_ray)
    check(not floor_hit.is_empty() and absf(float((floor_hit["position"] as Vector2).y)-300.0) < 0.1,"vertical middle-platform fixture starts on the actual lower floor")
    var jumped: bool = false
    var landed: bool = false
    for tick in range(130):
        await physics_tick(game)
        jumped = jumped or game.boss.velocity.y < -1.0
        if game.boss.is_on_floor() and absf(game.boss.position.y-210.0) < 0.5 and game.boss.position.x >= 2849.0 and game.boss.position.x <= 2923.0:
            landed = true
            break
    check(jumped,"Boss directly below middle platform initiates a legal 90px jump")
    check(landed,"Boss physically lands on the 90px overhead one-way middle platform")
    await dispose_game(game)
func check_boss_middle_platform_descent() -> void:
    # The target's foot layer is authoritative in both directions. At the same
    # x coordinate, a landing query must not silently relock this 210px platform.
    var game: NavigationGame = fresh_boss(Vector2(2886,210),Vector2(2886,300))
    await physics_frame
    var accepted: bool = game.boss.try_navigation_jump(game.player.position,false)
    check(accepted,"Boss accepts a real middle-platform to lower-floor navigation request")
    var status: Dictionary = game.boss.get_navigation_status()
    var landing: Vector2 = status.get("landing",Vector2.INF)
    check(accepted and absf(landing.y-300.0) < 0.1,"downward navigation locks the target floor at 300 instead of its own platform at 210")
    var landed: bool = false
    for tick in range(150):
        await physics_tick(game)
        if game.boss.is_on_floor() and absf(game.boss.position.y-300.0) < 0.5 and absf(game.boss.position.x-2886.0) <= 58.0:
            landed = true
            break
    check(landed,"production Boss physically descends from middle platform to the target lower floor")
    await dispose_game(game)
func check_boss_bounds_and_wall() -> void:
    for entry: Dictionary in [{"at":Vector2(2670,300),"target":Vector2(2500,300),"side":"left"},{"at":Vector2(3320,300),"target":Vector2(3480,300),"side":"right"}]:
        var game: NavigationGame = fresh_boss(entry["at"],entry["target"])
        var stays_inside: bool = true
        for tick in range(20):
            await physics_tick(game)
            stays_inside = stays_inside and game.boss.position.x >= ARENA_LEFT-0.1 and game.boss.position.x <= ARENA_RIGHT+0.1
        check(stays_inside,"real Boss respects logical "+str(entry["side"])+" arena boundary")
        await dispose_game(game)
    var wall: StaticBody2D = static_rect(Rect2(3000,180,12,120),"BossNavigationWall")
    var game: NavigationGame = fresh_boss(Vector2(2960,300),Vector2(3070,300))
    var blocked: bool = true
    for tick in range(55):
        await physics_tick(game)
        blocked = blocked and game.boss.position.x <= 2987.2
    check(blocked,"production pursuit cannot tunnel through an unreachable real wall")
    await dispose_game(game)
    wall.queue_free()
    await physics_frame

func no_pending_contact(boss: Node2D) -> bool:
    return boss._duel_state.is_empty() and boss._authored_shift.is_empty() and boss._authored_dash.is_empty() and boss._blade_clip.is_empty() and boss._blade_previous.is_empty()

func start_real_duel(game: NavigationGame) -> void:
    game.boss.set_duel_enabled(true)
    await physics_tick(game)
    # Same signal that shipping MusicDirector sends. No forged duel state.
    game.music.beat.emit(0)

func advance_to_cut(game: NavigationGame) -> bool:
    for tick in range(24):
        await physics_tick(game)
        if not game.boss._blade_clip.is_empty(): return true
    return false

func check_boss_cleanup() -> void:
    var game: NavigationGame = fresh_boss(Vector2(2950,300),Vector2(3020,300))
    await start_real_duel(game)
    check(str(game.boss.get_navigation_status()["mode"]) == "draw","real beat starts a local duel before cleanup probes")
    var at: Vector2 = game.boss.position
    var speed: Vector2 = game.boss.velocity
    var elapsed: float = game.boss._duel_elapsed
    var clock: float = game.music.now
    game._paused = true
    paused = true
    for tick in range(6): game.boss._physics_process(0.25)
    check(game.boss.position == at and game.boss.velocity == speed and is_equal_approx(game.boss._duel_elapsed,elapsed) and is_equal_approx(game.music.now,clock),"tree and overlay pause freeze movement duel and its clock")
    paused = false
    game._paused = false
    await physics_tick(game)
    check(game.boss._duel_elapsed > elapsed and str(game.boss.get_navigation_status()["mode"]) == "draw","resume continues the existing duel instead of skipping its windup")
    var cut_started: bool = await advance_to_cut(game)
    check(cut_started,"real duel reaches its blade phase before rest cancellation")
    game.boss._on_section("rest")
    check(game.story_safe and no_pending_contact(game.boss),"rest cancels duel shift dash blade and previous contact samples")
    at = game.boss.position
    var damage_before: int = game.damage_events
    for tick in range(6): await physics_tick(game)
    check(is_equal_approx(game.boss.position.x,at.x) and game.damage_events == damage_before and not bool(game.boss.get_blade_state()["active"]),"rest has no pursuit or delayed blade damage")
    await dispose_game(game)

    game = fresh_boss(Vector2(2950,300),Vector2(3020,300))
    await start_real_duel(game)
    cut_started = await advance_to_cut(game)
    check(cut_started,"second real duel reaches a blade phase before death cancellation")
    game.boss._die()
    check(game.boss.dead and no_pending_contact(game.boss) and not game.music.running,"death cancels all movement/contact intents and stops score")
    at = game.boss.position
    damage_before = game.damage_events
    for tick in range(6): await physics_tick(game)
    check(game.boss.position == at and game.damage_events == damage_before and not bool(game.boss.get_blade_state()["active"]),"dead Boss cannot move or release delayed contact")
    await dispose_game(game)

func check_infinite_flight() -> void:
    var game: NavigationGame = fresh_boss(Vector2(5000,-2000),Vector2(5200,-2140))
    check(game.boss.has_method("set_infinite_room"),"Boss exposes the production infinite-flight movement mode")
    if not game.boss.has_method("set_infinite_room"):
        await dispose_game(game)
        return
    game.boss.set_infinite_room(true)
    var before: Vector2 = game.boss.position
    for tick in range(30): await physics_tick(game)
    check(game.boss.position.y < before.y-25.0 and game.boss.position.x > before.x,"air pursuit follows the target in both axes far outside the old arena")
    check(game.boss.collision_mask == 0,"infinite flight cannot be stopped by the old room masonry")
    var arena: Rect2 = game.boss.get_attack_arena()
    check(arena.has_point(game.player.position) and arena.get_center().distance_to(game.player.position) < 230.0,"attack planning space follows an infinitely travelling player")
    game.boss._authored_actions.clear()
    game.boss.velocity = Vector2(0,150)
    var dash_target: Vector2 = game.player.position
    game.boss._execute_authored_action({"type":"dash","time":game.music.now,"duration_beats":0.5,"source_serial":91,"source_pattern":"fast_1","source_index":0,"resolved_target":dash_target,"source_locked_target":dash_target},game.music.now)
    var end: float = game.music.now + 0.5 * game.music.seconds_per_beat()
    while game.music.now < end:
        await physics_tick(game)
    check(game.boss.position.distance_to(dash_target) < 0.01 and game.boss.velocity == Vector2.ZERO,"authored dash reaches its exact 2D target without residual pursuit drift")
    game.boss.velocity = Vector2(0,-130)
    var shift_target: Vector2 = game.player.position + Vector2(80,40)
    game.boss._execute_authored_action({"type":"teleport","time":game.music.now,"source_serial":91,"source_pattern":"fast_1","source_index":1,"resolved_target":shift_target,"source_locked_target":shift_target},game.music.now)
    var shift_ticks: int = 0
    while not game.boss._authored_shift.is_empty() and shift_ticks < 120:
        await physics_tick(game)
        shift_ticks += 1
    check(game.boss.position.distance_to(shift_target) <= 1.0,"authored shift reaches its 2D destination; actual=%s target=%s ticks=%d" % [game.boss.position,shift_target,shift_ticks])
    check(game.boss.velocity == Vector2.ZERO,"authored shift clears residual vertical motion")
    game.boss._authored_dash.clear()
    game.boss._clear_blade()
    game.boss._authored_actions.clear()
    game.boss._authored_actions.append({"type":"dash","time":game.music.now+1.0,"source_serial":92,"source_pattern":"fast_3","source_index":3,"resolved_target":Vector2.ZERO,"source_locked_target":Vector2.ZERO})
    game.boss._execute_authored_action({"type":"aim","time":game.music.now,"source_serial":92,"source_pattern":"fast_3","source_index":2,"resolved_target":game.player.position,"source_locked_target":game.player.position},game.music.now)
    check(game.boss._authored_actions[0]["resolved_target"] == game.player.position and game.boss._authored_actions[0]["source_locked_target"] == game.player.position,"fast repeated aim retains the infinite two-dimensional player target")
    check(game.boss.get_warning_geometry()["to"] == game.player.position,"fast repeated aim previews the actual airborne target instead of a horizontal-only point")
    game.story_safe = true
    game.boss.velocity = Vector2(100,-100)
    await physics_tick(game)
    check(game.boss.velocity == Vector2.ZERO and game.boss.position.y < before.y,"narrative rest freezes the airborne body without gravity or drift")
    game.story_safe = false
    var shot: Node2D = load("res://combat/projectile.gd").new()
    game.add_child(shot)
    shot.configure(game,game.player.position+Vector2(0,-500),Vector2.ZERO)
    shot._physics_process(STEP)
    check(not shot.get("_cleared"),"Boss projectile survives far above the retired room coordinates")
    shot.queue_free()
    await dispose_game(game)

    game = fresh_boss(Vector2(5300,-2000),Vector2(5370,-2000))
    game.boss.set_infinite_room(true)
    game.boss.set_duel_enabled(true)
    game.boss.velocity = Vector2(0,140)
    game.music.beat.emit(0)
    var duel_y: float = game.boss.position.y
    var duel_ticks: int = 0
    var hovered: bool = game.boss._duel_state == "draw"
    while not game.boss._duel_state.is_empty() and duel_ticks < 120:
        await physics_tick(game)
        hovered = hovered and is_equal_approx(game.boss.position.y,duel_y) and game.boss.velocity.y == 0.0
        duel_ticks += 1
    check(hovered and duel_ticks >= 70,"airborne draw cut retreat and recovery hover without ground-era vertical drift")
    await dispose_game(game)

func run() -> void:
    fixture = Node2D.new()
    root.add_child(fixture)
    level = Level.new()
    fixture.add_child(level)
    level.setup(null)
    await physics_frame
    check_terrain()
    await check_platform_landings()
    await check_wall_collision()
    var terrain_only: bool = OS.get_cmdline_user_args().has("--terrain-only")
    if not terrain_only: await check_runtime()
    fixture.queue_free()
    await process_frame
    finished = true
    print("Boss navigation%s: %d passed, %d failed" % [" terrain-only (runtime not executed)" if terrain_only else "",passed,failed])
    quit(1 if failed else 0)

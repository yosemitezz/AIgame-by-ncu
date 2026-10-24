extends SceneTree
## Room-owned geometry only; no actors, song playback, input replay or main loop.
const Dungeon = preload("res://levels/bellkeep.gd")
const Chamber = preload("res://levels/boss_chamber.gd")
const STEP: float = 1.0/60.0
var passed: int = 0
var failed: int = 0
var finished: bool = false
var fixture: Node2D

func _initialize() -> void:
    call_deferred("run")
    create_timer(15.0,true,false,true).timeout.connect(func() -> void:
        if not finished:
            push_error("ROOM GEOMETRY bounded fixture timeout")
            quit(1))

func check(ok: bool,label: String) -> void:
    if ok:
        passed += 1
        print("PASS ",label)
    else:
        failed += 1
        push_error("ROOM GEOMETRY FAIL: "+label)

func hit(from: Vector2,to: Vector2) -> Dictionary:
    var query := PhysicsRayQueryParameters2D.create(from,to,1)
    return fixture.get_world_2d().direct_space_state.intersect_ray(query)

func probe(at: Vector2,size: Vector2) -> CharacterBody2D:
    var body := CharacterBody2D.new()
    body.position = at
    body.collision_layer = 0
    body.collision_mask = 1
    body.floor_snap_length = 5.0
    var collider := CollisionShape2D.new()
    var shape := RectangleShape2D.new()
    shape.size = size
    collider.shape = shape
    collider.position = Vector2(0,-size.y*0.5)
    body.add_child(collider)
    fixture.add_child(body)
    return body

func check_spec(spec: Dictionary,id: String) -> void:
    var keys: Array[String] = ["id","title","bounds","spawn","checkpoint","boss_spawn","portal_at","fall_limit","platforms","shard_indices"]
    var complete: bool = true
    for key: String in keys: complete = complete and spec.has(key)
    check(complete and str(spec["id"]) == id,"complete stable room spec for "+id)
    check((spec["bounds"] as Rect2).has_point(spec["spawn"]),"room spawn belongs to its own camera bounds "+id)

func run() -> void:
    fixture = Node2D.new()
    root.add_child(fixture)
    var dungeon: Node2D = Dungeon.new()
    fixture.add_child(dungeon)
    dungeon.setup(null)
    await physics_frame
    var dungeon_spec: Dictionary = dungeon.get_room_spec()
    check_spec(dungeon_spec,"dungeon")
    check(dungeon_spec["bounds"] == Rect2(-40,-160,2700,860),"dungeon bounds end at the portal wing")
    var owns_tail: bool = false
    for area: Rect2 in dungeon_spec["platforms"]:
        owns_tail = owns_tail or area.end.x > 2642.0
    check(not owns_tail,"instantiated dungeon platform data excludes Boss tail")
    check(hit(Vector2(2886,299),Vector2(2886,307)).is_empty(),"dungeon physics has no old Boss floor")
    check(hit(Vector2(2886,200),Vector2(2886,222)).is_empty(),"dungeon physics has no old Boss middle platform")
    check(hit(Vector2(100,299),Vector2(100,307)).has("position"),"original teaching floor remains in dungeon")
    check(not dungeon.climb_at(Vector2(548,400)).is_empty() and dungeon.water_at(Vector2(800,494)),"dungeon chains and shallow-water branch are preserved")
    var portal: Dictionary = dungeon.portal_at(Vector2(2560,300))
    check(str(portal.get("target","")) == "boss" and str(portal.get("requires","")) == "elite","portal declares Boss destination and elite gate")
    check(not dungeon.portal_at(Vector2(2524,244)).is_empty() and not dungeon.portal_at(Vector2(2596,308)).is_empty(),"portal feet rectangle includes its boundary")
    check(dungeon.portal_at(Vector2(2523.99,300)).is_empty() and dungeon.portal_at(Vector2(2560,308.01)).is_empty(),"portal does not trigger just outside its feet boundary")
    check(not dungeon_spec["shard_indices"].has(11) and dungeon_spec["shard_indices"].size() == Dungeon.SHARDS.size()-1,"dungeon excludes only stable global Boss shard index 11")
    var body: CharacterBody2D = probe(Vector2(2596,300),Vector2(14,26))
    for tick in range(20):
        await physics_frame
        body.velocity = Vector2(200,40)
        body.move_and_slide()
    check(body.position.x <= 2619.2 and body.is_on_wall(),"real end wall blocks continuation into the former arena")
    body.queue_free()
    check(dungeon.try_interact(Vector2(676,476)),"dungeon door interaction remains functional")
    var opened: Array = dungeon.get_opened_ids()
    check(opened.has("crypt_door"),"dungeon retains its own opened door IDs")
    dungeon.queue_free()
    await physics_frame
    await physics_frame
    check(hit(Vector2(100,299),Vector2(100,307)).is_empty(),"freeing the dungeon removes its actual collision tree")

    var chamber: Node2D = Chamber.new()
    fixture.add_child(chamber)
    chamber.setup(null)
    chamber.restore_opened_ids(opened)
    await physics_frame
    var boss_spec: Dictionary = chamber.get_room_spec()
    check_spec(boss_spec,"boss")
    check(chamber.get_parent() == fixture and chamber.get_script() != Dungeon,"Boss chamber is an independent scene-tree node")
    check(chamber.get_child_count() == Chamber.PLATFORMS.size() and Chamber.ENEMIES.is_empty(),"Boss room creates only owned geometry and no dungeon mob or Boss actors")
    check(chamber.get_opened_ids().is_empty() and chamber.climb_at(Vector2(548,400)).is_empty() and not chamber.water_at(Vector2(800,494)),"dungeon doors chains and water cannot leak into chamber")
    check(hit(Vector2(100,299),Vector2(100,307)).is_empty(),"Boss tree contains no teaching-route floor")
    var floor_hit: Dictionary = hit(Vector2(2990,299),Vector2(2990,307))
    check(not floor_hit.is_empty() and is_equal_approx((floor_hit["position"] as Vector2).y,300.0),"Boss chamber has its own solid 300px floor")
    for at: Vector2 in [Vector2(2737,252),Vector2(2886,210),Vector2(3174,252)]:
        var platform_hit: Dictionary = hit(at-Vector2(0,3),at+Vector2(0,8))
        var one_way: bool = false
        if not platform_hit.is_empty():
            for collider: Node in (platform_hit["collider"] as Node).get_children():
                if collider is CollisionShape2D: one_way = collider.one_way_collision and is_equal_approx(collider.one_way_collision_margin,4.0)
        check(one_way,"Boss platform retains real one-way collision at "+str(at))
    check(not hit(Vector2(2610,180),Vector2(2640,180)).is_empty() and not hit(Vector2(3350,180),Vector2(3380,180)).is_empty(),"standalone chamber owns both physical side walls")
    check(boss_spec["shard_indices"] == [11] and Chamber.SHARDS[0] == Dungeon.SHARDS[11],"Boss shard keeps its original global index and authored location")
    body = probe(boss_spec["spawn"],Vector2(14,26))
    for tick in range(8):
        await physics_frame
        body.velocity.y += 950.0*STEP
        body.move_and_slide()
    check(body.is_on_floor() and absf(body.position.y-300) < 0.5,"Boss-room player entry is physically supported")
    body.queue_free()
    body = probe(Vector2(2990,-60),Vector2(14,26))
    for tick in range(20):
        await physics_frame
        body.velocity = Vector2(0,-400)
        body.move_and_slide()
    check(body.is_on_ceiling() and body.position.y-26.0 >= Chamber.WORLD_BOUNDS.position.y-0.2,"solid ceiling stops repeated upward body motion before leaving room bounds")
    body.queue_free()
    check(chamber.portal_at(Chamber.SPAWN).is_empty(),"combat chamber does not automatically exit through its spawn")
    chamber.queue_free()
    await physics_frame
    var restored: Node2D = Dungeon.new()
    fixture.add_child(restored)
    restored.setup(null)
    restored.restore_opened_ids(opened)
    await physics_frame
    check(restored.get_opened_ids().has("crypt_door"),"a rebuilt dungeon restores only its own stable door state")
    fixture.queue_free()
    await process_frame
    finished = true
    print("Room geometry: %d passed, %d failed" % [passed,failed])
    quit(1 if failed else 0)

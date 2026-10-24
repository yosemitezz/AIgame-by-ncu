extends SceneTree
## Selective main-project migration fixtures. No playable scene, input bot, or playthrough.
const Level = preload("res://levels/bellkeep.gd")
const SOURCE_COMMIT: String = "e895c4477237c47ad14ed75ed7a7a8b4460c38fd"
const ORIGINAL_SHARDS: Array[Vector2] = [Vector2(372,232),Vector2(490,188),Vector2(648,144),Vector2(816,120),Vector2(956,164),Vector2(1092,206),Vector2(1248,224),Vector2(1460,276),Vector2(1584,228),Vector2(1970,276),Vector2(2392,276),Vector2(2914,186),Vector2(2158,232),Vector2(2300,188),Vector2(2440,232)]
var passed: int = 0
var failed: int = 0
var checks: Array[Dictionary] = []
var map: Node2D

func check(value: bool,label: String) -> void:
	checks.append({"test": label,"passed": value})
	if value: passed += 1
	else:
		failed += 1
		push_error("MAIN DUNGEON FAIL: " + label)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	map = Level.new()
	root.add_child(map)
	map.setup(null)
	await physics_frame
	var built: int = map.get_child_count()
	map.setup(null)
	check(map.get_child_count() == built,"map setup is idempotent")
	check(built == Level.PLATFORMS.size()+Level.DOORS.size(),"real terrain and all new door bodies constructed")
	check_contract()
	check_graph()
	check_regions()
	await check_doors()
	await check_shafts()
	map.queue_free()
	await process_frame
	var evidence: Dictionary = {"source_commit":SOURCE_COMMIT,"passed":passed,"failed":failed,"checks":checks,"playthrough":false}
	var directory: String = ProjectSettings.globalize_path("res://artifacts")
	DirAccess.make_dir_recursive_absolute(directory)
	var file: FileAccess = FileAccess.open("res://artifacts/main_dungeon_migration_report.json",FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(evidence,"\t",true))
		file.close()
	else:
		failed += 1
		push_error("Cannot save migration evidence")
	print("Main dungeon migration: %d passed, %d failed" % [passed,failed])
	quit(1 if failed else 0)

func check_contract() -> void:
	check(Level.SPAWN == Vector2(90,260),"spawn contract retained")
	check(Level.CHECKPOINT == Vector2(1860,260),"checkpoint position retained")
	check(Level.CHECKPOINT_RECT == Rect2(1824,240,72,72),"checkpoint is a spatial rectangle")
	check(not Level.CHECKPOINT_RECT.has_point(Vector2(1860,48)),"upper traversal cannot trigger shrine by x")
	check(Level.CHECKPOINT_RECT.has_point(Level.CHECKPOINT),"checkpoint spawn is inside shrine")
	check(Level.BOSS_TRIGGER_X == 2640 and Level.BOSS_POSITION == Vector2(2990,250),"Boss entry and spawn unchanged")
	check(Level.LEVEL_END == 3380,"legacy exit unchanged")
	check(Level.WORLD_BOUNDS == Rect2(-40,-160,3520,860) and Level.FALL_LIMIT == 720,"world covers library and crypt")
	check(Level.PLATFORMS.size() == 26 and Level.CLIMBABLES.size() == 4,"26 terrain pieces and four real chains")
	check(Level.DOORS.size() == 3 and Level.WATER_REGIONS.size() == 2,"three interactions and two shallow pools")
	check(Level.SHARDS.size() == 25,"reward branch carries migrated actual pickups")
	for i: int in ORIGINAL_SHARDS.size():
		check(Level.SHARDS[i] == ORIGINAL_SHARDS[i],"stable original shard %d" % i)
	for entry: Dictionary in Level.ENEMIES:
		check(entry["kind"] in ["sentry","wisp","elite"],"no new creature category in migration")
	check(map.room_at(Vector2(1450,48)).get("id","") == "archive","library map room exposed")
	check(map.room_at(Vector2(1100,500)).get("id","") == "crypt","crypt map room exposed")
	check(map.room_at(Vector2(1100,300)).is_empty(),"legacy nave falls back to existing zones")
	check(map.interaction_hint(Level.SPAWN).is_empty(),"no false interaction at spawn")

func gap_x(a: Rect2,b: Rect2) -> float:
	return maxf(0,maxf(b.position.x-a.end.x,a.position.x-b.end.x))

func can_jump(a: Rect2,b: Rect2) -> bool:
	var rise: float = a.position.y-b.position.y
	return rise <= 56 and rise >= -72 and gap_x(a,b) <= (54 if rise > 8 else 100)

func can_fall(a: Rect2,b: Rect2) -> bool:
	if b.position.y <= a.position.y+56: return false
	for x: float in [a.position.x-9,a.end.x+9]:
		if x-7 < b.position.x or x+7 > b.end.x: continue
		var clear: bool = true
		var shaft: Rect2 = Rect2(x-7,a.position.y+1,14,b.position.y-a.position.y-2)
		for terrain: Rect2 in Level.PLATFORMS:
			if terrain != a and terrain != b and shaft.intersects(terrain): clear = false
		if clear: return true
	return false

func near_chain(floor: Rect2,chain: Rect2) -> bool:
	var x: float = chain.get_center().x
	return floor.position.y >= chain.position.y and floor.position.y <= chain.end.y and x >= floor.position.x-64 and x <= floor.end.x+64

func can_climb(a: Rect2,b: Rect2) -> bool:
	for entry: Dictionary in Level.CLIMBABLES:
		if near_chain(a,entry["rect"]) and near_chain(b,entry["rect"]): return true
	return false

func check_graph() -> void:
	var reached: Array[bool] = []
	reached.resize(Level.PLATFORMS.size())
	reached.fill(false)
	var seed: int = -1
	var top: float = INF
	for i: int in Level.PLATFORMS.size():
		var floor: Rect2 = Level.PLATFORMS[i]
		if Level.SPAWN.x >= floor.position.x and Level.SPAWN.x <= floor.end.x and floor.position.y >= Level.SPAWN.y and floor.position.y < top:
			seed = i
			top = floor.position.y
	check(seed >= 0,"single SPAWN seed exists")
	if seed < 0: return
	reached[seed] = true
	var changed: bool = true
	while changed:
		changed = false
		for i: int in reached.size():
			if not reached[i]: continue
			for j: int in reached.size():
				if reached[j]: continue
				var a: Rect2 = Level.PLATFORMS[i]
				var b: Rect2 = Level.PLATFORMS[j]
				if can_jump(a,b) or can_fall(a,b) or can_climb(a,b):
					reached[j] = true
					changed = true
	for i: int in reached.size():
		check(reached[i],"SPAWN graph reaches floor %d" % i)
	var west: Rect2 = Rect2(440,500,512,80)
	var middle: Rect2 = Rect2(1032,500,384,80)
	var east: Rect2 = Rect2(1496,500,312,80)
	check(can_climb(Level.PLATFORMS[seed],west),"entry chain connects nave to crypt")
	check(can_jump(west,middle) and can_jump(middle,east),"lower route crosses both authored gaps")
	check(can_climb(east,Rect2(1798,300,1762,120)),"return chain completes shrine-side loop")
	check(can_climb(middle,Rect2(1392,48,184,20)),"library reward branch connects from crypt")

func check_regions() -> void:
	for entry: Dictionary in Level.CLIMBABLES:
		var r: Rect2 = entry["rect"]
		check(map.climb_at(Vector2(r.get_center().x,r.position.y)).get("id","") == entry["id"],"chain top included "+str(entry["id"]))
		check(map.climb_at(Vector2(r.get_center().x,r.end.y)).get("id","") == entry["id"],"chain bottom included "+str(entry["id"]))
		check(map.climb_at(Vector2(r.get_center().x,r.position.y-0.01)).is_empty(),"chain outside top excluded "+str(entry["id"]))
	for r: Rect2 in Level.WATER_REGIONS:
		check(map.water_at(r.position) and map.water_at(r.end),"water surface and floor endpoints included")
		check(not map.water_at(r.end+Vector2(0.01,0)),"water trailing outside excluded")
		check(not map.water_at(r.position-Vector2(0,0.01)),"water above surface excluded")

func settle() -> void:
	await physics_frame
	await physics_frame

func ray_hits(from: Vector2,to: Vector2) -> bool:
	var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(from,to,1)
	return not map.get_world_2d().direct_space_state.intersect_ray(query).is_empty()

func check_doors() -> void:
	await settle()
	check(ray_hits(Vector2(656,450),Vector2(696,450)),"closed crypt physically blocks")
	check(not map.try_interact(Vector2(712.01,476)),"outside interaction radius rejected")
	check(map.try_interact(Vector2(712,476)),"exact interaction radius accepted")
	await settle()
	check(not ray_hits(Vector2(656,450),Vector2(696,450)),"opened crypt physically clears")
	check(not map.try_interact(Vector2(676,476)),"door does not reopen twice")
	check(ray_hits(Vector2(1762,304),Vector2(1762,348)),"shortcut initially blocks its shaft")
	check(map.try_interact(Vector2(1712,500)),"lever is reachable from lower path")
	await settle()
	check(not ray_hits(Vector2(1762,304),Vector2(1762,348)),"lever physically opens return hatch")
	check(map.try_interact(Vector2(1261,48)),"library door opens from reward side")
	await settle()
	check(not ray_hits(Vector2(1228,-20),Vector2(1268,-20)),"library door physically clears")
	check(map.get_opened_ids() == ["crypt_door","shortcut_hatch","archive_door"],"stable door IDs serializable for retry")
	map.restore_opened_ids(["crypt_door","shortcut_hatch","unknown"])
	await settle()
	check(map.get_opened_ids() == ["crypt_door","shortcut_hatch"],"retry restores only known IDs")
	check(ray_hits(Vector2(1228,-20),Vector2(1268,-20)),"unlisted library door remains closed")
	map.reset_interactions()
	await settle()
	check(map.get_opened_ids().is_empty() and ray_hits(Vector2(656,450),Vector2(696,450)),"new-run reset restores door collision")

func check_shafts() -> void:
	map.restore_opened_ids(["crypt_door","shortcut_hatch","archive_door"])
	await settle()
	for entry: Dictionary in Level.CLIMBABLES:
		var r: Rect2 = entry["rect"]
		var body: CharacterBody2D = CharacterBody2D.new()
		body.collision_layer = 2
		body.collision_mask = 1
		var collider: CollisionShape2D = CollisionShape2D.new()
		var shape: RectangleShape2D = RectangleShape2D.new()
		shape.size = Vector2(14,26)
		collider.shape = shape
		collider.position = Vector2(0,-13)
		body.add_child(collider)
		root.add_child(body)
		body.position = Vector2(r.get_center().x,r.end.y-1)
		await physics_frame
		var hit: KinematicCollision2D = body.move_and_collide(Vector2(0,r.position.y-body.position.y))
		check(hit == null,"real body fits upward shaft "+str(entry["id"]))
		hit = body.move_and_collide(Vector2(0,r.end.y-1-body.position.y))
		check(hit == null,"real body fits downward shaft "+str(entry["id"]))
		body.queue_free()
		await physics_frame

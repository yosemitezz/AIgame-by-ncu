extends SceneTree
## Bounded terrain/interaction fixtures, not a gameplay playthrough.
const Level = preload("res://levels/bellkeep.gd")
const Player = preload("res://actors/player.gd")
class MapGame extends Node2D:
	signal animation_event(actor: Node, state: String, frame: int, facing: int)
	var level: Node
	var story_safe: bool = false
	var _paused: bool = false
	func emit_fx(_kind: String, _at: Vector2, _direction: Vector2, _power: float) -> void:
		pass
	func hero_attack(_source: Node2D, _damage: int, _reach: float, _combo: int) -> void:
		pass
var passed: int = 0
var failed: int = 0
var map: Node2D
var fixture_game: MapGame
func check(value: bool,label: String) -> void:
	if value: passed += 1
	else:
		failed += 1
		push_error("DUNGEON FAIL: " + label)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	for action: String in ["move_left","move_right","attack","dash","parry","jump","climb_up","climb_down"]:
		if not InputMap.has_action(action): InputMap.add_action(action)
	fixture_game = MapGame.new()
	root.add_child(fixture_game)
	map = Level.new()
	fixture_game.level = map
	root.add_child(map)
	map.setup(null)
	await physics_frame
	check_graph()
	check_regions()
	await check_doors()
	await check_climb_paths()
	map.queue_free()
	fixture_game.queue_free()
	await process_frame
	print("Dungeon layout: %d passed, %d failed" % [passed,failed])
	quit(1 if failed else 0)
func gap_x(a: Rect2,b: Rect2) -> float:
	return maxf(0.0,maxf(b.position.x-a.end.x,a.position.x-b.end.x))
func can_jump(a: Rect2,b: Rect2) -> bool:
	var rise: float = a.position.y-b.position.y
	if rise > 56 or rise < -72: return false
	return gap_x(a,b) <= (54 if rise > 8 else 100)
func can_fall(a: Rect2,b: Rect2) -> bool:
	if b.position.y <= a.position.y+56: return false
	for x: float in [a.position.x-9,a.end.x+9]:
		if x-7 < b.position.x or x+7 > b.end.x: continue
		var shaft: Rect2 = Rect2(x-7,a.position.y+1,14,b.position.y-a.position.y-2)
		var blocked: bool = false
		for p: Rect2 in Level.PLATFORMS:
			if p == a or p == b: continue
			if shaft.intersects(p): blocked = true
		if not blocked: return true
	return false
func near_chain(p: Rect2,entry: Dictionary) -> bool:
	var r: Rect2 = entry["rect"]
	var x: float = r.get_center().x
	return p.position.y >= r.position.y and p.position.y <= r.end.y and x >= p.position.x-64 and x <= p.end.x+64
func can_climb(a: Rect2,b: Rect2) -> bool:
	for entry: Dictionary in Level.CLIMBABLES:
		if near_chain(a,entry) and near_chain(b,entry): return true
	return false
func check_graph() -> void:
	# Exactly one seed: the nearest floor under SPAWN. Never mark every solid as reachable.
	var count: int = Level.PLATFORMS.size()
	var reached: Array[bool] = []
	reached.resize(count)
	reached.fill(false)
	var seed: int = -1
	var nearest: float = INF
	for i: int in count:
		var p: Rect2 = Level.PLATFORMS[i]
		if Level.SPAWN.x >= p.position.x and Level.SPAWN.x <= p.end.x and p.position.y >= Level.SPAWN.y and p.position.y < nearest:
			seed = i
			nearest = p.position.y
	check(seed >= 0,"SPAWN has a supporting floor")
	if seed < 0: return
	reached[seed] = true
	var changed: bool = true
	while changed:
		changed = false
		for i: int in count:
			if not reached[i]: continue
			for j: int in count:
				if reached[j]: continue
				var a: Rect2 = Level.PLATFORMS[i]
				var b: Rect2 = Level.PLATFORMS[j]
				if can_jump(a,b) or can_fall(a,b) or can_climb(a,b):
					reached[j] = true
					changed = true
	for i: int in count:
		check(reached[i],"SPAWN graph reaches terrain %d at %s" % [i,str(Level.PLATFORMS[i])])
	# Doors have no inaccessible keys: crypt/archive operate from either side; the hatch lever is on the lower route.
	check(map.try_interact(Vector2(663,500)),"crypt door is reachable from its entry-side floor")
	check(map.try_interact(Vector2(1712,500)),"shortcut lever is reachable on the lower route")
	map.reset_interactions()
func check_regions() -> void:
	for entry: Dictionary in Level.CLIMBABLES:
		var r: Rect2 = entry["rect"]
		var x: float = r.get_center().x
		check(map.climb_at(Vector2(x,r.position.y)).get("id","") == entry["id"],"chain top included "+str(entry["id"]))
		check(map.climb_at(Vector2(x,r.end.y)).get("id","") == entry["id"],"chain bottom included "+str(entry["id"]))
		check(map.climb_at(Vector2(x,r.position.y-0.01)).is_empty(),"chain above outside "+str(entry["id"]))
	for r: Rect2 in Level.WATER_REGIONS:
		check(map.water_at(r.position),"water leading/surface boundary")
		check(map.water_at(r.end),"water trailing/floor boundary")
		check(not map.water_at(r.end+Vector2(0.01,0)),"water x outside")
		check(not map.water_at(r.position-Vector2(0,0.01)),"water above surface outside")
	check(not Level.CHECKPOINT_RECT.has_point(Vector2(1860,48)),"upper route cannot activate shrine by x alone")
	check(Level.CHECKPOINT_RECT.has_point(Level.CHECKPOINT),"real shrine spawn is in spatial trigger")
	check(Level.FALL_LIMIT > 680,"crypt is above real fall limit")
	check(map.interaction_hint(Vector2(90,260)).is_empty(),"no irrelevant interaction hint at spawn")
func ray_hits(from: Vector2,to: Vector2) -> bool:
	var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(from,to,1)
	return not map.get_world_2d().direct_space_state.intersect_ray(query).is_empty()
func settle() -> void:
	await physics_frame
	await physics_frame
func check_doors() -> void:
	map.reset_interactions()
	await settle()
	check(ray_hits(Vector2(656,450),Vector2(696,450)),"closed crypt door physically blocks")
	check(not map.try_interact(Vector2(676,476)+Vector2(36.01,0)),"interaction rejects outside radius")
	check(map.try_interact(Vector2(676,476)+Vector2(36,0)),"interaction includes exact radius")
	await settle()
	check(not ray_hits(Vector2(656,450),Vector2(696,450)),"opened crypt door physically clears")
	check(not map.try_interact(Vector2(676,476)),"opened door does not reopen/reward twice")
	check(ray_hits(Vector2(1762,304),Vector2(1762,348)),"closed shortcut hatch blocks chain")
	check(map.try_interact(Vector2(1712,500)),"lower lever opens shortcut")
	await settle()
	check(not ray_hits(Vector2(1762,304),Vector2(1762,348)),"shortcut hatch physically clears")
	check(ray_hits(Vector2(1228,-20),Vector2(1268,-20)),"archive door physically blocks")
	check(map.try_interact(Vector2(1261,48)),"archive door operates from reward side")
	await settle()
	check(not ray_hits(Vector2(1228,-20),Vector2(1268,-20)),"archive door physically clears")
	check(map.get_opened_ids().size() == 3,"three stable opened IDs")
	map.restore_opened_ids(["crypt_door","shortcut_hatch","unknown"])
	await settle()
	check(map.get_opened_ids().size() == 2,"restore accepts only known door IDs")
	check(ray_hits(Vector2(1228,-20),Vector2(1268,-20)),"restore closes unlisted door")
	map.reset_interactions()
	await settle()
	check(map.get_opened_ids().is_empty(),"new-run reset closes all doors")
	check(ray_hits(Vector2(656,450),Vector2(696,450)),"reset restores physical crypt collision")
func make_probe(at: Vector2) -> CharacterBody2D:
	var body: CharacterBody2D = Player.new()
	body.configure(fixture_game)
	fixture_game.add_child(body)
	body.set_physics_process(false)
	body.position = at
	return body
func check_climb_paths() -> void:
	map.restore_opened_ids(["crypt_door","shortcut_hatch","archive_door"])
	await settle()
	for entry: Dictionary in Level.CLIMBABLES:
		var r: Rect2 = entry["rect"]
		var x: float = r.get_center().x
		var probe: CharacterBody2D = make_probe(Vector2(x,r.end.y-1))
		await physics_frame
		var collision: KinematicCollision2D = probe.move_and_collide(Vector2(0,r.position.y-probe.position.y))
		check(collision == null,"14x26 body can climb shaft upward "+str(entry["id"]))
		collision = probe.move_and_collide(Vector2(0,r.end.y-1-probe.position.y))
		check(collision == null,"14x26 body can descend shaft "+str(entry["id"]))
		# Exercise real Player input/traversal at the bottom endpoint, not only its collider.
		probe.revive(Vector2(x,r.end.y-12))
		Input.action_press("climb_down")
		var attached_bottom: bool = false
		for frame in range(16):
			await physics_frame
			probe._physics_process(1.0/60.0)
			attached_bottom = attached_bottom or probe.climbing
		Input.action_release("climb_down")
		check(attached_bottom and not probe.climbing and absf(probe.position.y-r.end.y) < 2.0,"actual Player exits grounded chain bottom "+str(entry["id"]))
		probe.revive(Vector2(x,r.position.y+12))
		Input.action_press("climb_up")
		var attached_top: bool = false
		for frame in range(16):
			await physics_frame
			probe._physics_process(1.0/60.0)
			attached_top = attached_top or probe.climbing
			if attached_top and not probe.climbing: break
		Input.action_release("climb_up")
		check(attached_top and not probe.climbing and absf(probe.position.y-r.position.y) < 2.0,"actual Player releases at chain top "+str(entry["id"]))
		Input.action_press("move_right")
		var landed: bool = false
		for frame in range(48):
			await physics_frame
			probe._physics_process(1.0/60.0)
			if probe.is_on_floor():
				landed = true
				break
		check(landed,"chain top has a real right-hand landing "+str(entry["id"]))
		if landed:
			check(absf(probe.position.y-(300.0 if r.position.y > 100 else 48.0)) < 2.0,"top exit lands on expected deck "+str(entry["id"]))
		Input.action_release("move_right")
		probe.queue_free()
		await physics_frame

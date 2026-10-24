extends SceneTree
## Geometry arithmetic only. Reachability is checked from SPAWN by dungeon_layout_test.
const Level = preload("res://levels/bellkeep.gd")
const OLD_SHARDS: Array[Vector2] = [Vector2(372,232),Vector2(490,188),Vector2(648,144),Vector2(816,120),Vector2(956,164),Vector2(1092,206),Vector2(1248,224),Vector2(1460,276),Vector2(1584,228),Vector2(1970,276),Vector2(2392,276),Vector2(2914,186),Vector2(2158,232),Vector2(2300,188),Vector2(2440,232)]
var passed: int = 0
var failed: int = 0
func check(value: bool, label: String) -> void:
	if value: passed += 1
	else:
		failed += 1
		push_error("FAIL " + label)
func _initialize() -> void:
	var plats: Array[Rect2] = Level.PLATFORMS
	for i: int in plats.size():
		check(plats[i].size.x >= 14 and plats[i].size.y > 0, "nonempty terrain %d" % i)
		for j: int in range(i+1, plats.size()):
			check(not plats[i].intersects(plats[j]), "terrain %d/%d does not overlap" % [i,j])
	for k: int in Level.SHARDS.size():
		var at: Vector2 = Level.SHARDS[k]
		var over: bool = false
		for p: Rect2 in plats:
			if at.x >= p.position.x and at.x <= p.end.x and absf(at.y - p.position.y + 24) <= 2:
				over = true
		check(over, "shard %d over real floor" % k)
	for i: int in OLD_SHARDS.size():
		check(Level.SHARDS[i] == OLD_SHARDS[i], "original shard index %d preserved" % i)
	for entry: Dictionary in Level.ENEMIES:
		var at: Vector2 = entry["at"]
		var over: bool = false
		for p: Rect2 in plats:
			if at.x >= p.position.x and at.x <= p.end.x and at.y <= p.position.y + 2:
				over = true
		check(over, "enemy %s over terrain" % str(at))
	var main: Array[Rect2] = []
	for p: Rect2 in plats:
		if p.position.y == 300 and p.size.y > 16:
			main.append(p)
	main.sort_custom(func(a: Rect2,b: Rect2) -> bool: return a.position.x < b.position.x)
	for i: int in range(1,main.size()):
		check(main[i].position.x-main[i-1].end.x <= 100, "legacy route gap %d remains jumpable" % i)
	for z: int in range(1,Level.ZONES.size()):
		check(float(Level.ZONES[z]["x"]) > float(Level.ZONES[z-1]["x"]), "legacy zone %d ordered" % z)
	check(Level.ENEMIES.size() == 11, "eleven authored encounters")
	check(Level.BOSS_TRIGGER_X == 2640 and Level.BOSS_POSITION == Vector2(2990,250), "Boss contract unchanged")
	print("Level layout: %d passed, %d failed" % [passed,failed])
	quit(1 if failed else 0)

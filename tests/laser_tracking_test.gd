extends SceneTree
## Synthetic checks for half-beat volley clustering and one-shot center re-aim.
const Planner = preload("res://combat/friend_rhythm/laser_formation_planner.gd")
const Hazard = preload("res://combat/boss_hazard.gd")

const WINDOW: float = 0.5 * 60.0 / 203.0

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

func config() -> Dictionary:
	return {"line_thickness": 9.0, "patterns": {
		"diamond": {"safe_radius": 44.0, "safe_offsets": [[0.0, 0.0]]},
		"parallel": {"line_offsets": [-36.0, -12.0, 12.0, 36.0], "safe_offsets": [[0.0, 0.0]]},
		"grid": {"vertical_half_gap": 64.0, "horizontal_half_gap": 43.0, "safe_offsets": [[0.0, 0.0]]},
		"rotating": {"safe_radius": 38.0, "safe_offsets": [[0.0, 0.0]]},
	}}

func formation(pattern: String, index: int = 0) -> Dictionary:
	var lasers: Array[Dictionary] = []
	for line: int in 4:
		lasers.append({"time": 9.0 + float(line) * 0.1, "damage_time": 10.0 + float(line) * 0.1, "source_index": line})
	return {"index": index, "occurrence": 0, "pattern": pattern, "lasers": lasers}

func arena_at(center: Vector2) -> Rect2:
	return Rect2(center - Vector2(360.0, 220.0), Vector2(720.0, 440.0))

func run() -> void:
	var arena: Rect2 = arena_at(Vector2(400, 280))
	var center: Vector2 = arena.get_center()
	for pattern: String in ["diamond", "parallel", "grid", "rotating"]:
		var lines: Array[Dictionary] = Planner.build_lines(formation(pattern), config(), arena)
		var ok: bool = lines.size() == 4
		for line: Dictionary in lines:
			var carries_offset: bool = typeof(line.get("center_offset")) == TYPE_VECTOR2
			ok = ok and carries_offset
			if carries_offset:
				var offset: Vector2 = line["center_offset"]
				var origin: Vector2 = line["origin"]
				ok = ok and origin.is_equal_approx(center + offset)
		check(ok, pattern + " lines carry an exact center offset")

	var center_a: Vector2 = Vector2(400, 280)
	var center_b: Vector2 = Vector2(520, 300)
	var lines_a: Array[Dictionary] = Planner.build_lines(formation("diamond"), config(), arena_at(center_a))
	var lines_b: Array[Dictionary] = Planner.build_lines(formation("diamond"), config(), arena_at(center_b))
	var rebase_ok: bool = true
	for index: int in 4:
		var offset_a: Vector2 = lines_a[index].get("center_offset", Vector2.ZERO)
		var rebased: Vector2 = center_b + offset_a
		var built: Vector2 = lines_b[index]["origin"]
		rebase_ok = rebase_ok and rebased.is_equal_approx(built)
		rebase_ok = rebase_ok and is_equal_approx(float(lines_a[index]["angle_radians"]), float(lines_b[index]["angle_radians"]))
		for other: int in 4:
			var origin_a: Vector2 = lines_a[index]["origin"]
			var origin_b: Vector2 = lines_a[other]["origin"]
			var other_offset: Vector2 = lines_a[other].get("center_offset", Vector2.ZERO)
			var moved_a: Vector2 = center_b + offset_a
			var moved_b: Vector2 = center_b + other_offset
			rebase_ok = rebase_ok and is_equal_approx(origin_a.distance_to(origin_b), moved_a.distance_to(moved_b))
	check(rebase_ok, "re-basing to a new center preserves distances and angles")

	var grid: Array[Dictionary] = Planner.build_lines(formation("grid"), config(), arena)
	var offsets: Array[Vector2] = []
	for line: Dictionary in grid:
		offsets.append(line.get("center_offset", Vector2.ZERO))
	check(offsets[0].is_equal_approx(Vector2(-64.0, -240.0)) and offsets[1].is_equal_approx(Vector2(64.0, -240.0)) and offsets[2].is_equal_approx(Vector2(-380.0, -43.0)) and offsets[3].is_equal_approx(Vector2(-380.0, 43.0)), "grid keeps its full-arena offsets")

	print("LASER_TRACKING_TEST: %d passed, %d failed" % [passed, failed])
	quit(1 if failed > 0 else 0)

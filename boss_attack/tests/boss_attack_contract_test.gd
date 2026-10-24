extends SceneTree

const PARSER_SCRIPT := preload("res://scripts/chart_parser.gd")
const SLOTS_SCRIPT := preload("res://scripts/boss_move_slots.gd")
const PLANNER_SCRIPT := preload("res://scripts/boss_attack_planner.gd")
const LASER_PLANNER_SCRIPT := preload("res://scripts/laser_formation_planner.gd")

var passed := 0
var failed := 0


func _initialize() -> void:
	test_attack_plans()
	test_cube_diagonals()
	test_laser_geometries()
	print("BOSS ATTACK RESULTS: %d passed, %d failed" % [passed, failed])
	quit(1 if failed > 0 else 0)


func test_attack_plans() -> void:
	var slots = SLOTS_SCRIPT.new()
	assert_true(slots.load_config("res://data/boss_moves.json"), "boss pattern config loads")
	var beat := 60.0 / 203.0
	var arena := Rect2(84.0, 38.0, 542.0, 310.0)
	var boss_position := Vector2(320.0, 108.0)
	var locked_player := Vector2(450.0, 300.0)

	var move_1: Dictionary = slots.get_normal_pattern(0)
	var plan_1: Dictionary = PLANNER_SCRIPT.build_plan(move_1, 10.0, beat, boss_position, locked_player, arena)
	var actions_1: Array = plan_1["actions"]
	assert_eq(actions_1.size(), 3, "move 1 has aim, dash and ring")
	assert_eq(actions_1[0]["type"], "aim", "move 1 first half aims")
	assert_eq(actions_1[1]["type"], "dash", "move 1 second half dashes")
	assert_close(float(actions_1[1]["time"]), 10.0 + 2.0 * beat, 0.0001, "move 1 dash starts on beat 2")
	assert_eq(actions_1[2]["count"], 8, "move 1 ends with eight-way ring")
	assert_eq(plan_1["locked_player"], locked_player, "dash keeps trigger-time lock")

	var move_4: Dictionary = slots.get_normal_pattern(3)
	var plan_4: Dictionary = PLANNER_SCRIPT.build_plan(move_4, 20.0, beat, boss_position, locked_player, arena)
	var rings: Array = (plan_4["actions"] as Array).filter(func(action: Dictionary) -> bool: return action["type"] == "ring")
	assert_eq(rings.size(), 2, "move 4 has two rings")
	assert_close(float(rings[1]["angle_offset_degrees"]), 22.5, 0.0001, "move 4 second ring is offset")

	var fast_3: Dictionary = slots.get_fast_pattern(2)
	var plan_fast_3: Dictionary = PLANNER_SCRIPT.build_plan(fast_3, 30.0, beat, boss_position, locked_player, arena)
	assert_eq((plan_fast_3["actions"] as Array).size(), 4, "fast double-dash has four beats")
	assert_eq((plan_fast_3["actions"] as Array).filter(func(action: Dictionary) -> bool: return action["type"] == "dash").size(), 2, "fast group 3 has two dashes")
	slots.free()


func test_cube_diagonals() -> void:
	var slots = SLOTS_SCRIPT.new()
	slots.load_config("res://data/boss_moves.json")
	var parameters: Dictionary = slots.get_fixed_pattern().get("parameters", {})
	var arena := Rect2(84.0, 38.0, 542.0, 310.0)
	var square: Dictionary = PLANNER_SCRIPT.build_fixed_cube(parameters, 10.0, 60.0 / 203.0, Vector2(320, 108), arena, 0, false)
	var diamond: Dictionary = PLANNER_SCRIPT.build_fixed_cube(parameters, 10.0, 60.0 / 203.0, Vector2(320, 108), arena, 0, true)
	assert_false(square["diamond"], "square orientation produces X diagonals")
	assert_true(diamond["diamond"], "diamond orientation produces + diagonals")
	assert_close(float(square["flight_end_time"]), float(square["start_time"]) + 2.0 * 60.0 / 203.0, 0.0001, "cube flies for two beats")
	assert_true(float(square["damage_time"]) > float(square["flight_end_time"]), "cube warns after stopping")
	assert_true(arena.has_point(square["to"]), "cube target stays in arena")
	slots.free()


func test_laser_geometries() -> void:
	var slots = SLOTS_SCRIPT.new()
	slots.load_config("res://data/boss_moves.json")
	var config: Dictionary = slots.get_laser_formations()
	var arena := Rect2(84.0, 38.0, 542.0, 310.0)
	for pattern in ["diamond", "parallel", "grid", "rotating"]:
		var records: Array[Dictionary] = []
		for index in 4:
			records.append({
				"time": 10.0 + index * 0.5,
				"damage_time": 10.2 + index * 0.5,
				"source_index": index,
			})
		var formation := {
			"index": 0,
			"pattern": pattern,
			"occurrence": 0,
			"lasers": records,
			"active_until": 13.0,
		}
		var lines: Array = LASER_PLANNER_SCRIPT.build_lines(formation, config, arena)
		assert_eq(lines.size(), 4, "%s formation has four full-screen lines" % pattern)
		assert_eq(float(lines[0]["angle_radians"]), float(lines[1]["angle_radians"]) if pattern == "parallel" else float(lines[0]["angle_radians"]), "line angles are deterministic")
		assert_true(float(lines[3]["active_until"]) > float(lines[3]["damage_time"]), "%s lines remain active" % pattern)
		assert_true(_has_safe_sample(lines, arena), "%s formation leaves a dodgeable gap" % pattern)
		if pattern == "grid":
			assert_close(float(lines[0]["angle_radians"]), PI * 0.5, 0.0001, "grid starts with vertical line")
			assert_close(float(lines[2]["angle_radians"]), 0.0, 0.0001, "grid includes horizontal line")
		if pattern == "parallel":
			assert_close(float(lines[0]["angle_radians"]), float(lines[1]["angle_radians"]), 0.0001, "parallel lines share angle")

	var mirrored := {
		"index": 1,
		"pattern": "parallel",
		"occurrence": 1,
		"lasers": [
			{"time": 1, "damage_time": 2, "source_index": 0},
			{"time": 1.5, "damage_time": 2.5, "source_index": 1},
			{"time": 2, "damage_time": 3, "source_index": 2},
			{"time": 2.5, "damage_time": 3.5, "source_index": 3},
		],
		"active_until": 4,
	}
	var mirrored_lines: Array = LASER_PLANNER_SCRIPT.build_lines(mirrored, config, arena)
	assert_close(float(mirrored_lines[0]["angle_radians"]), deg_to_rad(135.0), 0.0001, "parallel formation mirrors on the next call")

	var parser = PARSER_SCRIPT.new()
	assert_true(parser.parse_file("res://data/if_infinity.chart.json", 203.0, 245.0, 4.0), "reference chart parses")
	var generic_count: int = int(parser.laser_count) - int(parser.fixed_attack_event_count) * 2
	var built_count := 0
	for formation in parser.laser_formations:
		built_count += LASER_PLANNER_SCRIPT.build_lines(formation, config, arena).size()
	assert_eq(built_count, generic_count, "non-fixed chart lasers receive geometry")
	slots.free()


func _has_safe_sample(lines: Array, arena: Rect2) -> bool:
	for x in range(5, 21):
		for y in range(5, 21):
			var point := Vector2(
				arena.position.x + arena.size.x * float(x) / 20.0,
				arena.position.y + arena.size.y * float(y) / 20.0
			)
			var safe := true
			for line in lines:
				var origin: Vector2 = line["origin"]
				var normal := Vector2.from_angle(float(line["angle_radians"]) + PI * 0.5)
				if absf((point - origin).dot(normal)) <= float(line["thickness"]) * 0.5 + 10.0:
					safe = false
					break
			if safe:
				return true
	return false


func assert_true(value: bool, label: String) -> void:
	if value:
		passed += 1
	else:
		failed += 1
		push_error("FAIL %s" % label)


func assert_false(value: bool, label: String) -> void:
	assert_true(not value, label)


func assert_eq(actual: Variant, expected: Variant, label: String) -> void:
	if actual == expected:
		passed += 1
	else:
		failed += 1
		push_error("FAIL %s: expected %s, got %s" % [label, expected, actual])


func assert_close(actual: float, expected: float, tolerance: float, label: String) -> void:
	if absf(actual - expected) <= tolerance:
		passed += 1
	else:
		failed += 1
		push_error("FAIL %s: expected %.8f, got %.8f" % [label, expected, actual])

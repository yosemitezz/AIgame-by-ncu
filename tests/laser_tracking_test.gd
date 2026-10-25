extends SceneTree
## Synthetic checks for half-beat volley clustering and one-shot center re-aim.
const Planner = preload("res://combat/friend_rhythm/laser_formation_planner.gd")
const Hazard = preload("res://combat/boss_hazard.gd")

const WINDOW: float = 0.5 * 60.0 / 203.0

class Clock extends Node:
	var time: float = 0.0
	func get_score_time() -> float:
		return time

class ProbePlayer extends Node2D:
	var dead: bool = false
	var health: int = 8
	func receive_hit(_amount: int, _at: Vector2) -> void:
		pass

class ProbeBoss extends Node:
	var dead: bool = false
	var hazard_generation: int = 1
	var player: Node2D
	func get_laser_arena() -> Rect2:
		return Rect2(player.global_position - Vector2(360.0, 240.0), Vector2(720.0, 440.0))

class GameProbe extends Node:
	var music: Node
	var player: ProbePlayer
	var story_safe: bool = false
	var _paused: bool = false
	var outcome: String = ""
	var damage_requests: int = 0
	func emit_fx(_kind: String, _at: Vector2, _direction: Vector2 = Vector2.ZERO, _power: float = 1.0) -> void:
		pass
	func damage_player(amount: int, at: Vector2) -> void:
		damage_requests += 1
		player.receive_hit(amount, at)

var passed: int = 0
var failed: int = 0
var games: Array[Node] = []

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

func make_fixture(created_at: float) -> Dictionary:
	var game := GameProbe.new()
	var clock := Clock.new()
	var player := ProbePlayer.new()
	player.position = Vector2(400, 300)
	var boss := ProbeBoss.new()
	boss.player = player
	game.music = clock
	game.player = player
	game.add_child(clock)
	game.add_child(player)
	game.add_child(boss)
	root.add_child(game)
	games.append(game)
	clock.time = created_at
	return {"game": game, "clock": clock, "player": player, "boss": boss}

func volley_formation() -> Dictionary:
	var lasers: Array[Dictionary] = [
		{"time": 9.5, "damage_time": 10.5, "source_index": 0},
		{"time": 9.6, "damage_time": 10.6, "source_index": 1},
		{"time": 11.5, "damage_time": 12.5, "source_index": 2},
		{"time": 11.6, "damage_time": 12.6, "source_index": 3},
	]
	return {"index": 0, "occurrence": 0, "pattern": "diamond", "lasers": lasers}

func make_hazard(fixture: Dictionary) -> Variant:
	var game: GameProbe = fixture["game"]
	var boss: ProbeBoss = fixture["boss"]
	var arena: Rect2 = boss.get_laser_arena()
	var lines: Array[Dictionary] = Planner.build_lines(volley_formation(), config(), arena)
	var hazard: Variant = Hazard.new()
	game.add_child(hazard)
	hazard.configure_lines(game, boss, lines, arena, 1, "diamond", WINDOW)
	hazard.set_physics_process(false)
	fixture["hazard"] = hazard
	return hazard

func line_count(hazard: Variant) -> int:
	var value: Array = hazard.lines
	return value.size()

func step(fixture: Dictionary, at: float) -> void:
	var clock: Clock = fixture["clock"]
	clock.time = at
	var hazard: Variant = fixture["hazard"]
	hazard._physics_process(1.0 / 60.0)

func point_at(line: Variant, key: String) -> Vector2:
	var value: Vector2 = line[key]
	return value

func same_geometry(left: Variant, right: Variant) -> bool:
	var left_dict: Dictionary = left
	var right_dict: Dictionary = right
	if left_dict.size() != right_dict.size():
		return false
	if typeof(left_dict.get("center_offset")) == TYPE_VECTOR2:
		var left_offset: Vector2 = left_dict["center_offset"]
		var right_offset: Vector2 = right_dict["center_offset"]
		if not left_offset.is_equal_approx(right_offset):
			return false
	for key: String in ["origin", "a", "b", "angle_radians", "thickness", "warning_time", "damage_time", "active_until"]:
		if typeof(left_dict.get(key)) == TYPE_VECTOR2:
			if not point_at(left_dict, key).is_equal_approx(point_at(right_dict, key)):
				return false
		elif not is_equal_approx(float(left_dict[key]), float(right_dict[key])):
			return false
	return true

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

	var fixture: Dictionary = make_fixture(8.0)
	var hazard: Variant = make_hazard(fixture)
	var spawn: Dictionary = hazard.get_geometry_snapshot()
	var spawn_tracking: Dictionary = spawn.get("tracking", {})
	check(int(spawn_tracking.get("clusters", -1)) == 2 and int(spawn_tracking.get("aimed", -1)) == 0 and is_equal_approx(float(spawn_tracking.get("window", -1.0)), WINDOW), "four lines cluster into two half-beat volleys")
	var spawn_lines: Array = spawn["lines"]

	var game: GameProbe = fixture["game"]
	game.player.global_position = Vector2(460, 300)
	var aimed_center: Vector2 = Vector2(460, 280)
	step(fixture, 9.5)
	var first: Dictionary = hazard.get_geometry_snapshot()
	var first_lines: Array = first["lines"]
	var first_tracking: Dictionary = first.get("tracking", {})
	var first_ok: bool = int(first_tracking.get("aimed", -1)) == 1
	for index: int in [0, 1]:
		var offset: Vector2 = first_lines[index]["center_offset"]
		first_ok = first_ok and point_at(first_lines[index], "origin").is_equal_approx(aimed_center + offset)
		first_ok = first_ok and (point_at(first_lines[index], "a") - point_at(spawn_lines[index], "a")).is_equal_approx(Vector2(60.0, 0.0))
		first_ok = first_ok and (point_at(first_lines[index], "b") - point_at(spawn_lines[index], "b")).is_equal_approx(Vector2(60.0, 0.0))
	for index: int in [2, 3]:
		first_ok = first_ok and same_geometry(first_lines[index], spawn_lines[index])
	check(first_ok, "first volley re-centers once on the moved player")

	game.player.global_position = Vector2(340, 300)
	step(fixture, 11.5)
	var second: Dictionary = hazard.get_geometry_snapshot()
	var second_lines: Array = second["lines"]
	var second_tracking: Dictionary = second.get("tracking", {})
	var second_ok: bool = int(second_tracking.get("aimed", -1)) == 2
	for index: int in [2, 3]:
		var offset: Vector2 = second_lines[index]["center_offset"]
		second_ok = second_ok and point_at(second_lines[index], "origin").is_equal_approx(Vector2(340, 280) + offset)
		second_ok = second_ok and (point_at(second_lines[index], "a") - point_at(spawn_lines[index], "a")).is_equal_approx(Vector2(-60.0, 0.0))
	for index: int in [0, 1]:
		second_ok = second_ok and same_geometry(second_lines[index], first_lines[index])
	check(second_ok, "second volley re-centers while the first stays put")

	game.player.global_position = Vector2(520, 300)
	step(fixture, 11.8)
	var frozen: Dictionary = hazard.get_geometry_snapshot()
	var frozen_tracking: Dictionary = frozen.get("tracking", {})
	var frozen_ok: bool = int(frozen_tracking.get("aimed", -1)) == 2
	for index: int in 4:
		frozen_ok = frozen_ok and same_geometry(frozen["lines"][index], second_lines[index])
	check(frozen_ok, "later movement never re-aims an aimed volley")

	var late: Dictionary = make_fixture(9.8)
	var late_hazard: Variant = make_hazard(late)
	var late_spawn: Array = late_hazard.get_geometry_snapshot()["lines"]
	var late_tracking: Dictionary = late_hazard.get_geometry_snapshot().get("tracking", {})
	var late_aimed: bool = int(late_tracking.get("aimed", -1)) == 1
	var late_game: GameProbe = late["game"]
	late_game.player.global_position = Vector2(460, 300)
	step(late, 10.0)
	var late_after: Array = late_hazard.get_geometry_snapshot()["lines"]
	var late_ok: bool = late_aimed
	for index: int in [0, 1]:
		late_ok = late_ok and same_geometry(late_after[index], late_spawn[index])
	check(late_ok, "a volley already in warning when created never moves")

	var cube_fixture: Dictionary = make_fixture(8.0)
	var cube_game: GameProbe = cube_fixture["game"]
	var cube_boss: ProbeBoss = cube_fixture["boss"]
	var cube_plan: Dictionary = {"from": Vector2(400, 120), "to": Vector2(400, 280), "start_time": 8.0, "flight_end_time": 9.0, "damage_time": 9.2, "active_until": 9.9, "diamond": false, "thickness": 7.0}
	var cube: Variant = Hazard.new()
	cube_game.add_child(cube)
	cube.configure_cube(cube_game, cube_boss, cube_plan, cube_boss.get_laser_arena(), 1)
	cube.set_physics_process(false)
	var cube_spawn: Array = cube.get_geometry_snapshot()["lines"]
	var cube_tracking: Dictionary = cube.get_geometry_snapshot().get("tracking", {})
	check(int(cube_tracking.get("clusters", -1)) == 0 and cube_spawn.size() == 2, "cubes never cluster and keep their two authored lines")
	cube_game.player.global_position = Vector2(520, 300)
	cube_fixture["hazard"] = cube
	step(cube_fixture, 9.05)
	var cube_ok: bool = true
	for index: int in 2:
		cube_ok = cube_ok and same_geometry(cube.get_geometry_snapshot()["lines"][index], cube_spawn[index])
	check(cube_ok, "cubes never re-aim")

	var one: Dictionary = make_fixture(8.0)
	var one_hazard: Variant = make_hazard(one)
	var one_ok: bool = one_hazard.get_child_count() == 0 and line_count(one_hazard) == 4
	step(one, 9.5)
	step(one, 11.5)
	one_ok = one_ok and one_hazard.get_child_count() == 0 and line_count(one_hazard) == 4
	check(one_ok, "two volleys stay inside one hazard and spawn no child")

	for game_node: Node in games:
		game_node.free()
	await process_frame
	print("LASER_TRACKING_TEST: %d passed, %d failed" % [passed, failed])
	quit(1 if failed > 0 else 0)

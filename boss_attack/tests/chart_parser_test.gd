extends SceneTree

const PARSER_SCRIPT := preload("res://scripts/chart_parser.gd")

var passed := 0
var failed := 0


func _initialize() -> void:
	test_reference_chart()
	test_exact_beat_grouping()
	print("CHART RESULTS: %d passed, %d failed" % [passed, failed])
	quit(1 if failed > 0 else 0)


func test_reference_chart() -> void:
	var parser = PARSER_SCRIPT.new()
	var ok: bool = parser.parse_file("res://data/if_infinity.chart.json", 203.0, 245.0, 4.0)
	assert_true(ok, "reference chart parses: %s" % [parser.errors])
	assert_eq(parser.note_count, 1148, "note record count")
	assert_eq(parser.timed_note_count, 1147, "playable timed note count")
	assert_eq(parser.unique_time_count, 920, "unique exact beat count")
	assert_eq(parser.normal_timing_group_count, 794, "timing group count")
	assert_eq(parser.heavy_group_count, 106, "heavy group count")
	assert_eq(parser.laser_count, 130, "laser count")
	assert_eq(parser.phase_count, 23, "phase count")
	assert_close(parser.bpm, 203.0, 0.0001, "configured BPM")
	assert_close(parser.offset_ms, 245.0, 0.0001, "configured offset")

	var first_heavy: Dictionary = parser.heavy_groups[0]
	assert_eq(first_heavy["beat_key"], "73:0:4", "first heavy exact beat")
	assert_close(float(first_heavy["time"]), 21.82135468, 0.0001, "first heavy music time")

	var first_laser: Dictionary = parser.lasers[0]
	assert_eq(first_laser["beat_key"], "297:0:4", "first laser warning beat")
	assert_eq(first_laser["endbeat_key"], "301:0:4", "first laser damage beat")
	assert_close(float(first_laser["time"]), 88.02825123, 0.0001, "first laser warning time")


func test_exact_beat_grouping() -> void:
	var document := {
		"note": [
			{"beat": [1, 0, 4], "column": 1},
			{"beat": [1, 0, 4], "column": 2},
			{"beat": [1, 0, 4], "column": 3},
			{"beat": [1, 0, 4], "column": 0},
			{"beat": [1, 0, 2], "column": 1},
			{"beat": [1, 0, 2], "column": 2},
			{"beat": [3, 0, 4], "endbeat": [4, 0, 4], "column": 2},
			{"beat": [0, 0, 1], "sound": "ignored.ogg", "offset": 245},
			{"beat": [9, 0, 4], "column": 0},
		],
	}
	var parser = PARSER_SCRIPT.new()
	var ok: bool = parser.parse_text(JSON.stringify(document), 203.0, 245.0, 4.0)
	assert_true(ok, "synthetic chart parses: %s" % [parser.errors])
	assert_eq(parser.note_count, 9, "all note records counted")
	assert_eq(parser.timed_note_count, 8, "sound record excluded from timing")
	assert_eq(parser.unique_time_count, 4, "exact beat keys define unique times")
	assert_eq(parser.normal_timing_group_count, 3, "normal timing groups")
	assert_eq(parser.heavy_group_count, 1, "columns 1/2/3 make a heavy group")
	assert_eq(parser.laser_count, 1, "endbeat creates a laser")
	assert_eq(parser.phase_count, 2, "gap over four beats starts a phase")
	assert_true(parser.heavy_groups[0]["columns"].has(0), "column zero may coexist with heavy")
	assert_false(parser.timing_groups[1]["is_heavy"], "equal float beats with different triples stay separate")


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


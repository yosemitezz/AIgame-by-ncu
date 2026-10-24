extends SceneTree

const PARSER_SCRIPT := preload("res://scripts/chart_parser.gd")

var passed := 0
var failed := 0


func _initialize() -> void:
	test_reference_chart()
	test_equal_interval_pairs_and_laser_pairs()
	print("CHART RESULTS: %d passed, %d failed" % [passed, failed])
	quit(1 if failed > 0 else 0)


func test_reference_chart() -> void:
	var parser = PARSER_SCRIPT.new()
	var ok: bool = parser.parse_file("res://data/if_infinity.chart.json", 203.0, 245.0, 4.0)
	assert_true(ok, "reference chart parses: %s" % [parser.errors])
	assert_eq(parser.note_count, 1172, "new note record count")
	assert_eq(parser.timed_note_count, 1171, "new playable timed note count")
	assert_eq(parser.unique_time_count, 862, "new unique exact beat count")
	assert_eq(parser.normal_timing_group_count, 703, "new timing group count")
	assert_eq(parser.heavy_group_count, 107, "new heavy group count")
	assert_eq(parser.laser_count, 230, "new laser count")
	assert_eq(parser.phase_count, 21, "new phase count")
	assert_eq(parser.paired_note_group_count, 315, "two-note group count")
	assert_eq(parser.action_phrase_count, 228, "attack phrase count")
	assert_eq(parser.fixed_attack_event_count, 24, "same-beat laser pair count")
	assert_eq(parser.laser_formation_count, 48, "generic laser formation count")
	var basic_phrases: int = parser.action_phrases.filter(func(phrase: Dictionary) -> bool: return phrase["mode"] == "basic").size()
	var fast_phrases: int = parser.action_phrases.filter(func(phrase: Dictionary) -> bool: return phrase["mode"] == "fast").size()
	assert_eq(basic_phrases, 141, "two-note basic action phrases")
	assert_eq(fast_phrases, 87, "four-note accelerated action phrases")

	var first_heavy: Dictionary = parser.heavy_groups[0]
	assert_eq(first_heavy["beat_key"], "73:0:4", "first heavy exact beat")
	assert_close(float(first_heavy["time"]), 21.82135468, 0.0001, "first heavy music time")

	var first_fixed: Dictionary = parser.fixed_attack_events[0]
	assert_eq(first_fixed["beat_key"], "492:0:4", "first fixed laser trigger beat")
	assert_eq((first_fixed["lasers"] as Array).size(), 2, "two lasers trigger fixed move 1")
	assert_true((first_fixed["lasers"] as Array)[0].get("fixed_primary", false), "first laser is primary trigger")

	var first_formation: Dictionary = parser.laser_formations[0]
	assert_eq(str(first_formation["pattern"]), "diamond", "laser geometry cycles from diamond")
	assert_true((first_formation["lasers"] as Array).size() <= 4, "formation has at most four lines")


func test_equal_interval_pairs_and_laser_pairs() -> void:
	var document := {
		"note": [
			{"beat": [10, 0, 4], "column": 0},
			{"beat": [10, 2, 4], "column": 1},
			{"beat": [11, 0, 4], "column": 2},
			{"beat": [11, 2, 4], "column": 3},
			{"beat": [12, 0, 4], "column": 0},
			{"beat": [12, 2, 4], "column": 1},
			{"beat": [13, 0, 4], "column": 2},
			{"beat": [13, 2, 4], "column": 3},
			{"beat": [20, 0, 4], "endbeat": [21, 0, 4], "column": 0},
			{"beat": [20, 0, 4], "endbeat": [21, 0, 4], "column": 1},
			{"beat": [0, 0, 1], "sound": "ignored.ogg", "offset": 245},
		],
	}
	var parser = PARSER_SCRIPT.new()
	var ok: bool = parser.parse_text(JSON.stringify(document), 203.0, 245.0, 4.0)
	assert_true(ok, "synthetic chart parses: %s" % [parser.errors])
	assert_eq(parser.note_count, 11, "all records counted")
	assert_eq(parser.timed_note_count, 10, "sound record excluded")
	assert_eq(parser.normal_timing_group_count, 8, "normal timing groups")
	assert_eq(parser.paired_note_group_count, 4, "eight equal-interval notes form four pairs")
	assert_eq(parser.action_phrase_count, 2, "two pairs form one accelerated four-note phrase")
	assert_eq(parser.action_phrases[0]["mode"], "fast", "one-beat spacing is fast mode")
	assert_eq(parser.action_phrases[0]["note_count"], 4, "fast phrase has four notes")
	assert_eq(parser.fixed_attack_event_count, 1, "same-beat endbeat notes trigger fixed move 1")
	assert_eq((parser.fixed_attack_events[0]["lasers"] as Array).size(), 2, "fixed trigger stores both lasers")


func assert_true(value: bool, label: String) -> void:
	if value:
		passed += 1
	else:
		failed += 1
		push_error("FAIL %s" % label)


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

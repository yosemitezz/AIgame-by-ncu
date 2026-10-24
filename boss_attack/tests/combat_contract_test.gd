extends SceneTree

const DOUBLE_TAP_SCRIPT := preload("res://scripts/double_tap_tracker.gd")
const HEAVY_JUDGE_SCRIPT := preload("res://scripts/heavy_judge.gd")
const MOVE_SLOTS_SCRIPT := preload("res://scripts/boss_move_slots.gd")

var passed := 0
var failed := 0


func _initialize() -> void:
	test_double_taps_are_independent()
	test_heavy_windows_and_overlap()
	test_move_slots_and_pattern_contract()
	print("COMBAT RESULTS: %d passed, %d failed" % [passed, failed])
	quit(1 if failed > 0 else 0)


func test_double_taps_are_independent() -> void:
	var tracker = DOUBLE_TAP_SCRIPT.new(0.25)
	assert_false(tracker.register_press(&"left", 0.0), "first left press")
	assert_true(tracker.register_press(&"left", 0.20), "second left press in window")
	assert_false(tracker.register_press(&"left", 0.30), "successful double tap resets pair")
	assert_false(tracker.register_press(&"down", 0.31), "first down press independent")
	assert_true(tracker.register_press(&"down", 0.55), "down double tap at boundary")
	assert_false(tracker.register_press(&"right", 0.60), "first right press")
	assert_false(tracker.register_press(&"right", 0.90), "late second press rejected")
	assert_true(tracker.register_press(&"right", 1.10), "right can pair after rejected press")


func test_heavy_windows_and_overlap() -> void:
	var judge = HEAVY_JUDGE_SCRIPT.new()
	judge.setup([{"time": 1.0}, {"time": 1.2}], 0.125)
	judge.register_block(1.13)
	var before_deadline: Array = judge.update(1.124)
	assert_eq(before_deadline.size(), 0, "judgement waits for late edge")
	var first_results: Array = judge.update(1.126)
	assert_eq(first_results.size(), 1, "first heavy judged")
	assert_false(first_results[0]["success"], "block outside first heavy window")
	var second_results: Array = judge.update(1.326)
	assert_eq(second_results.size(), 1, "second heavy judged independently")
	assert_true(second_results[0]["success"], "same block inside second heavy window")

	var boundary = HEAVY_JUDGE_SCRIPT.new()
	boundary.setup([{"time": 2.0}], 0.125)
	boundary.register_block(2.125)
	var boundary_result: Array = boundary.update(2.126)
	assert_eq(boundary_result.size(), 1, "boundary heavy judged")
	assert_true(boundary_result[0]["success"], "positive 125ms boundary is inclusive")


func test_move_slots_and_pattern_contract() -> void:
	var slots = MOVE_SLOTS_SCRIPT.new()
	var ok: bool = slots.load_config("res://data/boss_moves.json")
	assert_true(ok, "move slots load: %s" % [slots.errors])
	assert_eq(slots.slots.size(), 6, "exactly six slots")
	for slot_id in ["move_1", "move_2", "move_3", "move_4", "fixed_1"]:
		assert_true(slots.slots.has(slot_id), "%s exists" % slot_id)
		assert_true(bool(slots.slots[slot_id]["enabled"]), "%s authored logic is enabled" % slot_id)
	assert_false(bool(slots.slots["fixed_2"]["enabled"]), "fixed_2 remains intentionally empty")
	assert_eq(slots.normal_cycle, ["move_1", "move_2", "move_3", "move_4"], "normal move cycle")
	assert_eq(slots.fast_cycle, ["fast_1", "fast_2", "fast_3", "fast_4"], "fast action cycle")
	assert_eq(slots.get_normal_pattern(0).get("pattern_id"), "charge_dash_ring", "first normal move")
	assert_eq(slots.get_fast_pattern(3).get("display_name"), "四连弹", "fourth fast group")
	assert_eq(slots.get_fixed_pattern().get("pattern_id"), "cube_diagonal_lasers", "fixed move 1")
	slots.free()


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


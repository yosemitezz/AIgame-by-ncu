extends SceneTree

const DIRECTOR_SCRIPT := preload("res://scripts/battle_director.gd")

var passed := 0
var failed := 0


func _initialize() -> void:
	await run()
	print("SCHEDULER RESULTS: %d passed, %d failed" % [passed, failed])
	quit(1 if failed > 0 else 0)


func run() -> void:
	await process_frame
	var director = DIRECTOR_SCRIPT.new()
	director.configure({
		"bpm": 203.0,
		"offset_ms": 245.0,
		"phase_gap_beats": 4.0,
		"chart_path": "res://data/if_infinity.chart.json",
		"music_path": "res://audio/missing-for-manual-clock.flac",
		"song_duration_seconds": 418.516,
	})
	root.add_child(director)
	assert_true(director.initialize(), "director initializes")
	var counters := {"groups": 0, "heavy": 0, "warnings": 0, "damage": 0, "phases": 0, "rests": 0}
	director.timing_group.connect(func(_group: Dictionary, _phase: int) -> void: counters["groups"] += 1)
	director.heavy_group.connect(func(_group: Dictionary, _phase: int) -> void: counters["heavy"] += 1)
	director.laser_warning.connect(func(_laser: Dictionary) -> void: counters["warnings"] += 1)
	director.laser_damage.connect(func(_laser: Dictionary) -> void: counters["damage"] += 1)
	director.phase_started.connect(func(_phase: Dictionary) -> void: counters["phases"] += 1)
	director.rest_started.connect(func(_phase: Dictionary) -> void: counters["rests"] += 1)
	director.start()
	assert_true(director.manual_clock, "missing test music uses deterministic manual clock")
	director.advance_to(90.0)
	assert_true(int(counters["groups"]) > 0, "timing groups dispatched")
	assert_true(int(counters["heavy"]) > 0, "heavy groups dispatched")
	assert_true(int(counters["warnings"]) > 0, "laser warnings dispatched")
	assert_true(int(counters["damage"]) > 0, "laser damage events dispatched")
	assert_true(int(counters["phases"]) > 1, "phase events dispatched")
	assert_true(int(counters["rests"]) > 0, "rest events dispatched")
	director.queue_free()


func assert_true(value: bool, label: String) -> void:
	if value:
		passed += 1
	else:
		failed += 1
		push_error("FAIL %s" % label)

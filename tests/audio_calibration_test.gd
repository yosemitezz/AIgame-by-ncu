extends SceneTree
const Calibration = preload("res://combat/audio_calibration.gd")

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

func groups(times: Array[float]) -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    for at: float in times:
        result.append({"time": at})
    return result

func run() -> void:
    var calibration: RefCounted = Calibration.new()
    check(Calibration.SAMPLE_COUNT == 5 and is_equal_approx(Calibration.SEARCH_AFTER_SECONDS, 35.0), "module constants match the spec")
    var fixture: Array[Dictionary] = groups([10.0, 34.9, 40.74, 41.18, 41.62, 42.06, 42.50, 50.0])
    check(calibration.configure(fixture, 245.0), "first regular five-group run after 35 s is selected")
    check(calibration.sample_times == [40.74, 41.18, 41.62, 42.06, 42.50], "selected cluster is the actual chart run")
    check(is_equal_approx(calibration.preview_start_seconds(), 38.74), "preview starts two seconds before the first sample")
    check(is_equal_approx(calibration.base_offset_ms, 245.0), "base offset is retained")
    check(not calibration.is_complete() and is_equal_approx(calibration.adjusted_offset_ms(), 245.0), "incomplete calibration reports the base offset")

    var irregular: RefCounted = Calibration.new()
    check(not irregular.configure(groups([36.0, 36.1, 36.5, 37.0, 38.2]), 245.0), "irregular five-group runs are rejected")
    var short_fixture: RefCounted = Calibration.new()
    check(not short_fixture.configure(groups([40.0, 41.0, 42.0, 43.0]), 245.0), "fewer than five groups is rejected")

    check(calibration.register_tap(40.83), "tap inside 350 ms is accepted")
    check(not calibration.register_tap(41.60), "tap farther than 350 ms from the next sample is rejected")
    check(calibration.tap_positions == [40.83], "rejected tap does not advance progress")
    check(calibration.register_tap(41.27) and calibration.register_tap(41.71) and calibration.register_tap(42.15) and calibration.register_tap(42.59), "remaining four taps are accepted")
    check(calibration.is_complete(), "five accepted taps complete the sample")
    check(is_equal_approx(calibration.adjusted_offset_ms(), 335.0), "mean 90 ms lateness is added to the base offset")
    check(is_equal_approx(calibration.last_error_seconds, 0.09), "mean error is reported in seconds")
    check(not calibration.register_tap(43.0), "a sixth tap is rejected")

    print("Audio calibration: %d passed, %d failed" % [passed, failed])
    quit(1 if failed else 0)

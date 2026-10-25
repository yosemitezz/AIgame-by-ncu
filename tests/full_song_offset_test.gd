extends SceneTree
const Transport = preload("res://audio/full_song_transport.gd")
const Music = preload("res://audio/music_director.gd")

class TestGame extends Node2D:
    var story_safe: bool = false
    func set_story_safe(value: bool) -> void: story_safe = value
    func announce(_message: String, _seconds: float = 3.0) -> void: pass
    func on_boss_defeated() -> void: pass

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

func load_config() -> Dictionary:
    var file: FileAccess = FileAccess.open("res://data/full_song_timeline.json", FileAccess.READ)
    return JSON.parse_string(file.get_as_text())

func run() -> void:
    var config: Dictionary = load_config()
    var duration: float = 418.51573696145124
    var transport: RefCounted = Transport.new()
    check(transport.configure(config, duration), "transport accepts the shipping boundaries")
    var old_fixed: float = transport.fixed_end
    var old_rest: float = transport.rest_end
    check(transport.set_offset_ms(345.0), "offset applies while stopped")
    check(is_equal_approx(transport.offset_ms, 345.0) and is_equal_approx(transport.offset_seconds, 0.345), "offset is stored in both units")
    check(is_equal_approx(transport.fixed_end, old_fixed + 0.1) and is_equal_approx(transport.rest_end, old_rest + 0.1), "all four boundaries shift by the exact delta")
    check(is_equal_approx(transport.beat_time(200.0), old_fixed + 0.1), "beat mapping uses the new offset")
    transport.start()
    check(not transport.set_offset_ms(245.0) and is_equal_approx(transport.offset_ms, 345.0), "running transport rejects offset edits")
    transport.stop()
    var short: RefCounted = Transport.new()
    check(short.configure(config, 88.0), "short-but-valid song configures")
    check(not short.set_offset_ms(1000.0) and is_equal_approx(short.offset_ms, 245.0), "offset that pushes rest past the audio is rejected atomically")

    var game := TestGame.new()
    root.add_child(game)
    var music: Node = Music.new()
    game.add_child(music)
    music.configure(game, "res://data/full_song_timeline.json")
    music.set_process(false)
    music._dummy = true
    check(music.is_full_song(), "director loads the shipping full song")
    var before: Array[Dictionary] = music.get_heavy_groups()
    var chart_before: RefCounted = music._full_chart
    check(before.size() == 107, "fixture exposes all 107 heavy groups")
    check(music.replace_offset_ms(345.0), "director applies a stopped-session offset")
    check(is_equal_approx(float(music.get_full_song_status()["offset_ms"]), 345.0), "status reports the new offset")
    check(is_equal_approx(float(music.timeline["offset_ms"]), 345.0), "timeline commits the new offset")
    var after: Array[Dictionary] = music.get_heavy_groups()
    check(after.size() == 107 and music._full_chart != chart_before, "chart is re-parsed instead of mutated")
    check(is_equal_approx(float(after[0]["time"]) - float(before[0]["time"]), 0.1), "every heavy group shifts by exactly 100 ms")
    check(music._full_chart.timed_note_count == 1171 and music._full_chart.action_phrases.size() == 228, "chart counts and phrases are unchanged")
    var committed_chart: RefCounted = music._full_chart
    check(music.replace_offset_ms(345.0), "equal offset is an idempotent success")
    check(music._full_chart == committed_chart, "equal offset does not re-parse")
    check(music.replace_offset_ms(-10.0), "negative offset clamps to zero")
    check(is_equal_approx(float(music.timeline["offset_ms"]), 0.0), "clamped offset is committed")
    check(is_equal_approx(float(music.get_heavy_groups()[0]["time"]), 73.0 * 60.0 / 203.0), "clamped chart starts at the raw source beat")
    music.start_score()
    var running_chart: RefCounted = music._full_chart
    check(not music.replace_offset_ms(300.0) and music._full_chart == running_chart, "running score rejects and preserves the chart")
    music.stop_score()
    music._full_chart_path = "res://data/missing_offset_chart.json"
    var missing_chart: RefCounted = music._full_chart
    check(not music.replace_offset_ms(300.0), "unparseable replacement is rejected")
    check(music._full_chart == missing_chart and is_equal_approx(float(music.timeline["offset_ms"]), 0.0), "failed replacement leaves chart, timeline and offset untouched")

    var original_game := TestGame.new()
    root.add_child(original_game)
    var original: Node = Music.new()
    original_game.add_child(original)
    original.configure(original_game, "res://data/music_timeline.json")
    original.set_process(false)
    check(not original.is_full_song() and not original.replace_offset_ms(300.0), "original-score mode rejects calibration offsets")

    game.queue_free()
    original_game.queue_free()
    await process_frame
    print("Full song offset: %d passed, %d failed" % [passed, failed])
    quit(1 if failed else 0)

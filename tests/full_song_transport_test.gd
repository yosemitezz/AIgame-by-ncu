extends SceneTree
const Transport = preload("res://audio/full_song_transport.gd")
const Music = preload("res://audio/music_director.gd")
class TestGame extends Node2D:
    var story_safe: bool = false
    var safety: Array[bool] = []
    var defeat_callbacks: int = 0
    var announcements: Array[String] = []
    func set_story_safe(value: bool) -> void:
        story_safe = value
        safety.append(value)
    func announce(message: String, _seconds: float = 3.0) -> void:
        announcements.append(message)
    func on_boss_defeated() -> void:
        defeat_callbacks += 1
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
func run() -> void:
    var file: FileAccess = FileAccess.open("res://data/full_song_timeline.json", FileAccess.READ)
    var config: Dictionary = JSON.parse_string(file.get_as_text())
    var duration: float = 418.51573696145124
    var t: RefCounted = Transport.new()
    check(t.configure(config, duration), "public full-song boundary configuration validates")
    check(is_equal_approx(t.fixed_end, 59.3583004926108), "beat200 source boundary includes245ms exactly once")
    check(is_equal_approx(t.random_end, 78.2745566502463) and is_equal_approx(t.rest_end, 87.732684729064), "rest uses quiet source beat264..296 gap")
    var sections: Array[String] = []
    t.section_changed.connect(func(section: String) -> void: sections.append(section))
    var done: Array[int] = []
    t.completed.connect(func() -> void: done.append(1))
    t.start()
    var initial: int = t.generation
    var loop_duration: float = t.random_end - t.random_start
    t.advance(t.random_end + loop_duration * 2.0 + 0.125)
    check(t.generation == initial + 3, "three health-gated phrase loops create three epochs")
    check(is_equal_approx(t.chart_time, t.random_start + 0.125), "source returns to configured random phrase after three loops")
    var previous_score: float = t.score_time
    check(previous_score > t.chart_time and is_equal_approx(previous_score - t.chart_time, 3.0 * loop_duration), "runtime clock unwraps all three source rewinds monotonically")
    t.set_paused(true)
    t.advance(100.0)
    check(t.score_time == previous_score and is_equal_approx(t.chart_time, t.random_start + 0.125), "pause freezes both clocks")
    t.set_paused(false)
    t.request_advance()
    t.advance(loop_duration - 0.126)
    check(t.section == "random" and t.advance_queued, "health request cannot cut the phrase early")
    t.advance(0.002)
    check(t.section == "rest" and t.chart_time >= t.random_end, "health request advances only at source phrase end")
    t.advance(t.rest_end - t.chart_time + 0.01)
    check(t.section == "final" and sections.has("rest"), "rest is emitted before final even in a large frame")
    t.advance(duration)
    check(t.ended and not t.running and done.size() == 1, "source EOF ends once")
    t.advance(duration)
    check(done.size() == 1, "repeated EOF cannot complete twice")
    t.start()
    check(t.running and not t.ended and t.score_time == 0.0 and t.chart_time == 0.0, "retry rewinds both clocks in a fresh epoch")
    var invalid: RefCounted = Transport.new()
    check(not invalid.configure(config, 30.0), "track shorter than gameplay boundaries rejects")
    var game := TestGame.new()
    root.add_child(game)
    var music: Node = Music.new()
    game.add_child(music)
    music.configure(game, "res://data/full_song_timeline.json")
    music.set_process(false)
    music._dummy = true
    check(music.is_full_song() and music._audio.stream is AudioStreamOggVorbis, "actual selected existing OGG loads into main AudioStreamPlayer")
    check(absf(float(music.get_full_song_status()["duration"]) - duration) < 0.001, "Godot decoder duration matches Ogg granule audit")
    check(music._full_chart.timed_note_count == 1171 and music._full_chart.action_phrases.size() == 228, "complete source chart is parsed without short-placeholder truncation")
    var heavy: Array[Dictionary] = music.get_heavy_groups()
    check(heavy.size() == 107 and not str(heavy[0]["id"]).is_empty(), "107 source heavy groups expose stable exact-key IDs")
    check(is_equal_approx(float(heavy[0]["time"]), 73.0 * 60.0 / 203.0 + 0.245), "first heavy time is sourcebeat73 plus one245ms offset")
    var beats: Array[int] = []
    music.beat.connect(func(index: int) -> void: beats.append(index))
    var completed: Array[int] = []
    music.song_completed.connect(func() -> void: completed.append(1))
    music.start_score()
    check(beats.is_empty(), "starting full audio does not falsely emit sourcebeat0 at time0")
    music._process(0.244)
    check(beats.is_empty(), "sourcebeat0 waits through positive audio offset")
    music._process(0.002)
    check(beats == [0], "sourcebeat0 emits once at245ms")
    music.set_score_paused(true)
    var held: float = music.get_score_time()
    music._process(30.0)
    check(music.get_score_time() == held and music.get_full_song_status()["paused"] and music._transport.paused, "main pause freezes requested audio state and sole score clock")
    music.set_score_paused(false)
    music._process(0.05)
    check(music.get_score_time() > held and not music.get_full_song_status()["paused"], "main resume releases clocks without wall-time catch-up")
    # Exercise the real sample intake, not just Dummy advance. The mixer itself
    # stays Dummy; supplied positions model an oversized frame at the loop edge.
    music._dummy = false
    music.start_score()
    music._consume_full_audio_sample(0.0, 0.0, 0.0, 0.016)
    var source_after_end: float = music._transport.random_end + 0.725
    music._consume_full_audio_sample(source_after_end, 0.0, 0.0, 0.016)
    var final_source: float = music._transport.random_start + 0.725
    check(is_equal_approx(music.get_chart_time(), final_source), "real sampler preserves loop-frame overshoot in chart position")
    check(is_equal_approx(music._last_requested_seek, final_source) and is_equal_approx(music._source_read_anchor, final_source), "actual seek request is deferred to final overshoot-adjusted source position")
    var before_jitter: float = music.get_score_time()
    music._consume_full_audio_sample(final_source - 0.03, 0.0, 0.02, 0.016)
    check(music.get_score_time() == before_jitter, "negative compensated post-seek jitter cannot rewind or re-add overshoot")
    music._consume_full_audio_sample(final_source + 0.02, 0.005, 0.010, 0.016)
    check(is_equal_approx(music.get_score_time(), before_jitter + 0.015), "positive mixer sample advances only its actual compensated increment")
    # A real input may arrive before the next process frame after a seek.
    music._dummy = false
    music.start_score()
    music._consume_full_audio_sample(0.0, 0.0, 0.0, 0.016)
    music._consume_full_audio_sample(music._transport.random_end + 0.1, 0.0, 0.0, 0.016)
    var seek_target: float = music._last_requested_seek
    var seek_score: float = music.get_score_time()
    music._consume_full_audio_sample(music._transport.random_end, 0.0, 0.0, 0.016)
    check(music.get_score_time() == seek_score, "unchanged old loop-end sample cannot settle a source rewind")
    await create_timer(0.61, true, false, true).timeout
    var fresh: float = music.sample_input_chart_time({"playback": seek_target + 0.6, "since_mix": 0.0, "latency": 0.0})
    check(is_equal_approx(fresh, seek_target + 0.6) and is_equal_approx(music.get_score_time(), seek_score + 0.6), "post-seek input arriving before process accepts real600ms progress from the audio sample")
    music._consume_full_audio_sample(seek_target + 1.1, 0.0, 0.0, 0.5)
    check(is_equal_approx(music.get_score_time(), seek_score + 1.1) and music.running, "later post-seek sample continues without false timeout or double increment")
    var cached: float = music.get_chart_time()
    fresh = music.sample_input_chart_time({"playback": cached + 0.20, "since_mix": 0.0, "latency": 0.0})
    check(is_equal_approx(fresh, cached + 0.20), "input timestamp refreshes cached transport from the same live audio authority")
    music._dummy = true
    music.request_advance()
    music._process(music._transport.rest_end - music.get_chart_time() + 0.01)
    check(music.current_section == "final" and game.safety.has(true), "large source frame still applies narrative rest safety")
    music._process(duration - music.get_chart_time() + 0.01)
    check(not music.running and game.story_safe and completed.size() == 1, "main EOF stops and makes a surviving Boss safe")
    check(game.defeat_callbacks == 0, "song EOF never fabricates a Boss victory")
    music._process(10.0)
    check(completed.size() == 1, "main EOF signal is idempotent")
    music.start_score()
    check(music.running and music.get_chart_time() == 0.0 and not game.story_safe, "main score restart rewinds and restores combat safety state")
    music.stop_score()
    check(not music.running and game.story_safe, "explicit full-song stop clears combat safety")
    game.queue_free()
    await process_frame
    await process_frame
    print("FULL SONG TRANSPORT: %d passed, %d failed" % [passed, failed])
    quit(1 if failed > 0 else 0)

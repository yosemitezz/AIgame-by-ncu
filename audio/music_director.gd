extends Node
const FullTransport = preload("res://audio/full_song_transport.gd")
const SourceParser = preload("res://combat/friend_rhythm/chart_parser.gd")
## Original in-memory score and the sole boss beat/section clock.
## Audio playback time is latency-compensated; Dummy audio uses deterministic delta.

signal beat(index: int)
signal section_changed(section: String)
signal phrase_boundary(index: int)
signal transport_changed(generation: int, chart_time: float)
signal song_completed
signal score_error(message: String)

var _full: bool = false
var _full_requested: bool = false
var _full_error: String = ""
var _transport: RefCounted
var _full_chart: RefCounted
var _full_chart_path: String = ""
var _full_paused: bool = false
var _full_last_emitted: int = -1
var _source_read_anchor: float = 0.0
var _seek_pending: bool = false
var _seek_wait: float = 0.0
var _last_requested_seek: float = 0.0
var _seek_committed_usec: int = 0
var game: Node
var bpm: float = 112.0
var total_beats: int = 0
var current_section: String = "fixed"
var advance_health_ratio: float = 0.5
var running: bool = false
var timeline: Dictionary = {}
var _section_beats: int = 0
var _advance_requested: bool = false
var _audio: AudioStreamPlayer
var _streams: Dictionary = {}
var _audio_loops: int = 0
var _last_audio_position: float = 0.0
var _clock_origin: float = 0.0
var _fallback_clock: float = 0.0
var _last_clock: float = 0.0
var _stream_duration: float = 0.0
var _dummy: bool = false
var _device_dummy: bool = false

func configure(p_game: Node, timeline_path: String = "res://data/music_timeline.json") -> void:
    game = p_game
    var document: Dictionary = _read_json(timeline_path)
    _full_requested = str(document.get("mode", "")) in ["full_song", "local_full_song"] or timeline_path.get_file() in ["full_song_timeline.json", "local_score.json"] or (document.is_empty() and timeline_path != "res://data/music_timeline.json")
    var local_audio: String = ""
    if str(document.get("mode", "")) == "local_full_song":
        local_audio = str(document.get("audio_path", ""))
        document = _read_json(str(document.get("timeline_path", "res://data/full_song_timeline.json")))
        if not local_audio.is_empty():
            document["audio_path"] = local_audio
    timeline = document
    bpm = clampf(float(timeline.get("bpm", 112.0)), 60.0, 240.0)
    advance_health_ratio = clampf(float(timeline.get("advance_health_ratio", 0.5)), 0.1, 0.9)
    var music_bus: int = AudioServer.get_bus_index("Music")
    if music_bus < 0:
        AudioServer.add_bus()
        music_bus = AudioServer.bus_count - 1
        AudioServer.set_bus_name(music_bus, "Music")
    _audio = AudioStreamPlayer.new()
    _audio.name = "BossScore" if _full_requested else "OriginalScore"
    _audio.bus = "Music"
    _audio.volume_db = float(timeline.get("music_volume_db", -8.0))
    add_child(_audio)
    _dummy = AudioServer.get_driver_name() == "Dummy"
    _device_dummy = _dummy
    if _full_requested:
        if document.is_empty():
            _fail_full_song("Explicit score configuration is missing or malformed")
            return
        if str(document.get("mode", "")) != "full_song":
            _fail_full_song("Explicit full-song configuration has an invalid mode")
            return
        _configure_full_song()
        return
    for section: String in ["fixed", "random", "rest", "final"]:
        _streams[section] = _synthesize(section, _section_length(section))

func _read_json(path: String) -> Dictionary:
    var file: FileAccess = FileAccess.open(path, FileAccess.READ)
    if file == null:
        return {}
    var parsed: Variant = JSON.parse_string(file.get_as_text().trim_prefix("\ufeff"))
    return parsed if parsed is Dictionary else {}

func _fail_full_song(message: String) -> void:
    _full = false
    running = false
    _full_error = message
    push_warning("Full-song configuration rejected: " + message)
    score_error.emit(message)
    if is_instance_valid(game) and game.has_method("announce"):
        game.announce("FULL SCORE ERROR: " + message, 8.0)

func _configure_full_song() -> void:
    var audio_path: String = str(timeline.get("audio_path", ""))
    _full_chart_path = str(timeline.get("chart_path", ""))
    if audio_path.is_empty() or not FileAccess.file_exists(audio_path):
        _fail_full_song("Audio file is unavailable")
        return
    if _full_chart_path.is_empty() or not FileAccess.file_exists(_full_chart_path):
        _fail_full_song("Source chart is unavailable")
        return
    var expected_audio: String = str(timeline.get("expected_audio_sha256", ""))
    var expected_chart: String = str(timeline.get("expected_chart_sha256", ""))
    if not expected_audio.is_empty() and FileAccess.get_sha256(audio_path) != expected_audio:
        _fail_full_song("Audio SHA256 does not match the configured recording")
        return
    if not expected_chart.is_empty() and FileAccess.get_sha256(_full_chart_path) != expected_chart:
        _fail_full_song("Source chart SHA256 does not match")
        return
    var stream: AudioStreamOggVorbis = AudioStreamOggVorbis.load_from_file(ProjectSettings.globalize_path(audio_path))
    if stream == null or stream.get_length() <= 0.0:
        _fail_full_song("OGG decoding failed")
        return
    stream.loop = false
    _full_chart = SourceParser.new()
    _full_chart.fast_interval_threshold_beats = float(timeline.get("fast_interval_threshold_beats", 1.1))
    if not _full_chart.parse_file(_full_chart_path, bpm, float(timeline.get("offset_ms", 245.0)), 4.0):
        _fail_full_song("Source chart could not be parsed")
        return
    if stream.get_length() + 0.000001 < float(_full_chart.chart_end_time):
        _fail_full_song("Audio ends before the last source chart event")
        return
    _transport = FullTransport.new()
    if not _transport.configure(timeline, stream.get_length()):
        _fail_full_song(_transport.error)
        return
    _transport.section_changed.connect(_on_full_section)
    _transport.jumped.connect(_on_full_jump)
    _transport.completed.connect(_on_full_completed)
    _audio.stream = stream
    _audio.finished.connect(_on_full_audio_finished)
    _full = true

func is_full_song() -> bool:
    return _full

func get_chart_time() -> float:
    return float(_transport.chart_time) if _full else _last_clock

func get_transport_generation() -> int:
    return int(_transport.generation) if _full else 0

func get_heavy_groups() -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    if not _full:
        return result
    for group: Dictionary in _full_chart.heavy_groups:
        var value: Dictionary = group.duplicate(true)
        value["id"] = str(value["beat_key"])
        result.append(value)
    return result

func get_full_song_status() -> Dictionary:
    return {"chart_stats": _full_chart.get_stats() if _full else {}, "requested": _full_requested, "ready": _full, "error": _full_error, "chart_path": _full_chart_path, "bpm": bpm, "offset_ms": float(timeline.get("offset_ms", 0.0)), "duration": float(_transport.duration) if _full else 0.0, "generation": get_transport_generation(), "chart_time": get_chart_time(), "score_time": get_score_time(), "paused": _full_paused, "ended": bool(_transport.ended) if _full else false}

func set_score_paused(value: bool) -> void:
    _full_paused = value
    if _audio:
        _audio.stream_paused = value
    if _full:
        _transport.set_paused(value)

func _on_full_section(section: String) -> void:
    _last_clock = float(_transport.score_time)
    current_section = section
    _section_beats = 0
    _advance_requested = false
    if is_instance_valid(game):
        game.set_story_safe(section == "rest")
    section_changed.emit(section)

func _on_full_jump(generation: int, chart_time: float) -> void:
    _last_clock = float(_transport.score_time)
    _source_read_anchor = chart_time
    _seek_pending = running
    _seek_wait = 0.0
    # The transport may still consume overshoot after this boundary callback.
    # Seek only once advance() returns, to its final source position.
    transport_changed.emit(generation, chart_time)

func _on_full_completed() -> void:
    _last_clock = float(_transport.score_time)
    running = false
    _audio.stop()
    if is_instance_valid(game):
        game.set_story_safe(true)
    song_completed.emit()

func _on_full_audio_finished() -> void:
    if _full and running and current_section == "final":
        _transport.advance(maxf(0.0, float(_transport.duration) - float(_transport.chart_time)))
        _last_clock = float(_transport.score_time)

func _commit_full_seek() -> void:
    if not _seek_pending or not running:
        return
    _source_read_anchor = float(_transport.chart_time)
    _last_requested_seek = _source_read_anchor
    _seek_wait = 0.0
    _seek_committed_usec = Time.get_ticks_usec()
    # Dummy has no physical output: loading the real OGG and exercising the
    # sample intake is sufficient, without orphaning native playback workers.
    if not _device_dummy:
        _audio.play(_source_read_anchor)
        _audio.stream_paused = _full_paused
    if _dummy:
        _seek_pending = false

func _consume_full_audio_sample(playback: float, since_mix: float, latency: float, frame_delta: float) -> void:
    # Shared real-audio intake seam: tests can supply exact mixer samples without
    # simulating a seven-minute playback or advancing a second gameplay clock.
    if not _full or not running or _full_paused:
        return
    var raw: float = playback + since_mix - latency
    if _seek_pending:
        _seek_wait += frame_delta
        # Wall time only validates a seek handshake, never drives score time.
        # Input can arrive before _process after a blocked frame.
        if _seek_committed_usec > 0:
            _seek_wait = maxf(_seek_wait, float(Time.get_ticks_usec() - _seek_committed_usec) / 1000000.0)
        # A first post-seek frame can arrive late; permit elapsed forward
        # progress while rejecting an unchanged old loop-end position.
        if playback >= _source_read_anchor - 0.5 and playback <= _source_read_anchor + maxf(0.5, _seek_wait + 0.25):
            _seek_pending = false
        elif _seek_wait > 1.0:
            running = false
            _audio.stop()
            _full_error = "Audio seek did not settle"
            if is_instance_valid(game):
                game.set_story_safe(true)
            score_error.emit(_full_error)
            return
        else:
            return
    var progress: float = maxf(0.0, raw - _source_read_anchor)
    _source_read_anchor = maxf(_source_read_anchor, raw)
    var prior_generation: int = int(_transport.generation)
    _transport.advance(progress)
    if int(_transport.generation) != prior_generation:
        _commit_full_seek()
    _last_clock = maxf(_last_clock, float(_transport.score_time))

func sample_input_chart_time(mixer_sample: Dictionary = {}) -> float:
    if _full and running and not _full_paused and not _dummy:
        var playback: float = float(mixer_sample.get("playback", _audio.get_playback_position()))
        var mix: float = float(mixer_sample.get("since_mix", AudioServer.get_time_since_last_mix()))
        var latency: float = float(mixer_sample.get("latency", AudioServer.get_output_latency()))
        _consume_full_audio_sample(playback, mix, latency, 0.0)
    return get_chart_time()

func _process_full_song(delta: float) -> void:
    if _full_paused or get_tree().paused:
        return
    if _dummy:
        var prior_generation: int = int(_transport.generation)
        _transport.advance(maxf(0.0, delta))
        if int(_transport.generation) != prior_generation:
            _commit_full_seek()
    else:
        _consume_full_audio_sample(_audio.get_playback_position(), AudioServer.get_time_since_last_mix(), AudioServer.get_output_latency(), delta)
    _last_clock = maxf(_last_clock, float(_transport.score_time))
    var target: int = int(floor((_last_clock - float(timeline.get("offset_ms", 245.0)) / 1000.0) / seconds_per_beat() + 0.000001))
    while _full_last_emitted < target and running:
        _full_last_emitted += 1
        total_beats = maxi(0, _full_last_emitted)
        _section_beats += 1
        var phrase: int = maxi(1, int(timeline.get("phrase_beats", 8)))
        if total_beats > 0 and total_beats % phrase == 0:
            phrase_boundary.emit(total_beats / phrase)
        beat.emit(total_beats)

func start_score() -> void:
    if _audio == null:
        return
    if _full_requested and not _full:
        score_error.emit(_full_error)
        return
    if _full:
        total_beats = 0
        _full_last_emitted = -1
        _last_clock = 0.0
        _full_paused = false
        running = true
        _transport.start()
        _commit_full_seek()
        return
    total_beats = 0
    _fallback_clock = 0.0
    _last_clock = 0.0
    running = true
    _set_section("fixed")
    beat.emit(0)

func stop_score() -> void:
    if _full:
        running = false
        _transport.stop()
        _audio.stop()
        if is_instance_valid(game):
            game.set_story_safe(true)
        return
    running = false
    if _audio:
        _audio.stop()

func request_advance() -> void:
    if _full:
        _transport.request_advance()
        return
    if current_section == "random":
        _advance_requested = true

func is_advance_queued() -> bool:
    return bool(_transport.advance_queued) if _full else _advance_requested

func get_section_beat() -> int:
    return _section_beats

func get_score_time() -> float:
    # Read the existing latency-compensated monotonic clock; no extra timer.
    return _last_clock

func seconds_per_beat() -> float:
    return 60.0 / bpm

static func compensated_clock(section_origin: float, loop_count: int, loop_duration: float, latency_adjusted_position: float) -> float:
    # A negative compensated position after a WAV wrap still belongs to the prior
    # audible phrase. Clamp only the fully unwrapped time, never each local loop.
    return section_origin + maxf(float(loop_count) * loop_duration + latency_adjusted_position, 0.0)

func _process(delta: float) -> void:
    if not running or _full_paused:
        return
    if _full:
        _process_full_song(delta)
        return
    var clock: float
    if _dummy:
        _fallback_clock += delta
        clock = _fallback_clock
    else:
        var raw: float = _audio.get_playback_position() + AudioServer.get_time_since_last_mix() - AudioServer.get_output_latency()
        # The WAV loops. Unwrap its local playback position to a monotonically increasing clock.
        if raw + 0.15 < _last_audio_position:
            _audio_loops += 1
        _last_audio_position = raw
        clock = compensated_clock(_clock_origin, _audio_loops, _stream_duration, raw)
    _last_clock = maxf(_last_clock, clock)
    var target_beat: int = int(floor(_last_clock / seconds_per_beat()))
    while total_beats < target_beat and running:
        advance_beat()

func advance_beat() -> void:
    ## Public deterministic seam for headless score-rule checks; never harms the player.
    if _full:
        _process_full_song(seconds_per_beat())
        return
    total_beats += 1
    _section_beats += 1
    var length: int = _section_length(current_section)
    if _section_beats >= length:
        match current_section:
            "fixed":
                _set_section("random")
            "random":
                if _advance_requested:
                    _set_section("rest")
                else:
                    _section_beats = 0
            "rest":
                _set_section("final")
            "final":
                _section_beats = 0
    var phrase: int = maxi(1, int(timeline.get("phrase_beats", 8)))
    if total_beats % phrase == 0:
        phrase_boundary.emit(total_beats / phrase)
    beat.emit(total_beats)

func _set_section(section: String) -> void:
    current_section = section
    _section_beats = 0
    _advance_requested = false
    if is_instance_valid(game):
        game.set_story_safe(section == "rest")
    # Section safety/cancellation is applied before the downbeat reaches attack listeners.
    section_changed.emit(section)
    if _audio:
        _audio.stream = _streams.get(section)
        _audio_loops = 0
        _last_audio_position = 0.0
        _clock_origin = float(total_beats) * seconds_per_beat()
        _stream_duration = float(_section_length(section)) * seconds_per_beat()
        if running and not _dummy:
            _audio.play()

func _section_length(section: String) -> int:
    var key: String = "fixed_beats"
    match section:
        "random": key = "random_loop_beats"
        "rest": key = "rest_beats"
        "final": key = "final_loop_beats"
    var fallback: int = 16 if section == "random" or section == "final" else 8
    var phrase: int = maxi(1, int(timeline.get("phrase_beats", 8)))
    # Every configurable section remains an integer number of musical phrases.
    var requested: int = maxi(phrase, int(timeline.get(key, fallback)))
    return maxi(phrase, int(ceil(float(requested) / float(phrase))) * phrase)

func _synthesize(section: String, beats: int) -> AudioStreamWAV:
    var sample_rate: int = clampi(int(timeline.get("sample_rate", 16000)), 8000, 48000)
    var spb: float = seconds_per_beat()
    var count: int = int(round(float(beats) * spb * sample_rate))
    var pcm := PackedByteArray()
    pcm.resize(count * 2)
    # D minor, original bell-like motif; a quiet pad replaces percussion in rest.
    var melody: Array[int] = [62, 69, 65, 72, 70, 69, 64, 65, 62, 65, 69, 74, 72, 70, 65, 64]
    var bass: Array[int] = [38, 38, 34, 41]
    var energetic: bool = section == "final"
    for i: int in count:
        var t: float = float(i) / float(sample_rate)
        var b: int = int(t / spb)
        var local_t: float = fmod(t, spb)
        var half_t: float = fmod(t, spb * 0.5)
        var midi: int = melody[b % melody.size()]
        var frequency: float = 440.0 * pow(2.0, float(midi - 69) / 12.0)
        var bass_freq: float = 440.0 * pow(2.0, float(bass[(b / 4) % bass.size()] - 69) / 12.0)
        var note_env: float = exp(-local_t * 6.5) * minf(local_t * 200.0, 1.0)
        var sample: float = (sin(TAU * frequency * t) + 0.3 * sin(TAU * frequency * 2.0 * t)) * note_env * 0.11
        sample += sin(TAU * bass_freq * t) * 0.075
        if section == "rest":
            sample *= 0.38
            sample += sin(TAU * frequency * 0.5 * t) * 0.018
        else:
            var kick_t: float = fmod(t, spb * 2.0)
            sample += sin(TAU * (72.0 * kick_t - 22.0 * kick_t * kick_t)) * exp(-kick_t * 22.0) * 0.2
            if b % 2 == 1:
                var noise: float = sin(float(i) * 1.723) * sin(float(i) * 0.913)
                sample += noise * exp(-local_t * 32.0) * 0.09
            sample += sin(TAU * 4900.0 * half_t) * exp(-half_t * 80.0) * 0.024
            if energetic:
                sample += sin(TAU * frequency * 2.0 * t) * exp(-half_t * 11.0) * 0.045
        # Prevent boundary clicks. Both ends of each rendered phrase settle to zero.
        var edge: float = minf(minf(t * 160.0, float(count - 1 - i) / sample_rate * 160.0), 1.0)
        pcm.encode_s16(i * 2, int(clampf(sample * edge, -0.9, 0.9) * 32767.0))
    var stream := AudioStreamWAV.new()
    stream.format = AudioStreamWAV.FORMAT_16_BITS
    stream.mix_rate = sample_rate
    stream.stereo = false
    stream.data = pcm
    stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
    stream.loop_begin = 0
    stream.loop_end = count
    return stream

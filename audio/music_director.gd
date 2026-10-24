extends Node
## Original in-memory score and the sole boss beat/section clock.
## Audio playback time is latency-compensated; Dummy audio uses deterministic delta.

signal beat(index: int)
signal section_changed(section: String)
signal phrase_boundary(index: int)

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

func configure(p_game: Node) -> void:
    game = p_game
    var file := FileAccess.open("res://data/music_timeline.json", FileAccess.READ)
    if file:
        var parsed: Variant = JSON.parse_string(file.get_as_text().trim_prefix("\ufeff"))
        if parsed is Dictionary:
            timeline = parsed
    bpm = clampf(float(timeline.get("bpm", 112.0)), 60.0, 200.0)
    advance_health_ratio = clampf(float(timeline.get("advance_health_ratio", 0.5)), 0.1, 0.9)
    var music_bus: int = AudioServer.get_bus_index("Music")
    if music_bus < 0:
        AudioServer.add_bus()
        music_bus = AudioServer.bus_count - 1
        AudioServer.set_bus_name(music_bus, "Music")
    _audio = AudioStreamPlayer.new()
    _audio.name = "OriginalScore"
    _audio.bus = "Music"
    _audio.volume_db = float(timeline.get("music_volume_db", -8.0))
    add_child(_audio)
    _dummy = AudioServer.get_driver_name() == "Dummy"
    # Render one complete loop per section once. No recording is written to disk.
    for section: String in ["fixed", "random", "rest", "final"]:
        _streams[section] = _synthesize(section, _section_length(section))

func start_score() -> void:
    if _audio == null:
        return
    total_beats = 0
    _fallback_clock = 0.0
    _last_clock = 0.0
    running = true
    _set_section("fixed")
    beat.emit(0)

func stop_score() -> void:
    running = false
    if _audio:
        _audio.stop()

func request_advance() -> void:
    if current_section == "random":
        _advance_requested = true

func is_advance_queued() -> bool:
    return _advance_requested

func get_section_beat() -> int:
    return _section_beats

func seconds_per_beat() -> float:
    return 60.0 / bpm

static func compensated_clock(section_origin: float, loop_count: int, loop_duration: float, latency_adjusted_position: float) -> float:
    # A negative compensated position after a WAV wrap still belongs to the prior
    # audible phrase. Clamp only the fully unwrapped time, never each local loop.
    return section_origin + maxf(float(loop_count) * loop_duration + latency_adjusted_position, 0.0)

func _process(delta: float) -> void:
    if not running:
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


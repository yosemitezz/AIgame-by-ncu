extends RefCounted
## Pure source-position/runtime mapping. MusicDirector alone drives this from
## compensated AudioStreamPlayer position (or deterministic Dummy-driver delta).
signal section_changed(section: String)
signal jumped(generation: int, chart_time: float)
signal completed
var bpm: float = 203.0
var offset_seconds: float = 0.245
var duration: float = 0.0
var fixed_end: float = 0.0
var random_start: float = 0.0
var random_end: float = 0.0
var rest_end: float = 0.0
var chart_time: float = 0.0
var score_time: float = 0.0
var generation: int = 0
var section: String = "fixed"
var running: bool = false
var paused: bool = false
var advance_queued: bool = false
var ended: bool = false
var error: String = ""

func configure(config: Dictionary, song_duration: float) -> bool:
    bpm = float(config.get("bpm", 203.0))
    offset_seconds = float(config.get("offset_ms", 245.0)) / 1000.0
    duration = song_duration
    error = ""
    if not is_finite(bpm) or bpm <= 0.0 or not is_finite(duration):
        error = "Invalid tempo or duration"
        return false
    fixed_end = beat_time(float(config.get("fixed_end_beat", 200.0)))
    random_start = beat_time(float(config.get("random_start_beat", 200.0)))
    random_end = beat_time(float(config.get("random_end_beat", 264.0)))
    rest_end = beat_time(float(config.get("rest_end_beat", 296.0)))
    if not (fixed_end > 0.0 and is_equal_approx(fixed_end, random_start) and random_end > random_start and rest_end > random_end and duration > rest_end):
        error = "Invalid full-song gameplay boundaries"
        return false
    return true

func beat_time(beat: float) -> float:
    return beat * 60.0 / bpm + offset_seconds

func start() -> void:
    chart_time = 0.0
    score_time = 0.0
    section = "fixed"
    generation += 1
    advance_queued = false
    ended = false
    paused = false
    running = true
    section_changed.emit(section)
    jumped.emit(generation, chart_time)

func stop() -> void:
    if not running and not paused:
        return
    running = false
    paused = false
    generation += 1
    jumped.emit(generation, chart_time)

func request_advance() -> void:
    if section == "random":
        advance_queued = true

func set_paused(value: bool) -> void:
    paused = value

func advance(delta: float) -> void:
    if not running or paused or not is_finite(delta) or delta <= 0.0:
        return
    var remaining: float = delta
    while remaining > 0.0000001 and running:
        var boundary: float = duration
        match section:
            "fixed": boundary = fixed_end
            "random": boundary = random_end
            "rest": boundary = rest_end
        var step: float = minf(remaining, maxf(0.0, boundary - chart_time))
        chart_time += step
        score_time += step
        remaining -= step
        if chart_time < boundary - 0.0000001:
            break
        chart_time = boundary
        match section:
            "fixed":
                section = "random"
                section_changed.emit(section)
            "random":
                if advance_queued:
                    section = "rest"
                    advance_queued = false
                    section_changed.emit(section)
                else:
                    chart_time = random_start
                    generation += 1
                    jumped.emit(generation, chart_time)
            "rest":
                section = "final"
                section_changed.emit(section)
            "final":
                ended = true
                running = false
                completed.emit()

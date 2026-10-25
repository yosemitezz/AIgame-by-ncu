extends RefCounted
## Measures the residual gap between chart beats and the sound the player hears.
## The selected run is the first five regular heavy groups after 35 seconds,
## which is the 40.74-42.51 second cluster in the source chart.

const SAMPLE_COUNT: int = 5
const SEARCH_AFTER_SECONDS: float = 35.0
const PREVIEW_LEAD_SECONDS: float = 2.0
const MAX_TAP_DISTANCE_SECONDS: float = 0.35

var base_offset_ms: float = 245.0
var sample_times: Array[float] = []
var tap_positions: Array[float] = []
var last_error_seconds: float = 0.0

func configure(heavy_groups: Array[Dictionary], current_offset_ms: float) -> bool:
    base_offset_ms = current_offset_ms
    sample_times.clear()
    tap_positions.clear()
    last_error_seconds = 0.0
    var candidates: Array[float] = []
    for group: Dictionary in heavy_groups:
        if not group.has("time"):
            continue
        var at: float = float(group["time"])
        if is_finite(at) and at >= SEARCH_AFTER_SECONDS:
            candidates.append(at)
    candidates.sort()
    if candidates.size() < SAMPLE_COUNT:
        return false
    for start: int in range(0, candidates.size() - SAMPLE_COUNT + 1):
        var run: Array[float] = candidates.slice(start, start + SAMPLE_COUNT)
        var interval: float = run[1] - run[0]
        var regular: bool = interval > 0.0
        for index: int in range(1, run.size()):
            regular = regular and absf((run[index] - run[index - 1]) - interval) <= 0.025
        if regular:
            sample_times = run
            tap_positions.clear()
            return true
    return false

func preview_start_seconds() -> float:
    return maxf(0.0, sample_times[0] - PREVIEW_LEAD_SECONDS) if not sample_times.is_empty() else 0.0

func register_tap(audio_position: float) -> bool:
    if tap_positions.size() >= SAMPLE_COUNT or not is_finite(audio_position):
        return false
    var expected: float = sample_times[tap_positions.size()]
    if absf(audio_position - expected) > MAX_TAP_DISTANCE_SECONDS:
        return false
    tap_positions.append(audio_position)
    last_error_seconds = 0.0
    for index: int in tap_positions.size():
        last_error_seconds += tap_positions[index] - sample_times[index]
    last_error_seconds /= float(tap_positions.size())
    return true

func is_complete() -> bool:
    return tap_positions.size() == SAMPLE_COUNT

func adjusted_offset_ms() -> float:
    if not is_complete():
        return base_offset_ms
    var total_error: float = 0.0
    for index: int in SAMPLE_COUNT:
        total_error += tap_positions[index] - sample_times[index]
    last_error_seconds = total_error / float(SAMPLE_COUNT)
    return base_offset_ms + last_error_seconds * 1000.0

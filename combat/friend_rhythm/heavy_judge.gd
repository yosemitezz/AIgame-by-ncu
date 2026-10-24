# Adapted from MIT boss_attack/scripts/heavy_judge.gd by zjuan-ctrl, PR #1/#3.
# See third_party/friend-boss-pr1/LICENSE. No source audio/chart is loaded here.
extends RefCounted
## Cosmetic heavy-mark results only. The caller supplies the one music clock.
## Each unjudged mark retains its first accepted press until its right boundary,
## so long frame gaps cannot prune a previously accepted input.
const EPSILON: float = 0.000001
const FEEDBACK_SECONDS: float = 0.6
var window_seconds: float = 0.125
var generation: int = 0
var _clock: float = 0.0
var _marks: Array[Dictionary] = []

func setup(groups: Array[Dictionary], judgement_window: float = 0.125, generation: int = 0, start_time: float = 0.0) -> void:
    window_seconds = maxf(judgement_window, 0.0) if is_finite(judgement_window) else 0.125
    self.generation = generation
    _clock = maxf(0.0, start_time) if is_finite(start_time) else 0.0
    _marks.clear()
    for index: int in groups.size():
        var raw: Variant = groups[index].get("time")
        if not (raw is float or raw is int):
            continue
        var time: float = float(raw)
        if not is_finite(time) or time + window_seconds < _clock - EPSILON:
            continue
        # IDs remain the original bounded array indices, including after a seek.
        _marks.append({"id": index, "time": time, "judged": false, "success": false, "accepted": false, "matched_time": 0.0})

func register_block(now: float) -> void:
    if not _accept_clock(now):
        return
    for mark: Dictionary in _marks:
        if bool(mark["judged"]) or bool(mark["accepted"]):
            continue
        if absf(now - float(mark["time"])) <= window_seconds + EPSILON:
            mark["accepted"] = true
            mark["matched_time"] = now

func update(now: float) -> Array[Dictionary]:
    var results: Array[Dictionary] = []
    if not _accept_clock(now):
        return results
    for mark: Dictionary in _marks:
        if bool(mark["judged"]) or now + EPSILON < float(mark["time"]) + window_seconds:
            continue
        mark["judged"] = true
        mark["success"] = bool(mark["accepted"])
        results.append(_public_mark(mark))
    return results

func get_visible(now: float, lead_seconds: float = 2.0) -> Array[Dictionary]:
    var visible: Array[Dictionary] = []
    if not _accept_clock(now):
        return visible
    var lead: float = maxf(0.0, lead_seconds) if is_finite(lead_seconds) else 2.0
    for mark: Dictionary in _marks:
        var time: float = float(mark["time"])
        if now + lead + EPSILON < time or now > time + window_seconds + FEEDBACK_SECONDS + EPSILON:
            continue
        visible.append(_public_mark(mark))
    return visible

func _accept_clock(now: float) -> bool:
    if not is_finite(now) or now < _clock - EPSILON:
        return false
    _clock = maxf(_clock, now)
    return true

func _public_mark(mark: Dictionary) -> Dictionary:
    var matched: Variant = null
    var error: Variant = null
    if bool(mark["judged"]) and bool(mark["success"]):
        matched = float(mark["matched_time"])
        error = float(matched) - float(mark["time"])
    return {"id": int(mark["id"]), "time": float(mark["time"]), "judged": bool(mark["judged"]), "success": bool(mark["success"]), "generation": generation, "feedback_until": float(mark["time"]) + window_seconds + FEEDBACK_SECONDS, "matched_time": matched, "error_seconds": error}

extends RefCounted
class_name HeavyJudge

## Judges every heavy group independently. Results are delayed until the
## right edge of the window so a late but valid block can still succeed.

var window_seconds: float
var _marks: Array[Dictionary] = []
var _block_times: Array[float] = []


func setup(groups: Array[Dictionary], judgement_window: float = 0.125) -> void:
	window_seconds = maxf(judgement_window, 0.0)
	_marks.clear()
	_block_times.clear()
	for group in groups:
		_marks.append({
			"time": float(group["time"]),
			"judged": false,
			"success": false,
		})


func register_block(now: float) -> void:
	_block_times.append(now)


func update(now: float) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	for mark in _marks:
		if mark["judged"]:
			continue
		var event_time := float(mark["time"])
		if now + 0.000001 < event_time + window_seconds:
			continue
		mark["judged"] = true
		mark["success"] = _has_block(event_time)
		results.append(mark.duplicate())
	_block_times = _block_times.filter(func(value: float) -> bool: return now - value <= window_seconds * 3.0)
	return results


func get_block_time_for(event_time: float) -> float:
	for value in _block_times:
		if absf(value - event_time) <= window_seconds + 0.000001:
			return value
	return INF


func _has_block(event_time: float) -> bool:
	for value in _block_times:
		if absf(value - event_time) <= window_seconds + 0.000001:
			return true
	return false

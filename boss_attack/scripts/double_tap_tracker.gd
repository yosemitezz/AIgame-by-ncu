extends RefCounted
class_name DoubleTapTracker

## Double-tap state is kept per direction so A, D, S, and W cannot consume
## each other's presses.

var window_seconds: float
var _last_press: Dictionary = {}


func _init(double_tap_window: float = 0.25) -> void:
	window_seconds = maxf(double_tap_window, 0.001)


func register_press(direction: StringName, now: float) -> bool:
	var previous := INF
	if _last_press.has(direction):
		previous = float(_last_press[direction])
	_last_press[direction] = now
	if previous == INF:
		return false
	var elapsed := now - previous
	if elapsed >= 0.0 and elapsed <= window_seconds:
		_last_press.erase(direction)
		return true
	return false


func reset() -> void:
	_last_press.clear()


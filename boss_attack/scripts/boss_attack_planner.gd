extends RefCounted
class_name BossAttackPlanner

## Converts the JSON action list into an immutable chart-time attack plan.
## Target positions are locked when the plan is created; later player movement
## cannot change a dash destination.


static func build_plan(
	pattern: Dictionary,
	start_time: float,
	beat_seconds: float,
	boss_position: Vector2,
	locked_player_position: Vector2,
	arena_rect: Rect2
) -> Dictionary:
	var parameters: Dictionary = pattern.get("parameters", {})
	var actions_source: Array = parameters.get("actions", pattern.get("actions", []))
	var plan_actions: Array[Dictionary] = []
	for source_value in actions_source:
		var source := (source_value as Dictionary).duplicate(true)
		var beat := float(source.get("beat", 0.0))
		var action := source.duplicate(true)
		action["time"] = start_time + beat * beat_seconds
		action["source_beat"] = beat
		action["resolved_target"] = _resolve_target(str(source.get("target", "")), boss_position, locked_player_position, arena_rect)
		plan_actions.append(action)
	plan_actions.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["time"]) < float(b["time"]))
	return {
		"pattern_id": str(pattern.get("pattern_id", pattern.get("display_name", "unnamed"))),
		"start_time": start_time,
		"end_time": start_time + 4.0 * beat_seconds,
		"locked_player": locked_player_position,
		"actions": plan_actions,
	}


static func build_fixed_cube(
	parameters: Dictionary,
	start_time: float,
	beat_seconds: float,
	boss_position: Vector2,
	arena_rect: Rect2,
	occurrence: int,
	orientation_diamond: bool
) -> Dictionary:
	var flight := float(parameters.get("cube_flight_beats", 2.0)) * beat_seconds
	var warning := float(parameters.get("warning_beats", 2.0)) * beat_seconds
	var lanes: Array = parameters.get("target_lanes", [{"x": 0.5, "y": 0.5}])
	var lane: Dictionary = lanes[posmod(occurrence, lanes.size())]
	var target := Vector2(
		lerpf(arena_rect.position.x, arena_rect.end.x, float(lane.get("x", 0.5))),
		lerpf(arena_rect.position.y, arena_rect.end.y, float(lane.get("y", 0.5)))
	)
	return {
		"start_time": start_time,
		"flight_end_time": start_time + flight,
		"damage_time": start_time + flight + warning,
		"active_until": start_time + flight + warning + float(parameters.get("line_hold_seconds", 0.9)),
		"from": boss_position,
		"to": target,
		"diamond": orientation_diamond,
		"thickness": float(parameters.get("line_thickness", 10.0)),
	}


static func _resolve_target(
	kind: String,
	boss_position: Vector2,
	locked_player_position: Vector2,
	arena_rect: Rect2
) -> Vector2:
	var margin := 30.0
	match kind:
		"locked_player":
			return Vector2(
				clampf(locked_player_position.x, arena_rect.position.x + margin, arena_rect.end.x - margin),
				clampf(locked_player_position.y, arena_rect.position.y + margin, arena_rect.end.y - margin)
			)
		"arena_left":
			return Vector2(arena_rect.position.x + margin, locked_player_position.y)
		"arena_right":
			return Vector2(arena_rect.end.x - margin, locked_player_position.y)
		"center":
			return arena_rect.get_center()
		_:
			return boss_position

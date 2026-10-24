extends RefCounted
class_name LaserFormationPlanner

## Produces full-screen infinite line geometry. Every formation leaves multiple
## gaps, and the safe offsets change between occurrences so "stand center" does
## not remain a universal solution.


static func build_lines(formation: Dictionary, config: Dictionary, arena_rect: Rect2) -> Array[Dictionary]:
	var pattern := str(formation.get("pattern", "diamond"))
	var occurrence := int(formation.get("occurrence", 0))
	var patterns: Dictionary = config.get("patterns", {})
	var pattern_config: Dictionary = patterns.get(pattern, {})
	var records: Array = formation.get("lasers", [])
	var thickness := float(config.get("line_thickness", 9.0))
	var center := arena_rect.get_center()
	var safe_offsets: Array = pattern_config.get("safe_offsets", [[0.0, 0.0]])
	var safe_offset_value: Array = safe_offsets[occurrence % safe_offsets.size()]
	var safe_shift := Vector2(
		float(safe_offset_value[0]) * arena_rect.size.x,
		float(safe_offset_value[1]) * arena_rect.size.y
	)
	var base := center + safe_shift
	var lines: Array[Dictionary] = []

	for index in records.size():
		var origin := base
		var angle_degrees := 0.0
		match pattern:
			"diamond":
				var safe_radius := float(pattern_config.get("safe_radius", 44.0))
				var angles := [135.0, 45.0, 135.0, 45.0]
				var side := 1.0 if index < 2 else -1.0
				angle_degrees = angles[index % angles.size()]
				origin = base + Vector2(-safe_radius if index % 2 == 0 else safe_radius, 0.0) * side
			"parallel":
				angle_degrees = 45.0 if occurrence % 2 == 0 else 135.0
				var offsets: Array = pattern_config.get("line_offsets", [-36.0, -12.0, 12.0, 36.0])
				var offset := float(offsets[index % offsets.size()])
				var normal := Vector2.from_angle(deg_to_rad(angle_degrees + 90.0))
				origin = base + normal * offset
			"grid":
				var vertical_gap := float(pattern_config.get("vertical_half_gap", 64.0))
				var horizontal_gap := float(pattern_config.get("horizontal_half_gap", 43.0))
				if index < 2:
					angle_degrees = 90.0
					origin = Vector2(base.x + (-vertical_gap if index == 0 else vertical_gap), arena_rect.position.y - 20.0)
				else:
					angle_degrees = 0.0
					origin = Vector2(arena_rect.position.x - 20.0, base.y + (-horizontal_gap if index == 2 else horizontal_gap))
			"rotating":
				var radius := float(pattern_config.get("safe_radius", 38.0))
				var angles := [32.0, 148.0, 32.0, 148.0]
				angle_degrees = angles[index % angles.size()]
				var normal := Vector2.from_angle(deg_to_rad(angle_degrees + 90.0))
				var offset := radius * (-1.0 if index < 2 else 1.0)
				origin = base + normal * offset + Vector2(0.0, -radius * 0.45 if index % 2 == 0 else radius * 0.45)

		var record: Dictionary = records[index]
		lines.append({
			"formation_index": int(formation.get("index", -1)),
			"line_index": index,
			"pattern": pattern,
			"angle_radians": deg_to_rad(angle_degrees),
			"origin": origin,
			"thickness": thickness,
			"warning_time": float(record["time"]),
			"damage_time": float(record["damage_time"]),
			"active_until": float(formation.get("active_until", record["damage_time"] + 0.7)),
			"damage": float(record.get("damage", 6.0)),
			"source_index": int(record.get("source_index", -1)),
		})
	return lines

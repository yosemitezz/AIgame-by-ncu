extends Node2D
class_name ProjectileSystem

signal projectile_hit_player(damage: float)
signal laser_hit_player(damage: float)

var arena_rect := Rect2(84.0, 38.0, 542.0, 310.0)
var boss_origin := Vector2(320.0, 108.0)
var player: Node2D
var chart_time := 0.0
var barrage_enabled := true

var _bullets: Array[Dictionary] = []
var _lasers: Array[Dictionary] = []
var _cubes: Array[Dictionary] = []
var _config: Dictionary = {}
var _boss_texture: Texture2D
var _laser_rects: Array[Rect2] = []


func configure(config: Dictionary, battle_rect: Rect2) -> void:
	_config = config.duplicate(true)
	arena_rect = battle_rect


func set_player(value: Node2D) -> void:
	player = value


func set_boss_origin(value: Vector2) -> void:
	boss_origin = value


func set_projectile_texture(value: Texture2D) -> void:
	_boss_texture = value
	queue_redraw()


func set_chart_time(value: float) -> void:
	chart_time = value


func begin_phase() -> void:
	barrage_enabled = true


func enter_rest() -> void:
	barrage_enabled = false


func try_training_shot(target: Vector2, delta_time: float) -> bool:
	if not barrage_enabled or player == null:
		return false
	var training: Dictionary = _config.get("training_preview", {})
	if not bool(training.get("enabled", false)):
		return false
	var cooldown := float(training.get("shot_cooldown_seconds", 0.42))
	if chart_time - float(_config.get("_last_shot_time", -INF)) < cooldown:
		return false
	_config["_last_shot_time"] = chart_time
	var speed := float(training.get("projectile_speed", 330.0))
	var direction := (target - boss_origin).normalized()
	_spawn_bullet(
		boss_origin,
		direction * speed,
		float(_config.get("combat", {}).get("normal_attack_damage", 6.0)),
		float(training.get("projectile_radius", 5.0)),
		float(training.get("projectile_ttl_seconds", 0.89))
	)
	return true


func execute_slot(slot: Dictionary, context: Dictionary) -> void:
	var pattern_id := str(slot.get("pattern_id", ""))
	var parameters: Dictionary = (slot.get("parameters", {}) as Dictionary).duplicate(true)
	parameters.merge(context, false)
	spawn_pattern(pattern_id, parameters)


func spawn_ring(
	origin: Vector2,
	count: int,
	angle_offset_degrees: float,
	speed: float,
	ttl_seconds: float,
	damage: float
) -> void:
	for index in maxi(count, 1):
		var angle := deg_to_rad(angle_offset_degrees + 360.0 * float(index) / float(maxi(count, 1)))
		_spawn_bullet(origin, Vector2.from_angle(angle) * speed, damage, 5.0, ttl_seconds)


func spawn_fan(
	origin: Vector2,
	target: Vector2,
	count: int,
	spread_degrees: float,
	angle_offset_degrees: float,
	speed: float,
	ttl_seconds: float,
	damage: float
) -> void:
	var base_direction := (target - origin).normalized()
	if base_direction == Vector2.ZERO:
		base_direction = Vector2.DOWN
	base_direction = base_direction.rotated(deg_to_rad(angle_offset_degrees))
	for index in maxi(count, 1):
		var fraction := 0.5 if count <= 1 else float(index) / float(count - 1)
		var angle := deg_to_rad(spread_degrees) * (fraction - 0.5)
		_spawn_bullet(origin, base_direction.rotated(angle) * speed, damage, 5.0, ttl_seconds)


func spawn_side_spray(origin: Vector2, count: int, speed: float, ttl_seconds: float, damage: float) -> void:
	for index in maxi(count, 1):
		var x_offset := (float(index) - float(count - 1) * 0.5) * 13.0
		var launch := origin + Vector2(x_offset, 0.0)
		_spawn_bullet(launch, Vector2.UP * speed + Vector2.RIGHT * speed * 0.22, damage, 5.0, ttl_seconds)
		_spawn_bullet(launch, Vector2.DOWN * speed + Vector2.RIGHT * speed * 0.22, damage, 5.0, ttl_seconds)


func spawn_diagonal_cube(cube: Dictionary) -> void:
	var data := cube.duplicate(true)
	data["position"] = data["from"]
	data["fired"] = false
	_cubes.append(data)


func queue_laser_geometry(line: Dictionary) -> void:
	var laser := line.duplicate(true)
	laser["configured"] = true
	laser["generic_line"] = true
	laser["hit"] = false
	_lasers.append(laser)
	queue_redraw()


func spawn_pattern(pattern_id: StringName, parameters: Dictionary = {}) -> void:
	var count := maxi(int(parameters.get("count", 1)), 1)
	var speed := float(parameters.get("speed", 300.0))
	var spread_degrees := float(parameters.get("spread_degrees", 0.0))
	var target := player.global_position if player != null else Vector2(320.0, 280.0)
	var base_direction := (target - boss_origin).normalized()
	match str(pattern_id):
		"aimed", "training_aimed":
			for index in count:
				var offset_angle := 0.0
				if count > 1:
					offset_angle = deg_to_rad(spread_degrees) * ((float(index) / float(count - 1)) - 0.5)
				_spawn_bullet(boss_origin, base_direction.rotated(offset_angle) * speed, float(parameters.get("damage", 6.0)), 5.0, 0.9)
		"spread":
			for index in count:
				var angle := deg_to_rad(spread_degrees) * ((float(index) / float(maxi(count - 1, 1))) - 0.5)
				_spawn_bullet(boss_origin, base_direction.rotated(angle) * speed, float(parameters.get("damage", 6.0)), 5.0, float(parameters.get("ttl_seconds", 1.2)))
		"radial":
			var starting_angle := float(parameters.get("start_angle_degrees", 0.0))
			for index in count:
				var angle := deg_to_rad(starting_angle + 360.0 * float(index) / float(count))
				_spawn_bullet(boss_origin, Vector2.from_angle(angle) * speed, float(parameters.get("damage", 6.0)), 5.0, float(parameters.get("ttl_seconds", 1.4)))
		"rain":
			for index in count:
				var lane_t := (float(index) + 0.5) / float(count)
				var start := Vector2(lerpf(arena_rect.position.x + 12.0, arena_rect.end.x - 12.0, lane_t), arena_rect.position.y - 8.0)
				_spawn_bullet(start, Vector2.DOWN * speed, float(parameters.get("damage", 6.0)), 5.0, float(parameters.get("ttl_seconds", 1.7)))
		_:
			push_warning("No projectile pattern configured for '%s'" % pattern_id)


func queue_laser_warning(laser: Dictionary) -> void:
	var training: Dictionary = _config.get("training_preview", {})
	if not bool(training.get("laser_enabled", false)):
		_lasers.append({"event": laser.duplicate(true), "configured": false, "hit": false})
		return
	var damage_time := float(laser["damage_time"])
	_lasers.append({
		"event": laser.duplicate(true),
		"configured": true,
		"direction": str(training.get("laser_direction", "horizontal")),
		"lane_ratio": float(training.get("laser_lane_ratio", 0.52)),
		"hold_seconds": float(training.get("laser_hold_seconds", 0.55)),
		"thickness": float(training.get("laser_dimensions", 12.0)),
		"damage_time": damage_time,
		"active_until": damage_time + float(training.get("laser_hold_seconds", 0.55)),
		"hit": false,
	})
	queue_redraw()


func configure_pending_laser(event_source_index: int, direction: String, lane_ratio: float, hold_seconds: float, thickness: float) -> bool:
	for laser in _lasers:
		var event: Dictionary = laser["event"]
		if int(event["source_index"]) != event_source_index:
			continue
		laser["configured"] = true
		laser["direction"] = direction
		laser["lane_ratio"] = lane_ratio
		laser["hold_seconds"] = hold_seconds
		laser["thickness"] = thickness
		laser["active_until"] = float(laser["damage_time"]) + hold_seconds
		return true
	return false


func clear_barrages() -> void:
	_bullets.clear()
	_lasers.clear()
	_cubes.clear()
	_laser_rects.clear()
	queue_redraw()


func projectile_count() -> int:
	return _bullets.size()


func _process(delta: float) -> void:
	for bullet in _bullets:
		bullet["position"] = (bullet["position"] as Vector2) + (bullet["velocity"] as Vector2) * delta
		bullet["ttl"] = float(bullet["ttl"]) - delta

	var surviving: Array[Dictionary] = []
	for bullet in _bullets:
		var position := bullet["position"] as Vector2
		var expired := float(bullet["ttl"]) <= 0.0 or not arena_rect.grow(30.0).has_point(position)
		if expired:
			continue
		if player != null and position.distance_to(player.global_position) <= float(bullet["radius"]) + 10.0:
			if player.has_method("receive_damage"):
				var accepted: bool = player.receive_damage(float(bullet["damage"]), position, float(_config.get("combat", {}).get("hurt_knockback", 35.0)))
				if accepted:
					projectile_hit_player.emit(float(bullet["damage"]))
			continue
		surviving.append(bullet)
	_bullets = surviving

	_update_cubes()

	_laser_rects.clear()
	var surviving_lasers: Array[Dictionary] = []
	for laser in _lasers:
		if not bool(laser.get("configured", false)):
			surviving_lasers.append(laser)
			continue
		var damage_time := float(laser["damage_time"])
		var active_until := float(laser["active_until"])
		if chart_time > active_until + 0.2:
			continue
		var beam_rect := _beam_rect(laser)
		_laser_rects.append(beam_rect)
		if chart_time >= damage_time and chart_time <= active_until and not bool(laser.get("hit", false)):
			var intersects := false
			if bool(laser.get("generic_line", false)):
				intersects = _point_hits_line(player.global_position if player != null else Vector2.ZERO, laser, 10.0)
			else:
				intersects = beam_rect.grow(10.0).has_point(player.global_position) if player != null else false
			if player != null and intersects:
				var damage := float(_config.get("combat", {}).get("normal_attack_damage", 6.0))
				damage = float(laser.get("damage", damage))
				if player.has_method("receive_damage"):
					var accepted: bool = player.receive_damage(damage, player.global_position + Vector2.UP * 20.0, 20.0)
					if accepted:
						laser["hit"] = true
						laser_hit_player.emit(damage)
		surviving_lasers.append(laser)
	_lasers = surviving_lasers
	queue_redraw()


func _update_cubes() -> void:
	var surviving: Array[Dictionary] = []
	for cube in _cubes:
		var flight_end := float(cube["flight_end_time"])
		var damage_time := float(cube["damage_time"])
		if chart_time <= flight_end:
			var duration := maxf(flight_end - float(cube["start_time"]), 0.001)
			var t := clampf((chart_time - float(cube["start_time"])) / duration, 0.0, 1.0)
			cube["position"] = (cube["from"] as Vector2).lerp(cube["to"] as Vector2, t)
		else:
			cube["position"] = cube["to"]
		if chart_time >= damage_time and not bool(cube.get("fired", false)):
			cube["fired"] = true
			var angles := [45.0, 135.0] if bool(cube.get("diamond", false)) else [0.0, 90.0]
			for index in angles.size():
				_lasers.append({
					"configured": true,
					"generic_line": true,
					"hit": false,
					"origin": cube["to"],
					"angle_radians": deg_to_rad(float(angles[index])),
					"thickness": float(cube.get("thickness", 10.0)),
					"warning_time": damage_time,
					"damage_time": damage_time,
					"active_until": float(cube["active_until"]),
					"damage": float(_config.get("combat", {}).get("normal_attack_damage", 6.0)),
					"source_index": -1,
				})
		if chart_time <= float(cube["active_until"]) + 0.2:
			surviving.append(cube)
	_cubes = surviving


func _point_hits_line(point: Vector2, laser: Dictionary, player_radius: float) -> bool:
	var origin := laser["origin"] as Vector2
	var angle := float(laser["angle_radians"])
	var normal := Vector2.from_angle(angle + PI * 0.5)
	return absf((point - origin).dot(normal)) <= float(laser.get("thickness", 9.0)) * 0.5 + player_radius


func _beam_rect(laser: Dictionary) -> Rect2:
	if bool(laser.get("generic_line", false)):
		return Rect2(laser["origin"] as Vector2, Vector2.ZERO)
	var direction := str(laser.get("direction", "horizontal"))
	var lane_ratio := float(laser.get("lane_ratio", 0.5))
	var thickness := float(laser.get("thickness", 12.0))
	if direction == "vertical":
		var x := lerpf(arena_rect.position.x, arena_rect.end.x, lane_ratio)
		return Rect2(x - thickness * 0.5, arena_rect.position.y, thickness, arena_rect.size.y)
	var y := lerpf(arena_rect.position.y, arena_rect.end.y, lane_ratio)
	return Rect2(arena_rect.position.x, y - thickness * 0.5, arena_rect.size.x, thickness)


func _spawn_bullet(start: Vector2, velocity: Vector2, damage: float, radius: float, ttl: float) -> void:
	_bullets.append({
		"position": start,
		"velocity": velocity,
		"damage": damage,
		"radius": radius,
		"ttl": ttl,
	})


func _draw() -> void:
	for bullet in _bullets:
		var position := bullet["position"] as Vector2
		if _boss_texture != null:
			var size := _boss_texture.get_size()
			draw_texture_rect(_boss_texture, Rect2(position - size * 0.5, size), false)
		else:
			draw_circle(position, float(bullet["radius"]), Color("#ffcb5a"))
			draw_circle(position, float(bullet["radius"]) * 0.45, Color("#fff6cc"))

	for laser in _lasers:
		if not bool(laser.get("configured", false)):
			continue
		var damage_time := float(laser["damage_time"])
		var active_until := float(laser["active_until"])
		if bool(laser.get("generic_line", false)):
			if chart_time < float(laser["warning_time"]):
				continue
			var angle := float(laser["angle_radians"])
			var direction := Vector2.from_angle(angle)
			var origin := laser["origin"] as Vector2
			var low := origin - direction * 1000.0
			var high := origin + direction * 1000.0
			var width := float(laser.get("thickness", 9.0))
			if chart_time < damage_time:
				draw_line(low, high, Color(1.0, 0.22, 0.25, 0.35), 2.0)
				draw_line(low, high, Color(1.0, 0.22, 0.25, 0.14), width + 8.0)
			elif chart_time <= active_until:
				draw_line(low, high, Color("#ff304d"), width + 5.0)
				draw_line(low, high, Color("#fff0cf"), maxf(width - 3.0, 1.0))
			continue

		var rect := _beam_rect(laser)
		if chart_time < damage_time:
			draw_rect(rect, Color(1.0, 0.18, 0.2, 0.2), true)
			if rect.size.x >= rect.size.y:
				draw_line(Vector2(rect.position.x, rect.get_center().y), Vector2(rect.end.x, rect.get_center().y), Color(1.0, 0.25, 0.28, 0.8), 2.0)
			else:
				draw_line(Vector2(rect.get_center().x, rect.position.y), Vector2(rect.get_center().x, rect.end.y), Color(1.0, 0.25, 0.28, 0.8), 2.0)
		elif chart_time <= active_until:
			draw_rect(rect, Color("#ff304d"), true)
			draw_rect(rect.grow(-3.0), Color("#fff0cf"), true)

	for cube in _cubes:
		var position := cube["position"] as Vector2
		var half := 16.0
		var points := PackedVector2Array([
			position + Vector2(-half, 0),
			position + Vector2(0, -half),
			position + Vector2(half, 0),
			position + Vector2(0, half),
		])
		draw_colored_polygon(points, Color("#79c9ff"))
		draw_polyline(points + PackedVector2Array([points[0]]), Color.WHITE, 2.0)
		if not bool(cube.get("fired", false)):
			draw_circle(position, 4.0, Color("#fff0ae"))


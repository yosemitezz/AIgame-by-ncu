extends Node2D
class_name BossController

signal health_changed(current: float, maximum: float)
signal defeated
signal attack_started(pattern_id: StringName)

var max_health := 3200.0
var health := 3200.0
var arena_rect := Rect2(84.0, 38.0, 542.0, 310.0)
var home_position := Vector2.ZERO
var beat_seconds := 60.0 / 203.0
var current_pattern_id: StringName = &""

var _hit_flash := 0.0
var _chart_time := 0.0
var _plan: Dictionary = {}
var _action_index := 0
var _dash: Dictionary = {}
var _dash_hit_done := false
var _telegraph_target := Vector2.ZERO
var _telegraph_until := -INF
var _fixed_parameters: Dictionary = {}
var _cube_occurrence := 0
var _rng := RandomNumberGenerator.new()
var _projectiles: ProjectileSystem
var _player: PlayerCombat

@onready var sprite: Sprite2D = get_node_or_null("Sprite2D")


func _ready() -> void:
	home_position = global_position
	_rng.randomize()
	queue_redraw()


func configure(config: Dictionary, battle_rect: Rect2 = arena_rect) -> void:
	max_health = float(config.get("combat", {}).get("boss_max_health", max_health))
	health = max_health
	arena_rect = battle_rect
	beat_seconds = 60.0 / float(config.get("bpm", 203.0))
	health_changed.emit(health, max_health)


func set_battle_context(player_value: PlayerCombat, projectiles_value: ProjectileSystem) -> void:
	_player = player_value
	_projectiles = projectiles_value


func set_fixed_parameters(parameters: Dictionary) -> void:
	_fixed_parameters = parameters.duplicate(true)


func set_visual_texture(texture: Texture2D) -> void:
	if sprite != null:
		sprite.texture = texture
		sprite.visible = texture != null
	queue_redraw()


func begin_attack(pattern: Dictionary, start_time: float, locked_player_position: Vector2) -> bool:
	var actions: Array = (pattern.get("parameters", {}) as Dictionary).get("actions", pattern.get("actions", []))
	if actions.is_empty():
		return false
	_plan = BossAttackPlanner.build_plan(
		pattern,
		start_time,
		beat_seconds,
		global_position,
		locked_player_position,
		arena_rect
	)
	_action_index = 0
	_dash.clear()
	_dash_hit_done = false
	current_pattern_id = StringName(str(pattern.get("pattern_id", pattern.get("display_name", "unnamed"))))
	attack_started.emit(current_pattern_id)
	advance_to(start_time)
	return true


func begin_fixed_one(pattern: Dictionary, start_time: float, occurrence: int, force_diamond: int = -1) -> bool:
	if _projectiles == null:
		return false
	var parameters: Dictionary = pattern.get("parameters", {})
	if _fixed_parameters.is_empty():
		_fixed_parameters = parameters.duplicate(true)
	var diamond := force_diamond >= 0
	if force_diamond < 0:
		diamond = _rng.randi_range(0, 1) == 1
	var cube := BossAttackPlanner.build_fixed_cube(
		parameters,
		start_time,
		beat_seconds,
		global_position,
		arena_rect,
		occurrence,
		diamond
	)
	_projectiles.spawn_diagonal_cube(cube)
	current_pattern_id = &"cube_diagonal_lasers"
	attack_started.emit(current_pattern_id)
	return true


func advance_to(chart_time: float) -> void:
	_chart_time = maxf(_chart_time, chart_time)
	if not _plan.is_empty():
		var actions: Array = _plan["actions"]
		while _action_index < actions.size():
			var action: Dictionary = actions[_action_index]
			if float(action["time"]) > _chart_time + 0.000001:
				break
			_execute_action(action)
			_action_index += 1
		if _chart_time > float(_plan["end_time"]) + 0.4 and _action_index >= actions.size():
			_plan.clear()
	_update_dash()
	queue_redraw()


func take_damage(amount: float) -> void:
	if health <= 0.0:
		return
	health = maxf(0.0, health - amount)
	_hit_flash = 0.12
	health_changed.emit(health, max_health)
	queue_redraw()
	if health <= 0.0:
		defeated.emit()


func _execute_action(action: Dictionary) -> void:
	var target: Vector2 = action.get("resolved_target", global_position)
	match str(action["type"]):
		"aim":
			_telegraph_target = target
			_telegraph_until = _chart_time + beat_seconds * 2.0
		"teleport":
			global_position = _clamp_position(target)
		"center":
			global_position = arena_rect.get_center()
		"dash":
			var duration_beats := float(action.get("duration_beats", 1.0))
			_dash = {
				"start_time": _chart_time,
				"end_time": _chart_time + duration_beats * beat_seconds,
				"from": global_position,
				"to": _clamp_position(target),
				"damage": float(action.get("damage", 6.0)),
			}
			_dash_hit_done = false
		"ring":
			if _projectiles != null:
				_projectiles.spawn_ring(
					global_position,
					int(action.get("count", 8)),
					float(action.get("angle_offset_degrees", 0.0)),
					float(action.get("speed", 150.0)),
					float(action.get("ttl_seconds", 2.0)),
					float(action.get("damage", 6.0))
				)
		"fan":
			if _projectiles != null:
				_projectiles.spawn_fan(
					global_position,
					_plan.get("locked_player", target),
					int(action.get("count", 3)),
					float(action.get("spread_degrees", 34.0)),
					float(action.get("angle_offset_degrees", 0.0)),
					float(action.get("speed", 180.0)),
					float(action.get("ttl_seconds", 1.8)),
					float(action.get("damage", 6.0))
				)
		"side_spray":
			if _projectiles != null:
				_projectiles.spawn_side_spray(
					global_position,
					int(action.get("count", 3)),
					float(action.get("speed", 118.0)),
					float(action.get("ttl_seconds", 2.0)),
					float(action.get("damage", 6.0))
				)


func _update_dash() -> void:
	if _dash.is_empty():
		return
	var start_time := float(_dash["start_time"])
	var end_time := float(_dash["end_time"])
	if _chart_time < start_time:
		return
	var progress := clampf((_chart_time - start_time) / maxf(end_time - start_time, 0.001), 0.0, 1.0)
	global_position = (_dash["from"] as Vector2).lerp(_dash["to"] as Vector2, progress)
	if not _dash_hit_done and _player != null:
		if global_position.distance_to(_player.global_position) <= 28.0:
			_dash_hit_done = true
			_player.receive_damage(float(_dash.get("damage", 6.0)), global_position, 24.0)
	if _chart_time >= end_time:
		global_position = _clamp_position(_dash["to"] as Vector2)
		_dash.clear()
		_dash_hit_done = false


func _clamp_position(value: Vector2) -> Vector2:
	var margin := 30.0
	return Vector2(
		clampf(value.x, arena_rect.position.x + margin, arena_rect.end.x - margin),
		clampf(value.y, arena_rect.position.y + margin, arena_rect.end.y - margin)
	)


func _process(delta: float) -> void:
	if _hit_flash > 0.0:
		_hit_flash = maxf(0.0, _hit_flash - delta)
		queue_redraw()


func _draw() -> void:
	if sprite == null or sprite.texture == null:
		var color := Color("#ff5b6e") if _hit_flash <= 0.0 else Color.WHITE
		var points := PackedVector2Array([
			Vector2(-34, 18), Vector2(-26, -12), Vector2(-10, -27),
			Vector2(0, -40), Vector2(12, -24), Vector2(29, -14),
			Vector2(35, 19), Vector2(14, 31), Vector2(-12, 31),
		])
		draw_colored_polygon(points, color)
		draw_circle(Vector2(-12, -8), 4.0, Color("#fff3c4"))
		draw_circle(Vector2(12, -8), 4.0, Color("#fff3c4"))
		draw_line(Vector2(-8, 12), Vector2(8, 12), Color("#64162d"), 3.0)
	if not _dash.is_empty():
		draw_line(Vector2(-20, 24), Vector2(20, 24), Color("#ffb347"), 3.0)
	if _chart_time <= _telegraph_until:
		draw_line(Vector2.ZERO, _telegraph_target - global_position, Color(1.0, 0.2, 0.25, 0.48), 2.0)
		draw_circle(_telegraph_target - global_position, 8.0, Color(1.0, 0.2, 0.25, 0.2))

extends CharacterBody2D
class_name PlayerCombat

signal health_changed(current: float, maximum: float)
signal dash_started(direction: Vector2)
signal dash_unavailable(direction: Vector2)
signal block_started
signal sword_active
signal damaged(amount: float)
signal defeated

const ACTION_LEFT := &"move_left"
const ACTION_RIGHT := &"move_right"
const ACTION_UP := &"move_up"
const ACTION_DOWN := &"move_down"
const ACTION_BLOCK := &"block"
const ACTION_ATTACK := &"attack"

var max_health := 100.0
var health := 100.0
var regen_per_second := 0.5
var move_speed := 118.0
var dash_seconds := 0.17
var dash_cooldown := 0.42
var dash_speed := 620.0
var invulnerability_seconds := 0.23
var sword_windup := 0.34
var sword_active_time := 0.13
var sword_recovery := 0.24

var arena_rect := Rect2(84.0, 38.0, 542.0, 310.0)
var double_tap := DoubleTapTracker.new(0.25)

var _time := 0.0
var _dash_remaining := 0.0
var _dash_direction := Vector2.ZERO
var _invulnerable_remaining := 0.0
var _dash_cooldowns: Dictionary = {
	"left": 0.0,
	"right": 0.0,
	"up": 0.0,
	"down": 0.0,
}
var _attack_state := "idle"
var _attack_timer := 0.0
var _attack_resolved := false
var _block_flash := 0.0
var _hurt_flash := 0.0

@onready var sprite: Sprite2D = get_node_or_null("Sprite2D")


func _ready() -> void:
	_ensure_input_actions()
	health = max_health
	queue_redraw()


func configure(config: Dictionary, battle_rect: Rect2) -> void:
	var combat: Dictionary = config.get("combat", {})
	max_health = float(combat.get("player_max_health", max_health))
	health = max_health
	regen_per_second = float(combat.get("health_regen_per_second", regen_per_second))
	move_speed = float(combat.get("move_speed", move_speed))
	dash_seconds = float(combat.get("dash_seconds", dash_seconds))
	dash_cooldown = float(combat.get("dash_cooldown_seconds", dash_cooldown))
	dash_speed = float(combat.get("dash_speed", dash_speed))
	invulnerability_seconds = float(combat.get("dash_invulnerability_seconds", invulnerability_seconds))
	sword_windup = float(combat.get("sword_windup_seconds", sword_windup))
	sword_active_time = float(combat.get("sword_active_seconds", sword_active_time))
	sword_recovery = float(combat.get("sword_recovery_seconds", sword_recovery))
	double_tap.window_seconds = float(config.get("double_tap_seconds", double_tap.window_seconds))
	arena_rect = battle_rect
	health_changed.emit(health, max_health)


func set_visual_texture(texture: Texture2D) -> void:
	if sprite != null:
		sprite.texture = texture
		sprite.visible = texture != null
	queue_redraw()


func is_invulnerable() -> bool:
	return _invulnerable_remaining > 0.0


func is_dashing() -> bool:
	return _dash_remaining > 0.0


func receive_damage(amount: float, source_position: Vector2, knockback_force: float = 35.0) -> bool:
	if health <= 0.0 or is_invulnerable():
		return false
	health = maxf(0.0, health - amount)
	_invulnerable_remaining = maxf(_invulnerable_remaining, 0.1)
	_hurt_flash = 0.15
	var knockback_direction := (global_position - source_position).normalized()
	if knockback_direction == Vector2.ZERO:
		knockback_direction = Vector2.DOWN
	global_position += knockback_direction * minf(knockback_force, 40.0)
	_clamp_to_arena()
	health_changed.emit(health, max_health)
	damaged.emit(amount)
	queue_redraw()
	if health <= 0.0:
		defeated.emit()
	return true


func reset() -> void:
	health = max_health
	_dash_remaining = 0.0
	_invulnerable_remaining = 0.0
	_attack_state = "idle"
	_attack_timer = 0.0
	double_tap.reset()
	health_changed.emit(health, max_health)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(ACTION_LEFT):
		_handle_direction_press("left", Vector2.LEFT, _time)
	elif event.is_action_pressed(ACTION_RIGHT):
		_handle_direction_press("right", Vector2.RIGHT, _time)
	elif event.is_action_pressed(ACTION_UP):
		_handle_direction_press("up", Vector2.UP, _time)
	elif event.is_action_pressed(ACTION_DOWN):
		_handle_direction_press("down", Vector2.DOWN, _time)
	if event.is_action_pressed(ACTION_BLOCK):
		block_started.emit()
		_block_flash = 0.16
	if event.is_action_pressed(ACTION_ATTACK):
		start_sword_attack()


func _physics_process(delta: float) -> void:
	_time += delta
	_invulnerable_remaining = maxf(0.0, _invulnerable_remaining - delta)
	_block_flash = maxf(0.0, _block_flash - delta)
	_hurt_flash = maxf(0.0, _hurt_flash - delta)
	if health < max_health and health > 0.0:
		health = minf(max_health, health + regen_per_second * delta)
		health_changed.emit(health, max_health)

	if _dash_remaining > 0.0:
		_dash_remaining = maxf(0.0, _dash_remaining - delta)
		global_position += _dash_direction * dash_speed * delta
	else:
		var input_vector := Input.get_vector(ACTION_LEFT, ACTION_RIGHT, ACTION_UP, ACTION_DOWN)
		global_position += input_vector * move_speed * delta
	_clamp_to_arena()
	_update_attack(delta)
	queue_redraw()


func _handle_direction_press(direction: StringName, vector: Vector2, now: float) -> void:
	if not double_tap.register_press(direction, now):
		return
	if now < float(_dash_cooldowns.get(direction, 0.0)) or _dash_remaining > 0.0:
		dash_unavailable.emit(vector)
		return
	_dash_remaining = dash_seconds
	_dash_direction = vector
	_invulnerable_remaining = maxf(_invulnerable_remaining, invulnerability_seconds)
	_dash_cooldowns[direction] = now + dash_cooldown
	dash_started.emit(vector)


func start_sword_attack() -> bool:
	if _attack_state != "idle" or health <= 0.0:
		return false
	_attack_state = "windup"
	_attack_timer = sword_windup
	_attack_resolved = false
	return true


func _update_attack(delta: float) -> void:
	if _attack_state == "idle":
		return
	_attack_timer -= delta
	if _attack_timer > 0.0:
		return
	match _attack_state:
		"windup":
			_attack_state = "active"
			_attack_timer = sword_active_time
			if not _attack_resolved:
				_attack_resolved = true
				sword_active.emit()
		"active":
			_attack_state = "recovery"
			_attack_timer = sword_recovery
		"recovery":
			_attack_state = "idle"
			_attack_timer = 0.0


func _clamp_to_arena() -> void:
	global_position.x = clampf(global_position.x, arena_rect.position.x + 12.0, arena_rect.end.x - 12.0)
	global_position.y = clampf(global_position.y, arena_rect.position.y + 12.0, arena_rect.end.y - 12.0)


func _ensure_input_actions() -> void:
	_bind_key(ACTION_LEFT, KEY_A)
	_bind_key(ACTION_RIGHT, KEY_D)
	_bind_key(ACTION_UP, KEY_W)
	_bind_key(ACTION_DOWN, KEY_S)
	_bind_key(ACTION_BLOCK, KEY_SHIFT)
	_bind_key(ACTION_ATTACK, KEY_J)
	if InputMap.has_action(ACTION_ATTACK):
		var mouse := InputEventMouseButton.new()
		mouse.button_index = MOUSE_BUTTON_LEFT
		InputMap.action_add_event(ACTION_ATTACK, mouse)


func _bind_key(action: StringName, keycode: int) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var already_bound := false
	for existing in InputMap.action_get_events(action):
		if existing is InputEventKey and (existing as InputEventKey).physical_keycode == keycode:
			already_bound = true
			break
	if already_bound:
		return
	var event := InputEventKey.new()
	event.physical_keycode = keycode
	InputMap.action_add_event(action, event)


func _draw() -> void:
	if sprite == null or sprite.texture == null:
		var body_color := Color("#50e3c2")
		if _hurt_flash > 0.0:
			body_color = Color("#ff4560")
		elif _block_flash > 0.0:
			body_color = Color("#79c9ff")
		draw_circle(Vector2.ZERO, 10.0, body_color)
		draw_circle(Vector2.ZERO, 4.0, Color("#eafffb"))
		if is_invulnerable():
			draw_arc(Vector2.ZERO, 14.0, 0.0, TAU, 24, Color(0.7, 0.95, 1.0, 0.75), 2.0)
		if _attack_state != "idle":
			var alpha := 0.35 if _attack_state != "active" else 0.9
			draw_arc(Vector2.ZERO, 28.0, -1.2, 1.2, 18, Color(1.0, 0.86, 0.45, alpha), 3.0)


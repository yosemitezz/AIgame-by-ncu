extends CharacterBody2D
## Combat stages and local impact freeze run independently of the music clock.

signal health_changed(current: int, maximum: int)
signal died
signal state_changed(state: String, frame: int, direction: int)
signal parried

const PixelActor = preload("res://assets/art/pixel_actor.gd")
const AttackProfile = preload("res://combat/attack_profile.gd")
const DirectionTaps = preload("res://combat/double_tap_tracker.gd")
const LightWings = preload("res://vfx/light_wings.gd")
## Air jumps are unlimited: every press in the air jumps again. Wings open at WING_OPEN_RATE per second and fold over WING_FOLD_TIME.
const INFINITE_AIR_JUMPS: bool = true
const WING_OPEN_RATE: float = 9.0
const WING_FOLD_TIME: float = 0.9
const RUN_SPEED: float = 180.0
const JUMP_SPEED: float = -340.0
const GRAVITY: float = 900.0
const DASH_SPEED: float = 420.0
const DASH_DURATION: float = 0.17
const DASH_COOLDOWN: float = 0.42
const DASH_INVULNERABILITY: float = 0.23
const DIRECTION_TAPS: Dictionary = {"move_left": Vector2.LEFT, "move_right": Vector2.RIGHT, "climb_up": Vector2.UP, "climb_down": Vector2.DOWN}
## Crouch walk speed factor, crouch blend time, landing squat, air-jump flip and apex window.
const CROUCH_SPEED: float = 0.45
const CROUCH_BLEND: float = 0.12
const LAND_TIME: float = 0.16
const LAND_MIN_SPEED: float = 230.0
const AIR_FLIP_TIME: float = 0.34
const AIR_APEX_SPEED: float = 60.0
const RUN_FRAME_RATE: float = 14.0
const COYOTE_TIME: float = 0.10
const JUMP_BUFFER: float = 0.12
const CLIMB_SPEED: float = 90.0
const CLIMB_ALIGN_SPEED: float = 80.0
const SHALLOW_WATER_SPEED: float = 0.72
const WATER_SPLASH_INTERVAL: float = 0.18
const PARRY_WINDOW: float = 0.16
const PARRY_RECOIL: float = 0.06
const PARRY_RECOVER: float = 0.10
const PARRY_COUNTER_DELAY: float = 0.035
const PARRY_RECOIL_SPEED: float = 55.0
## Shared damage and visual sweep geometry; retain the main project's cadence and step.
static var HIT_REACH: Array[float] = [AttackProfile.radii(1).x, AttackProfile.radii(2).x, AttackProfile.radii(3).x]
static var ATTACK_STARTUP: float = AttackProfile.duration(1, "windup")
static var COMBO_WINDUP: Array[float] = [AttackProfile.duration(1, "windup"), AttackProfile.duration(2, "windup"), AttackProfile.duration(3, "windup")]
static var COMBO_ACTIVE: Array[float] = [AttackProfile.duration(1, "active"), AttackProfile.duration(2, "active"), AttackProfile.duration(3, "active")]
static var COMBO_RECOVER: Array[float] = [AttackProfile.duration(1, "recover"), AttackProfile.duration(2, "recover"), AttackProfile.duration(3, "recover")]
static var COMBO_LENGTHS: Array[float] = [AttackProfile.total_duration(1), AttackProfile.total_duration(2), AttackProfile.total_duration(3)]
static var LUNGE_TIME: float = float(AttackProfile.profile(1).get("lunge_seconds", 0.085))
static var LUNGE_SPEED: Array[float] = [float(AttackProfile.profile(1).get("lunge_speed", 130.0)), float(AttackProfile.profile(2).get("lunge_speed", 170.0)), float(AttackProfile.profile(3).get("lunge_speed", 210.0))]
const RECOVER_CANCEL_DELAY: float = 0.055
const CONFIRM_CANCEL_DELAY: float = 0.050

var game: Node
var facing: int = 1
var health: int = 8
var max_health: int = 8
var invuln: float = 0.0
var parry_timer: float = 0.0
var parry_phase: String = "none"
var dash_timer: float = 0.0
var dash_direction: Vector2 = Vector2.RIGHT
var _dash_intent: Vector2 = Vector2.ZERO
var _direction_taps: RefCounted = DirectionTaps.new(0.25)
var _tap_clock: float = 0.0
var _tap_held: Dictionary = {}
var _tap_keys: Dictionary = {}
var attack_timer: float = 0.0
var attack_phase: String = "none"
var attack_serial: int = 0
var attack_sweep_from: float = 0.25
var attack_sweep_to: float = 0.25
var _attack_query_progress: float = 0.25
var queued_attack: bool = false
var combat_freeze: float = 0.0
var impact_flash: float = 0.0
var animation_state: String = "idle"
var frame: int = 0
var combo: int = 0
var dead: bool = false
## Held crouch: visual pose plus a slower walk. Collider and attack timing are untouched.
var crouching: bool = false
var _crouch_held: bool = false
var _crouch_out: float = 0.0
var _land_timer: float = 0.0
var _air_flip: float = 0.0
var climbing: bool = false
var climb_kind: String = ""
var climb_id: String = ""
var in_shallow_water: bool = false
var _climb_axis: float = 0.0
var _climb_rect: Rect2 = Rect2()
var _climb_distance: float = 0.0
var _climb_moving: bool = false
var _climb_release_required: bool = false
var _climb_regrab_cooldown: float = 0.0
var _water_splash_cooldown: float = 0.0
var _coyote: float = 0.0
var _jump_buffer: float = 0.0
var _jump_cut_requested: bool = false
var _air_jumps: int = 1
## Wings of light: open on an air jump, stay out while airborne and fold slowly after landing.
var wing_amount: float = 0.0
var wing_flap: float = 0.0
var _wings_out: bool = false
var wings: Node2D
# One per-direction authority. The computed legacy property supports old fixture resets.
var _dash_cooldowns: Dictionary = {Vector2.LEFT: 0.0, Vector2.RIGHT: 0.0, Vector2.UP: 0.0, Vector2.DOWN: 0.0}
var _dash_cooldown: float:
	get:
		return float(_dash_cooldowns.get(dash_direction, 0.0))
	set(value):
		if value <= 0.0:
			for direction: Vector2 in _dash_cooldowns:
				_dash_cooldowns[direction] = 0.0
		else:
			_dash_cooldowns[dash_direction] = value
var _dash_buffer: float = 0.0
var _parry_cooldown: float = 0.0
var _parry_buffer: float = 0.0
var _parry_elapsed: float = 0.0
var _parry_seen: Dictionary = {}
var _move_axis: float = 0.0
var _combo_grace: float = 0.0
var _attack_elapsed: float = 0.0
var _phase_elapsed: float = 0.0
var _hit_confirmed: bool = false
var _strike_done: bool = false
var _lunge_timer: float = 0.0
var _hurt_lock: float = 0.0
var _state_clock: float = 0.0
var _trail_clock: float = 0.0
var _last_frame: int = -1
var _last_state: String = ""
var _last_facing: int = 0

func configure(owner_game: Node) -> void:
	game = owner_game

func _ready() -> void:
	collision_layer = 2
	collision_mask = 1
	floor_snap_length = 5.0
	var collider: CollisionShape2D = CollisionShape2D.new()
	var shape: RectangleShape2D = RectangleShape2D.new()
	shape.size = Vector2(14.0, 26.0)
	collider.shape = shape
	collider.position = Vector2(0.0, -13.0)
	add_child(collider)
	add_to_group("player")
	wings = LightWings.new()
	wings.name = "LightWings"
	add_child(wings)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	health_changed.emit(health, max_health)

func _capture_input() -> void:
	# Capture every edge BEFORE a hit-stop early return. One combo intent survives
	# any windup/active/recovery length and cannot stack into an unattended chain.
	_move_axis = Input.get_axis("move_left", "move_right")
	_capture_direction_taps()
	_climb_axis = Input.get_axis("climb_up", "climb_down") if InputMap.has_action("climb_up") and InputMap.has_action("climb_down") else 0.0
	if is_zero_approx(_climb_axis):
		_climb_release_required = false
	if Input.is_action_just_pressed("attack"):
		queued_attack = true
	if Input.is_action_just_pressed("jump"):
		_jump_buffer = JUMP_BUFFER
	if Input.is_action_just_released("jump"):
		_jump_cut_requested = true
	if Input.is_action_just_pressed("dash"):
		# Empty in the main physical key map; retain the original logical input/test API.
		_dash_buffer = 0.16
		_dash_intent = Vector2(_move_axis if not is_zero_approx(_move_axis) else float(facing), 0.0)
	if Input.is_action_just_pressed("parry"):
		_parry_buffer = 0.12
	_crouch_held = (InputMap.has_action("crouch") and Input.is_action_pressed("crouch")) or (InputMap.has_action("climb_down") and Input.is_action_pressed("climb_down"))

func _unhandled_input(event: InputEvent) -> void:
	# Merge physical aliases into one directional held edge. Releases and new
	# presses can both occur between physics samples, so keep the real key set.
	if dead or _parry_paused() or (is_instance_valid(game) and bool(game.story_safe)):
		return
	if event is InputEventKey and event.echo:
		return
	for action: String in DIRECTION_TAPS:
		if not InputMap.has_action(action):
			continue
		var presses: bool = event.is_action_pressed(action, false)
		var releases: bool = event.is_action_released(action)
		if not presses and not releases:
			continue
		var keys: Dictionary = _tap_keys.get(action, {})
		var was_held: bool = _tap_held.get(action, false) == true
		var code: int = _direction_key(event)
		if presses:
			keys[code] = true
		else:
			keys.erase(code)
		_tap_keys[action] = keys
		_tap_held[action] = not keys.is_empty()
		if presses and not was_held:
			_register_direction_press(action)

func _direction_key(event: InputEvent) -> int:
	if event is InputEventKey:
		return int(event.physical_keycode if event.physical_keycode != 0 else event.keycode)
	return -1

func _register_direction_press(action: String) -> void:
	if _direction_taps.register_press(StringName(action), _tap_clock):
		_dash_intent = DIRECTION_TAPS[action]
		_dash_buffer = 0.16

func _capture_direction_taps() -> void:
	# Logical Input.action_press does not emit an event; retain that old API.
	# The shared held edge prevents event delivery and polling counting twice.
	for action: String in DIRECTION_TAPS:
		if not InputMap.has_action(action):
			continue
		var keys: Dictionary = _tap_keys.get(action, {})
		var pressed: bool = Input.is_action_pressed(action) or not keys.is_empty()
		var was_held: bool = _tap_held.get(action, false) == true
		if pressed and not was_held and Input.is_action_just_pressed(action):
			_register_direction_press(action)
		_tap_held[action] = pressed

func reset_direction_taps() -> void:
	_direction_taps.reset()
	_tap_clock = 0.0
	_dash_buffer = 0.0
	_dash_intent = Vector2.ZERO
	_tap_held.clear()
	_tap_keys.clear()
	# Holding an alias across pause/retry is not a new directional press.
	for action: String in DIRECTION_TAPS:
		var keys: Dictionary = {}
		if InputMap.has_action(action):
			for binding: InputEvent in InputMap.action_get_events(action):
				if binding is InputEventKey:
					var code: int = _direction_key(binding)
					var held: bool = Input.is_physical_key_pressed(code) if binding.physical_keycode != 0 else Input.is_key_pressed(code)
					if held:
						keys[code] = true
		_tap_keys[action] = keys
		_tap_held[action] = not keys.is_empty() or (InputMap.has_action(action) and Input.is_action_pressed(action))

func _physics_process(delta: float) -> void:
	if _parry_paused():
		reset_direction_taps()
		return
	# Pausable physics time for input windows; actor hit-stop does not stop capture.
	_tap_clock += maxf(0.0, delta)
	_capture_input()
	impact_flash = maxf(0.0, impact_flash - delta)
	# Defensive windows and cooldowns use real physics delta, even in local freeze.
	invuln = maxf(0.0, invuln - delta)
	parry_timer = maxf(0.0, parry_timer - delta)
	if parry_timer <= 0.0:
		_parry_seen.clear()
		if parry_phase == "ready":
			_clear_parry()
	elif parry_phase == "none":
		parry_phase = "ready"
	for direction: Vector2 in _dash_cooldowns:
		_dash_cooldowns[direction] = maxf(0.0, float(_dash_cooldowns[direction]) - delta)
	_parry_cooldown = maxf(0.0, _parry_cooldown - delta)
	var safe: bool = is_instance_valid(game) and bool(game.story_safe)
	if safe:
		reset_direction_taps()
		reset_traversal(true)
		_clear_parry()
		_cancel_attack()
		combat_freeze = 0.0
		parry_timer = 0.0
		dash_timer = 0.0
		_dash_buffer = 0.0
		_parry_buffer = 0.0
		_hurt_lock = 0.0
	if dead:
		reset_direction_taps()
		reset_traversal(true)
		_clear_parry()
		_cancel_attack()
		velocity = Vector2.ZERO
		if combat_freeze > 0.0:
			combat_freeze = maxf(0.0, combat_freeze - delta)
			queue_redraw()
			return
		_set_animation("dead", delta)
		return
	if combat_freeze > 0.0:
		combat_freeze = maxf(0.0, combat_freeze - delta)
		queue_redraw()
		return
	_hurt_lock = maxf(0.0, _hurt_lock - delta)
	_land_timer = maxf(0.0, _land_timer - delta)
	_air_flip = maxf(0.0, _air_flip - delta)
	_crouch_out = maxf(0.0, _crouch_out - delta)
	_update_crouch(delta)
	_combo_grace = maxf(0.0, _combo_grace - delta)
	_jump_buffer = maxf(0.0, _jump_buffer - delta)
	_dash_buffer = maxf(0.0, _dash_buffer - delta)
	_parry_buffer = maxf(0.0, _parry_buffer - delta)
	if _move_axis != 0.0 and dash_timer <= 0.0 and attack_phase == "none" and parry_phase == "none":
		facing = 1 if _move_axis > 0.0 else -1
	if is_on_floor():
		_coyote = COYOTE_TIME
		_air_jumps = 1
	else:
		_coyote = maxf(0.0, _coyote - delta)
	_update_climb_intent(delta, safe)
	if not safe:
		_update_water(delta)
	if _dash_buffer > 0.0 and _start_dash(_move_axis, _dash_intent):
		_dash_buffer = 0.0
	elif not safe and _parry_buffer > 0.0:
		_start_parry()
	if queued_attack and attack_phase == "none" and dash_timer <= 0.0 and not _parry_blocks_attack() and _hurt_lock <= 0.0 and not safe:
		_start_attack()
	var used_climb: bool = climbing
	if used_climb:
		_move_climb(delta)
	elif dash_timer > 0.0:
		dash_timer = maxf(0.0, dash_timer - delta)
		velocity = dash_direction * DASH_SPEED
		_trail_clock -= delta
		if _trail_clock <= 0.0:
			_fx("dash_ghost", global_position + Vector2(0.0, -13.0), -dash_direction, 0.55)
			_trail_clock = 0.045
	else:
		if not is_on_floor():
			velocity.y = minf(velocity.y + GRAVITY * delta, 620.0)
		if _hurt_lock <= 0.0:
			var desired: float = _move_axis * RUN_SPEED * (CROUCH_SPEED if crouching else 1.0)
			if in_shallow_water and is_on_floor():
				desired *= SHALLOW_WATER_SPEED
			if is_on_floor() and attack_phase != "none":
				desired *= 0.32 if attack_phase == "windup" else 0.70
				if _lunge_timer > 0.0 and attack_phase == "active" and _can_ground_lunge(delta):
					desired = facing * LUNGE_SPEED[clampi(combo - 1, 0, 2)]
					# Hold the speed through the whole lunge instead of easing in, so the step reads as a lunge.
					velocity.x = desired
			velocity.x = -facing * PARRY_RECOIL_SPEED if parry_phase == "recoil" else move_toward(velocity.x, desired, (1800.0 if is_on_floor() else 1250.0) * delta)
		if _jump_buffer > 0.0 and _hurt_lock <= 0.0:
			if _coyote > 0.0:
				_jump(false)
			elif INFINITE_AIR_JUMPS or _air_jumps > 0:
				_air_jumps = maxi(0, _air_jumps - 1)
				_jump(true)
		if _jump_cut_requested and velocity.y < -120.0:
			velocity.y *= 0.48
		_jump_cut_requested = false
	_lunge_timer = maxf(0.0, _lunge_timer - delta)
	var was_grounded: bool = is_on_floor()
	var fall_speed: float = velocity.y
	if not used_climb:
		move_and_slide()
	if not was_grounded and is_on_floor():
		_fx("land", global_position, Vector2.ZERO, 0.4)
		if fall_speed > LAND_MIN_SPEED and attack_phase == "none" and dash_timer <= 0.0:
			_land_timer = LAND_TIME
			_air_flip = 0.0
	_update_wings(delta)
	_advance_parry(delta)
	if attack_phase != "none":
		_advance_attack(delta)
	_refresh_animation(delta)

func _traversal_level() -> Node:
	if not is_instance_valid(game):
		return null
	var value: Variant = game.get("level")
	return value if value is Node and is_instance_valid(value) else null

func _query_climb() -> Dictionary:
	var level: Node = _traversal_level()
	if not is_instance_valid(level) or not level.has_method("climb_at"):
		return {}
	var answer: Variant = level.climb_at(global_position)
	if not answer is Dictionary:
		return {}
	var area: Variant = answer.get("rect")
	var kind: Variant = answer.get("kind")
	var identifier: Variant = answer.get("id")
	if not area is Rect2 or not kind is String or not identifier is String:
		return {}
	if area.size.x <= 0.0 or area.size.y <= 0.0 or not area.position.is_finite() or not area.size.is_finite() or kind not in ["ladder", "chain"] or identifier.is_empty():
		return {}
	# The level includes both endpoints. Reject remote/malformed provider data.
	if not area.grow(2.0).has_point(global_position):
		return {}
	return answer

func _update_climb_intent(delta: float, safe: bool) -> void:
	_climb_regrab_cooldown = maxf(0.0, _climb_regrab_cooldown - delta)
	if safe or dead or _hurt_lock > 0.0:
		_leave_climb(true)
		return
	var target: Dictionary = _query_climb()
	if climbing:
		if target.is_empty() or String(target.id) != climb_id:
			_leave_climb(true)
			return
		_climb_rect = target.rect
		if _jump_buffer > 0.0:
			_leave_climb(true)
			# Reuse the existing ground-jump authority and retain an air jump.
			_coyote = COYOTE_TIME
			return
		if queued_attack or _dash_buffer > 0.0 or _parry_buffer > 0.0 or absf(_move_axis) > 0.2:
			_leave_climb(true)
			return
		if (_climb_axis < 0.0 and global_position.y <= _climb_rect.position.y + 0.5) or (_climb_axis > 0.0 and global_position.y >= _climb_rect.end.y - 0.5):
			_leave_climb(true)
		return
	if target.is_empty() or is_zero_approx(_climb_axis) or _climb_release_required or _climb_regrab_cooldown > 0.0:
		return
	if attack_phase != "none" or parry_phase != "none" or parry_timer > 0.0 or dash_timer > 0.0 or queued_attack or _jump_buffer > 0.0 or _dash_buffer > 0.0 or _parry_buffer > 0.0:
		return
	var area: Rect2 = target.rect
	if (_climb_axis < 0.0 and global_position.y <= area.position.y + 0.5) or (_climb_axis > 0.0 and global_position.y >= area.end.y - 0.5):
		return
	climbing = true
	crouching = false
	_crouch_out = 0.0
	_land_timer = 0.0
	_air_flip = 0.0
	climb_kind = target.kind
	climb_id = target.id
	_climb_rect = area
	_climb_moving = false
	_climb_distance = 0.0
	velocity = Vector2.ZERO
	_coyote = 0.0
	_air_jumps = 1

func _move_climb(delta: float) -> void:
	# Releasing jump while gripping is not a request to shorten the next detached jump.
	_jump_cut_requested = false
	var before: Vector2 = global_position
	var center_x: float = _climb_rect.get_center().x
	velocity.x = clampf((center_x - global_position.x) * 10.0, -CLIMB_ALIGN_SPEED, CLIMB_ALIGN_SPEED)
	velocity.y = _climb_axis * CLIMB_SPEED
	var step: float = maxf(delta, 0.000001)
	if velocity.y < 0.0:
		velocity.y = maxf(velocity.y, (_climb_rect.position.y - global_position.y) / step)
	elif velocity.y > 0.0:
		velocity.y = minf(velocity.y, (_climb_rect.end.y - global_position.y) / step)
	move_and_slide()
	var moved: float = absf(global_position.y - before.y)
	_climb_distance += moved
	_climb_moving = moved > 0.02
	if _climb_axis < 0.0 and is_on_ceiling() and moved < 0.02:
		_leave_climb(true)

func _leave_climb(require_release: bool = true) -> void:
	if not climbing:
		return
	climbing = false
	climb_kind = ""
	climb_id = ""
	_climb_rect = Rect2()
	_climb_moving = false
	velocity.y = 0.0
	_climb_release_required = require_release and not is_zero_approx(_climb_axis)
	_climb_regrab_cooldown = 0.12 if require_release else 0.0

func get_climb_progress() -> float:
	if not climbing or _climb_rect.size.y <= 0.0:
		return 0.0
	return clampf(1.0 - (global_position.y - _climb_rect.position.y) / _climb_rect.size.y, 0.0, 1.0)

func reset_traversal(require_release: bool = false) -> void:
	_leave_climb(require_release)
	climbing = false
	climb_kind = ""
	climb_id = ""
	_climb_rect = Rect2()
	_climb_distance = 0.0
	_climb_moving = false
	in_shallow_water = false
	_water_splash_cooldown = 0.0
	_climb_release_required = require_release and not is_zero_approx(_climb_axis)
	_climb_regrab_cooldown = 0.12 if require_release else 0.0
	if not require_release:
		_climb_axis = 0.0

func _update_water(delta: float) -> void:
	var level: Node = _traversal_level()
	var wet: bool = false
	if is_instance_valid(level) and level.has_method("water_at"):
		var answer: Variant = level.water_at(global_position)
		wet = answer is bool and answer
	_water_splash_cooldown = maxf(0.0, _water_splash_cooldown - delta)
	if wet and not in_shallow_water:
		_fx("water_splash", global_position, Vector2(velocity.x, -absf(velocity.y)).normalized(), 0.65)
		_water_splash_cooldown = WATER_SPLASH_INTERVAL
	elif wet and is_on_floor() and absf(velocity.x) > 35.0 and _water_splash_cooldown <= 0.0:
		_fx("water_splash", global_position, Vector2(signf(velocity.x), -0.2), 0.35)
		_water_splash_cooldown = WATER_SPLASH_INTERVAL
	in_shallow_water = wet

func set_impact_freeze(seconds: float) -> void:
	if is_instance_valid(game) and bool(game.story_safe):
		combat_freeze = 0.0
		return
	combat_freeze = maxf(combat_freeze, clampf(seconds, 0.0, 0.12))

func confirm_attack_hit() -> void:
	if attack_phase == "active" or attack_phase == "recover":
		_hit_confirmed = true

func can_cancel_attack() -> bool:
	if attack_phase == "none":
		return true
	if attack_phase == "active":
		return _hit_confirmed and _phase_elapsed >= CONFIRM_CANCEL_DELAY
	if attack_phase == "recover":
		return _hit_confirmed or _phase_elapsed >= RECOVER_CANCEL_DELAY
	return false

func _start_dash(move_axis: float, requested_direction: Vector2 = Vector2.ZERO) -> bool:
	var direction: Vector2 = requested_direction if requested_direction.is_finite() else Vector2.ZERO
	if direction.is_zero_approx():
		direction = Vector2(signf(move_axis) if not is_zero_approx(move_axis) else float(facing), 0.0)
	# Only four cardinal evasions: no diagonal speed gain or position teleport.
	var cardinal: Vector2 = Vector2(signf(direction.x), 0.0) if absf(direction.x) >= absf(direction.y) else Vector2(0.0, signf(direction.y))
	if dead or _parry_paused() or dash_timer > 0.0 or float(_dash_cooldowns.get(cardinal, 0.0)) > 0.0 or _hurt_lock > 0.0 or combat_freeze > 0.0 or parry_phase == "recoil" or not can_cancel_attack() or (is_instance_valid(game) and bool(game.story_safe)):
		return false
	if move_axis != 0.0:
		facing = 1 if move_axis > 0.0 else -1
	_leave_climb(true)
	_cancel_attack()
	_clear_parry()
	dash_direction = cardinal
	if not is_zero_approx(dash_direction.x):
		facing = 1 if dash_direction.x > 0.0 else -1
	_dash_intent = Vector2.ZERO
	dash_timer = DASH_DURATION
	_dash_cooldowns[cardinal] = DASH_COOLDOWN
	invuln = maxf(invuln, DASH_INVULNERABILITY)
	parry_timer = 0.0
	_trail_clock = 0.0
	_fx("dash_start", global_position + Vector2(0.0, -13.0), dash_direction, 0.5)
	return true

func _update_wings(delta: float) -> void:
	if is_on_floor() or climbing:
		_wings_out = false
	if _wings_out:
		wing_amount = minf(1.0, wing_amount + delta * WING_OPEN_RATE)
	else:
		wing_amount = maxf(0.0, wing_amount - delta / WING_FOLD_TIME)
	wing_flap = maxf(0.0, wing_flap - delta * 2.2)

func _jump(airborne: bool) -> void:
	_leave_climb(true)
	if airborne:
		_wings_out = true
		wing_flap = 1.0
	velocity.y = JUMP_SPEED * (0.92 if airborne else 1.0)
	_jump_buffer = 0.0
	_coyote = 0.0
	_crouch_out = 0.0
	_land_timer = 0.0
	_air_flip = AIR_FLIP_TIME if airborne else 0.0
	_fx("air_jump" if airborne else "jump", global_position, Vector2.UP, 0.6)

func _start_attack() -> void:
	if dead or (is_instance_valid(game) and bool(game.story_safe)):
		return
	if attack_phase != "none" or combat_freeze > 0.0:
		queued_attack = true
		return
	if _hurt_lock > 0.0 or dash_timer > 0.0 or _parry_blocks_attack():
		return
	_leave_climb(true)
	_clear_parry()
	if _move_axis != 0.0:
		facing = 1 if _move_axis > 0.0 else -1
	combo = combo % 3 + 1 if _combo_grace > 0.0 else 1
	attack_serial += 1
	_attack_elapsed = 0.0
	attack_timer = COMBO_LENGTHS[combo - 1]
	attack_sweep_from = AttackProfile.contact_start()
	attack_sweep_to = attack_sweep_from
	_attack_query_progress = attack_sweep_from
	queued_attack = false
	_combo_grace = 0.0
	_hit_confirmed = false
	_strike_done = false
	_enter_attack_phase("windup")

func get_attack_progress() -> float:
	if attack_phase == "none":
		return 0.0
	return clampf(_phase_elapsed / maxf(0.001, _phase_duration()), 0.0, 1.0)

func _phase_duration() -> float:
	var slot: int = clampi(combo - 1, 0, 2)
	match attack_phase:
		"windup": return COMBO_WINDUP[slot]
		"active": return COMBO_ACTIVE[slot]
		"recover": return COMBO_RECOVER[slot]
	return 0.0

func _enter_attack_phase(stage: String) -> void:
	attack_phase = stage
	_phase_elapsed = 0.0
	_state_clock = 0.0
	if stage == "active":
		_lunge_timer = LUNGE_TIME
		_fx("lunge", global_position + Vector2(0.0, -2.0), Vector2(facing, 0.0), float(combo))
		_fx("slash", global_position + Vector2(facing * 22.0, -18.0), Vector2(facing, 0.0), float(combo))
	_set_animation("attack" if stage == "active" else stage, 0.0)

func _can_ground_lunge(delta: float) -> bool:
	if not is_inside_tree() or not is_on_floor():
		return false
	var state: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	var speed: float = float(AttackProfile.profile(combo).get("lunge_speed", 126.0))
	var ahead: float = maxf(26.0, speed * delta + 10.0)
	var wall: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(global_position + Vector2(0.0, -12.0), global_position + Vector2(facing * ahead, -12.0), 1)
	if not state.intersect_ray(wall).is_empty():
		return false
	var ground: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(global_position + Vector2(facing * ahead, -4.0), global_position + Vector2(facing * ahead, 24.0), 1)
	return not state.intersect_ray(ground).is_empty()

func _query_active_sweep(progress: float) -> bool:
	attack_sweep_from = _attack_query_progress
	attack_sweep_to = clampf(progress, AttackProfile.contact_start(), 1.0)
	_attack_query_progress = attack_sweep_to
	_strike_done = true
	_set_animation("attack", 0.0)
	if is_instance_valid(game) and not bool(game.story_safe):
		game.hero_attack(self, 2 if combo == 3 else 1, AttackProfile.radii(combo).x, combo)
	return combat_freeze > 0.0 or attack_phase == "none"

func _advance_attack(delta: float) -> void:
	var remaining: float = maxf(0.0, delta)
	while remaining > 0.000001 and attack_phase != "none":
		var duration: float = _phase_duration()
		if duration <= 0.0:
			_cancel_attack()
			return
		var contact_begin: float = duration * AttackProfile.contact_start()
		var consumed: float = minf(remaining, maxf(0.0, duration - _phase_elapsed))
		if attack_phase == "active" and not _strike_done and _phase_elapsed < contact_begin:
			consumed = minf(consumed, contact_begin - _phase_elapsed)
		_phase_elapsed += consumed
		_attack_elapsed += consumed
		attack_timer = maxf(0.0, AttackProfile.total_duration(combo) - _attack_elapsed)
		remaining -= consumed
		if attack_phase == "active" and _phase_elapsed >= contact_begin - 0.000001:
			var progress: float = clampf(_phase_elapsed / duration, AttackProfile.contact_start(), 1.0)
			if not _strike_done or progress > _attack_query_progress + 0.000001:
				# First clash is exactly the forward pose. Later queries cover the
				# entire physics interval, including its final active edge.
				if _query_active_sweep(progress):
					return
		if _phase_elapsed >= duration - 0.000001:
			match attack_phase:
				"windup": _enter_attack_phase("active")
				"active": _enter_attack_phase("recover")
				"recover":
					attack_phase = "none"
					attack_timer = 0.0
					_combo_grace = 0.22
					_lunge_timer = 0.0

func _cancel_attack() -> void:
	attack_phase = "none"
	attack_timer = 0.0
	queued_attack = false
	combo = 0
	_combo_grace = 0.0
	_attack_elapsed = 0.0
	_phase_elapsed = 0.0
	_lunge_timer = 0.0
	_hit_confirmed = false
	_strike_done = true
	attack_sweep_from = AttackProfile.contact_start()
	attack_sweep_to = attack_sweep_from
	_attack_query_progress = attack_sweep_from

func receive_hit(amount: int, origin: Vector2) -> bool:
	if dead or invuln > 0.0 or amount <= 0 or (is_instance_valid(game) and bool(game.story_safe)):
		return false
	reset_direction_taps()
	reset_traversal(true)
	health = maxi(0, health - amount)
	impact_flash = 0.11
	invuln = 0.80
	_hurt_lock = 0.18
	_clear_parry()
	_cancel_attack()
	parry_timer = 0.0
	dash_timer = 0.0
	_dash_buffer = 0.0
	_parry_buffer = 0.0
	var away: float = 1.0 if global_position.x >= origin.x else -1.0
	# Heavier blows throw the hero further and higher; a single point of damage keeps the original shove.
	var weight: float = clampf(float(amount) - 1.0, 0.0, 2.0)
	velocity = Vector2(away * (180.0 + 45.0 * weight), -115.0 - 40.0 * weight)
	_fx("hurt", global_position + Vector2(0.0, -16.0), Vector2(away, -0.3), 1.0)
	health_changed.emit(health, max_health)
	if health <= 0:
		dead = true
		died.emit()
	_refresh_animation(0.0)
	return true

func _parry_paused() -> bool:
	if is_inside_tree() and get_tree().paused:
		return true
	return is_instance_valid(game) and game.get("_paused") == true

func _start_parry() -> bool:
	if dead or _parry_paused() or not is_instance_valid(game) or bool(game.story_safe) or _parry_cooldown > 0.0 or dash_timer > 0.0 or _hurt_lock > 0.0 or parry_phase == "recoil" or not can_cancel_attack():
		return false
	_leave_climb(true)
	_cancel_attack()
	_clear_parry()
	if _move_axis != 0.0:
		facing = 1 if _move_axis > 0.0 else -1
	parry_timer = PARRY_WINDOW
	parry_phase = "ready"
	_parry_cooldown = 0.38
	_set_animation("parry", 0.0)
	_fx("parry_ready", global_position + Vector2(facing * 14.0, -17.0), Vector2(facing, 0.0), 0.35)
	return true

func parry_success(target: Node = null, contact: Vector2 = Vector2.INF, kind: String = "melee", token: int = -1) -> bool:
	if dead or (is_instance_valid(game) and bool(game.story_safe)):
		_clear_parry()
		return false
	if not is_instance_valid(game) or _parry_paused() or parry_timer <= 0.0:
		return false
	if kind not in ["melee", "projectile", "guard_break"]:
		return false
	# Default contact/token are a compatibility path for minimal old mocks.
	# Every actual enemy/Boss/projectile supplies its real contact and serial.
	var legacy: bool = contact == Vector2.INF and token < 0 and not game.has_method("on_parry_contact")
	if game.has_method("on_parry_contact") and token < 0:
		return false
	if legacy:
		contact = global_position + Vector2(facing * 18.0, -16.0)
	if not contact.is_finite():
		return false
	var relative: Vector2 = contact - (global_position + Vector2(0.0, -16.0))
	if relative.x * facing < 0.0 or absf(relative.x) > 64.0 or absf(relative.y) > 42.0:
		return false
	if kind != "projectile" and target is Node2D and (target.global_position.x - global_position.x) * facing < 0.0:
		return false
	if token >= 0:
		if not is_instance_valid(target):
			return false
		var key: String = "%d:%d" % [target.get_instance_id(), token]
		if _parry_seen.has(key):
			return false
		_parry_seen[key] = true
	var counter_intent: bool = queued_attack
	_cancel_attack()
	queued_attack = counter_intent
	dash_timer = 0.0
	parry_phase = "recoil"
	_parry_elapsed = 0.0
	velocity.x = -facing * PARRY_RECOIL_SPEED
	invuln = maxf(invuln, 0.18)
	_dash_cooldown = 0.0
	_set_animation("parry_recoil", 0.0)
	# Never extend the original real-time contact window on a successful clash.
	parried.emit()
	if game.has_method("on_parry_contact"):
		game.on_parry_contact(self, target, contact, kind)
	else:
		_fx("parry", contact, Vector2(facing, 0.0), 1.4)
		if game.has_method("request_impact"):
			game.request_impact(self, target, false, true)
	return true

func get_parry_progress() -> float:
	match parry_phase:
		"ready": return clampf(1.0 - parry_timer / PARRY_WINDOW, 0.0, 1.0)
		"recoil": return clampf(_parry_elapsed / PARRY_RECOIL, 0.0, 1.0)
		"recover": return clampf(_parry_elapsed / PARRY_RECOVER, 0.0, 1.0)
	return 0.0

func _parry_blocks_attack() -> bool:
	if parry_phase == "recoil":
		return true
	if parry_phase == "recover":
		return _parry_elapsed < PARRY_COUNTER_DELAY
	return parry_timer > 0.0 or parry_phase == "ready"

func _advance_parry(delta: float) -> void:
	var remaining: float = maxf(0.0, delta)
	while remaining > 0.000001 and parry_phase in ["recoil", "recover"]:
		var duration: float = PARRY_RECOIL if parry_phase == "recoil" else PARRY_RECOVER
		var step: float = minf(remaining, maxf(0.0, duration - _parry_elapsed))
		_parry_elapsed += step
		remaining -= step
		if _parry_elapsed >= duration - 0.000001:
			if parry_phase == "recoil":
				parry_phase = "recover"
				_parry_elapsed = 0.0
				_set_animation("parry_recover", 0.0)
			else:
				_clear_parry()

func _clear_parry() -> void:
	parry_timer = 0.0
	parry_phase = "none"
	_parry_elapsed = 0.0
	_parry_buffer = 0.0
	_parry_seen.clear()

func revive(at: Vector2) -> void:
	reset_direction_taps()
	dash_direction = Vector2.RIGHT
	reset_traversal()
	global_position = at
	velocity = Vector2.ZERO
	health = max_health
	dead = false
	invuln = 1.0
	combat_freeze = 0.0
	impact_flash = 0.0
	_clear_parry()
	_cancel_attack()
	parry_timer = 0.0
	dash_timer = 0.0
	_jump_buffer = 0.0
	_jump_cut_requested = false
	_hurt_lock = 0.0
	_dash_cooldown = 0.0
	_dash_buffer = 0.0
	_parry_cooldown = 0.0
	_parry_buffer = 0.0
	_air_jumps = 1
	_coyote = 0.0
	_move_axis = 0.0
	_wings_out = false
	wing_amount = 0.0
	wing_flap = 0.0
	crouching = false
	_crouch_held = false
	_crouch_out = 0.0
	_land_timer = 0.0
	_air_flip = 0.0
	_set_animation("idle", 0.0)
	health_changed.emit(health, max_health)

func _refresh_animation(delta: float) -> void:
	if dead:
		_set_animation("dead", delta)
	elif _hurt_lock > 0.0:
		_set_animation("hurt", delta)
	elif dash_timer > 0.0:
		_set_animation("dash", delta)
	elif parry_phase == "recoil":
		_set_animation("parry_recoil", delta)
	elif parry_phase == "recover":
		_set_animation("parry_recover", delta)
	elif parry_timer > 0.0:
		_set_animation("parry", delta)
	elif attack_phase != "none":
		_set_animation("attack" if attack_phase == "active" else attack_phase, delta)
	elif climbing:
		_set_animation("climb" if _climb_moving else "climb_idle", delta)
	elif not is_on_floor():
		_set_animation(_air_state(), delta)
	elif _land_timer > 0.0:
		_set_animation("land", delta)
	elif crouching:
		if absf(velocity.x) > 8.0:
			_set_animation("crouch_walk", delta)
		elif animation_state == "crouch_in" and _state_clock < CROUCH_BLEND:
			_set_animation("crouch_in", delta)
		elif animation_state in ["crouch_in", "crouch_walk", "crouch"]:
			_set_animation("crouch", delta)
		else:
			_set_animation("crouch_in", delta)
	elif _crouch_out > 0.0:
		_set_animation("crouch_out", delta)
	elif absf(velocity.x) > 8.0:
		_set_animation("run", delta)
	else:
		_set_animation("idle", delta)

func _set_animation(state: String, delta: float) -> void:
	if animation_state != state:
		animation_state = state
		_state_clock = 0.0
	else:
		_state_clock += delta
	if state in ["windup", "attack", "recover"] and attack_phase != "none":
		frame = clampi(int(4.0 * get_attack_progress() + 0.000001), 0, 3)
	elif state in ["parry", "parry_recoil", "parry_recover"] and parry_phase != "none":
		frame = clampi(int(4.0 * get_parry_progress() + 0.000001), 0, 3)
	elif state in ["climb", "climb_idle"]:
		frame = int(_climb_distance / 6.0) % 4
	elif state == "run":
		frame = int(_state_clock * RUN_FRAME_RATE) % 8
	elif state == "idle":
		frame = int(_state_clock * 6.0) % 6
	elif state == "jump":
		frame = clampi(int((1.0 - (-velocity.y) / absf(JUMP_SPEED)) * 3.0), 0, 2)
	elif state == "apex":
		frame = int(_state_clock * 9.0) % 2
	elif state == "fall":
		frame = clampi(int(velocity.y / 170.0), 0, 2)
	elif state == "land":
		frame = clampi(int((1.0 - _land_timer / LAND_TIME) * 3.0), 0, 2)
	elif state == "air_jump":
		frame = clampi(int((1.0 - _air_flip / AIR_FLIP_TIME) * 6.0), 0, 5)
	elif state == "crouch_in":
		frame = clampi(int(_state_clock / CROUCH_BLEND * 3.0), 0, 2)
	elif state == "crouch_out":
		frame = clampi(int((1.0 - _crouch_out / CROUCH_BLEND) * 3.0), 0, 2)
	elif state == "crouch":
		frame = int(_state_clock * 5.0) % 4
	elif state == "crouch_walk":
		frame = int(_state_clock * 11.0) % 6
	elif state == "dead" or state == "hurt":
		frame = mini(3, int(_state_clock * 10.0))
	else:
		frame = int(_state_clock * 12.0) % 4
	if frame != _last_frame or state != _last_state or facing != _last_facing:
		_last_frame = frame
		_last_state = state
		_last_facing = facing
		state_changed.emit(state, frame, facing)
		if is_instance_valid(game) and game.has_signal("animation_event"):
			game.emit_signal("animation_event", self, state, frame, facing)
	queue_redraw()

func _air_state() -> String:
	if _air_flip > 0.0:
		return "air_jump"
	if velocity.y < -AIR_APEX_SPEED:
		return "jump"
	if velocity.y > AIR_APEX_SPEED:
		return "fall"
	return "apex"

func _update_crouch(_delta: float) -> void:
	var want: bool = _crouch_held and not climbing and is_on_floor() and attack_phase == "none" and dash_timer <= 0.0 and parry_phase == "none" and parry_timer <= 0.0 and _hurt_lock <= 0.0 and not dead and not (is_instance_valid(game) and bool(game.story_safe))
	if crouching and not want:
		_crouch_out = CROUCH_BLEND
	elif want and not crouching:
		_crouch_out = 0.0
	crouching = want

func _fx(kind: String, at: Vector2, direction: Vector2, power: float) -> void:
	if is_instance_valid(game):
		game.emit_fx(kind, at, direction, power)

func _draw() -> void:
	if invuln > 0.2 and int(invuln * 24.0) % 2 == 0:
		return
	PixelActor.paint(self, "hero", animation_state, frame, facing)

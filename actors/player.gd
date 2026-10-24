extends CharacterBody2D
## Combat stages and local impact freeze run independently of the music clock.

signal health_changed(current: int, maximum: int)
signal died
signal state_changed(state: String, frame: int, direction: int)
signal parried

const PixelActor = preload("res://assets/art/pixel_actor.gd")
const RUN_SPEED: float = 180.0
const JUMP_SPEED: float = -340.0
const GRAVITY: float = 900.0
const DASH_SPEED: float = 420.0
const COYOTE_TIME: float = 0.10
const JUMP_BUFFER: float = 0.12
const PARRY_WINDOW: float = 0.16
const ATTACK_STARTUP: float = 0.065
const COMBO_WINDUP: Array[float] = [0.065, 0.080, 0.110]
const COMBO_ACTIVE: Array[float] = [0.105, 0.120, 0.150]
const COMBO_RECOVER: Array[float] = [0.140, 0.160, 0.230]
const COMBO_LENGTHS: Array[float] = [0.310, 0.360, 0.490]
const RECOVER_CANCEL_DELAY: float = 0.055
const CONFIRM_CANCEL_DELAY: float = 0.050

var game: Node
var facing: int = 1
var health: int = 8
var max_health: int = 8
var invuln: float = 0.0
var parry_timer: float = 0.0
var dash_timer: float = 0.0
var attack_timer: float = 0.0
var attack_phase: String = "none"
var attack_serial: int = 0
var queued_attack: bool = false
var combat_freeze: float = 0.0
var impact_flash: float = 0.0
var animation_state: String = "idle"
var frame: int = 0
var combo: int = 0
var dead: bool = false
var _coyote: float = 0.0
var _jump_buffer: float = 0.0
var _jump_cut_requested: bool = false
var _air_jumps: int = 1
var _dash_cooldown: float = 0.0
var _dash_buffer: float = 0.0
var _parry_cooldown: float = 0.0
var _parry_buffer: float = 0.0
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
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	health_changed.emit(health, max_health)

func _capture_input() -> void:
	# Capture every edge BEFORE a hit-stop early return. One combo intent survives
	# any windup/active/recovery length and cannot stack into an unattended chain.
	_move_axis = Input.get_axis("move_left", "move_right")
	if Input.is_action_just_pressed("attack"):
		queued_attack = true
	if Input.is_action_just_pressed("jump"):
		_jump_buffer = JUMP_BUFFER
	if Input.is_action_just_released("jump"):
		_jump_cut_requested = true
	if Input.is_action_just_pressed("dash"):
		_dash_buffer = 0.16
	if Input.is_action_just_pressed("parry"):
		_parry_buffer = 0.12

func _physics_process(delta: float) -> void:
	_capture_input()
	impact_flash = maxf(0.0, impact_flash - delta)
	# Defensive windows and cooldowns use real physics delta, even in local freeze.
	invuln = maxf(0.0, invuln - delta)
	parry_timer = maxf(0.0, parry_timer - delta)
	_dash_cooldown = maxf(0.0, _dash_cooldown - delta)
	_parry_cooldown = maxf(0.0, _parry_cooldown - delta)
	var safe: bool = is_instance_valid(game) and bool(game.story_safe)
	if safe:
		_cancel_attack()
		combat_freeze = 0.0
		parry_timer = 0.0
		dash_timer = 0.0
		_dash_buffer = 0.0
		_parry_buffer = 0.0
		_hurt_lock = 0.0
	if dead:
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
	_combo_grace = maxf(0.0, _combo_grace - delta)
	_jump_buffer = maxf(0.0, _jump_buffer - delta)
	_dash_buffer = maxf(0.0, _dash_buffer - delta)
	_parry_buffer = maxf(0.0, _parry_buffer - delta)
	if _move_axis != 0.0 and dash_timer <= 0.0 and attack_phase == "none":
		facing = 1 if _move_axis > 0.0 else -1
	if is_on_floor():
		_coyote = COYOTE_TIME
		_air_jumps = 1
	else:
		_coyote = maxf(0.0, _coyote - delta)
	if _dash_buffer > 0.0 and _start_dash(_move_axis):
		_dash_buffer = 0.0
	elif not safe and _parry_buffer > 0.0 and _parry_cooldown <= 0.0 and dash_timer <= 0.0 and _hurt_lock <= 0.0 and can_cancel_attack():
		_cancel_attack()
		parry_timer = PARRY_WINDOW
		_parry_cooldown = 0.38
		_parry_buffer = 0.0
		_fx("parry_ready", global_position + Vector2(facing * 14.0, -17.0), Vector2(facing, 0.0), 0.35)
	if queued_attack and attack_phase == "none" and dash_timer <= 0.0 and parry_timer <= 0.0 and _hurt_lock <= 0.0 and not safe:
		_start_attack()
	if dash_timer > 0.0:
		dash_timer = maxf(0.0, dash_timer - delta)
		velocity = Vector2(facing * DASH_SPEED, 0.0)
		_trail_clock -= delta
		if _trail_clock <= 0.0:
			_fx("dash_ghost", global_position + Vector2(0.0, -13.0), Vector2(-facing, 0.0), 0.55)
			_trail_clock = 0.045
	else:
		if not is_on_floor():
			velocity.y = minf(velocity.y + GRAVITY * delta, 620.0)
		if _hurt_lock <= 0.0:
			var desired: float = _move_axis * RUN_SPEED
			if is_on_floor() and attack_phase != "none":
				desired *= 0.32 if attack_phase == "windup" else 0.70
				if _lunge_timer > 0.0 and attack_phase == "active":
					desired = facing * (150.0 if combo == 3 else (108.0 if combo == 2 else 88.0))
			velocity.x = move_toward(velocity.x, desired, (1800.0 if is_on_floor() else 1250.0) * delta)
		if _jump_buffer > 0.0 and _hurt_lock <= 0.0:
			if _coyote > 0.0:
				_jump(false)
			elif _air_jumps > 0:
				_air_jumps -= 1
				_jump(true)
		if _jump_cut_requested and velocity.y < -120.0:
			velocity.y *= 0.48
		_jump_cut_requested = false
	_lunge_timer = maxf(0.0, _lunge_timer - delta)
	var was_grounded: bool = is_on_floor()
	move_and_slide()
	if not was_grounded and is_on_floor():
		_fx("land", global_position, Vector2.ZERO, 0.4)
	if attack_phase != "none":
		_advance_attack(delta)
	_refresh_animation(delta)

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

func _start_dash(move_axis: float) -> bool:
	if dead or _dash_cooldown > 0.0 or _hurt_lock > 0.0 or combat_freeze > 0.0 or not can_cancel_attack() or (is_instance_valid(game) and bool(game.story_safe)):
		return false
	if move_axis != 0.0:
		facing = 1 if move_axis > 0.0 else -1
	_cancel_attack()
	dash_timer = 0.16
	_dash_cooldown = 0.48
	invuln = maxf(invuln, 0.15)
	parry_timer = 0.0
	_trail_clock = 0.0
	_fx("dash_start", global_position + Vector2(0.0, -13.0), Vector2(facing, 0.0), 0.5)
	return true

func _jump(airborne: bool) -> void:
	velocity.y = JUMP_SPEED * (0.92 if airborne else 1.0)
	_jump_buffer = 0.0
	_coyote = 0.0
	_fx("air_jump" if airborne else "jump", global_position, Vector2.UP, 0.6)

func _start_attack() -> void:
	if dead or (is_instance_valid(game) and bool(game.story_safe)):
		return
	if attack_phase != "none" or combat_freeze > 0.0:
		queued_attack = true
		return
	if _hurt_lock > 0.0 or dash_timer > 0.0 or parry_timer > 0.0:
		return
	if _move_axis != 0.0:
		facing = 1 if _move_axis > 0.0 else -1
	combo = combo % 3 + 1 if _combo_grace > 0.0 else 1
	attack_serial += 1
	_attack_elapsed = 0.0
	attack_timer = COMBO_LENGTHS[combo - 1]
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
		_lunge_timer = 0.065
		_fx("slash", global_position + Vector2(facing * 22.0, -18.0), Vector2(facing, 0.0), float(combo))
	_set_animation("attack" if stage == "active" else stage, 0.0)

func _advance_attack(delta: float) -> void:
	var remaining: float = maxf(0.0, delta)
	var pulsed: bool = false
	while remaining > 0.000001 and attack_phase != "none":
		var duration: float = _phase_duration()
		if duration <= 0.0:
			_cancel_attack()
			return
		var contact_start: float = duration * 0.25
		# Active pose 0 still carries the raised blade. First contact is pose 1,
		# then the rest of this active phase continues querying every physics tick.
		if attack_phase == "active" and not pulsed and _phase_elapsed >= contact_start - 0.000001:
			pulsed = true
			_strike_done = true
			_set_animation("attack", 0.0)
			if is_instance_valid(game) and not bool(game.story_safe):
				game.hero_attack(self, 2 if combo == 3 else 1, 55.0 if combo == 3 else (47.0 if combo == 2 else 42.0), combo)
			# Impact holds this pose immediately; music/projectiles are untouched.
			if combat_freeze > 0.0 or attack_phase == "none":
				return
		var consumed: float = minf(remaining, maxf(0.0, duration - _phase_elapsed))
		if attack_phase == "active" and not pulsed and _phase_elapsed < contact_start:
			consumed = minf(consumed, contact_start - _phase_elapsed)
		_phase_elapsed += consumed
		_attack_elapsed += consumed
		attack_timer = maxf(0.0, COMBO_LENGTHS[clampi(combo - 1, 0, 2)] - _attack_elapsed)
		remaining -= consumed
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

func receive_hit(amount: int, origin: Vector2) -> bool:
	if dead or invuln > 0.0 or amount <= 0 or (is_instance_valid(game) and bool(game.story_safe)):
		return false
	health = maxi(0, health - amount)
	impact_flash = 0.11
	invuln = 0.80
	_hurt_lock = 0.18
	_cancel_attack()
	parry_timer = 0.0
	dash_timer = 0.0
	_dash_buffer = 0.0
	_parry_buffer = 0.0
	var away: float = 1.0 if global_position.x >= origin.x else -1.0
	velocity = Vector2(away * 180.0, -115.0)
	_fx("hurt", global_position + Vector2(0.0, -16.0), Vector2(away, -0.3), 1.0)
	health_changed.emit(health, max_health)
	if health <= 0:
		dead = true
		died.emit()
	_refresh_animation(0.0)
	return true

func parry_success(target: Node = null) -> void:
	if dead or (is_instance_valid(game) and bool(game.story_safe)):
		return
	invuln = maxf(invuln, 0.18)
	_dash_cooldown = 0.0
	# The success reward never extends the real 0.16s contact window.
	_fx("parry", global_position + Vector2(facing * 14.0, -16.0), Vector2(facing, 0.0), 1.4)
	parried.emit()
	if is_instance_valid(game) and game.has_method("request_impact"):
		game.request_impact(self, target, false, true)

func revive(at: Vector2) -> void:
	global_position = at
	velocity = Vector2.ZERO
	health = max_health
	dead = false
	invuln = 1.0
	combat_freeze = 0.0
	impact_flash = 0.0
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
	_set_animation("idle", 0.0)
	health_changed.emit(health, max_health)

func _refresh_animation(delta: float) -> void:
	if dead:
		_set_animation("dead", delta)
	elif _hurt_lock > 0.0:
		_set_animation("hurt", delta)
	elif dash_timer > 0.0:
		_set_animation("dash", delta)
	elif parry_timer > 0.0:
		_set_animation("parry", delta)
	elif attack_phase != "none":
		_set_animation("attack" if attack_phase == "active" else attack_phase, delta)
	elif not is_on_floor():
		_set_animation("jump" if velocity.y < 0.0 else "fall", delta)
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
	elif state == "run":
		frame = int(_state_clock * 12.0) % 6
	elif state == "idle":
		frame = int(_state_clock * 5.0) % 4
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

func _fx(kind: String, at: Vector2, direction: Vector2, power: float) -> void:
	if is_instance_valid(game):
		game.emit_fx(kind, at, direction, power)

func _draw() -> void:
	if invuln > 0.2 and int(invuln * 24.0) % 2 == 0:
		return
	PixelActor.paint(self, "hero", animation_state, frame, facing)

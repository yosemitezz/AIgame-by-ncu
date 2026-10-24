extends CharacterBody2D
## Physics and combat own their timing; presentation only reads state/frame signals.

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
const COMBO_LENGTHS: Array[float] = [0.27, 0.29, 0.37]

var game: Node
var facing: int = 1
var health: int = 8
var max_health: int = 8
var invuln: float = 0.0
var parry_timer: float = 0.0
var dash_timer: float = 0.0
var attack_timer: float = 0.0
var animation_state: String = "idle"
var frame: int = 0
var combo: int = 0
var dead: bool = false
var _coyote: float = 0.0
var _jump_buffer: float = 0.0
var _air_jumps: int = 1
var _dash_cooldown: float = 0.0
var _parry_cooldown: float = 0.0
var _attack_buffer: float = 0.0
var _combo_grace: float = 0.0
var _attack_elapsed: float = 0.0
var _strike_done: bool = false
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

func _physics_process(delta: float) -> void:
	invuln = maxf(0.0, invuln - delta)
	_dash_cooldown = maxf(0.0, _dash_cooldown - delta)
	_parry_cooldown = maxf(0.0, _parry_cooldown - delta)
	parry_timer = maxf(0.0, parry_timer - delta)
	_hurt_lock = maxf(0.0, _hurt_lock - delta)
	_combo_grace = maxf(0.0, _combo_grace - delta)
	_jump_buffer = maxf(0.0, _jump_buffer - delta)
	_attack_buffer = maxf(0.0, _attack_buffer - delta)
	if dead:
		velocity = Vector2.ZERO
		_set_animation("dead", delta)
		return
	if Input.is_action_just_pressed("jump"):
		_jump_buffer = JUMP_BUFFER
	var move_axis: float = Input.get_axis("move_left", "move_right")
	if move_axis != 0.0 and dash_timer <= 0.0 and attack_timer <= 0.0:
		facing = 1 if move_axis > 0.0 else -1
	if is_on_floor():
		_coyote = COYOTE_TIME
		_air_jumps = 1
	else:
		_coyote = maxf(0.0, _coyote - delta)
	var safe: bool = is_instance_valid(game) and bool(game.story_safe)
	if safe:
		attack_timer = 0.0
		parry_timer = 0.0
		_attack_buffer = 0.0
		combo = 0
	elif Input.is_action_just_pressed("attack"):
		_attack_buffer = 0.16
	if Input.is_action_just_pressed("dash") and _dash_cooldown <= 0.0 and _hurt_lock <= 0.0:
		_start_dash(move_axis)
	if not safe and Input.is_action_just_pressed("parry") and _parry_cooldown <= 0.0 and dash_timer <= 0.0 and _hurt_lock <= 0.0:
		parry_timer = PARRY_WINDOW
		_parry_cooldown = 0.38
		attack_timer = 0.0
		_attack_buffer = 0.0
		_fx("parry_ready", global_position + Vector2(facing * 14.0, -17.0), Vector2(facing, 0.0), 0.35)
	if _attack_buffer > 0.0 and attack_timer <= 0.0 and dash_timer <= 0.0 and parry_timer <= 0.0 and _hurt_lock <= 0.0 and not safe:
		_start_attack()
	if dash_timer > 0.0:
		dash_timer = maxf(0.0, dash_timer - delta)
		velocity = Vector2(facing * DASH_SPEED, 0.0)
		_trail_clock -= delta
		if _trail_clock <= 0.0:
			_fx("dash", global_position + Vector2(0.0, -13.0), Vector2(-facing, 0.0), 0.55)
			_trail_clock = 0.045
	else:
		if not is_on_floor():
			velocity.y = minf(velocity.y + GRAVITY * delta, 620.0)
		if _hurt_lock <= 0.0:
			var control: float = 1.0
			if attack_timer > 0.0 and is_on_floor():
				control = 0.58
			velocity.x = move_toward(velocity.x, move_axis * RUN_SPEED * control, (1800.0 if is_on_floor() else 1250.0) * delta)
		if _jump_buffer > 0.0 and _hurt_lock <= 0.0:
			if _coyote > 0.0:
				_jump(false)
			elif _air_jumps > 0:
				_air_jumps -= 1
				_jump(true)
		if Input.is_action_just_released("jump") and velocity.y < -120.0:
			velocity.y *= 0.48
	var was_grounded: bool = is_on_floor()
	move_and_slide()
	if not was_grounded and is_on_floor():
		_fx("land", global_position, Vector2.ZERO, 0.4)
	if attack_timer > 0.0:
		_attack_elapsed += delta
		attack_timer = maxf(0.0, attack_timer - delta)
		if not _strike_done and _attack_elapsed >= ATTACK_STARTUP:
			_strike_done = true
			if is_instance_valid(game) and not bool(game.story_safe):
				game.hero_attack(self, 2 if combo == 3 else 1, 55.0 if combo == 3 else (47.0 if combo == 2 else 42.0), combo)
				_fx("slash", global_position + Vector2(facing * 22.0, -18.0), Vector2(facing, 0.0), float(combo))
		if attack_timer <= 0.0:
			_combo_grace = 0.22
	if _hurt_lock > 0.0:
		_set_animation("hurt", delta)
	elif dash_timer > 0.0:
		_set_animation("dash", delta)
	elif parry_timer > 0.0:
		_set_animation("parry", delta)
	elif attack_timer > 0.0:
		_set_animation("attack", delta)
	elif not is_on_floor():
		_set_animation("jump" if velocity.y < 0.0 else "fall", delta)
	elif absf(velocity.x) > 8.0:
		_set_animation("run", delta)
	else:
		_set_animation("idle", delta)

func _start_dash(move_axis: float) -> void:
	if move_axis != 0.0:
		facing = 1 if move_axis > 0.0 else -1
	dash_timer = 0.16
	_dash_cooldown = 0.48
	invuln = maxf(invuln, 0.15)
	attack_timer = 0.0
	parry_timer = 0.0
	_strike_done = true
	_trail_clock = 0.0

func _jump(airborne: bool) -> void:
	velocity.y = JUMP_SPEED * (0.92 if airborne else 1.0)
	_jump_buffer = 0.0
	_coyote = 0.0
	_fx("air_jump" if airborne else "jump", global_position, Vector2.UP, 0.6)

func _start_attack() -> void:
	combo = combo % 3 + 1 if _combo_grace > 0.0 else 1
	_attack_elapsed = 0.0
	attack_timer = COMBO_LENGTHS[combo - 1]
	_attack_buffer = 0.0
	_combo_grace = 0.0
	_strike_done = false
	_state_clock = 0.0

func receive_hit(amount: int, origin: Vector2) -> bool:
	if dead or invuln > 0.0 or amount <= 0 or (is_instance_valid(game) and bool(game.story_safe)):
		return false
	health = maxi(0, health - amount)
	invuln = 0.80
	_hurt_lock = 0.15
	attack_timer = 0.0
	parry_timer = 0.0
	dash_timer = 0.0
	_attack_buffer = 0.0
	var away: float = 1.0 if global_position.x >= origin.x else -1.0
	velocity = Vector2(away * 170.0, -115.0)
	_fx("hurt", global_position + Vector2(0.0, -16.0), Vector2(away, -0.3), 1.0)
	health_changed.emit(health, max_health)
	if health <= 0:
		dead = true
		died.emit()
	return true

func parry_success() -> void:
	if dead or (is_instance_valid(game) and bool(game.story_safe)):
		return
	invuln = maxf(invuln, 0.18)
	_dash_cooldown = 0.0
	# Success rewards invulnerability without extending the contact window.
	_fx("parry", global_position + Vector2(facing * 14.0, -16.0), Vector2(facing, 0.0), 1.4)
	parried.emit()

func revive(at: Vector2) -> void:
	global_position = at
	velocity = Vector2.ZERO
	health = max_health
	dead = false
	invuln = 1.0
	parry_timer = 0.0
	dash_timer = 0.0
	attack_timer = 0.0
	_attack_buffer = 0.0
	_jump_buffer = 0.0
	_hurt_lock = 0.0
	_dash_cooldown = 0.0
	_parry_cooldown = 0.0
	_combo_grace = 0.0
	combo = 0
	_air_jumps = 1
	_coyote = 0.0
	_set_animation("idle", 0.0)
	health_changed.emit(health, max_health)

func _set_animation(state: String, delta: float) -> void:
	if animation_state != state:
		animation_state = state
		_state_clock = 0.0
	else:
		_state_clock += delta
	if state == "attack":
		frame = mini(5, int(_attack_elapsed / 0.045))
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



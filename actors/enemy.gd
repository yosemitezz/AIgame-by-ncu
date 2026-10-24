extends CharacterBody2D
## Deliberately readable enemy attack tells; body contact alone does not damage.

const PixelActor = preload("res://assets/art/pixel_actor.gd")
var game: Node
var kind: String = "sentry"
var health: int = 3
var max_health: int = 3
var dead: bool = false
var facing: int = -1
var animation_state: String = "idle"
var frame: int = 0
var _home: Vector2
var _clock: float = 0.0
var _cooldown: float = 0.8
var _windup: float = 0.0
var _recovery: float = 0.0
var _stagger: float = 0.0
var _hurt_flash: float = 0.0
var _death_time: float = 0.0
var _attack_facing: int = -1
var _attack_target: Vector2
var _shot: bool = false
var _last_state: String = ""
var _last_frame: int = -1
var _last_facing: int = 0

func configure(owner_game: Node, enemy_kind: String, at: Vector2) -> void:
	game = owner_game
	kind = enemy_kind
	position = at
	_home = at
	max_health = 9 if kind == "elite" else (2 if kind == "wisp" else 3)
	health = max_health

func _ready() -> void:
	collision_layer = 4
	collision_mask = 1
	floor_snap_length = 5.0
	if kind == "wisp":
		motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	var collider: CollisionShape2D = CollisionShape2D.new()
	var shape: RectangleShape2D = RectangleShape2D.new()
	shape.size = Vector2(20.0, 30.0) if kind == "elite" else Vector2(14.0, 24.0)
	collider.shape = shape
	collider.position = Vector2(0.0, -shape.size.y * 0.5)
	add_child(collider)
	add_to_group("enemies")
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func _physics_process(delta: float) -> void:
	_clock += delta
	_hurt_flash = maxf(0.0, _hurt_flash - delta)
	_stagger = maxf(0.0, _stagger - delta)
	_cooldown = maxf(0.0, _cooldown - delta)
	_recovery = maxf(0.0, _recovery - delta)
	if dead:
		_death_time += delta
		animation_state = "dead"
		frame = mini(3, int(_death_time * 10.0))
		_publish_animation()
		queue_redraw()
		if _death_time > 0.36:
			queue_free()
		return
	if not is_instance_valid(game) or not is_instance_valid(game.player):
		return
	var target: Node2D = game.player
	var offset: Vector2 = target.global_position - global_position
	var safe: bool = bool(game.story_safe) or bool(target.dead)
	if kind != "wisp":
		velocity.y = minf(velocity.y + 900.0 * delta, 620.0)
	if safe:
		_windup = 0.0
		_recovery = 0.0
		velocity.x = move_toward(velocity.x, 0.0, 1000.0 * delta)
		if kind == "wisp":
			velocity.y = 0.0
		animation_state = "idle"
	elif _stagger > 0.0:
		_windup = 0.0
		velocity.x = move_toward(velocity.x, 0.0, 600.0 * delta)
		animation_state = "hurt"
	elif _windup > 0.0:
		_windup = maxf(0.0, _windup - delta)
		velocity.x = move_toward(velocity.x, 0.0, 1200.0 * delta)
		if kind == "wisp":
			velocity.y = 0.0
		animation_state = "windup"
		if _windup <= 0.0:
			_execute_attack()
	elif _recovery > 0.0:
		velocity.x = move_toward(velocity.x, 0.0, 900.0 * delta)
		if kind == "wisp":
			velocity.y = 0.0
		animation_state = "attack"
	else:
		facing = 1 if offset.x > 0.0 else -1
		if kind == "wisp":
			_update_wisp(offset, delta)
		else:
			_update_walker(offset, delta)
	move_and_slide()
	frame = int(_clock * (12.0 if animation_state == "run" else 7.0)) % 4
	if global_position.y > 720.0:
		_die()
	_publish_animation()
	queue_redraw()

func _publish_animation() -> void:
	if animation_state == _last_state and frame == _last_frame and facing == _last_facing:
		return
	_last_state = animation_state
	_last_frame = frame
	_last_facing = facing
	if is_instance_valid(game) and game.has_signal("animation_event"):
		game.emit_signal("animation_event", self, animation_state, frame, facing)
func _update_walker(offset: Vector2, delta: float) -> void:
	var attack_range: float = 48.0 if kind == "elite" else 35.0
	if absf(offset.x) < attack_range and absf(offset.y) < 34.0 and _cooldown <= 0.0:
		_begin_attack()
		return
	var speed: float = 88.0 if kind == "elite" else 50.0
	if absf(offset.x) < 310.0 and absf(offset.x) > attack_range * 0.75:
		var may_move: bool = not is_on_floor() or _floor_ahead(facing)
		velocity.x = move_toward(velocity.x, facing * speed if may_move else 0.0, 650.0 * delta)
		if kind == "elite" and is_on_floor() and offset.y < -32.0 and absf(offset.x) < 160.0:
			velocity.y = -280.0
	else:
		velocity.x = move_toward(velocity.x, 0.0, 650.0 * delta)
	animation_state = "run" if absf(velocity.x) > 6.0 else "idle"

func _update_wisp(offset: Vector2, delta: float) -> void:
	var target_y: float = _home.y - 12.0 + sin(_clock * 2.3) * 10.0
	if absf(offset.x) < 350.0:
		velocity.x = move_toward(velocity.x, facing * 42.0 if absf(offset.x) > 170.0 else -facing * 16.0, 150.0 * delta)
		if _cooldown <= 0.0 and offset.length() < 300.0:
			_begin_attack()
	else:
		velocity.x = move_toward(velocity.x, (_home.x - global_position.x) * 0.5, 120.0 * delta)
	velocity.y = clampf((target_y - global_position.y) * 3.0, -35.0, 35.0)
	animation_state = "idle"

func _floor_ahead(direction: int) -> bool:
	var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(global_position + Vector2(direction * 15.0, -4.0), global_position + Vector2(direction * 15.0, 20.0), 1)
	var hit: Dictionary = get_world_2d().direct_space_state.intersect_ray(query)
	return not hit.is_empty()

func _begin_attack() -> void:
	_windup = 0.66 if kind == "wisp" else (0.48 if kind == "elite" else 0.58)
	_cooldown = 1.55 if kind == "wisp" else (1.12 if kind == "elite" else 1.45)
	_attack_facing = facing
	_attack_target = game.player.global_position + Vector2(0.0, -14.0)
	_shot = false
	if game.has_signal("warning_issued"):
		game.emit_signal("warning_issued", "wisp" if kind == "wisp" else "melee", global_position + Vector2(facing * 22.0, -16.0), _windup)
	game.emit_fx("warning", global_position + Vector2(0.0, -33.0), Vector2(facing, 0.0), 0.5)

func _execute_attack() -> void:
	if _shot or dead or bool(game.story_safe) or bool(game.player.dead):
		return
	_shot = true
	_recovery = 0.34
	if kind == "wisp":
		var shot_origin: Vector2 = global_position + Vector2(facing * 8.0, -13.0)
		var direction: Vector2 = (_attack_target - shot_origin).normalized()
		game.spawn_projectile(shot_origin, direction * 130.0, false)
		return
	var player: Node2D = game.player
	var offset: Vector2 = player.global_position - global_position
	var reach: float = 55.0 if kind == "elite" else 41.0
	game.emit_fx("enemy_slash", global_position + Vector2(_attack_facing * 22.0, -17.0), Vector2(_attack_facing, 0.0), 0.8 if kind == "elite" else 0.5)
	if absf(offset.x) > reach or absf(offset.y) > 32.0 or offset.x * _attack_facing < -8.0:
		return
	if float(player.parry_timer) > 0.0 and (global_position.x - player.global_position.x) * int(player.facing) >= -8.0:
		player.parry_success()
		_stagger = 0.55
		_cooldown = 1.1
		receive_hit(1, player.global_position)
	else:
		game.damage_player(1, global_position)

func receive_hit(amount: int, origin: Vector2) -> void:
	if dead or amount <= 0 or _hurt_flash > 0.06 or (is_instance_valid(game) and bool(game.story_safe)):
		return
	health = maxi(0, health - amount)
	_hurt_flash = 0.13
	_stagger = maxf(_stagger, 0.18)
	_windup = 0.0
	velocity.x = (1.0 if global_position.x >= origin.x else -1.0) * (80.0 if kind == "elite" else 145.0)
	if is_instance_valid(game):
		game.emit_fx("hit", global_position + Vector2(0.0, -18.0), (global_position - origin).normalized(), 1.0)
	if health <= 0:
		_die()

func _die() -> void:
	if dead:
		return
	dead = true
	collision_layer = 0
	collision_mask = 0
	remove_from_group("enemies")
	if is_instance_valid(game):
		game.emit_fx("death", global_position + Vector2(0.0, -16.0), Vector2.UP, 1.4 if kind == "elite" else 0.8)
		game.on_enemy_defeated(self)

func _draw() -> void:
	PixelActor.paint(self, kind, animation_state, frame, facing)
	if _windup > 0.0:
		draw_rect(Rect2(-2.0, -41.0, 4.0, 8.0), Color("ffd77c"))
		draw_rect(Rect2(-2.0, -31.0, 4.0, 3.0), Color("fff1bd"))
	if health < max_health and not dead:
		draw_rect(Rect2(-14.0, -45.0, 28.0, 3.0), Color("161829"))
		draw_rect(Rect2(-14.0, -45.0, 28.0 * health / max_health, 3.0), Color("f07873"))


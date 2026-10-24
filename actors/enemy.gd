extends CharacterBody2D
## Deliberately readable enemy attack tells; body contact alone does not damage.

const PixelActor = preload("res://assets/art/pixel_actor.gd")
const AttackProfile = preload("res://combat/attack_profile.gd")
# Original mob patterns: finite layers with a frozen aim corridor, never frame-rate fire.
const SCREEN_WARMUP: float = 0.25
const MAX_LAYERS_PER_TICK: int = 2
var barrage_pattern: String = ""
var barrage_aim: Vector2 = Vector2.LEFT
var barrage_origin: Vector2 = Vector2.ZERO
var game: Node
var kind: String = "sentry"
var patrol_bounds: Rect2 = Rect2()
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
var hurt_flash: float = 0.0
var combat_freeze: float = 0.0
var _hurt_elapsed: float = 0.0
var _death_time: float = 0.0
var _attack_facing: int = -1
var attack_serial: int = 0
var _attack_target: Vector2
var _shot: bool = false
var _last_state: String = ""
var _last_frame: int = -1
var _last_facing: int = 0
var _attack_ranged: bool = false
var _visible_time: float = 0.0
var _barrage_cycle: int = 0
var _barrage_elapsed: float = 0.0
var _barrage_queue: Array[Dictionary] = []
var _owned_shots: Array[WeakRef] = []

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

func set_impact_freeze(seconds: float) -> void:
	if is_instance_valid(game) and bool(game.story_safe):
		combat_freeze = 0.0
		return
	combat_freeze = maxf(combat_freeze, clampf(seconds, 0.0, 0.12))

func _physics_process(delta: float) -> void:
	# Rest wins over queued attacks and local impact hold before either can tick.
	var story_rest: bool = is_instance_valid(game) and bool(game.story_safe)
	if story_rest:
		combat_freeze = 0.0
		_cancel_barrage()
		_clear_owned_hostiles()
		_stagger = 0.0
	_update_visibility(delta)
	_prune_owned_shots()
	if combat_freeze > 0.0:
		combat_freeze = maxf(0.0, combat_freeze - delta)
		queue_redraw()
		return
	_clock += delta
	_hurt_flash = maxf(0.0, _hurt_flash - delta)
	hurt_flash = _hurt_flash
	modulate = Color(2.5, 2.1, 1.7, 1.0) if hurt_flash > 0.065 else Color.WHITE
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
	var safe: bool = story_rest or bool(target.dead)
	if kind != "wisp":
		velocity.y = minf(velocity.y + 900.0 * delta, 620.0)
	if not _barrage_queue.is_empty():
		if safe or _stagger > 0.0 or not _can_emit_barrage():
			_cancel_barrage()
		else:
			_advance_barrage(delta)
	if safe:
		_cancel_barrage()
		velocity.x = move_toward(velocity.x, 0.0, 1000.0 * delta)
		if kind == "wisp":
			velocity.y = 0.0
		animation_state = "idle"
	elif _stagger > 0.0:
		_cancel_barrage()
		_hurt_elapsed += delta
		# Preserve the impulse through hurt: steering cannot overwrite it.
		velocity.x = move_toward(velocity.x, 0.0, (190.0 if kind == "elite" else 280.0) * delta)
		if kind == "wisp":
			velocity.y = move_toward(velocity.y, 0.0, 160.0 * delta)
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
	_keep_in_patrol()
	frame = mini(3, int(_hurt_elapsed * 14.0)) if animation_state == "hurt" else int(_clock * (12.0 if animation_state == "run" else 7.0)) % 4
	var out_of_bounds: bool = bool(game.enemy_out_of_bounds(global_position)) if game.has_method("enemy_out_of_bounds") else global_position.y > 720.0
	if out_of_bounds:
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
	if not _target_in_patrol():
		var home_offset: float = _home.x - global_position.x
		var direction: int = 1 if home_offset > 0.0 else -1
		var may_return: bool = absf(home_offset) > 12.0 and (not is_on_floor() or _floor_ahead(direction))
		velocity.x = move_toward(velocity.x, direction * 40.0 if may_return else 0.0, 650.0 * delta)
		animation_state = "run" if absf(velocity.x) > 6.0 else "idle"
		return
	var attack_range: float = 48.0 if kind == "elite" else 35.0
	if absf(offset.x) < attack_range and absf(offset.y) < 34.0 and _cooldown <= 0.0:
		_begin_attack()
		return
	if _cooldown <= 0.0 and is_on_floor() and _can_start_barrage():
		_begin_attack(true)
		return
	var speed: float = 88.0 if kind == "elite" else 50.0
	if absf(offset.x) < ranged_outer_distance() + 12.0 and absf(offset.x) > attack_range * 0.75:
		var may_move: bool = not is_on_floor() or _floor_ahead(facing)
		velocity.x = move_toward(velocity.x, facing * speed if may_move else 0.0, 650.0 * delta)
		if kind == "elite" and is_on_floor() and offset.y < -32.0 and absf(offset.x) < 160.0:
			velocity.y = -280.0
	else:
		velocity.x = move_toward(velocity.x, 0.0, 650.0 * delta)
	animation_state = "run" if absf(velocity.x) > 6.0 else "idle"

func _update_wisp(offset: Vector2, delta: float) -> void:
	var target_y: float = _home.y - 12.0 + sin(_clock * 2.3) * 10.0
	if patrol_bounds.has_area():
		target_y = clampf(target_y, patrol_bounds.position.y + 12.0, patrol_bounds.end.y - 8.0)
	if absf(offset.x) < ranged_outer_distance() + 12.0 and _target_in_patrol():
		velocity.x = move_toward(velocity.x, facing * 42.0 if absf(offset.x) > wisp_standoff_distance() else -facing * 16.0, 150.0 * delta)
		if _cooldown <= 0.0 and _can_start_barrage():
			_begin_attack(true)
	else:
		velocity.x = move_toward(velocity.x, (_home.x - global_position.x) * 0.5, 120.0 * delta)
	velocity.y = clampf((target_y - global_position.y) * 3.0, -35.0, 35.0)
	animation_state = "idle"

func _target_in_patrol() -> bool:
	return not patrol_bounds.has_area() or patrol_bounds.grow(8.0).has_point(game.player.global_position)

func _keep_in_patrol() -> void:
	if not patrol_bounds.has_area():
		return
	var minimum: float = patrol_bounds.position.x + 8.0
	var maximum: float = maxf(minimum, patrol_bounds.end.x - 8.0)
	global_position.x = clampf(global_position.x, minimum, maximum)
	if (global_position.x <= minimum and velocity.x < 0.0) or (global_position.x >= maximum and velocity.x > 0.0):
		velocity.x = 0.0
	if kind == "wisp":
		var min_y: float = patrol_bounds.position.y + 8.0
		var max_y: float = maxf(min_y, patrol_bounds.end.y - 8.0)
		global_position.y = clampf(global_position.y, min_y, max_y)
		if (global_position.y <= min_y and velocity.y < 0.0) or (global_position.y >= max_y and velocity.y > 0.0):
			velocity.y = 0.0

func _floor_ahead(direction: int) -> bool:
	var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(global_position + Vector2(direction * 15.0, -4.0), global_position + Vector2(direction * 15.0, 20.0), 1)
	var hit: Dictionary = get_world_2d().direct_space_state.intersect_ray(query)
	return not hit.is_empty()

func _begin_attack(ranged: bool = false) -> void:
	if dead or not is_instance_valid(game) or not is_instance_valid(game.player) or bool(game.story_safe) or bool(game.player.dead):
		return
	var will_shoot: bool = kind == "wisp" or ranged
	if will_shoot and not _can_start_barrage():
		return
	_barrage_queue.clear()
	_attack_ranged = will_shoot
	attack_serial += 1
	_attack_facing = facing
	_attack_target = game.player.global_position + Vector2(0.0, -14.0)
	barrage_origin = _muzzle()
	barrage_aim = (_attack_target - barrage_origin).normalized()
	if barrage_aim.length_squared() < 0.1:
		barrage_aim = Vector2(_attack_facing, 0)
	_shot = false
	if will_shoot:
		barrage_pattern = "sentry_fork" if kind == "sentry" else ("wisp_crown" if kind == "wisp" else ("elite_fan" if _barrage_cycle % 2 == 0 else "elite_wheel"))
		_barrage_cycle += 1
		_windup = 0.75 if kind == "wisp" else (0.85 if kind == "elite" else 0.62)
		_cooldown = _ranged_reload()
	else:
		barrage_pattern = ""
		_windup = 0.48 if kind == "elite" else 0.58
		_cooldown = 1.12 if kind == "elite" else 1.45
	if game.has_signal("warning_issued"):
		game.emit_signal("warning_issued", "mob_" + kind if will_shoot else "melee", barrage_origin, _windup)
	game.emit_fx("warning", global_position + Vector2(0.0, -33.0), Vector2(_attack_facing, 0.0), 0.5)

func _execute_attack() -> void:
	if _shot or dead or bool(game.story_safe) or bool(game.player.dead):
		return
	_shot = true
	_windup = 0.0
	_recovery = 0.34
	if _attack_ranged:
		if not _can_emit_barrage():
			_cancel_barrage()
			return
		_barrage_elapsed = 0.0
		_barrage_queue.append({"at": 0.0, "layer": 0})
		if kind != "sentry":
			_barrage_queue.append({"at": 0.24 if kind == "wisp" else 0.28, "layer": 1})
		_recovery = 0.42 if kind == "elite" else (0.38 if kind == "wisp" else 0.34)
		_advance_barrage(0.0)
		return
	var player: Node2D = game.player
	var offset: Vector2 = player.global_position - global_position
	var reach: float = 55.0 if kind == "elite" else 41.0
	game.emit_fx("enemy_slash", global_position + Vector2(_attack_facing * 22.0, -17.0), Vector2(_attack_facing, 0.0), 0.8 if kind == "elite" else 0.5)
	if absf(offset.x) > reach or absf(offset.y) > 32.0 or offset.x * _attack_facing < -8.0:
		return
	var blade_root: Vector2 = global_position + Vector2(_attack_facing * 8.0, -17.0)
	var blade_tip: Vector2 = global_position + Vector2(_attack_facing * reach, -17.0)
	var guard_point: Vector2 = player.global_position + Vector2(int(player.facing) * 18.0, -18.0)
	var contact: Vector2 = Geometry2D.get_closest_point_to_segment(guard_point, blade_root, blade_tip)
	if player.parry_success(self, contact, "melee", attack_serial):
		_stagger = 0.55
		_cooldown = 1.1
		receive_hit(1, player.global_position)
	else:
		game.damage_player(1, global_position)

func _muzzle() -> Vector2:
	return global_position + Vector2(_attack_facing * 10.0, -18.0 if kind != "wisp" else -13.0)

func _emitter_visible() -> bool:
	# Test the complete actor bounds in viewport coordinates. This follows both
	# camera axes, its actual viewport size and zoom, including underground rooms.
	var bounds: Rect2 = get_global_transform_with_canvas() * Rect2(-14, -42, 28, 44)
	return get_viewport_rect().grow(-24.0).encloses(bounds)

func _update_visibility(delta: float) -> void:
	if _emitter_visible():
		_visible_time = minf(SCREEN_WARMUP, _visible_time + maxf(delta, 0.0))
	else:
		_visible_time = 0.0
		if _attack_ranged or not _barrage_queue.is_empty():
			_cancel_barrage()
		_cooldown = maxf(_cooldown, 0.45)

func _has_line_of_sight(target_at: Vector2) -> bool:
	if not is_inside_tree():
		return false
	var query := PhysicsRayQueryParameters2D.create(_muzzle(), target_at, 1)
	return get_world_2d().direct_space_state.intersect_ray(query).is_empty()

static func ranged_outer_distance() -> float:
	# The real finisher reaches 228px. Add 112px of visible warning runway,
	# capped at 340px so the existing screen/LOS checks remain the outer authority.
	return minf(340.0, AttackProfile.radii(3).x + 112.0)

static func wisp_standoff_distance() -> float:
	# A 32px buffer beyond the real finisher (260px now) permits a readable
	# retreat, while player speed still closes on the unchanged 16px/s backpedal.
	return minf(ranged_outer_distance() - 64.0, AttackProfile.radii(3).x + 32.0)

func _ranged_distance_allowed() -> bool:
	if not is_instance_valid(game) or not is_instance_valid(game.player):
		return false
	var distance: float = _muzzle().distance_to(game.player.global_position + Vector2(0, -14))
	var minimum: float = 144.0 if kind == "elite" else (120.0 if kind == "wisp" else 112.0)
	var maximum: float = ranged_outer_distance()
	return distance >= minimum and distance <= maximum

func _can_start_barrage() -> bool:
	return _visible_time >= SCREEN_WARMUP and _emitter_visible() and _target_in_patrol() and _ranged_distance_allowed() and _has_line_of_sight(game.player.global_position + Vector2(0, -14))

func _can_emit_barrage() -> bool:
	return _visible_time >= SCREEN_WARMUP and _emitter_visible() and _target_in_patrol() and _ranged_distance_allowed() and _has_line_of_sight(_attack_target)

func _ranged_reload() -> float:
	return 1.70 if kind == "wisp" else (2.10 if kind == "elite" else 1.75)

func get_pending_barrage_layers() -> int:
	return _barrage_queue.size()

static func barrage_angles(pattern: String, layer: int = 0) -> Array[float]:
	var degrees: Array[float] = []
	match pattern:
		"sentry_fork": degrees.assign([-24.0, -12.0, 12.0, 24.0])
		"wisp_crown": degrees.assign([-54.0, -36.0, -18.0, 18.0, 36.0, 54.0] if layer == 0 else [-51.0, -33.0, -15.0, 21.0, 39.0, 57.0])
		"elite_fan": degrees.assign([-48.0, -34.0, -22.0, -10.0, 10.0, 22.0, 34.0, 48.0])
		"elite_wheel":
			for i: int in 12:
				var angle: float = wrapf(float(i) * 30.0 + float(layer) * 15.0, -180.0, 180.0)
				if absf(angle) > 30.0:
					degrees.append(angle)
	var result: Array[float] = []
	for angle: float in degrees:
		result.append(deg_to_rad(angle))
	return result

func _advance_barrage(delta: float) -> void:
	if _barrage_queue.is_empty():
		return
	if dead or bool(game.story_safe) or bool(game.player.dead) or _stagger > 0.0 or not _can_emit_barrage():
		_cancel_barrage()
		return
	_barrage_elapsed += maxf(0.0, delta)
	var dispatched: int = 0
	while not _barrage_queue.is_empty() and dispatched < MAX_LAYERS_PER_TICK and float(_barrage_queue[0]["at"]) <= _barrage_elapsed:
		var layer: Dictionary = _barrage_queue.pop_front()
		# Consume the finite layer even when root/global/source caps reject shots.
		# No rejected projectile is retried on future physics frames.
		dispatched += 1
		_emit_barrage_layer(int(layer["layer"]))
	if _barrage_queue.is_empty():
		_cooldown = maxf(_cooldown, _ranged_reload())

func _emit_barrage_layer(layer: int) -> void:
	var speed: float = 118.0 if kind == "elite" else (105.0 if kind == "wisp" else 115.0)
	var style: String = "elite_rune" if kind == "elite" else ("wisp_seed" if kind == "wisp" else "sentry_shard")
	var source_cap: int = 28 if kind == "elite" else (18 if kind == "wisp" else 8)
	for angle: float in barrage_angles(barrage_pattern, layer):
		if _live_hostiles() >= source_cap:
			break
		var projectile: Node2D = game.spawn_projectile(_muzzle(), barrage_aim.rotated(angle) * speed, false, style)
		if not is_instance_valid(projectile):
			continue
		projectile.set_meta("mob_source_id", get_instance_id())
		projectile.set_meta("mob_attack_serial", attack_serial)
		_owned_shots.append(weakref(projectile))

func _live_hostiles() -> int:
	var total: int = 0
	for ref: WeakRef in _owned_shots:
		var projectile: Node = ref.get_ref()
		if is_instance_valid(projectile) and not projectile.is_queued_for_deletion() and not bool(projectile.get("friendly")):
			total += 1
	return total

func _prune_owned_shots() -> void:
	var outer: Rect2 = get_viewport_rect().grow(96.0)
	for i: int in range(_owned_shots.size() - 1, -1, -1):
		var projectile: Node2D = _owned_shots[i].get_ref()
		if not is_instance_valid(projectile) or projectile.is_queued_for_deletion():
			_owned_shots.remove_at(i)
		elif not bool(projectile.get("friendly")) and not outer.has_point(projectile.get_global_transform_with_canvas() * Vector2.ZERO):
			projectile.clear()
			_owned_shots.remove_at(i)

func _clear_owned_hostiles() -> void:
	for ref: WeakRef in _owned_shots:
		var projectile: Node = ref.get_ref()
		if is_instance_valid(projectile) and not projectile.is_queued_for_deletion() and not bool(projectile.get("friendly")):
			projectile.clear()
	_owned_shots.clear()

func _cancel_barrage() -> void:
	_barrage_queue.clear()
	_barrage_elapsed = 0.0
	_attack_ranged = false
	_windup = 0.0
	_recovery = 0.0
	_shot = true

func receive_hit(amount: int, origin: Vector2) -> void:
	if dead or amount <= 0 or _hurt_flash > 0.06 or (is_instance_valid(game) and bool(game.story_safe)):
		return
	var heavy: bool = amount >= 2
	health = maxi(0, health - amount)
	_hurt_flash = 0.15 if heavy else 0.12
	hurt_flash = _hurt_flash
	_hurt_elapsed = 0.0
	_stagger = maxf(_stagger, (0.30 if heavy else 0.18) if kind == "elite" else (0.36 if heavy else 0.23))
	_cancel_barrage()
	_cooldown = maxf(_cooldown, _stagger + 0.24)
	var impulse: float = (155.0 if heavy else 90.0) if kind == "elite" else (230.0 if heavy else 145.0)
	velocity.x = (1.0 if global_position.x >= origin.x else -1.0) * impulse
	velocity.y = -110.0 if heavy else -52.0
	modulate = Color(2.5, 2.1, 1.7, 1.0)
	animation_state = "hurt"
	frame = 0
	_publish_animation()
	if is_instance_valid(game):
		game.emit_fx("hit", global_position + Vector2(0.0, -18.0), (global_position - origin).normalized(), 1.35 if heavy else 0.75)
	if health <= 0:
		_die()

func _die() -> void:
	if dead:
		return
	dead = true
	_cancel_barrage()
	_clear_owned_hostiles()
	animation_state = "dead"
	frame = 0
	_publish_animation()
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

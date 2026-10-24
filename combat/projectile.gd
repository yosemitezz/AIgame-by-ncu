extends Node2D
## Swept contacts avoid tunnelling. A musical miss is never a damage source.

var game: Node
var velocity: Vector2 = Vector2.ZERO
var friendly: bool = false
var _age: float = 0.0
var _cleared: bool = false
var _trail: Array[Vector2] = []

func configure(owner_game: Node, at: Vector2, motion: Vector2, is_friendly: bool = false) -> void:
	game = owner_game
	position = at
	velocity = motion
	friendly = is_friendly

func _ready() -> void:
	add_to_group("projectiles")
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	z_index = 5

func _physics_process(delta: float) -> void:
	if _cleared:
		return
	if not is_instance_valid(game) or bool(game.story_safe):
		clear()
		return
	_age += delta
	if _age > 6.0 or global_position.y > 720.0 or global_position.y < -350.0:
		clear()
		return
	var previous: Vector2 = global_position
	var destination: Vector2 = previous + velocity * delta
	var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(previous, destination, 1)
	var wall_hit: Dictionary = get_world_2d().direct_space_state.intersect_ray(query)
	if not wall_hit.is_empty():
		destination = wall_hit["position"]
	if friendly:
		var chosen: Node2D
		var chosen_distance: float = INF
		for enemy in get_tree().get_nodes_in_group("enemies"):
			if not is_instance_valid(enemy) or bool(enemy.dead):
				continue
			var center: Vector2 = enemy.global_position + Vector2(0.0, -26.0 if enemy == game.boss else -15.0)
			var closest: Vector2 = Geometry2D.get_closest_point_to_segment(center, previous, destination)
			var radius: float = 25.0 if enemy == game.boss else 16.0
			if closest.distance_to(center) <= radius and previous.distance_to(closest) < chosen_distance:
				chosen = enemy
				chosen_distance = previous.distance_to(closest)
		if is_instance_valid(chosen):
			chosen.receive_hit(2, previous)
			game.emit_fx("hit", chosen.global_position + Vector2(0.0, -18.0), velocity.normalized(), 0.9)
			clear()
			return
	elif is_instance_valid(game.player) and not bool(game.player.dead):
		var player: Node2D = game.player
		var center: Vector2 = player.global_position + Vector2(0.0, -13.0)
		var hurt_contact: float = _circle_contact(previous, destination, center, 11.0)
		var parry_center: Vector2 = player.global_position + Vector2(int(player.facing) * 18.0, -16.0)
		var parry_contact: float = _circle_contact(previous, destination, parry_center, 20.0)
		# Resolve the earliest actual contact. A shot arriving from behind cannot
		# be reflected after it has already crossed the player's hurt circle.
		if float(player.parry_timer) > 0.0 and parry_contact >= 0.0 and (hurt_contact < 0.0 or parry_contact <= hurt_contact):
			global_position = previous.lerp(destination, parry_contact)
			reflect()
			return
		if hurt_contact >= 0.0:
			game.damage_player(1, previous)
			clear()
			return
	_trail.push_front(previous)
	if _trail.size() > 5:
		_trail.pop_back()
	global_position = destination
	if not wall_hit.is_empty():
		game.emit_fx("spark", destination, -velocity.normalized(), 0.25)
		clear()
		return
	queue_redraw()

func _circle_contact(from_at: Vector2, to_at: Vector2, center: Vector2, radius: float) -> float:
	var offset: Vector2 = from_at - center
	var c: float = offset.length_squared() - radius * radius
	if c <= 0.0:
		return 0.0
	var step: Vector2 = to_at - from_at
	var a: float = step.length_squared()
	if a < 0.000001:
		return -1.0
	var b: float = 2.0 * offset.dot(step)
	var discriminant: float = b * b - 4.0 * a * c
	if discriminant < 0.0:
		return -1.0
	var contact: float = (-b - sqrt(discriminant)) / (2.0 * a)
	return contact if contact >= 0.0 and contact <= 1.0 else -1.0

func reflect() -> void:
	if _cleared or friendly or not is_instance_valid(game) or bool(game.story_safe):
		return
	friendly = true
	_age = 0.0
	_trail.clear()
	var direction: Vector2 = Vector2(1.0, -0.12)
	if is_instance_valid(game.player):
		direction = Vector2(int(game.player.facing), -0.12).normalized()
		game.player.parry_success()
	var nearest: float = 900.0
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy) or bool(enemy.dead):
			continue
		var target: Vector2 = enemy.global_position + Vector2(0.0, -26.0 if enemy == game.boss else -15.0)
		var distance: float = global_position.distance_to(target)
		if distance < nearest:
			nearest = distance
			direction = (target - global_position).normalized()
	velocity = direction * maxf(250.0, velocity.length() + 80.0)
	queue_redraw()

func clear() -> void:
	if _cleared:
		return
	_cleared = true
	remove_from_group("projectiles")
	queue_free()

func _draw() -> void:
	var ink: Color = Color("73f6df") if friendly else Color("ffd47c")
	for index in range(_trail.size() - 1, -1, -1):
		var local: Vector2 = (_trail[index] - global_position).round()
		var tail: Color = ink
		tail.a = 0.40 * (1.0 - float(index) / 6.0)
		draw_rect(Rect2(local - Vector2.ONE, Vector2(3.0, 3.0)), tail)
	draw_rect(Rect2(-2.0, -4.0, 4.0, 8.0), ink)
	draw_rect(Rect2(-4.0, -2.0, 8.0, 4.0), ink)
	draw_rect(Rect2(-1.0, -2.0, 2.0, 4.0), Color("f3ffea"))



extends SceneTree
## Shared profile geometry and static physics fixtures. No level playback.
const AttackProfile = preload("res://combat/attack_profile.gd")
const MeleeQuery = preload("res://combat/melee_query.gd")
const Player = preload("res://actors/player.gd")
const STEP: float = 1.0 / 60.0
var passed: int = 0
var failed: int = 0
var arena: QueryArena
var player: CharacterBody2D
var markers: Array[Node2D] = []

class Target extends Node2D:
	var dead: bool = false
	var damage_calls: int = 0
	func receive_hit(_amount: int, _origin: Vector2) -> void:
		damage_calls += 1

class QueryArena extends Node2D:
	signal animation_event(actor: Node, state: String, frame: int, facing: int)
	var story_safe: bool = false
	var _paused: bool = false
	var targets: Array[Node2D] = []
	var queries: Array[Dictionary] = []
	var freeze_first: bool = false
	var held_once: bool = false
	func emit_fx(_kind: String, _at: Vector2, _direction: Vector2, _power: float) -> void:
		pass
	func hero_attack(source: Node2D, damage: int, reach: float, combo: int) -> void:
		if story_safe:
			return
		var hits: Array[Node2D] = MeleeQuery.collect(source, targets, source.attack_sweep_from, source.attack_sweep_to, 0)
		queries.append({"serial": source.attack_serial, "combo": combo, "damage": damage, "reach": reach, "from": source.attack_sweep_from, "to": source.attack_sweep_to, "progress": source.get_attack_progress(), "time": source._attack_elapsed, "hits": hits})
		if freeze_first and not held_once:
			held_once = true
			source.set_impact_freeze(0.04)

func check(value: bool, label: String) -> void:
	if value:
		passed += 1
		print("PASS ", label)
	else:
		failed += 1
		push_error("FAIL " + label)

func marker(local_at: Vector2, size: Vector2 = Vector2(0.5, 0.5)) -> Node2D:
	var node: Target = Target.new()
	node.set_meta("melee_hurt_rect", Rect2(-size * 0.5, size))
	arena.add_child(node)
	node.global_position = player.global_position + local_at
	markers.append(node)
	return node

func arc_point(slot: int, degrees: float, fraction: float) -> Vector2:
	var radius: Vector2 = AttackProfile.radii(slot) * fraction
	var angle: float = deg_to_rad(degrees)
	return AttackProfile.origin() + Vector2(cos(angle) * radius.x, sin(angle) * radius.y)

func clear_markers() -> void:
	for node: Node2D in markers:
		if is_instance_valid(node):
			node.free()
	markers.clear()
	arena.targets.clear()

func reset_player(at: Vector2 = Vector2(0.0, 300.0)) -> void:
	arena.story_safe = false
	arena.freeze_first = false
	arena.held_once = false
	arena.queries.clear()
	player.revive(at)
	player.invuln = 0.0
	player.facing = 1
	player.move_and_slide()
	for action: String in ["move_left", "move_right", "attack", "dash", "parry", "jump", "climb_up", "climb_down"]:
		if InputMap.has_action(action):
			Input.action_release(action)

func ticks(count: int, delta: float = 0.01) -> void:
	for index: int in range(count):
		player._physics_process(delta)

func wall(at: Vector2, size: Vector2) -> StaticBody2D:
	var body: StaticBody2D = StaticBody2D.new()
	var collider: CollisionShape2D = CollisionShape2D.new()
	var shape: RectangleShape2D = RectangleShape2D.new()
	shape.size = size
	collider.shape = shape
	collider.position = at
	body.add_child(collider)
	arena.add_child(body)
	return body

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	for action: String in ["move_left", "move_right", "attack", "dash", "parry", "jump"]:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
	arena = QueryArena.new()
	root.add_child(arena)
	player = Player.new()
	player.configure(arena)
	arena.add_child(player)
	player.set_physics_process(false)
	player.hide()
	var floor_body: StaticBody2D = wall(Vector2(-100.0, 312.0), Vector2(300.0, 24.0))
	await physics_frame
	reset_player()
	await process_frame
	check(AttackProfile.data().get("version") == 1, "versioned attack JSON is the loaded single profile source")
	var expected: Array[Vector2] = [Vector2(180.0, 72.0), Vector2(204.0, 84.0), Vector2(228.0, 96.0)]
	for slot: int in range(1, 4):
		player.combo = slot
		player.attack_phase = "active"
		var radius: Vector2 = AttackProfile.radii(slot)
		check(radius == expected[slot - 1] and radius.x > 3.0 * [42.0, 47.0, 55.0][slot - 1], "cut %d actual radii significantly exceed the former short reach" % slot)
		var inner: Node2D = marker(AttackProfile.origin() + Vector2(radius.x - 0.75, 0.0))
		var outer: Node2D = marker(AttackProfile.origin() + Vector2(radius.x + 1.0, 0.0))
		var corner: Node2D = marker(AttackProfile.origin() + radius * 0.95)
		var candidates: Array[Node2D] = MeleeQuery.collect(player, [inner, outer, corner, inner], 0.25, 1.0, 0)
		check(candidates.has(inner) and not candidates.has(outer), "cut %d distinguishes inside and outside reach boundary" % slot)
		check(not candidates.has(corner), "cut %d rejects a rectangular corner outside its elliptical sword route" % slot)
		check(candidates.count(inner) == 1 and inner.damage_calls == 0, "cut %d returns each candidate once without applying any damage" % slot)
		var middle_angle: float = [22.0, -20.0, 21.0][slot - 1]
		var middle: Node2D = marker(arc_point(slot, middle_angle, 0.8))
		check(MeleeQuery.collect(player, [middle], 0.25, 0.25, 0).is_empty() and MeleeQuery.collect(player, [middle], 1.0, 1.0, 0).is_empty() and MeleeQuery.collect(player, [middle], 0.25, 1.0, 0).has(middle), "cut %d catches an intermediate swept angle missed by both endpoint poses" % slot)
		var high: Node2D = marker(arc_point(slot, [-28.0, -65.0, -25.0][slot - 1], 0.8))
		var low: Node2D = marker(arc_point(slot, [65.0, 24.0, 62.0][slot - 1], 0.8))
		var too_high: Node2D = marker(AttackProfile.origin() + Vector2(20.0, -radius.y - 2.0))
		var vertical: Array[Node2D] = MeleeQuery.collect(player, [high, low, too_high], 0.25, 1.0, 0)
		check(vertical.has(high) and vertical.has(low) and not vertical.has(too_high), "cut %d has real high and low coverage with a finite vertical boundary" % slot)
		check(AttackProfile.sweep_polygon(slot, 0.0, 0.249).is_empty(), "cut %d raised active pose remains harmless" % slot)
		clear_markers()

	player.combo = 1
	player.attack_phase = "active"
	var behind: Node2D = marker(Vector2(-1.0, -24.0), Vector2(30.0, 20.0))
	check(MeleeQuery.collect(player, [behind], 0.25, 1.0, 0).is_empty(), "behind-center target is rejected even when its hurtbox overlaps the front")
	clear_markers()
	player.facing = -1
	var mirrored: Node2D = marker(AttackProfile.origin() + Vector2(-150.0, 0.0))
	check(MeleeQuery.collect(player, [mirrored], 0.25, 1.0, 0).has(mirrored), "left-facing sweep mirrors the same large profile")
	player.attack_phase = "recover"
	check(MeleeQuery.collect(player, [mirrored], 0.25, 1.0, 0).is_empty(), "recovery cannot produce melee candidates")
	clear_markers()
	reset_player()
	player.combo = 1
	player.attack_phase = "active"
	var occluded: Node2D = marker(AttackProfile.origin() + Vector2(150.0, 0.0))
	var barrier: StaticBody2D = wall(Vector2(90.0, 276.0), Vector2(8.0, 240.0))
	await physics_frame
	check(MeleeQuery.collect(player, [occluded], 0.25, 1.0, 0).has(occluded) and MeleeQuery.collect(player, [occluded], 0.25, 1.0, 1).is_empty(), "world-mask wall blocks a geometrically valid target")
	barrier.free()
	await physics_frame
	check(MeleeQuery.collect(player, [occluded], 0.25, 1.0, 1).has(occluded), "removing the wall restores an actual clear line of sight")
	var expired: Node2D = Target.new()
	expired.free()
	check(MeleeQuery.collect(player, [expired, null, 7], 0.25, 1.0, 0).is_empty(), "stale or malformed candidate entries are ignored safely")
	clear_markers()

	for delta: float in [0.01, 0.11]:
		reset_player()
		await process_frame
		var middle: Node2D = marker(arc_point(1, 22.0, 0.6))
		arena.targets = [middle]
		player._start_attack()
		var serial: int = player.attack_serial
		for index: int in range(60):
			if player.attack_phase == "none":
				break
			player._physics_process(delta)
		var contiguous: bool = not arena.queries.is_empty()
		var previous: float = 0.25
		var caught: bool = false
		for query: Dictionary in arena.queries:
			contiguous = contiguous and query.serial == serial and absf(float(query["from"]) - previous) < 0.000001 and float(query.to) >= float(query["from"]) and float(query.progress) >= 0.25
			previous = float(query.to)
			caught = caught or query.hits.has(middle)
		check(contiguous and is_equal_approx(previous, 1.0), "physics delta %.2f covers contiguous sweep intervals through the final active edge" % delta)
		check(caught and middle.damage_calls == 0, "physics delta %.2f catches the middle route without stealing root damage authority" % delta)
		var first_query: Dictionary = arena.queries[0] if not arena.queries.is_empty() else {}
		check(not first_query.is_empty() and absf(float(first_query.time) - 0.06875) < 0.000001, "physics delta %.2f preserves exact first contact gating at active quarter" % delta)
		clear_markers()

	reset_player()
	await process_frame
	arena.freeze_first = true
	player._start_attack()
	player._physics_process(0.08)
	var held_queries: int = arena.queries.size()
	var held_from: float = player.attack_sweep_from
	var held_to: float = player.attack_sweep_to
	ticks(3)
	check(player.combat_freeze > 0.0 and arena.queries.size() == held_queries and player.attack_sweep_from == held_from and player.attack_sweep_to == held_to, "local hold freezes sweep queries and their displayed contact interval")
	ticks(3)
	check(arena.queries.size() > held_queries, "sweep resumes after local hold without discarding the active interval")
	player.queued_attack = true
	arena.story_safe = true
	player._physics_process(0.0)
	var stopped_queries: int = arena.queries.size()
	arena.story_safe = false
	ticks(40)
	check(player.attack_phase == "none" and not player.queued_attack and arena.queries.size() == stopped_queries, "rest cancels pending wide sweep and queued follow-up")
	var old_serial: int = player.attack_serial
	player.revive(Vector2.ZERO)
	player._start_attack()
	check(player.attack_serial == old_serial + 1 and is_equal_approx(player.attack_sweep_from, 0.25) and is_equal_approx(player.attack_sweep_to, 0.25), "retry starts a fresh serial with reset sweep interval")

	reset_player(Vector2(0.0, 300.0))
	await physics_frame
	player._physics_process(STEP)
	check(player.is_on_floor() and player._can_ground_lunge(STEP), "guarded lunge is allowed over clear nearby ground")
	player.position.x = 38.0
	player.move_and_slide()
	check(not player._can_ground_lunge(STEP), "forward ground probe refuses automatic lunge at a pit edge")
	player._start_attack()
	player._advance_attack(0.08)
	var edge_at: Vector2 = player.global_position
	player._physics_process(STEP)
	check(is_equal_approx(player.velocity.x, 0.0) and is_equal_approx(player.global_position.x, edge_at.x), "neutral attack does not drag a player over the edge")
	reset_player(Vector2(0.0, 300.0))
	var near_wall: StaticBody2D = wall(Vector2(18.0, 276.0), Vector2(4.0, 80.0))
	await physics_frame
	player._physics_process(STEP)
	check(not player._can_ground_lunge(STEP), "forward wall probe rejects automatic push into an obstacle")
	near_wall.free()
	reset_player(Vector2(0.0, 200.0))
	player._start_attack()
	player._advance_attack(0.08)
	player._physics_process(STEP)
	check(not player.is_on_floor() and is_equal_approx(player.velocity.x, 0.0), "air attack preserves separate free steering without ground auto-push")
	check(is_equal_approx(Engine.time_scale, 1.0) and not paused, "wide attacks never change the global music or simulation clock")
	floor_body.free()
	clear_markers()
	arena.free()
	print("Attack profile: %d passed, %d failed" % [passed, failed])
	quit(1 if failed > 0 else 0)

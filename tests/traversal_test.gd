extends SceneTree
## Static traversal fixtures and bounded controller checks, no level playthrough.
const Player = preload("res://actors/player.gd")
const STEP: float = 1.0 / 60.0
var passed: int = 0
var failed: int = 0
var game: TraversalGame
var level: Terrain
var player: CharacterBody2D

class Terrain extends Node:
	var enabled: bool = true
	var malformed: bool = false
	var wet: bool = false
	var kind: String = "ladder"
	var area: Rect2 = Rect2(-12.0, 100.0, 24.0, 200.0)
	func climb_at(feet: Vector2) -> Dictionary:
		if malformed:
			return {"rect": "invalid", "kind": 1, "id": null}
		if enabled and feet.x >= area.position.x and feet.x <= area.end.x and feet.y >= area.position.y and feet.y <= area.end.y:
			return {"rect": area, "kind": kind, "id": "fixture_" + kind}
		return {}
	func water_at(feet: Vector2) -> bool:
		return wet and feet.x >= 180.0 and feet.x <= 460.0 and feet.y >= 296.0 and feet.y <= 326.0

class TraversalGame extends Node2D:
	signal animation_event(actor: Node, state: String, frame: int, facing: int)
	var level: Node
	var story_safe: bool = false
	var _paused: bool = false
	var effects: Array[String] = []
	func hero_attack(_source: Node2D, _damage: int, _reach: float, _combo: int) -> void:
		pass
	func emit_fx(kind: String, _at: Vector2, _direction: Vector2, _power: float) -> void:
		effects.append(kind)

class LegacyGame extends Node2D:
	var story_safe: bool = false
	func emit_fx(_kind: String, _at: Vector2, _direction: Vector2, _power: float) -> void:
		pass

func check(value: bool, label: String) -> void:
	if value:
		passed += 1
		print("PASS ", label)
	else:
		failed += 1
		push_error("FAIL " + label)

func reset_actor(at: Vector2 = Vector2(0.0, 200.0)) -> void:
	game.story_safe = false
	game._paused = false
	level.enabled = true
	level.malformed = false
	level.wet = false
	level.kind = "ladder"
	game.effects.clear()
	player.configure(game)
	player.revive(at)
	player.invuln = 0.0
	player.move_and_slide()
	for action: String in ["move_left", "move_right", "attack", "dash", "parry", "jump", "climb_up", "climb_down"]:
		Input.action_release(action)

func ticks(count: int, delta: float = 0.01) -> void:
	for index: int in range(count):
		player._physics_process(delta)

func attach(at: Vector2 = Vector2(0.0, 200.0)) -> void:
	reset_actor(at)
	await process_frame
	Input.action_press("climb_up")
	player._physics_process(STEP)

func body_rect(at: Vector2, size: Vector2) -> StaticBody2D:
	var body: StaticBody2D = StaticBody2D.new()
	var collider: CollisionShape2D = CollisionShape2D.new()
	var shape: RectangleShape2D = RectangleShape2D.new()
	shape.size = size
	collider.shape = shape
	collider.position = at
	body.add_child(collider)
	game.add_child(body)
	return body

func splash_count() -> int:
	return game.effects.count("water_splash")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	for action: String in ["move_left", "move_right", "attack", "dash", "parry", "jump", "climb_up", "climb_down"]:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
	game = TraversalGame.new()
	root.add_child(game)
	level = Terrain.new()
	game.add_child(level)
	game.level = level
	body_rect(Vector2(0.0, 312.0), Vector2(2000.0, 24.0))
	player = Player.new()
	player.configure(game)
	game.add_child(player)
	player.set_physics_process(false)
	player.hide()
	await physics_frame
	reset_actor()
	await process_frame
	player._physics_process(STEP)
	check(not player.climbing and player.velocity.y > 0.0, "overlapping a ladder without vertical intent never auto-grabs")

	reset_actor()
	await process_frame
	level.kind = "chain"
	Input.action_press("climb_up")
	player._physics_process(STEP)
	check(player.climbing and player.climb_kind == "chain" and player.climb_id == "fixture_chain", "iron chain uses the same identified physical traversal contract")
	reset_actor(Vector2(8.0, 200.0))
	await process_frame
	Input.action_press("climb_up")
	await physics_frame
	var before: Vector2 = player.global_position
	player._physics_process(STEP)
	check(player.climbing and player.climb_kind == "ladder" and player.climb_id == "fixture_ladder", "up intent attaches to identified climb corridor")
	check(absf(player.global_position.x - before.x) <= 1.4 and player.global_position.x != 0.0, "alignment uses capped physical velocity instead of teleporting to center")
	check(player.velocity.y < 0.0 and player.get_climb_progress() > 0.0 and player.get_climb_progress() < 1.0 and player.animation_state == "climb", "climb exposes real motion state and normalized height")
	Input.action_release("climb_up")
	await process_frame
	before = player.global_position
	player._physics_process(STEP)
	var idle_frame: int = player.frame
	check(player.climbing and player.animation_state == "climb_idle" and is_equal_approx(player.global_position.y, before.y), "releasing vertical input holds the chain with gravity disabled")
	ticks(5)
	check(player.frame == idle_frame, "idle climb pose does not cycle while stationary")
	Input.action_press("climb_up")
	for index: int in range(5):
		await physics_frame
		player._physics_process(STEP)
	check(player.animation_state == "climb" and player.frame >= 0 and player.frame <= 3 and player.frame != idle_frame, "climb frames advance from actual rung travel")
	player.position = Vector2(0.0, 100.25)
	player._physics_process(STEP)
	check(not player.climbing and player.velocity.y > 0.0, "top endpoint releases into ordinary gravity for side walkout")

	await attach(Vector2(0.0, 299.75))
	player.position.y = 299.75
	Input.action_release("climb_up")
	Input.action_press("climb_down")
	player._physics_process(STEP)
	check(not player.climbing, "bottom endpoint exits reliably instead of hovering inside floor")
	await attach()
	Input.action_press("move_right")
	player._physics_process(STEP)
	check(not player.climbing and player.velocity.x > 0.0, "horizontal walk releases the grip into normal movement")

	await attach()
	Input.action_press("jump")
	player._physics_process(0.01)
	Input.action_release("jump")
	await process_frame
	check(not player.climbing and player.velocity.y < -300.0 and player._air_jumps == 1, "SPACE detaches into the existing full jump and retains air jump")
	ticks(20)
	check(not player.climbing and player._climb_release_required, "held up cannot immediately steal control back after jumping off")
	Input.action_release("climb_up")
	player._physics_process(0.01)
	player.position = Vector2(0.0, 200.0)
	Input.action_press("climb_up")
	player._physics_process(0.01)
	check(player.climbing, "release and renewed vertical intent allow a later deliberate regrab")

	await attach()
	Input.action_press("dash")
	player._physics_process(0.01)
	Input.action_release("dash")
	await process_frame
	check(not player.climbing and player.dash_timer > 0.0 and is_equal_approx(absf(player.velocity.x), Player.DASH_SPEED), "dash detaches and keeps original speed and duration authority")
	await attach()
	var serial: int = player.attack_serial
	Input.action_press("attack")
	player._physics_process(0.01)
	Input.action_release("attack")
	await process_frame
	check(not player.climbing and player.attack_serial == serial + 1 and player.attack_phase == "windup", "attack detaches before starting the unchanged three-stage controller")
	await attach()
	Input.action_press("parry")
	player._physics_process(0.01)
	Input.action_release("parry")
	await process_frame
	check(not player.climbing and player.parry_phase == "ready" and player.parry_timer > 0.15, "parry detaches before raising a genuine defense window")

	reset_actor()
	await process_frame
	player._start_attack()
	Input.action_press("climb_up")
	player._physics_process(0.01)
	check(not player.climbing and player.attack_phase == "windup", "climb cannot cancel a committed active combat sequence")
	await attach()
	player.set_impact_freeze(0.06)
	player.parry_timer = 0.04
	before = player.global_position
	var frozen_frame: int = player.frame
	Input.action_press("jump")
	player._physics_process(0.01)
	Input.action_release("jump")
	await process_frame
	ticks(3)
	check(player.climbing and player.global_position == before and player.frame == frozen_frame and player._jump_buffer > 0.0, "local hold preserves climb pose while collecting the jump edge")
	check(player.parry_timer == 0.0, "real parry time still expires during a frozen climb")
	ticks(6)
	check(not player.climbing and player.velocity.y < 0.0, "queued jump detaches as soon as local hold resumes")

	await attach()
	player.receive_hit(1, Vector2(-30.0, 200.0))
	check(not player.climbing and player.climb_id == "" and player._hurt_lock > 0.0 and player.velocity.x > 0.0, "accepted damage clears grip and retains normal hit knockback")
	await attach()
	player.receive_hit(99, Vector2(-30.0, 200.0))
	check(player.dead and not player.climbing and player.climb_kind == "", "death clears traversal immediately")
	player.revive(Vector2(240.0, 300.0))
	check(not player.climbing and not player.in_shallow_water and player._climb_regrab_cooldown == 0.0, "revive clears traversal identity, water and regrab timers")
	await attach()
	player.set_impact_freeze(0.08)
	game.story_safe = true
	player._physics_process(0.01)
	check(not player.climbing and player.combat_freeze == 0.0 and not player.in_shallow_water, "rest preempts grip and local hold without stale traversal state")
	game.story_safe = false
	ticks(20)
	check(not player.climbing, "leaving rest does not resurrect a held old climb intent")
	await attach()
	level.enabled = false
	player._physics_process(0.01)
	check(not player.climbing and player.velocity.y > 0.0, "removed climb corridor restores gravity instead of leaving a hanging player")

	reset_actor()
	await process_frame
	level.malformed = true
	Input.action_press("climb_up")
	player._physics_process(STEP)
	check(not player.climbing and player.velocity.y > 0.0, "malformed traversal data safely falls back to ordinary movement")
	var legacy: LegacyGame = LegacyGame.new()
	root.add_child(legacy)
	player.configure(legacy)
	player._physics_process(STEP)
	check(not player.climbing and not player.in_shallow_water, "old game mock without level or new interfaces stays compatible")
	player.configure(game)
	legacy.free()

	await attach()
	var ceiling: StaticBody2D = body_rect(Vector2(0.0, 164.0), Vector2(80.0, 8.0))
	for index: int in range(10):
		await physics_frame
		player._physics_process(STEP)
	check(not player.climbing and player.global_position.y >= 193.8, "sealed ceiling blocks upward travel and releases an obstructed grip")
	ceiling.free()

	reset_actor(Vector2(240.0, 300.0))
	await process_frame
	level.wet = true
	player._physics_process(STEP)
	Input.action_press("move_right")
	for index: int in range(12):
		await physics_frame
		player._physics_process(STEP)
	check(player.in_shallow_water and is_equal_approx(player.velocity.x, Player.RUN_SPEED * 0.72), "grounded shallow-water run speed is exactly 72 percent of base")
	check(splash_count() >= 1 and splash_count() <= 3, "water feedback is bounded by the entry event and stride cooldown")
	level.wet = false
	ticks(4)
	check(not player.in_shallow_water and is_equal_approx(player.velocity.x, Player.RUN_SPEED), "dry ground restores base target speed without accumulating multipliers")

	reset_actor(Vector2(240.0, 300.0))
	await process_frame
	level.wet = true
	ticks(30)
	check(splash_count() == 1, "standing still in water emits one entry splash rather than a particle loop")
	await process_frame
	Input.action_press("jump")
	player._physics_process(0.01)
	Input.action_release("jump")
	await process_frame
	check(is_equal_approx(player.velocity.y, Player.JUMP_SPEED), "shallow water does not change jump launch velocity")
	reset_actor(Vector2(240.0, 300.0))
	await process_frame
	level.wet = true
	player._physics_process(STEP)
	Input.action_press("dash")
	player._physics_process(0.01)
	Input.action_release("dash")
	await process_frame
	check(is_equal_approx(absf(player.velocity.x), Player.DASH_SPEED) and is_equal_approx(player.dash_timer, 0.15), "shallow water does not slow dash or change its action clock")
	player.reset_traversal()
	check(not player.in_shallow_water and not player.climbing and player._water_splash_cooldown == 0.0, "explicit map-reset helper clears all traversal feedback state")
	check(is_equal_approx(Engine.time_scale, 1.0) and not paused, "traversal never changes global music or simulation clocks")
	for action: String in ["move_left", "move_right", "attack", "dash", "parry", "jump", "climb_up", "climb_down"]:
		Input.action_release(action)
	game.free()
	print("Traversal: %d passed, %d failed" % [passed, failed])
	quit(1 if failed > 0 else 0)

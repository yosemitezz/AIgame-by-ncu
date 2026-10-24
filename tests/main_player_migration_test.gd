extends SceneTree
## Bounded controller fixtures, not a level playthrough. Preserve the main hero while adding traversal and geometry.
const Player = preload("res://actors/player.gd")
const Profile = preload("res://combat/attack_profile.gd")
const Query = preload("res://combat/melee_query.gd")
var passed: int = 0
var failed: int = 0
var arena: FixtureGame
var player: CharacterBody2D
var level: FixtureLevel

class FixtureLevel extends Node:
	var chain: bool = false
	var wet: bool = false
	var rect: Rect2 = Rect2(-12.0, 100.0, 24.0, 200.0)
	func climb_at(feet: Vector2) -> Dictionary:
		if chain and feet.x >= rect.position.x and feet.x <= rect.end.x and feet.y >= rect.position.y and feet.y <= rect.end.y:
			return {"rect": rect, "kind": "chain", "id": "fixture_chain"}
		return {}
	func water_at(_feet: Vector2) -> bool:
		return wet

class FixtureGame extends Node2D:
	signal animation_event(actor: Node, state: String, frame: int, facing: int)
	var story_safe: bool = false
	var _paused: bool = false
	var level: Node
	var pulses: Array[Dictionary] = []
	var effects: Dictionary = {}
	var hold_next: bool = false
	var contacts: int = 0
	func hero_attack(source: Node2D, damage: int, reach: float, combo: int) -> void:
		pulses.append({"from": source.attack_sweep_from, "to": source.attack_sweep_to, "combo": combo, "reach": reach, "damage": damage, "time": source._attack_elapsed})
		if hold_next:
			hold_next = false
			source.set_impact_freeze(0.08)
	func emit_fx(kind: String, _at: Vector2, _direction: Vector2, _power: float) -> void:
		effects[kind] = int(effects.get(kind, 0)) + 1
	func on_parry_contact(_defender: Node, _source: Node, _at: Vector2, _kind: String) -> void:
		contacts += 1

func check(ok: bool, label: String) -> void:
	if ok:
		passed += 1
		print("PASS ", label)
	else:
		failed += 1
		push_error("FAIL " + label + " [pos=%s v=%s phase=%s parry=%s climb=%s release=%s air=%s anim=%s auto=%s splashes=%s]" % [player.global_position, player.velocity, player.attack_phase, player.parry_phase, player.climbing, player._climb_release_required, player._air_jumps, player.animation_state, player.is_physics_processing(), arena.effects.get("water_splash", 0)])

func release_all() -> void:
	for action: String in ["move_left", "move_right", "jump", "attack", "dash", "parry", "crouch", "climb_up", "climb_down"]:
		Input.action_release(action)

func reset(at: Vector2 = Vector2(0.0, 300.0)) -> void:
	release_all()
	arena.story_safe = false
	arena._paused = false
	arena.level = level
	level.chain = false
	level.wet = false
	arena.effects.clear()
	arena.pulses.clear()
	arena.hold_next = false
	player.revive(at)
	player.invuln = 0.0
	player.facing = 1

func tick(count: int = 1) -> void:
	for index: int in range(count):
		await physics_frame
		player._physics_process(1.0 / 60.0)

func marker(at: Vector2) -> Node2D:
	var target: Node2D = Node2D.new()
	target.position = at
	target.set_meta("melee_hurt_rect", Rect2(-1.0, -1.0, 2.0, 2.0))
	arena.add_child(target)
	return target

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	for action: String in ["move_left", "move_right", "jump", "attack", "dash", "parry", "crouch", "climb_up", "climb_down"]:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
	arena = FixtureGame.new()
	root.add_child(arena)
	level = FixtureLevel.new()
	arena.add_child(level)
	arena.level = level
	var floor_body: StaticBody2D = StaticBody2D.new()
	var floor_shape: CollisionShape2D = CollisionShape2D.new()
	var rectangle: RectangleShape2D = RectangleShape2D.new()
	rectangle.size = Vector2(1000.0, 24.0)
	floor_shape.shape = rectangle
	floor_shape.position = Vector2(0.0, 312.0)
	floor_body.add_child(floor_shape)
	arena.add_child(floor_body)
	player = Player.new()
	player.configure(arena)
	player.set_physics_process(false)
	arena.add_child(player)
	player.set_physics_process(false)
	reset()
	await tick(3)
	check(Player.INFINITE_AIR_JUMPS and is_instance_valid(player.wings), "main infinite air jumps and LightWings survive migration")
	check(player.get_child(0).shape.size == Vector2(14.0, 26.0), "existing hero collider retained")
	for combo: int in [1, 2, 3]:
		var expected: float = [0.31, 0.36, 0.66][combo - 1]
		check(absf(Profile.total_duration(combo) - expected) < 0.00001 and absf(Player.COMBO_LENGTHS[combo - 1] - expected) < 0.00001, "combo %d matches the light thrust/drill cadence" % combo)
		check(Player.LUNGE_SPEED[combo - 1] == [180.0, 280.0, 560.0][combo - 1] and is_equal_approx(Profile.lunge_seconds(combo), [0.075, 0.11, 0.32][combo - 1]), "combo %d uses its distinct point-led step/drill duration" % combo)
		check(Player.HIT_REACH[combo - 1] == [180.0, 204.0, 228.0][combo - 1], "combo %d shares wide reach" % combo)
	reset(Vector2(0.0, 150.0))
	# Let the preserved coyote window expire before asserting every press is airborne.
	await tick(10)
	var air_jumps_ok: bool = true
	for index: int in range(5):
		Input.action_press("jump")
		await tick()
		air_jumps_ok = air_jumps_ok and player.velocity.y < -300.0 and player.animation_state == "air_jump"
		Input.action_release("jump")
		await tick(2)
	check(air_jumps_ok and player._air_jumps == 0, "five actual air inputs still jump beyond finite counter")
	check(player.wing_amount > 0.0 and player.wing_flap > 0.0, "air jumps still open and flap light wings")
	reset()
	await tick(3)
	Input.action_press("climb_down")
	Input.action_press("move_right")
	await tick(10)
	check(player.crouching and player.animation_state == "crouch_walk", "S/Down remains crouch away from a chain")
	check(absf(player.velocity.x - Player.RUN_SPEED * Player.CROUCH_SPEED) < 0.1, "crouch walk keeps original speed")
	reset(Vector2(0.0, 270.0))
	await tick(2)
	player.velocity.y = 350.0
	for landing_tick: int in range(10):
		await tick()
		if player._land_timer > 0.0:
			break
	check(player._land_timer > 0.0 and player.animation_state == "land", "landing squat retained")
	reset()
	player.receive_hit(1, Vector2(-20.0, 300.0))
	var light: Vector2 = player.velocity
	player.invuln = 0.0
	player.receive_hit(3, Vector2(-20.0, 300.0))
	check(player.velocity.x > light.x and player.velocity.y < light.y and player.animation_state == "hurt", "current heavy hit reaction retained")
	reset(Vector2(0.0, 220.0))
	level.chain = true
	Input.action_press("climb_up")
	await tick(5)
	check(player.climbing and player.climb_id == "fixture_chain" and player.global_position.y < 217.0, "W grabs chain and climbs using physical motion")
	check(player.animation_state == "climb" and player.frame >= 0 and player.frame < 4, "climb publishes distance-driven frames")
	Input.action_release("climb_up")
	await tick(2)
	var held_y: float = player.global_position.y
	await tick(3)
	check(player.climbing and absf(player.global_position.y - held_y) < 0.05 and player.animation_state == "climb_idle", "neutral chain grip holds with idle pose")
	Input.action_press("jump")
	await tick()
	check(not player.climbing and player.velocity.y < -300.0, "Space immediately detaches and jumps")
	for action: String in ["dash", "attack", "parry"]:
		reset(Vector2(0.0, 220.0))
		level.chain = true
		Input.action_press("climb_up")
		await tick(2)
		Input.action_press(action)
		await tick()
		var authority: bool = player.dash_timer > 0.0 if action == "dash" else (player.attack_phase == "windup" if action == "attack" else player.parry_phase == "ready")
		check(not player.climbing and authority, "%s detaches through its existing action authority" % action)
	reset(Vector2(0.0, 101.0))
	level.chain = true
	Input.action_press("climb_up")
	await tick(4)
	check(not player.climbing and player._climb_release_required, "top endpoint releases grip and suppresses accidental regrab")
	reset(Vector2(0.0, 220.0))
	level.chain = true
	Input.action_press("climb_up")
	await tick(2)
	player.set_impact_freeze(0.08)
	player.parry_timer = 0.10
	var frozen_at: Vector2 = player.global_position
	Input.action_press("attack")
	await tick(2)
	check(player.queued_attack and player.combat_freeze > 0.0 and player.global_position.is_equal_approx(frozen_at), "local hold captures attack input without climbing movement")
	check(player.parry_timer < 0.08, "parry contact window keeps real delta during traversal hold")
	arena.story_safe = true
	await tick()
	check(not player.climbing and player.attack_phase == "none" and not player.queued_attack and player.combat_freeze == 0.0, "rest clears traversal and queued sweep ahead of hold")
	reset(Vector2(0.0, 220.0))
	level.chain = true
	Input.action_press("climb_up")
	await tick(2)
	player.receive_hit(1, Vector2(-30.0, 220.0))
	check(not player.climbing and player._hurt_lock > 0.0, "accepted hurt releases chain without swallowing knockback")
	player.revive(Vector2(0.0, 300.0))
	check(not player.climbing and player.climb_id.is_empty() and not player.in_shallow_water and not player._climb_release_required, "retry resets traversal identity and wet state")
	reset()
	await tick(3)
	level.wet = true
	Input.action_press("move_right")
	await tick(18)
	check(player.in_shallow_water and absf(player.velocity.x - Player.RUN_SPEED * 0.72) < 0.1, "shallow water changes only ground walk factor")
	var splashes: int = int(arena.effects.get("water_splash", 0))
	check(splashes >= 1 and splashes <= 3, "water splashes are rate limited")
	player._jump(false)
	check(is_equal_approx(player.velocity.y, Player.JUMP_SPEED), "water preserves jump impulse")
	check(player._start_dash(1.0), "water permits original dash input")
	await tick()
	check(is_equal_approx(player.velocity.x, Player.DASH_SPEED) and is_zero_approx(player.velocity.y), "water preserves dash speed and direction")
	reset(Vector2(0.0, 200.0))
	arena.level = null
	Input.action_press("climb_up")
	await tick(2)
	check(not player.climbing and player.velocity.y > 0.0, "old mocks without level degrade to ordinary gravity")
	# Actual controller intervals cover the complete sweep, including a coarse physics step.
	for combo: int in [1, 2, 3]:
		reset(Vector2.ZERO)
		player.combo = combo - 1
		player._combo_grace = 1.0
		player._start_attack()
		for index: int in range(8):
			player._advance_attack(0.11)
		var continuous: bool = not arena.pulses.is_empty()
		var last: float = Profile.contact_start()
		for pulse: Dictionary in arena.pulses:
			continuous = continuous and absf(float(pulse["from"]) - last) < 0.00001 and float(pulse["to"]) >= last
			last = float(pulse["to"])
		var first: Dictionary = arena.pulses[0] if not arena.pulses.is_empty() else {}
		check(continuous and is_equal_approx(last, 1.0), "combo %d coarse step has no swept gap or dropped final edge" % combo)
		check(not first.is_empty() and absf(float(first["time"]) - (Player.COMBO_WINDUP[combo - 1] + Player.COMBO_ACTIVE[combo - 1] * 0.25)) < 0.00001, "combo %d first contact keeps raised quarter harmless" % combo)
	reset(Vector2.ZERO)
	arena.hold_next = true
	player._start_attack()
	player._advance_attack(0.20)
	var pulse_count: int = arena.pulses.size()
	var hold_progress: float = player.get_attack_progress()
	await tick(2)
	check(pulse_count == 1 and arena.pulses.size() == pulse_count and is_equal_approx(player.get_attack_progress(), hold_progress), "impact holds actual first-contact pose without predictive future query")
	reset(Vector2.ZERO)
	player.attack_phase = "active"
	player.combo = 1
	player.attack_sweep_from = 0.25
	player.attack_sweep_to = 1.0
	var near: Node2D = marker(Vector2(178.0, -24.0))
	var far: Node2D = marker(Vector2(183.0, -24.0))
	var behind: Node2D = marker(Vector2(-1.0, -24.0))
	var outside_ellipse: Node2D = marker(Vector2(170.0, 40.0))
	var hits: Array[Node2D] = Query.collect(player, [near, far, behind, outside_ellipse, near], -1.0, -1.0, 0)
	check(hits.size() == 1 and hits.has(near), "narrow thrust honors front boundary/behind/height and deduplicates candidate list")
	var elevated: Node2D = marker(Vector2(40.0, -48.0))
	check(Query.collect(player, [elevated], 0.25, 1.0, 0).is_empty(), "light thrust cannot damage an elevated target outside the visible corridor")
	# The heavy cleave retains an elevated arc and a swept intermediate angle.
	player._cancel_attack()
	player.set_weapon("heavy")
	player.attack_phase = "active"
	player.combo = 1
	player.attack_sweep_from = 0.25
	player.attack_sweep_to = 1.0
	check(Query.collect(player, [elevated], 0.25, 1.0, 0).has(elevated), "heavy cleave reaches the elevated target the narrow thrust cannot")
	var sweep: PackedVector2Array = Profile.sweep_polygon(1, 0.25, 1.0)
	var between: Vector2 = Profile.origin() + Vector2(cos(deg_to_rad(20.0)) * 160.0, sin(deg_to_rad(20.0)) * 64.0)
	check(Geometry2D.is_point_in_polygon(between, sweep) and not Geometry2D.is_point_in_polygon(between, Profile.sweep_polygon(1, 0.25, 0.25)) and not Geometry2D.is_point_in_polygon(between, Profile.sweep_polygon(1, 1.0, 1.0)), "sweep covers an intermediate angle missed by both endpoints")
	var wall: StaticBody2D = StaticBody2D.new()
	var wall_shape: CollisionShape2D = CollisionShape2D.new()
	var wall_rect: RectangleShape2D = RectangleShape2D.new()
	wall_rect.size = Vector2(12.0, 160.0)
	wall_shape.shape = wall_rect
	wall.position = Vector2(80.0, -24.0)
	wall.add_child(wall_shape)
	arena.add_child(wall)
	await physics_frame
	near.position.x = 164.0
	check(Query.collect(player, [near]).is_empty(), "world-mask one blocks otherwise valid heavy hit through wall")
	wall.free()
	await physics_frame
	check(Query.collect(player, [near]).has(near), "removing occluder restores the heavy geometry candidate")
	player.attack_phase = "recover"
	check(Query.collect(player, [near], 0.25, 1.0, 0).is_empty(), "recover cannot create a second damage query")
	check(is_equal_approx(Engine.time_scale, 1.0), "migration never changes global time scale")
	release_all()
	arena.free()
	print("MAIN_PLAYER_MIGRATION_TEST: %d passed, %d failed" % [passed, failed])
	quit(1 if failed > 0 else 0)

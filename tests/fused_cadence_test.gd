extends SceneTree
## Actual controller cadence/contacts in a static fixture, never a playthrough.

const Player = preload("res://actors/player.gd")
const EXPECTED_TOTALS: Array[float] = [0.270, 0.290, 0.370]
const EXPECTED_CONTACTS: Array[float] = [0.06875, 0.08125, 0.10625]
const FIXED_STEP: float = 1.0 / 60.0
var passed: int = 0
var failed: int = 0
var arena: CadenceArena
var player: CharacterBody2D

class CadenceArena extends Node2D:
	signal animation_event(actor: Node, state: String, frame: int, facing: int)
	var story_safe: bool = false
	var _paused: bool = false
	var strikes: Array[Dictionary] = []
	func hero_attack(source: Node2D, damage: int, reach: float, combo: int) -> void:
		strikes.append({"serial": source.attack_serial, "combo": combo, "damage": damage, "reach": reach, "phase": source.attack_phase, "state": source.animation_state, "frame": source.frame, "progress": source.get_attack_progress(), "actor_time": source._attack_elapsed, "facing": source.facing})
	func emit_fx(_kind: String, _at: Vector2, _direction: Vector2, _power: float) -> void:
		pass

func check(value: bool, label: String) -> void:
	if value:
		passed += 1
		print("PASS ", label)
	else:
		failed += 1
		push_error("FAIL " + label)

func reset_actor() -> void:
	arena.story_safe = false
	player.revive(Vector2(0.0, 300.0))
	player.invuln = 0.0
	player.facing = 1
	arena.strikes.clear()
	for action: String in ["move_left", "move_right", "attack", "dash", "parry", "jump"]:
		Input.action_release(action)

func ticks(count: int, delta: float = 0.005) -> void:
	for index: int in range(count):
		player._physics_process(delta)

func advance_until(stage: String, maximum: int = 130) -> bool:
	for index: int in range(maximum):
		if player.attack_phase == stage:
			return true
		player._physics_process(0.005)
	return player.attack_phase == stage

func start_slot(slot: int) -> void:
	reset_actor()
	player.combo = slot - 1
	player._combo_grace = 0.22 if slot > 1 else 0.0
	player._start_attack()

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	for action: String in ["move_left", "move_right", "attack", "dash", "parry", "jump"]:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
	arena = CadenceArena.new()
	root.add_child(arena)
	var floor_body: StaticBody2D = StaticBody2D.new()
	var floor_collider: CollisionShape2D = CollisionShape2D.new()
	var floor_shape: RectangleShape2D = RectangleShape2D.new()
	floor_shape.size = Vector2(8000.0, 24.0)
	floor_collider.shape = floor_shape
	floor_collider.position = Vector2(0.0, 312.0)
	floor_body.add_child(floor_collider)
	arena.add_child(floor_body)
	player = Player.new()
	player.configure(arena)
	arena.add_child(player)
	player.set_physics_process(false)
	player.hide()
	await physics_frame
	reset_actor()
	await process_frame

	var total_action_time: float = 0.0
	var last_serial: int = player.attack_serial
	for slot: int in range(1, 4):
		# Use normal completed-combo grace to select the next slot, not frame mocks.
		player._start_attack()
		var serial: int = player.attack_serial
		var simulated: float = 0.0
		var seen: Dictionary = {"windup": true}
		var mapped: bool = player.animation_state == "windup" and player.frame == 0
		for index: int in range(40):
			if player.attack_phase == "none":
				break
			player._physics_process(FIXED_STEP)
			simulated += FIXED_STEP
			seen[player.attack_phase] = true
			if player.attack_phase != "none":
				var expected_state: String = "attack" if player.attack_phase == "active" else player.attack_phase
				mapped = mapped and player.animation_state == expected_state and player.frame >= 0 and player.frame <= 3
		check(player.combo == slot and serial == last_serial + 1, "cut %d retains combo selection and one new serial" % slot)
		check(player.attack_phase == "none" and absf(player._attack_elapsed - EXPECTED_TOTALS[slot - 1]) < 0.000001 and simulated >= EXPECTED_TOTALS[slot - 1] - 0.000001 and simulated <= EXPECTED_TOTALS[slot - 1] + FIXED_STEP, "cut %d completes at requested cadence within one 60Hz tick" % slot)
		check(mapped and seen.has("windup") and seen.has("active") and seen.has("recover"), "cut %d keeps actual three-stage poses and frame bounds" % slot)
		var contacts: Array[Dictionary] = []
		for strike: Dictionary in arena.strikes:
			if strike.serial == serial:
				contacts.append(strike)
		var valid_contacts: bool = contacts.size() >= 3
		for strike: Dictionary in contacts:
			valid_contacts = valid_contacts and strike.phase == "active" and strike.state == "attack" and int(strike.frame) >= 1 and float(strike.progress) >= 0.25 - 0.000001 and strike.damage == (2 if slot == 3 else 1)
		check(valid_contacts, "cut %d retains repeated genuine blade contacts after active pose zero" % slot)
		check(not contacts.is_empty() and absf(float(contacts[0].actor_time) - EXPECTED_CONTACTS[slot - 1]) < 0.000001, "cut %d first contact matches its shorter windup plus quarter-active pose" % slot)
		total_action_time += player._attack_elapsed
		last_serial = serial
	check(is_equal_approx(total_action_time, 0.93), "three cuts total 0.93 action seconds before optional impact holds")

	for slot: int in range(1, 4):
		start_slot(slot)
		check(not player._start_dash(-1.0), "cut %d still commits its shorter windup" % slot)
		for index: int in range(90):
			player._physics_process(0.005)
			if not arena.strikes.is_empty():
				break
		check(player.attack_phase == "active" and not player._start_dash(-1.0), "cut %d active whiff cannot be freely dodged out" % slot)
		player.confirm_attack_hit()
		check(not player.can_cancel_attack(), "cut %d first blade contact still precedes confirmed-cancel release" % slot)
		for index: int in range(30):
			if player.can_cancel_attack():
				break
			player._physics_process(0.005)
		check(player.attack_phase == "active" and player._start_dash(-1.0), "cut %d shorter active stage still has a usable confirmed-hit cancel" % slot)
		start_slot(slot)
		advance_until("recover")
		check(not player._start_dash(-1.0), "cut %d whiff keeps early recovery commitment" % slot)
		for index: int in range(30):
			if player.can_cancel_attack():
				break
			player._physics_process(0.005)
		check(player.attack_phase == "recover" and player._start_dash(-1.0), "cut %d whiff releases dash within its shorter recovery" % slot)

	reset_actor()
	await process_frame
	Input.action_press("move_right")
	player._physics_process(0.0)
	player._start_attack()
	var first_serial: int = player.attack_serial
	Input.action_release("move_right")
	Input.action_press("move_left")
	Input.action_press("attack")
	player._physics_process(0.005)
	Input.action_release("attack")
	await process_frame
	player.set_impact_freeze(0.04)
	var held_elapsed: float = player._attack_elapsed
	ticks(6)
	check(player.queued_attack and player.facing == 1 and player._attack_elapsed == held_elapsed, "short windup retains early next-cut intent and direction through local hold")
	for index: int in range(100):
		player._physics_process(0.005)
		if player.attack_serial > first_serial:
			break
	check(player.combo == 2 and player.attack_serial == first_serial + 1 and player.facing == -1, "faster queued second cut adopts new direction only on its own start")
	var retained_facing: bool = true
	for strike: Dictionary in arena.strikes:
		if strike.serial == first_serial:
			retained_facing = retained_facing and strike.facing == 1
	check(retained_facing, "shortened first cut never changes its active contact direction")
	Input.action_release("move_left")
	ticks(100)
	check(player.attack_serial == first_serial + 1 and player.attack_phase == "none", "one queued tap still cannot create an unattended third cut")

	reset_actor()
	await process_frame
	player._start_attack()
	advance_until("active")
	for index: int in range(30):
		if player.attack_phase != "active" or player.get_attack_progress() >= 0.8:
			break
		player._physics_process(0.005)
	Input.action_press("dash")
	player._physics_process(0.005)
	Input.action_release("dash")
	await process_frame
	check(player.attack_phase == "active" and player.dash_timer == 0.0, "late active dash input queues without bypassing whiff commitment")
	for index: int in range(40):
		player._physics_process(0.005)
		if player.dash_timer > 0.0:
			break
	check(player.dash_timer > 0.0 and player.attack_phase == "none", "short dash buffer reaches the legal early-recovery release")

	reset_actor()
	await process_frame
	player._start_attack()
	advance_until("active")
	player.queued_attack = true
	player.set_impact_freeze(0.08)
	arena.story_safe = true
	var contacts_before: int = arena.strikes.size()
	player._physics_process(0.005)
	arena.story_safe = false
	ticks(100)
	check(player.attack_phase == "none" and not player.queued_attack and player.combat_freeze == 0.0 and arena.strikes.size() == contacts_before, "rest still cancels shortened active attack, buffered follow-up and hold")
	check(is_equal_approx(Engine.time_scale, 1.0) and not paused, "cadence change never modifies global time")
	for action: String in ["move_left", "move_right", "attack", "dash", "parry", "jump"]:
		Input.action_release(action)
	arena.free()
	print("Fused cadence: %d passed, %d failed" % [passed, failed])
	quit(1 if failed > 0 else 0)

extends SceneTree
## Bounded controller/response checks; this never drives a level playthrough.

const Player = preload("res://actors/player.gd")
const Enemy = preload("res://actors/enemy.gd")
var passed: int = 0
var failed: int = 0
var arena: TestArena
var player: CharacterBody2D

class TestArena extends Node2D:
	signal animation_event(actor: Node, state: String, frame: int, facing: int)
	signal warning_issued(kind: String, at: Vector2, duration: float)
	var story_safe: bool = false
	var player: CharacterBody2D
	var boss: Node2D
	var strikes: Array[Dictionary] = []
	var animations: Array[Dictionary] = []
	var defeated: int = 0
	func _ready() -> void:
		animation_event.connect(func(actor: Node, state: String, pose: int, direction: int) -> void:
			animations.append({"actor": actor.get_instance_id(), "state": state, "frame": pose, "facing": direction}))
	func hero_attack(source: Node2D, damage: int, reach: float, combo: int) -> void:
		strikes.append({"phase": source.attack_phase, "serial": source.attack_serial, "facing": source.facing, "combo": combo, "damage": damage, "reach": reach, "frame": source.frame})
	func emit_fx(_kind: String, _at: Vector2, _direction: Vector2, _power: float) -> void:
		pass
	func damage_player(amount: int, origin: Vector2) -> void:
		player.receive_hit(amount, origin)
	func spawn_projectile(_at: Vector2, _velocity: Vector2, _friendly: bool = false) -> Node2D:
		return null
	func on_enemy_defeated(_enemy: Node2D) -> void:
		defeated += 1

class ImpactArena extends TestArena:
	var impact_calls: int = 0
	var last_source: Node
	var last_target: Node
	var last_parry: bool = false
	func request_impact(source: Node, target: Node, _heavy: bool = false, parry: bool = false) -> void:
		impact_calls += 1
		last_source = source
		last_target = target
		last_parry = parry

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

func ticks(count: int, dt: float = 0.01) -> void:
	for index: int in range(count):
		player._physics_process(dt)

func to_phase(stage: String, maximum: int = 90) -> bool:
	for index: int in range(maximum):
		if player.attack_phase == stage:
			return true
		player._physics_process(0.01)
	return player.attack_phase == stage

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	for action: String in ["move_left", "move_right", "attack", "dash", "parry", "jump"]:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
	arena = TestArena.new()
	root.add_child(arena)
	var floor_body: StaticBody2D = StaticBody2D.new()
	var floor_shape: CollisionShape2D = CollisionShape2D.new()
	var rectangle: RectangleShape2D = RectangleShape2D.new()
	rectangle.size = Vector2(8000.0, 24.0)
	floor_shape.shape = rectangle
	floor_shape.position = Vector2(0.0, 312.0)
	floor_body.add_child(floor_shape)
	arena.add_child(floor_body)
	player = Player.new()
	player.configure(arena)
	player.set_physics_process(false)
	arena.player = player
	arena.add_child(player)
	await physics_frame
	reset_actor()
	await process_frame
	ticks(2)
	check(player.is_on_floor(), "test fixture settles on real 2D floor")
	player._start_attack()
	var first_serial: int = player.attack_serial
	check(player.attack_phase == "windup" and player.animation_state == "windup" and player.frame == 0, "attack begins in its actual windup pose")
	player._physics_process(Player.COMBO_WINDUP[0] * 0.8)
	check(player.attack_phase == "windup" and arena.strikes.is_empty(), "windup has no damaging query")
	check(to_phase("active"), "windup advances to active in bounded time")
	check(arena.strikes.is_empty() and player.frame == 0, "raised active pose precedes the first blade contact")
	var first_active_count: int = arena.strikes.size()
	ticks(6)
	check(arena.strikes.size() >= first_active_count + 3, "active window queries contacts on successive physics ticks")
	var active_only: bool = true
	for strike: Dictionary in arena.strikes:
		active_only = active_only and strike.phase == "active" and strike.serial == first_serial and int(strike.frame) >= 1
	check(active_only, "every damaging pulse carries active phase and same swing serial")
	check(to_phase("recover") and player.animation_state == "recover", "damage window ends in distinct recovery pose")
	var count_at_recovery: int = arena.strikes.size()
	ticks(5)
	check(arena.strikes.size() == count_at_recovery, "recovery performs no damage queries")
	check(to_phase("none") and player.attack_timer == 0.0, "completed swing clears attack state")

	reset_actor()
	await process_frame
	player._start_attack()
	first_serial = player.attack_serial
	Input.action_press("attack")
	player._physics_process(0.01)
	Input.action_release("attack")
	await process_frame
	check(player.queued_attack, "early windup tap queues one next-swing intent")
	player.set_impact_freeze(0.09)
	var held_phase: String = player.attack_phase
	var held_elapsed: float = player._phase_elapsed
	var held_at: Vector2 = player.global_position
	ticks(6)
	check(player.queued_attack and player.attack_phase == held_phase and is_equal_approx(player._phase_elapsed, held_elapsed), "early combo intent and stage survive local hit-stop")
	check(player.global_position == held_at, "local hit-stop holds actor position")
	check(player.get_attack_progress() > 0.0 and player.get_attack_progress() < 1.0, "presentation progress reports the held combat stage")
	for index: int in range(100):
		player._physics_process(0.01)
		if player.attack_serial > first_serial:
			break
	check(player.attack_serial == first_serial + 1 and player.combo == 2, "early intent chains after full first swing instead of expiring")
	ticks(100)
	check(player.attack_serial == first_serial + 1 and player.attack_phase == "none", "one stored tap cannot create an unattended third swing")

	reset_actor()
	await process_frame
	Input.action_press("move_right")
	player._physics_process(0.0)
	player._start_attack()
	Input.action_release("move_right")
	Input.action_press("move_left")
	player._physics_process(0.02)
	check(player.facing == 1, "opposite movement cannot turn a committed windup")
	Input.action_press("attack")
	player._physics_process(0.01)
	Input.action_release("attack")
	await process_frame
	first_serial = player.attack_serial
	for index: int in range(80):
		player._physics_process(0.01)
		if player.attack_serial > first_serial:
			break
	check(player.combo == 2 and player.facing == -1, "next combo swing may adopt newly held direction")
	var committed: bool = true
	for strike: Dictionary in arena.strikes:
		if strike.serial == first_serial:
			committed = committed and strike.facing == 1
	check(committed, "all first-swing active queries retain its original direction")
	Input.action_release("move_left")

	reset_actor()
	await process_frame
	player._start_attack()
	check(not player._start_dash(-1.0), "windup cannot be cancelled into a free dodge")
	to_phase("active")
	check(not player._start_dash(-1.0), "unconfirmed active swing cannot be dash-cancelled")
	player.confirm_attack_hit()
	check(not player.can_cancel_attack(), "hit confirmation still preserves earliest active impact frames")
	ticks(6)
	check(player._start_dash(-1.0) and player.attack_phase == "none" and player.dash_timer > 0.0, "confirmed hit opens controlled active dash cancel")
	reset_actor()
	player._start_attack()
	to_phase("recover")
	check(not player._start_dash(-1.0), "whiff preserves the first recovery frames")
	ticks(6)
	check(player._start_dash(-1.0), "whiff permits dash after early recovery commitment")

	reset_actor()
	await process_frame
	player._start_attack()
	ticks(2)
	player.parry_timer = 0.05
	player.set_impact_freeze(0.10)
	held_elapsed = player._phase_elapsed
	held_at = player.global_position
	var held_velocity: Vector2 = player.velocity
	Input.action_press("attack")
	player._physics_process(0.01)
	Input.action_release("attack")
	await process_frame
	ticks(5)
	check(player.queued_attack, "attack edge is collected before frozen early return")
	check(player.parry_timer == 0.0, "parry contact window expires on real delta during freeze")
	check(player._phase_elapsed == held_elapsed and player.global_position == held_at and player.velocity == held_velocity, "impact freeze holds simulation and pose without erasing motion")
	check(is_equal_approx(Engine.time_scale, 1.0) and not paused, "impact freeze does not alter global music/projectile clock")
	player.combat_freeze = 0.0
	player.revive(Vector2(0.0, 300.0))
	player.set_impact_freeze(0.06)
	Input.action_press("dash")
	player._physics_process(0.01)
	Input.action_release("dash")
	await process_frame
	ticks(9)
	check(player.dash_timer > 0.0, "dash edge received in impact freeze survives until actor resumes")

	reset_actor()
	await process_frame
	player._start_attack()
	player.queued_attack = true
	player.parry_timer = 0.1
	player.dash_timer = 0.1
	player.set_impact_freeze(0.1)
	arena.story_safe = true
	var strikes_before_rest: int = arena.strikes.size()
	player._physics_process(0.01)
	check(player.attack_phase == "none" and not player.queued_attack and player.combat_freeze == 0.0 and player.parry_timer == 0.0 and player.dash_timer == 0.0, "rest preempts frozen attack, queue, parry and dash")
	var hp: int = player.health
	check(not player.receive_hit(2, Vector2.ZERO) and player.health == hp, "rest blocks incoming damage immediately")
	player._start_attack()
	check(player.attack_phase == "none" and not player.queued_attack, "direct start cannot arm a queued attack in rest")
	arena.story_safe = false
	ticks(70)
	check(arena.strikes.size() == strikes_before_rest and player.attack_phase == "none", "leaving rest cannot resurrect an old queued swing")

	reset_actor()
	await process_frame
	player.parry_timer = 0.07
	player.parry_success()
	check(is_equal_approx(player.parry_timer, 0.07), "legacy game without impact method still accepts default parry call")
	var feedback: ImpactArena = ImpactArena.new()
	root.add_child(feedback)
	var attacker: Node = Node.new()
	feedback.add_child(attacker)
	player.configure(feedback)
	player.parry_success(attacker)
	check(feedback.impact_calls == 1 and feedback.last_source == player and feedback.last_target == attacker and feedback.last_parry, "targeted parry dispatches exactly one impact with its attacker")
	player.parry_success()
	check(feedback.impact_calls == 2 and feedback.last_target == null, "default parry remains one dispatch with optional null target")
	player.configure(arena)
	feedback.free()
	reset_actor()
	player.receive_hit(1, Vector2(-30.0, 300.0))
	check(player.impact_flash > 0.10, "player hit publishes short impact flash")
	player.set_impact_freeze(0.06)
	ticks(2)
	check(player.impact_flash < 0.10 and player.impact_flash > 0.0 and player.combat_freeze > 0.0, "player impact flash expires on real delta during local hold")
	reset_actor()
	check(player.impact_flash == 0.0, "revive clears pending impact flash")
	var light: CharacterBody2D = Enemy.new()
	light.configure(arena, "sentry", Vector2(180.0, 300.0))
	light.set_physics_process(false)
	arena.add_child(light)
	var heavy: CharacterBody2D = Enemy.new()
	heavy.configure(arena, "sentry", Vector2(240.0, 300.0))
	heavy.set_physics_process(false)
	arena.add_child(heavy)
	await physics_frame
	light.receive_hit(1, Vector2(130.0, 300.0))
	heavy.receive_hit(2, Vector2(190.0, 300.0))
	check(light.animation_state == "hurt" and light.hurt_flash > 0.0 and light.frame == 0, "enemy hit immediately publishes distinct hurt pose and flash")
	check(absf(heavy.velocity.x) > absf(light.velocity.x) and heavy._stagger > light._stagger, "heavy strike has stronger push and longer stagger than light strike")
	var enemy_position: Vector2 = light.global_position
	var enemy_velocity: Vector2 = light.velocity
	var enemy_stagger: float = light._stagger
	light.set_impact_freeze(0.06)
	light._physics_process(0.02)
	check(light.global_position == enemy_position and light.velocity == enemy_velocity and light._stagger == enemy_stagger, "enemy impact hold preserves push and stagger for release")
	light.combat_freeze = 0.0
	light._physics_process(0.016)
	check(light.animation_state == "hurt" and light.velocity.x > 100.0, "enemy steering cannot immediately overwrite hit knockback")
	light._windup = 0.3
	light._recovery = 0.2
	light.set_impact_freeze(0.1)
	arena.story_safe = true
	light._physics_process(0.01)
	hp = light.health
	light.receive_hit(99, Vector2.ZERO)
	check(light.combat_freeze == 0.0 and light._windup == 0.0 and light._recovery == 0.0 and light.health == hp, "enemy rest cancels frozen old attacks and blocks damage")
	arena.story_safe = false
	light._hurt_flash = 0.0
	light.receive_hit(99, Vector2.ZERO)
	var death_events_before: int = arena.animations.size()
	light._physics_process(0.12)
	check(light.animation_state == "dead" and light.frame == 1 and arena.animations.size() > death_events_before, "enemy death animation continues publishing frame changes")
	for action: String in ["move_left", "move_right", "attack", "dash", "parry", "jump"]:
		Input.action_release(action)
	arena.free()
	print("Combat feel: %d passed, %d failed" % [passed, failed])
	quit(1 if failed > 0 else 0)

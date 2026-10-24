extends SceneTree
## Bounded genuine-contact controller tests; no level input playback.

const Player = preload("res://actors/player.gd")
const Enemy = preload("res://actors/enemy.gd")
var passed: int = 0
var failed: int = 0
var game: ParryGame
var player: CharacterBody2D
var source_a: Node2D
var source_b: Node2D

class ParryGame extends Node2D:
	signal animation_event(actor: Node, state: String, frame: int, facing: int)
	signal warning_issued(kind: String, at: Vector2, duration: float)
	var player: CharacterBody2D
	var boss: Node2D
	var story_safe: bool = false
	var _paused: bool = false
	var freeze_on_contact: bool = false
	var contacts: Array[Dictionary] = []
	var animations: Array[String] = []
	var effects: Array[String] = []
	var fallback_impacts: int = 0
	var parry_signals: int = 0
	var damage_calls: int = 0
	func _ready() -> void:
		animation_event.connect(func(_actor: Node, state: String, _frame: int, _facing: int) -> void: animations.append(state))
	func on_parry_contact(defender: Node, source: Node, at: Vector2, kind: String) -> void:
		contacts.append({"defender": defender, "source": source, "at": at, "kind": kind})
		if freeze_on_contact:
			defender.set_impact_freeze(0.06)
	func request_impact(_source: Node, _target: Node, _heavy: bool = false, _parry: bool = false) -> void:
		fallback_impacts += 1
	func emit_fx(kind: String, _at: Vector2, _direction: Vector2, _power: float) -> void:
		effects.append(kind)
	func hero_attack(_source: Node2D, _damage: int, _reach: float, _combo: int) -> void:
		pass
	func damage_player(amount: int, origin: Vector2) -> void:
		damage_calls += 1
		player.receive_hit(amount, origin)
	func spawn_projectile(_at: Vector2, _velocity: Vector2, _friendly: bool = false) -> Node2D:
		return null
	func on_enemy_defeated(_enemy: Node2D) -> void:
		pass

class NoPauseGame extends Node2D:
	var story_safe: bool = false
	func emit_fx(_kind: String, _at: Vector2, _direction: Vector2, _power: float) -> void:
		pass
	func on_parry_contact(_defender: Node, _source: Node, _at: Vector2, _kind: String) -> void:
		pass

func check(value: bool, label: String) -> void:
	if value:
		passed += 1
		print("PASS ", label)
	else:
		failed += 1
		push_error("FAIL " + label)

func reset_player() -> void:
	paused = false
	game._paused = false
	game.story_safe = false
	game.freeze_on_contact = false
	player.revive(Vector2(0.0, 300.0))
	player.invuln = 0.0
	player.facing = 1
	game.contacts.clear()
	game.animations.clear()
	game.effects.clear()
	game.fallback_impacts = 0
	game.parry_signals = 0
	game.damage_calls = 0
	for action: String in ["move_left", "move_right", "attack", "dash", "parry", "jump"]:
		Input.action_release(action)

func ticks(count: int, delta: float = 0.01) -> void:
	for index: int in range(count):
		player._physics_process(delta)

func front() -> Vector2:
	return player.global_position + Vector2(player.facing * 18.0, -18.0)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	for action: String in ["move_left", "move_right", "attack", "dash", "parry", "jump"]:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
	game = ParryGame.new()
	root.add_child(game)
	var floor_body: StaticBody2D = StaticBody2D.new()
	var floor_collider: CollisionShape2D = CollisionShape2D.new()
	var floor_shape: RectangleShape2D = RectangleShape2D.new()
	floor_shape.size = Vector2(2000.0, 24.0)
	floor_collider.shape = floor_shape
	floor_collider.position = Vector2(0.0, 312.0)
	floor_body.add_child(floor_collider)
	game.add_child(floor_body)
	player = Player.new()
	player.configure(game)
	player.set_physics_process(false)
	game.player = player
	game.add_child(player)
	player.set_physics_process(false)
	player.hide()
	player.parried.connect(func() -> void: game.parry_signals += 1)
	source_a = Node2D.new()
	source_b = Node2D.new()
	game.add_child(source_a)
	game.add_child(source_b)
	source_a.position = Vector2(36.0, 300.0)
	source_b.position = Vector2(44.0, 300.0)
	await physics_frame
	reset_player()
	await process_frame
	Input.action_press("parry")
	player._physics_process(0.01)
	Input.action_release("parry")
	await process_frame
	check(player.parry_phase == "ready" and player.animation_state == "parry" and player.parry_timer > 0.15, "K immediately raises the blade in a real ready window")
	check(game.contacts.is_empty(), "raising a blade without contact grants no parry reward")
	ticks(20)
	check(player.parry_timer == 0.0 and player.parry_phase == "none" and player.health == 8, "missing the window returns to neutral without beat-miss damage")

	reset_player()
	check(player._start_parry(), "explicit ready helper opens a fresh legal window")
	var original_window: float = player.parry_timer
	var at: Vector2 = front()
	var before: Vector2 = player.global_position
	check(player.parry_success(source_a, at, "melee", 10), "front blade contact succeeds during current window")
	check(player.parry_phase == "recoil" and player.animation_state == "parry_recoil" and player.frame == 0, "accepted contact immediately publishes the rebound pose")
	check(player.global_position == before and player.velocity.x < 0.0, "rebound starts as physical velocity without a teleport")
	check(player.parry_timer == original_window, "accepted contact never extends the original defense window")
	check(game.contacts.size() == 1 and game.contacts[0].source == source_a and game.contacts[0].at == at and game.contacts[0].kind == "melee", "one success dispatches its exact source/contact/kind once")
	check(game.fallback_impacts == 0 and not game.effects.has("parry") and game.parry_signals == 1, "central contact callback excludes legacy duplicate FX and impacts")
	player.invuln = 0.02
	player._dash_cooldown = 0.20
	check(not player.parry_success(source_a, at, "melee", 10), "same source and attack token cannot reward twice in one window")
	check(game.contacts.size() == 1 and is_equal_approx(player.invuln, 0.02) and is_equal_approx(player._dash_cooldown, 0.20), "duplicate contact cannot refresh defense or dodge rewards")
	check(player.parry_success(source_a, at, "melee", 11), "a genuinely new attack token from the same source is independent")
	check(player.parry_success(source_b, at, "projectile", 10) and game.contacts.size() == 3, "distinct source instance may reuse a numeric token")

	reset_player()
	player._start_parry()
	check(not player.parry_success(), "real game rejects bare compatibility call as a genuine contact")
	check(not player.parry_success(null, front(), "melee", 21), "real attack token requires a live source")
	check(not player.parry_success(source_a, Vector2.INF, "melee", 22), "actual attacks require a finite contact point")
	check(not player.parry_success(source_a, player.global_position + Vector2(-18.0, -18.0), "melee", 23), "back-side blade contact fails a forward guard")
	source_a.position.x = -36.0
	check(not player.parry_success(source_a, front(), "melee", 24), "rear attacker cannot fake a front contact after crossing the body")
	source_a.position.x = 36.0
	check(not player.parry_success(source_a, player.global_position + Vector2(150.0, -18.0), "melee", 25), "distant point cannot manufacture a blade clash")
	player.parry_timer = 0.0
	check(not player.parry_success(source_a, front(), "melee", 26) and game.contacts.is_empty(), "expired window rejects contact with no reward")

	reset_player()
	player._start_parry()
	var no_pause_mock: NoPauseGame = NoPauseGame.new()
	root.add_child(no_pause_mock)
	player.configure(no_pause_mock)
	player.revive(Vector2(0.0, 300.0))
	check(not player._parry_paused() and player._start_parry() and player.parry_success(source_a, front(), "melee", 29), "minimal game without root pause property has a null-safe pause check")
	player.configure(game)
	no_pause_mock.free()
	reset_player()
	player._start_parry()
	paused = true
	check(not player.parry_success(source_a, front(), "melee", 30) and game.contacts.is_empty(), "paused tree rejects contact")
	var paused_window: float = player.parry_timer
	player._physics_process(0.03)
	check(player.parry_timer == paused_window, "pause does not consume the active defense window")
	paused = false
	game._paused = true
	check(not player.parry_success(source_a, front(), "melee", 31), "root pause state also rejects contact")
	game._paused = false
	check(player.parry_success(source_a, front(), "melee", 32), "rejected paused contact did not poison valid source token state")
	game.story_safe = true
	check(not player.parry_success(source_a, front(), "melee", 33) and player.parry_phase == "none" and player._parry_seen.is_empty(), "rest rejects contact and clears reaction and remembered attacks")
	player.set_impact_freeze(0.1)
	player._physics_process(0.0)
	check(player.combat_freeze == 0.0 and player.parry_timer == 0.0, "rest overrides local hold and old defense window immediately")

	reset_player()
	player._start_parry()
	player.parry_success(source_a, front(), "melee", 40)
	player.dead = true
	check(not player.parry_success(source_a, front(), "melee", 41) and player.parry_phase == "none" and player._parry_seen.is_empty(), "death rejects new contact and clears remembered reaction state")
	reset_player()
	player._start_parry()
	check(player.parry_success(source_a, front(), "melee", 40), "revive opens a clean source-token history")
	ticks(50)
	check(player._start_parry() and player._parry_seen.is_empty(), "a later ready window starts with an empty per-window cache")
	check(player.parry_success(source_a, front(), "melee", 40), "controller cache is per-window rather than permanently blocking a source")

	reset_player()
	await physics_frame
	player._physics_process(1.0 / 60.0)
	player._start_parry()
	player.parry_success(source_a, front(), "melee", 50)
	before = player.global_position
	for index: int in range(4):
		await physics_frame
		player._physics_process(1.0 / 60.0)
	var rebound_distance: float = before.x - player.global_position.x
	check(rebound_distance >= 2.0 and rebound_distance <= 4.1, "successful clash physically retreats only two to four pixels")
	check(player.parry_phase == "recover" and player.animation_state == "parry_recover", "brief rebound advances to explicit recovery")
	check(game.animations.has("parry_recoil") and game.animations.has("parry_recover") and player.get_parry_progress() >= 0.0 and player.get_parry_progress() <= 1.0, "reaction animations and normalized progress follow real controller stages")
	var attack_before: int = player.attack_serial
	await process_frame
	Input.action_press("attack")
	player._physics_process(0.01)
	Input.action_release("attack")
	await process_frame
	check(player.queued_attack and player.attack_serial == attack_before, "early recovery captures counter intent without skipping initial settle")
	for index: int in range(12):
		player._physics_process(0.01)
		if player.attack_serial > attack_before:
			break
	check(player.attack_serial == attack_before + 1 and player.parry_phase == "none" and player.attack_phase == "windup", "buffered counter starts in recovery and relinquishes remaining defense")

	reset_player()
	await process_frame
	player._start_parry()
	game.freeze_on_contact = true
	player.parry_success(source_a, front(), "projectile", 60)
	Input.action_press("attack")
	Input.action_press("jump")
	player._physics_process(0.01)
	Input.action_release("attack")
	Input.action_release("jump")
	await process_frame
	var frozen_progress: float = player.get_parry_progress()
	ticks(3)
	check(player.queued_attack and player._jump_buffer > 0.0 and player.parry_phase == "recoil" and player.get_parry_progress() == frozen_progress, "local impact hold preserves both input edges and rebound pose")
	check(player.parry_timer < 0.13, "real defense window continues expiring during the rebound hold")
	attack_before = player.attack_serial
	for index: int in range(40):
		player._physics_process(0.01)
		if player.attack_serial > attack_before:
			break
	check(player.attack_serial == attack_before + 1 and player.velocity.y < 0.0, "held jump and counter intents execute after local hold without loss")
	check(is_equal_approx(Engine.time_scale, 1.0) and not paused, "parry reaction never changes global simulation speed")

	reset_player()
	player.position.y = 180.0
	player._physics_process(0.0)
	player._coyote = 0.0
	player._start_parry()
	player.parry_success(source_a, front(), "melee", 70)
	await process_frame
	Input.action_press("jump")
	player._physics_process(0.01)
	Input.action_release("jump")
	await process_frame
	check(player.velocity.y < -250.0 and player._air_jumps == 0, "airborne rebound still accepts the available air jump")
	ticks(7)
	Input.action_press("move_right")
	ticks(3)
	Input.action_release("move_right")
	check(player.velocity.x > 0.0, "air control resumes during the short recovery")

	reset_player()
	await process_frame
	var wall: StaticBody2D = StaticBody2D.new()
	var wall_collider: CollisionShape2D = CollisionShape2D.new()
	var wall_shape: RectangleShape2D = RectangleShape2D.new()
	wall_shape.size = Vector2(4.0, 100.0)
	wall_collider.shape = wall_shape
	wall_collider.position = Vector2(-11.0, 265.0)
	wall.add_child(wall_collider)
	game.add_child(wall)
	await physics_frame
	player._physics_process(1.0 / 60.0)
	player._start_parry()
	player.parry_success(source_a, front(), "melee", 80)
	for index: int in range(4):
		await physics_frame
		player._physics_process(1.0 / 60.0)
	check(player.global_position.x >= -2.1, "rebound uses body collision and cannot teleport through a rear wall")
	wall.free()

	reset_player()
	var enemy: CharacterBody2D = Enemy.new()
	enemy.configure(game, "elite", Vector2(35.0, 300.0))
	enemy.facing = -1
	enemy.set_physics_process(false)
	game.add_child(enemy)
	enemy.set_physics_process(false)
	enemy.hide()
	await physics_frame
	player._start_parry()
	enemy._begin_attack()
	var first_serial: int = enemy.attack_serial
	enemy._execute_attack()
	check(first_serial > 0 and game.contacts.size() == 1 and game.contacts[0].source == enemy, "enemy supplies a live attacker and unique attack serial")
	check(player.health == 8 and enemy._stagger >= 0.5 and player.parry_phase == "recoil", "enemy staggers only after an accepted genuine clash")
	var blade_at: Vector2 = game.contacts[0].at if not game.contacts.is_empty() else Vector2.INF
	check(blade_at.is_finite() and blade_at.x >= -20.0 and blade_at.x <= 27.0 and is_equal_approx(blade_at.y, 283.0), "enemy reports a point on its actual attack blade segment")
	enemy._execute_attack()
	check(game.contacts.size() == 1, "resolved enemy attack cannot dispatch another clash")
	reset_player()
	enemy._stagger = 0.0
	enemy._hurt_flash = 0.0
	enemy._begin_attack()
	enemy._execute_attack()
	check(enemy.attack_serial > first_serial and player.health == 7 and enemy._stagger == 0.0, "new enemy attack outside a guard window damages normally and does not stagger itself")
	for action: String in ["move_left", "move_right", "attack", "dash", "parry", "jump"]:
		Input.action_release(action)
	game.free()
	print("Parry controller: %d passed, %d failed" % [passed, failed])
	quit(1 if failed > 0 else 0)

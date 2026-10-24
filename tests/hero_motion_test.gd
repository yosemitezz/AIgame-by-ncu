extends SceneTree
## Hero animation states: crouch, jump phases, landing, air-jump flight, air cuts and atlas integrity.
## Attack timing, hit windows and the collider are covered by combat_feel_test and level_layout_test.

const Player = preload("res://actors/player.gd")
const Renderer = preload("res://presentation/actor_renderer.gd")
var passed: int = 0
var failed: int = 0
var arena: TestArena
var player: CharacterBody2D

class TestArena extends Node2D:
	signal animation_event(actor: Node, state: String, frame: int, facing: int)
	var story_safe: bool = false
	var player: CharacterBody2D
	var boss: Node2D
	func hero_attack(_source: Node2D, _damage: int, _reach: float, _combo: int) -> void:
		pass
	func emit_fx(_kind: String, _at: Vector2, _direction: Vector2, _power: float) -> void:
		pass
	func damage_player(amount: int, origin: Vector2) -> void:
		player.receive_hit(amount, origin)
	func spawn_projectile(_at: Vector2, _velocity: Vector2, _friendly: bool = false) -> Node2D:
		return null

func check(value: bool, label: String) -> void:
	if value:
		passed += 1
		print("PASS ", label)
	else:
		failed += 1
		push_error("FAIL " + label)

func release_all() -> void:
	for action: String in ["move_left", "move_right", "attack", "dash", "parry", "jump", "crouch"]:
		Input.action_release(action)

func reset_actor() -> void:
	arena.story_safe = false
	player.revive(Vector2(0.0, 300.0))
	player.invuln = 0.0
	player.facing = 1
	release_all()

func ticks(count: int) -> void:
	# move_and_slide only advances inside a physics frame, so every tick waits for one.
	for index: int in range(count):
		await physics_frame
		player._physics_process(1.0 / 60.0)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	for action: String in ["move_left", "move_right", "attack", "dash", "parry", "jump", "crouch"]:
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
	await ticks(4)
	check(player.is_on_floor(), "fixture settles on the floor")

	# Atlas integrity: every state exists, every frame lies inside the sheet, anchor and canvas agree.
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://presentation/feel_frames/manifest.json"))
	var states: Dictionary = manifest["hero"]["states"]
	var needed: Array[String] = ["idle", "run", "jump", "apex", "fall", "land", "air_jump", "crouch_in", "crouch", "crouch_out", "crouch_walk", "dash", "hurt", "dead"]
	for combo: int in [1, 2, 3]:
		for phase: String in ["windup", "attack", "recover"]:
			needed.append("cut_%d_%s" % [combo, phase])
			needed.append("air_cut_%d_%s" % [combo, phase])
	var all_present: bool = true
	for key: String in needed:
		all_present = all_present and states.has(key)
	check(all_present, "atlas manifest lists every ground, air, crouch and landing state")
	var atlas: Texture2D = load("res://presentation/feel_frames/hero_atlas.png")
	var inside: bool = true
	for key: String in needed:
		var info: Dictionary = states[key]
		for f: int in range(int(info["count"])):
			var region: Rect2 = Renderer.hero_region(key, f)
			inside = inside and region.position.x >= 0.0 and region.position.y >= 0.0 and region.end.x <= atlas.get_width() and region.end.y <= atlas.get_height()
	check(inside, "every hero frame region lies inside the atlas texture")
	check(Renderer.HERO_SIZE == Vector2(manifest["hero"]["canvas"][0], manifest["hero"]["canvas"][1]), "renderer frame size matches the manifest canvas")
	check(Renderer.HERO_ANCHOR == Vector2(manifest["hero"]["anchor"][0], manifest["hero"]["anchor"][1]), "renderer anchor matches the manifest anchor")
	check(atlas.get_width() == 8 * int(Renderer.HERO_SIZE.x), "atlas has eight columns of whole frames")
	check(Renderer.hero_region("attack", 1, 1, true) != Renderer.hero_region("attack", 1, 1, false), "airborne cut uses its own frames")
	check(Renderer.hero_region("attack", 2, 1) != Renderer.hero_region("attack", 2, 3), "finisher keeps a distinct pose")
	var reach: float = 0.0
	for combo: int in [1, 2, 3]:
		for f: int in range(8):
			reach = maxf(reach, absf(Renderer.weapon_tip_local(combo, f).x))
	check(reach >= 55.0, "blade tip sweeps at least 55 px from the feet axis (%.0f)" % reach)
	var low: float = 0.0
	var high: float = 0.0
	for f: int in range(8):
		var tip: Vector2 = Renderer.weapon_tip_local(1, f, false, "heavy")
		low = minf(low, tip.y)
		high = maxf(high, tip.y)
	check(low < -60.0 and high > -10.0, "heavy first cleave sweeps from overhead to ground level (%.0f to %.0f)" % [low, high])
	var light_low: float = INF
	var light_high: float = -INF
	var point_forward: bool = true
	for f: int in range(8):
		var tip: Vector2 = Renderer.weapon_tip_local(1, f, false, "light")
		light_low = minf(light_low, tip.y)
		light_high = maxf(light_high, tip.y)
		point_forward = point_forward and tip.x > 0.0
	check(point_forward and light_high - light_low <= 12.0, "light first thrust keeps the point in a narrow forward corridor (%.0f to %.0f)" % [light_low, light_high])

	# Crouch: held input, slower walk, no collider change, blocked in the air and during attacks.
	reset_actor()
	var shape: RectangleShape2D = player.get_node_or_null("CollisionShape2D").shape if player.get_node_or_null("CollisionShape2D") != null else null
	var size_before: Vector2 = shape.size if shape != null else Vector2.ZERO
	await ticks(3)
	check(player.animation_state == "idle" and not player.crouching, "idle before crouch")
	Input.action_press("crouch")
	await ticks(1)
	check(player.crouching and player.animation_state == "crouch_in", "holding crouch enters the lowering pose")
	await ticks(12)
	check(player.animation_state == "crouch", "crouch settles into the held pose")
	if shape != null:
		check(shape.size == size_before, "crouch leaves the collider alone")
	Input.action_press("move_right")
	await ticks(25)
	check(player.animation_state == "crouch_walk", "moving while crouched plays the crouch walk")
	check(absf(player.velocity.x - Player.RUN_SPEED * Player.CROUCH_SPEED) < 0.1, "crouch walk is slow (%.0f px/s)" % player.velocity.x)
	Input.action_release("move_right")
	Input.action_release("crouch")
	await ticks(1)
	check(not player.crouching and player.animation_state == "crouch_out", "releasing crouch plays the rise")
	await ticks(14)
	check(player.animation_state == "idle", "rise returns to idle")

	reset_actor()
	Input.action_press("crouch")
	await ticks(3)
	check(player.crouching, "crouch held again")
	Input.action_press("attack")
	await ticks(2)
	check(not player.crouching and player.attack_phase != "none", "an attack takes over from crouch")
	Input.action_release("attack")
	await ticks(60)
	check(player.attack_phase == "none" and player.crouching, "crouch resumes after the swing while still held")
	Input.action_release("crouch")
	reset_actor()
	player.global_position = Vector2(0.0, 200.0)
	player.velocity = Vector2.ZERO
	Input.action_press("crouch")
	await ticks(2)
	check(not player.crouching, "no crouch in the air")
	release_all()
	await ticks(90)

	# Jump phases follow vertical speed, then the landing squat.
	reset_actor()
	await ticks(3)
	var seen: Dictionary = {}
	player._jump(false)
	for index: int in range(140):
		await ticks(1)
		seen[player.animation_state] = true
	check(seen.has("jump") and seen.has("apex") and seen.has("fall"), "a jump plays rise, apex and fall states (%s)" % str(seen.keys()))
	check(seen.has("land"), "landing from a jump plays the landing squat")
	await ticks(20)
	check(player.animation_state == "idle", "landing squat hands back to idle")

	reset_actor()
	await ticks(3)
	player._jump(false)
	await ticks(14)
	player._jump(true)
	await ticks(1)
	check(player.animation_state == "air_jump", "the air jump plays the wing-powered flight pose")
	var flight_frames: Dictionary = {}
	for index: int in range(26):
		await ticks(1)
		if player.animation_state == "air_jump":
			flight_frames[player.frame] = true
	check(flight_frames.size() >= 4, "wing-powered flight steps through its frames (%d)" % flight_frames.size())
	await ticks(120)

	# Airborne cuts read the airborne atlas rows.
	reset_actor()
	player.global_position = Vector2(0.0, 150.0)
	player.velocity = Vector2.ZERO
	await ticks(1)
	check(Renderer.is_airborne(player), "renderer reports airborne while off the floor")
	player._start_attack()
	await ticks(1)
	check(player.attack_phase != "none", "attack starts in the air")
	release_all()

	# Infinite air jumps: ten presses in a row each launch upward, and the wings stay out.
	reset_actor()
	await ticks(3)
	player._jump(false)
	await ticks(6)
	check(player.wing_amount == 0.0, "wings stay folded on a ground jump")
	var all_jumped: bool = true
	for index: int in range(10):
		player.velocity.y = 120.0
		player._jump_buffer = 0.12
		await ticks(1)
		all_jumped = all_jumped and player.velocity.y < -250.0
		await ticks(4)
	check(all_jumped, "ten air jumps in a row all launch (unlimited)")
	check(player.wing_amount > 0.9, "air jumps open the light wings (%.2f)" % player.wing_amount)
	check(player.wings != null and player.wings.visible, "wings node is visible while open")

	# Landing folds the wings gradually, not instantly.
	player.global_position = Vector2(0.0, 296.0)
	player.velocity = Vector2(0.0, 200.0)
	await ticks(6)
	check(player.is_on_floor(), "hero lands")
	var folding: float = player.wing_amount
	check(folding > 0.05 and folding < 0.95, "wings are partly folded right after landing (%.2f)" % folding)
	await ticks(70)
	check(player.wing_amount == 0.0 and not player.wings.visible, "wings finish folding away")

	# Enemy hit reactions: knockback, stun and launch.
	reset_actor()
	var Enemy = load("res://actors/enemy.gd")
	var foe: CharacterBody2D = Enemy.new()
	foe.configure(arena, "sentry", Vector2(60.0, 300.0))
	foe.set_physics_process(false)
	arena.add_child(foe)
	await physics_frame
	foe.react("knockback", Vector2(0.0, 300.0))
	check(foe.reaction == "knockback" and foe.velocity.x > 200.0, "knockback shoves the enemy away from the hero (%.0f)" % foe.velocity.x)
	foe.velocity = Vector2.ZERO
	foe._stagger = 0.0
	foe.react("stun", Vector2(0.0, 300.0))
	check(foe.reaction == "stun" and foe._stun > 0.9 and foe._stagger >= foe._stun, "stun leaves the enemy dizzy for about a second")
	foe._stun = 0.0
	foe._stagger = 0.0
	foe.react("launch", Vector2(0.0, 300.0))
	check(foe.reaction == "launch" and foe.velocity.y < -300.0 and foe.velocity.x > 150.0, "launch throws the enemy up and away")
	var elite: CharacterBody2D = Enemy.new()
	elite.configure(arena, "elite", Vector2(120.0, 300.0))
	elite.set_physics_process(false)
	arena.add_child(elite)
	await physics_frame
	elite.react("stun", Vector2(0.0, 300.0))
	check(elite._stun > 0.0 and elite._stun < 0.7, "elites resist stun (%.2f)" % elite._stun)
	elite.react("launch", Vector2(0.0, 300.0))
	check(elite.velocity.y > -250.0, "elites resist launch height (%.0f)" % elite.velocity.y)
	foe.health = 0
	foe.dead = true
	foe.react("launch", Vector2(0.0, 300.0))
	check(foe.reaction == "launch", "a dead enemy ignores new reactions")
	arena.story_safe = true
	elite.reaction = ""
	elite.react("knockback", Vector2(0.0, 300.0))
	check(elite.reaction == "", "rest sections block reactions")
	arena.story_safe = false

	release_all()
	arena.free()
	print("Hero motion: %d passed, %d failed" % [passed, failed])
	quit(1 if failed > 0 else 0)

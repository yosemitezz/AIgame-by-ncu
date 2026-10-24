extends SceneTree
## Real-scene feedback contracts; no playthrough or camera/physics mutation by the service.
var passed: int = 0
var failed: int = 0
func check(value: bool, label: String) -> void:
	if value: passed += 1
	else:
		failed += 1
		push_error("FAIL " + label)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var game: Node = load("res://main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	await process_frame
	game.set_process(false)
	game.set_physics_process(false)
	game.player.set_physics_process(false)
	game.music.stop_score()
	game.music.set_process(false)
	for enemy: Node in get_nodes_in_group("enemies"):
		enemy.set_physics_process(false)
	game.effects.set_process(false)
	var speed: Node2D = game.speed_feedback
	speed.set_process(false)
	var at: Vector2 = game.player.position
	var camera_at: Vector2 = game._camera.position
	var time_scale_before: float = Engine.time_scale
	var health: int = game.player.health
	game.set_story_safe(false)
	game.impact.reduced_motion = false
	game.speed_effects_level = 1
	game.player._cancel_attack()
	game.player.dash_timer = 0.0
	game.player.velocity = Vector2.ZERO
	check(speed.sample_camera_lead(0.1) == 0.0, "idle has no speed lead")
	game.player.facing = 1
	game.player.dash_timer = 0.16
	var first: float = speed.sample_camera_lead(0.025)
	var full: float = speed.sample_camera_lead(0.025)
	check(first > 0.0 and full == 24.0, "dash lead rises quickly to capped twenty-four native pixels")
	game.player.dash_timer = 0.0
	game.player.attack_phase = "active"
	check(speed.sample_camera_lead(0.1) == 12.0, "attack advancement has a smaller twelve-pixel lead")
	game.player.facing = -1
	check(speed.sample_camera_lead(0.1) == -12.0, "lead follows committed attack direction")
	game.player._cancel_attack()
	check(speed.sample_camera_lead(0.1) == 0.0, "lead returns promptly to rest")
	game.player.velocity = Vector2(420, 0)
	game.player.dash_timer = 0.16
	for i: int in 12:
		game.player.position.x += 8
		speed._process(0.02)
	check(speed._marks.size() > 0 and speed._marks.size() <= 64, "moving dash generates bounded background marks")
	check(not speed.z_as_relative and speed.z_index < game.player.z_index, "speed accents stay below actors")
	var count_before: int = speed._marks.size()
	speed._process(0.001)
	check(speed._marks.size() <= count_before, "time without displacement adds no static streak cloud")
	game.speed_effects_level = 2
	for i: int in 100:
		game.player.position.x += 8
		speed._spawn_clock = 0
		speed._process(0.00001)
	check(speed._marks.size() <= speed.MAX_MARKS, "strong mode respects sixty-four mark cap")
	game.player.dash_timer = 0
	game.player.velocity = Vector2.ZERO
	for i: int in 20: speed._process(0.02)
	check(speed._marks.is_empty(), "marks expire after movement ends")
	game.player.dash_timer = 0.16
	game.impact.reduced_motion = true
	check(speed.sample_camera_lead(0.1) == 0 and speed._marks.is_empty(), "reduced motion clears marks and returns zero lead")
	game.impact.reduced_motion = false
	game.speed_effects_level = 0
	check(speed.sample_camera_lead(0.1) == 0, "F3 off mode disables lead")
	game.speed_effects_level = 1
	game.set_story_safe(true)
	check(speed.sample_camera_lead(0.1) == 0 and speed._marks.is_empty(), "story safety clears background feedback")
	game.set_story_safe(false)
	game._overlay = "map"
	check(speed.sample_camera_lead(0.1) == 0, "map stops feedback and camera lead")
	game._overlay = ""
	game._paused = true
	check(speed.sample_camera_lead(0.1) == 0, "pause stops feedback")
	game._paused = false
	paused = true
	check(speed.sample_camera_lead(0.1) == 0 and speed._marks.is_empty(), "tree pause clears feedback")
	paused = false
	game.player.position = at
	check(game._camera.position == camera_at and game.player.health == health, "feedback never writes camera or health")
	check(Engine.time_scale == time_scale_before, "feedback never changes global time")
	var shader_source: String = FileAccess.get_file_as_string("res://presentation/ghost_outline.gdshader")
	check(not shader_source.contains("SCREEN_TEXTURE") and not shader_source.contains("textureLod"), "outline shader cannot blur screen, UI or projectiles")
	print("Speed feedback: %d passed, %d failed" % [passed, failed])
	quit(1 if failed else 0)

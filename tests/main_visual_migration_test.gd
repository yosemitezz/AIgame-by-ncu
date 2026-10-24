extends SceneTree
## Short real-scene migration contracts. No playthrough or timing authority in visuals.
const Katana = preload("res://presentation/katana_visual.gd")
const Renderer = preload("res://presentation/actor_renderer.gd")
const Boss = preload("res://combat/boss.gd")
const HERO_SHA: String = "06dd2263c3640969416449cfae1f9372290bc041b0ca9fbfeb938a147e43b8c3"
const IMPACT_SHA: String = "4bff7680dc43e6615561771b3d688b2d4fc3663e646fa70ce26a612c44ed9a48"
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
	check(FileAccess.get_sha256("res://presentation/feel_frames/hero_atlas.png") == HERO_SHA, "primary long-limb hero atlas stays byte-identical")
	check(FileAccess.get_sha256("res://combat/impact_feedback.gd") == IMPACT_SHA, "primary heavy-impact and zoom service stays byte-identical")
	check(Renderer.HERO_SIZE == Vector2(144,128) and Renderer.HERO_ANCHOR == Vector2(66,108), "primary hero native cell and feet anchor stay unchanged")
	check(Katana.data().get("total_frames",0) == 62 and Katana.states().size() == 15, "only original katana Boss family migrates: sixty-two cells / fifteen states")
	for state: String in Katana.states():
		var descriptor: Dictionary = Katana.states()[state]
		for index: int in int(descriptor["count"]):
			var region: Rect2 = Katana.region(state,index)
			check(region.size == Vector2(128,128) and Rect2(0,0,1024,1024).encloses(region), state+" native atlas cell remains in bounds")
	check(Katana.landmark("cut_a",0,"guard").x <= 14 and Katana.landmark("cut_a",0,"weapon_tip").x >= 60, "katana first cut already extends through the real contact interval")
	var game: Node = load("res://main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	await process_frame
	game.set_process(false)
	game.set_physics_process(false)
	game.player.set_physics_process(false)
	game.music.stop_score()
	game.music.set_process(false)
	for enemy: Node in get_nodes_in_group("enemies"): enemy.set_physics_process(false)
	var fx: Node = game.get_node("FxLayer")
	fx.set_process(false)
	var blur: Node = game.get_node("MotionBlur")
	blur.set_process(false)
	var health_before: int = game.player.health
	var at: Vector2 = game.player.position
	var time_before: float = Engine.time_scale
	var camera_before: Vector2 = game._camera.position
	fx.setup(game)
	fx.setup(game)
	var subscribed: int = 0
	for connection: Dictionary in game.vfx_requested.get_connections():
		var callback: Callable = connection["callable"]
		if callback.get_object() == fx: subscribed += 1
	check(subscribed == 1, "FxLayer stays one signal subscriber after repeated setup")
	var boss := Boss.new()
	game.add_child(boss)
	boss.configure(game,Vector2(3000,300))
	boss.set_physics_process(false)
	boss.reaction_state = "guard_break"
	boss.reaction_progress = 0.15
	var pose: Dictionary = Katana.describe(boss,"idle",0)
	check(pose["state"] == "guard_break" and is_equal_approx(float(pose["progress"]),0.15), "Boss actual reaction overrides fallback animation frame")
	fx._ghost(boss,"boss",Color.CYAN,0.5,0.3)
	var ghost: Node = fx._ghosts.back()
	var frozen: Dictionary = ghost.boss_pose_snapshot.duplicate(true)
	boss.reaction_state = "none"
	boss.reaction_progress = 0
	check(Katana.describe(ghost,"idle",0) == frozen, "Boss ghost retains its complete reaction snapshot")
	ghost.tick(0.03)
	check(ghost.scale == Vector2.ONE and ghost.z_index == 1 and not ghost.z_as_relative, "outline ghost fades at native scale below actors")
	fx.clear_hostile()
	game.player.combo = 2
	game.player.attack_serial += 1
	game.player.attack_phase = "active"
	game.player._phase_elapsed = game.player._phase_duration()*0.5
	fx.spawn("slash",game.player.position,Vector2.RIGHT,2)
	check(fx.has_method("_hexagram") and fx.has_method("_crystal"), "primary angular crystal and hexagram drawing paths remain")
	var primary: Dictionary = {}
	for shape: Dictionary in fx._shapes:
		if bool(shape.get("profile",false)): primary = shape
	check(not primary.is_empty(), "real active main sword uses the shared attack profile in this same FxLayer")
	if not primary.is_empty():
		var profile: Script = load("res://combat/attack_profile.gd")
		var first: float = game.player.attack_sweep_from
		var last: float = game.player.attack_sweep_to
		check(primary["polygon"] == profile.call("world_polygon",game.player,first,last), "angular main contour uses exactly the actual damage query polygon")
		var polygon: PackedVector2Array = primary["polygon"].duplicate()
		game.player.combat_freeze = 0.1
		fx._process(0.02)
		check(primary["polygon"] == polygon, "local hit-stop holds the real primary contour")
		game.player.combat_freeze = 0
	game.player._cancel_attack()
	fx._process(0.001)
	check(not fx._shapes.any(func(shape: Dictionary) -> bool: return bool(shape.get("phase_bound",false))), "attack cancellation cuts the primary contour immediately")
	fx.clear_hostile()
	fx.spawn("blade_parry",at,Vector2.RIGHT,1)
	fx._process(0.05)
	check(not fx._shapes.any(func(shape: Dictionary) -> bool: return shape["type"] == "flash") and fx.shape_count() > 0 and fx.particle_count() > 0, "clash white core expires by fifty milliseconds while color/sparks remain")
	var shot: Node = game.spawn_projectile(Vector2(800,100),Vector2.RIGHT*40,false)
	shot.set_physics_process(false)
	fx._track_projectiles()
	shot.position.x += 2
	fx._track_projectiles()
	check(fx._proj_trails[shot.get_instance_id()]["pts"].size() >= 2, "projectile second-frame cache remains typed Dictionary-of-points")
	shot.clear()
	fx._track_projectiles()
	check(not fx._proj_trails.has(shot.get_instance_id()), "cleared shot leaves no phantom tail")
	game.player.dash_timer = 0.16
	game.player.velocity = Vector2(420,0)
	game.impact.reduced_motion = false
	blur.enabled_by_user = true
	for i: int in 8:
		game.player.position.x += 8
		blur._process(0.02)
	check(blur.is_active() and blur._marks.size() <= 64, "legacy MotionBlur API now produces bounded background speed lines")
	check(blur._background is Node2D and blur._background.z_index == 1, "background speed marks sit below actors and projectiles")
	check(blur.sample_camera_lead(0.1) <= 24, "speed service returns bounded lead without applying camera motion")
	game.impact.reduced_motion = true
	check(blur.sample_camera_lead(0.1) == 0 and not blur.is_active(), "F2 reduced motion disables speed marks and lead")
	game.impact.reduced_motion = false
	blur.enabled_by_user = false
	check(blur.sample_camera_lead(0.1) == 0, "F3 can disable replacement background feedback")
	var source: String = FileAccess.get_file_as_string("res://vfx/motion_blur.gd")
	check(not source.contains("hint_screen_texture") and not source.contains("texture(screen") and not source.contains("ColorRect"), "no full-screen actor/projectile/UI sampling or blur remains")
	game.player.position = at
	game.player.velocity = Vector2.ZERO
	game.player.dash_timer = 0
	game.set_story_safe(true)
	check(fx.counts().get("warnings",-1) == 0, "story rest clears hostile telegraphs")
	check(game.player.health == health_before and Engine.time_scale == time_before and game._camera.position == camera_before, "visual migration does not mutate damage, global time or camera transform")
	boss.queue_free()
	print("Main visual migration: %d passed, %d failed" % [passed,failed])
	quit(1 if failed else 0)

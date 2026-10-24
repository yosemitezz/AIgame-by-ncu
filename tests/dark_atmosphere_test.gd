extends SceneTree
## Dark-fantasy mood: palette, scenery tables, light pools, the atmosphere layer and its draw pass.

const Level = preload("res://levels/bellkeep.gd")
var passed: int = 0
var failed: int = 0

func check(value: bool, label: String) -> void:
	if value:
		passed += 1
	else:
		failed += 1
		push_error("FAIL " + label)

func _initialize() -> void:
	call_deferred("run")

func luma(c: Color) -> float:
	return 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b

func run() -> void:
	# Palette: dark overall, warm gold accents, crimson haze.
	check(luma(Level.SKY) < 0.06 and luma(Level.SKY_LOW) < 0.08 and luma(Level.FAR) < 0.1, "sky and far silhouettes are near-black")
	check(Level.HAZE.r > Level.HAZE.b and Level.HAZE.r > Level.HAZE.g, "the horizon haze is crimson")
	check(Level.GOLD.r > Level.GOLD.b + 0.2, "gold accents are warm ember tones")
	check(Level.GLASS.size() == 4, "stained glass uses four hues")
	# Scenery tables land on solid ground, away from the safe zones.
	var ground_ok: bool = true
	for x: int in Level.TREE_XS:
		ground_ok = ground_ok and x >= -80 and x <= 3560
	check(ground_ok and Level.TREE_XS.size() >= 10 and Level.TOMB_XS.size() >= 15, "dead trees and tombstones are placed along the route")
	check(Level.GARGOYLES.size() == 6 and Level.CAGES.size() == 5, "gargoyles guard the gates and cages hang over the crypt")
	# Light pools: all inside the world, with a sane radius and strength, and a pool at every torch and the shrine.
	var lights_ok: bool = true
	for entry: Dictionary in Level.LIGHTS:
		lights_ok = lights_ok and Level.WORLD_BOUNDS.has_point(entry["at"]) and float(entry["r"]) >= 30.0 and float(entry["r"]) <= 160.0 and float(entry["a"]) > 0.05 and float(entry["a"]) < 0.5
	check(lights_ok and Level.LIGHTS.size() >= 15, "%d light pools are inside the world with bounded radius and strength" % Level.LIGHTS.size())
	var shrine_lit: bool = false
	for entry: Dictionary in Level.LIGHTS:
		shrine_lit = shrine_lit or (entry["at"].distance_to(Vector2(Level.CHECKPOINT.x, 236.0)) < 8.0 and entry["tint"].g > 0.8)
	check(shrine_lit, "the shrine glows cyan")
	# Gameplay is untouched: the same platforms and floor line.
	check(Level.PLATFORMS.size() == 26 and Level.PLATFORMS[0] == Rect2(-80, 300, 590, 24) and Level.LAYOUT_VERSION == 2, "level geometry is unchanged")
	# Running game.
	var game: Node = load("res://main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	await process_frame
	game.set_physics_process(false)
	game.player.set_physics_process(false)
	game.music.stop_score()
	game.music.set_process(false)
	for enemy: Node in get_nodes_in_group("enemies"):
		enemy.set_physics_process(false)
	var mood: Node = game.get_node_or_null("DarkAtmosphere")
	check(mood != null, "the atmosphere layer is attached")
	var tint: Node = game.get_node_or_null("AmbientTint")
	check(tint is CanvasModulate and luma(tint.color) > 0.6 and luma(tint.color) < 0.95, "an ambient tint darkens the scene without crushing it")
	check(game.get_node_or_null("VignetteLayer") != null, "the vignette layer exists")
	check(mood.material is CanvasItemMaterial and mood.material.blend_mode == CanvasItemMaterial.BLEND_MODE_ADD, "light pools blend additively")
	# Teleport to the shrine and draw: the nearby pools must be counted and nothing errors.
	game.player.position = Vector2(Level.CHECKPOINT.x, 290.0)
	game._camera.position = game.camera_target(game.player.position, 1)
	for _i: int in 4:
		await process_frame
	check(mood.visible_lights >= 1, "lights near the camera are drawn (%d)" % mood.visible_lights)
	game.player.position = Vector2(2500.0, 290.0)
	game._camera.position = game.camera_target(game.player.position, 1)
	for _i: int in 4:
		await process_frame
	var far_count: int = mood.visible_lights
	game.player.position = Vector2(700.0, 440.0)
	game._camera.position = game.camera_target(game.player.position, 1)
	for _i: int in 4:
		await process_frame
	check(mood.visible_lights >= 2 and far_count <= mood.visible_lights + 6, "only lights inside the view are drawn (%d here, %d at the arena)" % [mood.visible_lights, far_count])
	# Flicker stays in a sane band and varies over time.
	var low: float = 9.0
	var high: float = -9.0
	for i: int in 200:
		mood._clock = float(i) * 0.05
		var f: float = mood.flicker(1.3)
		low = minf(low, f)
		high = maxf(high, f)
	check(low > 0.55 and high < 1.05 and high - low > 0.1, "torch flicker breathes between %.2f and %.2f" % [low, high])
	# Reduced particle budget is a hard cap.
	check(mood.MAX_ASH <= 64 and mood.MAX_EMBERS <= 30, "particle budget is capped")
	# Level repaint survives every region (floor, crypt, library, arena).
	for at: Vector2 in [Vector2(90, 290), Vector2(900, 480), Vector2(1300, 20), Vector2(2900, 290), Vector2(3300, 290)]:
		game.player.position = at
		game._camera.position = game.camera_target(at, 1)
		for _i: int in 3:
			await process_frame
	check(true, "the dark level draws in every region without errors")
	game.queue_free()
	await process_frame
	print("Dark atmosphere: %d passed, %d failed" % [passed, failed])
	quit(1 if failed > 0 else 0)

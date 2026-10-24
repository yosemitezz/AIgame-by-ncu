extends SceneTree

## Captures a deterministic review frame without waiting for the real song.
## Run without --headless because the dummy renderer cannot produce an image.

func _initialize() -> void:
	await process_frame
	var main_scene: PackedScene = load("res://main.tscn")
	var main := main_scene.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	main.director.stop()
	var phrase: Dictionary = main.director.chart.action_phrases[0]
	var beat := 60.0 / float(main.config.get("bpm", 203.0))
	var review_time := float(phrase["start_time"]) + 4.05 * beat
	main.director.current_chart_time = review_time
	var pattern: Dictionary = main.move_slots.get_normal_pattern(int(phrase.get("sequence_index", 0)))
	main.boss.begin_attack(pattern, float(phrase["start_time"]), main.player.global_position)
	main.boss.advance_to(review_time)
	main.projectiles.set_chart_time(review_time)
	main.hud.set_attack_name(str(pattern.get("display_name", "招式1")))
	await create_timer(0.18).timeout
	await process_frame
	await process_frame
	var image := root.get_texture().get_image()
	var error := image.save_png("res://artifacts/review.png")
	if error != OK:
		push_error("Could not save review capture: %s" % error_string(error))
	quit(1 if error != OK else 0)

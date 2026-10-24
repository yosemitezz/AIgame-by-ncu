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
	main.director.current_chart_time = 20.75
	main.projectiles.set_chart_time(20.75)
	await process_frame
	await process_frame
	var image := root.get_texture().get_image()
	var error := image.save_png("res://artifacts/review.png")
	if error != OK:
		push_error("Could not save review capture: %s" % error_string(error))
	quit(1 if error != OK else 0)

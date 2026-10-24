extends SceneTree
## One fixed800x450 airborne keyframe. No input, elapsed combat or audio playback.
var game: Node
var complete: bool=false
func _initialize() -> void:call_deferred("run")
func freeze(node: Node) -> void:
	node.set_process(false);node.set_physics_process(false)
	for child: Node in node.get_children():freeze(child)
func run() -> void:
	root.size=Vector2i(800,450);root.content_scale_size=Vector2i(800,450)
	AudioServer.set_bus_mute(0,true)
	create_timer(20.0,true,false,true).timeout.connect(func() -> void:
		if not complete:push_error("Static wing capture watchdog");quit(2))
	for key: String in ["bellkeep_room","bellkeep_checkpoint","bellkeep_elite","bellkeep_shards","bellkeep_doors","bellkeep_weapon"]:
		if has_meta(key):remove_meta(key)
	game=load("res://main.tscn").instantiate();root.add_child(game);current_scene=game
	freeze(game);game.music.stop_score();game._announcement_time=0.0
	var player: CharacterBody2D=game.player
	player.position=Vector2(500,180);player.velocity=Vector2(520,0)
	player.facing=1;player.invuln=0.0;player.animation_state="dash";player.frame=1
	player.dash_direction=Vector2.RIGHT;player.dash_timer=.12
	player.wing_amount=0.0;player.wing_flap=0.0
	player.wings._process(0.0);player.wings.queue_redraw();player.queue_redraw()
	game._camera.position=game.camera_target(player.position,1);game._camera.force_update_scroll()
	game._refresh_hud();game._hud._line_clock=99;game._hud.queue_redraw()
	await process_frame;await process_frame;await RenderingServer.frame_post_draw
	var image: Image=root.get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts/wing-flight"))
	var error: int=image.save_png("res://artifacts/wing-flight/runtime-air-dash.png")
	var record: FileAccess=FileAccess.open("res://artifacts/wing-flight/capture-manifest.json",FileAccess.WRITE)
	record.store_string(JSON.stringify({"static_only":true,"input_playback":false,"size":[image.get_width(),image.get_height()],"renderer":RenderingServer.get_video_adapter_name(),"music_running":game.music.running,"player_physics":player.is_physics_processing(),"wing_gameplay_amount":player.wing_amount,"dash_direction":[1,0],"save_error":error},"  ")+"\n")
	print("WING_CAPTURE ",error," ",image.get_size());complete=true
	game.queue_free();await process_frame;quit(0 if error==OK else 1)

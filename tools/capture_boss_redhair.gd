extends SceneTree
## Four frozen actual Boss-room frames. No input replay, AI or audio progression.
var game: Node
var captures: Array[Dictionary] = []
var output: String = "res://artifacts/boss-redhair/"
var complete: bool = false
func _initialize() -> void: call_deferred("run")
func freeze(node: Node) -> void:
	node.set_process(false);node.set_physics_process(false)
	for child: Node in node.get_children():freeze(child)
func capture(name: String) -> void:
	game._refresh_hud();game._hud._line_clock=99;game._hud.queue_redraw();game.boss.queue_redraw();game.player.queue_redraw()
	await process_frame;await process_frame;await RenderingServer.frame_post_draw
	var image: Image=root.get_texture().get_image()
	var result: int=image.save_png(output+name+".png")
	captures.append({"name":name,"result":result,"native_size":[image.get_width(),image.get_height()],"room_id":game.room_id,"boss_pose":game.boss.get_presentation_pose(),"music_running":game.music.running,"boss_physics":game.boss.is_physics_processing(),"player_physics":game.player.is_physics_processing()})
	print("BOSS_STATIC ",name," ",result)
func run() -> void:
	root.size=Vector2i(800,450);root.content_scale_size=Vector2i(800,450);AudioServer.set_bus_mute(0,true)
	create_timer(25.0,true,false,true).timeout.connect(func() -> void:
		if not complete:push_error("Static Boss capture watchdog");quit(2))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	for key: String in ["bellkeep_room","bellkeep_checkpoint","bellkeep_elite","bellkeep_shards","bellkeep_doors"]:
		if has_meta(key):remove_meta(key)
	game=load("res://main.tscn").instantiate();root.add_child(game);current_scene=game
	freeze(game);game._start_boss();game.music.stop_score();freeze(game)
	game._announcement_time=0;game._room_prepare=0;game._portal_confirm_room=""
	game.boss._cancel_all_attacks();game.boss._active=false;game.boss.velocity=Vector2.ZERO;game.boss.reaction_state="none"
	game.boss.position=Vector2(3020,300);game.boss.facing=-1
	game.player.position=Vector2(2910,300);game.player.velocity=Vector2.ZERO;game.player.facing=1;game.player.animation_state="idle";game.player.frame=0
	game.player.invuln=0;game.player.dead=false;game.player.impact_flash=0;game.player._hurt_lock=0
	game._camera.position=game.camera_target(Vector2(2980,300),1);game._camera.force_update_scroll()
	await capture("runtime-idle")
	if not OS.get_cmdline_user_args().has("--idle-only"):
		game.boss._blade_clip="cut_a";game.boss._blade_duration=.20;game.boss._blade_elapsed=.075
		await capture("runtime-cut")
		game.boss._blade_clip="";game.boss.reaction_state="parry_recoil";game.boss.reaction_progress=.55;game.boss._reaction_blocks_attacks=true
		await capture("runtime-parry-recoil")
		game.boss.reaction_state="guard_break";game.boss.reaction_progress=.22
		await capture("runtime-guard-break")
	var record: FileAccess=FileAccess.open(output+("runtime-idle-comparison-manifest.json" if OS.get_cmdline_user_args().has("--idle-only") else "runtime-capture-manifest.json"),FileAccess.WRITE)
	record.store_string(JSON.stringify({"static_only":true,"input_playback":false,"renderer":RenderingServer.get_video_adapter_name(),"captures":captures},"  ")+"\n")
	complete=true;game.queue_free();await process_frame;quit(0)

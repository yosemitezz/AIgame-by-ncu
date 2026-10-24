extends SceneTree
## Three fixed runtime keyframes. Physics, AI, audio and clocks remain disabled throughout.
var game: Node
var output: String = "res://artifacts/weapon-motion/"
var complete: bool = false
var captures: Array[Dictionary] = []
func _initialize() -> void: call_deferred("run")
func freeze(node: Node) -> void:
	node.set_process(false);node.set_physics_process(false)
	for child: Node in node.get_children():freeze(child)
func capture(name: String) -> void:
	game._refresh_hud();game._hud._line_clock=99;game._hud.queue_redraw()
	game.player.queue_redraw();game.get_node("FxLayer").queue_redraw()
	await process_frame;await process_frame;await RenderingServer.frame_post_draw
	var image: Image=root.get_texture().get_image()
	var error: int=image.save_png(output+name+".png")
	captures.append({"name":name,"error":error,"size":[image.get_width(),image.get_height()],"weapon":game.player.weapon,"combo":game.player.combo,"progress":game.player.get_attack_progress(),"music_running":game.music.running,"player_physics":game.player.is_physics_processing(),"on_floor":game.player.is_on_floor()})
	print("WEAPON_CAPTURE ",name," ",error)
func run() -> void:
	root.size=Vector2i(800,450);root.content_scale_size=Vector2i(800,450)
	AudioServer.set_bus_mute(0,true)
	create_timer(25.0,true,false,true).timeout.connect(func() -> void:
		if not complete:push_error("Static contact capture watchdog");quit(2))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	for key: String in ["bellkeep_room","bellkeep_checkpoint","bellkeep_elite","bellkeep_shards","bellkeep_doors","bellkeep_weapon"]:
		if has_meta(key):remove_meta(key)
	game=load("res://main.tscn").instantiate();root.add_child(game);current_scene=game
	freeze(game);game.music.stop_score();game._announcement_time=0
	game.player.position=Vector2(500,300)
	# One terrain-only setup contact establishes grounded animation selection. No AI/input runs.
	game.player.velocity=Vector2(0,60)
	await physics_frame
	game.player.move_and_slide()
	game.player.velocity=Vector2.ZERO
	game._camera.position=game.camera_target(game.player.position,1);game._camera.force_update_scroll()
	var fx: Node=game.get_node("FxLayer")
	for wid: String in ["light","heavy","great"]:
		game.player._cancel_attack();game.player.set_weapon(wid)
		game.player.combo=3;game.player.facing=1;game.player.attack_serial+=1
		game.player.attack_phase="active";game.player._phase_elapsed=game.player._phase_duration()*.58
		game.player.attack_previous_position=game.player.global_position-Vector2(9,0)
		game.player.attack_sweep_from=.50;game.player.attack_sweep_to=.58
		game.player.animation_state="attack";game.player._set_animation("attack",0)
		fx.clear_hostile();game.effects.clear_hostile()
		game.emit_fx("slash",game.player.position,Vector2.RIGHT,3)
		if wid=="heavy":
			var wave: Node=game.spawn_sword_wave(game.player,game.player.attack_serial)
			if wave!=null:
				wave.set_physics_process(false);wave.position+=Vector2(140,0);wave.queue_redraw()
		freeze(game)
		await capture("runtime-"+wid+"-finisher")
		for projectile: Node in get_nodes_in_group("hero_waves"):projectile.queue_free()
	var record: FileAccess=FileAccess.open(output+"runtime-capture-manifest.json",FileAccess.WRITE)
	record.store_string(JSON.stringify({"static_only":true,"input_playback":false,"renderer":RenderingServer.get_video_adapter_name(),"captures":captures},"  ")+"\n")
	complete=true
	game.queue_free();await process_frame;quit(0)

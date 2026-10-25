extends SceneTree
## Three static room fixtures. No input playback, elapsed encounter or audio.
var game: Node
var output: String = "res://artifacts/rooms-visual/"
var captures: Array[Dictionary] = []
var finished: bool = false

func _initialize() -> void:
    call_deferred("run")

func freeze(node: Node) -> void:
    node.set_process(false)
    node.set_physics_process(false)
    for child: Node in node.get_children(): freeze(child)

func capture(filename: String) -> bool:
    game._refresh_hud()
    game._hud._line_clock = 99.0
    game._hud.queue_redraw()
    await process_frame
    await process_frame
    await RenderingServer.frame_post_draw
    var image: Image = root.get_texture().get_image()
    if image == null or image.is_empty():
        push_error("Fixed capture unavailable: rendering backend produced no pixels")
        return false
    var error: int = image.save_png(output+filename+".png")
    captures.append({"name":filename,"result":error,"width":image.get_width(),"height":image.get_height(),"room_id":game.room_id,"music_running":game.music.running,"player_physics":game.player.is_physics_processing()})
    print("ROOM_CAPTURE ",filename," ",error," ",image.get_size())
    return error == OK

func run() -> void:
    root.size = Vector2i(800,450)
    root.content_scale_size = Vector2i(800,450)
    AudioServer.set_bus_mute(0,true)
    create_timer(20.0,true,false,true).timeout.connect(func() -> void:
        if not finished:
            push_error("Fixed capture watchdog: renderer did not complete")
            quit(2))
    for key: String in ["bellkeep_room","bellkeep_checkpoint","bellkeep_elite","bellkeep_shards","bellkeep_doors"]:
        if has_meta(key): remove_meta(key)
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
    game = load("res://main.tscn").instantiate()
    root.add_child(game)
    current_scene = game
    freeze(game)
    game.music.stop_score()
    game._announcement_time = 0.0
    game.elite_defeated = true
    game.checkpoint_active = true
    game._retire_room_node(game._elite_gate)
    game._elite_gate = null
    game.player.position = Vector2(2540,300)
    game.player.animation_state = "idle"
    game.player.frame = 0
    game.player.queue_redraw()
    game._portal_confirm_room = "boss"
    game._portal_confirm_until = 99.0
    game._camera.position = game.camera_target(game.player.position,1)
    game._camera.force_update_scroll()
    if not await capture("01-dungeon-portal-confirm"):
        quit(2)
        return
    game._portal_confirm_room = ""
    game._mount_room("boss")
    game._room_prepare = 0.0
    game._start_boss(false)
    game.music.stop_score()
    freeze(game)
    game._announcement_time = 0.0
    game._overlay = "map"
    game._paused = true
    game._camera.force_update_scroll()
    if not await capture("02-boss-room-map-hud"):
        quit(2)
        return
    game._overlay = ""
    game._paused = false
    game.room_flow.begin("dungeon")
    game.room_flow.progress = 0.5
    game.room_flow.mounted = true
    game._camera.force_update_scroll()
    if not await capture("03-room-preparation-blackout"):
        quit(2)
        return
    var record: FileAccess = FileAccess.open(output+"capture-manifest.json",FileAccess.WRITE)
    record.store_string(JSON.stringify({"native_size":[800,450],"static_only":true,"renderer":RenderingServer.get_video_adapter_name(),"frames":captures},"  ")+"\n")
    finished = true
    print("ROOM_CAPTURE_COMPLETE ",captures.size())
    quit(0)

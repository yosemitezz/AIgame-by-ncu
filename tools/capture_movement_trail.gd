extends SceneTree
## One static comparison pair; no gameplay input, AI or music advances.
var game: Node
var complete: bool=false
func _initialize() -> void:call_deferred("run")
func freeze(node: Node) -> void:
    node.set_process(false);node.set_physics_process(false)
    for child: Node in node.get_children():freeze(child)
func snapshot(name: String) -> void:
    game.player.queue_redraw();game.player.wings.queue_redraw()
    await process_frame;await process_frame;await RenderingServer.frame_post_draw
    var image: Image=root.get_texture().get_image()
    var error: int=image.save_png("res://artifacts/movement-trail/"+name+".png")
    if error!=OK:push_error("Failed static snapshot");quit(2)
func run() -> void:
    OS.set_environment("BELLKEEP_DISABLE_STORY","1")
    root.size=Vector2i(800,450);root.content_scale_size=Vector2i(800,450)
    AudioServer.set_bus_mute(0,true)
    create_timer(20,true,false,true).timeout.connect(func() -> void:
        if not complete:push_error("Movement static capture watchdog");quit(2))
    for key: String in ["bellkeep_room","bellkeep_checkpoint","bellkeep_elite","bellkeep_shards","bellkeep_doors","bellkeep_weapon"]:
        if has_meta(key):remove_meta(key)
    game=load("res://main.tscn").instantiate();root.add_child(game);current_scene=game
    freeze(game);game.music.stop_score();game._announcement_time=0
    var hero: Node2D=game.player
    hero.position=Vector2(606,180);hero.velocity=Vector2(520,0);hero.dash_timer=.11;hero.dash_direction=Vector2.RIGHT
    hero.animation_state="dash";hero.frame=1;hero.facing=1;hero.invuln=0;hero.wing_amount=0;hero.impact_flash=0
    var service: Node=game.get_node("MotionBlur")
    var trail: Node=service.get_node("MovementTrail")
    service.clear();service.enabled_by_user=false
    game._camera.position=game.camera_target(hero.position,1);game._camera.force_update_scroll()
    hero.wings._process(0);game._refresh_hud();game._hud._line_clock=99;game._hud.queue_redraw()
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts/movement-trail"))
    await snapshot("off-fixed-air-dash")
    service.enabled_by_user=true;game.speed_effects_level=1
    hero.position=Vector2(450,180);trail._process(0)
    for i: int in 12:
        hero.position+=Vector2(13,0)
        hero.frame=i%4
        trail._process(.025)
    hero.frame=1;hero.wings._process(0)
    await snapshot("on-fixed-air-dash")
    var positions: Array=[]
    for sample: Dictionary in trail._samples:positions.append([sample["at"].x,sample["at"].y])
    var record: FileAccess=FileAccess.open("res://artifacts/movement-trail/capture-manifest.json",FileAccess.WRITE)
    record.store_string(JSON.stringify({"static_only":true,"input_playback":false,"size":[800,450],"music_running":game.music.running,"player_physics":hero.is_physics_processing(),"positions":positions,"actual_player":[hero.position.x,hero.position.y],"snapshots":trail.counts(),"renderer":RenderingServer.get_video_adapter_name()},"  ")+"\n")
    print("MOVEMENT_CAPTURE ",trail.counts());complete=true
    game.queue_free();await process_frame;quit(0)
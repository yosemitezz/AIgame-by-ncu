extends SceneTree
## Static chapter contact frames only. No input, AI, score playback or game traversal.
const Story=preload("res://flow/chapter_story.gd")
const Eye=preload("res://presentation/flying_eye.gd")
const Aura=preload("res://presentation/corruption_aura.gd")
const Overlay=preload("res://ui/chapter_overlay.gd")
var game: Node
var eye: Node2D
var aura: Node2D
var overlay: Control
var complete: bool=false
var records: Array[Dictionary]=[]
var capture_only: PackedStringArray=OS.get_environment("BELLKEEP_CHAPTER_CAPTURE_ONLY").split(",",false)
func _initialize() -> void:call_deferred("run")
func freeze(node: Node) -> void:
    node.set_process(false);node.set_physics_process(false)
    for child: Node in node.get_children():freeze(child)
func hide_existing_visuals(node: Node) -> void:
    var script: Script=node.get_script()
    if node is CanvasItem and script!=null and script.resource_path in ["res://presentation/flying_eye.gd","res://presentation/corruption_aura.gd","res://ui/chapter_overlay.gd"]:node.hide()
    for child: Node in node.get_children():hide_existing_visuals(child)
func picture(name: String,presentation: Dictionary) -> void:
    if not capture_only.is_empty() and name not in capture_only:return
    eye.update_story(presentation);eye.snap_to_hero();eye.queue_redraw()
    aura.update_story(presentation);aura._clock=2.3;aura._process(0.0);aura.queue_redraw()
    overlay.update_state(presentation);overlay.queue_redraw()
    await process_frame;await process_frame;await RenderingServer.frame_post_draw
    var image: Image=root.get_texture().get_image()
    var path: String="res://artifacts/chapter-story/"+name+".png"
    var error: int=image.save_png(path)
    records.append({"name":name,"path":path,"size":[image.get_width(),image.get_height()],"save_error":error,"phase":presentation.get("phase",""),"input_playback":false,"music_running":game.music.running,"player_physics":game.player.is_physics_processing(),"comparison_adjustment":"unmasked aura comparison only" if name=="04-corrupted-after-boss" else "none"})
    if error!=OK:push_error("Capture save failed "+name)
func run() -> void:
    root.size=Vector2i(800,450);root.content_scale_size=Vector2i(800,450)
    AudioServer.set_bus_mute(0,true)
    create_timer(25.0,true,false,true).timeout.connect(func() -> void:
        if not complete:push_error("Chapter visual capture watchdog");quit(2))
    for key: String in ["bellkeep_room","bellkeep_checkpoint","bellkeep_elite","bellkeep_shards","bellkeep_doors","bellkeep_weapon"]:
        if has_meta(key):remove_meta(key)
    game=load("res://main.tscn").instantiate();root.add_child(game);current_scene=game
    freeze(game);hide_existing_visuals(game)
    game.music.stop_score();game._announcement_time=0.0;game.outcome=""
    var hero: CharacterBody2D=game.player
    hero.position=Vector2(500,300);hero.velocity=Vector2.ZERO;hero.invuln=0.0;hero.dead=false
    hero.impact_flash=0.0;hero._hurt_lock=0.0;hero.animation_state="idle";hero.frame=0;hero.facing=1;hero.wing_amount=0.0
    hero.attack_phase="none";hero.parry_timer=0.0;hero.queue_redraw()
    game._camera.position=game.camera_target(hero.position,1);game._camera.force_update_scroll()
    game._refresh_hud();game._hud._line_clock=99;game._hud.queue_redraw()
    eye=Eye.new();game.add_child(eye);eye.configure(game,hero);eye.set_process(false)
    aura=Aura.new();game.add_child(aura);aura.configure(hero);aura.set_process(false)
    var canvas:=CanvasLayer.new();canvas.layer=40;game.add_child(canvas)
    overlay=Overlay.new();canvas.add_child(overlay);overlay.set_process(false)
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts/chapter-story"))
    var clean:=Story.new()
    await picture("01-clean-companion",clean.presentation())
    clean.begin_chapter();clean.tick(.55)
    await picture("02-opening",clean.presentation())
    clean.skip();clean.request_rescue({"in_boss":true,"lethal":true});clean.tick(.55)
    await picture("03-rescue",clean.presentation())
    clean.skip();clean.boss_defeated();clean.tick(.50)
    var aftermath: Dictionary=clean.presentation();aftermath["line"]="";aftermath["blocking"]=false;aftermath["blackout"]=0.0
    await picture("04-corrupted-after-boss",aftermath)
    for i: int in 1000:
        var dimming: Dictionary=clean.presentation()
        if float(dimming.get("blackout",0))>=.55 and float(dimming.get("blackout",0))<=.65 and not bool(dimming.get("eye_closeup",false)):break
        clean.tick(.05)
    await picture("04b-fading-vision",clean.presentation())
    for i: int in 1000:
        if bool(clean.presentation().get("eye_closeup",false)):break
        clean.tick(.10)
    await picture("05-cold-eye",clean.presentation())
    for i: int in 1000:
        var fading: Dictionary=clean.presentation()
        if str(fading.get("node_id",""))=="betray_beat" and float(fading.get("faint",0))>=0.45 and float(fading.get("faint",0))<=0.55:break
        clean.tick(.05)
    await picture("05b-fading-eye",clean.presentation())
    clean.skip();clean.tick(2.5)
    await picture("06-narrative-death",clean.presentation())
    var manifest_name: String="capture-manifest.json" if capture_only.is_empty() else "capture-plot-update-manifest.json"
    var file: FileAccess=FileAccess.open("res://artifacts/chapter-story/"+manifest_name,FileAccess.WRITE)
    file.store_string(JSON.stringify({"static_only":true,"input_playback":false,"renderer":RenderingServer.get_video_adapter_name(),"frames":records},"  ")+"\n")
    print("CHAPTER_STATIC_CAPTURE ",records.size()," frames")
    complete=true;game.queue_free();await process_frame
    quit(0 if records.all(func(item: Dictionary) -> bool:return item["save_error"]==OK) else 1)
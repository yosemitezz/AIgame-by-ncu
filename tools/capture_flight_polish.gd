extends SceneTree
## Static authored flight phases only; no input playback, AI or music advancement.
const Renderer=preload("res://presentation/actor_renderer.gd")
const Wings=preload("res://vfx/light_wings.gd")
var complete:bool=false
class Context extends Node:
    var story_safe:bool=false
class Probe extends Node2D:
    var game:Node
    var airborne:bool=true
    var facing:int=1
    var frame:int=0
    var animation_state:String="dash"
    var weapon:String="light"
    var combo:int=1
    var dead:bool=false
    var invuln:float=0.0
    var impact_flash:float=0.0
    var parry_phase:String="none"
    var wing_amount:float=0.0
    var wing_flap:float=0.0
    var dash_timer:float=.17
    var dash_direction:Vector2=Vector2.RIGHT
    var velocity:Vector2=Vector2.RIGHT*520
    func is_on_floor()->bool:return not airborne
    func _draw()->void:Renderer.paint(self,"hero",animation_state,frame,facing)
class Board extends Node2D:
    var fold:bool=false
    func _draw()->void:
        draw_rect(Rect2(0,0,1200,720),Color("111722"))
        var font:Font=ThemeDB.fallback_font
        var labels:Array=["OPEN 0%","OPEN 4%","OPEN 10%","OPEN 70%"] if fold else ["SPREAD 5%","PRESS 30%","DRIVE 63%","GLIDE 96%"]
        for i:int in 4:draw_string(font,Vector2(i*300+20,28),labels[i],HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color("d5d8d9"))
        for i:int in (2 if fold else 3):draw_string(font,Vector2(14,i*220+74),(["AIR UP","AIR DOWN"][i] if fold else ["SIDE","ASCEND","DESCEND"][i]),HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color("a4ccd7"))
func _initialize()->void:call_deferred("run")
func freeze(node:Node)->void:
    node.set_process(false);node.set_physics_process(false)
    for child:Node in node.get_children():freeze(child)
func snap(path:String)->void:
    await process_frame;await process_frame;await RenderingServer.frame_post_draw
    var img:Image=root.get_texture().get_image()
    var error:int=img.save_png(path)
    if error!=OK:push_error("Capture failed "+path);quit(3)
func run()->void:
    create_timer(25.0,true,false,true).timeout.connect(func()->void:
        if not complete:push_error("Flight fixed-frame watchdog");quit(2))
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts/polish-flight"))
    root.size=Vector2i(1200,720);root.content_scale_size=root.size
    var context:=Context.new();root.add_child(context)
    var board:=Board.new();context.add_child(board)
    var phases:Array[float]=[.05,.30,.63,.96]
    var directions:Array[Vector2]=[Vector2.RIGHT,Vector2.UP,Vector2.DOWN]
    for row:int in 3:
        for col:int in 4:
            var actor:=Probe.new();actor.game=context;actor.dash_direction=directions[row]
            actor.velocity=directions[row]*520;actor.dash_timer=.17*(1-phases[col]);actor.frame=mini(3,int(phases[col]*4))
            actor.position=Vector2(col*300+150,row*220+175);actor.scale=Vector2(2,2)
            board.add_child(actor)
            var wing:=Wings.new();actor.add_child(wing);wing.set_process(false);wing._process(0)
            actor.queue_redraw();wing.queue_redraw()
    await snap("res://artifacts/polish-flight/after-phase-contact.png")
    board.queue_free();await process_frame
    var fold_board:=Board.new();fold_board.fold=true;context.add_child(fold_board)
    for row:int in 2:
        for col:int in 4:
            var actor:=Probe.new();actor.game=context;actor.animation_state="air_jump";actor.frame=col
            actor.dash_timer=0;actor.dash_direction=Vector2.UP if row==0 else Vector2.DOWN
            actor.velocity=actor.dash_direction*200;actor.wing_amount=[0.0,.04,.10,.70][col]
            actor.position=Vector2(col*300+150,row*220+175);actor.scale=Vector2(2,2)
            fold_board.add_child(actor)
            var wing:=Wings.new();actor.add_child(wing);wing.set_process(false);wing._process(0)
            actor.queue_redraw();wing.queue_redraw()
    await snap("res://artifacts/polish-flight/after-fold-contact.png")
    context.queue_free();await process_frame
    root.size=Vector2i(800,450);root.content_scale_size=root.size
    AudioServer.set_bus_mute(0,true)
    for key:String in ["bellkeep_room","bellkeep_checkpoint","bellkeep_elite","bellkeep_shards","bellkeep_doors","bellkeep_weapon"]:
        if has_meta(key):remove_meta(key)
    var game:Node=load("res://main.tscn").instantiate();root.add_child(game);current_scene=game
    freeze(game);game.music.stop_score();game._announcement_time=0
    var actor:CharacterBody2D=game.player
    actor.position=Vector2(500,180);actor.velocity=Vector2(520,0);actor.facing=1
    actor.invuln=0;actor.impact_flash=0;actor.animation_state="dash";actor.dash_direction=Vector2.RIGHT
    actor.wing_amount=0;actor.wing_flap=0
    game._camera.position=game.camera_target(actor.position,1);game._camera.force_update_scroll()
    for i:int in 3:
        var p:float=[.05,.63,.96][i]
        actor.dash_timer=.17*(1-p);actor.frame=mini(3,int(p*4))
        actor.wings._process(0);actor.wings.queue_redraw();actor.queue_redraw()
        game._refresh_hud();game._hud._line_clock=99;game._hud.queue_redraw()
        await snap("res://artifacts/polish-flight/after-"+["onset","drive","glide"][i]+".png")
    var record:FileAccess=FileAccess.open("res://artifacts/polish-flight/capture-manifest.json",FileAccess.WRITE)
    record.store_string(JSON.stringify({"static_only":true,"input_playback":false,"music_running":game.music.running,"player_physics":actor.is_physics_processing(),"renderer":RenderingServer.get_video_adapter_name(),"viewport":[800,450],"phases":[.05,.63,.96]},"  ")+"\n")
    complete=true;game.queue_free();await process_frame;print("Flight static phases captured");quit(0)
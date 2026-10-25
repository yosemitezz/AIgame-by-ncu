extends Node
## Main-scene chapter adapter. Combat and music remain the existing authorities.
const Story=preload("res://flow/chapter_story.gd")
const Save=preload("res://flow/chapter_save.gd")
const Eye=preload("res://presentation/flying_eye.gd")
const Aura=preload("res://presentation/corruption_aura.gd")
const Overlay=preload("res://ui/chapter_overlay.gd")
const SAVE_PATH:String="res://.local/chapter-save.json"
const STORY_META:String="bellkeep_story"
var game:Node
var state:RefCounted
var eye:Node2D
var aura:Node2D
var overlay:Control
var enabled:bool=true
var persist:bool=true
var _locked:bool=false
var _interact_guard:int=-1
var _last_room:String=""
var _last_position:Vector2=Vector2.ZERO
var _moved:float=0.0
var _shock:float=0.0
var _saved_score:float=-1.0
var _reengage:float=0.0
var _reengage_from:Vector2
var _reengage_to:Vector2
var _pending_unlock:bool=false
var _returning:bool=false
var _last_node:String=""
var telemetry:Array[Dictionary]=[]

static func _option(game_node:Node,key:String,fallback:Variant)->Variant:
    for property:Dictionary in game_node.get_property_list():
        if str(property.get("name",""))==key:return game_node.get(key)
    return fallback

static func valid_snapshot(value:Variant)->bool:
    if not value is Dictionary or value.is_empty():return false
    var validator:RefCounted=Story.new()
    var cursor:Variant=value.get("cursor",{})
    if not cursor is Dictionary:return false
    if bool(cursor.get("blocking",false)) and not validator.data.get("nodes",{}).has(str(cursor.get("node",""))):return false
    return validator.restore(value)

static func restore_run(game_node:Node,path:String=SAVE_PATH)->void:
    if not bool(_option(game_node,"chapter_enabled",OS.get_environment("BELLKEEP_DISABLE_STORY")!="1")):return
    if not bool(_option(game_node,"chapter_persist",true)):return
    var tree:SceneTree=game_node.get_tree()
    # Scene retries keep the live snapshot; disk is only consulted on a fresh app.
    if tree.has_meta(STORY_META):return
    var saved:Dictionary=Save.read(path)
    if saved.is_empty():return
    var story:Dictionary=saved["story"]
    var validator:RefCounted=Story.new()
    if not valid_snapshot(story) or not validator.restore(story):return
    var progress:Dictionary=saved["progress"]
    # Disk saves are checkpoint saves, not a serialized live Boss director.
    # A quit during rescue re-enters the Boss checkpoint with once-flags intact.
    if str(progress.get("room","dungeon"))=="boss" and not bool(story.get("chapter_complete",false)):
        story=validator.prepare_retry()
    tree.set_meta(STORY_META,story)
    tree.set_meta("bellkeep_checkpoint",bool(progress.get("checkpoint",false)))
    tree.set_meta("bellkeep_elite",bool(progress.get("elite",false)))
    tree.set_meta("bellkeep_doors",progress.get("doors",[]) if progress.get("doors",[]) is Array else [])
    var collected:Dictionary={}
    for index:Variant in progress.get("shards",[]):
        if (index is int or index is float) and int(index)>=0 and int(index)<64:collected[int(index)]=true
    tree.set_meta("bellkeep_shards",collected)
    var room:String=str(progress.get("room","dungeon"))
    if room not in ["dungeon","boss"]:room="dungeon"
    if bool(story.get("chapter_complete",false)) and bool(story.get("ending_dismissed",false)):room="dungeon"
    tree.set_meta("bellkeep_room",room)
    tree.set_meta("bellkeep_chapter_complete",bool(story.get("chapter_complete",false)))
    var weapon:String=str(progress.get("weapon","light"))
    if weapon in ["light","heavy","great"]:tree.set_meta("bellkeep_weapon",weapon)

func configure(owner_game:Node,options:Dictionary={})->void:
    game=owner_game
    enabled=bool(options.get("enabled",_option(game,"chapter_enabled",OS.get_environment("BELLKEEP_DISABLE_STORY")!="1")))
    persist=bool(options.get("persist",_option(game,"chapter_persist",true)))
    process_mode=Node.PROCESS_MODE_ALWAYS
    set_process(false)
    if not enabled:return
    state=Story.new()
    var candidate:Variant=game.get_tree().get_meta(STORY_META,{})
    var saved:Dictionary=candidate if candidate is Dictionary else {}
    var restored:bool=valid_snapshot(saved) and state.restore(saved)
    state.configure({},options)
    _last_room=str(game.get("room_id"))
    _last_position=game.player.global_position
    eye=Eye.new();eye.name="FlyingEye";game.add_child(eye);eye.configure(game,game.player)
    aura=Aura.new();aura.name="ChapterCorruption";game.add_child(aura);aura.configure(game.player)
    var canvas:=CanvasLayer.new();canvas.name="ChapterCanvas";canvas.layer=40;game.add_child(canvas)
    overlay=Overlay.new();overlay.name="ChapterOverlay";canvas.add_child(overlay)
    state.event("room_changed",{"room":_last_room})
    if state.chapter_complete:
        game.get_tree().set_meta("bellkeep_chapter_complete",true)
        if not state.ending_dismissed:
            game.outcome="victory"
            game._room_prepare=0.0
    state.synchronize_commands()
    if not restored:state.begin_chapter()
    _drain()
    refresh()
    save()

func blocked()->bool:
    return enabled and (_locked or _reengage>0.0 or (state!=null and (state.blocking or state.narrative_dead)))

func consume_interact_guard()->bool:
    return enabled and Engine.get_physics_frames()<=_interact_guard

func tick(delta:float)->void:
    if not enabled or state==null:return
    var paused:bool=bool(game.get("_paused")) or game.get_tree().paused
    var transporting:bool=bool(game.room_flow.active) or float(game.get("_room_prepare"))>0.0
    if str(game.get("room_id"))!=_last_room:
        _last_room=str(game.get("room_id"));state.event("room_changed",{"room":_last_room})
        _last_position=game.player.global_position
        if is_instance_valid(eye):eye.snap_to_hero()
        save()
    state.tick(delta,paused,transporting)
    _drain()
    var current_node:String=str(state.presentation().get("node_id",""))
    if current_node!=_last_node:
        _last_node=current_node
        save()
    if not paused and not transporting:
        _shock=maxf(0.0,_shock-delta)
        if _shock<=0.0 and is_instance_valid(game.get("boss")) and game.boss.has_meta("chapter_pose"):
            game.boss.remove_meta("chapter_pose")
        _animate_reengage(delta)
        if not blocked() and str(game.get("outcome"))=="" and not bool(game.player.dead):_actual_operations()
    refresh()

func _actual_operations()->void:
    var at:Vector2=game.player.global_position
    var traveled:float=at.distance_to(_last_position)
    var requested:float=Input.get_axis("move_left","move_right") if InputMap.has_action("move_left") and InputMap.has_action("move_right") else 0.0
    if traveled<80.0 and absf(requested)>0.0 and float(game.player.get("_hurt_lock"))<=0.0:_moved+=traveled
    _last_position=at
    if _moved>=24.0:event("move")
    # Jump teaching is notified from the real player jump/air_jump effect hook;
    # upward knockback is deliberately not treated as a jump.
    if float(game.player.dash_timer)>0.0:event("dodge")
    if bool(game.player.climbing):event("climbed")

func event(id:String,context:Dictionary={})->bool:
    if not enabled or state==null:return false
    var accepted:bool=state.event(id,context)
    _drain();refresh()
    if accepted:save()
    return accepted

func try_rescue(amount:int,origin:Vector2,allow:bool=true)->bool:
    if not enabled or state==null or not allow or amount<=0 or bool(game.get("_paused")) or game.get_tree().paused:return false
    if str(game.get("room_id"))!="boss" or not bool(game.get("boss_started")) or bool(game.get("story_safe")) or str(game.get("outcome"))!="":return false
    if bool(game.room_flow.active) or float(game.get("_room_prepare"))>0.0:return false
    if not is_instance_valid(game.get("boss")) or bool(game.boss.dead):return false
    if bool(game.player.dead) or float(game.player.invuln)>0.0 or amount<int(game.player.health):return false
    if not state.can_rescue(true,true):return false
    if not state.request_rescue({"in_boss":true,"lethal":true}):return false
    game.player.health=1;game.player.health_changed.emit(1,game.player.max_health)
    game.player.impact_flash=0.0
    game.player._set_animation("hurt",0.0);game.player.frame=2
    _drain();refresh();save()
    telemetry.append({"kind":"real_boss_lethal_intercept","chart_time":_chart_time(),"origin":origin})
    return true

func on_boss_defeated()->void:
    if not enabled or state==null:return
    game.get_tree().set_meta("bellkeep_chapter_complete",true)
    state.boss_defeated();_drain();refresh();save()

func _drain()->void:
    if state==null:return
    var commands:Array[Dictionary]=state.take_commands()
    for item:Dictionary in commands:
        match str(item.get("command","")):
            "narrative_lock":_lock(str(item.get("data",{}).get("scene","")))
            "rescue_restore":_restore_hero()
            "boss_shock":_boss_shock()
            "narrative_unlock":_unlock()
            "chapter_complete":game.get_tree().set_meta("bellkeep_chapter_complete",true)
            "narrative_death":
                game.outcome="victory"
                game.get_tree().set_meta("bellkeep_chapter_complete",true)
                _lock("completed_narrative_death")
    # Only save after the once-only effects have been consumed.
    if not commands.is_empty():save()

func _set_lock(value:bool)->void:
    _locked=value
    for property:Dictionary in game.get_property_list():
        if str(property.get("name",""))=="chapter_locked":game.set("chapter_locked",value);break

func _lock(scene:String)->void:
    if not _locked:
        _saved_score=_chart_time()
        telemetry.append({"kind":"narrative_cleanup","scene":scene,"chart_time":_saved_score,"reason":"narrative safety: old attacks canceled, not replayed"})
    _set_lock(true)
    game.music.set_score_paused(true)
    game.set_story_safe(true)
    game.player.reset_direction_taps();game.player.reset_traversal();game.player._cancel_attack();game.player._clear_parry()
    game.player.dash_timer=0.0;game.player.velocity=Vector2.ZERO;game.player.set_physics_process(false)
    if is_instance_valid(game.get("boss")) and not bool(game.boss.dead):
        game.boss._cancel_all_attacks();game.boss.velocity=Vector2.ZERO;game.boss.set_physics_process(false)
    if is_instance_valid(game.get("_motion_fx")):game._motion_fx.clear()
    game._portal_confirm_room=""
    if state!=null and str(state.phase) in ["aftermath","betrayal"]:
        game.player._set_animation("hurt",0.0);game.player.frame=1

func _uses_flight_room()->bool:
    var level:Node=game.get("level")
    if not is_instance_valid(level):return false
    var script:Script=level.get_script()
    return script!=null and script.resource_path=="res://levels/boss_room.gd"

func _recovery_position(at:Vector2)->Vector2:
    # The lethal contact already occurred at a valid flight position. Narrative
    # locking freezes that position; do not teleport back into the old arena.
    if _uses_flight_room():return at
    return Vector2(clampf(at.x,2680.0,3310.0),300.0)

func _restore_hero()->void:
    if not is_instance_valid(game.player) or bool(state.chapter_complete):return
    var at:Vector2=_recovery_position(game.player.global_position)
    game.player.revive(at)
    game.player.health=maxi(1,int(ceil(float(game.player.max_health)*0.5)))
    game.player.invuln=0.7
    game.player.velocity=Vector2.ZERO
    game.player.set_physics_process(false)
    game.player.health_changed.emit(game.player.health,game.player.max_health)
    if is_instance_valid(game.get("boss")):game.player.facing=1 if game.boss.position.x>=at.x else -1
    if is_instance_valid(eye):eye.snap_to_hero()
    telemetry.append({"kind":"rescue_restore","chart_time":_chart_time(),"health":game.player.health})

func _boss_shock()->void:
    if not is_instance_valid(game.get("boss")) or bool(game.boss.dead):return
    _shock=0.65
    game.boss.set_meta("chapter_pose",{"state":"hurt","progress":0.55,"strike":0,"armored":false,"contact_serial":-1})
    _reengage=0.16
    _reengage_from=game.player.global_position
    _reengage_to=_reengage_from+Vector2(float(game.player.facing)*12.0,0)
    if not _uses_flight_room():_reengage_to.x=clampf(_reengage_to.x,2680.0,3310.0)
    if game.player.is_inside_tree():
        var ray:=PhysicsRayQueryParameters2D.create(_reengage_from+Vector2(0,-13),_reengage_to+Vector2(0,-13),1)
        if not game.player.get_world_2d().direct_space_state.intersect_ray(ray).is_empty():_reengage_to=_reengage_from
    game.player._set_animation("dash",0.0);game.player.frame=1

func _animate_reengage(delta:float)->void:
    if _reengage<=0.0:return
    _reengage=maxf(0.0,_reengage-delta)
    var t:float=1.0-_reengage/0.16
    game.player.global_position=_reengage_from.lerp(_reengage_to,smoothstep(0.0,1.0,t))
    game.player.queue_redraw()
    if _reengage<=0.0 and _pending_unlock:
        _pending_unlock=false;_unlock()

func _unlock()->void:
    if _reengage>0.0:_pending_unlock=true;return
    _set_lock(false)
    _interact_guard=Engine.get_physics_frames()+1
    var safe:bool=str(game.get("outcome"))!="" or str(game.music.current_section)=="rest" or bool(game.room_flow.active) or float(game.get("_room_prepare"))>0.0
    game.set_story_safe(safe)
    var world_wait:bool=bool(game.room_flow.active) or float(game.get("_room_prepare"))>0.0 or str(game.get("outcome"))!=""
    if not world_wait and not bool(game.player.dead):
        game.player.set_physics_process(true);game.player.reset_direction_taps();game.player._refresh_animation(0.0)
    if is_instance_valid(game.get("boss")) and not bool(game.boss.dead):
        if game.boss.has_meta("chapter_pose"):game.boss.remove_meta("chapter_pose")
        _shock=0.0
        if not world_wait:game.boss.set_physics_process(true)
    game.music.set_score_paused(bool(game.get("_paused")))
    if _saved_score>=0.0:
        telemetry.append({"kind":"narrative_resume","before":_saved_score,"after":_chart_time()});_saved_score=-1.0
    if is_instance_valid(eye):eye.snap_to_hero()

func handle_input(input:InputEvent)->bool:
    if not enabled or state==null or not input is InputEventKey or not input.pressed or input.echo:return false
    if bool(game.get("_paused")):return false
    # Completed narrative replay must never intercept an ordinary dungeon defeat.
    if bool(game.player.dead) or str(game.get("outcome"))=="defeat":return false
    var key:int=input.physical_keycode if input.physical_keycode!=0 else input.keycode
    if state.blocking:
        if key in [KEY_E,KEY_ENTER,KEY_KP_ENTER]:state.advance();_interact_guard=Engine.get_physics_frames()+1;_drain();refresh();save();return true
        if key==KEY_BACKSPACE:state.skip();_interact_guard=Engine.get_physics_frames()+1;_drain();refresh();save();return true
        return false
    if bool(state.chapter_complete) and key==KEY_V and not bool(game.room_flow.active):
        state.replay_ending();_drain();refresh();save();return true
    if bool(state.narrative_dead) and key in [KEY_E,KEY_ENTER,KEY_KP_ENTER,KEY_R]:return_to_dungeon();return true
    if bool(state.chapter_complete) and key==KEY_R:return_to_dungeon();return true
    return false

func return_to_dungeon()->bool:
    if not enabled or not state.chapter_complete or state.blocking or bool(game.room_flow.active):return false
    if bool(game.player.dead) or str(game.get("outcome"))=="defeat":return false
    if state.narrative_dead and not state.dismiss_completed():return false
    _drain();_set_lock(false)
    game.outcome="victory"
    _interact_guard=Engine.get_physics_frames()+1
    var moved:bool=true
    if str(game.get("room_id"))=="boss":moved=game.begin_room_transition("dungeon")
    else:
        game.outcome="";game.set_story_safe(false);game.player.set_physics_process(true)
    _returning=true;refresh();save()
    return moved

func prepare_reload(full:bool)->void:
    if not enabled or state==null:return
    if full:
        if game.get_tree().has_meta(STORY_META):game.get_tree().remove_meta(STORY_META)
        if persist:Save.erase(SAVE_PATH)
    else:
        var saved:Dictionary=state.prepare_retry()
        game.get_tree().set_meta(STORY_META,saved)
        if persist:Save.write(SAVE_PATH,saved,_progress())
    if is_instance_valid(overlay):overlay.set_suspended(true)

func set_paused(value:bool)->void:
    if not enabled:return
    if state!=null:
        state.tick(0.0,value,bool(game.room_flow.active) or float(game.get("_room_prepare"))>0.0)
    if is_instance_valid(overlay):overlay.set_suspended(value)
    if is_instance_valid(game.get("music")):game.music.set_score_paused(value or blocked())

func _chart_time()->float:
    if not is_instance_valid(game.get("music")):return 0.0
    return float(game.music.get_chart_time()) if game.music.has_method("get_chart_time") else float(game.music.get_score_time())

func presentation()->Dictionary:
    return state.presentation() if enabled and state!=null else {}

func refresh()->void:
    if not enabled or state==null:return
    var shown:Dictionary=state.presentation()
    if is_instance_valid(eye):eye.update_story(shown)
    if is_instance_valid(aura):aura.update_story(shown)
    if is_instance_valid(overlay):overlay.update_state(shown)

func _progress()->Dictionary:
    var tree:SceneTree=game.get_tree()
    return {"checkpoint":bool(tree.get_meta("bellkeep_checkpoint",false)),"elite":bool(tree.get_meta("bellkeep_elite",false)),
        "doors":tree.get_meta("bellkeep_doors",[]),"shards":tree.get_meta("bellkeep_shards",{}).keys(),
        "room":str(game.get("room_id")),"weapon":str(game.player.weapon)}

func save()->void:
    if not enabled or state==null or not is_instance_valid(game):return
    var snapshot:Dictionary=state.snapshot()
    game.get_tree().set_meta(STORY_META,snapshot)
    if persist:Save.write(SAVE_PATH,snapshot,_progress())
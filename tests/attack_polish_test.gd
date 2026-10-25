extends SceneTree
## Real-profile rendering and short contact lifetimes, no encounter playback.
const FX=preload("res://vfx/fx_layer.gd")
const Profile=preload("res://combat/attack_profile.gd")
var passed:int=0
var failed:int=0
class Actor extends Node2D:
    var weapon:String="light"
    var combo:int=3
    var facing:int=1
    var dead:bool=false
    var frame:int=4
    var animation_state:String="attack"
    var attack_phase:String="active"
    var attack_serial:int=1
    var attack_sweep_from:float=.45
    var attack_sweep_to:float=.55
    var attack_previous_position:Vector2=Vector2.ZERO
    var progress:float=.55
    func get_attack_progress()->float:return progress
class MovementOwner extends Node:
    func is_movement_trail_owner()->bool:return true
class Game extends Node:
    signal vfx_requested(kind:String,at:Vector2,direction:Vector2,power:float)
    signal warning_issued(kind:String,at:Vector2,duration:float)
    var player:Node2D
    var boss:Node2D
    var story_safe:bool=false
    var _paused:bool=false
    var _overlay:String=""
func check(ok:bool,label:String)->void:
    if ok:passed+=1;print("PASS ",label)
    else:failed+=1;push_error("FAIL "+label)
func _initialize()->void:call_deferred("run")
func run()->void:
    var game:=Game.new();root.add_child(game)
    var actor:=Actor.new();game.add_child(actor);game.player=actor
    var fx:=FX.new();game.add_child(fx);fx.setup(game);fx.set_process(false)
    for wid:String in ["light","heavy","great"]:
        actor.weapon=wid;Profile.set_weapon(wid);actor.attack_serial+=1
        fx.clear_hostile();actor.attack_phase="active"
        actor.attack_sweep_from=.45;actor.attack_sweep_to=.55;actor.progress=.55
        fx.spawn("slash",actor.global_position,Vector2.RIGHT,3.0)
        check(fx._shapes.size()==1 and fx._shapes[0].get("type")=="profile",wid+" empty swing has one boundary stroke and no contact burst")
        var shape:Dictionary=fx._shapes[0]
        check(shape["polygon"]==Profile.world_polygon(actor,.45,.55),wid+" visible primary contour still uses exact damaging geometry")
        var chips:int=fx._parts.size()
        var points:PackedVector2Array=shape["polygon"].duplicate()
        for i:int in 8:fx._sync_slash(shape)
        check(fx._parts.size()==chips and shape["polygon"]==points,wid+" actor-local hold neither advances ink nor emits repeated fragments")
        var active:Dictionary=fx.profile_ink_state(shape)
        check(active["active"] and active["opacity"]==1.0 and not active["closed_outline"] and not active["wide_fill"],wid+" active effect keeps a readable core without wire-box or opaque area")
        actor.attack_phase="recover";fx._sync_slash(shape)
        var recovery:Dictionary=fx.profile_ink_state(shape)
        shape["tail_age"]=FX.SLASH_TAIL_LIFE*.5
        var later:Dictionary=fx.profile_ink_state(shape)
        shape["tail_age"]=FX.SLASH_TAIL_LIFE
        check(float(recovery["opacity"])<=.16 and float(later["opacity"])<float(recovery["opacity"]) and fx.profile_ink_state(shape)["opacity"]==0.0,wid+" afterglow quickly contracts to zero within75ms")
        # Recovery deliberately detached this shape into a world-fixed tail.
        # Test cancellation on a fresh bound active shape, as the runtime does.
        actor.attack_phase="active";actor.attack_serial+=1
        fx.clear_hostile();fx.spawn("slash",actor.global_position,Vector2.RIGHT,3.0)
        var cancelled:Dictionary=fx._shapes[0]
        actor.attack_phase="none"
        check(not fx._sync_slash(cancelled),wid+" cancellation cannot leave a live primary blade")
    actor.weapon="great";Profile.set_weapon("great");actor.attack_phase="active"
    var full:PackedVector2Array=Profile.world_polygon(actor,.25,1.0)
    var origin:Vector2=actor.global_position+Profile.origin()
    var closed:PackedVector2Array=fx.profile_outer_edge(full,origin)
    check(closed.size()==full.size()+1 and closed[0]==full[0] and closed[closed.size()-1]==closed[0],"completed full-circle contour retains every actual outer point and closing segment")
    var partial:PackedVector2Array=Profile.world_polygon(actor,.45,.55)
    var open:PackedVector2Array=fx.profile_outer_edge(partial,origin)
    check(open.size()==partial.size()-1 and open[0]!=open[open.size()-1],"partial circular sweep remains open instead of becoming a complete ring")
    for wid:String in ["light","heavy","great","wave"]:
        fx.clear_hostile()
        var at:=Vector2(120,90)
        fx.spawn("weapon_hit_"+wid,at,Vector2.RIGHT,1.0)
        check(fx._shapes.size()==1 and fx._shapes[0]["type"]=="weapon_contact" and fx._shapes[0]["at"]==at,wid+" contact core is anchored to the supplied real point")
        var core:Dictionary=fx._shapes[0]
        check(float(core["max"])<=.18 and fx._parts.size()<=7,wid+" impact is a bounded short burst rather than a large hit halo")
        var count:int=fx._parts.size()
        fx.spawn("weapon_hit_"+wid,at,Vector2.RIGHT,1.0)
        check(fx._shapes.size()==1 and fx._parts.size()==count,wid+" duplicate same-contact visual is not doubled")
    fx.clear_hostile();game.story_safe=true
    fx.spawn("weapon_hit_heavy",Vector2.ZERO,Vector2.RIGHT,1.0)
    check(fx._shapes.is_empty() and fx._parts.is_empty(),"rest rejects new hit decorations")
    game.story_safe=false;game._paused=true
    fx.spawn("weapon_hit_heavy",Vector2.ZERO,Vector2.RIGHT,1.0)
    check(fx._shapes.is_empty(),"pause rejects new contact visuals")
    game._paused=false
    for i:int in 200:
        fx.spawn("weapon_hit_heavy",Vector2(i*8,0),Vector2.RIGHT,1.0)
    check(fx._shapes.size()<=FX.MAX_SHAPES and fx._parts.size()<=FX.MAX_PARTS and fx._weapon_contacts.size()<=16,"long fights retain bounded effect, particle and dedup storage")
    fx.clear_hostile()
    check(fx._shapes.is_empty() and fx._parts.is_empty() and fx._weapon_contacts.is_empty(),"room/rest cleanup clears all new contact state")
    var movement:=MovementOwner.new();movement.name="MotionBlur";game.add_child(movement)
    actor.animation_state="dash";actor.attack_phase="none"
    fx._ghost(actor,"hero",Color.WHITE,.3,.15)
    check(fx._ghosts.is_empty(),"dedicated movement owner prevents old dash afterimages from doubling")
    actor.animation_state="attack";actor.attack_phase="active"
    fx._ghost(actor,"hero",Color.WHITE,.3,.15)
    check(fx._ghosts.size()==1,"dedicated movement owner preserves the attack afterimage")
    fx.clear_hostile()
    var hostile:=Actor.new();game.add_child(hostile);game.boss=hostile
    hostile.animation_state="dash";hostile.attack_phase="none"
    fx._ghost(hostile,"boss",Color.WHITE,.3,.15)
    check(fx._ghosts.size()==1 and fx._ghosts[0].kind=="boss","hero movement ownership does not suppress Boss dash afterimages")
    fx.clear_hostile()
    check(Engine.time_scale==1.0,"VFX never changes the music time scale")
    Profile.set_weapon("light");game.queue_free();await process_frame
    print("Attack polish: %d passed, %d failed"%[passed,failed]);quit(1 if failed else 0)
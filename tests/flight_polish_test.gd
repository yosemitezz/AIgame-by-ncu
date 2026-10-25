extends SceneTree
## Actual flight staging and geometry. Bounded fixtures; no input playback.
const Renderer=preload("res://presentation/actor_renderer.gd")
const Wings=preload("res://vfx/light_wings.gd")
var passed:int=0
var failed:int=0
class Context extends Node:
    var story_safe:bool=false
class Actor extends Node2D:
    var game:Node
    var wing_amount:float=0.0
    var wing_flap:float=0.0
    var velocity:Vector2=Vector2.RIGHT*520
    var dash_timer:float=.17
    var dash_direction:Vector2=Vector2.RIGHT
    var airborne:bool=true
    var facing:int=1
    var frame:int=0
    var animation_state:String="dash"
    var weapon:String="light"
    var combo:int=1
    var dead:bool=false
    var invuln:float=0.0
    func is_on_floor()->bool:return not airborne
func check(ok:bool,label:String)->void:
    if ok:passed+=1
    else:failed+=1;push_error("FAIL "+label)
func v(a:Array)->Vector2:return Vector2(float(a[0]),float(a[1]))
func _initialize()->void:call_deferred("run")
func run()->void:
    var context:=Context.new();root.add_child(context)
    var actor:=Actor.new();actor.game=context;context.add_child(actor)
    var wing:=Wings.new();actor.add_child(wing);wing.set_process(false)
    var hero:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://presentation/feel_frames/manifest.json"))["hero"]
    check(int(hero["total_frames"])==167 and Renderer.HERO_ANCHOR==Vector2(66,108),"no index, canvas or foot-anchor changes")
    var directions:Dictionary={"air_dash_side":Vector2.RIGHT,"air_dash_up":Vector2.UP,"air_dash_down":Vector2.DOWN}
    for wid:String in ["light","heavy","great"]:
        var clips:Dictionary=hero["weapons"][wid]["flight_pose_joints"]
        for key:String in directions:
            var poses:Array=clips[key]
            var upright:bool=true
            var aligned:bool=true
            for pose:Dictionary in poses:
                upright=upright and float(pose["rotation_degrees"])==0.0 and v(pose["head"]).y<v(pose["hip"]).y-12
                aligned=aligned and (v(pose["weapon_tip"])-v(pose["hand"])).normalized().dot(directions[key])>0.65
            check(upright,wid+" "+key+" never rolls/inverts")
            check(aligned,wid+" "+key+" blade follows flight direction")
            var first:Vector2=v(poses[0]["head"])-v(poses[0]["hip"])
            var drive:Vector2=v(poses[2]["head"])-v(poses[2]["hip"])
            check(first.distance_to(drive)>4,wid+" "+key+" commits distinct whole-body weight instead of repeating a stamp")
    check(str(hero["weapons"]["light"]["weapon_design"])=="rapier" and str(hero["weapons"]["heavy"]["weapon_design"])=="iron_slab" and str(hero["weapons"]["great"]["weapon_design"])=="long_crossblade","three weapons have distinct constructed forms")
    check(float(hero["weapons"]["heavy"]["max_blade_width_source_px"])>float(hero["weapons"]["light"]["max_blade_width_source_px"])*5.0,"iron cleaver is a broad slab rather than a recoloured rapier")
    check(float(hero["weapons"]["great"]["grip_length_source_px"])>float(hero["weapons"]["heavy"]["grip_length_source_px"])+2.0,"two-handed orbit sword retains its own long-grip silhouette")
    for wid:String in ["light","heavy","great"]:
        var carry:bool=true
        for state:String in ["jump","apex","fall","air_jump"]:
            for pose:Dictionary in hero["weapons"][wid]["flight_pose_joints"][state]:
                carry=carry and v(pose["weapon_tip"]).x<v(pose["hand"]).x-8.0
        check(carry,wid+" free-air sword trails naturally behind the hand")
    for combo:int in [1,2,3]:
        var aligned:bool=true
        var tips:Array=hero["weapons"]["light"]["weapon_tips"]["air_cut_%d_attack" % combo]
        for index:int in range(2,8):
            aligned=aligned and absf(float(tips[index][1])+24.0)<7.0
        check(aligned,"airborne rapier contact steel follows the actual narrow thrust centre: "+str(combo))
    var onset:Dictionary=Wings.phase_profile(.08)
    var drive:Dictionary=Wings.phase_profile(.60)
    var settle:Dictionary=Wings.phase_profile(.96)
    check(onset["stage"]=="spread" and drive["stage"]=="drive" and settle["stage"]=="glide","one original dodge has spread/drive/glide phases")
    check(float(onset["fan"])>float(drive["fan"])+.35 and float(settle["fan"])>float(drive["fan"])+.2,"wing fan visibly changes shape before and after compression")
    check(float(drive["drive"])>float(onset["drive"])+.4 and float(drive["drive"])>float(settle["drive"])+.4,"tail/wing pressure peaks in drive, never at both ends")
    for dir:Vector2 in [Vector2.RIGHT,Vector2.LEFT,Vector2.UP,Vector2.DOWN]:
        actor.dash_direction=dir;actor.dash_timer=.17*(1-.6);actor.frame=2
        var state:Dictionary=Wings.presentation_state(actor)
        check(state["direction"]==dir and is_equal_approx(float(state["progress"]),.6),"actual physics clock/direction route "+str(dir))
        for near:bool in [false,true]:
            var shape:Dictionary=Wings.wing_shape(state,near)
            check(shape["feathers"].size()==6 and Vector2(shape["elbow"]).distance_to(Vector2(shape["wrist"]))>6,"separate elbow/wrist and feather roots "+str(dir)+str(near))
            var behind:bool=true
            for polygon:PackedVector2Array in shape["feathers"]:
                for point:Vector2 in polygon:behind=behind and point.dot(-dir)>-2 and point.length()<58
            check(behind,"bounded wing stays behind motion and away from face "+str(dir)+str(near))
    var simple:bool=true
    for progress:float in [.05,.3,.63,.96]:
        for dir:Vector2 in [Vector2.LEFT,Vector2.RIGHT,Vector2.UP,Vector2.DOWN]:
            actor.dash_timer=.17*(1-progress);actor.dash_direction=dir
            var state:Dictionary=Wings.presentation_state(actor)
            for near:bool in [false,true]:
                var shape:Dictionary=Wings.wing_shape(state,near)
                for amount:float in [.001,.03,.2,.5,1.0]:
                    var points:PackedVector2Array=PackedVector2Array()
                    for p:Vector2 in shape["coverts"]:points.append((p*amount).round())
                    var hull:PackedVector2Array=Wings.pixel_hull(points)
                    simple=simple and (hull.is_empty() or not Geometry2D.triangulate_polygon(hull).is_empty())
    check(simple,"quantized wing fold never submits a self-crossing or degenerate polygon")
    var before:Array=[actor.velocity,actor.dash_timer,actor.wing_amount,actor.wing_flap,actor.dash_direction]
    wing._process(.016)
    check(before==[actor.velocity,actor.dash_timer,actor.wing_amount,actor.wing_flap,actor.dash_direction],"presentation never writes player physics/wing game state")
    var clock:float=wing._clock;paused=true;wing._process(.05)
    check(wing._clock==clock,"paused flight animation holds, independent of UI clock")
    paused=false
    actor.dash_timer=0;wing._process(.11)
    check(wing._dash_tail==0.0,"small wake fully decays within100ms")
    actor.airborne=false;actor.wing_amount=0
    check(float(Wings.presentation_state(actor)["open"])==0.0,"ground dash does not acquire flight wings")
    actor.airborne=true;actor.dash_timer=.15;context.story_safe=true;wing._process(.01)
    check(not wing.visible and wing._dash_tail==0.0,"story safety/room transfer clears wing wake immediately")
    context.story_safe=false;actor.dead=true
    check(float(Wings.presentation_state(actor)["open"])==0.0,"death never preserves forced spread")
    check(Wings.MAX_TAIL_LENGTH<=26 and is_equal_approx(Engine.time_scale,1.0),"short trail and untouched musical clock")
    context.queue_free();await process_frame
    print("Flight polish: %d passed, %d failed" % [passed,failed])
    quit(1 if failed else 0)
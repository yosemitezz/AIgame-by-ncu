extends SceneTree
## Bounded movement fixtures. Existing infinite air jumps/wings are retained, not introduced here.
const Player = preload("res://actors/player.gd")
var passed: int = 0
var failed: int = 0
var player: CharacterBody2D
var arena: MobilityGame
var level: MobilityLevel

class MobilityLevel extends Node:
    var chain: bool = false
    func climb_at(at: Vector2) -> Dictionary:
        return {"id":"chain","kind":"chain","rect":Rect2(-12,100,24,200)} if chain and Rect2(-12,100,24,200).grow(0.01).has_point(at) else {}
    func water_at(_at: Vector2) -> bool: return false
class MobilityGame extends Node2D:
    signal animation_event(actor:Node,state:String,frame:int,facing:int)
    var story_safe: bool = false
    var _paused: bool = false
    var level: Node
    var effects: Dictionary = {}
    func emit_fx(kind:String,_at:Vector2,_direction:Vector2,_power:float)->void: effects[kind]=int(effects.get(kind,0))+1
    func hero_attack(_source:Node2D,_damage:int,_reach:float,_combo:int)->void: pass
    func on_parry_contact(_defender:Node,_source:Node,_at:Vector2,_kind:String)->void: pass

func check(ok:bool,label:String)->void:
    if ok:
        passed+=1
        print("PASS ",label)
    else:
        failed+=1
        push_error("FAIL "+label+" [pos=%s vel=%s phase=%s]"%[player.global_position,player.velocity,player.attack_phase])
func action(name:String,pressed:bool)->void:
    var edge:InputEventAction=InputEventAction.new()
    edge.action=name
    edge.pressed=pressed
    Input.parse_input_event(edge)
    Input.flush_buffered_events()
func release_all()->void:
    for name:String in ["move_left","move_right","jump","dash","attack","parry","climb_up","climb_down","crouch"]: action(name,false)
func reset(at:Vector2=Vector2(0,300))->void:
    release_all()
    arena.story_safe=false
    arena._paused=false
    level.chain=false
    player.revive(at)
    player.invuln=0.0
    arena.effects.clear()
func tick(count:int=1)->void:
    for _i:int in range(count):
        await physics_frame
        player._physics_process(1.0/60.0)
func _initialize()->void: call_deferred("run")
func run()->void:
    for name:String in ["move_left","move_right","jump","dash","attack","parry","climb_up","climb_down","crouch"]:
        if not InputMap.has_action(name): InputMap.add_action(name)
    arena=MobilityGame.new()
    root.add_child(arena)
    level=MobilityLevel.new()
    arena.add_child(level)
    arena.level=level
    var floor_body:StaticBody2D=StaticBody2D.new()
    var shape:CollisionShape2D=CollisionShape2D.new()
    var rectangle:RectangleShape2D=RectangleShape2D.new()
    rectangle.size=Vector2(2000,24)
    shape.shape=rectangle
    shape.position=Vector2(0,312)
    floor_body.add_child(shape)
    arena.add_child(floor_body)
    player=Player.new()
    player.configure(arena)
    arena.add_child(player)
    player.set_physics_process(false)
    reset()
    await tick(3)
    check(Player.RUN_SPEED==232.0 and Player.DASH_SPEED==520.0,"runtime uses the new single-source mobility tuning")
    check(Player.INFINITE_AIR_JUMPS and is_instance_valid(player.wings),"previously committed infinite air jumps and light wings survive")
    check(Player.HIT_RECOIL_SPEED==[85.0,105.0,140.0],"existing light hit pushback stays unchanged")
    action("move_right",true)
    await tick(6)
    check(absf(player.velocity.x-232.0)<0.1,"ground reaches232px/s within100ms")
    action("move_right",false)
    action("move_left",true)
    await tick(9)
    check(absf(player.velocity.x+232.0)<0.1,"ground reverses full speed within150ms versus the old200ms")
    action("move_left",false)
    await tick(5)
    check(is_zero_approx(player.velocity.x),"ground release brakes to rest within84ms")
    reset(Vector2(0,150))
    await tick(2)
    player.velocity.x=Player.RUN_SPEED
    action("move_left",true)
    await tick(6)
    check(player.velocity.x<0.0,"air steering changes direction within100ms")
    await tick(8)
    check(absf(player.velocity.x+Player.RUN_SPEED)<0.1,"air fully reverses within233ms versus the old288ms")
    reset()
    await tick(3)
    action("jump",true)
    await tick()
    check(player.velocity.y<=-369.0,"ground jump responds on its first physics edge")
    var held_apex:float=player.global_position.y
    for _i:int in range(50):
        await tick()
        held_apex=minf(held_apex,player.global_position.y)
    check(300.0-held_apex>=60.0 and 300.0-held_apex<=76.0,"faster jump preserves level-compatible full height")
    reset()
    await tick(3)
    action("jump",true)
    await tick(2)
    action("jump",false)
    var tap_apex:float=player.global_position.y
    for _i:int in range(35):
        await tick()
        tap_apex=minf(tap_apex,player.global_position.y)
    check(300.0-tap_apex<0.65*(300.0-held_apex),"release gives a clearly shorter controlled hop")
    reset()
    await tick(3)
    player.global_position.x=1100.0
    await tick(4)
    action("jump",true)
    await tick()
    check(int(arena.effects.get("jump",0))==1 and int(arena.effects.get("air_jump",0))==0,"ledge grace produces a ground-authority coyote jump")
    reset(Vector2(0,150))
    await tick(10)
    var air_ok:bool=true
    for _i:int in range(5):
        action("jump",true)
        await tick()
        air_ok=air_ok and player.velocity.y<-330.0
        action("jump",false)
        await tick(2)
    check(air_ok and player._air_jumps==0 and player.wing_amount>0.0,"existing unlimited air presses keep wings and remain responsive")
    reset(Vector2(0,200))
    await tick(10)
    player.global_position=Vector2(0,292)
    player.velocity=Vector2(0,250)
    action("jump",true)
    await tick()
    check(player._jump_buffer>0.0 and player.velocity.y>0.0,"near-floor press buffers for landing instead of wasting a weaker air jump")
    await tick(2)
    check(player.velocity.y<-330.0 and int(arena.effects.get("land",0))>0 and int(arena.effects.get("jump",0))==1 and int(arena.effects.get("air_jump",0))==0,"buffered landing immediately launches through the ground jump authority")
    reset(Vector2(0,270))
    await tick(2)
    action("move_right",true)
    player.velocity.y=350.0
    for _i:int in range(20):
        await tick()
        if player.is_on_floor(): break
    await tick(4)
    check(player.animation_state=="run" and player.velocity.x>220.0,"moving landing hands back to run without the old160ms visual stall")
    reset(Vector2(0,100))
    check(player._start_dash(1.0,Vector2.RIGHT),"first dodge starts")
    check(player.invuln==0.23 and player.dash_timer==0.17,"first dodge retains source movement and immunity duration")
    await tick(11)
    var prior:float=player.invuln
    check(player._start_dash(-1.0,Vector2.LEFT),"a different direction can still link movement after active dodge")
    check(player.invuln==prior and player.dodge_immunity_rearm>0.0,"linked movement does not refresh the first immunity tail")
    await tick(4)
    check(player.invuln==0.0 and player.dash_timer>0.0,"linked dodge has a real vulnerable interval")
    reset(Vector2(0,100))
    var directions:Array[Vector2]=[Vector2.RIGHT,Vector2.LEFT,Vector2.UP,Vector2.DOWN]
    var next:int=0
    var starts:int=0
    var vulnerable:int=0
    for _i:int in range(100):
        if player.dash_timer<=0.0 and player._start_dash(0.0,directions[next%directions.size()]):
            starts+=1
            next+=1
        await tick()
        if player.invuln<=0.0: vulnerable+=1
    check(starts>=8 and vulnerable>=15,"four-direction rotation cannot sustain continuous invulnerability")
    player.revive(Vector2(0,300))
    check(player.dodge_immunity_rearm==0.0 and player._dash_buffer==0.0 and player._jump_buffer==0.0,"room/retry revive clears every new mobility cache")
    reset()
    player.set_impact_freeze(0.08)
    action("move_right",true)
    action("move_right",false)
    action("move_right",true)
    var held:Vector2=player.global_position
    await tick(2)
    check(player._dash_buffer>0 and player.global_position.is_equal_approx(held),"double-tap intent is captured before local hit-stop returns")
    await tick(5)
    check(player.dash_timer>0 and player.velocity.x==Player.DASH_SPEED,"queued dodge releases at the new speed without losing input")
    reset()
    player._start_attack()
    check(not player._start_dash(1.0,Vector2.RIGHT),"faster movement does not bypass committed attack startup")
    player._advance_attack(Player.COMBO_WINDUP[0]+Player.COMBO_ACTIVE[0]+Player.RECOVER_CANCEL_DELAY-0.002)
    check(not player.can_cancel_attack(),"recovery remains committed before its actual release boundary")
    player._advance_attack(0.003)
    check(player._start_dash(1.0,Vector2.RIGHT),"defensive dodge releases at the shorter recovery cancel window")
    reset(Vector2(0,220))
    level.chain=true
    action("climb_up",true)
    await tick()
    action("climb_up",false)
    action("climb_up",true)
    await tick()
    check(player.climbing and player.dash_timer==0.0,"grab plus one grip adjustment cannot accidentally dodge")
    action("climb_up",false)
    action("climb_up",true)
    await tick()
    check(not player.climbing and player.dash_direction==Vector2.UP,"deliberate double-tap while gripping still dodges off the chain")
    check(player._start_parry()==false,"active dodge still rejects a simultaneous parry")
    reset()
    check(player._start_parry() and player.parry_timer==0.16,"left Shift contact parry keeps its existing window")
    check(Engine.time_scale==1.0,"mobility tuning never changes global time")
    release_all()
    arena.free()
    print("PLAYER_MOBILITY_TEST: %d passed, %d failed; run232 dash520 ground_reverse150ms air_reverse233ms"%[passed,failed])
    quit(1 if failed>0 else 0)

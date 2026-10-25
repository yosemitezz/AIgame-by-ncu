extends SceneTree
## Historical pose sampling and cleanup fixtures. No gameplay input or playthrough.
const Service = preload("res://vfx/motion_blur.gd")
const Renderer = preload("res://presentation/actor_renderer.gd")
var passed: int=0
var failed: int=0
class Hero extends Node2D:
    var velocity: Vector2=Vector2.RIGHT*232
    var facing: int=1
    var frame: int=0
    var combo: int=1
    var animation_state: String="run"
    var attack_phase: String="none"
    var dash_timer: float=0.0
    var dash_direction: Vector2=Vector2.RIGHT
    var airborne: bool=false
    var dead: bool=false
    var weapon: String="light"
class Impact extends Node:
    var reduced_motion: bool=false
class Game extends Node2D:
    var player: Node2D
    var impact: Node
    var story_safe: bool=false
    var _paused: bool=false
    var _overlay: String=""
    var outcome: String=""
    var room_id: String="dungeon"
    var speed_effects_level: int=1
var game: Game
var service: Node
var trail: Node
func _initialize() -> void: call_deferred("run")
func check(value: bool,label: String) -> void:
    if value: passed+=1;print("PASS ",label)
    else: failed+=1;push_error("FAIL "+label)
func move(dt: float, offset: Vector2) -> void:
    game.player.position+=offset
    trail._process(dt)
func reset() -> void:
    trail.clear()
    game.story_safe=false;game._paused=false;game._overlay="";game.outcome="";game.room_id="dungeon";game.speed_effects_level=1
    service.enabled_by_user=true;game.impact.reduced_motion=false
    game.player.position=Vector2(0,200);game.player.velocity=Vector2(232,0);game.player.dead=false
    game.player.frame=0;game.player.weapon="light";game.player.animation_state="run";game.player.attack_phase="none";game.player.dash_timer=0;game.player.airborne=false;game.player.facing=1
func seed_run() -> void:
    trail._process(0)
    for i: int in 8: move(.016,Vector2(4,0))
func run() -> void:
    game=Game.new();root.add_child(game)
    game.player=Hero.new();game.add_child(game.player)
    game.impact=Impact.new();game.add_child(game.impact)
    service=Service.new();service.name="MotionBlur";game.add_child(service);service.setup(game);service.set_process(false)
    trail=service.get_node("MovementTrail");trail.set_process(false)
    reset();seed_run()
    check(trail.counts()["snapshots"]>0,"running creates short actual-history snapshots")
    var first: Dictionary=trail._samples[0]
    check(first["at"]!=game.player.position and Vector2(first["at"]).x<game.player.position.x,"snapshot is behind at an actual prior world position")
    check(first["region"]==Renderer.hero_region("run",0) and first["facing"]==1 and first["weapon"]=="light","past region, facing and sword are immutable snapshots")
    game.player.frame=5;game.player.weapon="great";game.player.facing=-1
    check(first["region"]==Renderer.hero_region("run",0) and first["weapon"]=="light" and first["facing"]==1,"live pose/equipment changes do not mutate history")
    var emitted: int=trail.emitted_total
    for i: int in 100: trail._process(.001)
    check(trail.emitted_total==emitted,"stationary render frames cannot pile up same-position copies")
    reset();trail._process(0)
    for i: int in 30: move(.001,Vector2(1,0))
    check(trail._samples.is_empty(),"minimum time prevents high-refresh emission flood")
    move(.05,Vector2(1,0))
    check(trail._samples.size()==1,"both distance and time thresholds must pass before emission")
    reset();trail._process(0);move(.50,Vector2(12,0))
    check(not trail.is_active(),"a long frame cannot rejuvenate an already expired pose")
    move(.05,Vector2(12,0))
    check(trail._samples.size()==1 and float(trail._samples[0]["age"])>=.049,"new history retains actual capture age")
    reset();trail._process(0);trail._process(.30);move(.016,Vector2(10,0))
    check(not trail.is_active(),"moving after a long stationary hold cannot replay an expired anchor")
    reset();trail._process(0)
    for i: int in 20: move(.05,Vector2(.1,0))
    check(trail._samples.is_empty(),"minimum distance prevents tiny-jitter afterimages")
    for direction: Vector2 in [Vector2.RIGHT,Vector2.LEFT,Vector2.UP,Vector2.DOWN,Vector2(1,-1).normalized()]:
        reset();game.player.velocity=direction*520;game.player.airborne=true;game.player.dash_timer=.12;game.player.animation_state="dash";game.player.dash_direction=direction;trail._process(0)
        for i: int in 5: move(.025,direction*13)
        check(trail._samples.size()>0 and Vector2(trail._samples.back()["direction"]).dot(direction)>.999,"trajectory matches movement vector "+str(direction))
        check(trail._samples.back()["region"]==Renderer.hero_region_for(game.player,"dash",0),"directional dash captures matching authored frame")
    reset();game.player.dash_timer=.12;game.player.animation_state="dash";game.player.velocity=Vector2.RIGHT*520;trail._process(0)
    for i: int in 300: move(.025,Vector2(13,0))
    check(trail.counts()["snapshots"]<=8,"long travel respects eight-snapshot budget")
    game.player.velocity=Vector2.ZERO;game.player.dash_timer=0;game.player.animation_state="idle";trail._process(.06)
    check(not trail.is_active(),"stopping consumes residual history within60ms")
    reset();seed_run();game.impact.reduced_motion=true
    trail._process(.016)
    check(trail.is_active() and service.sample_camera_lead(.1)==0,"F2 disables camera lead but keeps moving-sprite effects independent")
    service.enabled_by_user=false;trail._process(.016)
    check(not trail.is_active() and service.is_movement_trail_owner(),"F3 clears movement effects without handing control back to old ghosts")
    reset();seed_run();game.speed_effects_level=0;trail._process(.016)
    check(not trail.is_active(),"speed setting OFF clears every motion snapshot")
    reset();seed_run();game.player.position.x+=500;trail._process(.016)
    check(not trail.is_active(),"teleport never draws a long cross-map streak")
    reset();seed_run();game.room_id="boss";trail._process(.016)
    check(not trail.is_active(),"room identity change clears old history")
    reset();seed_run();game.player.dead=true;trail._process(.016)
    check(not trail.is_active(),"death removes motion history")
    reset();seed_run();game.story_safe=true;trail._process(.016)
    check(not trail.is_active(),"narrative safety removes motion history")
    reset();seed_run();game._paused=true;trail._process(.016)
    check(not trail.is_active(),"pause cannot leave animated afterimages")
    reset();seed_run();service.clear()
    check(not trail.is_active() and trail._last_observed==Vector2.INF,"existing service clear also resets sampling anchor")
    reset();game.player.attack_phase="active";seed_run()
    check(not trail.is_active(),"attack VFX remain under the single attack owner")
    trail.settings["strength"]=9.0
    check(is_equal_approx(trail.strength(),1.5),"effect intensity has an upper bound")
    trail.settings["strength"]=0.0;trail._process(.02)
    check(not trail.is_active(),"zero configured strength disables sampling")
    check(Engine.time_scale==1.0,"motion presentation never changes global music time")
    game.queue_free();await process_frame
    print("Movement trail: %d passed, %d failed" % [passed,failed]);quit(1 if failed else 0)
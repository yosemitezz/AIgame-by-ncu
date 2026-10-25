extends Node2D
## Pixel feather flight: jointed wings and short wake, presentation only.
## The player still owns every movement, input, immunity and cooldown window.
const Renderer = preload("res://presentation/actor_renderer.gd")
const FEATHERS: int = 6
const MAX_TAIL_SECONDS: float = 0.10
const MAX_TAIL_LENGTH: float = 26.0
const INK := Color("26394e")
const SHADE := Color("5c92aa")
const IVORY := Color("e9eee6")
const COOL := Color("a3d6de")
const GOLD := Color("d6bd7c")
var _clock: float = 0.0
var _dash_tail: float = 0.0
var _last_direction: Vector2 = Vector2.RIGHT
var _visual_direction: Vector2 = Vector2.RIGHT
var _direction_ready: bool = false
var _last_strength: float = 0.0

func _ready() -> void:
    # Mixed native colours keep the feather shadow/edge instead of a solid additive jet.
    show_behind_parent = true
    texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    visible = false

static func _blocked(actor: Object) -> bool:
    if actor == null or not is_instance_valid(actor) or actor.get("dead") == true: return true
    var owner: Variant = actor.get("game")
    return owner is Object and is_instance_valid(owner) and owner.get("story_safe") == true

static func phase_profile(progress: float) -> Dictionary:
    var p: float = clampf(progress,0.0,1.0)
    # Spread first, press the wing elbow back, then release a small glide fan.
    var fan: float
    var drive: float
    var stage: String
    if p < 0.24:
        fan = lerpf(0.82,1.0,p/0.24)
        drive = lerpf(0.0,0.72,p/0.24)
        stage = "spread"
    elif p < 0.72:
        fan = lerpf(1.0,0.24,smoothstep(0.24,0.62,p))
        drive = lerpf(0.72,1.0,smoothstep(0.24,0.52,p))
        stage = "drive"
    else:
        fan = lerpf(0.24,0.62,smoothstep(0.72,1.0,p))
        drive = lerpf(1.0,0.20,smoothstep(0.72,1.0,p))
        stage = "glide"
    return {"stage":stage,"fan":fan,"drive":drive,"progress":p}

static func presentation_state(actor: Object) -> Dictionary:
    var empty: Dictionary={"open":0.0,"air_dash":false,"direction":Vector2.RIGHT,"anchor":Vector2(-3,-35),"progress":0.0,"stage":"folded","fan":0.0,"drive":0.0,"blocked":true}
    if actor == null or not is_instance_valid(actor): return empty
    var saved: Variant=actor.get("wing_amount")
    var amount: float=clampf(float(saved),0.0,1.0) if saved != null else 0.0
    var timer: Variant=actor.get("dash_timer")
    var airborne: bool=Renderer.is_airborne(actor)
    var blocked: bool=_blocked(actor)
    var air_dash: bool=airborne and timer != null and float(timer)>0.0 and not blocked
    var direction: Vector2=Renderer.dash_direction_of(actor)
    var velocity: Variant=actor.get("velocity")
    var face: Variant=actor.get("facing")
    var facing: float=-1.0 if face != null and int(face)<0 else 1.0
    if not air_dash:
        direction=velocity if velocity is Vector2 and velocity.length()>30.0 else Vector2(facing,-0.30)
    if direction.is_zero_approx(): direction=Vector2(facing,0)
    var profile: Dictionary=phase_profile(Renderer.flight_progress(actor)) if air_dash else {"stage":"balance","fan":0.76,"drive":0.16,"progress":0.0}
    return {"open":0.0 if blocked else maxf(amount,0.90 if air_dash else 0.0),"air_dash":air_dash,
        "direction":direction.normalized(),"anchor":Renderer.wing_anchor(actor),"blocked":blocked,
        "progress":profile["progress"],"stage":profile["stage"],"fan":profile["fan"],"drive":profile["drive"]}

static func wing_shape(state: Dictionary, near: bool) -> Dictionary:
    # Each wing has a shoulder, bent elbow and wrist. Primaries grow along the
    # wrist instead of all seven rays emanating from one fixed backpack point.
    var back: Vector2=-Vector2(state["direction"])
    var normal: Vector2=back.orthogonal()
    var side: float=-1.0 if near else 1.0
    var fan: float=float(state["fan"])
    var drive: float=float(state["drive"])
    var scale_w: float=1.0 if near else 0.75
    var root: Vector2=Vector2.ZERO
    var elbow: Vector2=back*(7.0+4.0*drive)*scale_w+normal*side*(4.0+11.0*fan)*scale_w
    var wrist: Vector2=elbow+back*(9.0+5.0*drive)*scale_w+normal*side*(2.0*fan-2.0*drive)*scale_w
    var feathers: Array[PackedVector2Array]=[]
    for i: int in FEATHERS:
        var t: float=float(i)/float(FEATHERS-1)
        var base: Vector2=elbow.lerp(wrist,t)
        var feather_dir: Vector2=(back*0.82+normal*side*lerpf(1.0,-0.18,t)*fan).normalized()
        var cross: Vector2=feather_dir.orthogonal()
        var length: float=lerpf(13.0,22.0,t)*scale_w*(0.83+0.17*drive)
        var width: float=lerpf(2.2,2.8,t)*scale_w
        var middle: Vector2=base+feather_dir*length*0.46
        feathers.append(PackedVector2Array([base.round(),(middle+cross*width).round(),(base+feather_dir*length).round(),(middle-cross*width*0.62).round()]))
    return {"root":root,"elbow":elbow.round(),"wrist":wrist.round(),"feathers":feathers,
        "coverts":PackedVector2Array([root,elbow-normal*side*2.0,wrist,elbow+back*4.0+normal*side*3.0]).duplicate()}

static func pixel_hull(points: PackedVector2Array) -> PackedVector2Array:
    # Quantized tiny wings can collapse several vertices onto the same pixel.
    # Draw only a simple non-degenerate hull, including during the landing fold.
    var hull: PackedVector2Array=Geometry2D.convex_hull(points)
    if hull.size()>1 and hull[0]==hull[hull.size()-1]: hull.remove_at(hull.size()-1)
    if hull.size()<3 or Geometry2D.triangulate_polygon(hull).is_empty(): return PackedVector2Array()
    return hull

func _fill_pixel_polygon(points: PackedVector2Array, colour: Color) -> void:
    var hull: PackedVector2Array=pixel_hull(points)
    if hull.size()>=3: draw_colored_polygon(hull,colour)

func _process(delta: float) -> void:
    if is_inside_tree() and get_tree().paused: return
    var state: Dictionary=presentation_state(get_parent())
    if bool(state["blocked"]):
        _dash_tail=0.0
        _last_strength=0.0
        _direction_ready=false
        visible=false
        return
    _clock+=maxf(delta,0.0)
    var desired: Vector2=state["direction"]
    if not _direction_ready:
        _visual_direction=desired
        _direction_ready=true
    else:
        _visual_direction=Vector2.from_angle(lerp_angle(_visual_direction.angle(),desired.angle(),clampf(delta*28.0,0.0,1.0)))
    if bool(state["air_dash"]):
        _dash_tail=MAX_TAIL_SECONDS
        _last_direction=_visual_direction
        _last_strength=float(state["drive"])
    else:
        _dash_tail=maxf(0.0,_dash_tail-maxf(delta,0.0))
    visible=float(state["open"])>0.01 or _dash_tail>0.0
    if visible: queue_redraw()

func _open() -> float:
    return float(presentation_state(get_parent())["open"])

func _draw() -> void:
    var actor: Node=get_parent()
    var state: Dictionary=presentation_state(actor)
    if bool(state["blocked"]): return
    var saved: Variant=actor.get("invuln")
    var invuln: float=float(saved) if saved != null else 0.0
    if invuln>0.2 and int(invuln*24.0)%2==0: return
    var open: float=float(state["open"])
    var face: float=-1.0 if int(actor.get("facing"))<0 else 1.0
    var anchor: Vector2=state["anchor"]
    anchor.x*=face
    var drawing: Dictionary=state.duplicate()
    drawing["direction"]=_visual_direction if _direction_ready else state["direction"]
    if not bool(state["air_dash"]):
        drawing["fan"]=float(state["fan"])+sin(_clock*12.0)*0.07
    if open>0.01:
        var amount: float=smoothstep(0.0,1.0,open)
        for near: bool in [false,true]:
            var shape: Dictionary=wing_shape(drawing,near)
            var alpha: float=(0.87 if near else 0.43)*minf(1.0,open*1.5)
            var coverts: PackedVector2Array=PackedVector2Array()
            for point: Vector2 in shape["coverts"]: coverts.append((anchor+point*amount).round())
            _fill_pixel_polygon(coverts,Color(SHADE,alpha*0.60))
            # Far feathers first; each has a cool edge, ivory leading half and
            # sparse gold joint accents, leaving the forward body/face untouched.
            for index: int in range(FEATHERS-1,-1,-1):
                var local_points: PackedVector2Array=shape["feathers"][index]
                var points: PackedVector2Array=PackedVector2Array()
                for point: Vector2 in local_points: points.append((anchor+point*amount).round())
                _fill_pixel_polygon(points,Color(SHADE if near else INK,alpha))
                draw_line(points[0],points[2],Color(COOL if index%3 else IVORY,alpha),2.0,false)
                draw_line(points[1],points[2],Color(IVORY,alpha*0.8),1.0,false)
            var elbow: Vector2=(anchor+Vector2(shape["elbow"])*amount).round()
            var wrist: Vector2=(anchor+Vector2(shape["wrist"])*amount).round()
            draw_line(anchor.round(),elbow,Color(COOL,alpha),2.0,false)
            draw_line(elbow,wrist,Color(IVORY,alpha*.8),2.0,false)
            draw_rect(Rect2(elbow-Vector2.ONE,Vector2(2,2)),Color(GOLD,alpha*.8))
    var tail: float=(float(state["drive"]) if bool(state["air_dash"]) else _last_strength*clampf(_dash_tail/MAX_TAIL_SECONDS,0.0,1.0))
    if tail>0.01:
        var back: Vector2=-(_visual_direction if _direction_ready else Vector2(state["direction"]))
        var normal: Vector2=back.orthogonal()
        for i: int in 3:
            var offset: float=float(i-1)*5.0
            var start: Vector2=anchor+back*17.0+normal*offset
            var length: float=(MAX_TAIL_LENGTH-absf(offset)*1.5)*tail
            var end: Vector2=start+back*length
            draw_line(start.round(),end.round(),Color(COOL,0.14*tail),1.0,false)
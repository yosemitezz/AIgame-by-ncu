extends Node2D
## Presentation only. Existing jump/air-jump/dodge physics and the .9s ground fold remain in player.gd.
const Renderer = preload("res://presentation/actor_renderer.gd")
const FEATHERS: int = 7
const MAX_TAIL_SECONDS: float = 0.10
const MAX_TAIL_LENGTH: float = 44.0
var _clock: float = 0.0
var _dash_tail: float = 0.0
var _last_direction: Vector2 = Vector2.RIGHT

func _ready() -> void:
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = add
	show_behind_parent = true
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	visible = false

static func presentation_state(actor: Object) -> Dictionary:
	if actor == null or not is_instance_valid(actor): return {"open":0.0,"air_dash":false,"direction":Vector2.RIGHT,"anchor":Vector2(-3,-35)}
	var saved: Variant = actor.get("wing_amount")
	var amount: float = clampf(float(saved),0.0,1.0) if saved != null else 0.0
	var dead: Variant = actor.get("dead")
	var timer: Variant = actor.get("dash_timer")
	var airborne: bool = Renderer.is_airborne(actor)
	var air_dash: bool = airborne and timer != null and float(timer) > 0.0 and dead != true
	var direction: Vector2 = Renderer.dash_direction_of(actor)
	var velocity: Variant = actor.get("velocity")
	var face: Variant = actor.get("facing")
	var facing: float = -1.0 if face != null and int(face)<0 else 1.0
	if not air_dash:
		direction = velocity if velocity is Vector2 and velocity.length()>30.0 else Vector2(facing,-0.3)
	if direction.is_zero_approx(): direction=Vector2(facing,0)
	return {"open":0.0 if dead == true else maxf(amount,0.90 if air_dash else 0.0),
		"air_dash":air_dash,"direction":direction.normalized(),"anchor":Renderer.wing_anchor(actor)}

func _process(delta: float) -> void:
	_clock += delta
	var state: Dictionary = presentation_state(get_parent())
	if bool(state["air_dash"]):
		_dash_tail=MAX_TAIL_SECONDS
		_last_direction=state["direction"]
	else:
		_dash_tail=maxf(0.0,_dash_tail-delta)
	visible = float(state["open"])>0.01 or _dash_tail>0.0
	if visible: queue_redraw()

func _open() -> float:
	return float(presentation_state(get_parent())["open"])

func _draw() -> void:
	var actor: Node = get_parent()
	var state: Dictionary = presentation_state(actor)
	if actor == null or actor.get("dead") == true: return
	var saved: Variant = actor.get("invuln")
	var invuln: float = float(saved) if saved != null else 0.0
	if invuln>0.2 and int(invuln*24.0)%2==0: return
	var open: float = float(state["open"])
	var face: float = -1.0 if int(actor.get("facing"))<0 else 1.0
	var root: Vector2 = state["anchor"]
	root.x *= face
	var direction: Vector2 = state["direction"]
	var air_dash: bool = bool(state["air_dash"])
	var back: Vector2 = -direction
	var normal: Vector2 = back.orthogonal()
	var e: float = smoothstep(0.0,1.0,open)
	var flap_value: Variant = actor.get("wing_flap")
	var flap: float = clampf(float(flap_value),0.0,1.0) if flap_value != null else 0.0
	var beat: float = sin(_clock*19.0)*(.04+.13*flap)*(0.35 if air_dash else 1.0)
	if open>0.01:
		for side: int in 2:
			var near: bool = side==1
			var layer_scale: float = 1.0 if near else 0.76
			for i: int in FEATHERS:
				var t: float=float(i)/float(FEATHERS-1)
				var spread: float=lerpf(-0.78,0.78,t)*(0.55 if air_dash else 1.0)+beat
				var feather: Vector2=(back*0.9+normal*spread).normalized()
				var length: float=(18.0+14.0*sin(t*PI))*(.25+.75*e)*layer_scale
				var width: float=(2.7 if near else 2.0)*(.4+.6*e)
				var cross: Vector2=feather.orthogonal()
				var hue: float=fposmod(.48+t*.22+_clock*.07+(0.0 if near else .10),1.0)
				var alpha: float=(.72 if near else .40)*minf(1.0,open*1.3)
				var col: Color=Color.from_hsv(hue,.35,1.0,alpha)
				var base: Vector2=root+normal*(1.0 if near else -1.0)
				var middle: Vector2=base+feather*length*.42
				var points:=PackedVector2Array([base.round(),(middle+cross*width).round(),(base+feather*length).round(),(middle-cross*width*.65).round()])
				draw_colored_polygon(points,col)
				draw_line(base.round(),(base+feather*length).round(),Color(0.9,1.0,1.0,alpha*.75),1.0)
	# Five short exhaust streaks taper behind the wing root, not over the action field.
	var tail: float=1.0 if air_dash else clampf(_dash_tail/MAX_TAIL_SECONDS,0.0,1.0)
	if tail>0.0:
		var trail_back: Vector2=-(_last_direction if not air_dash else direction)
		var trail_normal: Vector2=trail_back.orthogonal()
		for i: int in 5:
			var offset: float=float(i-2)*5.0
			var start: Vector2=root+trail_normal*offset+trail_back*9.0
			var length: float=(MAX_TAIL_LENGTH-absf(offset)*1.2)*tail
			var stop: Vector2=start+trail_back*length
			draw_line(start.round(),stop.round(),Color(0.52,0.86,1.0,.22*tail),1.0)

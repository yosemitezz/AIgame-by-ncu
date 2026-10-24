extends Node2D
## Rainbow light wings behind the hero. They snap open on an air jump, flutter while airborne and fold
## away gradually after landing. Presentation only: it reads `wing_amount` / `wing_flap` from the parent
## and never touches physics, hit detection or timing.

const FEATHERS: int = 7
const ROOT: Vector2 = Vector2(-3.0, -35.0)

var _clock: float = 0.0

func _ready() -> void:
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = add
	show_behind_parent = true
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	visible = false

func _process(delta: float) -> void:
	_clock += delta
	var open: float = _open()
	visible = open > 0.01
	if visible:
		queue_redraw()

func _open() -> float:
	var p: Node = get_parent()
	if p == null:
		return 0.0
	var v: Variant = p.get("wing_amount")
	return clampf(float(v), 0.0, 1.0) if v != null else 0.0

func _draw() -> void:
	var p: Node = get_parent()
	var open: float = _open()
	if p == null or open <= 0.01 or bool(p.get("dead")):
		return
	var invuln: float = float(p.get("invuln"))
	if invuln > 0.2 and int(invuln * 24.0) % 2 == 0:
		return
	var face: float = float(int(p.get("facing")))
	var flap: float = clampf(float(p.get("wing_flap")), 0.0, 1.0)
	var vel: Vector2 = p.get("velocity")
	# Ease so the wings burst open quickly and fold slowly.
	var e: float = open * open * (3.0 - 2.0 * open)
	var beat: float = sin(_clock * 19.0) * (0.05 + 0.2 * flap)
	var drag: float = clampf(vel.y / 520.0, -1.0, 1.0)     # falling lifts the tips, rising pulls them back
	for side: int in 2:
		var near: bool = side == 1
		var scale_w: float = 1.0 if near else 0.78
		var root: Vector2 = Vector2(ROOT.x * face, ROOT.y) + Vector2(0.0, 0.0 if near else -1.0)
		for pass_index: int in 2:
			var glow: bool = pass_index == 0
			for i: int in FEATHERS:
				var t: float = float(i) / float(FEATHERS - 1)
				var open_angle: float = lerpf(1.32, -0.18, t) + beat * (0.6 + t) + drag * 0.22
				var closed_angle: float = -1.22 + t * 0.12
				var a: float = lerpf(closed_angle, open_angle, e)
				var length: float = (13.0 + 15.0 * sin(t * PI * 0.85 + 0.35)) * (0.22 + 0.78 * e) * scale_w
				var dir := Vector2(-cos(a) * face, -sin(a))
				var nrm := Vector2(-dir.y, dir.x)
				var width: float = (3.6 if near else 2.8) * (0.45 + 0.55 * e) * (2.0 if glow else 1.0)
				var hue: float = fposmod(_clock * 0.45 + t * 0.55 + (0.0 if near else 0.12), 1.0)
				var alpha: float = (0.22 if glow else (0.9 if near else 0.55)) * minf(1.0, open * 1.6)
				var col: Color = Color.from_hsv(hue, 0.0 if (not glow and i % 3 == 0) else 0.5, 1.0, alpha)
				var mid: Vector2 = root + dir * length * 0.38
				var pts := PackedVector2Array([
					root.round(),
					(mid + nrm * width).round(),
					(root + dir * length).round(),
					(mid - nrm * width * 0.7).round(),
				])
				draw_colored_polygon(pts, col)
				if not glow:
					draw_line(root.round(), (root + dir * length).round(), Color(1.0, 1.0, 1.0, alpha * 0.8), 1.0)

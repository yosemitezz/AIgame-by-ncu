extends Control

const BLACK := Color("000000")
const INK2 := Color("1c223a")
const DEEP := Color("0c1025")
const STONE := Color("9ca4ba")
const BONE := Color("d6ccba")
const BONE2 := Color("f0e6d2")
const BRASS := Color("94683e")
const GOLD := Color("e0b048")
const GOLD_L := Color("ecbc40")
const BLOOD := Color("a82a36")
const CORAL := Color("ef7678")
const CORAL_L := Color("ffbeb8")
const CYAN := Color("58c4d6")
const LID_SKIN := Color("2c1c30")
const LID_DARK := Color("1a1020")
const LID_EDGE := Color("3a2438")
const EYE_CENTRE := Vector2(400, 213)
const EYE_W: float = 300.0
const EYE_H: float = 104.0
const EYE_OPEN: float = 0.62
const EYE_LOW: float = 0.94
const IRIS_R: int = 58

var _clock: float = 0.0
var _mouse: Vector2 = Vector2(400, 200)

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(delta: float) -> void:
	_clock += delta
	queue_redraw()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_mouse = event.position

func _draw() -> void:
	_draw_backdrop()
	_draw_eye()
	_draw_ornament()
	_draw_vignette()

func _draw_backdrop() -> void:
	for y: int in 450:
		var t: float = float(y) / 450.0
		draw_rect(Rect2(0, y, 800, 1), DEEP.lerp(INK2, clampf(t * 1.45, 0.0, 1.0) * 0.72))
	for i: int in 4:
		var cx: float = 100.0 + float(i) * 200.0
		for step: int in 44:
			var a: float = PI + PI * float(step) / 43.0
			var px: float = cx + cos(a) * 92.0
			var py: float = 352.0 + sin(a) * 154.0
			draw_rect(Rect2(roundf(px), roundf(py), 2, 2), Color(0.13, 0.12, 0.19, 0.55))
		for step: int in 44:
			var a2: float = PI + PI * float(step) / 43.0
			var px2: float = cx + cos(a2) * 78.0
			var py2: float = 352.0 + sin(a2) * 132.0
			draw_rect(Rect2(roundf(px2), roundf(py2), 1, 1), Color(0.10, 0.09, 0.15, 0.45))
		draw_rect(Rect2(cx - 92, 352, 1, 58), Color(0.11, 0.10, 0.16, 0.45))
		draw_rect(Rect2(cx + 91, 352, 1, 58), Color(0.11, 0.10, 0.16, 0.45))
	draw_rect(Rect2(0, 428, 800, 1), Color(BRASS, 0.18))
	for side: int in 2:
		var cx: float = 64.0 if side == 0 else 736.0
		var glow: float = 0.07 + 0.02 * sin(_clock * 1.7 + float(side))
		_pixel_disc(Vector2(cx, 356), 18, Color(CORAL, glow * 0.45))
		_pixel_disc(Vector2(cx, 356), 9, Color(CORAL, glow * 0.55))
		draw_rect(Rect2(cx - 1, 342, 2, 15), Color(BONE, 0.5))
		draw_rect(Rect2(cx - 1, 338, 2, 3), Color(GOLD_L, 0.7 + 0.2 * sin(_clock * 5.0 + float(side))))
	for i: int in 20:
		var seed_value: float = float(i) * 37.13
		var px: float = fmod(seed_value * 3.7 + sin(_clock * 0.35 + seed_value) * 26.0, 800.0)
		var py: float = 400.0 - fmod(_clock * (7.0 + fmod(seed_value, 5.0)) + seed_value * 11.0, 420.0)
		var alpha: float = 0.09 + 0.08 * sin(_clock * 1.6 + seed_value)
		draw_rect(Rect2(roundf(px), roundf(py), 1, 1), Color(CORAL, alpha))

func _draw_eye() -> void:
	var centre: Vector2 = EYE_CENTRE
	var blink: float = _blink_amount()
	for ring: int in 3:
		_pixel_disc(centre, 206 - ring * 26, Color(CORAL, 0.012))
	_draw_optic_nerve(centre)
	for x: int in range(-int(EYE_W), int(EYE_W) + 1):
		var nx: float = float(x) / EYE_W
		var half: float = EYE_H * pow(maxf(0.0, 1.0 - nx * nx), 0.62)
		if half < 1.5:
			continue
		var outer_top: float = centre.y - half
		var eye_top: float = centre.y - half * EYE_OPEN
		var eye_bottom: float = centre.y + half * EYE_LOW
		var edge: float = clampf(absf(nx), 0.0, 1.0)
		draw_rect(Rect2(centre.x + x, outer_top, 1, eye_top - outer_top), LID_DARK)
		draw_rect(Rect2(centre.x + x, outer_top + (eye_top - outer_top) * 0.38, 1, (eye_top - outer_top) * 0.62), LID_SKIN)
		draw_rect(Rect2(centre.x + x, eye_top - 3.0, 1, 2), LID_EDGE)
		draw_rect(Rect2(centre.x + x, eye_top - 5.0, 1, 1), Color(0.30, 0.18, 0.26, 0.55))
		var crease_y: float = outer_top + (eye_top - outer_top) * 0.34
		draw_rect(Rect2(centre.x + x, crease_y, 1, 1), Color("0d0812"))
		var base: Color = BONE2.lerp(BONE, smoothstep(0.10, 0.80, edge) * 0.55)
		base = base.lerp(STONE, smoothstep(0.78, 1.0, edge) * 0.82)
		draw_rect(Rect2(centre.x + x, eye_top, 1, eye_bottom - eye_top), base)
		var span: float = eye_bottom - eye_top
		var t_eye: float = clampf((centre.y - eye_top) / maxf(span, 1.0), 0.0, 1.0)
		var lid_shade: float = smoothstep(0.0, 0.42, t_eye) * smoothstep(1.0, 0.62, t_eye)
		draw_rect(Rect2(centre.x + x, eye_top, 1, span), Color(0.32, 0.18, 0.24, 0.16 * (1.0 - lid_shade)))
		draw_rect(Rect2(centre.x + x, eye_bottom - span * 0.30, 1, span * 0.30), Color(0.42, 0.24, 0.30, 0.12))
		if span < 4.0:
			continue
		draw_rect(Rect2(centre.x + x, outer_top, 1, 1), Color("100a14"))
		draw_rect(Rect2(centre.x + x, eye_bottom - 1.0, 1, 1), Color("2a1a26"))
	_draw_veins(centre)
	_draw_iris(centre)
	if blink > 0.001:
		for x: int in range(-int(EYE_W), int(EYE_W) + 1):
			var nx: float = float(x) / EYE_W
			var half: float = EYE_H * pow(maxf(0.0, 1.0 - nx * nx), 0.62)
			if half < 1.5:
				continue
			var eye_top: float = centre.y - half * EYE_OPEN
			var eye_bottom: float = centre.y + half * EYE_LOW
			var close_y: float = lerpf(eye_top, eye_bottom, blink * 0.98)
			draw_rect(Rect2(centre.x + x, eye_top, 1, close_y - eye_top), LID_SKIN)
			draw_rect(Rect2(centre.x + x, close_y - 1.0, 1, 1), Color("6a3e4c"))
	for x: int in range(-int(EYE_W), int(EYE_W) + 1):
		var nx: float = float(x) / EYE_W
		var half: float = EYE_H * pow(maxf(0.0, 1.0 - nx * nx), 0.62)
		if half < 3.0:
			continue
		var eye_top: float = centre.y - half * EYE_OPEN
		draw_rect(Rect2(centre.x + x, eye_top, 1, 1), Color(CORAL, 0.34))
		draw_rect(Rect2(centre.x + x, eye_top + 1.0, 1, 1), Color(BONE2, 0.12))

func _draw_veins(centre: Vector2) -> void:
	for i: int in 9:
		var a: float = TAU * (float(i) + 0.37) / 9.0 + sin(float(i) * 2.7) * 0.12
		var direction := Vector2(cos(a), sin(a) * 0.74).normalized()
		var point: Vector2 = centre + direction * float(IRIS_R - 2)
		var previous: Vector2 = point
		var reach: int = 9 + (i * 5) % 6
		for k: int in reach:
			var nx: float = (point.x - centre.x) / EYE_W
			var half: float = EYE_H * pow(maxf(0.0, 1.0 - nx * nx), 0.62)
			var eye_top: float = centre.y - half * EYE_OPEN
			var eye_bottom: float = centre.y + half * EYE_LOW
			if absf(point.x - centre.x) > EYE_W - 4.0 or point.y < eye_top + 3.0 or point.y > eye_bottom - 3.0:
				break
			var fade: float = 0.30 * (1.0 - float(k) / float(reach)) * (1.0 - smoothstep(0.34, 0.72, absf(nx)))
			draw_line(previous, point, Color("5a1a26", fade), 1.0)
			if k == 6 or k == 12:
				var side: float = 1.0 if (i + k) % 2 == 0 else -1.0
				var branch: Vector2 = point
				var branch_previous: Vector2 = point
				for n: int in 5:
					branch += direction.orthogonal() * side * 2.4 + direction * 1.1 + direction.orthogonal() * sin(float(n) * 2.1 + float(i)) * 0.9
					draw_line(branch_previous, branch, Color("5a1a26", fade * 0.45), 1.0)
					branch_previous = branch
			previous = point
			point += direction * 3.4 + direction.orthogonal() * sin(float(k) * 1.9 + float(i) * 1.3) * 1.9
			direction = direction.rotated(sin(float(k) * 1.1 + float(i) * 1.7) * 0.07)
	var start: Vector2 = centre + Vector2(cos(0.35), sin(0.35) * 0.72) * float(IRIS_R)
	var vessel: Vector2 = start
	var vessel_direction := Vector2(cos(0.35), sin(0.35) * 0.6).normalized()
	for k: int in 26:
		var previous: Vector2 = vessel
		vessel += vessel_direction * 2.6
		vessel_direction = vessel_direction.rotated(sin(float(k) * 0.8) * 0.05)
		draw_line(previous, vessel, Color("6e1a26", 0.24 * (1.0 - float(k) / 26.0)), 1.0)

func _draw_iris(centre: Vector2) -> void:
	var breath: float = 1.0 + sin(_clock * 0.85) * 0.015
	var gaze: Vector2 = ((_mouse - centre) / Vector2(180.0, 90.0)).limit_length(1.0)
	_pixel_disc(centre + Vector2(0, 2), IRIS_R + 4, Color(0.30, 0.18, 0.24, 0.22))
	_pixel_disc(centre, int(float(IRIS_R) * breath), Color("3a121c"))
	_pixel_disc(centre, int(56.0 * breath), Color("5e1a26"))
	_pixel_disc(centre, int(52.0 * breath), Color("7a1e2c"))
	_pixel_disc(centre, int(46.0 * breath), BLOOD)
	_pixel_disc(centre, int(38.0 * breath), Color("8e2230"))
	_pixel_disc(centre, int(31.0 * breath), Color("4a1420"))
	for i: int in 48:
		var a: float = TAU * float(i) / 48.0
		for k: int in 12:
			var radius: float = 20.0 + float(k) * 2.5
			var px: float = centre.x + cos(a) * radius * breath
			var py: float = centre.y + sin(a) * radius * breath * 0.98
			draw_rect(Rect2(roundf(px), roundf(py), 1, 1), Color("c03a48") if k % 2 == 0 else Color("6e1a26"))
	var pupil: Vector2 = centre + gaze * 6.5
	_pixel_disc(pupil, 18, BLACK)
	_pixel_disc(pupil + Vector2(0, -1), 16, Color("0a0508"))
	for i: int in 18:
		var a: float = PI * 0.62 + PI * 0.46 * float(i) / 17.0
		draw_rect(Rect2((centre + Vector2(cos(a) * 56.0, sin(a) * 56.0)).round(), Vector2.ONE), Color(CYAN, 0.30))
	draw_rect(Rect2((pupil + Vector2(-8, -11)).round(), Vector2(6, 6)), Color(CORAL_L, 0.88))
	draw_rect(Rect2((pupil + Vector2(-7, -10)).round(), Vector2(3, 3)), BONE2)
	draw_rect(Rect2((pupil + Vector2(5, 6)).round(), Vector2(3, 3)), Color(CORAL, 0.28))

func _draw_optic_nerve(centre: Vector2) -> void:
	var start: Vector2 = centre + Vector2(EYE_W * 0.82, 42.0)
	for strand: int in 3:
		for i: int in 44:
			var t: float = float(i) / 43.0
			var px: float = lerpf(start.x, 790.0, t)
			var py: float = lerpf(start.y, 344.0, t) + sin(t * 8.0 + float(strand) * 2.1 + _clock * 0.2) * 4.5 + float(strand) * 3.0
			var fade: float = clampf(1.0 - smoothstep(0.72, 1.0, t) * 0.65, 0.0, 1.0)
			draw_rect(Rect2(roundf(px), roundf(py), 3, 2), Color("4a2e58", fade))
			if strand == 0:
				draw_rect(Rect2(roundf(px), roundf(py) - 1.0, 2, 1), Color("8a6aa0", 0.45 * fade))
	for i: int in 4:
		var t: float = 0.12 + float(i) * 0.08
		var px: float = lerpf(start.x, 790.0, t)
		var py: float = lerpf(start.y, 344.0, t) + sin(t * 8.0 + _clock * 0.2) * 4.5
		draw_rect(Rect2(roundf(px), roundf(py) - 4.0, 1, 4), Color("6a4478", 0.5))

func _blink_amount() -> float:
	var phase: float = fmod(_clock, 8.4)
	if phase > 0.10 and phase < 0.34:
		return sin((phase - 0.10) / 0.24 * PI)
	return 0.0

func _pixel_disc(centre: Vector2, radius: int, ink: Color) -> void:
	if radius <= 0:
		return
	var cx: float = roundf(centre.x)
	var cy: float = roundf(centre.y)
	for y: int in range(-radius, radius + 1):
		var width: int = int(floor(sqrt(maxf(0.0, float(radius * radius + radius - y * y)))))
		draw_rect(Rect2(cx - float(width), cy + float(y), float(width * 2 + 1), 1.0), ink)

func _draw_ornament() -> void:
	draw_rect(Rect2(270, 104, 260, 1), Color(BRASS, 0.42))
	draw_rect(Rect2(322, 103, 156, 3), Color(BRASS, 0.55))
	draw_rect(Rect2(342, 103, 116, 1), Color(GOLD, 0.9))
	for dx: float in [-132.0, 132.0]:
		var cx: float = 400.0 + dx
		draw_rect(Rect2(cx - 1, 102, 3, 1), Color(GOLD, 0.65))
		draw_rect(Rect2(cx, 101, 1, 3), Color(GOLD, 0.65))

func _draw_vignette() -> void:
	for i: int in 46:
		var alpha: float = 0.055 * (1.0 - float(i) / 46.0)
		draw_rect(Rect2(0, i, 800, 1), Color(0, 0, 0, alpha))
		draw_rect(Rect2(0, 449 - i, 800, 1), Color(0, 0, 0, alpha))
		draw_rect(Rect2(i, 0, 1, 450), Color(0, 0, 0, alpha * 0.8))
		draw_rect(Rect2(799 - i, 0, 1, 450), Color(0, 0, 0, alpha * 0.8))

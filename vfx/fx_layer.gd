extends Node2D
## Presentation-only combat VFX. It listens to the game's existing signals (vfx_requested,
## warning_issued) and never touches physics, hit detection, damage or timing.
##
## Readability rules (docs/art-ui-contract.md):
##   telegraph = thin gold line, never filled across the lane;
##   hostile hits = warm ramp (white, gold, coral, magenta);
##   player / parry / reflected = cool ramp (white, cyan, blue, violet, pink);
##   big moments (burst, checkpoint, pickups) = rainbow ramp.
## Colour moves along each effect's life and along its length, so every effect reads as a gradient.
## An additive child layer adds the glow; everything stays on the integer pixel grid.

const MAX_PARTS: int = 420
const MAX_SHAPES: int = 64
const MAX_WARNINGS: int = 24

const RAMP_SOURCE: Dictionary = {
	"cool": ["ffffff", "c4fff6", "72ece2", "5aa4ff", "a278ff", "ff7ad0"],
	"warm": ["ffffff", "fff1bd", "e9bb68", "ff9a5a", "ef7678", "b04aa8"],
	"hurt": ["ffffff", "ffc0b8", "ef7678", "c0405f", "5a1d4a"],
	"dust": ["f2f6d6", "b8c4cf", "77839c", "394462"],
	"gold": ["ffffff", "fff1bd", "e9bb68", "88704e"],
}

var game: Node = null
var _ramps: Dictionary = {}
var _parts: Array[Dictionary] = []
var _shapes: Array[Dictionary] = []
var _warns: Array[Dictionary] = []
var _clock: float = 0.0
var _rng := RandomNumberGenerator.new()
var _glow: Node2D = null

func _ready() -> void:
	z_index = 6
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_rng.seed = 20261024
	for key: String in RAMP_SOURCE:
		var stops := PackedColorArray()
		for hex: String in RAMP_SOURCE[key]:
			stops.append(Color(hex))
		_ramps[key] = stops
	var material := CanvasItemMaterial.new()
	material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_glow = Node2D.new()
	_glow.material = material
	_glow.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_glow)
	_glow.draw.connect(func() -> void: _paint(_glow, true))

func setup(p_game: Node) -> void:
	game = p_game
	game.vfx_requested.connect(spawn)
	game.warning_issued.connect(_on_warning)

func particle_count() -> int:
	return _parts.size()

func shape_count() -> int:
	return _shapes.size()

func warning_count() -> int:
	return _warns.size()

# ------------------------------------------------------------------ colour

func _col(ramp: String, u: float, a: float = 1.0, h: float = 0.0) -> Color:
	u = clampf(u, 0.0, 1.0)
	var c: Color
	if ramp == "rainbow":
		var sat: float = clampf(u * 5.0, 0.0, 1.0) * 0.62
		c = Color.from_hsv(fposmod(u * 0.85 + h + _clock * 0.6, 1.0), sat, 1.0)
	else:
		var stops: PackedColorArray = _ramps[ramp]
		var f: float = u * float(stops.size() - 1)
		var i: int = mini(int(f), stops.size() - 2)
		c = stops[i].lerp(stops[i + 1], f - float(i))
	c.a = clampf(a, 0.0, 1.0)
	return c

# ------------------------------------------------------------------ spawning

func _part(at: Vector2, vel: Vector2, life: float, ramp: String, size: int = 2, kind: String = "dot", grav: float = 100.0, drag: float = 0.0) -> void:
	if _parts.size() >= MAX_PARTS:
		return
	_parts.append({"p": at, "v": vel, "life": life, "max": life, "ramp": ramp, "size": size, "kind": kind, "grav": grav, "drag": drag, "h": _rng.randf()})

func _shape(type: String, at: Vector2, life: float, ramp: String, extra: Dictionary = {}) -> void:
	if _shapes.size() >= MAX_SHAPES:
		_shapes.remove_at(0)
	var s: Dictionary = {"type": type, "at": at, "life": life, "max": life, "ramp": ramp}
	s.merge(extra)
	_shapes.append(s)

func _sparks(at: Vector2, dir: Vector2, n: int, ramp: String, speed: float, life: float, kind: String = "streak", spread: float = 0.9) -> void:
	var has_dir: bool = dir.length() > 0.01
	var base: float = dir.angle() if has_dir else 0.0
	var spr: float = spread if has_dir else PI
	for _i: int in n:
		var a: float = base + _rng.randf_range(-spr, spr)
		var sp: float = speed * _rng.randf_range(0.45, 1.0)
		var l: float = life * _rng.randf_range(0.6, 1.0)
		_part(at, Vector2.from_angle(a) * sp, l, ramp, _rng.randi_range(2, 3), kind, 160.0, 2.2)

func _hostile_near(at: Vector2) -> bool:
	var b: Variant = game.get("boss") if is_instance_valid(game) else null
	return b != null and is_instance_valid(b) and at.distance_to((b as Node2D).global_position) < 90.0

func spawn(kind: String, at: Vector2, dir: Vector2, power: float) -> void:
	var d: float = 1.0 if dir.x >= 0.0 else -1.0
	match kind:
		"slash":
			var combo: int = clampi(int(roundf(power)), 1, 3)
			_shape("arc", at, 0.26 + 0.04 * float(combo), "cool", {"d": d, "r": 22.0 + 5.0 * float(combo), "w": 3.0 + float(combo), "flip": combo == 2, "half": 1.35 if combo < 3 else 1.95})
			_sparks(at + Vector2(d * 16.0, 0.0), Vector2(d, 0.0), 5 + combo * 3, "cool", 170.0, 0.4)
			_shape("star", at + Vector2(d * 22.0, 0.0), 0.16, "cool", {"r": 7.0 + 2.0 * float(combo)})
			if combo == 3:
				_shape("ring", at + Vector2(d * 10.0, 0.0), 0.34, "cool", {"r0": 6.0, "r1": 44.0, "w": 4.0, "ry": 0.75})
		"enemy_slash":
			_shape("arc", at, 0.24, "warm", {"d": d, "r": 18.0 + 8.0 * power, "w": 3.0, "flip": false, "half": 1.3})
			_sparks(at + Vector2(d * 14.0, 0.0), Vector2(d, 0.0), 6, "warm", 130.0, 0.35)
		"parry":
			_shape("ring", at, 0.34, "cool", {"r0": 4.0, "r1": 26.0 + 9.0 * power, "w": 4.0, "ry": 1.0})
			_shape("ring", at, 0.24, "rainbow", {"r0": 2.0, "r1": 16.0 + 5.0 * power, "w": 3.0, "ry": 1.0})
			_shape("rays", at, 0.3, "cool", {"n": 10, "r1": 30.0 + 8.0 * power, "rot": 1.2})
			_shape("star", at, 0.22, "cool", {"r": 14.0})
			_sparks(at, dir, 16, "cool", 260.0, 0.5)
			_sparks(at, Vector2.ZERO, 5, "rainbow", 120.0, 0.55, "twinkle")
		"parry_ready":
			_shape("ring", at, 0.16, "cool", {"r0": 16.0, "r1": 5.0, "w": 2.0, "ry": 1.0})
		"hit":
			_shape("star", at, 0.18, "warm", {"r": 11.0 + 3.0 * power})
			_shape("rays", at, 0.22, "warm", {"n": 8, "r1": 20.0 + 6.0 * power, "rot": 0.0})
			_sparks(at, dir, 10, "warm", 220.0, 0.4, "streak", 1.2)
			_sparks(at, dir, 5, "warm", 120.0, 0.55, "deb", 1.6)
		"hurt":
			_shape("ring", at, 0.3, "hurt", {"r0": 3.0, "r1": 26.0, "w": 4.0, "ry": 1.0})
			_shape("star", at, 0.2, "hurt", {"r": 12.0})
			_sparks(at, dir, 12, "hurt", 200.0, 0.45, "streak", 1.6)
		"dash":
			var hostile: bool = _hostile_near(at)
			_shape("bars", at, 0.26, "warm" if hostile else "cool", {"d": 1.0 if dir.x >= 0.0 else -1.0, "len": 26.0 * clampf(power, 0.5, 1.5)})
			_sparks(at, dir, 2, "warm" if hostile else "cool", 60.0, 0.3, "twinkle", 1.0)
		"jump":
			_shape("ring", at, 0.24, "dust", {"r0": 2.0, "r1": 13.0, "w": 2.0, "ry": 0.3})
			_sparks(at, Vector2.ZERO, 4, "dust", 50.0, 0.3, "dot", 0.5)
		"air_jump":
			_shape("ring", at, 0.3, "cool", {"r0": 3.0, "r1": 24.0, "w": 3.0, "ry": 0.35})
			_shape("ring", at, 0.22, "rainbow", {"r0": 2.0, "r1": 14.0, "w": 2.0, "ry": 0.35})
			_sparks(at, Vector2(0.0, 1.0), 4, "cool", 70.0, 0.35, "twinkle", 1.3)
		"land":
			_shape("ring", at, 0.26, "dust", {"r0": 3.0, "r1": 20.0, "w": 2.0, "ry": 0.28})
			_sparks(at + Vector2(0.0, -1.0), Vector2(0.0, -1.0), 5, "dust", 70.0, 0.3, "dot", 1.4)
		"pickup":
			var n: int = clampi(int(8.0 * power), 3, 12)
			_shape("star", at, 0.3, "rainbow", {"r": 5.0 + 4.0 * power})
			for _i: int in n:
				_part(at, Vector2(_rng.randf_range(-40.0, 40.0), _rng.randf_range(-110.0, -30.0)), _rng.randf_range(0.5, 0.9), "rainbow", 2, "twinkle", 30.0, 1.0)
		"checkpoint":
			_shape("pillar", at + Vector2(0.0, 20.0), 1.1, "rainbow", {"h": 96.0, "w0": 14.0})
			_shape("ring", at + Vector2(0.0, 20.0), 0.7, "rainbow", {"r0": 4.0, "r1": 44.0, "w": 4.0, "ry": 0.3})
			_shape("ring", at + Vector2(0.0, 12.0), 0.9, "cool", {"r0": 4.0, "r1": 30.0, "w": 3.0, "ry": 0.3})
			for _i: int in 22:
				_part(at + Vector2(_rng.randf_range(-8.0, 8.0), 20.0), Vector2(_rng.randf_range(-16.0, 16.0), _rng.randf_range(-120.0, -40.0)), _rng.randf_range(0.7, 1.2), "rainbow", 2, "twinkle", -10.0, 0.8)
		"death":
			_shape("star", at, 0.24, "warm", {"r": 14.0 * power})
			_shape("rays", at, 0.34, "warm", {"n": 10, "r1": 32.0 * power, "rot": 0.8})
			_shape("ring", at, 0.38, "warm", {"r0": 4.0, "r1": 30.0 * power, "w": 4.0, "ry": 0.9})
			_sparks(at, Vector2.ZERO, 16, "warm", 190.0, 0.6)
			_sparks(at, Vector2.UP, 8, "warm", 110.0, 0.7, "deb", 1.2)
		"burst", "boss_defeat":
			var big: float = maxf(power, 1.0)
			_shape("star", at, 0.4, "rainbow", {"r": 26.0 * big})
			_shape("rays", at, 0.7, "rainbow", {"n": 16, "r1": 54.0 * big, "rot": 2.4})
			_shape("ring", at, 0.55, "rainbow", {"r0": 4.0, "r1": 60.0 * big, "w": 5.0, "ry": 1.0})
			_shape("ring", at, 0.75, "cool", {"r0": 2.0, "r1": 90.0 * big, "w": 3.0, "ry": 0.8})
			_shape("ring", at, 0.95, "warm", {"r0": 2.0, "r1": 120.0 * big, "w": 2.0, "ry": 0.7})
			_sparks(at, Vector2.ZERO, 34, "rainbow", 300.0, 1.0)
			_sparks(at, Vector2.ZERO, 14, "rainbow", 140.0, 1.1, "twinkle")
		"spark":
			_shape("star", at, 0.14, "gold", {"r": 5.0})
			_sparks(at, dir, 4, "gold", 120.0, 0.25)
		"warning", "telegraph":
			# Telegraphs stay gold. A small pulse only; the lane itself is drawn by warning_issued.
			_shape("star", at, 0.2, "gold", {"r": 6.0})
		_:
			_sparks(at, dir, 4, "gold", 80.0, 0.3, "dot")

func _on_warning(_kind: String, at: Vector2, duration: float) -> void:
	if is_instance_valid(game) and bool(game.get("story_safe")):
		return
	if _warns.size() >= MAX_WARNINGS:
		_warns.remove_at(0)
	_warns.append({"at": at, "life": duration, "max": maxf(duration, 0.05)})

# ------------------------------------------------------------------ simulation

func _process(delta: float) -> void:
	_clock += delta
	for i: int in range(_parts.size() - 1, -1, -1):
		var q: Dictionary = _parts[i]
		q["life"] = float(q["life"]) - delta
		if float(q["life"]) <= 0.0:
			_parts.remove_at(i)
			continue
		var v: Vector2 = q["v"]
		v.y += float(q["grav"]) * delta
		v *= maxf(0.0, 1.0 - float(q["drag"]) * delta)
		q["v"] = v
		q["p"] = Vector2(q["p"]) + v * delta
	for i: int in range(_shapes.size() - 1, -1, -1):
		_shapes[i]["life"] = float(_shapes[i]["life"]) - delta
		if float(_shapes[i]["life"]) <= 0.0:
			_shapes.remove_at(i)
	if is_instance_valid(game) and bool(game.get("story_safe")):
		_warns.clear()
	for i: int in range(_warns.size() - 1, -1, -1):
		_warns[i]["life"] = float(_warns[i]["life"]) - delta
		if float(_warns[i]["life"]) <= 0.0:
			_warns.remove_at(i)
	queue_redraw()
	if _glow != null:
		_glow.queue_redraw()

# ------------------------------------------------------------------ drawing

func _draw() -> void:
	_paint(self, false)

func _paint(c: CanvasItem, glow: bool) -> void:
	for s: Dictionary in _shapes:
		var t: float = 1.0 - float(s["life"]) / float(s["max"])
		match String(s["type"]):
			"arc": _arc(c, s, t, glow)
			"ring": _ring(c, s, t, glow)
			"rays": _rays(c, s, t, glow)
			"star": _star(c, Vector2(s["at"]).round(), float(s["r"]) * (1.0 - t), String(s["ramp"]), t, glow)
			"pillar": _pillar(c, s, t, glow)
			"bars": _bars(c, s, t, glow)
	for q: Dictionary in _parts:
		_particle(c, q, glow)
	if not glow:
		for w: Dictionary in _warns:
			_warning(c, w)

func _arc(c: CanvasItem, s: Dictionary, t: float, glow: bool) -> void:
	var at: Vector2 = s["at"]
	var ramp: String = s["ramp"]
	var d: float = s["d"]
	var r: float = float(s["r"]) * (0.9 + 0.2 * minf(t * 3.0, 1.0))
	var half: float = s["half"]
	var ys: float = -1.0 if bool(s["flip"]) else 1.0
	var head: float = clampf(t / 0.4, 0.0, 1.0) * 1.2
	var tail: float = clampf((t - 0.25) / 0.75, 0.0, 1.0) * 1.2
	var pts := PackedVector2Array()
	var cols := PackedColorArray()
	var n: int = 18
	for k: int in range(n + 1):
		var pos: float = float(k) / float(n)
		if pos > head or pos < tail:
			continue
		var a: float = -half + 2.0 * half * pos
		pts.append((at + Vector2(cos(a) * r * d, sin(a) * r * 0.95 * ys)).round())
		var u: float = clampf((head - pos) * 0.9 + t * 0.5, 0.0, 1.0)
		var al: float = clampf((pos - tail) * 3.0 + 0.2, 0.0, 1.0) * (1.0 - t * t)
		cols.append(_col(ramp, u, al * (0.22 if glow else 1.0)))
	if pts.size() < 2:
		return
	var w: float = float(s["w"]) * (1.0 - 0.45 * t)
	if glow:
		c.draw_polyline_colors(pts, cols, roundf(w * 3.0), false)
		return
	c.draw_polyline_colors(pts, cols, maxf(1.0, roundf(w)), false)
	var core := PackedColorArray()
	for col: Color in cols:
		core.append(col.lerp(Color(1, 1, 1, col.a), 0.65))
	c.draw_polyline_colors(pts, core, maxf(1.0, roundf(w / 3.0)), false)

func _ring(c: CanvasItem, s: Dictionary, t: float, glow: bool) -> void:
	var at: Vector2 = s["at"]
	var ramp: String = s["ramp"]
	var ease_out: float = 1.0 - (1.0 - t) * (1.0 - t)
	var r: float = lerpf(float(s["r0"]), float(s["r1"]), ease_out)
	var ry: float = float(s.get("ry", 1.0))
	var w: float = maxf(1.0, roundf(float(s["w"]) * (1.0 - t)))
	var n: int = 28
	var pts := PackedVector2Array()
	var cols := PackedColorArray()
	for i: int in range(n + 1):
		var a: float = TAU * float(i) / float(n)
		pts.append((at + Vector2(cos(a) * r, sin(a) * r * ry)).round())
		var u: float = clampf(t * 0.45 + 0.45 * absf(2.0 * float(i) / float(n) - 1.0), 0.0, 1.0)
		cols.append(_col(ramp, u, (1.0 - t * t) * (0.2 if glow else 1.0)))
	c.draw_polyline_colors(pts, cols, w * (3.0 if glow else 1.0), false)

func _rays(c: CanvasItem, s: Dictionary, t: float, glow: bool) -> void:
	var at: Vector2 = s["at"]
	var ramp: String = s["ramp"]
	var n: int = int(s["n"])
	var r1: float = s["r1"]
	var outer_max: float = r1 * (1.0 - (1.0 - t) * (1.0 - t))
	var inner: float = outer_max * clampf(t * 1.4, 0.0, 0.85)
	var rot: float = float(s.get("rot", 0.0)) * t
	var al: float = (1.0 - t) * (0.25 if glow else 1.0)
	for i: int in n:
		var dir_v: Vector2 = Vector2.from_angle(TAU * float(i) / float(n) + rot)
		var outer: float = outer_max * (0.6 if i % 2 == 1 else 1.0)
		var hue: float = float(i) / float(n)
		var pts := PackedVector2Array([(at + dir_v * inner).round(), (at + dir_v * outer).round()])
		var cols := PackedColorArray([_col(ramp, t * 0.4 + 0.1, al, hue), _col(ramp, t * 0.4 + 0.5, al * 0.6, hue)])
		c.draw_polyline_colors(pts, cols, (3.0 if glow else (2.0 if t < 0.5 else 1.0)), false)

func _star(c: CanvasItem, at: Vector2, arm: float, ramp: String, t: float, glow: bool) -> void:
	if arm < 1.0:
		return
	var al: float = 1.0 - t
	if glow:
		var halo: Color = _col(ramp, 0.2 + t * 0.6, 0.2 * al)
		c.draw_rect(Rect2(at - Vector2(arm, arm) * 0.8, Vector2(arm, arm) * 1.6), halo)
		return
	var col: Color = _col(ramp, t * 0.8, al)
	var wid: float = 2.0 if t < 0.5 else 1.0
	c.draw_line(at + Vector2(-arm, 0.0), at + Vector2(arm, 0.0), col, wid)
	c.draw_line(at + Vector2(0.0, -arm), at + Vector2(0.0, arm), col, wid)
	var diag: float = arm * 0.55
	var col2: Color = _col(ramp, t * 0.8 + 0.2, al * 0.8)
	c.draw_line(at + Vector2(-diag, -diag), at + Vector2(diag, diag), col2, 1.0)
	c.draw_line(at + Vector2(-diag, diag), at + Vector2(diag, -diag), col2, 1.0)
	c.draw_rect(Rect2(at - Vector2.ONE, Vector2(3, 3)), Color(1, 1, 1, al))

func _pillar(c: CanvasItem, s: Dictionary, t: float, glow: bool) -> void:
	var at: Vector2 = s["at"]
	var ramp: String = s["ramp"]
	var h: float = float(s["h"]) * minf(t * 4.0 + 0.2, 1.0)
	var w0: float = float(s["w0"]) * (1.0 - t) * (3.0 if glow else 1.0)
	var y: float = 0.0
	while y < h:
		var f: float = y / maxf(h, 1.0)
		var wid: float = roundf(w0 * (1.0 - f * 0.6))
		if wid >= 1.0:
			var al: float = (1.0 - f) * (1.0 - t) * (0.18 if glow else 0.9)
			c.draw_rect(Rect2(roundf(at.x - wid * 0.5), roundf(at.y - y), wid, 2.0), _col(ramp, f * 0.9 + t * 0.3, al))
		y += 2.0

func _bars(c: CanvasItem, s: Dictionary, t: float, glow: bool) -> void:
	var at: Vector2 = s["at"]
	var ramp: String = s["ramp"]
	var back: float = -float(s["d"])
	var length: float = float(s["len"]) * (1.0 - 0.4 * t)
	var al: float = (1.0 - t) * (0.2 if glow else 1.0)
	var offsets: Array[float] = [-7.0, 0.0, 7.0]
	for j: int in offsets.size():
		var y: float = offsets[j]
		var l2: float = length * (1.0 if j == 1 else 0.7)
		var p0: Vector2 = (at + Vector2(0.0, y)).round()
		var p1: Vector2 = (at + Vector2(back * l2, y)).round()
		var cols := PackedColorArray([_col(ramp, t * 0.5, al), _col(ramp, 0.5 + t * 0.5, al * 0.5)])
		c.draw_polyline_colors(PackedVector2Array([p0, p1]), cols, (6.0 if glow else (2.0 if j == 1 else 1.0)), false)

func _particle(c: CanvasItem, q: Dictionary, glow: bool) -> void:
	var life_ratio: float = float(q["life"]) / float(q["max"])
	var u: float = 1.0 - life_ratio
	var al: float = minf(1.0, life_ratio * 2.0)
	var ramp: String = q["ramp"]
	var h: float = q["h"]
	var p: Vector2 = Vector2(q["p"]).round()
	var size: int = int(q["size"])
	match String(q["kind"]):
		"streak":
			if glow:
				c.draw_rect(Rect2(p - Vector2(3, 3), Vector2(6, 6)), _col(ramp, u, al * 0.18, h))
			else:
				var tail: Vector2 = (p - Vector2(q["v"]) * 0.04).round()
				c.draw_line(p, tail, _col(ramp, u, al, h), 2.0 if life_ratio > 0.5 else 1.0)
		"twinkle":
			var arm: float = roundf(float(size) * (0.6 + life_ratio * 1.6))
			if glow:
				c.draw_rect(Rect2(p - Vector2(arm, arm), Vector2(arm, arm) * 2.0), _col(ramp, u, al * 0.16, h))
			else:
				var col: Color = _col(ramp, u * 0.8, al, h)
				c.draw_line(p + Vector2(-arm, 0), p + Vector2(arm, 0), col, 1.0)
				c.draw_line(p + Vector2(0, -arm), p + Vector2(0, arm), col, 1.0)
				c.draw_rect(Rect2(p, Vector2.ONE), Color(1, 1, 1, al))
		_:
			if not glow:
				c.draw_rect(Rect2(p, Vector2.ONE * float(size)), _col(ramp, u, al, h))

func _warning(c: CanvasItem, w: Dictionary) -> void:
	var at: Vector2 = Vector2(w["at"]).round()
	var ratio: float = float(w["life"]) / float(w["max"])
	var prog: float = 1.0 - ratio
	var late: bool = ratio < 0.25 and int(_clock * 24.0) % 2 == 0
	var base: Color = Color("fff1bd") if late else Color("e9bb68")
	# Thin lane line plus marching ticks; it is only a cue and never fills the area.
	c.draw_line(at + Vector2(-17, 0), at + Vector2(17, 0), Color(base, 0.7), 2.0)
	var march: int = int(_clock * 24.0) % 4
	for i: int in 9:
		c.draw_rect(Rect2(at + Vector2(-16 + i * 4 + march - 4, -3), Vector2(2, 2)), Color(base, 0.55))
	# Progress strip: gold at the tail, white-hot at the leading edge.
	var strip: int = int(32.0 * prog)
	for x: int in range(0, strip, 2):
		var f: float = float(x) / maxf(float(strip), 1.0)
		c.draw_rect(Rect2(at + Vector2(-16 + x, 4), Vector2(2, 2)), _col("gold", 1.0 - f, 1.0))
	# Brackets close in toward the lane as the strike approaches.
	var gap: float = 17.0 + 12.0 * ratio
	for sgn: float in [-1.0, 1.0]:
		c.draw_rect(Rect2(at + Vector2(sgn * gap - 1.0, -4), Vector2(2, 8)), Color(base, 0.9))

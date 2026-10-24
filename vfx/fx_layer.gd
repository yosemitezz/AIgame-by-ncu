extends Node2D
## Presentation-only combat VFX. It listens to the game's existing signals (vfx_requested,
## warning_issued) and only READS actor state; it never touches physics, hit detection, damage or timing.
##
## Readability rules (docs/art-ui-contract.md):
##   telegraph = thin gold lane line, never a filled area, never drawn in story-safe sections;
##   hostile hits and shots = warm ramp (white, gold, coral, magenta), thin trails;
##   player / parry / reflected = "flow" ramp: a hue that slides along each stroke and over time;
##   big moments (burst, checkpoint, pickups) = rainbow.
## Layers: crisp pixel pass (this node) + additive glow pass (child) + additive afterimages (Ghost nodes).

const Level = preload("res://levels/bellkeep.gd")

const SIZE_BOOST: float = 1.75   # ring / ray / star / arc radii are this much larger than the first version
const SPEED_BOOST: float = 1.4
const MAX_PARTS: int = 520
const MAX_SHAPES: int = 64
const MAX_WARNINGS: int = 24
const MAX_GHOSTS: int = 28
const MAX_TRAIL_POINTS: int = 14
const TRAIL_LIFE: float = 0.34

const RAMP_SOURCE: Dictionary = {
	"cool": ["ffffff", "c4fff6", "72ece2", "5aa4ff", "a278ff", "ff7ad0"],
	"warm": ["ffffff", "fff1bd", "e9bb68", "ff9a5a", "ef7678", "b04aa8"],
	"hurt": ["ffffff", "ffc0b8", "ef7678", "c0405f", "5a1d4a"],
	"dust": ["f2f6d6", "b8c4cf", "77839c", "394462"],
	"gold": ["ffffff", "fff1bd", "e9bb68", "88704e"],
}

class Ghost extends Node2D:
	const PA = preload("res://assets/art/pixel_actor.gd")
	var kind: String = "hero"
	var state: String = "idle"
	var frame_index: int = 0
	var face: int = 1
	var life: float = 0.3
	var max_life: float = 0.3
	var tint: Color = Color.WHITE
	var base_alpha: float = 0.6

	func _draw() -> void:
		PA.paint(self, kind, state, frame_index, face)

	func tick(delta: float) -> bool:
		life -= delta
		var k: float = clampf(life / max_life, 0.0, 1.0)
		modulate = Color(tint.r, tint.g, tint.b, base_alpha * k * k)
		# Afterimages swell and stretch outward as they fade, so every move reads bigger than the sprite.
		var grow: float = 1.0 - k
		scale = Vector2(1.0 + grow * 0.34, 1.0 + grow * 0.2)
		return life <= 0.0

var game: Node = null
var _ramps: Dictionary = {}
var _parts: Array[Dictionary] = []
var _shapes: Array[Dictionary] = []
var _warns: Array[Dictionary] = []
var _ghosts: Array[Ghost] = []
var _body_trail: Array[Dictionary] = []
var _proj_trails: Dictionary = {}
var _clock: float = 0.0
var _ghost_clock: float = 0.0
var _boss_ghost_clock: float = 0.0
var _run_clock: float = 0.0
var _run_ghost_clock: float = 0.0
var _mote_clock: float = 0.0
var _shard_clock: float = 0.0
var _rng := RandomNumberGenerator.new()
var _glow: Node2D = null
var _add_material: CanvasItemMaterial = null

func _ready() -> void:
	z_index = 6
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_rng.seed = 20261024
	for key: String in RAMP_SOURCE:
		var stops := PackedColorArray()
		for hex: String in RAMP_SOURCE[key]:
			stops.append(Color(hex))
		_ramps[key] = stops
	_add_material = CanvasItemMaterial.new()
	_add_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_glow = Node2D.new()
	_glow.material = _add_material
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

func ghost_count() -> int:
	return _ghosts.size()

# ------------------------------------------------------------------ colour

func _col(ramp: String, u: float, a: float = 1.0, h: float = 0.0) -> Color:
	u = clampf(u, 0.0, 1.0)
	var c: Color
	if ramp == "rainbow":
		var sat: float = clampf(u * 5.0, 0.0, 1.0) * 0.62
		c = Color.from_hsv(fposmod(u * 0.85 + h + _clock * 0.6, 1.0), sat, 1.0)
	elif ramp == "flow":
		# Light flowing along the effect: hue slides with position along the stroke and with time.
		var sat2: float = clampf(u * 4.0, 0.0, 1.0) * 0.8
		c = Color.from_hsv(fposmod(0.5 + u * 0.55 + h + _clock * 1.3, 1.0), sat2, 1.0)
	else:
		var stops: PackedColorArray = _ramps[ramp]
		var f: float = u * float(stops.size() - 1)
		var i: int = mini(int(f), stops.size() - 2)
		c = stops[i].lerp(stops[i + 1], f - float(i))
	c.a = clampf(a, 0.0, 1.0)
	return c

func _player() -> Node2D:
	if not is_instance_valid(game):
		return null
	var p: Variant = game.get("player")
	if p != null and is_instance_valid(p):
		return p as Node2D
	return null

# ------------------------------------------------------------------ spawning

func _part(at: Vector2, vel: Vector2, life: float, ramp: String, size: int = 2, kind: String = "dot", grav: float = 100.0, drag: float = 0.0) -> void:
	if _parts.size() >= MAX_PARTS:
		return
	_parts.append({"p": at, "v": vel, "life": life, "max": life, "ramp": ramp, "size": size, "kind": kind, "grav": grav, "drag": drag, "h": _rng.randf()})

func _shape(type: String, at: Vector2, life: float, ramp: String, extra: Dictionary = {}) -> void:
	if _shapes.size() >= MAX_SHAPES:
		_shapes.remove_at(0)
	var s: Dictionary = {"type": type, "at": at, "life": life, "max": life, "ramp": ramp}
	for key: String in extra:
		var v: Variant = extra[key]
		if key in ["r", "r0", "r1", "h", "w0", "len"]:
			v = float(v) * SIZE_BOOST
		elif key == "w":
			v = float(v) * 1.5
		s[key] = v
	if type == "arc":
		var pl: Node2D = _player()
		if pl != null:
			s["rel"] = at - pl.global_position   # the crescent rides along with the hero
	_shapes.append(s)

func _sparks(at: Vector2, dir: Vector2, n: int, ramp: String, speed: float, life: float, kind: String = "streak", spread: float = 0.9) -> void:
	var has_dir: bool = dir.length() > 0.01
	var base: float = dir.angle() if has_dir else 0.0
	var spr: float = spread if has_dir else PI
	for _i: int in n:
		var a: float = base + _rng.randf_range(-spr, spr)
		var sp: float = speed * SPEED_BOOST * _rng.randf_range(0.45, 1.0)
		var l: float = life * _rng.randf_range(0.6, 1.0)
		_part(at, Vector2.from_angle(a) * sp, l, ramp, _rng.randi_range(2, 4), kind, 160.0, 2.2)

func _hostile_near(at: Vector2) -> bool:
	var b: Variant = game.get("boss") if is_instance_valid(game) else null
	return b != null and is_instance_valid(b) and at.distance_to((b as Node2D).global_position) < 90.0

func _ghost(source: Node2D, kind: String, tint: Color, alpha: float, life: float) -> void:
	if _ghosts.size() >= MAX_GHOSTS:
		var old: Ghost = _ghosts.pop_front()
		old.queue_free()
	var g := Ghost.new()
	g.kind = kind
	g.state = String(source.get("animation_state"))
	g.frame_index = int(source.get("frame"))
	g.face = int(source.get("facing"))
	g.life = life
	g.max_life = life
	g.tint = tint
	g.base_alpha = alpha
	g.material = _add_material
	g.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	g.z_index = -4
	g.position = source.global_position
	add_child(g)
	_ghosts.append(g)

func spawn(kind: String, at: Vector2, dir: Vector2, power: float) -> void:
	var d: float = 1.0 if dir.x >= 0.0 else -1.0
	match kind:
		"slash":
			var combo: int = clampi(int(roundf(power)), 1, 3)
			# Wide, layered crescents: a big flowing outer sweep, a rainbow middle, a white-hot inner edge.
			_shape("arc", at, 0.38 + 0.06 * float(combo), "flow", {"d": d, "r": 30.0 + 8.0 * float(combo), "w": 4.0 + float(combo) * 1.5, "flip": combo == 2, "half": 1.5 if combo < 3 else 2.2, "sweep": true})
			_shape("arc", at, 0.32 + 0.05 * float(combo), "rainbow", {"d": d, "r": 23.0 + 6.0 * float(combo), "w": 3.0, "flip": combo == 2, "half": 1.3 if combo < 3 else 1.9})
			_shape("arc", at, 0.26 + 0.05 * float(combo), "cool", {"d": d, "r": 15.0 + 4.0 * float(combo), "w": 2.0, "flip": combo == 2, "half": 1.1 if combo < 3 else 1.6})
			_shape("streaks", at + Vector2(d * 10.0, 0.0), 0.3, "flow", {"d": d, "len": 38.0 + 10.0 * float(combo), "n": 4 + combo})
			_sparks(at + Vector2(d * 18.0, 0.0), Vector2(d, 0.0), 12 + combo * 5, "flow", 200.0, 0.55)
			_sparks(at + Vector2(d * 18.0, 0.0), Vector2(d, 0.0), 6 + combo * 2, "rainbow", 150.0, 0.7, "shard", 1.3)
			_shape("star", at + Vector2(d * 24.0, 0.0), 0.26, "flow", {"r": 9.0 + 3.0 * float(combo)})
			if combo == 3:
				_shape("ring", at + Vector2(d * 12.0, 0.0), 0.5, "flow", {"r0": 6.0, "r1": 52.0, "w": 5.0, "ry": 0.75})
				_shape("ring", at + Vector2(d * 12.0, 0.0), 0.4, "rainbow", {"r0": 4.0, "r1": 36.0, "w": 3.0, "ry": 0.75})
				_sparks(at + Vector2(d * 22.0, 0.0), Vector2(d, 0.0), 22, "rainbow", 280.0, 0.8, "twinkle", 1.3)
		"enemy_slash":
			_shape("arc", at, 0.28, "warm", {"d": d, "r": 18.0 + 8.0 * power, "w": 3.0, "flip": false, "half": 1.3})
			_sparks(at + Vector2(d * 14.0, 0.0), Vector2(d, 0.0), 8, "warm", 130.0, 0.4)
		"parry":
			# Sekiro-style deflect: one instant white-hot cross flash, then a fan of fast sparks thrown
			# along the clash line, a hard shock ring, and long horizontal streaks. Colour only blooms
			# afterwards, so the first frames read as steel on steel.
			_shape("flash", at, 0.12, "cool", {"r": 34.0 + 10.0 * power})
			_shape("cross", at, 0.2, "cool", {"r": 30.0 + 8.0 * power, "d": d})
			_shape("streaks", at, 0.34, "flow", {"d": d, "len": 46.0, "n": 5, "both": true})
			_shape("ring", at, 0.28, "cool", {"r0": 3.0, "r1": 40.0 + 10.0 * power, "w": 5.0, "ry": 1.0})
			_shape("ring", at, 0.5, "flow", {"r0": 6.0, "r1": 62.0 + 14.0 * power, "w": 4.0, "ry": 1.0})
			_shape("ring", at, 0.42, "rainbow", {"r0": 2.0, "r1": 34.0 + 8.0 * power, "w": 3.0, "ry": 1.0})
			_shape("rays", at, 0.5, "flow", {"n": 18, "r1": 38.0 + 10.0 * power, "rot": 1.2})
			_shape("star", at, 0.3, "cool", {"r": 18.0})
			# Two fans: forward (where the blow came from) and back, like blades scraping apart.
			_sparks(at, Vector2(d, -0.15), 30, "warm", 380.0, 0.55, "streak", 0.55)
			_sparks(at, Vector2(-d, -0.25), 16, "cool", 300.0, 0.55, "streak", 0.5)
			_sparks(at, Vector2.ZERO, 22, "flow", 260.0, 0.8, "streak", PI)
			_sparks(at, Vector2.ZERO, 16, "rainbow", 150.0, 0.9, "shard", PI)
			_sparks(at, Vector2.ZERO, 12, "rainbow", 100.0, 0.9, "twinkle", PI)
			var pl: Node2D = _player()
			if pl != null:
				_ghost(pl, "hero", Color(0.55, 1.0, 0.95), 0.85, 0.45)
				_ghost(pl, "hero", Color(1.0, 0.6, 0.95), 0.5, 0.65)
		"parry_ready":
			_shape("ring", at, 0.2, "cool", {"r0": 16.0, "r1": 5.0, "w": 2.0, "ry": 1.0})
		"hit":
			_shape("flash", at, 0.1, "warm", {"r": 22.0 + 8.0 * power})
			_shape("star", at, 0.28, "warm", {"r": 16.0 + 5.0 * power})
			_shape("rays", at, 0.34, "warm", {"n": 14, "r1": 28.0 + 8.0 * power, "rot": 0.0})
			_shape("ring", at, 0.3, "warm", {"r0": 2.0, "r1": 26.0 + 8.0 * power, "w": 3.0, "ry": 1.0})
			_sparks(at, dir, 22, "warm", 260.0, 0.6, "streak", 1.2)
			_sparks(at, dir, 12, "rainbow", 150.0, 0.8, "shard", 1.6)
			_sparks(at, dir, 8, "warm", 120.0, 0.7, "deb", 1.6)
		"hurt":
			_shape("ring", at, 0.36, "hurt", {"r0": 3.0, "r1": 26.0, "w": 4.0, "ry": 1.0})
			_shape("star", at, 0.24, "hurt", {"r": 12.0})
			_sparks(at, dir, 16, "hurt", 200.0, 0.55, "streak", 1.6)
		"dash":
			var hostile: bool = _hostile_near(at)
			_shape("bars", at, 0.4, "warm" if hostile else "flow", {"d": 1.0 if dir.x >= 0.0 else -1.0, "len": 26.0 * clampf(power, 0.5, 1.5)})
			_sparks(at, dir, 3, "warm" if hostile else "flow", 60.0, 0.4, "twinkle", 1.0)
		"jump":
			_shape("ring", at, 0.28, "dust", {"r0": 2.0, "r1": 13.0, "w": 2.0, "ry": 0.3})
			_sparks(at, Vector2.ZERO, 6, "dust", 50.0, 0.35, "dot", 0.5)
		"air_jump":
			_shape("ring", at, 0.4, "flow", {"r0": 3.0, "r1": 24.0, "w": 3.0, "ry": 0.35})
			_shape("ring", at, 0.3, "rainbow", {"r0": 2.0, "r1": 14.0, "w": 2.0, "ry": 0.35})
			_sparks(at, Vector2(0.0, 1.0), 7, "flow", 70.0, 0.45, "twinkle", 1.3)
			var pl2: Node2D = _player()
			if pl2 != null:
				_ghost(pl2, "hero", Color(0.7, 0.85, 1.0), 0.6, 0.3)
		"land":
			_shape("ring", at, 0.3, "dust", {"r0": 3.0, "r1": 20.0, "w": 2.0, "ry": 0.28})
			_sparks(at + Vector2(0.0, -1.0), Vector2(0.0, -1.0), 7, "dust", 70.0, 0.35, "dot", 1.4)
		"pickup":
			var n: int = clampi(int(10.0 * power), 4, 14)
			_shape("star", at, 0.36, "rainbow", {"r": 5.0 + 4.0 * power})
			_shape("ring", at, 0.4, "rainbow", {"r0": 2.0, "r1": 12.0 + 6.0 * power, "w": 2.0, "ry": 1.0})
			for _i: int in n:
				_part(at, Vector2(_rng.randf_range(-50.0, 50.0), _rng.randf_range(-130.0, -30.0)), _rng.randf_range(0.6, 1.1), "rainbow", 2, "twinkle", 30.0, 1.0)
		"checkpoint":
			_shape("pillar", at + Vector2(0.0, 20.0), 1.3, "rainbow", {"h": 96.0, "w0": 14.0})
			_shape("ring", at + Vector2(0.0, 20.0), 0.9, "rainbow", {"r0": 4.0, "r1": 44.0, "w": 4.0, "ry": 0.3})
			_shape("ring", at + Vector2(0.0, 12.0), 1.1, "flow", {"r0": 4.0, "r1": 30.0, "w": 3.0, "ry": 0.3})
			for _i: int in 30:
				_part(at + Vector2(_rng.randf_range(-8.0, 8.0), 20.0), Vector2(_rng.randf_range(-24.0, 24.0), _rng.randf_range(-150.0, -40.0)), _rng.randf_range(0.8, 1.5), "rainbow", 2, "twinkle", -10.0, 0.8)
		"death":
			_shape("star", at, 0.3, "warm", {"r": 14.0 * power})
			_shape("rays", at, 0.4, "warm", {"n": 12, "r1": 32.0 * power, "rot": 0.8})
			_shape("ring", at, 0.46, "warm", {"r0": 4.0, "r1": 30.0 * power, "w": 4.0, "ry": 0.9})
			_sparks(at, Vector2.ZERO, 22, "warm", 190.0, 0.7)
			_sparks(at, Vector2.UP, 10, "warm", 110.0, 0.8, "deb", 1.2)
		"burst", "boss_defeat":
			var big: float = maxf(power, 1.0)
			_shape("star", at, 0.5, "rainbow", {"r": 26.0 * big})
			_shape("rays", at, 0.9, "rainbow", {"n": 20, "r1": 54.0 * big, "rot": 2.4})
			_shape("ring", at, 0.7, "rainbow", {"r0": 4.0, "r1": 60.0 * big, "w": 5.0, "ry": 1.0})
			_shape("ring", at, 0.95, "flow", {"r0": 2.0, "r1": 90.0 * big, "w": 3.0, "ry": 0.8})
			_shape("ring", at, 1.2, "warm", {"r0": 2.0, "r1": 120.0 * big, "w": 2.0, "ry": 0.7})
			_sparks(at, Vector2.ZERO, 50, "rainbow", 300.0, 1.2)
			_sparks(at, Vector2.ZERO, 22, "rainbow", 140.0, 1.3, "twinkle")
		"spark":
			_shape("star", at, 0.18, "gold", {"r": 5.0})
			_sparks(at, dir, 6, "gold", 120.0, 0.3)
		"warning", "telegraph":
			# Telegraphs stay gold. A small pulse only; the lane itself is drawn from warning_issued.
			_shape("star", at, 0.24, "gold", {"r": 6.0})
		_:
			_sparks(at, dir, 5, "gold", 80.0, 0.35, "dot")

func _on_warning(_kind: String, at: Vector2, duration: float) -> void:
	if is_instance_valid(game) and bool(game.get("story_safe")):
		return
	if _warns.size() >= MAX_WARNINGS:
		_warns.remove_at(0)
	_warns.append({"at": at, "life": duration, "max": maxf(duration, 0.05)})

# ------------------------------------------------------------------ simulation

func _process(delta: float) -> void:
	_clock += delta
	_follow_actors(delta)
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
		var s: Dictionary = _shapes[i]
		s["life"] = float(s["life"]) - delta
		if s.get("sweep", false):
			_sweep_sparks(s)
		if float(s["life"]) <= 0.0:
			_shapes.remove_at(i)
	if is_instance_valid(game) and bool(game.get("story_safe")):
		_warns.clear()
	for i: int in range(_warns.size() - 1, -1, -1):
		_warns[i]["life"] = float(_warns[i]["life"]) - delta
		if float(_warns[i]["life"]) <= 0.0:
			_warns.remove_at(i)
	for i: int in range(_ghosts.size() - 1, -1, -1):
		if _ghosts[i].tick(delta):
			_ghosts[i].queue_free()
			_ghosts.remove_at(i)
	queue_redraw()
	if _glow != null:
		_glow.queue_redraw()

func _arc_at(s: Dictionary) -> Vector2:
	var at: Vector2 = s["at"]
	if s.has("rel"):
		var pl: Node2D = _player()
		if pl != null:
			at = pl.global_position + Vector2(s["rel"])
	return at

func _sweep_sparks(s: Dictionary) -> void:
	## Sparks leave the tip of the crescent as it sweeps, so the light visibly travels along the cut.
	var t: float = 1.0 - float(s["life"]) / float(s["max"])
	if t > 0.5 or _parts.size() > MAX_PARTS - 40:
		return
	var pos: float = minf(clampf(t / 0.4, 0.0, 1.0) * 1.2, 1.0)
	var half: float = s["half"]
	var a: float = -half + 2.0 * half * pos
	var ys: float = -1.0 if bool(s["flip"]) else 1.0
	var d: float = s["d"]
	var r: float = float(s["r"])
	var tip: Vector2 = _arc_at(s) + Vector2(cos(a) * r * d, sin(a) * r * 0.95 * ys)
	var out: Vector2 = (tip - _arc_at(s)).normalized()
	for _i: int in 2:
		_part(tip, out * _rng.randf_range(30.0, 110.0) + Vector2(_rng.randf_range(-20.0, 20.0), _rng.randf_range(-20.0, 20.0)), _rng.randf_range(0.25, 0.5), "flow", _rng.randi_range(2, 3), "streak", 40.0, 2.0)

func _follow_actors(delta: float) -> void:
	var pl: Node2D = _player()
	var safe: bool = is_instance_valid(game) and bool(game.get("story_safe"))
	# Body ribbon and afterimages follow the hero, so every action leaves a continuous light path.
	if pl != null:
		var dash_t: float = float(pl.get("dash_timer"))
		var atk_t: float = float(pl.get("attack_timer"))
		var vel: Vector2 = pl.get("velocity")
		var strength: float = 0.0
		if dash_t > 0.0:
			strength = 1.0
		elif atk_t > 0.0:
			strength = 0.75
		elif absf(vel.x) > 60.0:
			strength = 0.55 if is_on_floor_safe(pl) else 0.4
		_body_trail.append({"p": pl.global_position + Vector2(0.0, -14.0), "age": 0.0, "k": strength})
		# Running: a flowing scarf of light from the shoulders, dust-and-colour kicks at the heels, and
		# a faint afterimage every few frames so walking reads as a continuous motion path.
		var running: bool = absf(vel.x) > 60.0 and dash_t <= 0.0
		if running:
			var fdir: float = 1.0 if vel.x >= 0.0 else -1.0
			_run_clock -= delta
			if _run_clock <= 0.0:
				_run_clock = 0.05
				var shoulder: Vector2 = pl.global_position + Vector2(-fdir * 4.0, -26.0)
				_part(shoulder, Vector2(-fdir * _rng.randf_range(50.0, 110.0), _rng.randf_range(-14.0, 14.0)), _rng.randf_range(0.28, 0.5), "flow", 3, "streak", 10.0, 1.5)
				_part(shoulder + Vector2(0.0, 6.0), Vector2(-fdir * _rng.randf_range(40.0, 90.0), _rng.randf_range(-8.0, 20.0)), _rng.randf_range(0.3, 0.55), "rainbow", 2, "twinkle", 0.0, 1.4)
				if is_on_floor_safe(pl):
					_part(pl.global_position + Vector2(-fdir * 6.0, -1.0), Vector2(-fdir * _rng.randf_range(20.0, 60.0), _rng.randf_range(-40.0, -12.0)), _rng.randf_range(0.2, 0.4), "dust", 2, "dot", 120.0, 2.0)
			_run_ghost_clock -= delta
			if _run_ghost_clock <= 0.0:
				_run_ghost_clock = 0.07
				_ghost(pl, "hero", Color.from_hsv(fposmod(_clock * 1.2 + 0.55, 1.0), 0.55, 1.0), 0.32, 0.26)
		_ghost_clock -= delta
		if dash_t > 0.0 and _ghost_clock <= 0.0:
			_ghost_clock = 0.03
			_ghost(pl, "hero", Color.from_hsv(fposmod(_clock * 1.7, 1.0), 0.75, 1.0), 0.75, 0.4)
		elif atk_t > 0.0 and _ghost_clock <= 0.0:
			_ghost_clock = 0.055
			_ghost(pl, "hero", Color.from_hsv(fposmod(_clock * 1.7 + 0.3, 1.0), 0.65, 1.0), 0.45, 0.3)
		_mote_clock -= delta
		if _mote_clock <= 0.0 and _parts.size() < MAX_PARTS - 140:
			_mote_clock = 0.07
			var center: Vector2 = pl.global_position
			_part(Vector2(center.x + _rng.randf_range(-280.0, 280.0), _rng.randf_range(90.0, 300.0)), Vector2(_rng.randf_range(-8.0, 8.0), _rng.randf_range(-22.0, -6.0)), _rng.randf_range(1.6, 2.8), "flow", 1, "dot", 0.0, 0.0)
		_shard_clock -= delta
		if _shard_clock <= 0.0 and _parts.size() < MAX_PARTS - 100:
			_shard_clock = 0.12
			_shimmer_shard(center_of(pl))
	for i: int in range(_body_trail.size() - 1, -1, -1):
		_body_trail[i]["age"] = float(_body_trail[i]["age"]) + delta
		if float(_body_trail[i]["age"]) > TRAIL_LIFE:
			_body_trail.remove_at(i)
	while _body_trail.size() > MAX_TRAIL_POINTS * 2:
		_body_trail.remove_at(0)
	# Boss dash afterimages in the hostile (warm) palette.
	var boss: Variant = game.get("boss") if is_instance_valid(game) else null
	_boss_ghost_clock -= delta
	if boss != null and is_instance_valid(boss) and not safe and String((boss as Node2D).get("animation_state")) == "dash" and _boss_ghost_clock <= 0.0:
		_boss_ghost_clock = 0.05
		_ghost(boss as Node2D, "boss", Color(1.0, 0.55, 0.45), 0.5, 0.35)
	_track_projectiles()

func is_on_floor_safe(n: Node2D) -> bool:
	return n.has_method("is_on_floor") and bool(n.call("is_on_floor"))

func center_of(n: Node2D) -> Vector2:
	return n.global_position

func _shimmer_shard(near: Vector2) -> void:
	var shards: Array[Vector2] = Level.SHARDS
	var collected: Dictionary = game.get("_collected") if is_instance_valid(game) and game.get("_collected") != null else {}
	var i: int = _rng.randi_range(0, shards.size() - 1)
	var at: Vector2 = shards[i]
	if collected.has(i) or at.distance_to(near) > 380.0:
		return
	_part(at + Vector2(_rng.randf_range(-6.0, 6.0), 4.0), Vector2(_rng.randf_range(-6.0, 6.0), _rng.randf_range(-40.0, -18.0)), _rng.randf_range(0.7, 1.2), "rainbow", 2, "twinkle", -6.0, 0.6)

func _track_projectiles() -> void:
	var seen: Dictionary = {}
	for node: Node in get_tree().get_nodes_in_group("projectiles"):
		if not is_instance_valid(node):
			continue
		var id: int = node.get_instance_id()
		seen[id] = true
		var trail: Array = _proj_trails.get(id, [])
		trail.append((node as Node2D).global_position)
		while trail.size() > 12:
			trail.pop_front()
		_proj_trails[id] = {"pts": trail, "friendly": bool(node.get("friendly"))}
	for id: Variant in _proj_trails.keys():
		if not seen.has(id):
			_proj_trails.erase(id)

# ------------------------------------------------------------------ drawing

func _draw() -> void:
	_paint(self, false)

func _paint(c: CanvasItem, glow: bool) -> void:
	_draw_projectile_trails(c, glow)
	_draw_body_trail(c, glow)
	for s: Dictionary in _shapes:
		var t: float = 1.0 - float(s["life"]) / float(s["max"])
		match String(s["type"]):
			"arc": _arc(c, s, t, glow)
			"ring": _ring(c, s, t, glow)
			"rays": _rays(c, s, t, glow)
			"star": _star(c, Vector2(s["at"]).round(), float(s["r"]) * (1.0 - t), String(s["ramp"]), t, glow)
			"pillar": _pillar(c, s, t, glow)
			"bars": _bars(c, s, t, glow)
			"flash": _flash(c, s, t, glow)
			"cross": _cross(c, s, t, glow)
			"streaks": _streaks(c, s, t, glow)
	for q: Dictionary in _parts:
		_particle(c, q, glow)
	if not glow:
		for w: Dictionary in _warns:
			_warning(c, w)

func _draw_body_trail(c: CanvasItem, glow: bool) -> void:
	var n: int = _body_trail.size()
	if n < 2:
		return
	for i: int in range(1, n):
		var a: Dictionary = _body_trail[i - 1]
		var b: Dictionary = _body_trail[i]
		var k: float = float(b["k"])
		if k <= 0.05:
			continue
		var life: float = 1.0 - float(b["age"]) / TRAIL_LIFE
		var u: float = float(i) / float(n)
		var width: float = roundf((2.0 + 9.0 * k) * life) * (2.4 if glow else 1.0)
		if width < 1.0:
			continue
		var al: float = life * k * (0.2 if glow else 0.85)
		var pa: Vector2 = Vector2(a["p"]).round()
		var pb: Vector2 = Vector2(b["p"]).round()
		if pa.distance_to(pb) > 60.0:
			continue
		c.draw_line(pa, pb, _col("flow", u, al, float(i) * 0.03), width, false)

func _draw_projectile_trails(c: CanvasItem, glow: bool) -> void:
	for id: Variant in _proj_trails:
		var info: Dictionary = _proj_trails[id]
		var pts: Array = info["pts"]
		var n: int = pts.size()
		if n < 2:
			continue
		var friendly: bool = info["friendly"]
		var line := PackedVector2Array()
		var cols := PackedColorArray()
		for i: int in n:
			var u: float = float(i) / float(n - 1)   # 1 = head
			line.append(Vector2(pts[i]).round())
			if friendly:
				cols.append(_col("flow", 1.0 - u, u * (0.22 if glow else 0.9), float(i) * 0.04))
			else:
				# Hostile shots keep a thin, low-alpha warm tail so safe lanes stay readable.
				cols.append(_col("warm", 0.2 + (1.0 - u) * 0.6, u * (0.1 if glow else 0.42)))
		var w: float = 3.0 if friendly else 2.0
		c.draw_polyline_colors(line, cols, w * (2.6 if glow else 1.0), false)

func _arc(c: CanvasItem, s: Dictionary, t: float, glow: bool) -> void:
	var at: Vector2 = _arc_at(s)
	var ramp: String = s["ramp"]
	var d: float = s["d"]
	var r: float = float(s["r"]) * (0.85 + 0.25 * minf(t * 3.0, 1.0))
	var half: float = s["half"]
	var ys: float = -1.0 if bool(s["flip"]) else 1.0
	var head: float = clampf(t / 0.4, 0.0, 1.0) * 1.2
	var tail: float = clampf((t - 0.25) / 0.75, 0.0, 1.0) * 1.2
	var n: int = 22
	var outer: Array[Vector2] = []
	var inner: Array[Vector2] = []
	var cols_o: Array[Color] = []
	var cols_i: Array[Color] = []
	var idx: Array[float] = []
	var thick: float = clampf(float(s["w"]) / 24.0 + 0.2, 0.2, 0.5)
	for k: int in range(n + 1):
		var pos: float = float(k) / float(n)
		if pos > head or pos < tail:
			continue
		var a: float = -half + 2.0 * half * pos
		var dirv := Vector2(cos(a) * d, sin(a) * 0.95 * ys)
		var inner_r: float = r * (1.0 - 0.05 - thick * sin(PI * pos))
		outer.append(at + dirv * r)
		inner.append(at + dirv * inner_r)
		var u: float = clampf((head - pos) * 0.9 + t * 0.5, 0.0, 1.0)
		var al: float = clampf((pos - tail) * 3.0 + 0.2, 0.0, 1.0) * (1.0 - t * t)
		cols_o.append(_col(ramp, u, al * (0.2 if glow else 1.0)))
		cols_i.append(_col(ramp, minf(u + 0.3, 1.0), al * (0.04 if glow else 0.12)))
		idx.append(pos)
	if outer.size() < 2:
		return
	if not glow:
		# Filled crescent: bright leading edge fading toward the inside, hue flowing along the cut.
		for k: int in range(outer.size() - 1):
			c.draw_polygon(PackedVector2Array([outer[k], outer[k + 1], inner[k + 1], inner[k]]), PackedColorArray([cols_o[k], cols_o[k + 1], cols_i[k + 1], cols_i[k]]))
	var edge := PackedVector2Array()
	for p: Vector2 in outer:
		edge.append(p.round())
	var w: float = float(s["w"]) * (1.0 - 0.45 * t)
	if glow:
		c.draw_polyline_colors(edge, PackedColorArray(cols_o), roundf(w * 3.0), false)
		return
	c.draw_polyline_colors(edge, PackedColorArray(cols_o), maxf(1.0, roundf(w * 0.6)), false)
	var core := PackedColorArray()
	for col: Color in cols_o:
		core.append(col.lerp(Color(1, 1, 1, col.a), 0.7))
	c.draw_polyline_colors(edge, core, maxf(1.0, roundf(w / 4.0)), false)

func _ring(c: CanvasItem, s: Dictionary, t: float, glow: bool) -> void:
	var at: Vector2 = s["at"]
	var ramp: String = s["ramp"]
	var ease_out: float = 1.0 - (1.0 - t) * (1.0 - t)
	var r: float = lerpf(float(s["r0"]), float(s["r1"]), ease_out)
	var ry: float = float(s.get("ry", 1.0))
	var w: float = maxf(1.0, roundf(float(s["w"]) * (1.0 - t)))
	var n: int = 32
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
		c.draw_polyline_colors(pts, cols, (4.0 if glow else (3.0 if t < 0.5 else 2.0)), false)

func _star(c: CanvasItem, at: Vector2, arm: float, ramp: String, t: float, glow: bool) -> void:
	if arm < 1.0:
		return
	var al: float = 1.0 - t
	if glow:
		var halo: Color = _col(ramp, 0.2 + t * 0.6, 0.2 * al)
		c.draw_rect(Rect2(at - Vector2(arm, arm) * 0.8, Vector2(arm, arm) * 1.6), halo)
		return
	var col: Color = _col(ramp, t * 0.8, al)
	var wid: float = 3.0 if t < 0.5 else 2.0
	c.draw_line(at + Vector2(-arm, 0.0), at + Vector2(arm, 0.0), col, wid)
	c.draw_line(at + Vector2(0.0, -arm), at + Vector2(0.0, arm), col, wid)
	var diag: float = arm * 0.6
	var col2: Color = _col(ramp, t * 0.8 + 0.2, al * 0.8)
	c.draw_line(at + Vector2(-diag, -diag), at + Vector2(diag, diag), col2, 1.0)
	c.draw_line(at + Vector2(-diag, diag), at + Vector2(diag, -diag), col2, 1.0)
	c.draw_rect(Rect2(at - Vector2(1, 1), Vector2(3, 3)), Color(1, 1, 1, al))

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

func _flash(c: CanvasItem, s: Dictionary, t: float, glow: bool) -> void:
	## One-to-two frame white-hot bloom at the contact point. Only drawn in the glow pass plus a tiny core.
	var at: Vector2 = Vector2(s["at"]).round()
	var r: float = float(s["r"]) * (0.5 + 0.8 * t)
	var al: float = (1.0 - t) * (1.0 - t)
	if glow:
		for k: int in 3:
			var rr: float = r * (1.0 - 0.28 * float(k))
			c.draw_rect(Rect2(at - Vector2(rr, rr), Vector2(rr, rr) * 2.0), _col("cool", 0.1 + 0.25 * float(k), al * 0.22))
	else:
		var core: float = r * 0.28
		c.draw_rect(Rect2(at - Vector2(core, core), Vector2(core, core) * 2.0), Color(1, 1, 1, al))

func _cross(c: CanvasItem, s: Dictionary, t: float, glow: bool) -> void:
	## Hard-edged four-point glint: long thin horizontal bar, shorter vertical, diagonals. Shrinks fast.
	var at: Vector2 = Vector2(s["at"]).round()
	var r: float = float(s["r"]) * (1.0 - t * t)
	if r < 2.0:
		return
	var al: float = 1.0 - t
	var wide: float = 4.0 if t < 0.35 else 2.0
	if glow:
		c.draw_line(at + Vector2(-r * 1.4, 0.0), at + Vector2(r * 1.4, 0.0), _col("cool", 0.3, al * 0.25), wide * 3.0)
		c.draw_line(at + Vector2(0.0, -r * 0.8), at + Vector2(0.0, r * 0.8), _col("flow", 0.3, al * 0.2), wide * 3.0)
		return
	c.draw_line(at + Vector2(-r * 1.4, 0.0), at + Vector2(r * 1.4, 0.0), Color(1, 1, 1, al), wide)
	c.draw_line(at + Vector2(0.0, -r * 0.8), at + Vector2(0.0, r * 0.8), Color(1, 1, 1, al), wide - 1.0)
	var dg: float = r * 0.6
	c.draw_line(at + Vector2(-dg, -dg), at + Vector2(dg, dg), _col("flow", t, al * 0.9), 2.0)
	c.draw_line(at + Vector2(-dg, dg), at + Vector2(dg, -dg), _col("flow", t + 0.3, al * 0.9), 2.0)

func _streaks(c: CanvasItem, s: Dictionary, t: float, glow: bool) -> void:
	## Long speed lines that stretch out and slide: gradient from white at the root to colour at the tip.
	var at: Vector2 = Vector2(s["at"]).round()
	var ramp: String = s["ramp"]
	var n: int = int(s["n"])
	var d: float = s["d"]
	var both: bool = s.get("both", false)
	var reach: float = float(s["len"]) * (1.0 - (1.0 - t) * (1.0 - t))
	var al: float = (1.0 - t) * (0.2 if glow else 1.0)
	for i: int in n:
		var off: float = (float(i) - float(n - 1) * 0.5) * 5.0
		var shrink: float = 1.0 - absf(float(i) - float(n - 1) * 0.5) / float(n) * 0.9
		for side: int in (2 if both else 1):
			var sgn: float = d * (1.0 if side == 0 else -1.0)
			var p0: Vector2 = (at + Vector2(sgn * reach * 0.12, off)).round()
			var p1: Vector2 = (at + Vector2(sgn * reach * shrink, off * 1.5)).round()
			var cols := PackedColorArray([Color(1, 1, 1, al), _col(ramp, 0.4 + t * 0.5, al * 0.7, float(i) * 0.12)])
			c.draw_polyline_colors(PackedVector2Array([p0, p1]), cols, (6.0 if glow else (3.0 if i == n / 2 else 2.0)), false)

func _bars(c: CanvasItem, s: Dictionary, t: float, glow: bool) -> void:
	var at: Vector2 = s["at"]
	var ramp: String = s["ramp"]
	var back: float = -float(s["d"])
	var length: float = float(s["len"]) * (1.0 - 0.4 * t)
	var al: float = (1.0 - t) * (0.2 if glow else 1.0)
	var offsets: Array[float] = [-9.0, 0.0, 9.0]
	for j: int in offsets.size():
		var y: float = offsets[j]
		var l2: float = length * (1.0 if j == 1 else 0.7)
		var p0: Vector2 = (at + Vector2(0.0, y)).round()
		var p1: Vector2 = (at + Vector2(back * l2, y)).round()
		var cols := PackedColorArray([_col(ramp, t * 0.5, al), _col(ramp, 0.5 + t * 0.5, al * 0.5)])
		c.draw_polyline_colors(PackedVector2Array([p0, p1]), cols, (8.0 if glow else (3.0 if j == 1 else 2.0)), false)

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
				c.draw_rect(Rect2(p - Vector2(4, 4), Vector2(8, 8)), _col(ramp, u, al * 0.18, h))
			else:
				var tail: Vector2 = (p - Vector2(q["v"]) * 0.07).round()
				c.draw_line(p, tail, _col(ramp, u, al, h), 3.0 if life_ratio > 0.5 else 2.0)
		"shard":
			# Tumbling coloured crystal chip: a rotating diamond whose hue drifts as it flies.
			var spin: float = _clock * 14.0 + h * TAU
			var len_a: float = float(size) * 2.4
			var len_b: float = float(size) * 1.0
			var ax: Vector2 = Vector2.from_angle(spin) * len_a
			var bx: Vector2 = Vector2.from_angle(spin + PI * 0.5) * len_b
			var pts := PackedVector2Array([p + ax, p + bx, p - ax, p - bx])
			if glow:
				c.draw_rect(Rect2(p - Vector2(4, 4), Vector2(8, 8)), _col(ramp, u, al * 0.16, h))
			else:
				c.draw_colored_polygon(pts, _col(ramp, u * 0.8, al, h))
				c.draw_rect(Rect2(p, Vector2.ONE), Color(1, 1, 1, al))
		"twinkle":
			var arm: float = roundf(float(size) * (0.8 + life_ratio * 1.8))
			if glow:
				c.draw_rect(Rect2(p - Vector2(arm, arm), Vector2(arm, arm) * 2.0), _col(ramp, u, al * 0.16, h))
			else:
				var col: Color = _col(ramp, u * 0.8, al, h)
				c.draw_line(p + Vector2(-arm, 0), p + Vector2(arm, 0), col, 1.0)
				c.draw_line(p + Vector2(0, -arm), p + Vector2(0, arm), col, 1.0)
				c.draw_rect(Rect2(p, Vector2(2, 2)), Color(1, 1, 1, al))
		_:
			if glow and size >= 2:
				c.draw_rect(Rect2(p - Vector2(2, 2), Vector2.ONE * float(size + 4)), _col(ramp, u, al * 0.12, h))
			elif not glow:
				c.draw_rect(Rect2(p, Vector2.ONE * float(size)), _col(ramp, u, al * (0.55 if size == 1 else 1.0), h))

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

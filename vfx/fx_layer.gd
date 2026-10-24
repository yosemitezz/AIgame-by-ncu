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

const GhostOutline = preload("res://presentation/ghost_outline.gdshader")
const GhostShadow = preload("res://presentation/ghost_shadow.gdshader")
const HeroSmear = preload("res://vfx/hero_smear.gd")
const Level = preload("res://levels/bellkeep.gd")

const SIZE_BOOST: float = 1.75   # ring / ray / star / arc radii are this much larger than the first version
const SPEED_BOOST: float = 1.4
const MAX_PARTS: int = 800
const MAX_SHAPES: int = 64
const MAX_WARNINGS: int = 24
const MAX_GHOSTS: int = 28
const MAX_TRAIL_POINTS: int = 14
const TRAIL_LIFE: float = 0.14
const SLASH_TAIL_LIFE: float = 0.10
const MAX_OWNER_GHOSTS: int = 8
const GHOST_INTERVAL: float = 0.032
const GHOST_MIN_DISTANCE: float = 5.0
const SWEEP_STEPS: int = 12
const SAFE_DECOR: Array[String] = ["pickup", "checkpoint", "burst", "boss_defeat"]

const RAMP_SOURCE: Dictionary = {
	"cool": ["ffffff", "c4fff6", "72ece2", "5aa4ff", "a278ff", "ff7ad0"],
	"warm": ["ffffff", "fff1bd", "e9bb68", "ff9a5a", "ef7678", "b04aa8"],
	"hurt": ["ffffff", "ffc0b8", "ef7678", "c0405f", "5a1d4a"],
	"dust": ["f2f6d6", "b8c4cf", "77839c", "394462"],
	"gold": ["ffffff", "fff1bd", "e9bb68", "88704e"],
	# Two house palettes: icy blade light and furnace ember. They replace the old hue-cycling rainbow.
	"blade": ["ffffff", "d6f6ff", "7fd6ff", "4f86e8", "6a48c8", "2c1a62"],
	"ember": ["ffffff", "ffe9a8", "ffb050", "ee5a38", "a02040", "40102e"],
	"reflected_tail": ["c4fff6", "73f6df", "43b9aa", "335f79"],
	"lantern_fan": ["fff1bd", "f4b95f", "bc7545", "67444b"],
	"bat_seed": ["eedbff", "c69aff", "8e65b7", "514267"],
	"bat_bloom": ["fff0ff", "e59bff", "a46ab8", "60416f"],
	"jailer_link": ["f3ffcf", "cce675", "95a94d", "4d6148"],
}

class Ghost extends Node2D:
	const PA = preload("res://assets/art/pixel_actor.gd")
	var kind: String = "hero"
	var state: String = "idle"
	var frame_index: int = 0
	var face: int = 1
	var combo: int = 1
	var parry_phase: String = "none"
	var parry_progress: float = 0.0
	var reaction_state: String = "none"
	var reaction_progress: float = 0.0
	var impact_flash: float = 0.0
	var source_id: int = 0
	var airborne: bool = false
	var weapon: String = "light"
	var boss_pose_snapshot: Dictionary = {}

	func is_on_floor() -> bool:
		return not airborne

	func get_parry_progress() -> float:
		return parry_progress
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
		# Native pixel cells never inflate while fading.
		scale = Vector2.ONE
		return life <= 0.0

var game: Node = null
## The pixel-frame layer (presentation/combat_vfx.gd) owns telegraph drawing because it knows the attack
## type (rain, armored, unblockable). Turn this on only when running this layer standalone.
var draw_warnings: bool = false
var _spawn_event: String = ""
var _safe_seen: bool = false
var _attack_profile: Script = null
var _ghost_material: ShaderMaterial
var _shadow_material: ShaderMaterial
var _smear: Node2D = null
var _ghost_samples: Dictionary = {}
var _trail_canvas: Node2D
var _katana_visual: Script = preload("res://presentation/katana_visual.gd")
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
## Per-attack variety: every swing re-rolls a hue and a "personality", never repeating the last one,
## and the hit that follows reuses the swing's hue so slash + impact read as one colourful blow.
var _hue_shift: float = 0.0
var _draw_hue: float = 0.0
var _last_hue: float = 0.0
var _last_slash_kind: int = -1
var _last_hit_kind: int = -1
var style_kind: int = 0
var _last_deflect_clock: float = -10.0
var _last_deflect_at: Vector2 = Vector2.INF
var _run_clock: float = 0.0
var _run_ghost_clock: float = 0.0
var _mote_clock: float = 0.0
var _shard_clock: float = 0.0
var _rng := RandomNumberGenerator.new()
var _glow: Node2D = null
var _add_material: CanvasItemMaterial = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
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
	_ghost_material = ShaderMaterial.new()
	_ghost_material.shader = GhostOutline
	_shadow_material = ShaderMaterial.new()
	_shadow_material.shader = GhostShadow
	_smear = HeroSmear.new()
	add_child(_smear)
	_trail_canvas = Node2D.new()
	_trail_canvas.z_as_relative = false
	_trail_canvas.z_index = 1
	add_child(_trail_canvas)
	_trail_canvas.draw.connect(func() -> void: _draw_body_trail(_trail_canvas, false))
	_glow = Node2D.new()
	_glow.material = _add_material
	_glow.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_glow)
	_glow.draw.connect(func() -> void: _paint(_glow, true))

func setup(p_game: Node) -> void:
	if is_instance_valid(game) and game != p_game:
		if game.vfx_requested.is_connected(spawn):
			game.vfx_requested.disconnect(spawn)
		if game.warning_issued.is_connected(_on_warning):
			game.warning_issued.disconnect(_on_warning)
	game = p_game
	if not game.vfx_requested.is_connected(spawn):
		game.vfx_requested.connect(spawn)
	if not game.warning_issued.is_connected(_on_warning):
		game.warning_issued.connect(_on_warning)

func counts() -> Dictionary:
	return {"effects": _shapes.size(), "chips": _parts.size(), "ghosts": _ghosts.size(),
		"warnings": _warns.size(), "trails": _body_trail.size() + _proj_trails.size()}

func _safe() -> bool:
	return is_instance_valid(game) and bool(game.get("story_safe"))

func _suspended() -> bool:
	if _safe() or get_tree().paused:
		return true
	if not is_instance_valid(game):
		return false
	var overlay: Variant = game.get("_overlay")
	return bool(game.get("_paused")) or (overlay != null and String(overlay) != "")

func _notification(what: int) -> void:
	if what == NOTIFICATION_PAUSED:
		clear_motion_decor()

func _speed_level() -> int:
	if not is_instance_valid(game):
		return 1
	var impact: Variant = game.get("impact")
	if impact != null and is_instance_valid(impact) and bool(impact.get("reduced_motion")):
		return 0
	var value: Variant = game.get("speed_effects_level")
	return clampi(int(value), 0, 2) if value != null else 1

func clear_motion_decor() -> void:
	if is_instance_valid(_smear):
		_smear.clear()
	# Pause suspends combat rather than cancelling it: retain primary shapes and warnings.
	_body_trail.clear()
	_proj_trails.clear()
	for ghost: Ghost in _ghosts:
		ghost.hide()
		ghost.queue_free()
	_ghosts.clear()
	_ghost_samples.clear()
	for index: int in range(_parts.size() - 1, -1, -1):
		if String(_parts[index].get("event", "")) in ["", "dash", "dash_start", "dash_ghost", "enemy_dash", "jump", "air_jump", "land", "water_splash"]:
			_parts.remove_at(index)
	_ghost_clock = 0.0
	_boss_ghost_clock = 0.0
	_run_clock = 0.0
	_run_ghost_clock = 0.0
	_mote_clock = 0.0
	_shard_clock = 0.0
	queue_redraw()
	if is_instance_valid(_trail_canvas):
		_trail_canvas.queue_redraw()
	if is_instance_valid(_glow):
		_glow.queue_redraw()

func clear_hostile() -> void:
	# Keep an already-issued victory/checkpoint celebration, never an old attack or ambient trail.
	for i: int in range(_parts.size() - 1, -1, -1):
		if String(_parts[i].get("event", "")) not in SAFE_DECOR:
			_parts.remove_at(i)
	for i: int in range(_shapes.size() - 1, -1, -1):
		if String(_shapes[i].get("event", "")) not in SAFE_DECOR:
			_shapes.remove_at(i)
	_warns.clear()
	_body_trail.clear()
	_proj_trails.clear()
	for ghost: Ghost in _ghosts:
		ghost.hide()
		ghost.queue_free()
	_ghosts.clear()
	_ghost_samples.clear()
	_ghost_clock = 0.0
	_boss_ghost_clock = 0.0
	_run_clock = 0.0
	_run_ghost_clock = 0.0
	_mote_clock = 0.0
	_shard_clock = 0.0
	_safe_seen = _safe()
	queue_redraw()
	if is_instance_valid(_trail_canvas):
		_trail_canvas.queue_redraw()
	if is_instance_valid(_glow):
		_glow.queue_redraw()

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
	if ramp == "rainbow" or ramp == "flow":
		# Furnace ember or icy blade, never a full spectrum. Hue only drifts a little per swing.
		var stops_hot: PackedColorArray = _ramps["ember" if ramp == "rainbow" else "blade"]
		var fh: float = u * float(stops_hot.size() - 1)
		var ih: int = mini(int(fh), stops_hot.size() - 2)
		c = stops_hot[ih].lerp(stops_hot[ih + 1], fh - float(ih))
		var drift: float = (fposmod(h + _draw_hue, 1.0) - 0.5) * 0.08
		c = Color.from_hsv(fposmod(c.h + drift, 1.0), c.s, c.v)
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
	_parts.append({"p": at, "v": vel, "life": life, "max": life, "event": _spawn_event, "ramp": ramp, "size": size, "kind": kind, "grav": grav, "drag": drag, "h": fposmod(_hue_shift + _rng.randf() * 0.32, 1.0)})

func _shape(type: String, at: Vector2, life: float, ramp: String, extra: Dictionary = {}) -> void:
	if _shapes.size() >= MAX_SHAPES:
		_shapes.remove_at(0)
	var s: Dictionary = {"type": type, "at": at, "life": life, "max": life, "event": _spawn_event, "ramp": ramp, "sh": _hue_shift, "seed": _rng.randf() * 100.0}
	for key: String in extra:
		var v: Variant = extra[key]
		if key in ["r", "r0", "r1", "h", "w0", "len"]:
			v = float(v) * SIZE_BOOST
		elif key == "w":
			v = float(v) * 1.5
		s[key] = v
	if _spawn_event == "slash":
		var actor: Node2D = _player()
		if actor != null and str(actor.get("attack_phase")) == "active":
			s["actor_ref"] = weakref(actor)
			s["serial"] = int(actor.get("attack_serial"))
			s["rel"] = at - actor.global_position
			s["phase_bound"] = true
			s["visual_t"] = 0.0
			s["spark_step"] = 0
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
	if not is_instance_valid(source) or _safe():
		return
	var id: int = source.get_instance_id()
	var previous: Dictionary = _ghost_samples.get(id, {})
	if not previous.is_empty() and (_clock - float(previous["time"]) < GHOST_INTERVAL or source.global_position.distance_to(Vector2(previous["at"])) < GHOST_MIN_DISTANCE):
		return
	_ghost_samples[id] = {"time": _clock, "at": source.global_position}
	var owned: int = 0
	for ghost: Ghost in _ghosts:
		if ghost.source_id == id:
			owned += 1
	if owned >= MAX_OWNER_GHOSTS:
		for index: int in _ghosts.size():
			if _ghosts[index].source_id == id:
				_ghosts[index].hide()
				_ghosts[index].queue_free()
				_ghosts.remove_at(index)
				break
	if _ghosts.size() >= MAX_GHOSTS:
		var oldest: Ghost = _ghosts.pop_front()
		oldest.hide()
		oldest.queue_free()
	var g := Ghost.new()
	g.kind = kind
	g.state = String(source.get("animation_state"))
	var held: Variant = source.get("weapon")
	g.weapon = String(held) if held != null else "light"
	g.frame_index = int(source.get("frame"))
	g.face = int(source.get("facing"))
	var cmb: Variant = source.get("combo")
	g.combo = clampi(int(cmb), 1, 3) if cmb != null else 1
	# Scalars only: a snapshot must not consult the moving actor during its later draw passes.
	var phase: Variant = source.get("parry_phase")
	g.parry_phase = String(phase) if phase != null else "none"
	if source.has_method("get_parry_progress"):
		g.parry_progress = float(source.call("get_parry_progress"))
	var reaction: Variant = source.get("reaction_state")
	g.reaction_state = String(reaction) if reaction != null else "none"
	var progress: Variant = source.get("reaction_progress")
	g.reaction_progress = float(progress) if progress != null else 0.0
	# Clash/break poses stay readable; a live hurt flash must not repaint an old ghost.
	g.impact_flash = 0.0
	g.life = minf(life, 0.16 if kind == "boss" else 0.3)
	g.max_life = g.life
	g.source_id = id
	g.airborne = source.has_method("is_on_floor") and not bool(source.call("is_on_floor"))
	if kind == "boss" and _katana_visual != null:
		var snapshot: Variant = _katana_visual.call("describe", source, g.state, g.frame_index)
		if snapshot is Dictionary:
			g.boss_pose_snapshot = snapshot.duplicate(true)
	g.tint = tint
	g.base_alpha = minf(alpha, 0.38 if kind == "boss" else 0.62)
	if kind == "hero":
		# The hero leaves a near-black silhouette with a faint violet rim that follows and fades.
		g.tint = Color.WHITE
		g.base_alpha = clampf(alpha * 0.9, 0.3, 0.62)
		g.material = _shadow_material
	else:
		g.material = _ghost_material
	g.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	g.z_as_relative = false
	g.z_index = 1
	g.scale = Vector2.ONE
	g.position = source.global_position.round()
	add_child(g)
	_ghosts.append(g)

func spawn(kind: String, at: Vector2, dir: Vector2, power: float) -> void:
	if _suspended() and kind not in SAFE_DECOR:
		return
	_spawn_event = kind
	_spawn_impl(kind, at, dir, power)
	_spawn_event = ""

func _spawn_impl(kind: String, at: Vector2, dir: Vector2, power: float) -> void:
	var d: float = 1.0 if dir.x >= 0.0 else -1.0
	# Event names from the combat-feel branch map onto this layer.
	match kind:
		"blade_parry", "projectile_parry", "guard_break":
			# Same clash, scaled: reflected shots small, blade-on-blade full, guard break biggest.
			var scale_p: float = 0.7 if kind == "projectile_parry" else (1.0 if kind == "blade_parry" else 1.7)
			_deflect(at, dir, scale_p, kind == "guard_break")
			return
		"parry":
			_deflect(at, dir, power, false)
			return
		"dash_ghost":
			kind = "dash"
		"dash_start":
			_shape("ring", at, 0.22, "flow", {"r0": 2.0, "r1": 14.0, "w": 2.0, "ry": 0.6})
			_sparks(at, Vector2(-d, 0.0), 6, "flow", 120.0, 0.35, "streak", 0.6)
			return
		"enemy_dash":
			_shape("bars", at, 0.34, "warm", {"d": d, "len": 30.0})
			_sparks(at, Vector2(-d, 0.0), 4, "warm", 90.0, 0.35, "streak", 0.6)
			return
		"lunge":
			# The forward step of a ground strike: dust kicked up at the heels, speed lines trailing
			# behind, and a tinted afterimage left where the hero started, in this swing's hue.
			var lc: float = clampf(power, 1.0, 3.0)
			_shape("bars", at + Vector2(0.0, -12.0), 0.26 + 0.04 * lc, "flow", {"d": d, "len": 22.0 + 8.0 * lc})
			_shape("ring", at, 0.22, "dust", {"r0": 2.0, "r1": 12.0 + 3.0 * lc, "w": 2.0, "ry": 0.3})
			_sparks(at + Vector2(-d * 4.0, 0.0), Vector2(-d, -0.35), 8 + 3 * int(lc), "dust", 150.0, 0.4, "dot", 0.5)
			_sparks(at + Vector2(-d * 6.0, -12.0), Vector2(-d, 0.0), 6 + 2 * int(lc), "flow", 200.0, 0.4, "streak", 0.45)
			var lp: Node2D = _player()
			if lp != null:
				_ghost(lp, "hero", Color.WHITE, 0.6, 0.3)
			return
		"unblockable_charge", "charge":
			kind = "telegraph"
		"impact":
			kind = "hit"
		"debris":
			kind = "spark"
	match kind:
		"slash":
			var combo: int = clampi(int(roundf(power)), 1, 3)
			_roll_style()
			var actor: Node2D = _player()
			if actor != null and str(actor.get("attack_phase")) == "active" and _ensure_profile():
				_profile_slash(actor, combo)
				return
			var c3: float = float(combo)
			var tip: Vector2 = at + Vector2(d * 18.0, 0.0)
			# Six swing personalities. Each re-rolls hue, and never repeats the previous swing's pick.
			match style_kind:
				0:   # Wide flowing crescent: the signature cut.
					_shape("arc", at, 0.38 + 0.06 * c3, "flow", {"d": d, "r": 30.0 + 8.0 * c3, "w": 4.0 + c3 * 1.5, "flip": combo == 2, "half": 1.5 if combo < 3 else 2.2, "sweep": true})
					_shape("arc", at, 0.32 + 0.05 * c3, "rainbow", {"d": d, "r": 23.0 + 6.0 * c3, "w": 3.0, "flip": combo == 2, "half": 1.3 if combo < 3 else 1.9})
					_shape("arc", at, 0.26 + 0.05 * c3, "cool", {"d": d, "r": 15.0 + 4.0 * c3, "w": 2.0, "flip": combo == 2, "half": 1.1 if combo < 3 else 1.6})
					_sparks(tip, Vector2(d, 0.0), 14 + combo * 6, "flow", 220.0, 0.6)
					_shape("ring", tip, 0.3, "cool", {"r0": 3.0, "r1": 22.0 + 6.0 * c3, "w": 3.0, "ry": 1.0, "sides": 4, "twist": 1.4})
				1:   # Double slash: two thin crossing arcs, one up one down.
					_shape("arc", at, 0.34, "rainbow", {"d": d, "r": 34.0 + 6.0 * c3, "w": 3.0, "flip": false, "half": 1.4, "sweep": true})
					_shape("arc", at, 0.34, "flow", {"d": d, "r": 30.0 + 6.0 * c3, "w": 3.0, "flip": true, "half": 1.4, "sweep": true, "facets": 5})
					_shape("crystal", tip, 0.34, "cool", {"r": 16.0 + 4.0 * c3, "rot": _rng.randf() * TAU, "spin": 0.8})
					_sparks(tip, Vector2(d, 0.0), 16 + combo * 5, "rainbow", 240.0, 0.6, "streak", 1.0)
				2:   # Thrust: a long needle of streaks and a star at the tip.
					_shape("streaks", at + Vector2(d * 6.0, 0.0), 0.34, "rainbow", {"d": d, "len": 70.0 + 14.0 * c3, "n": 3 + combo})
					_shape("streaks", at + Vector2(d * 6.0, 0.0), 0.28, "flow", {"d": d, "len": 52.0 + 10.0 * c3, "n": 3})
					_shape("hexagram", at + Vector2(d * (36.0 + 6.0 * c3), 0.0), 0.34, "flow", {"r": 13.0 + 3.0 * c3, "spin": 2.4})
					_shape("ring", at + Vector2(d * (36.0 + 6.0 * c3), 0.0), 0.3, "rainbow", {"r0": 3.0, "r1": 20.0 + 4.0 * c3, "w": 3.0, "ry": 1.0})
					_sparks(at + Vector2(d * 34.0, 0.0), Vector2(d, 0.0), 20 + combo * 6, "flow", 300.0, 0.55, "streak", 0.5)
				3:   # Spin: big full ring of petals around the hero.
					_shape("arc", at, 0.42, "rainbow", {"d": d, "r": 34.0 + 6.0 * c3, "w": 5.0, "flip": false, "half": 2.6, "sweep": true})
					_shape("ring", at, 0.4, "flow", {"r0": 8.0, "r1": 46.0 + 8.0 * c3, "w": 4.0, "ry": 0.85})
					_shape("ring", at, 0.42, "rainbow", {"r0": 6.0, "r1": 40.0 + 7.0 * c3, "w": 3.0, "ry": 0.85, "sides": 4, "twist": -1.6})
					_shape("hexagram", at, 0.46, "flow", {"r": 34.0 + 7.0 * c3, "spin": 3.0})
					_shape("hexagram", at, 0.38, "rainbow", {"r": 22.0 + 5.0 * c3, "spin": -3.6, "rot": 0.5})
					_shape("rays", at, 0.4, "rainbow", {"n": 12 + combo * 2, "r1": 38.0 + 8.0 * c3, "rot": 1.8})
					_sparks(at, Vector2.ZERO, 22 + combo * 6, "flow", 200.0, 0.6, "twinkle", PI)
				4:   # Shatter: the cut bursts into tumbling colour shards.
					_shape("arc", at, 0.3 + 0.05 * c3, "flow", {"d": d, "r": 28.0 + 8.0 * c3, "w": 4.0, "flip": combo == 2, "half": 1.4, "sweep": true, "facets": 5})
					_shape("ring", tip, 0.3, "cool", {"r0": 3.0, "r1": 24.0 + 4.0 * c3, "w": 3.0, "ry": 1.0})
					_sparks(tip, Vector2(d, -0.2), 18 + combo * 6, "rainbow", 280.0, 0.9, "shard", 1.2)
					_sparks(tip, Vector2(d, 0.2), 10 + combo * 4, "flow", 200.0, 0.7, "shard", 1.4)
					_shape("flash", tip, 0.1, "cool", {"r": 18.0 + 4.0 * c3})
					_shape("crystal", tip, 0.38, "rainbow", {"r": 20.0 + 5.0 * c3, "rot": _rng.randf() * TAU, "spin": 0.6})
				_:   # Comet: one fat arc dragging a long tail of fast streaks.
					_shape("arc", at, 0.45, "flow", {"d": d, "r": 36.0 + 8.0 * c3, "w": 7.0, "flip": combo != 2, "half": 1.7, "sweep": true})
					_shape("streaks", at, 0.4, "rainbow", {"d": d, "len": 56.0, "n": 5, "both": true})
					_sparks(tip, Vector2(d, 0.0), 24 + combo * 6, "rainbow", 260.0, 0.7, "streak", 0.9)
					_shape("ring", tip, 0.34, "flow", {"r0": 3.0, "r1": 26.0 + 5.0 * c3, "w": 3.0, "ry": 1.0, "sides": 4, "twist": 0.9})
			_shape("hexagram" if combo >= 2 else "crystal", at + Vector2(d * 24.0, 0.0), 0.3, "flow", {"r": 10.0 + 4.0 * c3, "spin": 2.0 * d, "rot": _rng.randf() * TAU})
			# Every swing also throws a few rising twinkles, so the air keeps glittering after it.
			_sparks(tip, Vector2.UP, 5 + combo * 2, "rainbow", 90.0, 0.9, "twinkle", 1.4)
			if combo == 3:
				_shape("hexagram", at + Vector2(d * 12.0, 0.0), 0.55, "rainbow", {"r": 44.0, "spin": 2.6 * d})
				_shape("ring", at + Vector2(d * 12.0, 0.0), 0.5, "flow", {"r0": 6.0, "r1": 52.0, "w": 5.0, "ry": 0.75})
				_shape("ring", at + Vector2(d * 12.0, 0.0), 0.4, "rainbow", {"r0": 4.0, "r1": 36.0, "w": 3.0, "ry": 0.75, "sides": 4, "twist": 1.3})
				_sparks(at + Vector2(d * 22.0, 0.0), Vector2(d, 0.0), 26, "rainbow", 300.0, 0.9, "twinkle", 1.3)
		"enemy_slash":
			_shape("arc", at, 0.28, "warm", {"d": d, "r": 18.0 + 8.0 * power, "w": 3.0, "flip": false, "half": 1.3})
			_sparks(at + Vector2(d * 14.0, 0.0), Vector2(d, 0.0), 8, "warm", 130.0, 0.4)
		"parry_ready":
			_shape("ring", at, 0.2, "cool", {"r0": 16.0, "r1": 5.0, "w": 2.0, "ry": 1.0})
		"weapon_swap":
			# Drawing a new sword: a flash on the hilt and a ring in that sword's colour.
			var swap_ramp: String = ["blade", "ember", "gold"][clampi(roundi(power) - 1, 0, 2)]
			_shape("flash", at, 0.1, swap_ramp, {"r": 16.0})
			_shape("ring", at, 0.3, swap_ramp, {"r0": 3.0, "r1": 22.0, "w": 2.0, "ry": 0.8, "sides": 4, "twist": 0.8})
			_sparks(at, Vector2.UP, 10, swap_ramp, 120.0, 0.5, "twinkle", 1.2)
		"hit":
			# White-hot core, two crossed cuts along the blow, a thin shock ring and ember sparks. A fourth of
			# the finishes changes (never the same twice in a row) so a long fight does not look stamped.
			var hv: float = clampf(power, 0.6, 2.0)
			var ncount: int = int(hv * 12.0)
			var base_angle: float = dir.angle() if dir.length() > 0.01 else (0.0 if d > 0.0 else PI)
			_shape("flash", at, 0.09, "warm", {"r": 20.0 + 8.0 * power})
			_shape("slash_mark", at, 0.2, "warm", {"ang": base_angle + 0.55, "len": 40.0 * hv})
			_shape("slash_mark", at, 0.22, "blade", {"ang": base_angle - 0.45, "len": 34.0 * hv})
			_shape("ring", at, 0.16, "warm", {"r0": 2.0, "r1": 14.0 + 4.0 * power, "w": 2.0, "ry": 1.0})
			_sparks(at, dir, 18 + ncount, "warm", 300.0, 0.55, "streak", 0.55)
			_sparks(at, dir, 8 + ncount / 2, "ember", 200.0, 0.8, "shard", 1.3)
			_sparks(at, dir, 6, "gold", 120.0, 0.7, "deb", 1.6)
			_smear.pulse(dir, power)
			var hk: int = _pick_variant(_last_hit_kind, 4)
			_last_hit_kind = hk
			match hk:
				0:   # Star burst
					_shape("rays", at, 0.3, "ember", {"n": 12, "r1": 30.0 + 8.0 * power, "rot": 0.0})
					_shape("star", at, 0.22, "warm", {"r": 12.0 + 4.0 * power})
				1:   # Shock ring
					_shape("ring", at, 0.3, "ember", {"r0": 2.0, "r1": 30.0 + 8.0 * power, "w": 3.0, "ry": 1.0})
					_shape("ring", at, 0.26, "blade", {"r0": 2.0, "r1": 22.0 + 5.0 * power, "w": 2.0, "ry": 1.0, "sides": 4, "twist": 1.0})
				2:   # Rising embers
					_sparks(at, Vector2.UP, 14 + ncount, "ember", 200.0, 0.9, "twinkle", 0.8)
					_shape("crystal", at, 0.32, "blade", {"r": 18.0 + 5.0 * power, "rot": _rng.randf() * TAU, "spin": 0.5})
				_:   # Cross cut
					_shape("slash_mark", at, 0.26, "warm", {"ang": base_angle + PI * 0.5 + 0.2, "len": 30.0 * hv})
					_shape("slash_mark", at, 0.26, "ember", {"ang": base_angle - PI * 0.5 + 0.2, "len": 30.0 * hv})
					_shape("ring", at, 0.24, "warm", {"r0": 3.0, "r1": 24.0 + 6.0 * power, "w": 2.0, "ry": 1.0, "sides": 4, "twist": -1.2})
		"hurt":
			_shape("ring", at, 0.36, "hurt", {"r0": 3.0, "r1": 26.0, "w": 4.0, "ry": 1.0})
			_shape("crystal", at, 0.3, "hurt", {"r": 18.0, "rot": _rng.randf() * TAU, "spin": 0.5})
			_sparks(at, dir, 16, "hurt", 200.0, 0.55, "streak", 1.6)
		"dash":
			var hostile: bool = false # enemy_dash is explicit; proximity never changes hero effect ownership.
			_shape("bars", at, 0.4, "warm" if hostile else "flow", {"d": 1.0 if dir.x >= 0.0 else -1.0, "len": 26.0 * clampf(power, 0.5, 1.5)})
			_sparks(at, dir, 3, "warm" if hostile else "flow", 60.0, 0.4, "twinkle", 1.0)
		"jump":
			_shape("ring", at, 0.28, "dust", {"r0": 2.0, "r1": 13.0, "w": 2.0, "ry": 0.3})
			_sparks(at, Vector2.ZERO, 6, "dust", 50.0, 0.35, "dot", 0.5)
		"air_jump":
			_shape("hexagram", at, 0.42, "flow", {"r": 22.0, "spin": 2.4})
			_shape("ring", at, 0.4, "flow", {"r0": 3.0, "r1": 24.0, "w": 3.0, "ry": 0.35})
			_shape("ring", at, 0.3, "rainbow", {"r0": 2.0, "r1": 14.0, "w": 2.0, "ry": 0.35})
			_sparks(at, Vector2(0.0, 1.0), 7, "flow", 70.0, 0.45, "twinkle", 1.3)
			var pl2: Node2D = _player()
			if pl2 != null:
				_ghost(pl2, "hero", Color.WHITE, 0.6, 0.3)
		"stun":
			_shape("hexagram", at, 0.7, "cool", {"r": 16.0, "spin": 3.0})
			_shape("crystal", at, 0.55, "gold", {"r": 14.0, "rot": 0.3, "spin": -1.2})
			_sparks(at, Vector2.UP, 8, "gold", 90.0, 0.6, "shard", 1.6)
		"launch":
			_shape("crystal", at, 0.45, "cool", {"r": 26.0, "rot": 0.0, "spin": 0.6})
			_shape("bars", at + Vector2(0.0, -4.0), 0.3, "warm", {"d": d, "len": 24.0})
			_sparks(at, dir, 14, "cool", 220.0, 0.5, "shard", 0.8)
		"land":
			_shape("ring", at, 0.3, "dust", {"r0": 3.0, "r1": 20.0, "w": 2.0, "ry": 0.28})
			_sparks(at + Vector2(0.0, -1.0), Vector2(0.0, -1.0), 7, "dust", 70.0, 0.35, "dot", 1.4)
			_sparks(at + Vector2(0.0, -1.0), Vector2(0.0, -1.0), 6, "cool", 120.0, 0.45, "shard", 1.5)
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

func _pick_variant(last: int, count: int) -> int:
	var pick: int = _rng.randi_range(0, count - 1)
	if pick == last:
		pick = (pick + 1 + _rng.randi_range(0, count - 2)) % count
	return pick

func _roll_style() -> void:
	## A new swing: pick a personality different from the last swing, and a hue at least 0.2 away.
	style_kind = _pick_variant(_last_slash_kind, 6)
	_last_slash_kind = style_kind
	var h: float = _rng.randf()
	var tries: int = 0
	while absf(fposmod(h - _last_hue + 0.5, 1.0) - 0.5) < 0.2 and tries < 6:
		h = _rng.randf()
		tries += 1
	_last_hue = h
	_hue_shift = h

func _recent_deflect(at: Vector2) -> bool:
	var now: float = _clock
	if now - _last_deflect_clock < 0.05 and at.distance_to(_last_deflect_at) < 24.0:
		return true
	_last_deflect_clock = now
	_last_deflect_at = at
	return false

func _deflect(at: Vector2, dir: Vector2, power: float, guard_break: bool) -> void:
	## Sekiro-style deflect: one instant white-hot flash and glint cross, then a fan of fast sparks thrown
	## along the clash line, hard shock rings and long two-way streaks. Colour only blooms afterwards, so
	## the first frames read as steel on steel. power scales the whole thing.
	var d: float = 1.0 if dir.x >= 0.0 else -1.0
	var k: float = clampf(power, 0.5, 2.0)
	var n_fan: int = int(30.0 * minf(k, 1.4))
	_shape("flash", at, 0.033, "cool", {"r": minf(12.0 * k, 18.0) / SIZE_BOOST, "contact_core": true})
	_shape("cross", at, 0.2, "cool", {"r": 30.0 * k, "d": d})
	_shape("streaks", at, 0.34, "flow", {"d": d, "len": 46.0 * k, "n": 5, "both": true})
	_shape("ring", at, 0.28, "cool", {"r0": 3.0, "r1": 40.0 * k, "w": 5.0, "ry": 1.0})
	_shape("ring", at, 0.5, "flow", {"r0": 6.0, "r1": 62.0 * k, "w": 4.0, "ry": 1.0})
	_shape("ring", at, 0.42, "rainbow", {"r0": 2.0, "r1": 34.0 * k, "w": 3.0, "ry": 1.0})
	_shape("rays", at, 0.5, "flow", {"n": 18, "r1": 38.0 * k, "rot": 1.2})
	_shape("star", at, 0.3, "cool", {"r": 18.0 * k})
	# Two fans: forward (where the blow came from) and back, like blades scraping apart.
	_sparks(at, Vector2(d, -0.15), n_fan, "warm", 380.0, 0.55, "streak", 0.55)
	_sparks(at, Vector2(-d, -0.25), n_fan / 2, "cool", 300.0, 0.55, "streak", 0.5)
	_sparks(at, Vector2.ZERO, int(22.0 * k), "flow", 260.0, 0.8, "streak", PI)
	_sparks(at, Vector2.ZERO, int(16.0 * k), "rainbow", 150.0, 0.9, "shard", PI)
	_sparks(at, Vector2.ZERO, int(12.0 * k), "rainbow", 100.0, 0.9, "twinkle", PI)
	var pl: Node2D = _player()
	if pl != null and k >= 0.9:
		_ghost(pl, "hero", Color(0.55, 1.0, 0.95), 0.85, 0.45)
		_ghost(pl, "hero", Color(1.0, 0.6, 0.95), 0.5, 0.65)
	if guard_break:
		_shape("ring", at, 0.9, "rainbow", {"r0": 6.0, "r1": 110.0, "w": 5.0, "ry": 0.8})
		_shape("rays", at, 0.8, "rainbow", {"n": 24, "r1": 70.0, "rot": -2.0})
		_sparks(at, Vector2.ZERO, 30, "rainbow", 320.0, 1.0, "shard", PI)

func _on_warning(kind: String, at: Vector2, duration: float) -> void:
	if not draw_warnings or (is_instance_valid(game) and bool(game.get("story_safe"))):
		return
	if _warns.size() >= MAX_WARNINGS:
		_warns.remove_at(0)
	_warns.append({"kind": kind, "at": at, "life": duration, "max": maxf(duration, 0.05)})

# ------------------------------------------------------------------ simulation

func _process(delta: float) -> void:
	# A manual check can call this during tree pause; it must obey the same frozen stage.
	if not _safe() and _suspended():
		clear_motion_decor()
		return
	_clock += delta
	var safe: bool = _safe()
	if safe and not _safe_seen:
		clear_hostile()
	_safe_seen = safe
	if safe:
		_smear.clear()
	else:
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
		if bool(s.get("phase_bound", false)):
			if not _sync_slash(s):
				_shapes.remove_at(i)
			continue
		if s.has("tail_age"):
			s["tail_age"] = float(s["tail_age"]) + delta
			var tail: float = clampf(float(s["tail_age"]) / SLASH_TAIL_LIFE, 0.0, 1.0)
			s["visual_t"] = lerpf(float(s["tail_start"]), 1.0, tail)
			if tail >= 1.0:
				_shapes.remove_at(i)
			continue
		s["life"] = float(s["life"]) - delta
		if s.get("sweep", false):
			_sweep_sparks(s, 1.0 - float(s["life"]) / float(s["max"]))
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
	if is_instance_valid(_trail_canvas):
		_trail_canvas.queue_redraw()
	if _glow != null:
		_glow.queue_redraw()

func _ensure_profile() -> bool:
	if _attack_profile == null and ResourceLoader.exists("res://combat/attack_profile.gd"):
		_attack_profile = load("res://combat/attack_profile.gd")
	return _attack_profile != null

func _profile_call(method: String, arguments: Array = []) -> Variant:
	return _attack_profile.callv(method, arguments)

func _profile_slash(actor: Node2D, combo: int) -> void:
	var info: Dictionary = _profile_call("weapon_info")
	var ramp: String = String(info.get("ramp", "blade"))
	_shape("profile", actor.global_position, 0.12, "flow", {"combo": combo, "style": style_kind, "profile": true, "sample_step": -1, "ramp": ramp})
	_profile_geometry(_shapes.back(), actor)
	var weapon: String = String(actor.get("weapon")) if actor.get("weapon") != null else "light"
	var d: float = -1.0 if int(actor.get("facing")) < 0 else 1.0
	var foot: Vector2 = actor.global_position + Vector2(d * 14.0, -1.0)
	# Weight: heavy blades kick dust off the floor, the greatsword also throws a ground shockwave on the finisher.
	if weapon == "heavy":
		_sparks(foot, Vector2(d, -0.2), 6 + combo * 2, "dust", 110.0, 0.4, "dot", 1.2)
		_sparks(actor.global_position + Vector2(d * 30.0, -22.0), Vector2(d, 0.0), 8 + combo * 3, "ember", 240.0, 0.5, "streak", 0.8)
		if combo == 3:
			_shape("ring", foot, 0.34, "ember", {"r0": 4.0, "r1": 34.0, "w": 3.0, "ry": 0.28})
	elif weapon == "great":
		_sparks(foot, Vector2(d, -0.1), 8 + combo * 3, "dust", 140.0, 0.5, "dot", 1.3)
		_sparks(actor.global_position + Vector2(d * 48.0, -22.0), Vector2(d, 0.0), 10 + combo * 4, "gold", 280.0, 0.55, "streak", 0.7)
		_shape("ring", foot, 0.3 + 0.05 * float(combo), "gold", {"r0": 4.0, "r1": 26.0 + 10.0 * float(combo), "w": 3.0, "ry": 0.26})
		if combo == 3:
			_shape("rays", actor.global_position + Vector2(d * 60.0, -22.0), 0.34, "gold", {"n": 10, "r1": 44.0, "rot": 0.0})

func _profile_geometry(shape: Dictionary, actor: Node2D) -> void:
	var progress: float = float(actor.call("get_attack_progress"))
	if progress < float(_profile_call("contact_start")):
		shape["polygon"] = PackedVector2Array()
		return
	var from_value: Variant = actor.get("attack_sweep_from")
	var to_value: Variant = actor.get("attack_sweep_to")
	var first: float = float(from_value) if from_value != null else progress
	var last: float = float(to_value) if to_value != null else progress
	shape["polygon"] = _profile_call("world_polygon", [actor, first, last])
	var facing: float = -1.0 if int(actor.get("facing")) < 0 else 1.0
	var edge: Vector2 = _profile_call("leading_edge", [int(shape["combo"]), last])
	shape["leading"] = actor.global_position + Vector2(edge.x * facing, edge.y)
	shape["origin"] = actor.global_position + Vector2(Vector2(_profile_call("origin")).x * facing, Vector2(_profile_call("origin")).y)
	# Angular/time progress is the sampling clock. Holding hit-stop emits no repeated fragments.
	var sample: int = clampi(int(progress * 8.0), 0, 8)
	var previous: int = maxi(int(float(_profile_call("contact_start")) * 8.0) - 1, int(shape.get("sample_step", -1)))
	for step: int in range(previous + 1, sample + 1):
		var sample_edge: Vector2 = _profile_call("leading_edge", [int(shape["combo"]), float(step) / 8.0])
		var at: Vector2 = actor.global_position + Vector2(sample_edge.x * facing, sample_edge.y)
		for _i: int in 2:
			_part(at, Vector2(_rng.randf_range(-30, 30), _rng.randf_range(-24, 24)), 0.10, "flow", 2, "streak", 0.0, 1.0)
			if not _parts.is_empty():
				_parts.back()["fade_scale"] = 0.25
	shape["sample_step"] = maxi(previous, sample)

func _draw_profile(c: CanvasItem, shape: Dictionary, glow: bool) -> void:
	var polygon: PackedVector2Array = shape.get("polygon", PackedVector2Array())
	if polygon.size() < 3:
		return
	var active: bool = bool(shape.get("phase_bound", false))
	var fade: float = 1.0 if active else 0.18 * (1.0 - clampf(float(shape.get("tail_age", 0.0)) / SLASH_TAIL_LIFE, 0.0, 1.0))
	var alpha: float = fade * (0.12 if glow else 1.0)
	var edge := PackedVector2Array()
	var colors := PackedColorArray()
	for index: int in range(1, polygon.size()):
		edge.append(polygon[index].round())
		colors.append(_col(String(shape.get("ramp", "flow")), float(index) / polygon.size(), alpha, float(shape.get("style", 0)) * 0.11))
	# The query supplies the exact outer limit; inset triangles keep the primary branch's cut-crystal style.
	if not glow:
		var center: Vector2 = Vector2(shape.get("origin", polygon[0])).round()
		var stride: int = maxi(1, int((polygon.size()-1)/5))
		for index: int in range(1, polygon.size()-1, stride):
			var last: int = mini(polygon.size()-1, index+stride)
			var a: Vector2 = polygon[index].round()
			var b: Vector2 = polygon[last].round()
			var inset: Vector2 = center.lerp((a+b)*0.5, 0.62).round()
			c.draw_colored_polygon(PackedVector2Array([a,b,inset]), _col(String(shape.get("ramp", "flow")), float(index)/polygon.size(), fade*0.25, float(shape.get("style",0))*0.11))
	# The very same queried polygon is the energy's limit; no old circle or long needle outside it.
	if not glow:
		c.draw_colored_polygon(polygon, _col(String(shape.get("ramp", "flow")), 0.5, 0.06 * fade))
	c.draw_polyline_colors(edge, colors, 7.0 if glow else 4.0, false)
	var origin: Vector2 = Vector2(shape.get("origin", polygon[0])).round()
	var leading: Vector2 = Vector2(shape.get("leading", polygon[polygon.size()-1])).round()
	c.draw_line(origin, leading, _col(String(shape.get("ramp", "flow")), 0.35, alpha * 0.75), 8.0 if glow else 5.0, false)
	if not glow:
		c.draw_line(origin, leading, Color(1, 1, 0.94, fade * 0.88), 2.0, false)

func _sync_slash(s: Dictionary) -> bool:
	var actor_ref: WeakRef = s["actor_ref"]
	var actor: Node2D = actor_ref.get_ref() as Node2D
	if not is_instance_valid(actor) or bool(actor.get("dead")):
		return false
	if int(actor.get("attack_serial")) != int(s["serial"]):
		return false
	var phase: String = String(actor.get("attack_phase"))
	# All six slash personalities share one origin, including rings/stars/thrust streaks.
	s["at"] = _arc_at(s)
	if phase == "active":
		# Real phase progress stops during local impact freeze. No real-age crescent can race ahead.
		var progress: float = clampf(float(actor.call("get_attack_progress")), 0.0, 1.0)
		s["visual_t"] = progress * 0.58
		if bool(s.get("profile", false)):
			_profile_geometry(s, actor)
		if s.get("sweep", false):
			_sweep_sparks(s, progress * 0.4)
		return true
	if phase == "recover":
		if s.get("sweep", false):
			_sweep_sparks(s, 0.4)
		s["at"] = _arc_at(s)
		s.erase("rel")
		s.erase("actor_ref")
		s["phase_bound"] = false
		s["tail_age"] = 0.0
		s["tail_start"] = maxf(0.58, float(s.get("visual_t", 0.0)))
		s["visual_t"] = s["tail_start"]
		return true
	# Dash, parry, damage and death cancellations cut the primary stroke immediately.
	return false

func _arc_at(s: Dictionary) -> Vector2:
	var at: Vector2 = s["at"]
	if s.has("rel") and s.has("actor_ref"):
		var actor_ref: WeakRef = s["actor_ref"]
		var actor: Node2D = actor_ref.get_ref() as Node2D
		if is_instance_valid(actor):
			at = actor.global_position + Vector2(s["rel"])
	return at

func _sweep_sparks(s: Dictionary, t: float) -> void:
	# Fixed angular buckets, rather than two particles on every render frame. All frame rates
	# sample the same twelve points; holding the actual attack phase emits nothing more.
	var target: int = clampi(int(minf(t / 0.4, 1.0) * SWEEP_STEPS), 0, SWEEP_STEPS)
	var previous: int = int(s.get("spark_step", 0))
	for step: int in range(previous + 1, target + 1):
		var fraction: float = float(step) / float(SWEEP_STEPS)
		var half: float = s["half"]
		var angle: float = -half + 2.0 * half * fraction
		var ys: float = -1.0 if bool(s["flip"]) else 1.0
		var radius: float = float(s["r"])
		var center: Vector2 = _arc_at(s)
		var tip: Vector2 = center + Vector2(cos(angle) * radius * float(s["d"]), sin(angle) * radius * 0.95 * ys)
		var outward: Vector2 = (tip - center).normalized()
		for _i: int in 2:
			_part(tip, outward * _rng.randf_range(30.0, 110.0) + Vector2(_rng.randf_range(-20.0, 20.0), _rng.randf_range(-20.0, 20.0)), _rng.randf_range(0.25, 0.5), "flow", _rng.randi_range(2, 3), "streak", 40.0, 2.0)
	s["spark_step"] = maxi(previous, target)

func _follow_actors(delta: float) -> void:
	var pl: Node2D = _player()
	var safe: bool = is_instance_valid(game) and bool(game.get("story_safe"))
	# Body ribbon and afterimages follow the hero, so every action leaves a continuous light path.
	if pl != null:
		_smear.follow(pl, delta, _speed_level())
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
		var trail_at: Vector2 = pl.global_position + Vector2(0.0, -14.0)
		if strength > 0.0 and (_body_trail.is_empty() or (trail_at.distance_to(Vector2(_body_trail.back()["p"])) >= 4.0 and _clock - float(_body_trail.back().get("time", 0.0)) >= 0.025)):
			_body_trail.append({"p": trail_at.round(), "age": 0.0, "k": strength, "time": _clock})
		# Running: a flowing scarf of light from the shoulders, dust-and-colour kicks at the heels, and
		# a faint afterimage every few frames so walking reads as a continuous motion path.
		var running: bool = absf(vel.x) > 60.0 and dash_t <= 0.0
		if running:
			var fdir: float = 1.0 if vel.x >= 0.0 else -1.0
			_run_clock -= delta
			if _run_clock <= 0.0:
				_run_clock = 0.05
				if is_on_floor_safe(pl):
					_part(pl.global_position + Vector2(-fdir * 6.0, -1.0), Vector2(-fdir * _rng.randf_range(20.0, 60.0), _rng.randf_range(-40.0, -12.0)), _rng.randf_range(0.2, 0.4), "dust", 2, "dot", 120.0, 2.0)
			_run_ghost_clock -= delta
			if _run_ghost_clock <= 0.0:
				_run_ghost_clock = 0.045
				_ghost(pl, "hero", Color.WHITE, 0.4, 0.26)
		_ghost_clock -= delta
		if dash_t > 0.0 and _ghost_clock <= 0.0:
			_ghost_clock = 0.026
			_ghost(pl, "hero", Color.WHITE, 0.75, 0.36)
		elif atk_t > 0.0 and _ghost_clock <= 0.0:
			_ghost_clock = 0.04
			_ghost(pl, "hero", Color.WHITE, 0.55, 0.3)
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
	while _body_trail.size() > MAX_TRAIL_POINTS:
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
		if not is_instance_valid(node) or node.is_queued_for_deletion() or bool(node.get("_cleared")):
			continue
		var id: int = node.get_instance_id()
		seen[id] = true
		var cached: Dictionary = _proj_trails.get(id, {})
		var trail: Array = cached.get("pts", [])
		trail.append((node as Node2D).global_position)
		while trail.size() > 12:
			trail.pop_front()
		var style: Variant = node.get("style")
		_proj_trails[id] = {"pts": trail, "friendly": bool(node.get("friendly")), "style": str(style) if style != null else "default"}
	for id: Variant in _proj_trails.keys():
		if not seen.has(id):
			_proj_trails.erase(id)

# ------------------------------------------------------------------ drawing

func _draw() -> void:
	_paint(self, false)

func _paint(c: CanvasItem, glow: bool) -> void:
	_draw_projectile_trails(c, glow)
	for s: Dictionary in _shapes:
		var t: float = float(s.get("visual_t", 1.0 - float(s["life"]) / float(s["max"])))
		_draw_hue = float(s.get("sh", 0.0))
		match String(s["type"]):
			"profile": _draw_profile(c, s, glow)
			"arc": _arc(c, s, t, glow)
			"ring": _ring(c, s, t, glow)
			"rays": _rays(c, s, t, glow)
			"star": _star(c, Vector2(s["at"]).round(), float(s["r"]) * (1.0 - t), String(s["ramp"]), t, glow)
			"pillar": _pillar(c, s, t, glow)
			"bars": _bars(c, s, t, glow)
			"flash": _flash(c, s, t, glow)
			"cross": _cross(c, s, t, glow)
			"streaks": _streaks(c, s, t, glow)
			"slash_mark": _slash_mark(c, s, t, glow)
			"hexagram": _hexagram(c, s, t, glow)
			"crystal": _crystal(c, s, t, glow)
	_draw_hue = 0.0
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
		var width: float = maxf(1.0, roundf((2.0 + k * 3.0) * life))
		if width < 1.0:
			continue
		var al: float = life * k * 0.5
		var pa: Vector2 = Vector2(a["p"]).round()
		var pb: Vector2 = Vector2(b["p"]).round()
		if pa.distance_to(pb) > 60.0:
			continue
		c.draw_line(pa, pb, Color(0.02, 0.0, 0.05, al), width, false)

func _trail_ramp(style: String, friendly: bool) -> String:
	if friendly: return "reflected_tail"
	return style if style in ["lantern_fan","bat_seed","bat_bloom","jailer_link"] else "warm"

func _draw_projectile_trails(c: CanvasItem, glow: bool) -> void:
	for id: Variant in _proj_trails:
		var info: Dictionary = _proj_trails[id]
		var pts: Array = info["pts"]
		var n: int = pts.size()
		if n < 2:
			continue
		var friendly: bool = info["friendly"]
		var tail_ramp: String = _trail_ramp(str(info.get("style","default")), friendly)
		var line := PackedVector2Array()
		var cols := PackedColorArray()
		for i: int in n:
			var u: float = float(i) / float(n - 1)   # 1 = head
			line.append(Vector2(pts[i]).round())
			if friendly:
				cols.append(_col(tail_ramp, 1.0 - u, u * (0.12 if glow else 0.72)))
			else:
				# Hostile shots keep a thin, low-alpha warm tail so safe lanes stay readable.
				cols.append(_col(tail_ramp, 0.2 + (1.0 - u) * 0.6, u * (0.06 if glow else 0.34)))
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
	var n: int = int(s.get("facets", 22))   # 22 = smooth round crescent, 5-6 = cut-crystal crescent
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
	var n: int = int(s.get("sides", 32))   # 32 = round shockwave, 6 = hexagon, 4 = square diamond
	var pts := PackedVector2Array()
	var cols := PackedColorArray()
	var twist: float = float(s.get("twist", 0.0)) * t + (PI / 6.0 if n == 6 else (PI / 4.0 if n == 4 else 0.0))
	for i: int in range(n + 1):
		var a: float = TAU * float(i) / float(n) + twist
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

func _hexagram(c: CanvasItem, s: Dictionary, t: float, glow: bool) -> void:
	## Six-pointed star made of two interlocking triangles that spin and shrink while hue slides along the edges.
	var at: Vector2 = Vector2(s["at"]).round()
	var ramp: String = s["ramp"]
	var e: float = minf(t * 3.0, 1.0)
	var grow: float = 1.0 - (1.0 - e) * (1.0 - e)
	var r: float = float(s["r"]) * (0.35 + 0.65 * grow) * (1.0 - 0.25 * t)
	if r < 2.0:
		return
	var rot: float = float(s.get("spin", 1.5)) * t + float(s.get("rot", 0.0))
	var al: float = (1.0 - t * t) * (0.22 if glow else 1.0)
	for tri: int in 2:
		var pts := PackedVector2Array()
		var cols := PackedColorArray()
		for i: int in range(4):
			var a: float = rot + PI * 0.5 + float(tri) * PI / 3.0 + TAU * float(i % 3) / 3.0
			pts.append((at + Vector2(cos(a), sin(a)) * r).round())
			cols.append(_col(ramp, clampf(0.15 + t * 0.5 + float(i % 3) * 0.2 + float(tri) * 0.25, 0.0, 1.0), al))
		c.draw_polyline_colors(pts, cols, (5.0 if glow else (3.0 if t < 0.5 else 2.0)), false)
	if not glow:
		var inner: float = r * 0.5
		var hex := PackedVector2Array()
		for i: int in range(7):
			var a2: float = rot + TAU * float(i) / 6.0
			hex.append((at + Vector2(cos(a2), sin(a2)) * inner).round())
		c.draw_polyline(hex, Color(1.0, 1.0, 1.0, al * 0.8), 1.0, false)

func _crystal(c: CanvasItem, s: Dictionary, t: float, glow: bool) -> void:
	## Ice crystal: faceted kite arms, each with a white spine and a pair of barbs, around a hex core.
	var at: Vector2 = Vector2(s["at"]).round()
	var ramp: String = s["ramp"]
	var grow: float = minf(t * 4.0, 1.0)
	var r: float = float(s["r"]) * (0.3 + 0.7 * grow) * (1.0 - 0.4 * t * t)
	if r < 2.0:
		return
	var rot: float = float(s.get("rot", 0.0)) + float(s.get("spin", 0.4)) * t
	var arms: int = int(s.get("n", 6))
	var al: float = (1.0 - t) * (0.2 if glow else 1.0)
	for i: int in arms:
		var a: float = rot + TAU * float(i) / float(arms)
		var u: Vector2 = Vector2(cos(a), sin(a))
		var v: Vector2 = Vector2(-u.y, u.x)
		var col: Color = _col(ramp, clampf(0.1 + t * 0.4 + float(i) / float(arms) * 0.5, 0.0, 1.0), al)
		if glow:
			c.draw_line(at, (at + u * r).round(), col, 5.0)
			continue
		var kite := PackedVector2Array([at, at + u * r * 0.32 + v * r * 0.13, at + u * r, at + u * r * 0.32 - v * r * 0.13])
		c.draw_colored_polygon(kite, Color(col, col.a * 0.55))
		c.draw_polyline(PackedVector2Array([kite[0], kite[1], kite[2], kite[3], kite[0]]), col, 1.0, false)
		c.draw_line(at, (at + u * r).round(), Color(1.0, 1.0, 1.0, al), 1.0, false)
		var barb_at: Vector2 = at + u * r * 0.62
		c.draw_line(barb_at.round(), (barb_at + (u * 0.5 + v * 0.55) * r * 0.3).round(), col, 1.0, false)
		c.draw_line(barb_at.round(), (barb_at + (u * 0.5 - v * 0.55) * r * 0.3).round(), col, 1.0, false)
	if not glow:
		var core := PackedVector2Array()
		for i: int in range(6):
			var a3: float = rot + TAU * float(i) / 6.0 + PI / 6.0
			core.append(at + Vector2(cos(a3), sin(a3)) * r * 0.16)
		c.draw_colored_polygon(core, Color(1.0, 1.0, 1.0, al))
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
	if bool(s.get("contact_core", false)):
		r = minf(r, 18.0)
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

func _slash_mark(c: CanvasItem, s: Dictionary, t: float, glow: bool) -> void:
	## A diagonal cut line through the contact point: tapered, white at the centre, colour at the ends.
	var at: Vector2 = Vector2(s["at"]).round()
	var dirv: Vector2 = Vector2.from_angle(float(s["ang"]))
	var reach: float = float(s["len"]) * (0.5 + 0.7 * minf(t * 4.0, 1.0)) * 0.5
	var al: float = (1.0 - t) * (1.0 - t) * (0.25 if glow else 1.0)
	var steps: int = 8
	for side: int in 2:
		var sgn: float = 1.0 if side == 0 else -1.0
		var pts := PackedVector2Array()
		var cols := PackedColorArray()
		for i: int in range(steps + 1):
			var f: float = float(i) / float(steps)
			pts.append((at + dirv * sgn * reach * f).round())
			cols.append(Color(1, 1, 1, al).lerp(_col("flow", f, al, 0.0), clampf(f * 1.4, 0.0, 1.0)))
		c.draw_polyline_colors(pts, cols, (6.0 if glow else (3.0 if t < 0.4 else 2.0)), false)

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
	var al: float = minf(1.0, life_ratio * 2.0) * float(q.get("fade_scale", 1.0))
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

extends Node2D
## Hero motion blur: a short row of translucent copies of the real sprite stretched behind the direction of travel.
## It samples nothing from the screen (no screen texture), only repaints the hero's own frame, so it is cheap, pixel
## aligned, and never touches physics. Strength follows speed (dash, lunge, fast fall) and a short pulse on each hit.
const PA = preload("res://assets/art/pixel_actor.gd")
const COPIES: int = 5
const PULSE_TIME: float = 0.14
const START_SPEED: float = 200.0
const FULL_SPEED: float = 420.0

class Copy extends Node2D:
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
	var airborne: bool = false
	var visual_scale: Vector2 = Vector2.ONE
	var weapon: String = "light"
	var pose_key: String = ""
	var boss_pose_snapshot: Dictionary = {}

	func is_on_floor() -> bool:
		return not airborne

	func get_parry_progress() -> float:
		return parry_progress

	func _draw() -> void:
		PA.paint(self, kind, state, frame_index, face)

var strength: float = 0.0
var _pulse: float = 0.0
var _pulse_dir: Vector2 = Vector2.RIGHT
var _copies: Array[Copy] = []

func _ready() -> void:
	name = "HeroSmear"
	z_as_relative = false
	z_index = 2
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	for index: int in COPIES:
		var copy := Copy.new()
		copy.visible = false
		copy.z_as_relative = false
		copy.z_index = 2
		add_child(copy)
		_copies.append(copy)

func visible_copies() -> int:
	var count: int = 0
	for copy: Copy in _copies:
		if copy.visible:
			count += 1
	return count

## Called on a landed hit. `dir` is the swing direction; the smear trails behind it.
func pulse(dir: Vector2, power: float) -> void:
	_pulse = PULSE_TIME * clampf(0.7 + power * 0.3, 0.7, 1.3)
	_pulse_dir = Vector2(-1.0 if dir.x < 0.0 else 1.0, 0.0)

func clear() -> void:
	strength = 0.0
	_pulse = 0.0
	for copy: Copy in _copies:
		copy.visible = false

## level: 0 off, 1 normal, 2 strong (F3 speed effects).
func follow(hero: Node2D, delta: float, level: int) -> void:
	_pulse = maxf(0.0, _pulse - delta)
	if hero == null or level <= 0:
		clear()
		return
	var velocity: Vector2 = Vector2.ZERO
	var raw: Variant = hero.get("velocity")
	if raw is Vector2:
		velocity = raw
	var speed: float = velocity.length()
	var wanted: float = clampf((speed - START_SPEED) / (FULL_SPEED - START_SPEED), 0.0, 1.0)
	var dir: Vector2 = velocity / speed if speed > 1.0 else Vector2(float(hero.get("facing")), 0.0)
	if _pulse > 0.0:
		var pulse_k: float = _pulse / PULSE_TIME * 0.85
		if pulse_k > wanted:
			wanted = pulse_k
			dir = _pulse_dir
	strength = minf(1.0, wanted * (1.3 if level >= 2 else 1.0))
	if strength < 0.05:
		for copy: Copy in _copies:
			copy.visible = false
		return
	var spacing: float = 5.0 + 5.0 * strength
	var phase: Variant = hero.get("parry_phase")
	var key: String = "%s|%s|%s|%s|%s" % [hero.get("animation_state"), hero.get("frame"), hero.get("facing"), hero.get("combo"), hero.get("weapon")]
	var parry_progress: float = float(hero.call("get_parry_progress")) if hero.has_method("get_parry_progress") else 0.0
	var airborne: bool = hero.has_method("is_on_floor") and not bool(hero.call("is_on_floor"))
	var squash: Variant = hero.get("visual_scale")
	for index: int in COPIES:
		var copy: Copy = _copies[index]
		var fade: float = 1.0 - float(index) / float(COPIES)
		copy.visible = true
		copy.position = (hero.global_position - dir * spacing * float(index + 1)).round()
		copy.modulate = Color(0.72, 0.8, 1.0, 0.4 * strength * fade * fade)
		if copy.pose_key == key + "|" + str(snappedf(parry_progress, 0.1)):
			continue
		copy.pose_key = key + "|" + str(snappedf(parry_progress, 0.1))
		var held: Variant = hero.get("weapon")
		copy.weapon = String(held) if held != null else "light"
		copy.state = String(hero.get("animation_state"))
		copy.frame_index = int(hero.get("frame"))
		copy.face = int(hero.get("facing"))
		var combo_value: Variant = hero.get("combo")
		copy.combo = clampi(int(combo_value), 1, 3) if combo_value != null else 1
		copy.parry_phase = String(phase) if phase != null else "none"
		copy.parry_progress = parry_progress
		copy.airborne = airborne
		copy.visual_scale = squash if squash is Vector2 else Vector2.ONE
		copy.queue_redraw()

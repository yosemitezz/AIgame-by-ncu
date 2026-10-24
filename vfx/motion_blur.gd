extends CanvasLayer
## Screen-space impact blur. Presentation only: it reads vfx_requested and actor state and never
## touches physics, damage or timing. Sits below the HUD layer (30) so UI text stays sharp.
##   directional blur  = the swing / hit / dash direction, a smear along the motion
##   radial blur       = zoom-style rush out from the contact point (parry, guard break, hurt)
##   chroma split      = red and blue pulled apart for a few frames after a big contact
## Everything decays in about 0.1 to 0.2 s and the layer hides itself when idle, so it costs nothing
## between blows. F2 (reduced motion) disables it together with the camera shake.

const MAX_BLUR: float = 0.075      # uv units; 0.01 is about 6 native pixels across
const MAX_RADIAL: float = 0.34
const MAX_CHROMA: float = 0.034
const DECAY: float = 9.0

const SHADER_CODE: String = """
shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear, repeat_disable;
uniform vec2 blur_vec = vec2(0.0);
uniform float radial = 0.0;
uniform vec2 center = vec2(0.5, 0.5);
uniform float chroma = 0.0;

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 to_c = uv - center;
	vec2 v = blur_vec + to_c * radial;
	vec3 sum = vec3(0.0);
	float wsum = 0.0;
	for (int i = 0; i < 14; i++) {
		float f = float(i) / 13.0 - 0.5;
		float w = 1.0 - abs(f) * 1.1;
		vec2 o = uv + v * f;
		vec3 s;
		s.r = texture(screen_tex, o + to_c * chroma).r;
		s.g = texture(screen_tex, o).g;
		s.b = texture(screen_tex, o - to_c * chroma).b;
		sum += s * w;
		wsum += w;
	}
	COLOR = vec4(sum / wsum, 1.0);
}
"""

var game: Node = null
var blur_vec: Vector2 = Vector2.ZERO
var radial: float = 0.0
var chroma: float = 0.0
var center_uv: Vector2 = Vector2(0.5, 0.5)
var enabled_by_user: bool = true
var _rect: ColorRect = null
var _material: ShaderMaterial = null

func _ready() -> void:
	layer = 20
	_material = ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = SHADER_CODE
	_material.shader = shader
	_rect = ColorRect.new()
	_rect.material = _material
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rect.visible = false
	add_child(_rect)

func setup(p_game: Node) -> void:
	game = p_game
	game.vfx_requested.connect(_on_fx)

func is_active() -> bool:
	return _rect != null and _rect.visible

func _reduced() -> bool:
	if not is_instance_valid(game):
		return false
	var imp: Variant = game.get("impact")
	return imp != null and is_instance_valid(imp) and bool(imp.get("reduced_motion"))

func _to_uv(world: Vector2) -> Vector2:
	var vp: Viewport = get_viewport()
	if vp == null:
		return Vector2(0.5, 0.5)
	var size: Vector2 = vp.get_visible_rect().size
	var screen: Vector2 = vp.get_canvas_transform() * world
	return Vector2(clampf(screen.x / size.x, 0.0, 1.0), clampf(screen.y / size.y, 0.0, 1.0))

func _kick(direction: Vector2, amount: float, rad: float, chr: float, at: Vector2) -> void:
	if _reduced() or not enabled_by_user or (is_instance_valid(game) and bool(game.get("story_safe"))):
		return
	var horizontal: Vector2 = Vector2(direction.x, direction.y * 0.35)
	if horizontal.length() < 0.01:
		horizontal = Vector2.RIGHT
	var wanted: Vector2 = horizontal.normalized() * amount
	if wanted.length() > blur_vec.length():
		blur_vec = wanted
	radial = maxf(radial, rad)
	chroma = maxf(chroma, chr)
	if rad > 0.0 or chr > 0.0:
		center_uv = _to_uv(at)
	_clamp()

func _clamp() -> void:
	blur_vec = blur_vec.limit_length(MAX_BLUR)
	radial = minf(radial, MAX_RADIAL)
	chroma = minf(chroma, MAX_CHROMA)

func _on_fx(kind: String, at: Vector2, dir: Vector2, power: float) -> void:
	var p: float = clampf(power, 0.4, 3.0)
	match kind:
		"slash":
			_kick(dir, 0.016 + 0.007 * p, 0.0, 0.0, at)
		"hit", "impact":
			_kick(dir, 0.026 * p, 0.06 * p, 0.006 * p, at)
		"hurt":
			_kick(dir, 0.03, 0.2, 0.026, at)
		"parry", "blade_parry":
			_kick(dir, 0.045, 0.22, 0.026, at)
		"projectile_parry":
			_kick(dir, 0.02, 0.1, 0.012, at)
		"guard_break":
			_kick(dir, 0.07, 0.34, 0.034, at)
		"dash_start", "enemy_dash":
			_kick(dir, 0.04, 0.05, 0.0, at)
		"death", "boss_defeat", "burst":
			_kick(Vector2.RIGHT, 0.02, 0.3, 0.03, at)

func _process(delta: float) -> void:
	if not is_instance_valid(game):
		return
	# Sustained smear while the hero is mid-dash.
	var pl: Variant = game.get("player")
	if pl != null and is_instance_valid(pl) and float(pl.get("dash_timer")) > 0.0:
		_kick(Vector2(float(pl.get("facing")), 0.0), 0.034, 0.03, 0.0, (pl as Node2D).global_position)
	var k: float = exp(-DECAY * delta)
	blur_vec *= k
	radial *= k
	chroma *= k
	var live: bool = blur_vec.length() > 0.0015 or radial > 0.004 or chroma > 0.0008
	if _reduced() or not enabled_by_user or bool(game.get("_paused")):
		live = false
		blur_vec = Vector2.ZERO
		radial = 0.0
		chroma = 0.0
	if _rect.visible != live:
		_rect.visible = live
	if live:
		_material.set_shader_parameter("blur_vec", blur_vec)
		_material.set_shader_parameter("radial", radial)
		_material.set_shader_parameter("chroma", chroma)
		_material.set_shader_parameter("center", center_uv)

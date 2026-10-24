extends Node2D
## Dark-fantasy mood layer: tinted ambient light, warm and cold light pools around flames, drifting ground fog,
## falling ash and rising embers, and a screen vignette. Presentation only: it reads the camera and the level's LIGHTS
## table, never touches gameplay, and every particle is a deterministic pixel rectangle (no textures, no shaders).
const Level = preload("res://levels/bellkeep.gd")
const AMBIENT := Color(0.86, 0.8, 0.94)
const MAX_ASH: int = 64
const MAX_EMBERS: int = 26
var game: Node
var _clock: float = 0.0
var _redraw: float = 0.0
var _vignette: Control
var _modulate: CanvasModulate
var visible_lights: int = 0

func setup(owner_game: Node) -> void:
	game = owner_game
	name = "DarkAtmosphere"
	process_mode = Node.PROCESS_MODE_PAUSABLE
	z_index = 8
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = add
	_modulate = CanvasModulate.new()
	_modulate.name = "AmbientTint"
	_modulate.color = AMBIENT
	game.add_child(_modulate)
	var layer := CanvasLayer.new()
	layer.name = "VignetteLayer"
	layer.layer = 12
	game.add_child(layer)
	_vignette = Control.new()
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_vignette.draw.connect(_draw_vignette)
	layer.add_child(_vignette)

func _process(delta: float) -> void:
	_clock += delta
	_redraw += delta
	if _redraw >= 0.066:
		_redraw = 0.0
		queue_redraw()
		if is_instance_valid(_vignette):
			_vignette.queue_redraw()

func view_rect() -> Rect2:
	var camera: Camera2D = game.get("_camera") as Camera2D if is_instance_valid(game) else null
	var size: Vector2 = get_viewport_rect().size
	var centre: Vector2 = camera.get_screen_center_position() if camera != null else Vector2.ZERO
	return Rect2(centre - size * 0.5, size)

## Alpha for a light at `phase`: a slow flicker so fires breathe instead of pulsing mechanically.
func flicker(phase: float) -> float:
	return 0.82 + 0.1 * sin(_clock * 7.0 + phase) + 0.08 * sin(_clock * 17.3 + phase * 2.3)

func _draw() -> void:
	if not is_instance_valid(game):
		return
	var view: Rect2 = view_rect()
	visible_lights = 0
	for entry: Dictionary in Level.LIGHTS:
		var at: Vector2 = entry["at"]
		var radius: float = float(entry["r"])
		if not view.grow(radius).has_point(at):
			continue
		visible_lights += 1
		_draw_light(at, radius, entry["tint"], float(entry["a"]) * flicker(at.x * 0.013 + at.y * 0.007))
	_draw_fog(view)
	_draw_ash(view)
	_draw_embers(view)

## Soft pool built from stepped, pixel-aligned discs. Rings alternate with the previous one so it reads as light falloff.
func _draw_light(at: Vector2, radius: float, tint: Color, strength: float) -> void:
	var steps: int = 6
	for step: int in steps:
		var r: float = radius * (1.0 - float(step) / float(steps))
		var alpha: float = strength * (0.1 + 0.9 * float(step + 1) / float(steps)) / float(steps) * 1.6
		var row_step: int = 2
		var iy: int = int(-r)
		while iy <= int(r):
			var half: int = int(sqrt(maxf(0.0, r * r - float(iy * iy))))
			half -= half % 2
			if half > 0:
				draw_rect(Rect2(at.x - half, at.y + iy, half * 2, row_step), Color(tint, alpha))
			iy += row_step

func _draw_fog(view: Rect2) -> void:
	# Low ground fog: wide soft bands that drift at different speeds near the floor line.
	for band: int in 5:
		var y: float = 262.0 + float(band) * 11.0
		if y < view.position.y - 12.0 or y > view.end.y + 12.0:
			continue
		var speed: float = 6.0 + float(band) * 3.0
		var width: float = 150.0 + float(band) * 36.0
		var gap: float = 270.0
		var first: int = int(floor((view.position.x - width) / gap)) - 1
		for i: int in range(first, first + int(view.size.x / gap) + 4):
			var x: float = float(i) * gap + fposmod(_clock * speed + float(band) * 53.0, gap)
			draw_rect(Rect2(x, y, width, 4), Color(0.45, 0.32, 0.55, 0.05))
			draw_rect(Rect2(x + 18, y + 4, width - 36, 3), Color(0.45, 0.32, 0.55, 0.04))

func _draw_ash(view: Rect2) -> void:
	for i: int in MAX_ASH:
		var depth: float = 0.5 + float(i % 4) * 0.25
		var x: float = view.position.x + fposmod(float(i) * 97.0 + _clock * (7.0 + float(i % 5) * 3.0) * depth + sin(_clock * 0.7 + float(i)) * 12.0, view.size.x)
		var y: float = view.position.y + fposmod(float(i) * 53.0 + _clock * (16.0 + float(i % 4) * 7.0) * depth, view.size.y)
		var size: float = 1.0 if i % 3 else 2.0
		draw_rect(Rect2(floorf(x), floorf(y), size, size), Color(0.75, 0.68, 0.8, 0.22 * depth))

func _draw_embers(view: Rect2) -> void:
	for i: int in MAX_EMBERS:
		var life: float = fposmod(_clock * (0.11 + float(i % 4) * 0.03) + float(i) * 0.137, 1.0)
		var x: float = view.position.x + fposmod(float(i) * 151.0 + sin(_clock * 1.3 + float(i) * 2.0) * 22.0, view.size.x)
		var y: float = view.end.y - life * (view.size.y * 0.8)
		var fade: float = sin(life * PI)
		var warm: Color = Color(1.0, 0.55 + 0.25 * float(i % 3) / 2.0, 0.22, 0.75 * fade)
		draw_rect(Rect2(floorf(x), floorf(y), 2, 2), warm)
		if i % 4 == 0:
			draw_rect(Rect2(floorf(x) + 2, floorf(y) - 2, 1, 1), Color(warm, 0.5 * fade))

func _draw_vignette() -> void:
	var size: Vector2 = _vignette.size
	if size.x <= 0.0:
		return
	# Concentric frames: transparent in the middle, near-black at the edges, 12 stepped bands.
	for band: int in 12:
		var inset: float = float(band) * 6.0
		var alpha: float = 0.5 * pow(1.0 - float(band) / 12.0, 2.0)
		_vignette.draw_rect(Rect2(inset, inset, size.x - inset * 2.0, size.y - inset * 2.0), Color(0.02, 0.0, 0.05, alpha), false, 6.0)

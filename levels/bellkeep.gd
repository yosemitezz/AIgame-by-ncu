extends Node2D
## Authored 2D route; all visible forms are original integer-grid pixel primitives.
## Final texture replacements may be supplied by Cursor without changing collision data.

const SPAWN: Vector2 = Vector2(90, 260)
const CHECKPOINT: Vector2 = Vector2(1860, 260)
const BOSS_TRIGGER_X: float = 2640.0
const BOSS_POSITION: Vector2 = Vector2(2990, 250)
const LEVEL_END: float = 3380.0
const WORLD_BOUNDS: Rect2 = Rect2(-40, -40, 3520, 440)
const PLATFORMS: Array[Rect2] = [
	# Main route: four forgiving gaps; the first is introduced before mixed combat.
	Rect2(-80, 300, 590, 120),
	Rect2(582, 300, 338, 120),
	Rect2(1000, 300, 332, 120),
	Rect2(1416, 300, 310, 120),
	Rect2(1798, 300, 1762, 120),
	# Optional upper route; thin platforms are one-way from below.
	Rect2(326, 256, 90, 12),
	Rect2(438, 212, 110, 12),
	Rect2(584, 168, 130, 12),
	Rect2(768, 144, 100, 12),
	Rect2(908, 188, 100, 12),
	Rect2(1040, 230, 110, 12),
	Rect2(1200, 248, 100, 12),
	Rect2(1532, 252, 108, 12),
	# The arena has optional height for aerial interception, never a mandatory wall.
	Rect2(2690, 252, 94, 12),
	Rect2(2862, 210, 104, 12),
	Rect2(3124, 252, 100, 12),
]
const ENEMIES: Array[Dictionary] = [
	{"kind": "sentry", "at": Vector2(390, 300)},
	{"kind": "sentry", "at": Vector2(748, 300)},
	{"kind": "wisp", "at": Vector2(1080, 238)},
	{"kind": "wisp", "at": Vector2(1512, 238)},
	{"kind": "sentry", "at": Vector2(1630, 300)},
	{"kind": "elite", "at": Vector2(2240, 300)},
]
const SHARDS: Array[Vector2] = [
	Vector2(372, 232), Vector2(490, 188), Vector2(648, 144),
	Vector2(816, 120), Vector2(956, 164), Vector2(1092, 206),
	Vector2(1248, 224), Vector2(1460, 276), Vector2(1584, 228),
	Vector2(1970, 276), Vector2(2392, 276), Vector2(2914, 186),
]
const ZONES: Array[Dictionary] = [
	{"x": 0.0, "title": "THE WAKING NAVE", "hint": "A/D move  /  SPACE jump  /  Follow the cyan light"},
	{"x": 274.0, "title": "A BORROWED EDGE", "hint": "J slash, chain three cuts  /  K parry on contact"},
	{"x": 500.0, "title": "THE BROKEN CLOISTER", "hint": "Jump the broken stones  /  A second jump reaches the upper route"},
	{"x": 1000.0, "title": "ASHEN CAUSEWAY", "hint": "SHIFT dash  /  Gold shots can be turned into cyan starfire"},
	{"x": 1798.0, "title": "EMBER SHRINE", "hint": "Checkpoint ahead  /  A quiet breath before the bell"},
	{"x": 2090.0, "title": "THE BELLWARDEN'S TRIAL", "hint": "An elite guards the passage  /  Watch its wind-up"},
	{"x": 2470.0, "title": "BEFORE THE LAST CHIME", "hint": "The bell marks attacks, but your blade answers their contact"},
	{"x": 2640.0, "title": "THE HOLLOW BELFRY", "hint": "Close the distance  /  Parry the golden rain"},
]

const SKY: Color = Color("101323")
const SKY_LOW: Color = Color("171b2c")
const FAR: Color = Color("1d2537")
const MID: Color = Color("273147")
const MASON: Color = Color("303a4d")
const STONE: Color = Color("3e4c60")
const LIP: Color = Color("6d7e8b")
const DARK: Color = Color("141b2b")
const CYAN_LOW: Color = Color("315b67")
const CYAN: Color = Color("77cfc8")
const GOLD_LOW: Color = Color("88704e")
const GOLD: Color = Color("b9a16d")

var game: Node = null
var _clock: float = 0.0
var _draw_clock: float = 0.0
var _built: bool = false

func setup(p_game: Node) -> void:
	game = p_game
	z_index = -20
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if _built:
		return
	_built = true
	for index in range(PLATFORMS.size()):
		var area: Rect2 = PLATFORMS[index]
		var body: StaticBody2D = StaticBody2D.new()
		body.name = "Masonry_%02d" % index
		body.collision_layer = 1
		body.collision_mask = 0
		body.position = area.get_center()
		var shape_node: CollisionShape2D = CollisionShape2D.new()
		var shape: RectangleShape2D = RectangleShape2D.new()
		shape.size = area.size
		shape_node.shape = shape
		shape_node.one_way_collision = area.size.y <= 16.0
		shape_node.one_way_collision_margin = 4.0
		body.add_child(shape_node)
		add_child(body)
	queue_redraw()

func _process(delta: float) -> void:
	_clock += delta
	_draw_clock += delta
	if _draw_clock >= 0.125:
		_draw_clock = 0.0
		queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(-360, -420, 4280, 1000), SKY)
	draw_rect(Rect2(-360, 116, 4280, 464), SKY_LOW)
	_draw_sky()
	_draw_silhouettes()
	_draw_colonnade()
	_draw_bell_landmark()
	for area in PLATFORMS:
		_draw_platform(area)
	_draw_broken_chains()
	_draw_shrine()
	_draw_wayfinding()
	_draw_gate(2640, 300, false)
	_draw_gate(3380, 300, true)

func _draw_sky() -> void:
	# Two-pixel star clusters, without filtering or generated bitmap content.
	for index in range(96):
		var x: int = -160 + ((index * 163 + 47) % 3760)
		var y: int = -40 + ((index * 47 + 11) % 172)
		var tint: Color = CYAN_LOW if index % 4 == 0 else MID
		draw_rect(Rect2(x, y, 2, 2), tint)
	# A single broken moon establishes the belfry as the destination.
	_pixel_disc(Vector2(2922, 74), 48, Color("334253"))
	_pixel_disc(Vector2(2936, 62), 43, SKY)
	draw_rect(Rect2(2864, 98, 128, 4), SKY_LOW)
	for index in range(13):
		var x: int = index * 288 - 100
		var y: int = 108 + (index % 3) * 12
		draw_rect(Rect2(x, y, 152, 4), Color("1d2639"))
		draw_rect(Rect2(x + 36, y - 4, 92, 4), Color("1d2639"))

func _draw_silhouettes() -> void:
	for index in range(18):
		var x: int = index * 216 - 150
		var top: int = 124 + ((index * 37) % 92)
		var width: int = 68 + (index % 4) * 12
		draw_rect(Rect2(x, top, width, 180), FAR)
		draw_rect(Rect2(x - 8, top - 8, width + 16, 8), FAR)
		for tooth in range(4):
			draw_rect(Rect2(x + tooth * 24, top - 20, 12, 16), FAR)
		if index % 3 != 1:
			var roof: PackedVector2Array = PackedVector2Array([
				Vector2(x - 4, top), Vector2(x + 12, top - 20),
				Vector2(x + width / 2, top - 48), Vector2(x + width - 12, top - 20),
				Vector2(x + width + 4, top),
			])
			draw_colored_polygon(roof, FAR)
		for row in range(3):
			draw_rect(Rect2(x + 18, top + 24 + row * 42, 6, 12), SKY_LOW)
			draw_rect(Rect2(x + width - 24, top + 24 + row * 42, 6, 12), SKY_LOW)
	# Mountain mass is deliberately flat silhouette; no perspective faces.
	draw_colored_polygon(PackedVector2Array([
		Vector2(-160, 300), Vector2(40, 214), Vector2(180, 270),
		Vector2(380, 206), Vector2(600, 284), Vector2(820, 242),
		Vector2(1020, 300),
	]), Color("202a3c"))

func _draw_colonnade() -> void:
	for index in range(12):
		var x: int = index * 220 + 68
		var arch_top: int = 110 + (index % 2) * 22
		var cut: bool = index == 3 or index == 6 or index == 9
		_draw_arch(x, arch_top, 132, 190, MID)
		if cut:
			draw_rect(Rect2(x + 42, arch_top - 4, 92, 28), SKY_LOW)
			draw_rect(Rect2(x + 96, arch_top + 24, 38, 38), SKY_LOW)
		draw_rect(Rect2(x - 8, 276, 28, 24), MASON)
		draw_rect(Rect2(x + 120, 276, 28, 24), MASON)
		if index % 3 == 0:
			_draw_tattered_banner(x + 28, arch_top + 42, index)

func _draw_arch(x: float, y: float, width: float, height: float, tint: Color) -> void:
	var edge: float = 12.0
	draw_rect(Rect2(x, y + 36, edge, height - 36), tint)
	draw_rect(Rect2(x + width - edge, y + 36, edge, height - 36), tint)
	draw_rect(Rect2(x + 8, y + 20, 16, 20), tint)
	draw_rect(Rect2(x + width - 24, y + 20, 16, 20), tint)
	draw_rect(Rect2(x + 20, y + 8, 20, 16), tint)
	draw_rect(Rect2(x + width - 40, y + 8, 20, 16), tint)
	draw_rect(Rect2(x + 36, y, width - 72, 12), tint)
	draw_rect(Rect2(x - 4, y + height - 10, 20, 10), tint)
	draw_rect(Rect2(x + width - 16, y + height - 10, 20, 10), tint)

func _draw_tattered_banner(x: int, y: int, variant: int) -> void:
	draw_rect(Rect2(x - 4, y - 4, 48, 4), GOLD_LOW)
	draw_rect(Rect2(x, y, 32, 64), Color("3b344b"))
	draw_rect(Rect2(x + 4, y, 4, 52), Color("514255"))
	draw_rect(Rect2(x + 24, y, 4, 56), Color("514255"))
	draw_rect(Rect2(x + 8, y + 24, 16, 4), GOLD_LOW)
	draw_rect(Rect2(x + 14, y + 16, 4, 20), GOLD_LOW)
	draw_rect(Rect2(x, y + 56, 12, 16 if variant % 2 == 0 else 8), Color("3b344b"))
	draw_rect(Rect2(x + 22, y + 56, 10, 20), Color("3b344b"))

func _draw_platform(area: Rect2) -> void:
	var top: float = area.position.y
	var left: float = area.position.x
	var width: float = area.size.x
	var thin: bool = area.size.y <= 16.0
	draw_rect(area, DARK)
	draw_rect(Rect2(left, top, width, 4), LIP)
	draw_rect(Rect2(left, top + 4, width, 4), STONE)
	if thin:
		draw_rect(Rect2(left + 4, top + 8, width - 8, 4), MASON)
		for index in range(int(width / 24)):
			draw_rect(Rect2(left + 8 + index * 24, top + 4, 2, 8), DARK)
		draw_rect(Rect2(left + 8, top + 12, 8, 12), MID)
		draw_rect(Rect2(left + width - 20, top + 12, 8, 12), MID)
	else:
		for row in range(4):
			var offset: int = (row % 2) * 20
			for index in range(int(width / 40) + 1):
				var stone_left: float = left + index * 40 - offset + 2
				var stone_right: float = minf(stone_left + 36, left + width - 2)
				stone_left = maxf(stone_left, left + 2)
				if stone_right > stone_left:
					draw_rect(Rect2(stone_left, top + 10 + row * 22, stone_right - stone_left, 18), MASON if row < 2 else MID)
		for index in range(int(width / 52)):
			draw_rect(Rect2(left + 8 + index * 52, top + 1, 12, 2), Color("8d999b"))
			draw_rect(Rect2(left + 10 + index * 52, top + 8, 6, 4), CYAN_LOW)

func _draw_broken_chains() -> void:
	for anchor in [548, 960, 1376, 1762]:
		for link in range(13):
			var x: int = int(anchor) + (2 if link % 2 else 0)
			var y: int = 14 + link * 10
			draw_rect(Rect2(x, y, 4, 6), MID)
			draw_rect(Rect2(x + 1, y + 1, 2, 4), DARK)
		# Hanging rubble makes the broken floor visually obvious below its bright lip.
		draw_rect(Rect2(int(anchor) - 22, 332, 16, 28), MID)
		draw_rect(Rect2(int(anchor) + 12, 348, 12, 38), FAR)

func _draw_shrine() -> void:
	var x: float = CHECKPOINT.x
	draw_rect(Rect2(x - 26, 288, 52, 12), STONE)
	draw_rect(Rect2(x - 18, 282, 36, 6), LIP)
	draw_rect(Rect2(x - 10, 246, 20, 36), MASON)
	draw_rect(Rect2(x - 2, 250, 4, 28), CYAN_LOW)
	var pulse: int = 2 if int(_clock * 4) % 2 == 0 else 0
	_draw_diamond(Vector2(x, 234 - pulse), 10, CYAN_LOW)
	_draw_diamond(Vector2(x, 234 - pulse), 5, CYAN)
	draw_rect(Rect2(x - 1, 226 - pulse, 2, 12), Color("c5f3df"))
	_draw_arch(x - 58, 164, 116, 136, MID)
	for side in [-1, 1]:
		_draw_candle(int(x) + side * 42, 286)

func _draw_bell_landmark() -> void:
	# Giant cracked bell forms a flat, readable arena backdrop.
	draw_rect(Rect2(2978, -60, 16, 120), MID)
	draw_rect(Rect2(2956, 38, 60, 12), MASON)
	draw_rect(Rect2(2936, 50, 100, 12), MASON)
	draw_rect(Rect2(2924, 62, 124, 48), MASON)
	draw_rect(Rect2(2912, 106, 148, 12), STONE)
	draw_rect(Rect2(2902, 118, 168, 12), MASON)
	draw_rect(Rect2(2978, 130, 16, 22), GOLD_LOW)
	draw_rect(Rect2(2966, 148, 40, 8), GOLD_LOW)
	draw_rect(Rect2(2944, 62, 4, 32), STONE)
	draw_rect(Rect2(2950, 56, 20, 4), STONE)
	draw_rect(Rect2(2996, 54, 6, 20), DARK)
	draw_rect(Rect2(2988, 70, 8, 16), DARK)
	draw_rect(Rect2(2994, 82, 6, 24), DARK)
	_draw_arch(2750, 14, 470, 286, FAR)

func _draw_wayfinding() -> void:
	for marker in [188, 690, 1192, 1942, 2532]:
		var x: int = int(marker)
		draw_rect(Rect2(x, 276, 12, 3), CYAN_LOW)
		draw_rect(Rect2(x + 10, 273, 4, 3), CYAN)
		draw_rect(Rect2(x + 14, 276, 4, 3), CYAN)
		draw_rect(Rect2(x + 10, 279, 4, 3), CYAN)
	for marker in [126, 900, 2076, 2580, 3300]:
		_draw_candle(int(marker), 300)
	# Side-route lanterns mark the optional ascent without masquerading as shots.
	for marker in [Vector2(346, 246), Vector2(612, 158), Vector2(792, 134)]:
		var at: Vector2 = marker
		draw_rect(Rect2(at.x, at.y - 10, 6, 10), CYAN_LOW)
		draw_rect(Rect2(at.x + 2, at.y - 8, 2, 5), CYAN)

func _draw_candle(x: int, y: int) -> void:
	draw_rect(Rect2(x - 4, y - 10, 8, 10), MASON)
	draw_rect(Rect2(x - 2, y - 14, 4, 6), GOLD_LOW)
	var flicker: int = 2 if int(_clock * 8 + x) % 3 == 0 else 0
	draw_rect(Rect2(x - 2, y - 19 - flicker, 4, 6 + flicker), GOLD)
	draw_rect(Rect2(x, y - 18 - flicker, 2, 4), Color("d7c898"))

func _draw_gate(x: int, floor_y: int, exit_gate: bool) -> void:
	var tint: Color = MASON if exit_gate else MID
	_draw_arch(x - 54, floor_y - 158, 108, 158, tint)
	draw_rect(Rect2(x - 60, floor_y - 12, 24, 12), STONE)
	draw_rect(Rect2(x + 36, floor_y - 12, 24, 12), STONE)
	if exit_gate:
		draw_rect(Rect2(x - 16, floor_y - 136, 32, 4), GOLD_LOW)
		draw_rect(Rect2(x - 2, floor_y - 148, 4, 28), GOLD_LOW)
	else:
		_draw_diamond(Vector2(x, floor_y - 144), 5, GOLD_LOW)

func _pixel_disc(at: Vector2, radius: int, tint: Color) -> void:
	for dy in range(-radius, radius + 1, 2):
		var half_width: int = int(sqrt(maxf(0.0, float(radius * radius - dy * dy))))
		half_width -= half_width % 2
		if half_width > 0:
			draw_rect(Rect2(at.x - half_width, at.y + dy, half_width * 2, 2), tint)

func _draw_diamond(at: Vector2, radius: int, tint: Color) -> void:
	for dy in range(-radius, radius + 1, 2):
		var half_width: int = radius - absi(dy)
		draw_rect(Rect2(at.x - half_width, at.y + dy, maxi(half_width * 2, 2), 2), tint)

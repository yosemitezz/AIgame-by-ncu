extends Node2D
## Authored 2D route; all visible forms are original integer-grid pixel primitives.
## Final texture replacements may be supplied by Cursor without changing collision data.

const ROOM_ID: String = "dungeon"
const PORTAL_POSITION: Vector2 = Vector2(2560, 300)
const PORTAL_RECT: Rect2 = Rect2(2524, 244, 72, 64)
const ROOM_END_WALL: Rect2 = Rect2(2626, -160, 16, 460)
const SPAWN: Vector2 = Vector2(90, 260)
const CHECKPOINT: Vector2 = Vector2(1860, 260)
const BOSS_TRIGGER_X: float = 2640.0
const BOSS_POSITION: Vector2 = Vector2(2990, 250)
const LEVEL_END: float = 3380.0
const WORLD_BOUNDS: Rect2 = Rect2(-40, -160, 3520, 860)
const FALL_LIMIT: float = 720.0
const CHECKPOINT_RECT: Rect2 = Rect2(1824, 240, 72, 72)
const INTERACTION_RADIUS: float = 36.0
const LAYOUT_VERSION: int = 2
const PLATFORMS: Array[Rect2] = [
	# Main route: four forgiving gaps; the first is introduced before mixed combat.
	Rect2(-80, 300, 590, 24),
	Rect2(582, 300, 338, 24),
	Rect2(1000, 300, 160, 24),
	Rect2(1192, 300, 140, 24),
	Rect2(1416, 300, 310, 24),
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
	# Optional gallery over the elite court: three one-way steps (rise 44, gaps 44/42) that give
	# the player an aerial option against the elite. Never required; all return to the same floor.
	Rect2(2110, 256, 96, 12),
	Rect2(2250, 212, 100, 12),
	Rect2(2392, 256, 96, 12),
	# The arena has optional height for aerial interception, never a mandatory wall.
	Rect2(2690, 252, 94, 12),
	Rect2(2834, 210, 104, 12),
	Rect2(3124, 252, 100, 12),
	# A genuine lower route loops from the first teaching gap to the shrine approach.
	Rect2(440, 500, 512, 80),
	Rect2(1032, 500, 384, 80),
	Rect2(1496, 500, 312, 80),
	# Library balcony. Its two open chain shafts have 32px clearance.
	Rect2(1128, 48, 32, 20),
	Rect2(1192, 48, 168, 20),
	Rect2(1392, 48, 184, 20),
]
const CLIMBABLES: Array[Dictionary] = [
	{"id": "entry_chain", "kind": "chain", "rect": Rect2(536, 244, 24, 256)},
	{"id": "shrine_chain", "kind": "chain", "rect": Rect2(1750, 244, 24, 256)},
	{"id": "archive_chain", "kind": "chain", "rect": Rect2(1364, 4, 24, 496)},
	{"id": "return_chain", "kind": "chain", "rect": Rect2(1164, 4, 24, 496)},
]
const WATER_REGIONS: Array[Rect2] = [Rect2(700, 488, 220, 12), Rect2(1148, 486, 236, 14)]
const DOORS: Array[Dictionary] = [
	{"id": "crypt_door", "kind": "door", "rect": Rect2(670, 324, 12, 176), "at": Vector2(676, 476), "hint": "E 打开墓廊铁门"},
	{"id": "shortcut_hatch", "kind": "lever", "rect": Rect2(1738, 320, 48, 12), "at": Vector2(1712, 476), "hint": "E 扳动机关，开启回程捷径"},
	{"id": "archive_door", "kind": "door", "rect": Rect2(1242, -100, 12, 148), "at": Vector2(1248, 24), "hint": "E 推开书库木门"},
]
const ROOMS: Array[Dictionary] = [
	{"id": "archive", "rect": Rect2(1100, -112, 520, 212), "title": "悬链书库", "hint": "沿链攀升；推门后可从另一条链返回回廊"},
	{"id": "crypt", "rect": Rect2(420, 340, 1420, 260), "title": "淤水墓廊", "hint": "浅水不致伤；沿石沿跨越缺口，寻找回程机关"},
]
const ENEMIES: Array[Dictionary] = [
    {"kind":"sentry","at":Vector2(390,300),"patrol":Rect2(310,190,190,134)},
    {"kind":"lantern","at":Vector2(748,300),"patrol":Rect2(620,180,280,144)},
    {"kind":"wisp","at":Vector2(1080,238),"patrol":Rect2(1008,142,320,182)},
    {"kind":"bat","at":Vector2(1512,238),"patrol":Rect2(1432,146,272,178)},
    {"kind":"sentry","at":Vector2(1630,300),"patrol":Rect2(1450,180,276,144)},
    {"kind":"elite","at":Vector2(2240,300),"patrol":Rect2(2090,176,398,148)},
    {"kind":"lantern","at":Vector2(760,500),"patrol":Rect2(704,380,200,144)},
    {"kind":"wisp","at":Vector2(1100,446),"patrol":Rect2(1056,350,320,174)},
    {"kind":"jailer","at":Vector2(1556,500),"patrol":Rect2(1512,350,272,174)},
    {"kind":"jailer","at":Vector2(1480,48),"patrol":Rect2(1408,-96,144,168)},
    {"kind":"bat","at":Vector2(1304,-4),"patrol":Rect2(1208,-100,140,168)},
]
const SHARDS: Array[Vector2] = [
	Vector2(372, 232), Vector2(490, 188), Vector2(648, 144),
	Vector2(816, 120), Vector2(956, 164), Vector2(1092, 206),
	Vector2(1248, 224), Vector2(1460, 276), Vector2(1584, 228),
	Vector2(1970, 276), Vector2(2392, 276), Vector2(2914, 186),
	# Appended, never reordered: collected shards are stored by index for the running session.
	Vector2(2158, 232), Vector2(2300, 188), Vector2(2440, 232),
	# New rewards are append-only: the original first fifteen shard indices are stable.
	Vector2(704, 476), Vector2(864, 476), Vector2(1104, 476),
	Vector2(1280, 476), Vector2(1576, 476), Vector2(1712, 476),
	Vector2(1288, 24), Vector2(1456, 24), Vector2(1480, 24), Vector2(1504, 24),
]
const ZONES: Array[Dictionary] = [
	{"x": 0.0, "title": "THE WAKING NAVE", "hint": "A/D move  /  SPACE jump  /  Follow the cyan light"},
	{"x": 274.0, "title": "A BORROWED EDGE", "hint": "J slash, chain three cuts  /  LEFT SHIFT parry on contact"},
	{"x": 500.0, "title": "THE BROKEN CLOISTER", "hint": "Jump the broken stones  /  A second jump reaches the upper route"},
	{"x": 1000.0, "title": "ASHEN CAUSEWAY", "hint": "Double-tap WASD to dodge  /  LEFT SHIFT reflects gold shots"},
	{"x": 1798.0, "title": "EMBER SHRINE", "hint": "Checkpoint ahead  /  A quiet breath before the bell"},
	{"x": 2090.0, "title": "THE BELLWARDEN'S TRIAL", "hint": "An elite guards the passage  /  Watch its wind-up"},
	{"x": 2470.0, "title": "BEFORE THE LAST CHIME", "hint": "The bell marks attacks, but your blade answers their contact"},
	{"x": 2640.0, "title": "THE HOLLOW BELFRY", "hint": "Close the distance  /  Parry the golden rain"},
]

const SKY: Color = Color("0b0a15")
const SKY_LOW: Color = Color("150f1e")
const HAZE: Color = Color("3a1a2c")
const FAR: Color = Color("1a1524")
const MID: Color = Color("241d30")
const MASON: Color = Color("322b3c")
const STONE: Color = Color("41394b")
const LIP: Color = Color("786b7e")
const DARK: Color = Color("0f0b16")
const CYAN_LOW: Color = Color("2d5560")
const CYAN: Color = Color("6fd0c6")
const GOLD_LOW: Color = Color("7d5a3c")
const GOLD: Color = Color("c08a4a")
const BONE: Color = Color("b8ad9a")
const BLOOD: Color = Color("6a1a28")
## Stained glass: wine, indigo, amber, teal.
const GLASS: Array[Color] = [Color("7a2338"), Color("2c3a78"), Color("b07a36"), Color("2f6a6a")]
const TREE_XS: Array[int] = [40, 250, 470, 640, 880, 1090, 1250, 1560, 1690, 1980, 2200, 2480, 3180, 3480]
const TOMB_XS: Array[int] = [96, 150, 214, 364, 420, 612, 668, 752, 1030, 1226, 1462, 1524, 1648, 1930, 2010, 2144, 2330, 2420, 2540, 3190, 3236, 3470]
const FENCES: Array[Vector2] = [Vector2(236, 356), Vector2(1440, 1600), Vector2(2150, 2300)]
const CAGES: Array[Vector2] = [Vector2(610, 28), Vector2(800, 44), Vector2(1060, 32), Vector2(1300, 50), Vector2(1490, 36)]
const GARGOYLES: Array[Vector3] = [Vector3(2626, 142, -1), Vector3(2654, 142, 1), Vector3(3366, 142, -1), Vector3(3394, 142, 1), Vector3(1836, 164, -1), Vector3(1884, 164, 1)]
## Light pools used by vfx/dark_atmosphere.gd. at: world position of the flame, r: radius in px, a: strength.
const LIGHTS: Array[Dictionary] = [
	{"at": Vector2(624, 388), "r": 78, "tint": Color("ff9a4a"), "a": 0.22},
	{"at": Vector2(916, 388), "r": 78, "tint": Color("ff9a4a"), "a": 0.22},
	{"at": Vector2(1392, 388), "r": 78, "tint": Color("ff9a4a"), "a": 0.22},
	{"at": Vector2(1640, 388), "r": 78, "tint": Color("ff9a4a"), "a": 0.22},
	{"at": Vector2(1116, -36), "r": 70, "tint": Color("ffa85a"), "a": 0.22},
	{"at": Vector2(1360, -36), "r": 70, "tint": Color("ffa85a"), "a": 0.22},
	{"at": Vector2(1592, -36), "r": 70, "tint": Color("ffa85a"), "a": 0.22},
	{"at": Vector2(126, 281), "r": 46, "tint": Color("ffb060"), "a": 0.2},
	{"at": Vector2(900, 281), "r": 46, "tint": Color("ffb060"), "a": 0.2},
	{"at": Vector2(2076, 281), "r": 46, "tint": Color("ffb060"), "a": 0.2},
	{"at": Vector2(2580, 281), "r": 46, "tint": Color("ffb060"), "a": 0.2},
	{"at": Vector2(3300, 281), "r": 46, "tint": Color("ffb060"), "a": 0.2},
	{"at": Vector2(1860, 236), "r": 104, "tint": Color("5fe0d0"), "a": 0.26},
	{"at": Vector2(349, 238), "r": 40, "tint": Color("5fe0d0"), "a": 0.2},
	{"at": Vector2(615, 150), "r": 40, "tint": Color("5fe0d0"), "a": 0.2},
	{"at": Vector2(795, 126), "r": 40, "tint": Color("5fe0d0"), "a": 0.2},
	{"at": Vector2(2640, 150), "r": 74, "tint": Color("c0504a"), "a": 0.2},
	{"at": Vector2(2990, 120), "r": 150, "tint": Color("d03a48"), "a": 0.2},
	{"at": Vector2(3380, 150), "r": 90, "tint": Color("c05040"), "a": 0.22},
]

var game: Node = null
var _clock: float = 0.0
var _draw_clock: float = 0.0
var _built: bool = false
var door_states: Dictionary = {}
var _door_bodies: Dictionary = {}

func setup(p_game: Node) -> void:
	game = p_game
	z_index = -20
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if _built:
		return
	_built = true
	var room_platforms: Array = get_room_spec()["platforms"]
	for index in range(room_platforms.size()):
		var area: Rect2 = room_platforms[index]
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
	_build_doors()
	queue_redraw()

func _process(delta: float) -> void:
	_clock += delta
	_draw_clock += delta
	if _draw_clock >= 0.125:
		_draw_clock = 0.0
		queue_redraw()

func _draw() -> void:
	_draw_sky_gradient()
	_draw_sky()
	_draw_silhouettes()
	_draw_spires()
	_draw_lancets()
	_draw_colonnade()
	_draw_graveyard()
	_draw_bell_landmark()
	_draw_dungeon_background()
	_draw_archive()
	for area: Rect2 in get_room_spec()["platforms"]:
		_draw_platform(area)
	_draw_hanging_cages()
	_draw_ground_details()
	_draw_broken_chains()
	_draw_shrine()
	_draw_wayfinding()
	_draw_room_portal()
	_draw_gargoyles()
	_draw_climbs()
	_draw_water()
	_draw_doors()

func _draw_sky() -> void:
	# Two-pixel star clusters, without filtering or generated bitmap content.
	for index in range(96):
		var x: int = -160 + ((index * 163 + 47) % 3760)
		var y: int = -40 + ((index * 47 + 11) % 172)
		var tint: Color = Color("5a4a66") if index % 4 == 0 else MID
		draw_rect(Rect2(x, y, 2, 2), tint)
	# A single broken moon establishes the belfry as the destination.
	for halo in range(4):
		_pixel_disc(Vector2(2922, 74), 84 - halo * 10, Color(0.55, 0.13, 0.2, 0.05 + halo * 0.03))
	_pixel_disc(Vector2(2922, 74), 48, Color("7d2230"))
	_pixel_disc(Vector2(2918, 70), 44, Color("9a2f3c"))
	for crater in [Vector2(2900, 62), Vector2(2934, 88), Vector2(2940, 56), Vector2(2910, 92)]:
		draw_rect(Rect2(crater.x, crater.y, 8, 6), Color("6a1c28"))
		draw_rect(Rect2(crater.x + 2, crater.y + 1, 4, 2), Color("7d2230"))
	draw_rect(Rect2(2864, 98, 128, 4), SKY_LOW)
	for index in range(13):
		var x: int = index * 288 - 100
		var y: int = 108 + (index % 3) * 12
		draw_rect(Rect2(x, y, 152, 4), Color("261c32"))
		draw_rect(Rect2(x + 36, y - 4, 92, 4), Color("261c32"))

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
	]), Color("211a2e"))

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
		for row in range(maxi(1, int((area.size.y - 10.0) / 22.0))):
			var offset: int = (row % 2) * 20
			for index in range(int(width / 40) + 1):
				var stone_left: float = left + index * 40 - offset + 2
				var stone_right: float = minf(stone_left + 36, left + width - 2)
				stone_left = maxf(stone_left, left + 2)
				if stone_right > stone_left:
					draw_rect(Rect2(stone_left, top + 10 + row * 22, stone_right - stone_left, minf(18.0, area.size.y - 12.0 - row * 22)), MASON if row < 2 else MID)
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


func climb_at(feet: Vector2) -> Dictionary:
	for entry: Dictionary in CLIMBABLES:
		var rect: Rect2 = entry["rect"]
		if _contains_closed(rect, feet):
			return entry.duplicate()
	return {}

func water_at(feet: Vector2) -> bool:
	for rect: Rect2 in WATER_REGIONS:
		if _contains_closed(rect, feet):
			return true
	return false

func room_at(feet: Vector2) -> Dictionary:
	for room: Dictionary in ROOMS:
		if _contains_closed(room["rect"], feet):
			return room.duplicate()
	return {}

func _contains_closed(rect: Rect2, point: Vector2) -> bool:
	return point.x >= rect.position.x and point.x <= rect.end.x and point.y >= rect.position.y and point.y <= rect.end.y

func _interaction_at(feet: Vector2) -> Dictionary:
	var nearest: Dictionary = {}
	var nearest_distance: float = INTERACTION_RADIUS + 0.001
	for entry: Dictionary in DOORS:
		if bool(door_states.get(entry["id"], false)):
			continue
		var distance: float = feet.distance_to(entry["at"])
		if distance <= INTERACTION_RADIUS and distance < nearest_distance:
			nearest_distance = distance
			nearest = entry
	return nearest

func interaction_hint(feet: Vector2) -> String:
	if not portal_at(feet).is_empty():
		return "E - Enter the hollow belfry" if is_instance_valid(game) and game.get("elite_defeated") == true else "The Bellwarden seals this portal"
	var entry: Dictionary = _interaction_at(feet)
	if not entry.is_empty():
		return str(entry["hint"])
	if not climb_at(feet).is_empty():
		return "W/S 或 ↑/↓ 攀链；空格跳离"
	if water_at(feet):
		return "浅水：可跑跳与冲刺"
	return ""

func try_interact(feet: Vector2) -> bool:
	var entry: Dictionary = _interaction_at(feet)
	if entry.is_empty():
		return false
	_set_door_open(str(entry["id"]), true)
	if is_instance_valid(game) and game.has_method("announce"):
		game.call("announce", "捷径已开启" if entry["kind"] == "lever" else "门已开启", 2.0)
	return true

func get_opened_ids() -> Array[String]:
	var result: Array[String] = []
	for entry: Dictionary in DOORS:
		var id: String = str(entry["id"])
		if bool(door_states.get(id, false)):
			result.append(id)
	return result

func restore_opened_ids(ids: Array) -> void:
	reset_interactions()
	for entry: Dictionary in DOORS:
		var id: String = str(entry["id"])
		if ids.has(id):
			_set_door_open(id, true)

func reset_interactions() -> void:
	for entry: Dictionary in DOORS:
		_set_door_open(str(entry["id"]), false)

func _build_doors() -> void:
	for entry: Dictionary in DOORS:
		var id: String = str(entry["id"])
		var rect: Rect2 = entry["rect"]
		var body: StaticBody2D = StaticBody2D.new()
		body.name = "Door_" + id
		body.position = rect.get_center()
		body.collision_layer = 1
		body.collision_mask = 0
		var collider: CollisionShape2D = CollisionShape2D.new()
		collider.name = "Collider"
		var shape: RectangleShape2D = RectangleShape2D.new()
		shape.size = rect.size
		collider.shape = shape
		collider.disabled = bool(door_states.get(id, false))
		body.add_child(collider)
		add_child(body)
		_door_bodies[id] = body
		door_states[id] = collider.disabled

func _set_door_open(id: String, opened: bool) -> void:
	door_states[id] = opened
	if _door_bodies.has(id):
		var body: StaticBody2D = _door_bodies[id]
		if is_instance_valid(body):
			var collider: CollisionShape2D = body.get_node("Collider")
			collider.set_deferred("disabled", opened)
	queue_redraw()

func _draw_dungeon_background() -> void:
	draw_rect(Rect2(400, 324, 1450, 276), Color("0f0f1a"))
	for row in range(11):
		var y: int = 326 + row * 16
		var offset: int = 16 if row % 2 else 0
		for column in range(46):
			var x: int = 400 + column * 32 - offset
			draw_rect(Rect2(x, y, 31, 15), Color("191a28") if (row + column) % 5 else Color("222335"))
	for x in [466, 728, 1008, 1270, 1552, 1784]:
		_draw_arch(float(x), 348.0, 108.0, 152.0, Color("2c2a3b"))
		draw_rect(Rect2(int(x) + 14, 390, 80, 110), Color("120f1b"))
		for bar in range(4):
			draw_rect(Rect2(int(x) + 24 + bar * 16, 382, 2, 116), Color("2a2838"))
	for index in range(38):
		var x: int = 432 + (index * 89) % 1330
		var y: int = 342 + (index * 31) % 104
		draw_rect(Rect2(x, y, 2, 14 + (index % 4) * 6), Color("2a4147"))
		draw_rect(Rect2(x + 2, y + 9, 3, 2), Color("344b4a"))
	for x in [624, 916, 1392, 1640]:
		_draw_wall_torch(int(x), 396)
	# Uneven low-value rubble fills the base without inventing walkable surfaces.
	for index in range(30):
		var x: int = 416 + index * 46
		draw_rect(Rect2(x, 480 + index % 3 * 4, 16, 12), Color("211f2c"))
		draw_rect(Rect2(x + 12, 488, 12, 12), Color("171520"))

func _draw_archive() -> void:
	draw_rect(Rect2(1096, -112, 520, 160), Color("1a1b2a"))
	for row in range(8):
		var offset: int = 16 if row % 2 else 0
		for col in range(17):
			draw_rect(Rect2(1096 + col * 32 - offset, -110 + row * 20, 31, 19), Color("29283a"))
	for x in [1140, 1210, 1290, 1412, 1492, 1560]:
		draw_rect(Rect2(int(x), -72, 48, 116), Color("342c35"))
		for row in range(4):
			var y: int = -68 + row * 28
			for book in range(6):
				var tint: Color = Color("575047") if (book + row) % 3 == 0 else Color("39434b")
				draw_rect(Rect2(int(x) + 4 + book * 7, y + (book % 2) * 3, 5, 20 - (book % 2) * 3), tint)
			draw_rect(Rect2(int(x), y + 22, 48, 3), Color("625144"))
	for x in [1116, 1360, 1592]:
		_draw_wall_torch(int(x), -28)
	# A low balcony rail is scenery, deliberately darker than the collision lip.
	for segment in [Rect2(1192, 28, 168, 20), Rect2(1392, 28, 184, 20)]:
		draw_rect(Rect2(segment.position.x, 28, segment.size.x, 2), Color("514c55"))
		for x in range(int(segment.position.x) + 6, int(segment.end.x), 16):
			draw_rect(Rect2(x, 30, 2, 18), Color("3c3948"))
	# The reliquary marks a bonus cluster; rewards remain actual SHARDS, not UI-only props.
	draw_rect(Rect2(1446, 32, 70, 16), Color("4c3a35"))
	draw_rect(Rect2(1446, 30, 70, 3), GOLD_LOW)
	draw_rect(Rect2(1478, 34, 4, 9), GOLD)

func _draw_climbs() -> void:
	for entry: Dictionary in CLIMBABLES:
		var rect: Rect2 = entry["rect"]
		var x: int = int(rect.get_center().x)
		draw_rect(Rect2(x - 8, rect.position.y - 8, 16, 6), STONE)
		for y in range(int(rect.position.y), int(rect.end.y), 10):
			draw_rect(Rect2(x - 3, y, 6, 7), Color("83939c"))
			draw_rect(Rect2(x - 1, y + 1, 2, 5), DARK)
			draw_rect(Rect2(x - 4, y + 6, 8, 2), Color("b8bec1"))
		for y in [int(rect.position.y) + 20, int(rect.end.y) - 22]:
			draw_rect(Rect2(x - 10, int(y), 4, 2), CYAN_LOW)
			draw_rect(Rect2(x + 6, int(y), 4, 2), CYAN_LOW)

func _draw_water() -> void:
	for region: Rect2 in WATER_REGIONS:
		draw_rect(region, Color("1f3f4d"))
		draw_rect(Rect2(region.position, Vector2(region.size.x, 1)), Color("5d8794"))
		for index in range(int(region.size.x / 28)):
			var x: float = region.position.x + 4 + index * 28 + (2 if int(_clock * 4) % 2 else 0)
			var y: float = region.position.y + 4 + (index % 3) * 3
			draw_rect(Rect2(x, y, 12, 1), Color("426d79"))

func _draw_wall_torch(x: int, y: int) -> void:
	draw_rect(Rect2(x - 7, y - 2, 14, 20), Color("31404a"))
	draw_rect(Rect2(x - 2, y + 4, 4, 12), Color("5d4e44"))
	var flicker: int = 2 if int(_clock * 5 + x) % 3 else 0
	draw_rect(Rect2(x - 4, y - 10 - flicker, 8, 14 + flicker), Color("916c4e"))
	draw_rect(Rect2(x - 2, y - 8 - flicker, 4, 10), Color("c19b66"))
	draw_rect(Rect2(x, y - 6 - flicker, 2, 6), Color("ded0a1"))

func _draw_doors() -> void:
	for entry: Dictionary in DOORS:
		var rect: Rect2 = entry["rect"]
		var opened: bool = bool(door_states.get(entry["id"], false))
		if entry["kind"] == "lever":
			var at: Vector2 = entry["at"]
			draw_rect(Rect2(at.x - 10, at.y + 12, 20, 12), STONE)
			draw_rect(Rect2(at.x - 3, at.y + 3, 6, 12), GOLD_LOW)
			draw_line(at + Vector2(0, 8), at + Vector2(9 if opened else -9, -2), GOLD, 3.0, false)
			draw_rect(Rect2(rect.position.x, rect.position.y, rect.size.x, 3), STONE)
			if not opened:
				for x in range(int(rect.position.x), int(rect.end.x), 8):
					draw_rect(Rect2(x, rect.position.y + 3, 5, 9), GOLD_LOW)
		else:
			draw_rect(Rect2(rect.position.x - 5, rect.position.y - 5, rect.size.x + 10, 5), STONE)
			if opened:
				draw_rect(Rect2(rect.position.x - 6, rect.position.y, 3, rect.size.y), GOLD_LOW)
			else:
				draw_rect(rect, Color("343a42"))
				for y in range(int(rect.position.y) + 5, int(rect.end.y), 12):
					draw_rect(Rect2(rect.position.x + 2, y, 8, 2), GOLD_LOW)
				draw_rect(Rect2(rect.position.x + 4, rect.end.y - 35, 4, 5), GOLD)

# ---------------------------------------------------------------- dark fantasy scenery (drawing only, no collision)
func _on_floor(x: float) -> bool:
	for index in range(6):
		var area: Rect2 = PLATFORMS[index]
		if x >= area.position.x + 4.0 and x <= area.end.x - 4.0:
			return true
	return false

func _draw_sky_gradient() -> void:
	# Near-black violet overhead, a bruised crimson haze toward the horizon, drawn in 20 px bands.
	for band in range(50):
		var y: int = -420 + band * 20
		var t: float = clampf((float(y) + 40.0) / 340.0, 0.0, 1.0)
		var tint: Color = SKY.lerp(HAZE, t * t) if y < 300 else SKY_LOW
		draw_rect(Rect2(-360, y, 4280, 20), tint)

func _draw_spires() -> void:
	for index in range(16):
		var x: int = index * 244 - 120
		var height: int = 120 + ((index * 53) % 90)
		var w: int = 20 + (index % 3) * 6
		var top: int = 300 - height
		draw_rect(Rect2(x, top, w, height), FAR)
		draw_rect(Rect2(x - 3, top - 4, w + 6, 4), FAR)
		draw_colored_polygon(PackedVector2Array([Vector2(x - 4, top - 4), Vector2(x + w / 2, top - 56 - (index % 2) * 18), Vector2(x + w + 4, top - 4)]), FAR)
		draw_rect(Rect2(x + w / 2 - 1, top - 74 - (index % 2) * 18, 2, 18), FAR)
		draw_rect(Rect2(x + w / 2 - 2, top + 18, 4, 10), Color("5a3a2c") if index % 4 == 0 else Color("1f1a2b"))
		# Flying buttress leaning toward the next tower.
		for step in range(6):
			draw_rect(Rect2(x + w + step * 8, top + 60 + step * 6, 10, 4), FAR)

func _draw_lancets() -> void:
	for index in range(12):
		_draw_lancet(index * 220 + 202, 132 + (index % 2) * 10, 28, 108 - (index % 2) * 10, index % 4)

func _draw_lancet(x: int, top: int, w: int, h: int, hue: int) -> void:
	var half: int = w / 2
	draw_colored_polygon(PackedVector2Array([Vector2(x - 4, top + h), Vector2(x - 4, top + half), Vector2(x + half, top - half - 6), Vector2(x + w + 4, top + half), Vector2(x + w + 4, top + h)]), MASON)
	draw_colored_polygon(PackedVector2Array([Vector2(x, top + h), Vector2(x, top + half), Vector2(x + half, top - half), Vector2(x + w, top + half), Vector2(x + w, top + h)]), Color("1a1020"))
	var rows: int = 4
	var pane: int = (h - half) / rows
	for row in range(rows):
		for col in range(2):
			var tint: Color = GLASS[(hue + row + col) % GLASS.size()]
			draw_rect(Rect2(x + 1 + col * half, top + half + row * pane + 1, half - 2, pane - 2), tint.darkened(0.3) if (row + col) % 2 else tint)
	draw_colored_polygon(PackedVector2Array([Vector2(x + 1, top + half), Vector2(x + half, top - half + 2), Vector2(x + w - 1, top + half)]), GLASS[hue % GLASS.size()].darkened(0.15))
	draw_rect(Rect2(x + half - 1, top - half + 2, 2, h + half - 2), Color("241c2c"))
	draw_rect(Rect2(x - 6, top + h, w + 12, 4), STONE)

func _draw_graveyard() -> void:
	for index in range(TREE_XS.size()):
		if _on_floor(float(TREE_XS[index])):
			_draw_dead_tree(TREE_XS[index], index)
	for index in range(TOMB_XS.size()):
		var x: int = TOMB_XS[index]
		if not _on_floor(float(x)) or absi(x - 1860) < 60 or absi(x - 2640) < 70 or absi(x - 3380) < 70 or (x > 2700 and x < 3160):
			continue
		_draw_tombstone(x, index)
	for fence: Vector2 in FENCES:
		draw_rect(Rect2(fence.x, 280, fence.y - fence.x, 2), Color("1a1622"))
		draw_rect(Rect2(fence.x, 290, fence.y - fence.x, 2), Color("1a1622"))
		for x in range(int(fence.x), int(fence.y), 10):
			draw_rect(Rect2(x, 274, 2, 26), Color("1a1622"))
			draw_rect(Rect2(x - 1, 270, 4, 4), Color("1a1622"))

func _draw_dead_tree(x: int, variant: int) -> void:
	var ink: Color = Color("0c0912")
	var h: int = 64 + (variant % 4) * 12
	var base: int = 300
	draw_rect(Rect2(x - 3, base - h, 6, h), ink)
	draw_rect(Rect2(x - 6, base - 10, 12, 10), ink)
	draw_rect(Rect2(x - 8, base - h - 6, 3, 10), ink)
	draw_rect(Rect2(x + 5, base - h - 10, 3, 14), ink)
	draw_rect(Rect2(x - 1, base - h - 14, 3, 14), ink)
	for side in [-1, 1]:
		var by: int = base - h + 16 + (variant % 3) * 6
		for step in range(5):
			var px: int = x + side * (2 + step * 4)
			draw_rect(Rect2(px if side > 0 else px - 4, by - step * 5, 5, 3), ink)
		draw_rect(Rect2(x + side * 22 - (0 if side > 0 else 2), by - 30, 2, 9), ink)
	if variant % 3 == 0:
		# A crow keeps watch on the right bough.
		var cx: int = x + 14
		var cy: int = base - h + 16 + (variant % 3) * 6 - 14
		draw_rect(Rect2(cx, cy - 5, 7, 5), ink)
		draw_rect(Rect2(cx + 7, cy - 6, 3, 3), ink)
		draw_rect(Rect2(cx + 10, cy - 5, 3, 1), ink)
		draw_rect(Rect2(cx + 8, cy - 5, 1, 1), Color("b04050"))

func _draw_tombstone(x: int, variant: int) -> void:
	match variant % 3:
		0:
			draw_rect(Rect2(x, 278, 14, 22), MASON)
			draw_rect(Rect2(x + 2, 276, 10, 2), MASON)
			draw_rect(Rect2(x, 278, 2, 22), STONE)
			draw_rect(Rect2(x + 6, 282, 2, 9), DARK)
			draw_rect(Rect2(x + 3, 285, 8, 2), DARK)
		1:
			draw_rect(Rect2(x + 5, 270, 4, 30), MASON)
			draw_rect(Rect2(x, 276, 14, 4), MASON)
			draw_rect(Rect2(x + 5, 270, 1, 30), STONE)
			draw_rect(Rect2(x - 2, 297, 18, 3), MID)
		_:
			draw_rect(Rect2(x, 286, 16, 14), MASON)
			draw_rect(Rect2(x + 4, 282, 8, 4), MASON)
			draw_rect(Rect2(x + 10, 296, 10, 4), MID)
			draw_rect(Rect2(x, 286, 2, 14), STONE)

func _draw_gargoyles() -> void:
	for entry: Vector3 in GARGOYLES:
		_draw_gargoyle(Vector2(entry.x, entry.y), int(entry.z))

func _draw_gargoyle(at: Vector2, flip: int) -> void:
	var ink: Color = Color("171220")
	draw_rect(Rect2(at.x - 7, at.y - 4, 14, 4), ink)
	draw_rect(Rect2(at.x - 4 + flip * 2, at.y - 14, 8, 10), ink)
	draw_rect(Rect2(at.x - 3 + flip * 5, at.y - 20, 7, 7), ink)
	draw_rect(Rect2(at.x + flip * 7, at.y - 22, 2, 4), ink)
	draw_colored_polygon(PackedVector2Array([Vector2(at.x - flip * 3, at.y - 14), Vector2(at.x - flip * 15, at.y - 30), Vector2(at.x - flip * 10, at.y - 10)]), ink)
	if int(_clock * 2.0 + at.x) % 5 != 0:
		draw_rect(Rect2(at.x + flip * 5 + (0 if flip > 0 else 1), at.y - 18, 2, 2), Color("d03a48"))

func _draw_hanging_cages() -> void:
	for entry: Vector2 in CAGES:
		var x: int = int(entry.x)
		var length: int = int(entry.y)
		for y in range(324, 324 + length, 6):
			draw_rect(Rect2(x, y, 2, 4), MID)
		var cy: int = 324 + length
		draw_rect(Rect2(x - 8, cy, 18, 3), Color("2c2a34"))
		draw_rect(Rect2(x - 8, cy + 24, 18, 3), Color("2c2a34"))
		for bar in range(5):
			draw_rect(Rect2(x - 7 + bar * 4, cy + 3, 1, 21), Color("3a3844"))
		draw_rect(Rect2(x - 3, cy + 14, 6, 6), BONE)
		draw_rect(Rect2(x - 2, cy + 16, 1, 2), DARK)
		draw_rect(Rect2(x + 1, cy + 16, 1, 2), DARK)

func _draw_ground_details() -> void:
	for index in range(110):
		var x: int = -70 + index * 33 + (index * 17) % 13
		if not _on_floor(float(x)):
			continue
		var tint: Color = Color("2d2438") if index % 5 else Color("4a2638")
		draw_rect(Rect2(x, 295, 1, 5), tint)
		draw_rect(Rect2(x + 2, 292 - index % 3, 1, 8 + index % 3), tint)
		draw_rect(Rect2(x + 4, 296, 1, 4), tint)
		if index % 9 == 4:
			draw_rect(Rect2(x + 8, 294, 6, 6), BONE)
			draw_rect(Rect2(x + 9, 296, 1, 2), DARK)
			draw_rect(Rect2(x + 12, 296, 1, 2), DARK)
			draw_rect(Rect2(x + 9, 299, 4, 1), DARK)
			draw_rect(Rect2(x + 16, 298, 8, 2), BONE)
		if index % 13 == 6:
			draw_rect(Rect2(x, 300, 14, 2), BLOOD)
			draw_rect(Rect2(x + 3, 302, 8, 1), Color("4a1220"))


## Room data is distinct from the legacy authoring constants: the old shard
## indices remain stable, while only dungeon-owned geometry enters this tree.
func get_room_spec() -> Dictionary:
	var platforms: Array[Rect2] = []
	for authored: Rect2 in PLATFORMS:
		if authored.position.x >= 2640.0:
			continue
		var clipped: Rect2 = authored
		if clipped.end.x > ROOM_END_WALL.position.x:
			clipped.size.x = ROOM_END_WALL.position.x - clipped.position.x
		if clipped.size.x > 0.0:
			platforms.append(clipped)
	platforms.append(ROOM_END_WALL)
	var indices: Array[int] = []
	for index in range(SHARDS.size()):
		if index != 11:
			indices.append(index)
	return {"id": ROOM_ID, "title": "THE WAKING NAVE", "bounds": Rect2(-40, -160, 2700, 860), "spawn": SPAWN, "checkpoint": CHECKPOINT, "boss_spawn": Vector2.ZERO, "portal_at": PORTAL_POSITION, "fall_limit": FALL_LIMIT, "platforms": platforms, "shard_indices": indices}

func portal_at(feet: Vector2) -> Dictionary:
	if not _contains_closed(PORTAL_RECT, feet):
		return {}
	return {"id": "belfry_portal", "target": "boss", "at": PORTAL_POSITION, "rect": PORTAL_RECT, "requires": "elite"}

func _draw_room_portal() -> void:
	# A freestanding stone doorway, with an opaque threshold: this is a room
	# transition marker, not a view into the encounter in the dungeon's tree.
	_draw_arch(2514, 164, 92, 136, MASON)
	draw_rect(Rect2(2528, 192, 64, 108), DARK)
	for x in [2530, 2586]:
		draw_rect(Rect2(x, 198, 4, 96), GOLD_LOW)
		draw_rect(Rect2(x + 1, 202, 2, 88), GOLD)
	var pulse: int = 2 if int(_clock * 4) % 2 == 0 else 0
	_draw_diamond(Vector2(2560, 230 - pulse), 10, GOLD_LOW)
	_draw_diamond(Vector2(2560, 230 - pulse), 4, BONE)
	draw_rect(Rect2(2522, 296, 76, 4), LIP)

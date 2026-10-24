extends Node2D
## Authored 2D route; all visible forms are original integer-grid pixel primitives.
## Final texture replacements may be supplied by Cursor without changing collision data.

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
var door_states: Dictionary = {}
var _door_bodies: Dictionary = {}

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
	_build_doors()
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
	_draw_dungeon_background()
	_draw_archive()
	for area in PLATFORMS:
		_draw_platform(area)
	_draw_broken_chains()
	_draw_shrine()
	_draw_wayfinding()
	_draw_gate(2640, 300, false)
	_draw_gate(3380, 300, true)
	_draw_climbs()
	_draw_water()
	_draw_doors()

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
	draw_rect(Rect2(400, 324, 1450, 276), Color("111a25"))
	for row in range(11):
		var y: int = 326 + row * 16
		var offset: int = 16 if row % 2 else 0
		for column in range(46):
			var x: int = 400 + column * 32 - offset
			draw_rect(Rect2(x, y, 31, 15), Color("1c2935") if (row + column) % 5 else Color("223440"))
	for x in [466, 728, 1008, 1270, 1552, 1784]:
		_draw_arch(float(x), 348.0, 108.0, 152.0, Color("293b46"))
		draw_rect(Rect2(int(x) + 14, 390, 80, 110), Color("16212e"))
		for bar in range(4):
			draw_rect(Rect2(int(x) + 24 + bar * 16, 382, 2, 116), Color("263540"))
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
		draw_rect(Rect2(x, 480 + index % 3 * 4, 16, 12), Color("26313b"))
		draw_rect(Rect2(x + 12, 488, 12, 12), Color("1b2733"))

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
		draw_rect(region, Color("2b5361"))
		draw_rect(Rect2(region.position, Vector2(region.size.x, 1)), Color("668c96"))
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

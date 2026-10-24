extends RefCounted
## One geometry source for accepted melee queries, the main sword arc and pose art.
const DATA_PATH: String = "res://data/hero_attack_profiles.json"
static var _data: Dictionary = {}
## The sword in hand. Light is the base table; heavy and great override it per combo step.
static var weapon: String = "light"
static var _merged: Dictionary = {}

static func data() -> Dictionary:
	if _data.is_empty():
		var file: FileAccess = FileAccess.open(DATA_PATH, FileAccess.READ)
		if file != null:
			var value: Variant = JSON.parse_string(file.get_as_text())
			if value is Dictionary:
				_data = value
	return _data

static func weapon_ids() -> Array[String]:
	var ids: Array[String] = []
	for key: Variant in data().get("weapons", {}):
		ids.append(str(key))
	if ids.is_empty():
		ids.append("light")
	return ids

static func set_weapon(id: String) -> bool:
	if not weapon_ids().has(id):
		return false
	weapon = id
	return true

static func weapon_info(id: String = "") -> Dictionary:
	var table: Dictionary = data().get("weapons", {})
	var value: Variant = table.get(weapon if id == "" else id, {})
	return value if value is Dictionary else {}

static func profile(combo: int, id: String = "") -> Dictionary:
	var key: String = str(clampi(combo, 1, 3))
	var wid: String = weapon if id == "" else id
	var cache_key: String = wid + ":" + key
	if not _merged.has(cache_key):
		var table: Dictionary = data().get("combos", {})
		var base: Variant = table.get(key, {})
		var out: Dictionary = base.duplicate(true) if base is Dictionary else {}
		var over: Variant = weapon_info(wid).get("combos", {})
		if over is Dictionary and over.get(key) is Dictionary:
			for field: Variant in over[key]:
				out[field] = over[key][field]
		var damage: Variant = weapon_info(wid).get("damage")
		if not out.has("damage"):
			out["damage"] = int(damage[clampi(combo, 1, 3) - 1]) if damage is Array and damage.size() >= 3 else (2 if combo == 3 else 1)
		_merged[cache_key] = out
	return _merged[cache_key].duplicate(true)

static func damage(combo: int) -> int:
	return maxi(1, int(profile(combo).get("damage", 1)))

static func lunge_speed(combo: int) -> float:
	return float(profile(combo).get("lunge_speed", 130.0))

static func lunge_seconds(combo: int) -> float:
	return float(profile(combo).get("lunge_seconds", 0.085))

static func origin() -> Vector2:
	var value: Array = data().get("origin", [0.0, -24.0])
	return Vector2(float(value[0]), float(value[1]))

static func contact_start() -> float:
	return clampf(float(data().get("contact_start", 0.25)), 0.0, 1.0)

static func radii(combo: int, id: String = "") -> Vector2:
	var value: Array = profile(combo, id).get("radii", [180.0, 72.0])
	return Vector2(float(value[0]), float(value[1]))

static func duration(combo: int, phase: String) -> float:
	var times: Dictionary = profile(combo).get("phase_seconds", {})
	return maxf(0.001, float(times.get(phase, 0.1)))

static func total_duration(combo: int) -> float:
	return duration(combo, "windup") + duration(combo, "active") + duration(combo, "recover")

static func angle_at(combo: int, progress: float, id: String = "") -> float:
	var keys: Array = profile(combo, id).get("angle_keys", [[0.0, 0.0], [1.0, 0.0]])
	var t: float = clampf(progress, 0.0, 1.0)
	for index: int in range(1, keys.size()):
		var left: Array = keys[index - 1]
		var right: Array = keys[index]
		if t <= float(right[0]):
			var fraction: float = clampf((t - float(left[0])) / maxf(0.000001, float(right[0]) - float(left[0])), 0.0, 1.0)
			return lerpf(float(left[1]), float(right[1]), fraction)
	return float(keys[keys.size() - 1][1])

static func kind(combo: int, id: String = "") -> String:
	return str(profile(combo, id).get("kind", "arc"))

static func _key_value(keys: Array, progress: float, fallback: float = 1.0) -> float:
	if keys.is_empty(): return fallback
	var t: float = clampf(progress, 0.0, 1.0)
	for index: int in range(1, keys.size()):
		var left: Array = keys[index - 1]
		var right: Array = keys[index]
		if t <= float(right[0]):
			return lerpf(float(left[1]), float(right[1]), clampf((t-float(left[0])) / maxf(0.000001,float(right[0])-float(left[0])),0.0,1.0))
	return float(keys.back()[1])

static func leading_edge(combo: int, progress: float, id: String = "") -> Vector2:
	var angle: float = deg_to_rad(angle_at(combo, progress, id))
	var size: Vector2 = radii(combo, id)
	if kind(combo, id) == "thrust":
		return origin() + Vector2.from_angle(angle) * size.x * _key_value(profile(combo,id).get("thrust_keys", []), progress)
	return origin() + Vector2(cos(angle) * size.x, sin(angle) * size.y)

static func sprite_tip(combo: int, progress: float) -> Vector2:
	return origin() + (leading_edge(combo, progress) - origin()) * float(profile(combo).get("sprite_tip_ratio", 0.26))

static func sweep_polygon(combo: int, from_progress: float, to_progress: float, id: String = "") -> PackedVector2Array:
	# Geometry follows the whole elapsed phase interval, never the current pose only.
	if maxf(from_progress, to_progress) < contact_start(): return PackedVector2Array()
	var first: float = clampf(minf(from_progress, to_progress), contact_start(), 1.0)
	var last: float = clampf(maxf(from_progress, to_progress), contact_start(), 1.0)
	var item: Dictionary = profile(combo, id)
	var mode: String = kind(combo, id)
	var size: Vector2 = radii(combo, id)
	if mode == "thrust":
		var points := PackedVector2Array()
		var samples: Array[float] = [first, last]
		for key: Array in item.get("thrust_keys", []):
			if float(key[0]) > first and float(key[0]) < last: samples.append(float(key[0]))
		for t: float in samples:
			var tip: Vector2 = leading_edge(combo,t,id)
			var unit: Vector2 = Vector2.from_angle(deg_to_rad(angle_at(combo,t,id)))
			var normal: Vector2 = unit.orthogonal()
			points.append(origin() + normal * size.y * 0.35)
			points.append(tip - unit * 12.0 + normal * size.y)
			points.append(tip)
			points.append(tip - unit * 12.0 - normal * size.y)
			points.append(origin() - normal * size.y * 0.35)
		return Geometry2D.convex_hull(points)
	var low: float = minf(angle_at(combo,first,id),angle_at(combo,last,id))
	var high: float = maxf(angle_at(combo,first,id),angle_at(combo,last,id))
	for key: Array in item.get("angle_keys", []):
		if float(key[0]) >= first and float(key[0]) <= last:
			low = minf(low,float(key[1])); high = maxf(high,float(key[1]))
	var half_span: float = float(item.get("blade_span_degrees",28.0)) * 0.5
	low -= half_span; high += half_span
	if mode != "spin":
		low = clampf(low,-88.0,88.0); high = clampf(high,-88.0,88.0)
	var full_circle: bool = high-low >= 360.0
	if full_circle: high = low + 360.0
	var count: int = maxi(1,int(ceil((high-low)/maxf(0.5,float(data().get("arc_step_degrees",3.0))))))
	var angles: Array[float] = []
	for index: int in range(count + (0 if full_circle else 1)):
		angles.append(lerpf(low,high,float(index)/count))
	# Axial extrema must be present exactly (not only a near-angle sample).
	for degrees: float in [-360.0,-270.0,-180.0,-90.0,0.0,90.0,180.0,270.0,360.0]:
		if degrees > low and degrees < high: angles.append(degrees)
	angles.sort()
	var points := PackedVector2Array() if full_circle else PackedVector2Array([origin()])
	var previous_angle: float = INF
	for degrees: float in angles:
		if is_equal_approx(degrees,previous_angle): continue
		previous_angle = degrees
		var angle: float = deg_to_rad(degrees)
		points.append(origin()+Vector2(cos(angle)*size.x,sin(angle)*size.y))
	return points

static func world_polygon(source: Node2D, from_progress: float, to_progress: float) -> PackedVector2Array:
	var value: Variant = source.get("combo")
	var combo: int = int(value) if value != null else 1
	var wid_value: Variant = source.get("weapon")
	var wid: String = str(wid_value) if wid_value != null else ""
	var direction: Variant = source.get("facing")
	var facing: float = -1.0 if direction != null and float(direction)<0.0 else 1.0
	var points: PackedVector2Array = sweep_polygon(combo,from_progress,to_progress,wid)
	for index: int in points.size():
		points[index] = source.global_position+Vector2(points[index].x*facing,points[index].y)
	return points

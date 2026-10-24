extends RefCounted
## Real pixel-steel landmarks only. Boss owns active windows, tokens and world occlusion.
const MANIFEST_PATH: String = "res://presentation/katana_frames/manifest.json"
const EPSILON: float = 0.00001
static var _manifest: Dictionary = {}

static func reload_manifest() -> bool:
    _manifest.clear()
    var file: FileAccess = FileAccess.open(MANIFEST_PATH, FileAccess.READ)
    if file == null: return false
    var parsed: Variant = JSON.parse_string(file.get_as_text())
    if not parsed is Dictionary: return false
    _manifest = parsed
    return _manifest.get("states") is Dictionary

static func data() -> Dictionary:
    if _manifest.is_empty(): reload_manifest()
    return _manifest

static func frame_index(clip: String, progress: float) -> int:
    var state: Dictionary = data().get("states", {}).get(clip, {})
    var count: int = int(state.get("count", 0))
    if count <= 0: return -1
    var p: float = clampf(progress, 0.0, 1.0) if is_finite(progress) else 0.0
    # Match KatanaVisual's existing early collapse/hold presentation.
    if clip == "guard_break": p = minf(1.0, p * 4.0)
    return clampi(int(p * count), 0, count - 1)

static func blade_pose(clip: String, progress: float, facing: int) -> Dictionary:
    var states: Dictionary = data().get("states", {})
    var fallback: bool = not states.has(clip)
    var resolved: String = "idle" if fallback else clip
    var index: int = frame_index(resolved, progress)
    var frames: Array = states.get(resolved, {}).get("frames", [])
    var record: Dictionary = frames[index] if index >= 0 and index < frames.size() else {}
    var root: Vector2 = _landmark(record.get("guard"))
    var tip: Vector2 = _landmark(record.get("weapon_tip"))
    var mirror: int = -1 if facing < 0 else 1
    var anchor_value: Array = data().get("anchor", [0.0, 0.0])
    var anchor: Vector2 = Vector2(float(anchor_value[0]), float(anchor_value[1]))
    var valid: bool = not fallback and index >= 0 and root.is_finite() and tip.is_finite()
    if not root.is_finite(): root = Vector2.ZERO
    if not tip.is_finite(): tip = Vector2.ZERO
    # Manifest coordinates already subtract the sprite anchor. Do not subtract it twice.
    root.x *= mirror
    tip.x *= mirror
    var hint: bool = valid and record.get("hit_window", false) == true
    return {"root": root, "tip": tip, "frame": index, "clip": resolved, "requested_clip": clip, "progress": clampf(progress, 0.0, 1.0) if is_finite(progress) else 0.0, "facing": mirror, "valid": valid, "fallback": fallback, "anchor": anchor, "hit_window": hint, "active_hint": hint}

static func active_window(clip: String) -> Vector2:
    # Descriptive manifest hint, not gameplay authority. End is exclusive unless 1.
    var frames: Array = data().get("states", {}).get(clip, {}).get("frames", [])
    var first: int = -1
    var last: int = -1
    for index: int in frames.size():
        if frames[index].get("hit_window", false) == true:
            if first < 0: first = index
            last = index
    if first < 0: return Vector2(-1.0, -1.0)
    return Vector2(float(first) / frames.size(), float(last + 1) / frames.size())

static func _landmark(value: Variant) -> Vector2:
    if not value is Array or value.size() < 2: return Vector2.INF
    if not (value[0] is float or value[0] is int) or not (value[1] is float or value[1] is int): return Vector2.INF
    return Vector2(float(value[0]), float(value[1]))

static func swept_pose_touch(previous: Dictionary, current: Dictionary, previous_origin: Vector2, current_origin: Vector2, target_rect: Rect2, thickness: float = 3.0) -> bool:
    if previous.get("valid", false) != true or current.get("valid", false) != true: return false
    return swept_touch(previous_origin + previous["root"], previous_origin + previous["tip"], current_origin + current["root"], current_origin + current["tip"], target_rect, thickness)

static func swept_touch(previous_root: Vector2, previous_tip: Vector2, current_root: Vector2, current_tip: Vector2, target_rect: Rect2, thickness: float = 3.0) -> bool:
    if not previous_root.is_finite() or not previous_tip.is_finite() or not current_root.is_finite() or not current_tip.is_finite() or not target_rect.position.is_finite() or not target_rect.size.is_finite() or not is_finite(thickness): return false
    # Square pixel cross-section, at most half the requested blade width per axis.
    # This is not the bounding box of the sweep: exact moving-segment tests follow.
    var target: Rect2 = target_rect.abs().grow(maxf(0.0, thickness) * 0.5)
    if _segment_rect(previous_root, previous_tip, target) or _segment_rect(current_root, current_tip, target) or _segment_rect(previous_root, current_root, target) or _segment_rect(previous_tip, current_tip, target): return true
    for corner: Vector2 in [target.position, Vector2(target.end.x, target.position.y), target.end, Vector2(target.position.x, target.end.y)]:
        if _moving_segment_contains(corner, previous_root, previous_tip, current_root, current_tip): return true
    return false

static func _segment_rect(a: Vector2, b: Vector2, target: Rect2) -> bool:
    var first: float = 0.0
    var last: float = 1.0
    var motion: Vector2 = b - a
    for axis: int in 2:
        if absf(motion[axis]) <= EPSILON:
            if a[axis] < target.position[axis] - EPSILON or a[axis] > target.end[axis] + EPSILON: return false
        else:
            var left: float = (target.position[axis] - a[axis]) / motion[axis]
            var right: float = (target.end[axis] - a[axis]) / motion[axis]
            first = maxf(first, minf(left, right))
            last = minf(last, maxf(left, right))
            if first > last + EPSILON: return false
    return true

static func _moving_segment_contains(point: Vector2, r0: Vector2, t0: Vector2, r1: Vector2, t1: Vector2) -> bool:
    var velocity: Vector2 = r1 - r0
    var blade: Vector2 = t0 - r0
    var blade_change: Vector2 = (t1 - r1) - blade
    var offset: Vector2 = point - r0
    var a: float = -velocity.cross(blade_change)
    var b: float = offset.cross(blade_change) - velocity.cross(blade)
    var c: float = offset.cross(blade)
    var roots: Array[float] = []
    if absf(a) <= EPSILON:
        if absf(b) > EPSILON: roots.append(-c / b)
    else:
        var discriminant: float = b * b - 4.0 * a * c
        if discriminant >= -EPSILON:
            var square_root: float = sqrt(maxf(0.0, discriminant))
            roots.append((-b - square_root) / (2.0 * a))
            roots.append((-b + square_root) / (2.0 * a))
    for time: float in roots:
        if time < -EPSILON or time > 1.0 + EPSILON: continue
        var p: float = clampf(time, 0.0, 1.0)
        var root: Vector2 = r0.lerp(r1, p)
        var edge: Vector2 = t0.lerp(t1, p) - root
        if edge.length_squared() <= EPSILON * EPSILON:
            if point.distance_squared_to(root) <= EPSILON * EPSILON: return true
        else:
            var along: float = (point - root).dot(edge) / edge.length_squared()
            if along >= -EPSILON and along <= 1.0 + EPSILON: return true
    return false

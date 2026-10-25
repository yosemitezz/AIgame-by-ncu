extends Node2D
## Main-game carrier for MIT friend line/cube geometry. No independent clock.
## Rendering and damage use the same clipped records; main owns safety and caps.
var game: Node
var source: WeakRef
var source_generation: int = -1
var kind: String = ""
var lines: Array[Dictionary] = []
var cube: Dictionary = {}
var arena_rect: Rect2
var clock_time: float = 0.0
var _cleared: bool = false
var _hits: Dictionary = {}
## Beams visibly run through the arena walls, so their clipped draw length is
## intentionally longer than the playable rectangle. Damage still only matters
## where the player can stand.
const BEAM_OVERSCAN: float = 260.0
var _first_warning: float = INF
var _first_damage: float = INF
var _warn_fx_done: bool = false
var _fire_fx_done: bool = false
var _track_window: float = 0.0
var _created_at: float = 0.0
var _clusters: Array[Dictionary] = []

func configure_lines(p_game: Node, owner_boss: Node, records: Array[Dictionary], arena: Rect2, version: int, formation_kind: String = "laser", half_beat_seconds: float = 0.0) -> void:
    game = p_game
    source = weakref(owner_boss)
    source_generation = version
    arena_rect = arena
    kind = formation_kind
    var clip_bounds: Rect2 = arena.grow(BEAM_OVERSCAN)
    for record: Dictionary in records:
        var line: Dictionary = record.duplicate(true)
        var segment: Array[Vector2] = clipped_line(line["origin"], float(line["angle_radians"]), clip_bounds)
        if segment.size() != 2:
            continue
        line["a"] = segment[0].round()
        line["b"] = segment[1].round()
        _first_warning = minf(_first_warning, float(line["warning_time"]))
        _first_damage = minf(_first_damage, float(line["damage_time"]))
        lines.append(line)
    _track_window = maxf(0.0, half_beat_seconds)
    var music_node: Variant = game.get("music") if is_instance_valid(game) else null
    _created_at = float(music_node.get_score_time()) if is_instance_valid(music_node) else 0.0
    clock_time = _created_at
    _build_clusters()

func configure_cube(p_game: Node, owner_boss: Node, plan: Dictionary, arena: Rect2, version: int) -> void:
    cube = plan.duplicate(true)
    cube["orientation"] = "diamond_plus" if bool(cube["diamond"]) else "square_x"
    cube["orientation_degrees"] = 45.0 if bool(cube["diamond"]) else 0.0
    var records: Array[Dictionary] = []
    var angles: Array = [0.0, 90.0] if bool(cube["diamond"]) else [45.0, 135.0]
    for angle: float in angles:
        records.append({"origin": cube["to"], "angle_radians": deg_to_rad(angle), "thickness": float(cube["thickness"]), "warning_time": float(cube["flight_end_time"]), "damage_time": float(cube["damage_time"]), "active_until": float(cube["active_until"])})
    configure_lines(p_game, owner_boss, records, arena, version, "cube_plus" if bool(cube["diamond"]) else "cube_x")

func _build_clusters() -> void:
    _clusters.clear()
    if _track_window <= 0.0:
        return
    var order: Array[int] = []
    for index: int in lines.size():
        if typeof(lines[index].get("center_offset")) == TYPE_VECTOR2:
            order.append(index)
    if order.is_empty():
        return
    order.sort_custom(func(left: int, right: int) -> bool: return float(lines[left]["damage_time"]) < float(lines[right]["damage_time"]))
    var cluster: Dictionary = {}
    var anchor: float = 0.0
    for index: int in order:
        var damage: float = float(lines[index]["damage_time"])
        if cluster.is_empty() or damage - anchor > _track_window:
            if not cluster.is_empty():
                _finish_cluster(cluster)
                _clusters.append(cluster)
            cluster = {"indices": [], "warning": float(lines[index]["warning_time"])}
            anchor = damage
        var indices: Array = cluster["indices"]
        indices.append(index)
        cluster["warning"] = minf(float(cluster["warning"]), float(lines[index]["warning_time"]))
    if not cluster.is_empty():
        _finish_cluster(cluster)
        _clusters.append(cluster)

func _finish_cluster(cluster: Dictionary) -> void:
    var warning: float = float(cluster["warning"])
    cluster["aim_at"] = maxf(warning, _created_at)
    cluster["aimed"] = warning <= _created_at + 0.000001

func _aim_due_clusters(owner_boss: Node, now: float) -> void:
    for cluster: Dictionary in _clusters:
        if bool(cluster["aimed"]) or now + 0.000001 < float(cluster["aim_at"]):
            continue
        var arena: Rect2 = arena_rect
        if is_instance_valid(owner_boss) and owner_boss.has_method("get_laser_arena"):
            arena = owner_boss.get_laser_arena()
        var center: Vector2 = arena.get_center()
        var bounds: Rect2 = arena.grow(BEAM_OVERSCAN)
        var indices: Array = cluster["indices"]
        for index: int in indices:
            var line: Dictionary = lines[index]
            var offset: Vector2 = line["center_offset"]
            var origin: Vector2 = center + offset
            var segment: Array[Vector2] = clipped_line(origin, float(line["angle_radians"]), bounds)
            if segment.size() != 2:
                continue
            line["origin"] = origin
            line["a"] = segment[0].round()
            line["b"] = segment[1].round()
        arena_rect = arena
        cluster["aimed"] = true

func _ready() -> void:
    add_to_group("boss_hazards")
    texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    z_index = 4

func clear() -> void:
    if _cleared:
        return
    _cleared = true
    remove_from_group("boss_hazards")
    queue_free()

func get_geometry_snapshot() -> Dictionary:
    return {"kind": kind, "lines": lines.duplicate(true), "cube": cube.duplicate(true), "generation": source_generation, "clock": clock_time, "tracking": {"window": _track_window, "clusters": _clusters.size(), "aimed": _aimed_count()}}

func _aimed_count() -> int:
    var count: int = 0
    for cluster: Dictionary in _clusters:
        if bool(cluster["aimed"]):
            count += 1
    return count

func _physics_process(_delta: float) -> void:
    if _cleared:
        return
    var owner_boss: Node = source.get_ref() if source != null else null
    if not is_instance_valid(game) or not is_instance_valid(owner_boss):
        clear()
        return
    if bool(game.story_safe) or bool(owner_boss.dead) or int(owner_boss.hazard_generation) != source_generation:
        clear()
        return
    if get_tree().paused or game.get("_paused") == true:
        return
    if game.get("outcome") != null and str(game.get("outcome")) != "":
        clear()
        return
    if not is_instance_valid(game.player) or bool(game.player.dead):
        clear()
        return
    clock_time = float(game.music.get_score_time())
    _aim_due_clusters(owner_boss, clock_time)
    _trigger_sfx()
    var last_active: float = -INF
    for index: int in lines.size():
        var line: Dictionary = lines[index]
        last_active = maxf(last_active, float(line["active_until"]))
        if clock_time < float(line["damage_time"]) or clock_time > float(line["active_until"]) or _hits.has(index):
            continue
        if line_hits_player(game.player.global_position, line):
            var hp_before: int = int(game.player.health)
            game.damage_player(1, line["origin"])
            if int(game.player.health) < hp_before:
                _hits[index] = true
    if clock_time > last_active + 0.15:
        clear()
        return
    queue_redraw()

static func clipped_line(origin: Vector2, angle: float, bounds: Rect2) -> Array[Vector2]:
    var direction: Vector2 = Vector2.from_angle(angle)
    var low: float = -INF
    var high: float = INF
    for axis: int in 2:
        var component: float = direction[axis]
        if absf(component) < 0.000001:
            if origin[axis] < bounds.position[axis] or origin[axis] > bounds.end[axis]:
                return []
            continue
        var a: float = (bounds.position[axis] - origin[axis]) / component
        var b: float = (bounds.end[axis] - origin[axis]) / component
        low = maxf(low, minf(a, b))
        high = minf(high, maxf(a, b))
    if low > high:
        return []
    return [origin + direction * low, origin + direction * high]

static func line_hits_player(feet: Vector2, line: Dictionary) -> bool:
    # Main player's actual 14x26 body, feet origin. Projectile/parry collision
    # remains in the existing controller; coral line hazards are not reflectable.
    var a: Vector2 = line["a"]
    var b: Vector2 = line["b"]
    var axis: Vector2 = (b - a).normalized()
    var normal: Vector2 = Vector2(-axis.y, axis.x)
    var center: Vector2 = feet + Vector2(0.0, -13.0)
    var offset: Vector2 = center - a
    var body_normal: float = absf(normal.x) * 7.0 + absf(normal.y) * 13.0
    var body_axis: float = absf(axis.x) * 7.0 + absf(axis.y) * 13.0
    return absf(offset.dot(normal)) <= float(line.get("thickness", 9.0)) * 0.5 + body_normal and offset.dot(axis) >= -body_axis and offset.dot(axis) <= a.distance_to(b) + body_axis

func _trigger_sfx() -> void:
    if _cleared or not is_instance_valid(game) or bool(game.get("story_safe")):
        return
    if not _warn_fx_done and clock_time >= _first_warning - 0.001:
        _warn_fx_done = true
        # A hazard restored mid-flight has nothing left to warn about.
        if clock_time < _first_damage - 0.02:
            _play_event("laser_warn", _first_point("origin"), _first_direction(), 1.0)
    if not _fire_fx_done and clock_time >= _first_damage - 0.001:
        _fire_fx_done = true
        _play_event("laser_fire", _first_midpoint(), _first_normal(), 1.4)

func _play_event(event_kind: String, at: Vector2, direction: Vector2, power: float) -> void:
    if is_instance_valid(game) and game.has_method("emit_fx"):
        game.emit_fx(event_kind, at, direction, power)

func _first_line() -> Dictionary:
    return lines[0] if not lines.is_empty() else {}

func _first_point(key: String) -> Vector2:
    var line: Dictionary = _first_line()
    return line[key] if line.has(key) else arena_rect.get_center()

func _first_midpoint() -> Vector2:
    var line: Dictionary = _first_line()
    if line.is_empty():
        return arena_rect.get_center()
    return (line["a"] as Vector2).lerp(line["b"], 0.5)

func _first_direction() -> Vector2:
    var line: Dictionary = _first_line()
    return Vector2.from_angle(float(line["angle_radians"])) if line.has("angle_radians") else Vector2.DOWN

func _first_normal() -> Vector2:
    var axis: Vector2 = _first_direction()
    return Vector2(-axis.y, axis.x)

func _draw() -> void:
    if _cleared:
        return
    for index: int in lines.size():
        var line: Dictionary = lines[index]
        var warning: float = float(line["warning_time"])
        var damage: float = float(line["damage_time"])
        var end: float = float(line["active_until"])
        if clock_time < warning or clock_time > end:
            continue
        var a: Vector2 = line["a"]
        var b: Vector2 = line["b"]
        var width: float = float(line.get("thickness", 9.0))
        var axis: Vector2 = (b - a).normalized()
        var normal: Vector2 = Vector2(-axis.y, axis.x)
        var span: float = a.distance_to(b)
        var pulse: float = 0.5 + 0.5 * sin(clock_time * 20.0 + float(index) * 1.9)
        if clock_time < damage:
            # Warning lane: dark rail, coral edge and travelling charge beads.
            var warn_w: float = maxf(10.0, width * 1.2)
            draw_line(a, b, Color(0.10, 0.04, 0.10, 0.5), warn_w * 3.4, false)
            draw_line(a, b, Color("633b59"), warn_w, false)
            draw_line(a, b, Color(1.0, 0.588, 0.498, 0.5 + 0.45 * pulse), maxf(2.0, warn_w * 0.18), false)
            var travel: float = fposmod(clock_time * 240.0, 78.0)
            while travel < span:
                var bead_point: Vector2 = (a + axis * travel).round()
                var bead: float = 2.0 + 1.6 * pulse
                draw_rect(Rect2(bead_point - Vector2(bead, bead), Vector2(bead, bead) * 2.0), Color(1.0, 0.835, 0.631, 0.9))
                draw_rect(Rect2(bead_point - Vector2(1, 1), Vector2(2, 2)), Color(1, 1, 1, 0.95))
                travel += 78.0
            var progress: float = clampf((clock_time - warning) / maxf(0.001, damage - warning), 0.0, 1.0)
            var marker: Vector2 = a.lerp(b, progress).round()
            draw_rect(Rect2(marker - Vector2(3, 3), Vector2(6, 6)), Color("ffd5a1"))
            draw_rect(Rect2(marker - Vector2(1, 1), Vector2(2, 2)), Color(1, 1, 1, 0.9))
        else:
            # Fired pillar: wide halo, saturated body, white-hot core, then
            # travelling chevrons so the beam reads as sustained energy.
            var flare: float = clampf(1.0 - (clock_time - damage) / 0.22, 0.0, 1.0)
            var beam_w: float = maxf(22.0, width * 2.4) * (0.93 + 0.10 * pulse)
            draw_line(a, b, Color(1.0, 0.16, 0.38, 0.10 + 0.05 * pulse), beam_w * 3.2, false)
            draw_line(a, b, Color(1.0, 0.28, 0.38, 0.20), beam_w * 2.0, false)
            draw_line(a, b, Color("ff5f8f"), beam_w * 1.22, false)
            draw_line(a, b, Color("ff967f"), beam_w, false)
            draw_line(a, b, Color("fff3cc"), maxf(4.0, beam_w * 0.40), false)
            draw_line(a, b, Color(1, 1, 1, 0.95), maxf(2.0, beam_w * 0.15), false)
            if flare > 0.0:
                draw_line(a, b, Color(1, 1, 1, 0.55 * flare), beam_w * 2.6, false)
                var fr: float = beam_w * (0.9 + 0.9 * flare)
                draw_colored_polygon(PackedVector2Array([
                    a + Vector2(0.0, -fr), a + Vector2(fr, 0.0),
                    a + Vector2(0.0, fr), a + Vector2(-fr, 0.0)
                ]), Color(1.0, 1.0, 0.92, 0.30 * flare))
            var tick: float = fposmod(clock_time * 320.0, 56.0)
            while tick < span:
                var tick_point: Vector2 = (a + axis * tick).round()
                var reach: float = beam_w * 0.62
                draw_line(tick_point - normal * reach, tick_point, Color(1.0, 1.0, 0.86, 0.55), maxf(2.0, beam_w * 0.11), false)
                draw_line(tick_point + normal * reach, tick_point, Color(1.0, 1.0, 0.86, 0.55), maxf(2.0, beam_w * 0.11), false)
                tick += 56.0
    if not cube.is_empty() and clock_time <= float(cube["damage_time"]) + 0.12:
        var start: float = float(cube["start_time"])
        var landing: float = float(cube["flight_end_time"])
        var t: float = clampf((clock_time - start) / maxf(0.001, landing - start), 0.0, 1.0)
        var diamond: bool = bool(cube["diamond"])
        for trail: float in [0.06, 0.11]:
            var trail_t: float = clampf(t - trail, 0.0, 1.0)
            if trail_t > 0.01:
                var trail_at: Vector2 = (cube["from"] as Vector2).lerp(cube["to"], trail_t).round()
                _draw_cube_marker(trail_at, diamond, 0.16, false)
        var at: Vector2 = (cube["from"] as Vector2).lerp(cube["to"], t).round()
        _draw_cube_marker(at, diamond, 1.0, true)
        if clock_time >= float(cube["damage_time"]):
            var flare: float = clampf(1.0 - (clock_time - float(cube["damage_time"])) / 0.12, 0.0, 1.0)
            draw_line(at - Vector2(26, 26) * flare, at + Vector2(26, 26) * flare, Color(1.0, 1.0, 0.92, 0.8 * flare), 3.0)
            draw_line(at - Vector2(26, -26) * flare, at + Vector2(26, -26) * flare, Color(1.0, 0.8, 0.7, 0.7 * flare), 2.0)

func _draw_cube_marker(at: Vector2, diamond: bool, alpha: float, bright: bool) -> void:
    var size: float = 13.0 if diamond else 10.0
    var halo: Color = Color(0.55, 0.88, 1.0, 0.14 * alpha)
    var pulse: float = 0.7 + 0.3 * sin(clock_time * 26.0)
    if diamond:
        draw_colored_polygon(PackedVector2Array([
            at + Vector2(0, -size * 1.5) * pulse, at + Vector2(size * 1.5, 0) * pulse,
            at + Vector2(0, size * 1.5) * pulse, at + Vector2(-size * 1.5, 0) * pulse
        ]), halo)
    else:
        draw_rect(Rect2(at - Vector2(size, size) * 1.4 * pulse, Vector2(size, size) * 2.8 * pulse), halo)
    var corners: PackedVector2Array
    if not diamond:
        corners = PackedVector2Array([at + Vector2(-size, -size), at + Vector2(size, -size), at + Vector2(size, size), at + Vector2(-size, size), at + Vector2(-size, -size)])
    else:
        corners = PackedVector2Array([at + Vector2(-size, 0), at + Vector2(0, -size), at + Vector2(size, 0), at + Vector2(0, size), at + Vector2(-size, 0)])
    draw_colored_polygon(corners.slice(0, 4), Color(0.145, 0.184, 0.322, alpha))
    draw_polyline(corners, Color(0.51, 0.86, 0.925, alpha), 2.0, false)
    if bright:
        draw_rect(Rect2(at - Vector2(3, 3), Vector2(6, 6)), Color("fff3cc"))
        draw_rect(Rect2(at - Vector2(1, 1), Vector2(2, 2)), Color(1, 1, 1, 0.95))

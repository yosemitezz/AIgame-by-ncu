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

func configure_lines(p_game: Node, owner_boss: Node, records: Array[Dictionary], arena: Rect2, version: int, formation_kind: String = "laser") -> void:
    game = p_game
    source = weakref(owner_boss)
    source_generation = version
    arena_rect = arena
    kind = formation_kind
    for record: Dictionary in records:
        var line: Dictionary = record.duplicate(true)
        var segment: Array[Vector2] = clipped_line(line["origin"], float(line["angle_radians"]), arena_rect)
        if segment.size() != 2:
            continue
        line["a"] = segment[0].round()
        line["b"] = segment[1].round()
        lines.append(line)

func configure_cube(p_game: Node, owner_boss: Node, plan: Dictionary, arena: Rect2, version: int) -> void:
    cube = plan.duplicate(true)
    cube["orientation"] = "diamond_plus" if bool(cube["diamond"]) else "square_x"
    cube["orientation_degrees"] = 45.0 if bool(cube["diamond"]) else 0.0
    var records: Array[Dictionary] = []
    var angles: Array = [0.0, 90.0] if bool(cube["diamond"]) else [45.0, 135.0]
    for angle: float in angles:
        records.append({"origin": cube["to"], "angle_radians": deg_to_rad(angle), "thickness": float(cube["thickness"]), "warning_time": float(cube["flight_end_time"]), "damage_time": float(cube["damage_time"]), "active_until": float(cube["active_until"])})
    configure_lines(p_game, owner_boss, records, arena, version, "cube_plus" if bool(cube["diamond"]) else "cube_x")

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
    return {"kind": kind, "lines": lines.duplicate(true), "cube": cube.duplicate(true), "generation": source_generation, "clock": clock_time}

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

func _draw() -> void:
    if _cleared:
        return
    for line: Dictionary in lines:
        var warning: float = float(line["warning_time"])
        var damage: float = float(line["damage_time"])
        var end: float = float(line["active_until"])
        if clock_time < warning or clock_time > end:
            continue
        var a: Vector2 = line["a"]
        var b: Vector2 = line["b"]
        var width: float = float(line.get("thickness", 9.0))
        if clock_time < damage:
            draw_line(a, b, Color("633b59"), width + 2.0, false)
            draw_line(a, b, Color("ff967f"), 1.0, false)
            var progress: float = clampf((clock_time - warning) / maxf(0.001, damage - warning), 0.0, 1.0)
            var marker: Vector2 = a.lerp(b, progress).round()
            draw_rect(Rect2(marker - Vector2(2, 2), Vector2(4, 4)), Color("ffd5a1"))
        else:
            draw_line(a, b, Color("963d69"), width + 4.0, false)
            draw_line(a, b, Color("ff967f"), width, false)
            draw_line(a, b, Color("fff3cc"), maxf(1.0, width - 5.0), false)
    if not cube.is_empty() and clock_time <= float(cube["damage_time"]):
        var t: float = clampf((clock_time - float(cube["start_time"])) / maxf(0.001, float(cube["flight_end_time"]) - float(cube["start_time"])), 0.0, 1.0)
        var at: Vector2 = (cube["from"] as Vector2).lerp(cube["to"], t).round()
        var corners: PackedVector2Array
        if not bool(cube["diamond"]):
            corners = PackedVector2Array([at + Vector2(-7, -7), at + Vector2(7, -7), at + Vector2(7, 7), at + Vector2(-7, 7), at + Vector2(-7, -7)])
        else:
            corners = PackedVector2Array([at + Vector2(-9, 0), at + Vector2(0, -9), at + Vector2(9, 0), at + Vector2(0, 9), at + Vector2(-9, 0)])
        draw_colored_polygon(corners.slice(0, 4), Color("252f52"))
        draw_polyline(corners, Color("82dbec"), 2.0, false)
        draw_rect(Rect2(at - Vector2(2, 2), Vector2(4, 4)), Color("fff3cc"))

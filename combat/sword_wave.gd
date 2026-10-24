extends Node2D
## Heavy finisher: independently owned, swept, single-hit-per-target sword energy.
## No hostile projectile budget, global clock, player immunity or time-scale changes.
const MeleeQuery = preload("res://combat/melee_query.gd")
const CONFIG: String = "res://data/hero_sword_wave.json"
static var _settings: Dictionary = {}
var game: Node
var owner_ref: WeakRef
var owner_serial: int = -1
var weapon: String = "heavy"
var facing: int = 1
var damage: int = 2
var speed: float = 640.0
var lifetime: float = 0.65
var size: Vector2 = Vector2(12, 58)
var age: float = 0.0
var _cleared: bool = false
var _targets: Dictionary = {}
var _trail: Array[Vector2] = []
var _shape: RectangleShape2D

static func settings() -> Dictionary:
    if _settings.is_empty():
        var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CONFIG))
        if parsed is Dictionary: _settings = parsed
    return _settings

static func live_limit() -> int:
    return clampi(int(settings().get("max_live", 3)), 1, 6)

func configure(owner_game: Node, source: Node2D, serial: int) -> void:
    game = owner_game
    owner_ref = weakref(source)
    owner_serial = serial
    facing = -1 if int(source.get("facing")) < 0 else 1
    # Snapshot immutable cast data. Equipping another sword cannot change a wave.
    var config: Dictionary = settings()
    damage = clampi(int(config.get("damage", 2)), 1, 10)
    speed = clampf(float(config.get("speed", 640)), 100, 900)
    lifetime = clampf(float(config.get("lifetime", 0.65)), 0.1, 1.2)
    size = Vector2(clampf(float(config.get("width", 12)), 4, 24), clampf(float(config.get("height", 58)), 16, 80))
    var center_y: float = float(config.get("center_y", -31))
    # Start at the body and sweep out: never spawn a damaging wave beyond a wall.
    position = source.global_position + Vector2(0, center_y)
    _shape = RectangleShape2D.new()
    _shape.size = size

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_PAUSABLE
    texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    z_index = 6
    add_to_group("hero_waves")

func _allowed() -> bool:
    if _cleared or not is_instance_valid(game) or bool(game.get("story_safe")):
        return false
    var source: Node = owner_ref.get_ref() if owner_ref != null else null
    return is_instance_valid(source) and source.get("dead") != true and str(game.get("outcome")) in ["", "<null>"]

func _physics_process(delta: float) -> void:
    if not _allowed():
        clear()
        return
    if get_tree().paused: return
    var elapsed: float = minf(maxf(0.0, delta), maxf(0.0, lifetime - age))
    if elapsed <= 0.0:
        clear()
        return
    age += elapsed
    var previous: Vector2 = global_position
    var motion: Vector2 = Vector2(facing * speed * elapsed, 0)
    var space: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
    var query: PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()
    query.shape = _shape
    query.transform = Transform2D(0.0, previous)
    query.collision_mask = 1
    query.collide_with_areas = false
    if not space.intersect_shape(query, 1).is_empty():
        clear()
        return
    query.motion = motion
    var fractions: PackedFloat32Array = space.cast_motion(query)
    var fraction: float = float(fractions[0]) if fractions.size() >= 1 else 1.0
    var destination: Vector2 = previous + motion * fraction
    var swept: PackedVector2Array = _sweep(previous, destination)
    for value: Node in get_tree().get_nodes_in_group("enemies"):
        if not value is Node2D or not is_instance_valid(value) or value.get("dead") == true:
            continue
        var target: Node2D = value as Node2D
        if _targets.has(target.get_instance_id()): continue
        var intersections: Array[PackedVector2Array] = Geometry2D.intersect_polygons(swept, MeleeQuery.target_polygon(target))
        if intersections.is_empty(): continue
        # Any wall between the swept path and the target wins over the energy.
        var contact: Vector2 = intersections[0][0]
        var center: Vector2 = Geometry2D.get_closest_point_to_segment(contact, previous, destination)
        var ray: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(center, contact, 1)
        ray.hit_from_inside = true
        if not space.intersect_ray(ray).is_empty(): continue
        _targets[target.get_instance_id()] = true
        if game.has_method("sword_wave_hit"):
            game.sword_wave_hit(self, target, previous - Vector2(facing * size.x, 0))
        if not _allowed():
            clear()
            return
    _trail.push_front(previous)
    if _trail.size() > 4: _trail.pop_back()
    global_position = destination
    if fraction < 0.99999 or age >= lifetime - 0.000001:
        clear()
        return
    queue_redraw()

func _sweep(from_at: Vector2, to_at: Vector2) -> PackedVector2Array:
    var left: float = minf(from_at.x, to_at.x) - size.x * 0.5
    var right: float = maxf(from_at.x, to_at.x) + size.x * 0.5
    return PackedVector2Array([Vector2(left, from_at.y - size.y * 0.5), Vector2(right, from_at.y - size.y * 0.5), Vector2(right, from_at.y + size.y * 0.5), Vector2(left, from_at.y + size.y * 0.5)])

func clear() -> void:
    if _cleared: return
    _cleared = true
    _targets.clear()
    _trail.clear()
    remove_from_group("hero_waves")
    hide()
    set_physics_process(false)
    queue_free()

func _draw() -> void:
    # Stepped warm crescent with a white cutting ridge, entirely within collision.
    # Sparse tails are translucent decoration, not a second damaging rectangle.
    var fade: float = minf(1.0, maxf(0.0, lifetime - age) / 0.10)
    for index: int in range(_trail.size() - 1, -1, -1):
        var offset: Vector2 = (_trail[index] - global_position).round()
        draw_line(offset + Vector2(0, -size.y * 0.22), offset + Vector2(0, size.y * 0.22), Color(1.0, 0.38, 0.12, fade * (0.10 - index * 0.018)), 2)
    for y: int in range(-int(size.y * 0.5), int(size.y * 0.5), 2):
        var bend: float = 1.0 - absf(float(y)) / (size.y * 0.5)
        var x: float = floorf(bend * (size.x - 4.0)) - size.x * 0.5 + 2.0
        var at: Vector2 = Vector2(roundf(x * facing), y)
        draw_rect(Rect2(at - Vector2(2, 0), Vector2(4, 2)), Color(1.0, 0.39 + bend * 0.35, 0.13, fade))
        draw_rect(Rect2(at, Vector2(2, 2)), Color(1.0, 0.96, 0.77, fade))
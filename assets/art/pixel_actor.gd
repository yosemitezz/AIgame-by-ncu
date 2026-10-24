extends RefCounted

const STATES := ["idle", "run", "jump", "fall", "dash", "attack", "parry", "hurt", "dead", "windup"]
static var textures: Dictionary = {}

static func paint(canvas: Node2D, kind: String, state: String, frame: int, facing: int) -> void:
    var key: String = kind if kind in ["hero", "sentry", "elite", "wisp", "boss"] else "sentry"
    if not textures.has(key):
        textures[key] = load("res://assets/art/placeholder_%s.png" % key)
    var texture: Texture2D = textures[key]
    if texture == null:
        return
    var row: int = STATES.find(state)
    if row < 0:
        row = 0
    var frame_size := Vector2(80, 80) if key == "boss" else Vector2(40, 48)
    var anchor := Vector2(40, 76) if key == "boss" else Vector2(20, 44)
    var size_scale: float = 1.15 if key == "elite" else 1.0
    canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2(float(facing) * size_scale, size_scale))
    canvas.draw_texture_rect_region(texture, Rect2(-anchor, frame_size), Rect2(Vector2(posmod(frame, 6) * frame_size.x, row * frame_size.y), frame_size))
    canvas.draw_set_transform(Vector2.ZERO)

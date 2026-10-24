extends RefCounted
## Sprite presentation only; phase and facing come from gameplay.
## New integer-grid poses retain a stable feet anchor. No gameplay transforms.
const HERO_ANCHOR := Vector2(28, 58)
const HERO_SIZE := Vector2(64, 64)
const ORIGINAL_STATES := ["idle", "run", "jump", "fall", "dash", "attack", "parry", "hurt", "dead", "windup"]
static var _textures: Dictionary = {}
static var _manifest: Dictionary = {}

static func _texture(name: String) -> Texture2D:
    if not _textures.has(name):
        _textures[name] = load(name)
    return _textures[name]

static func _data() -> Dictionary:
    if _manifest.is_empty():
        var file: FileAccess = FileAccess.open("res://presentation/feel_frames/manifest.json", FileAccess.READ)
        if file:
            var parsed: Variant = JSON.parse_string(file.get_as_text())
            if parsed is Dictionary:
                _manifest = parsed
    return _manifest

static func _combo(actor: Object) -> int:
    var value: Variant = actor.get("combo")
    return clampi(int(value), 1, 3) if value != null else 1

static func hero_region(state: String, frame: int, combo: int = 1) -> Rect2:
    var data: Dictionary = _data()
    var states: Dictionary = data.get("hero", {}).get("states", {})
    var key: String = state
    if state in ["windup", "attack", "recover"]:
        key = "cut_%d_%s" % [clampi(combo, 1, 3), state]
    elif state == "death":
        key = "dead"
    if not states.has(key):
        key = "idle"
    var descriptor: Dictionary = states.get(key, {"start": 0, "count": 4})
    var index: int = int(descriptor["start"]) + posmod(frame, int(descriptor["count"]))
    return Rect2(Vector2(index % 8, index / 8) * HERO_SIZE, HERO_SIZE)

static func weapon_tip_local(combo: int, frame: int) -> Vector2:
    var data: Dictionary = _data()
    var tips: Dictionary = data.get("hero", {}).get("weapon_tips", {})
    var key: String = "cut_%d_attack" % clampi(combo, 1, 3)
    var points: Array = tips.get(key, [[20, -24]])
    var point: Array = points[clampi(frame, 0, points.size() - 1)]
    return Vector2(float(point[0]), float(point[1]))

static func silhouette_texture() -> Texture2D:
    return _texture("res://presentation/feel_frames/hero_silhouette.png")

static func paint(canvas: Node2D, kind: String, state: String, frame: int, facing: int) -> void:
    var region: Rect2
    var anchor: Vector2
    var frame_size: Vector2
    var texture: Texture2D
    var flash: Variant = canvas.get("impact_flash")
    if flash == null:
        flash = canvas.get("_hurt_flash")
    if flash == null:
        flash = canvas.get("_hurt_timer")
    var flashing: bool = flash != null and float(flash) > 0.055
    if kind == "hero":
        texture = _texture("res://presentation/feel_frames/hero_flash.png" if flashing else "res://presentation/feel_frames/hero_atlas.png")
        frame_size = HERO_SIZE
        anchor = HERO_ANCHOR
        region = hero_region(state, frame, _combo(canvas))
    else:
        var key: String = kind if kind in ["sentry", "elite", "wisp", "boss"] else "sentry"
        texture = _texture("res://presentation/feel_frames/%s_flash.png" % key if flashing else "res://assets/art/placeholder_%s.png" % key)
        frame_size = Vector2(80, 80) if key == "boss" else Vector2(40, 48)
        anchor = Vector2(40, 76) if key == "boss" else Vector2(20, 44)
        var row: int = ORIGINAL_STATES.find(state)
        if row < 0:
            row = 5 if state == "recover" else 0
        region = Rect2(Vector2(posmod(frame, 6) * frame_size.x, row * frame_size.y), frame_size)
    if texture == null:
        return
    canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2(float(facing), 1))
    canvas.draw_texture_rect_region(texture, Rect2(-anchor, frame_size), region)
    canvas.draw_set_transform(Vector2.ZERO)

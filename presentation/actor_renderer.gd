extends RefCounted
const EnemyVisual = preload("res://presentation/enemy_visual.gd")
const KatanaVisual = preload("res://presentation/katana_visual.gd")
## Sprite presentation only; phase and facing come from gameplay.
## New integer-grid poses retain a stable feet anchor. No gameplay transforms.
const HERO_ANCHOR := Vector2(66, 108)
const HERO_SIZE := Vector2(144, 128)
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

static func is_airborne(actor: Object) -> bool:
    var saved: Variant = actor.get("airborne")
    if saved != null:
        return bool(saved)
    return actor is CharacterBody2D and not (actor as CharacterBody2D).is_on_floor()

static func _combo(actor: Object) -> int:
    var value: Variant = actor.get("combo")
    return clampi(int(value), 1, 3) if value != null else 1

static func hero_region(state: String, frame: int, combo: int = 1, airborne: bool = false) -> Rect2:
    var data: Dictionary = _data()
    var states: Dictionary = data.get("hero", {}).get("states", {})
    var key: String = state
    if state in ["windup", "attack", "recover"]:
        key = "%scut_%d_%s" % ["air_" if airborne else "", clampi(combo, 1, 3), state]
    elif state == "death":
        key = "dead"
    if not states.has(key):
        key = "idle"
    var descriptor: Dictionary = states.get(key, {"start": 0, "count": 4})
    var index: int = int(descriptor["start"]) + posmod(frame, int(descriptor["count"]))
    return Rect2(Vector2(index % 8, index / 8) * HERO_SIZE, HERO_SIZE)

static func weapon_tip_local(combo: int, frame: int, airborne: bool = false) -> Vector2:
    var data: Dictionary = _data()
    var tips: Dictionary = data.get("hero", {}).get("weapon_tips", {})
    var key: String = "%scut_%d_attack" % ["air_" if airborne else "", clampi(combo, 1, 3)]
    var points: Array = tips.get(key, [[20, -24]])
    var point: Array = points[clampi(frame, 0, points.size() - 1)]
    return Vector2(float(point[0]), float(point[1]))

static func silhouette_texture() -> Texture2D:
    return _texture("res://presentation/feel_frames/hero_silhouette.png")


static func parry_region(kind: String, state: String, progress: float) -> Rect2:
    var size: Vector2 = HERO_SIZE if kind == "hero" else Vector2(80, 80)
    var row: int = 0
    var p: float = clampf(progress, 0, 1)
    if kind == "hero":
        row = {"parry_ready": 0, "parry_recoil": 1, "parry_recover": 2}.get(state, 0)
    else:
        row = {"parry_recoil": 0, "parry_recover": 0, "guard_break": 1, "guard_recover": 2}.get(state, 0)
        if state == "parry_recover":
            p = 1.0 - p
        elif state == "guard_break":
            # Collapse near the start of the real break window, then hold the knee.
            p = minf(1.0, p * 4.0)
    var index: int = clampi(int(p * 4), 0, 3)
    return Rect2(Vector2(index * size.x, row * size.y), size)

static func _parry_pose(actor: Object, kind: String, state: String, frame: int) -> Dictionary:
    var key: String = ""
    var progress: float = float(clampi(frame, 0, 3)) / 3.0
    if kind == "hero":
        var phase: Variant = actor.get("parry_phase")
        if phase != null and str(phase) in ["ready", "recoil", "recover"]:
            key = {"ready": "parry_ready", "recoil": "parry_recoil", "recover": "parry_recover"}[str(phase)]
            if actor.has_method("get_parry_progress"):
                progress = float(actor.call("get_parry_progress"))
        elif state in ["parry", "parry_ready", "parry_recoil", "parry_recover"]:
            key = "parry_ready" if state == "parry" else state
    elif kind == "boss":
        var reaction: Variant = actor.get("reaction_state")
        if reaction != null and str(reaction) not in ["", "none"]:
            key = str(reaction)
            var value: Variant = actor.get("reaction_progress")
            if value != null:
                progress = float(value)
        elif state in ["parry_recoil", "parry_recover", "guard_break", "guard_recover"]:
            key = state
        if key == "recoil":
            key = "parry_recoil"
        elif key == "recover":
            key = "parry_recover"
    if key == "":
        return {}
    if kind == "boss" and key not in ["parry_recoil", "parry_recover", "guard_break", "guard_recover"]:
        return {}
    return {"state": key, "progress": progress}

static func paint(canvas: Node2D, kind: String, state: String, frame: int, facing: int) -> void:
    if EnemyVisual.supports(kind):
        EnemyVisual.paint(canvas, kind, state, frame, facing)
        return
    if kind == "boss":
        KatanaVisual.paint(canvas, state, frame, facing)
        return
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
    var parry_pose: Dictionary = _parry_pose(canvas, kind, state, frame)
    if not parry_pose.is_empty():
        var key: String = "hero" if kind == "hero" else "boss"
        texture = _texture("res://presentation/parry_frames/%s_%s.png" % [key, "flash" if flashing else "parry"])
        frame_size = HERO_SIZE if kind == "hero" else Vector2(80, 80)
        anchor = HERO_ANCHOR if kind == "hero" else Vector2(40, 76)
        region = parry_region(kind, parry_pose["state"], float(parry_pose["progress"]))
    elif kind == "hero":
        texture = _texture("res://presentation/feel_frames/hero_flash.png" if flashing else "res://presentation/feel_frames/hero_atlas.png")
        frame_size = HERO_SIZE
        anchor = HERO_ANCHOR
        region = hero_region(state, frame, _combo(canvas), is_airborne(canvas))
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
    # Optional squash and stretch about the feet; the hero sets it for take-off, landing and the cut itself.
    var squash: Vector2 = Vector2.ONE
    if kind == "hero":
        var squash_value: Variant = canvas.get("visual_scale")
        if squash_value is Vector2:
            squash = squash_value
    canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2(float(facing) * squash.x, squash.y))
    canvas.draw_texture_rect_region(texture, Rect2(-anchor, frame_size), region)
    canvas.draw_set_transform(Vector2.ZERO)

extends Node2D
## Infinite camera-following Boss room. It never mounts the dungeon or owns a gameplay clock.

signal calibration_complete(offset_ms: float)
signal heavy_clash_requested(event_time: float)
signal heavy_history_cleared

const Calibration = preload("res://combat/audio_calibration.gd")
const CalibrationOverlay = preload("res://ui/calibration_overlay.gd")

const ROOM_ID: String = "boss"
const SPAWN: Vector2 = Vector2(2706, 300)
const BOSS_POSITION: Vector2 = Vector2(2990, 300)
const WORLD_BOUNDS: Rect2 = Rect2(2580, -160, 840, 720)
const FALL_LIMIT: float = 720.0
const PLATFORM_SPACING: float = 200.0
const PLATFORM_WIDTH: float = 200.0
const PLATFORM_HEIGHT: float = 12.0
const PLATFORM_BASE_Y: float = 300.0
const PLATFORM_LAYER_COUNT: int = 5
const PLATFORM_LAYER_SPACING: float = 150.0
const PLATFORM_SURROUND: float = 700.0
const DRAW_INTERVAL: float = 0.1
const DRAW_MOVE: float = 8.0

const DARK: Color = Color("0f0b16")
const FAR: Color = Color("1a1524")
const MID: Color = Color("241d30")
const MASON: Color = Color("322b3c")
const STONE: Color = Color("41394b")
const LIP: Color = Color("786b7e")
const GOLD: Color = Color("c08a4a")
const GOLD_LOW: Color = Color("7d5a3c")

const ROOMS: Array = [{
    "id": ROOM_ID,
    "title": "THE HOLLOW BELFRY",
    "hint": "Close the distance / Parry the golden rain",
}]

var game: Node
var music: Node
var boss: Node2D
var active: bool = false
var calibrating: bool = false
var battle_running: bool = false
var _calibration: RefCounted
var _preview: AudioStreamPlayer
var _overlay: Control
var _overlay_generation: int = 0
var _preview_started_frame: int = -1
var _heavy_groups: Array[Dictionary] = []
var _heavy_cursor: int = 0
var _transport_generation: int = -1
var _last_chart_time: float = -1.0
var _platforms: Dictionary = {}
var _clock: float = 0.0
var _draw_clock: float = 0.0
var _last_draw_at: Vector2 = Vector2(INF, INF)

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_PAUSABLE
    z_index = -20
    texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    var canvas := CanvasLayer.new()
    canvas.layer = 40
    add_child(canvas)
    _overlay = CalibrationOverlay.new()
    canvas.add_child(_overlay)

func setup(owner_game: Node) -> void:
    game = owner_game
    music = owner_game.get("music")
    active = true

func get_room_spec() -> Dictionary:
    return {
        "id": ROOM_ID,
        "title": "THE HOLLOW BELFRY",
        "bounds": WORLD_BOUNDS,
        "spawn": SPAWN,
        "checkpoint": SPAWN,
        "boss_spawn": BOSS_POSITION,
        "portal_at": SPAWN,
        "fall_limit": FALL_LIMIT,
        "platforms": [],
        "shard_indices": [11],
    }

func get_map_bounds(center: Vector2) -> Rect2:
    return Rect2(center - Vector2(420, 320), Vector2(840, 640))

func room_at(_feet: Vector2) -> Dictionary:
    return ROOMS[0].duplicate()

func climb_at(_feet: Vector2) -> Dictionary: return {}
func water_at(_feet: Vector2) -> bool: return false
func portal_at(_feet: Vector2) -> Dictionary: return {}
func interaction_hint(_feet: Vector2) -> String: return ""
func try_interact(_feet: Vector2) -> bool: return false
func get_opened_ids() -> Array[String]: return []
func restore_opened_ids(_ids: Array) -> void: pass
func reset_interactions() -> void: pass

func start_room_entry() -> void:
    active = true
    calibrating = false
    battle_running = false
    _heavy_groups.clear()
    _heavy_cursor = 0
    _transport_generation = -1
    _last_chart_time = -1.0
    _clear_preview()
    var groups: Array[Dictionary] = []
    if is_instance_valid(music) and music.has_method("get_heavy_groups"):
        groups.assign(music.call("get_heavy_groups"))
    _calibration = Calibration.new()
    var base_offset: float = 245.0
    if is_instance_valid(music) and music.get("timeline") is Dictionary:
        base_offset = float(music.timeline.get("offset_ms", 245.0))
    if not _is_full_song():
        _skip_calibration("没有可校准的重拍，跳过校准。", false)
        return
    if groups.is_empty() or not _calibration.configure(groups, base_offset):
        _skip_calibration("没有可校准的重拍，跳过校准。", false)
        return
    if DisplayServer.get_name() == "headless" or AudioServer.get_driver_name() == "Dummy" or bool(music.get("_dummy")):
        _skip_calibration("当前音频设备不可用，跳过校准。", false)
        return
    calibrating = true
    if is_instance_valid(_overlay):
        _overlay.present("校准会在每次进入或重试时重新开始。")
    _start_preview()

func _is_full_song() -> bool:
    return is_instance_valid(music) and music.has_method("is_full_song") and bool(music.call("is_full_song"))

func _start_preview() -> void:
    if not calibrating or _calibration == null:
        return
    _clear_preview()
    var stream: AudioStream = null
    if is_instance_valid(music) and music.get("_audio") is AudioStreamPlayer:
        var source: AudioStreamPlayer = music.get("_audio")
        if is_instance_valid(source):
            stream = source.stream
    if stream == null:
        _skip_calibration("没有可用的音频文件，跳过校准。", true)
        return
    _preview = AudioStreamPlayer.new()
    _preview.name = "CalibrationPreview"
    _preview.bus = "Music"
    var volume_db: float = -8.0
    if is_instance_valid(music) and music.get("timeline") is Dictionary:
        volume_db = float(music.timeline.get("music_volume_db", -8.0))
    _preview.volume_db = volume_db
    _preview.stream = stream
    add_child(_preview)
    _preview.play(_calibration.preview_start_seconds())
    _preview_started_frame = Engine.get_process_frames()
    if is_instance_valid(_overlay):
        _overlay.set_progress(0, Calibration.SAMPLE_COUNT)

func _skip_calibration(reason: String, visible: bool) -> void:
    if not active:
        return
    calibrating = false
    _clear_preview()
    if visible and is_instance_valid(_overlay):
        _overlay.present("")
        _overlay.show_result(reason)
        _overlay_generation += 1
        get_tree().create_timer(2.2).timeout.connect(_hide_overlay_after_result.bind(_overlay_generation))
    calibration_complete.emit(_calibration.base_offset_ms if _calibration != null else 245.0)

func _finish_calibration(offset_ms: float) -> void:
    if not calibrating:
        return
    calibrating = false
    _clear_preview()
    var rounded: float = roundf(offset_ms)
    if is_instance_valid(_overlay):
        _overlay.show_result("校准完成：%.0f ms" % rounded)
        _overlay_generation += 1
        get_tree().create_timer(1.1).timeout.connect(_hide_overlay_after_result.bind(_overlay_generation))
    calibration_complete.emit(rounded)

func _hide_overlay_after_result(generation: int) -> void:
    if generation != _overlay_generation or not is_instance_valid(_overlay):
        return
    _overlay.dismiss()

func begin_battle(owner_boss: Node2D) -> void:
    boss = owner_boss
    battle_running = true
    calibrating = false
    _clear_preview()
    _overlay_generation += 1
    if is_instance_valid(_overlay):
        _overlay.dismiss()
    _heavy_groups.clear()
    if is_instance_valid(music) and music.has_method("get_heavy_groups"):
        _heavy_groups.assign(music.call("get_heavy_groups"))
    _heavy_cursor = 0
    _transport_generation = int(music.call("get_transport_generation")) if is_instance_valid(music) else -1
    _last_chart_time = -1.0

func _process(delta: float) -> void:
    if not active:
        return
    if calibrating:
        _process_calibration()
    elif battle_running:
        _process_heavy_groups()
    _update_platforms()
    _update_draw(delta)

func _process_calibration() -> void:
    if _preview == null or not is_instance_valid(_preview):
        return
    if not _preview.playing:
        if Engine.get_process_frames() > _preview_started_frame + 1:
            if _calibration.is_complete():
                _finish_calibration(_calibration.adjusted_offset_ms())
            else:
                _overlay.set_retry("没有采足 5 下，马上重新播放。")
                _start_preview()
        return
    var now: float = _preview_clock()
    _overlay.set_progress(_calibration.tap_positions.size(), Calibration.SAMPLE_COUNT)
    var finish_at: float = float(_calibration.sample_times.back()) + 0.75 if not _calibration.sample_times.is_empty() else INF
    if now >= finish_at:
        if _calibration.is_complete():
            _finish_calibration(_calibration.adjusted_offset_ms())
        else:
            _overlay.set_retry("没有采足 5 下，马上重新播放。")
            _start_preview()

func _preview_clock() -> float:
    if _preview == null or not is_instance_valid(_preview):
        return 0.0
    if not _preview.playing:
        return 0.0
    return maxf(0.0, _preview.get_playback_position() + AudioServer.get_time_since_last_mix() - AudioServer.get_output_latency())

func _unhandled_input(event: InputEvent) -> void:
    if not active or not calibrating or _calibration == null:
        return
    var key_event: InputEventKey = event as InputEventKey
    if key_event != null and key_event.pressed and not key_event.echo and key_event.physical_keycode in [KEY_ESCAPE, KEY_BACKSPACE]:
        _skip_calibration("已跳过校准。", true)
        get_viewport().set_input_as_handled()
        return
    var pressed: bool = false
    if key_event != null:
        pressed = key_event.pressed and not key_event.echo
    elif event is InputEventMouseButton:
        pressed = event.pressed
    elif event is InputEventJoypadButton:
        pressed = event.pressed
    if not pressed:
        return
    var accepted: bool = _calibration.register_tap(_preview_clock())
    get_viewport().set_input_as_handled()
    if not accepted:
        return
    _overlay.set_progress(_calibration.tap_positions.size(), Calibration.SAMPLE_COUNT)
    if _calibration.is_complete():
        _finish_calibration(_calibration.adjusted_offset_ms())

func _process_heavy_groups() -> void:
    if not is_instance_valid(music) or not bool(music.get("running")):
        return
    var now: float = float(music.call("get_chart_time"))
    var generation: int = int(music.call("get_transport_generation"))
    if generation != _transport_generation or now + 0.05 < _last_chart_time:
        _transport_generation = generation
        _heavy_cursor = 0
        heavy_history_cleared.emit()
        while _heavy_cursor < _heavy_groups.size():
            if float(_heavy_groups[_heavy_cursor].get("time", INF)) >= now - 0.000001:
                break
            _heavy_cursor += 1
    var safe: bool = is_instance_valid(game) and bool(game.get("story_safe"))
    while _heavy_cursor < _heavy_groups.size():
        var event_time: float = float(_heavy_groups[_heavy_cursor].get("time", INF))
        if event_time > now + 0.000001:
            break
        _heavy_cursor += 1
        if safe or event_time < 0.0:
            continue
        heavy_clash_requested.emit(event_time)
    _last_chart_time = now

func _update_platforms() -> void:
    if not is_instance_valid(game):
        return
    var player: Node2D = game.get("player")
    if not is_instance_valid(player):
        return
    var center: Vector2 = player.global_position
    var first_index: int = int(floor((center.x - PLATFORM_SURROUND) / PLATFORM_SPACING))
    var last_index: int = int(ceil((center.x + PLATFORM_SURROUND) / PLATFORM_SPACING))
    var drop_through: bool = InputMap.has_action("climb_down") and Input.is_action_pressed("climb_down")
    for key: Variant in _platforms.keys():
        var parts: PackedStringArray = str(key).split(":")
        var layer: int = int(parts[0]) if parts.size() == 2 else -1
        var index: int = int(parts[1]) if parts.size() == 2 else -1
        if layer < 0 or layer >= PLATFORM_LAYER_COUNT or index < first_index or index > last_index:
            var old: Node = _platforms[key]
            _platforms.erase(key)
            if is_instance_valid(old):
                old.queue_free()
    for layer: int in PLATFORM_LAYER_COUNT:
        for index: int in range(first_index, last_index + 1):
            var key: String = "%d:%d" % [layer, index]
            if not _platforms.has(key) or not is_instance_valid(_platforms[key]):
                _platforms[key] = _make_platform(layer, index)
            var body: StaticBody2D = _platforms[key]
            var shape_node: CollisionShape2D = body.get_child(0) as CollisionShape2D
            shape_node.disabled = drop_through

func _make_platform(layer: int, index: int) -> StaticBody2D:
    var body := StaticBody2D.new()
    body.name = "InfinitePlatform_%d_%d" % [layer, index]
    body.position = Vector2(float(index) * PLATFORM_SPACING + PLATFORM_WIDTH * 0.5, platform_layer_y(layer))
    body.collision_layer = 1
    body.collision_mask = 0
    var shape_node := CollisionShape2D.new()
    var shape := RectangleShape2D.new()
    shape.size = Vector2(PLATFORM_WIDTH, PLATFORM_HEIGHT)
    shape_node.shape = shape
    shape_node.one_way_collision = true
    shape_node.one_way_collision_margin = 4.0
    body.add_child(shape_node)
    add_child(body)
    return body

static func platform_layer_y(layer: int) -> float:
    return PLATFORM_BASE_Y + float(layer - 2) * PLATFORM_LAYER_SPACING

func _update_draw(delta: float) -> void:
    _clock += delta
    _draw_clock += delta
    var player: Node2D = game.get("player") if is_instance_valid(game) else null
    var moved: bool = not is_instance_valid(player) or player.global_position.distance_to(_last_draw_at) > DRAW_MOVE
    if _draw_clock < DRAW_INTERVAL and not moved:
        return
    _draw_clock = 0.0
    if is_instance_valid(player):
        _last_draw_at = player.global_position
    queue_redraw()

func _draw() -> void:
    if not active:
        return
    var visible_rect: Rect2 = get_viewport().get_canvas_transform().affine_inverse() * Rect2(Vector2.ZERO, get_viewport_rect().size)
    visible_rect = visible_rect.grow(96.0)
    draw_rect(visible_rect, DARK)
    var first_row: int = int(floor(visible_rect.position.y / 20.0))
    var last_row: int = int(ceil(visible_rect.end.y / 20.0))
    for row: int in range(first_row, last_row + 1):
        var y: float = float(row) * 20.0
        draw_rect(Rect2(visible_rect.position.x, y, visible_rect.size.x, 1), FAR)
        var offset: float = 20.0 if row % 2 else 0.0
        var first_col: int = int(floor((visible_rect.position.x - offset) / 40.0))
        var last_col: int = int(ceil((visible_rect.end.x - offset) / 40.0))
        for col: int in range(first_col, last_col + 1):
            draw_rect(Rect2(float(col) * 40.0 + offset, y + 1.0, 1.0, 19.0), FAR)
    var first_pillar: int = int(floor(visible_rect.position.x / 320.0))
    var last_pillar: int = int(ceil(visible_rect.end.x / 320.0))
    for index: int in range(first_pillar, last_pillar + 1):
        _draw_lancet(float(index * 320) + 16.0, -40.0, 252.0, FAR)
    var first_torch: int = int(floor(visible_rect.position.x / 480.0))
    var last_torch: int = int(ceil(visible_rect.end.x / 480.0))
    for index: int in range(first_torch, last_torch + 1):
        _draw_torch(float(index * 480) + 24.0, -14.0)
    for layer: int in PLATFORM_LAYER_COUNT:
        var layer_y: float = platform_layer_y(layer)
        _draw_platform(Rect2(visible_rect.position.x, layer_y - PLATFORM_HEIGHT * 0.5, visible_rect.size.x, PLATFORM_HEIGHT))

func _draw_platform(area: Rect2) -> void:
    draw_rect(area, DARK)
    draw_rect(Rect2(area.position.x, area.position.y, area.size.x, 4), LIP)
    draw_rect(Rect2(area.position.x, area.position.y + 4, area.size.x, 4), STONE)
    var row_count: int = maxi(1, int((area.size.y - 8) / 18))
    for row: int in range(row_count):
        var y: float = area.position.y + 9 + row * 18
        var offset: int = 18 if row % 2 else 0
        for col: int in range(int(area.size.x / 36) + 1):
            var left: float = maxf(area.position.x + 2, area.position.x + col * 36 - offset + 2)
            var right: float = minf(area.end.x - 2, area.position.x + col * 36 - offset + 34)
            if right > left:
                draw_rect(Rect2(left, y, right - left, minf(14, area.end.y - y)), MASON if row < 2 else MID)
    if area.size.y <= 16:
        for x: int in range(int(area.position.x) + 8, int(area.end.x) - 8, 24):
            draw_rect(Rect2(x, area.position.y + 4, 1, 8), DARK)

func _draw_lancet(x: float, top: float, height: float, tint: Color) -> void:
    draw_rect(Rect2(x, top + 32, 12, height - 32), tint)
    draw_rect(Rect2(x + 84, top + 32, 12, height - 32), tint)
    for step: int in range(4):
        var inset: float = 8.0 + float(step) * 8.0
        draw_rect(Rect2(x + inset, top + 24.0 - float(step) * 8.0, 96.0 - inset * 2.0, 8.0), tint)

func _draw_torch(x: float, y: float) -> void:
    draw_rect(Rect2(x - 4, y - 10, 8, 10), MASON)
    draw_rect(Rect2(x - 2, y - 14, 4, 6), GOLD_LOW)
    var flicker: int = 2 if int(_clock * 8.0 + x) % 3 == 0 else 0
    draw_rect(Rect2(x - 2, y - 19 - flicker, 4, 6 + flicker), GOLD)
    draw_rect(Rect2(x, y - 18 - flicker, 2, 4), Color("d7c898"))

func _clear_preview() -> void:
    if _preview != null and is_instance_valid(_preview):
        _preview.stop()
        _preview.queue_free()
    _preview = null

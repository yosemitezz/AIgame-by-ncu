extends Control
## Native-pixel HUD and screen overlays. Gameplay stays in the root/controller.
const PixelFont = preload("res://presentation/pixel_font.gd")
const Level = preload("res://levels/bellkeep.gd")
const WHITE := Color("eee8df")
const GOLD := Color("edd08e")
const CYAN := Color("78dcd6")
const PURPLE := Color("ba91d6")
var state: Dictionary = {}
var font: Font

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    process_mode = Node.PROCESS_MODE_ALWAYS
    texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    font = PixelFont.create()
    resized.connect(queue_redraw)

func update_state(next: Dictionary) -> void:
    state = next
    queue_redraw()

func panel_layout(canvas: Vector2) -> Dictionary:
    return {"status": Rect2(8, 8, canvas.x - 16, 44), "boss": Rect2(8, 58, canvas.x - 16, 40), "controls": Rect2(8, canvas.y - 44, canvas.x - 16, 36), "pause": Rect2((canvas.x - 456) * 0.5, (canvas.y - 276) * 0.5, 456, 276), "map": Rect2(24, 64, canvas.x - 48, canvas.y - 88)}

func text(at: Vector2, value: String, point_size: int = 12, ink: Color = WHITE, width: float = -1) -> void:
    draw_string(font, at.round(), value, HORIZONTAL_ALIGNMENT_LEFT, width, point_size, ink)

func centered(y: float, value: String, point_size: int = 12, ink: Color = WHITE) -> void:
    var measured: float = font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, point_size).x
    text(Vector2((size.x - measured) * 0.5, y), value, point_size, ink)

func frame_box(rect: Rect2, border: int = 1, accent: Color = WHITE) -> void:
    draw_rect(rect, accent)
    draw_rect(rect.grow(-border), Color("0b0d13"))
    # Cut-corner brackets keep a clear one-pixel frame at integer scale.
    draw_rect(Rect2(rect.position + Vector2(4, 4), Vector2(3, 1)), GOLD)
    draw_rect(Rect2(rect.end - Vector2(7, 5), Vector2(3, 1)), GOLD)

func _draw() -> void:
    if state.is_empty() or font == null:
        return
    var layout: Dictionary = panel_layout(size)
    var status: Rect2 = layout["status"]
    frame_box(status, 2)
    var hp: int = int(state.get("hp", 0))
    var maximum: int = maxi(1, int(state.get("max_hp", 8)))
    var low: bool = hp <= 2
    var hp_ink: Color = Color("ff777d") if low else GOLD
    text(status.position + Vector2(10, 17), "生命 %02d/%02d" % [hp, maximum], 12, hp_ink)
    for pip: int in maximum:
        draw_rect(Rect2(status.position + Vector2(10 + pip * 13, 25), Vector2(10, 8)), hp_ink if pip < hp else Color("442c37"))
    if low:
        text(status.position + Vector2(124, 34), "低血!", 12, hp_ink)
    text(status.position + Vector2(194, 17), "碎片 %02d/%02d" % [state.get("shards", 0), state.get("total_shards", 25)])
    text(status.position + Vector2(194, 34), "记忆仍未归来", 12, Color("9a98a5"))
    var label_x: float = size.x - 278
    text(Vector2(label_x, 25), str(state.get("zone", "")), 12, WHITE, 258)
    draw_rect(Rect2(label_x, 36, 260, 3), Color("373441"))
    draw_rect(Rect2(label_x, 36, roundf(260 * clampf(float(state.get("progress", 0)), 0, 1)), 3), PURPLE)
    if int(state.get("boss_hp", -1)) >= 0:
        _draw_boss(layout["boss"])
    var controls: Rect2 = layout["controls"]
    frame_box(controls)
    text(controls.position + Vector2(9, 14), str(state.get("hint", "")), 12, GOLD, controls.size.x - 18)
    var commands: String = "A/D 移动  空格 跳跃  W/S 攀爬  E 交互  J 攻击  K 弹刀" if size.x >= 760 else "A/D移动 空格跳 W/S攀爬 E交互 J/K攻防"
    text(controls.position + Vector2(9, 29), commands, 12, WHITE)
    text(Vector2(size.x - 234, controls.position.y + 29), "SHIFT 冲刺  TAB 地图  ESC 暂停", 12, Color("aaa6b2"))
    var narration: String = str(state.get("narration", ""))
    if narration != "":
        frame_box(Rect2(16, 105, size.x - 32, 27))
        text(Vector2(25, 123), narration, 12, Color("e8dfbc"), size.x - 50)
    var notice: String = str(state.get("parry_notice", ""))
    if notice != "" and not state.get("safe", false):
        centered(153, {"melee": "刀刃交锋", "projectile": "星火回返", "guard_break": "破架 / 反击窗口"}.get(notice, ""), 12, Color("e9b2ff"))
    if str(state.get("overlay", "")) == "map":
        _draw_map(layout["map"])
    elif state.get("paused", false):
        _draw_pause(layout["pause"])
    elif state.get("outcome", "") == "defeat":
        draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.92))
        centered(size.y * 0.36, "你死亡", 24, WHITE)
        centered(size.y * 0.49, "灯火记得你的来路。")
        centered(size.y * 0.62, "R 从检查点重试   F5 重新启程", 12, GOLD)
    elif state.get("outcome", "") == "victory":
        var ending: float = float(state.get("ending", 0))
        draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, clampf((ending - 2.0) / 2.5, 0, 1)))
        if ending > 4.5:
            centered(size.y * 0.33, "钟声之后", 24, GOLD)
            centered(size.y * 0.45, "声音仍在。记忆却止于此处。")
            centered(size.y * 0.60, "第一章结束", 12, Color("9f9ba7"))
            centered(size.y * 0.72, "F5 重新启程   R 重试")

func _draw_boss(rect: Rect2) -> void:
    frame_box(rect)
    text(rect.position + Vector2(10, 16), "执刃钟守")
    var bar_x: float = rect.position.x + 165
    var bar_width: float = rect.size.x - 177
    draw_rect(Rect2(bar_x, rect.position.y + 7, bar_width, 9), Color("3a2634"))
    draw_rect(Rect2(bar_x, rect.position.y + 7, roundf(bar_width * clampf(float(state.get("boss_hp", 0)) / maxf(1, float(state.get("boss_max", 1))), 0, 1)), 9), Color("db6868"))
    text(rect.position + Vector2(10, 34), "架势")
    var guard: int = int(state.get("boss_guard", 0))
    var broken: bool = str(state.get("reaction", "")) == "guard_break"
    for pip: int in maxi(1, int(state.get("boss_guard_max", 3))):
        draw_rect(Rect2(rect.position + Vector2(48 + pip * 15, 24), Vector2(10, 10)), PURPLE if broken else (GOLD if pip < guard else Color("39343f")))
    if broken:
        text(rect.position + Vector2(105, 34), "破架 / 可反击", 12, PURPLE)
    var phase_label: String = {"fixed": "定拍", "random": "游离", "rest": "休止 / 双方禁伤", "final": "终章"}.get(str(state.get("section", "")), "")
    text(rect.position + Vector2(rect.size.x - 244, 34), phase_label, 12, CYAN if state.get("safe", false) else WHITE)
    for beat: int in 8:
        draw_rect(Rect2(rect.position + Vector2(rect.size.x - 94 + beat * 10, 26), Vector2(5, 5)), GOLD if beat == posmod(int(state.get("beat", 0)), 8) else Color("34303a"))

func _draw_pause(rect: Rect2) -> void:
    draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.88))
    frame_box(rect, 2)
    centered(rect.position.y + 42, "歇息片刻", 24, GOLD)
    centered(rect.position.y + 80, "ESC 继续冒险    TAB 查看地图")
    centered(rect.position.y + 110, "R 返回检查点    F5 重新启程")
    centered(rect.position.y + 150, "F2 震屏：" + ("关闭" if state.get("reduced_motion", false) else "开启"), 12, CYAN)
    centered(rect.position.y + 180, "M 声音：" + ("静音" if state.get("muted", false) else "开启"), 12, CYAN)
    centered(rect.position.y + 210, "F3 速度感：" + ["关闭","标准","强"][clampi(int(state.get("speed_effects_level",1)),0,2)], 12, CYAN)
    centered(rect.position.y + 248, "空格跳跃 / W、S攀爬 / E操作门与机关", 12, Color("aaa6b2"))

func map_point(at: Vector2, area: Rect2) -> Vector2:
    var bounds: Rect2 = Level.WORLD_BOUNDS
    var factor: float = minf(area.size.x / bounds.size.x, area.size.y / bounds.size.y)
    var origin: Vector2 = area.position + (area.size - bounds.size * factor) * 0.5
    return (origin + (at - bounds.position) * factor).round()

func _draw_map(rect: Rect2) -> void:
    draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.94))
    frame_box(rect, 2)
    centered(rect.position.y + 29, "钟堡 / 路线图", 24, GOLD)
    centered(rect.position.y + 50, "悬链书库  ·  破碎回廊  ·  淤水墓廊", 12, Color("aaa6b2"))
    var area := Rect2(rect.position + Vector2(18, 70), rect.size - Vector2(36, 124))
    for platform: Rect2 in Level.PLATFORMS:
        var start: Vector2 = map_point(platform.position, area)
        var end: Vector2 = map_point(platform.end, area)
        draw_rect(Rect2(start, Vector2(maxf(2, end.x - start.x), maxf(2, minf(5, end.y - start.y)))), Color("777483"))
    for climb: Dictionary in Level.CLIMBABLES:
        var bounds: Rect2 = climb["rect"]
        draw_line(map_point(Vector2(bounds.get_center().x, bounds.position.y), area), map_point(Vector2(bounds.get_center().x, bounds.end.y), area), CYAN, 2)
    for water: Rect2 in Level.WATER_REGIONS:
        draw_line(map_point(water.position, area), map_point(Vector2(water.end.x, water.position.y), area), Color("587fc5"), 3)
    var opened: Array = state.get("opened_doors", [])
    for door: Dictionary in Level.DOORS:
        var at: Vector2 = map_point(door["rect"].get_center(), area)
        draw_rect(Rect2(at - Vector2(2, 3), Vector2(4, 6)), Color("474451") if door["id"] in opened else GOLD)
    var collected: Dictionary = state.get("collected", {})
    for index: int in Level.SHARDS.size():
        if not collected.has(index):
            var at: Vector2 = map_point(Level.SHARDS[index], area)
            draw_rect(Rect2(at, Vector2(2, 2)), Color("9c75b4"))
    var shrine: Vector2 = map_point(Level.CHECKPOINT, area)
    draw_rect(Rect2(shrine - Vector2(3, 3), Vector2(6, 6)), GOLD)
    var bell: Vector2 = map_point(Level.BOSS_POSITION, area)
    draw_rect(Rect2(bell - Vector2(3, 4), Vector2(6, 8)), Color("c9747b"))
    var player_at: Vector2 = map_point(state.get("player_at", Level.SPAWN), area)
    draw_rect(Rect2(player_at - Vector2(3, 3), Vector2(7, 7)), Color("101323"))
    draw_rect(Rect2(player_at - Vector2(2, 2), Vector2(5, 5)), Color.WHITE)
    text(rect.position + Vector2(18, rect.size.y - 31), "白点 你的位置    青线 铁链    蓝线 浅水    金色 门 / 检查点", 12, WHITE, rect.size.x - 36)
    centered(rect.end.y - 12, "TAB 或 ESC 返回冒险", 12, GOLD)

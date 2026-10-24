extends Control
## Undertale-style HUD: black panels with hard white frames, a red soul heart, a yellow-on-red HP bar, orange command
## buttons along the bottom and a typewriter dialogue box. Native-pixel and gameplay-free: it only draws the state
## dictionary that main.gd emits through hud_updated, so no gameplay code depends on it.
const PixelFont = preload("res://presentation/pixel_font.gd")
const Level = preload("res://levels/bellkeep.gd")
const WHITE := Color("ffffff")
const BLACK := Color("000000")
const YELLOW := Color("ffff00")
const RED := Color("ff0000")
const ORANGE := Color("ff7f27")
const GRAY := Color("a0a0a0")
const DIM := Color("606060")
const CYAN := Color("00e8fc")
const PURPLE := Color("d535d9")
const DEEP_RED := Color("a00000")
## Undertale soul: 8 x 7 bitmap, drawn as rectangles so it stays crisp at any integer scale.
const HEART: Array[String] = [".XX..XX.", "XXXXXXXX", "XXXXXXXX", "XXXXXXXX", ".XXXXXX.", "..XXXX..", "...XX..."]
const TYPE_RATE: float = 28.0
const HINT_SECONDS: float = 7.0
## Everything this file prints besides the state dictionary, kept in one list so a test can check the font has every glyph.
const STRINGS: Array[String] = [
    "旅人", "LV 01", "HP", "碎片", "攻击 J", "弹刀 K", "冲刺 SHIFT", "地图 TAB", "* ", "架势", "执刃钟守", "破架 / 可反击",
    "定拍", "游离", "休止 / 双方禁伤", "终章", "刀刃交锋", "星火回返", "破架 / 反击窗口",
    "A/D 移动  空格 跳跃 / 连跳  W/S 攀爬  S 蹲下  E 交互  ESC 暂停", "歇息片刻", "ESC 继续冒险", "TAB 查看地图", "R 返回检查点", "F5 重新启程",
    "F2 震屏：", "M 声音：", "F3 速度感：", "关闭", "开启", "静音", "标准", "强", "空格跳跃 / W、S攀爬 / E操作门与机关",
    "游戏结束", "保持决心……", "R 从检查点重试   F5 重新启程", "钟声之后", "声音仍在。记忆却止于此处。", "第一章结束", "F5 重新启程   R 重试",
    "钟堡 / 路线图", "悬链书库  ·  破碎回廊  ·  淤水墓廊", "红心 你的位置    青线 铁链    蓝线 浅水    黄色 门 / 检查点", "TAB 或 ESC 返回冒险", "低血!"]
var state: Dictionary = {}
var font: Font
var _clock: float = 0.0
var _line: String = ""
var _line_clock: float = 0.0
var _hint: String = ""
var _hint_age: float = 99.0
var _outcome: String = ""
var _outcome_clock: float = 0.0

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    process_mode = Node.PROCESS_MODE_ALWAYS
    texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    font = PixelFont.create()
    resized.connect(queue_redraw)

func _process(delta: float) -> void:
    _clock += delta
    _line_clock += delta
    _hint_age += delta
    _outcome_clock += delta
    var typing: bool = _line != "" and typed_count(_line.length(), _line_clock) < _line.length()
    if typing or _outcome != "" or _hint_age < HINT_SECONDS + 0.1 or int(state.get("hp", 9)) <= 2:
        queue_redraw()

func update_state(next: Dictionary) -> void:
    state = next
    var outcome: String = str(next.get("outcome", ""))
    if outcome != _outcome:
        _outcome = outcome
        _outcome_clock = 0.0
    var hint: String = str(next.get("hint", ""))
    if hint != _hint:
        _hint = hint
        _hint_age = 0.0
    var narration: String = str(next.get("narration", ""))
    var wanted: String = narration if narration != "" else (hint if _hint_age < HINT_SECONDS else "")
    if wanted != _line:
        _line = wanted
        _line_clock = 0.0
    queue_redraw()

## Characters of a dialogue line shown after `elapsed` seconds.
func typed_count(total: int, elapsed: float) -> int:
    return mini(total, int(maxf(elapsed, 0.0) * TYPE_RATE))

## HP bar length grows with max HP like the original: 16 px per point, clamped.
func hp_bar_width(maximum: int) -> float:
    return clampf(float(maximum) * 16.0, 48.0, 240.0)

func panel_layout(canvas: Vector2, has_boss: bool = false) -> Dictionary:
    var top: float = 8.0
    var boss := Rect2(8, top, canvas.x - 16, 40)
    var dialog_y: float = top + (48.0 if has_boss else 0.0)
    return {
        "boss": boss,
        "dialog": Rect2(16, dialog_y, canvas.x - 32, 44),
        "bottom": Rect2(0, canvas.y - 74, canvas.x, 74),
        "status": Rect2(16, canvas.y - 70, canvas.x - 32, 20),
        "buttons": Rect2(0, canvas.y - 48, canvas.x, 26),
        "controls": Rect2(16, canvas.y - 20, canvas.x - 32, 14),
        "pause": Rect2((canvas.x - 456) * 0.5, (canvas.y - 276) * 0.5, 456, 276),
        "map": Rect2(24, 64, canvas.x - 48, canvas.y - 88)}

func text(at: Vector2, value: String, point_size: int = 12, ink: Color = WHITE, width: float = -1) -> void:
    draw_string(font, at.round(), value, HORIZONTAL_ALIGNMENT_LEFT, width, point_size, ink)

func centered(y: float, value: String, point_size: int = 12, ink: Color = WHITE) -> void:
    var measured: float = font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, point_size).x
    text(Vector2((size.x - measured) * 0.5, y), value, point_size, ink)

## Black box with a hard white frame (3 px for dialogue, 2 px for panels), exactly like the battle box.
func frame_box(rect: Rect2, border: int = 2, accent: Color = WHITE) -> void:
    draw_rect(rect, accent)
    draw_rect(rect.grow(-border), BLACK)

func draw_heart(at: Vector2, scale: int, ink: Color = RED) -> void:
    for row: int in HEART.size():
        var line: String = HEART[row]
        for col: int in line.length():
            if line[col] == "X":
                draw_rect(Rect2(at + Vector2(col * scale, row * scale), Vector2(scale, scale)), ink)

func _draw() -> void:
    if state.is_empty() or font == null:
        return
    var has_boss: bool = int(state.get("boss_hp", -1)) >= 0
    var layout: Dictionary = panel_layout(size, has_boss)
    var outcome: String = str(state.get("outcome", ""))
    if outcome == "" or (outcome == "defeat" and _outcome_clock < 0.4):
        _draw_hud(layout, has_boss)
    if str(state.get("overlay", "")) == "map":
        _draw_map(layout["map"])
    elif state.get("paused", false):
        _draw_pause(layout["pause"])
    elif outcome == "defeat":
        _draw_game_over()
    elif outcome == "victory":
        _draw_victory()

func _draw_hud(layout: Dictionary, has_boss: bool) -> void:
    if has_boss:
        _draw_boss(layout["boss"])
    # Dialogue: typewriter text with the "* " bullet. The zone hint speaks for a few seconds after you enter a zone.
    if _line != "":
        var box: Rect2 = layout["dialog"]
        frame_box(box, 3)
        var shown: String = "* " + _line.substr(0, typed_count(_line.length(), _line_clock))
        draw_multiline_string(font, (box.position + Vector2(14, 20)).round(), shown, HORIZONTAL_ALIGNMENT_LEFT, box.size.x - 28, 12, 3, WHITE)
    var notice: String = str(state.get("parry_notice", ""))
    if notice != "" and not state.get("safe", false):
        var label: String = {"melee": "刀刃交锋", "projectile": "星火回返", "guard_break": "破架 / 反击窗口"}.get(notice, "")
        centered(size.y * 0.42, label, 12, PURPLE)
    # Bottom panel: status row, command buttons, controls.
    var bottom: Rect2 = layout["bottom"]
    draw_rect(bottom, Color(0, 0, 0, 0.88))
    draw_rect(Rect2(bottom.position, Vector2(bottom.size.x, 2)), WHITE)
    var status: Rect2 = layout["status"]
    var hp: int = int(state.get("hp", 0))
    var maximum: int = maxi(1, int(state.get("max_hp", 8)))
    var low: bool = hp <= 2
    var ink: Color = RED if low and int(_clock * 4.0) % 2 == 0 else WHITE
    var y: float = status.position.y + 14.0
    text(Vector2(status.position.x, y), "旅人", 12, WHITE)
    text(Vector2(status.position.x + 34, y), "LV 01", 12, WHITE)
    text(Vector2(status.position.x + 90, y), "HP", 12, WHITE)
    var bar_x: float = status.position.x + 114.0
    var bar_w: float = hp_bar_width(maximum)
    draw_rect(Rect2(bar_x, y - 11, bar_w, 14), RED)
    draw_rect(Rect2(bar_x, y - 11, roundf(bar_w * clampf(float(hp) / float(maximum), 0.0, 1.0)), 14), YELLOW)
    text(Vector2(bar_x + bar_w + 10, y), "%02d / %02d" % [hp, maximum], 12, ink)
    if low:
        text(Vector2(bar_x + bar_w + 78, y), "低血!", 12, RED)
    text(Vector2(bar_x + bar_w + 130, y), "碎片 %02d/%02d" % [state.get("shards", 0), state.get("total_shards", 25)], 12, WHITE)
    var zone_w: float = 220.0
    var zone_x: float = status.end.x - zone_w
    text(Vector2(zone_x, y), str(state.get("zone", "")), 12, WHITE, zone_w)
    draw_rect(Rect2(zone_x, y + 4, zone_w, 5), WHITE)
    draw_rect(Rect2(zone_x + 1, y + 5, zone_w - 2, 3), BLACK)
    draw_rect(Rect2(zone_x + 1, y + 5, roundf((zone_w - 2) * clampf(float(state.get("progress", 0)), 0.0, 1.0)), 3), YELLOW)
    _draw_buttons(layout["buttons"])
    var controls: Rect2 = layout["controls"]
    text(controls.position + Vector2(0, 11), "A/D 移动  空格 跳跃 / 连跳  W/S 攀爬  S 蹲下  E 交互  ESC 暂停", 12, GRAY, controls.size.x)

## Four orange command buttons in the FIGHT / ACT / ITEM / MERCY spot. They list the real combat keys; the one that is in use
## turns yellow and shows the soul.
func _draw_buttons(row: Rect2) -> void:
    var labels: Array[String] = ["攻击 J", "弹刀 K", "冲刺 SHIFT", "地图 TAB"]
    var active: Array[bool] = [
        false,
        str(state.get("parry_notice", "")) != "" or str(state.get("reaction", "")) == "guard_break",
        false,
        str(state.get("overlay", "")) == "map"]
    var width: float = 138.0
    var gap: float = 26.0
    var total: float = width * 4.0 + gap * 3.0
    var x0: float = roundf((row.size.x - total) * 0.5)
    for i: int in 4:
        var rect := Rect2(x0 + float(i) * (width + gap), row.position.y, width, row.size.y)
        var ink: Color = YELLOW if active[i] else ORANGE
        draw_rect(rect, ink)
        draw_rect(rect.grow(-2), BLACK)
        draw_heart(rect.position + Vector2(10, 6), 2, RED if active[i] else Color(RED, 0.0))
        text(rect.position + Vector2(34, 17), labels[i], 12, ink)

func _draw_boss(rect: Rect2) -> void:
    frame_box(rect, 2)
    text(rect.position + Vector2(12, 17), "* 执刃钟守", 12, WHITE)
    var bar_x: float = rect.position.x + 130
    var bar_w: float = rect.size.x - 142
    draw_rect(Rect2(bar_x - 2, rect.position.y + 6, bar_w + 4, 14), WHITE)
    draw_rect(Rect2(bar_x, rect.position.y + 8, bar_w, 10), DEEP_RED)
    draw_rect(Rect2(bar_x, rect.position.y + 8, roundf(bar_w * clampf(float(state.get("boss_hp", 0)) / maxf(1.0, float(state.get("boss_max", 1))), 0.0, 1.0)), 10), YELLOW)
    text(rect.position + Vector2(12, 34), "架势", 12, GRAY)
    var guard: int = int(state.get("boss_guard", 0))
    var broken: bool = str(state.get("reaction", "")) == "guard_break"
    for pip: int in maxi(1, int(state.get("boss_guard_max", 3))):
        var ink: Color = PURPLE if broken else (ORANGE if pip < guard else DIM)
        draw_heart(rect.position + Vector2(50 + pip * 14, 25), 1, ink)
    if broken:
        text(rect.position + Vector2(100, 34), "破架 / 可反击", 12, PURPLE)
    var phase_label: String = {"fixed": "定拍", "random": "游离", "rest": "休止 / 双方禁伤", "final": "终章"}.get(str(state.get("section", "")), "")
    text(rect.position + Vector2(rect.size.x - 244, 34), phase_label, 12, CYAN if state.get("safe", false) else WHITE)
    for beat: int in 8:
        draw_rect(Rect2(rect.position + Vector2(rect.size.x - 94 + beat * 10, 26), Vector2(5, 5)), YELLOW if beat == posmod(int(state.get("beat", 0)), 8) else DIM)

func _draw_pause(rect: Rect2) -> void:
    draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.9))
    frame_box(rect, 3)
    centered(rect.position.y + 44, "歇息片刻", 24, YELLOW)
    var items: Array[String] = ["ESC 继续冒险", "TAB 查看地图", "R 返回检查点", "F5 重新启程"]
    var left: float = rect.position.x + 120.0
    for i: int in items.size():
        var yy: float = rect.position.y + 84.0 + float(i) * 26.0
        draw_heart(Vector2(left, yy - 9), 2, RED if i == 0 else DIM)
        text(Vector2(left + 28, yy), items[i], 12, WHITE if i == 0 else GRAY)
    centered(rect.position.y + 200, "F2 震屏：" + ("关闭" if state.get("reduced_motion", false) else "开启"), 12, CYAN)
    centered(rect.position.y + 222, "M 声音：" + ("静音" if state.get("muted", false) else "开启"), 12, CYAN)
    centered(rect.position.y + 244, "F3 速度感：" + ["关闭", "标准", "强"][clampi(int(state.get("speed_effects_level", 1)), 0, 2)], 12, CYAN)
    centered(rect.position.y + 266, "空格跳跃 / W、S攀爬 / E操作门与机关", 12, GRAY)

## GAME OVER: the soul holds, cracks, bursts into shards, then the text types in.
func _draw_game_over() -> void:
    draw_rect(Rect2(Vector2.ZERO, size), BLACK)
    var t: float = _outcome_clock
    var centre: Vector2 = (size * Vector2(0.5, 0.36)).round()
    var scale: int = 4
    var origin: Vector2 = centre - Vector2(HEART[0].length() * scale, HEART.size() * scale) * 0.5
    if t < 0.9:
        draw_heart(origin, scale)
    elif t < 1.5:
        # Cracked: the two halves drift apart with a dark seam through the middle.
        draw_heart(origin + Vector2(-2, 0), scale)
        draw_rect(Rect2(origin + Vector2(HEART[0].length() * scale * 0.5 - 1, 0), Vector2(3, HEART.size() * scale)), BLACK)
        draw_rect(Rect2(origin + Vector2(HEART[0].length() * scale * 0.5 + 2, 0), Vector2(HEART[0].length() * scale * 0.5 + 2, HEART.size() * scale)), BLACK)
        draw_heart(origin + Vector2(2, 0), scale, Color(RED, 0.55))
    else:
        var k: float = t - 1.5
        var dirs: Array[Vector2] = [Vector2(-1.0, -1.2), Vector2(1.0, -1.4), Vector2(-1.6, -0.2), Vector2(1.5, -0.3), Vector2(-0.6, 0.2), Vector2(0.7, 0.1), Vector2(0.0, -1.7), Vector2(-1.2, 0.5)]
        for i: int in dirs.size():
            var p: Vector2 = centre + dirs[i] * 70.0 * k + Vector2(0.0, 220.0 * k * k)
            var fade: float = clampf(1.0 - k / 1.6, 0.0, 1.0)
            draw_rect(Rect2(p.round(), Vector2(6, 6)), Color(RED, fade))
            draw_rect(Rect2((p + Vector2(2, 2)).round(), Vector2(2, 2)), Color(1, 1, 1, fade))
    if t > 2.0:
        var a: float = clampf((t - 2.0) / 0.8, 0.0, 1.0)
        centered(size.y * 0.58, "游戏结束", 24, Color(1, 1, 1, a))
    if t > 3.0:
        centered(size.y * 0.68, "保持决心……", 12, Color(0.75, 0.75, 0.75, clampf((t - 3.0) / 0.8, 0.0, 1.0)))
    if t > 3.8:
        centered(size.y * 0.78, "R 从检查点重试   F5 重新启程", 12, Color(YELLOW, clampf((t - 3.8) / 0.6, 0.0, 1.0)))

func _draw_victory() -> void:
    var ending: float = float(state.get("ending", 0))
    draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, clampf((ending - 2.0) / 2.5, 0.0, 1.0)))
    if ending > 4.5:
        var box := Rect2(size.x * 0.5 - 250.0, size.y * 0.3, 500.0, 150.0)
        frame_box(box, 3)
        var lines: Array[String] = ["* 钟声之后", "* 声音仍在。记忆却止于此处。", "* 第一章结束"]
        var shown: float = (ending - 4.5) * TYPE_RATE
        var used: int = 0
        for i: int in lines.size():
            var count: int = clampi(int(shown) - used, 0, lines[i].length())
            used += lines[i].length()
            text(box.position + Vector2(22, 42 + i * 32), lines[i].substr(0, count), 12 if i else 24, YELLOW if i == 0 else WHITE)
        draw_heart(Vector2(size.x * 0.5 - 8.0, size.y * 0.3 + 168.0), 2, RED)
        centered(size.y * 0.3 + 205.0, "F5 重新启程   R 重试", 12, GRAY)

func map_point(at: Vector2, area: Rect2) -> Vector2:
    var bounds: Rect2 = Level.WORLD_BOUNDS
    var factor: float = minf(area.size.x / bounds.size.x, area.size.y / bounds.size.y)
    var origin: Vector2 = area.position + (area.size - bounds.size * factor) * 0.5
    return (origin + (at - bounds.position) * factor).round()

func _draw_map(rect: Rect2) -> void:
    draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.94))
    frame_box(rect, 3)
    centered(rect.position.y + 29, "钟堡 / 路线图", 24, YELLOW)
    centered(rect.position.y + 50, "悬链书库  ·  破碎回廊  ·  淤水墓廊", 12, GRAY)
    var area := Rect2(rect.position + Vector2(18, 70), rect.size - Vector2(36, 124))
    for platform: Rect2 in Level.PLATFORMS:
        var start: Vector2 = map_point(platform.position, area)
        var end: Vector2 = map_point(platform.end, area)
        draw_rect(Rect2(start, Vector2(maxf(2, end.x - start.x), maxf(2, minf(5, end.y - start.y)))), Color("c0c0c0"))
    for climb: Dictionary in Level.CLIMBABLES:
        var bounds: Rect2 = climb["rect"]
        draw_line(map_point(Vector2(bounds.get_center().x, bounds.position.y), area), map_point(Vector2(bounds.get_center().x, bounds.end.y), area), CYAN, 2)
    for water: Rect2 in Level.WATER_REGIONS:
        draw_line(map_point(water.position, area), map_point(Vector2(water.end.x, water.position.y), area), Color("3f7fff"), 3)
    var opened: Array = state.get("opened_doors", [])
    for door: Dictionary in Level.DOORS:
        var at: Vector2 = map_point(door["rect"].get_center(), area)
        draw_rect(Rect2(at - Vector2(2, 3), Vector2(4, 6)), DIM if door["id"] in opened else YELLOW)
    var collected: Dictionary = state.get("collected", {})
    for index: int in Level.SHARDS.size():
        if not collected.has(index):
            var at: Vector2 = map_point(Level.SHARDS[index], area)
            draw_rect(Rect2(at, Vector2(2, 2)), PURPLE)
    var shrine: Vector2 = map_point(Level.CHECKPOINT, area)
    draw_rect(Rect2(shrine - Vector2(3, 3), Vector2(6, 6)), YELLOW)
    var bell: Vector2 = map_point(Level.BOSS_POSITION, area)
    draw_rect(Rect2(bell - Vector2(3, 4), Vector2(6, 8)), ORANGE)
    var player_at: Vector2 = map_point(state.get("player_at", Level.SPAWN), area)
    draw_heart(player_at - Vector2(4, 4), 1, RED)
    text(rect.position + Vector2(18, rect.size.y - 31), "红心 你的位置    青线 铁链    蓝线 浅水    黄色 门 / 检查点", 12, WHITE, rect.size.x - 36)
    centered(rect.end.y - 12, "TAB 或 ESC 返回冒险", 12, YELLOW)

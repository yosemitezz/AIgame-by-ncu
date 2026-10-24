extends Control
## Integration-owned HUD: black/white pixel frame, only implemented game state.
const PixelFont = preload("res://presentation/pixel_font.gd")
var state: Dictionary = {}
var font: Font

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    process_mode = Node.PROCESS_MODE_ALWAYS
    texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    font = PixelFont.create()

func update_state(next: Dictionary) -> void:
    state = next
    queue_redraw()

func text(at: Vector2, value: String, size: int = 12, color: Color = Color.WHITE, width: float = -1) -> void:
    draw_string(font, at.round(), value, HORIZONTAL_ALIGNMENT_LEFT, width, size, color)

func frame_box(rect: Rect2, border: int = 1) -> void:
    draw_rect(rect, Color.WHITE)
    draw_rect(rect.grow(-border), Color.BLACK)

func _draw() -> void:
    if state.is_empty() or font == null:
        return
    var hp: int = int(state.get("hp", 0))
    var maximum: int = maxi(1, int(state.get("max_hp", 8)))
    var low: bool = hp <= 2
    frame_box(Rect2(8, 7, 624, 45), 2)
    text(Vector2(17, 25), "生命 %02d/%02d" % [hp, maximum], 12, Color("ff7373") if low else Color.WHITE)
    draw_rect(Rect2(17, 33, 112, 9), Color("4b2635"))
    draw_rect(Rect2(17, 33, 112 * float(hp) / maximum, 9), Color("ff7373") if low else Color("ffe181"))
    if low:
        text(Vector2(140, 41), "低血!", 12, Color("ff7373"))
    text(Vector2(205, 25), "碎片 %02d/%02d" % [state.get("shards", 0), state.get("total_shards", 12)])
    text(Vector2(360, 25), str(state.get("zone", "")), 12, Color.WHITE, 258)
    draw_rect(Rect2(360, 36, 260, 3), Color("383838"))
    draw_rect(Rect2(360, 36, 260 * float(state.get("progress", 0)), 3), Color.WHITE)
    if int(state.get("boss_hp", -1)) >= 0:
        frame_box(Rect2(8, 58, 624, 40))
        text(Vector2(17, 74), "钟楼守望者")
        draw_rect(Rect2(173, 65, 447, 9), Color("3a2634"))
        var boss_max: float = maxf(1, float(state.get("boss_max", 1)))
        draw_rect(Rect2(173, 65, 447 * float(state.get("boss_hp", 0)) / boss_max, 9), Color("db6868"))
        text(Vector2(17, 91), "架势")
        var guard: int = int(state.get("boss_guard", 0))
        var guard_max: int = maxi(1, int(state.get("boss_guard_max", 3)))
        var broken: bool = str(state.get("reaction", "")) == "guard_break"
        for i: int in guard_max:
            var ink := Color("d38fff") if broken else (Color("ffcc70") if i < guard else Color("393939"))
            draw_rect(Rect2(54 + i * 15, 82, 10, 10), ink)
        if broken:
            text(Vector2(113, 92), "破架 · 可反击", 12, Color("d38fff"))
        var names: Dictionary = {"fixed": "固定", "random": "随机", "rest": "休息 · 双方禁伤", "final": "终段"}
        text(Vector2(385, 91), names.get(str(state.get("section", "")), ""), 12, Color("a8eeeb") if state.get("safe", false) else Color.WHITE)
        for i: int in 8:
            draw_rect(Rect2(530 + i * 11, 83, 6, 6), Color("ffe181") if i == posmod(int(state.get("beat", 0)), 8) else Color("303030"))
    frame_box(Rect2(8, 312, 624, 48))
    text(Vector2(16, 327), str(state.get("hint", "")), 12, Color.WHITE, 606)
    text(Vector2(16, 349), "A/D 移动 · 空格 跳跃 · J 攻击 · K 弹刀")
    text(Vector2(391, 349), "S 蹲下 · SHIFT 冲刺 · R 重试 · ESC 暂停", 12, Color("b6b6b6"))
    var narration: String = str(state.get("narration", ""))
    if narration != "":
        frame_box(Rect2(16, 105, 608, 27))
        text(Vector2(25, 123), narration, 12, Color("e8dfbc"), 590)
    var parry_notice: String = str(state.get("parry_notice", ""))
    if parry_notice != "" and not state.get("safe", false):
        var labels: Dictionary = {"melee": "刀刃弹开", "projectile": "弹体反射", "guard_break": "破架"}
        text(Vector2(268, 153), str(labels.get(parry_notice, "")), 12, Color("e9b2ff"))
    if state.get("paused", false):
        draw_rect(Rect2(0, 0, 640, 360), Color(0, 0, 0, 0.9))
        frame_box(Rect2(92, 99, 456, 156), 2)
        text(Vector2(272, 143), "暂停", 24)
        text(Vector2(136, 181), "ESC 继续 · R 检查点 · F5 新旅程", 12)
        text(Vector2(160, 218), "F2 震屏开关 · M 声音开关", 12)
    elif state.get("outcome", "") == "defeat":
        draw_rect(Rect2(0, 0, 640, 360), Color(0, 0, 0, 0.9))
        text(Vector2(272, 145), "倒下了", 24, Color("ffabab"))
        text(Vector2(176, 188), "神龛记得归来的路。", 12)
        text(Vector2(170, 225), "R 检查点重试 · F5 新旅程", 12)
    elif state.get("outcome", "") == "victory":
        var ending: float = float(state.get("ending", 0))
        draw_rect(Rect2(0, 0, 640, 360), Color(0, 0, 0, clampf((ending - 2.0) / 2.5, 0, 1)))
        if ending > 4.5:
            text(Vector2(224, 143), "钟声止息", 24, Color("ffe181"))
            text(Vector2(194, 183), "声音仍在，记忆却没有归来。", 12)
            text(Vector2(248, 231), "第一章完成", 12)
            text(Vector2(194, 265), "F5 再次出发 · R 重试", 12)

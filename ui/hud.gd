extends Control
## Functional HUD only. Cursor may replace appearance while preserving update_state.
var state: Dictionary = {}
var font: Font
var hp_chrome: Texture2D = preload("res://assets/ui/chrome/hp_bar.png")
var boss_chrome: Texture2D = preload("res://assets/ui/chrome/boss_bar.png")

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    process_mode = Node.PROCESS_MODE_ALWAYS
    font = ThemeDB.fallback_font

func update_state(next: Dictionary) -> void:
    state = next
    queue_redraw()

func text(at: Vector2, value: String, size: int = 12, color: Color = Color("b6c1cf")) -> void:
    draw_string(font, at, value, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

func _draw() -> void:
    if state.is_empty() or font == null:
        return
    draw_rect(Rect2(0, 0, 640, 46), Color(0.025, 0.035, 0.075, 0.94))
    draw_line(Vector2(12, 45), Vector2(628, 45), Color("39475a"))
    text(Vector2(14, 17), "BELLKEEP", 13, Color("e9bb68"))
    draw_texture_rect(hp_chrome, Rect2(12, 21, 112, 17), false)
    for i: int in int(state.get("max_hp", 8)):
        var at := Vector2(15 + i * 13, 29)
        var ink := Color("72ece2") if i < int(state.get("hp", 0)) else Color("2b3850")
        draw_colored_polygon(PackedVector2Array([at, at + Vector2(4, -4), at + Vector2(8, 0), at + Vector2(4, 4)]), ink)
    text(Vector2(142, 32), "%02d / %02d SHARDS" % [state.get("shards", 0), state.get("total_shards", 12)], 11)
    text(Vector2(360, 18), state.get("zone", ""), 12, Color("d4dccf"))
    draw_rect(Rect2(360, 29, 264, 3), Color("29344a"))
    draw_rect(Rect2(360, 29, 264 * float(state.get("progress", 0)), 3), Color("679790"))
    if int(state.get("boss_hp", -1)) >= 0:
        text(Vector2(18, 63), "THE BELLKEEPER", 12, Color("e9bb68"))
        var section: String = str(state.get("section", ""))
        text(Vector2(373, 63), section.to_upper() + (" / NO DAMAGE" if state.get("safe", false) else " / CONTACT PARRY"), 11, Color("72ece2") if section == "rest" else Color("a9b6c8"))
        draw_texture_rect(boss_chrome, Rect2(14, 66, 612, 14), false)
        draw_rect(Rect2(18, 70, 604, 5), Color("263149"))
        var maximum: float = maxf(1, float(state.get("boss_max", 1)))
        draw_rect(Rect2(18, 70, 604 * float(state.get("boss_hp", 0)) / maximum, 5), Color("c47c65"))
        for i: int in 16:
            var ink := Color("f5d590") if i == posmod(int(state.get("beat", 0)), 16) else Color("36435a")
            draw_rect(Rect2(18 + i * 10, 82, 6, 3), ink)
    draw_rect(Rect2(0, 312, 640, 48), Color(0.025, 0.035, 0.075, 0.93))
    text(Vector2(14, 327), str(state.get("hint", "")), 11, Color("a9b6c8"))
    text(Vector2(14, 348), "A/D  MOVE    SPACE  JUMP x2    SHIFT  DASH    J  CUT    K  PARRY", 11, Color("72b6ba"))
    text(Vector2(468, 348), "R RETRY  /  ESC PAUSE", 10, Color("7f8ca5"))
    var narration: String = str(state.get("narration", ""))
    if narration != "":
        draw_rect(Rect2(16, 101, 608, 29), Color(0.025, 0.035, 0.075, 0.93))
        draw_rect(Rect2(16, 101, 3, 29), Color("e9bb68"))
        text(Vector2(27, 120), narration, 12, Color("d9d9bb"))
    if state.get("paused", false):
        draw_rect(Rect2(0, 0, 640, 360), Color(0.025, 0.035, 0.075, 0.85))
        text(Vector2(249, 152), "PAUSED", 25, Color("e9bb68"))
        text(Vector2(156, 189), "ESC resume  /  R checkpoint  /  F5 new journey", 14)
        text(Vector2(224, 219), "M toggles original score", 12)
    elif state.get("outcome", "") == "defeat":
        draw_rect(Rect2(0, 0, 640, 360), Color(0.025, 0.035, 0.075, 0.78))
        text(Vector2(250, 145), "FALLEN", 27, Color("efb59a"))
        text(Vector2(161, 185), "The shrine remembers the way back.", 16)
        text(Vector2(169, 223), "R  checkpoint    /    F5  new journey", 14, Color("72ece2"))
    elif state.get("outcome", "") == "victory":
        var ending: float = float(state.get("ending", 0))
        var fade: float = clampf((ending - 2.0) / 2.5, 0, 1)
        draw_rect(Rect2(0, 0, 640, 360), Color(0.01, 0.012, 0.025, fade))
        if ending > 4.5:
            text(Vector2(201, 143), "THE BELL FALLS SILENT", 20, Color("e9bb68"))
            text(Vector2(182, 181), "The voice remains. The memory does not.", 14)
            text(Vector2(202, 230), "FIRST CHAPTER COMPLETE", 14, Color("72ece2"))
            text(Vector2(219, 264), "F5  begin again  /  R retry", 12)

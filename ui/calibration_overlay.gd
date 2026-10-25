extends Control
## Full-screen calibration panel. It never reads input; the room owns taps and skip.

const PixelFont = preload("res://presentation/pixel_font.gd")

var _font: Font
var _tap_count: int = 0
var _target_count: int = 5
var _message: String = ""
var _result: String = ""

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _font = PixelFont.create()
    visible = false

func present(prompt: String = "") -> void:
    visible = true
    _tap_count = 0
    _result = ""
    _message = prompt
    queue_redraw()

func dismiss() -> void:
    visible = false
    _message = ""
    _result = ""
    queue_redraw()

func set_progress(count: int, total: int = 5) -> void:
    _tap_count = clampi(count, 0, total)
    _target_count = maxi(1, total)
    queue_redraw()

func set_retry(message: String) -> void:
    _message = message
    _result = ""
    queue_redraw()

func show_result(message: String) -> void:
    _result = message
    queue_redraw()

func _draw() -> void:
    if not visible or _font == null:
        return
    var viewport: Vector2 = size if size.x > 0.0 else get_viewport_rect().size
    var panel := Rect2(Vector2(82, 74), Vector2(maxf(320.0, viewport.x - 164.0), 188))
    draw_rect(Rect2(Vector2.ZERO, viewport), Color(0.01, 0.015, 0.03, 0.44))
    draw_rect(panel, Color(0.025, 0.035, 0.06, 0.96))
    draw_rect(panel, Color("6fe8d8"), false, 1.0)
    _text(Vector2(panel.position.x + 18, panel.position.y + 25), "节拍校准", 16, Color("f4f1dd"))
    _text(Vector2(panel.position.x + 18, panel.position.y + 49), "听到重鼓时按任意键；每轮重新校准。", 11, Color("b8c2ca"))
    if not _message.is_empty():
        _text(Vector2(panel.position.x + 18, panel.position.y + 73), _message, 10, Color("f0b45f"))
    var spacing: float = 38.0
    var start_x: float = panel.position.x + (panel.size.x - spacing * (float(_target_count) - 1.0)) * 0.5
    for index: int in _target_count:
        var center := Vector2(start_x + spacing * float(index), panel.position.y + 112)
        var filled: bool = index < _tap_count
        var ink: Color = Color("73f6df") if filled else Color("465263")
        draw_colored_polygon(PackedVector2Array([center + Vector2(0, -7), center + Vector2(7, 0), center + Vector2(0, 7), center + Vector2(-7, 0)]), ink)
    _text(Vector2(panel.position.x + 18, panel.position.y + 142), "重鼓  %d / %d" % [_tap_count, _target_count], 11, Color("f4f1dd"))
    if not _result.is_empty():
        draw_rect(Rect2(panel.position.x + 14, panel.position.y + 150, panel.size.x - 28, 1), Color("2f5a5a"))
        _text(Vector2(panel.position.x + 18, panel.position.y + 170), _result, 12, Color("73f6df"))

func _text(at: Vector2, value: String, font_size: int, ink: Color) -> void:
    draw_string(_font, at.round(), value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, ink)

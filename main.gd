extends Node2D

func _draw() -> void:
    draw_rect(Rect2(0, 0, 640, 360), Color("0c1025"))
    draw_rect(Rect2(0, 300, 640, 60), Color("2d3552"))
    draw_string(ThemeDB.fallback_font, Vector2(66, 140), "BELLKEEP / SHATTERED REFRAIN", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color("ebc879"))
    draw_string(ThemeDB.fallback_font, Vector2(67, 179), "Original 2D pixel adventure | Godot 4.7", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("8cdddc"))
    draw_string(ThemeDB.fallback_font, Vector2(67, 215), "Bootstrap milestone - gameplay integration follows", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("a1adc9"))

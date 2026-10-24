extends Theme
class_name PixelThemeFactory
## Builds a restrained Hollow-Knight-like pixel UI theme at runtime.
## Prefer calling PixelThemeFactory.make() until a .tres is authored in-editor.

const INK := Color("121018")
const BONE := Color("d6ccba")
const CLOAK := Color("344062")
const CLOAK_HI := Color("4e6294")
const GOLD := Color("e0b048")
const ASH := Color("767080")


static func make() -> Theme:
	var theme := Theme.new()
	theme.set_color("font_color", "Label", BONE)
	theme.set_color("font_outline_color", "Label", INK)
	theme.set_constant("outline_size", "Label", 2)

	theme.set_color("font_color", "Button", BONE)
	theme.set_color("font_hover_color", "Button", GOLD)
	theme.set_color("font_focus_color", "Button", GOLD)
	theme.set_color("font_disabled_color", "Button", ASH)
	theme.set_color("font_pressed_color", "Button", Color("f0e6d2"))

	var normal := _panel(CLOAK, BONE)
	var hover := _panel(CLOAK_HI, GOLD)
	var pressed := _panel(Color("b06836"), GOLD)
	var disabled := _panel(Color("242030"), ASH)
	theme.set_stylebox("normal", "Button", normal)
	theme.set_stylebox("hover", "Button", hover)
	theme.set_stylebox("focus", "Button", hover)
	theme.set_stylebox("pressed", "Button", pressed)
	theme.set_stylebox("disabled", "Button", disabled)

	theme.set_stylebox("panel", "PanelContainer", _panel(Color("1c1628cc"), BONE))
	return theme


static func _panel(bg: Color, border: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = border
	box.set_border_width_all(2)
	box.set_content_margin_all(8)
	box.corner_radius_top_left = 0
	box.corner_radius_top_right = 0
	box.corner_radius_bottom_left = 0
	box.corner_radius_bottom_right = 0
	return box

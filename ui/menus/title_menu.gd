extends Control
class_name TitleMenu

signal play_pressed
signal settings_pressed
signal quit_pressed

const GOLD := Color("e0b048")
const GOLD_L := Color("ecbc40")
const BRASS := Color("94683e")

@onready var _play: Button = %PlayButton
@onready var _settings: Button = %SettingsButton
@onready var _quit: Button = %QuitButton
var _clock: float = 0.0


func _ready() -> void:
	theme = PixelThemeFactory.make()
	theme.default_font = preload("res://presentation/pixel_font.gd").create()
	_play.pressed.connect(func() -> void: play_pressed.emit())
	_settings.pressed.connect(func() -> void: settings_pressed.emit())
	_quit.pressed.connect(func() -> void: quit_pressed.emit())
	for button: Button in [_play, _settings, _quit]:
		_style_button(button)
	_play.grab_focus()
	_play.focus_neighbor_bottom = _settings.get_path()
	_settings.focus_neighbor_top = _play.get_path()
	_settings.focus_neighbor_bottom = _quit.get_path()
	_quit.focus_neighbor_top = _settings.get_path()


func _process(delta: float) -> void:
	_clock += delta
	queue_redraw()


func _draw() -> void:
	var focused: Control = get_viewport().gui_get_focus_owner()
	if focused not in [_play, _settings, _quit]:
		return
	var button := focused as Button
	var rect := Rect2(button.global_position - global_position, button.size)
	var frame := rect.grow(2.0)
	for corner: Vector2 in [frame.position, Vector2(frame.end.x, frame.position.y), Vector2(frame.position.x, frame.end.y), frame.end]:
		var sx: float = 1.0 if corner.x <= frame.position.x else -1.0
		var sy: float = 1.0 if corner.y <= frame.position.y else -1.0
		draw_rect(Rect2(corner + Vector2(0.0 if sx > 0 else -8.0, 0.0 if sy > 0 else -1.0), Vector2(8, 1)), GOLD_L)
		draw_rect(Rect2(corner + Vector2(0.0 if sx > 0 else -1.0, 0.0 if sy > 0 else -8.0), Vector2(1, 8)), GOLD_L)
	var arrow_x: float = rect.end.x + 9.0 + sin(_clock * 5.0) * 1.5
	var arrow_y: float = rect.get_center().y
	for row: int in 5:
		var width: int = 5 - absi(row - 2)
		draw_rect(Rect2(arrow_x, arrow_y + row - 2, width, 1), GOLD_L)


func _style_button(button: Button) -> void:
	button.add_theme_stylebox_override("normal", _button_style(Color("121020"), BRASS, 1))
	button.add_theme_stylebox_override("hover", _button_style(Color("2a2038"), GOLD, 2))
	button.add_theme_stylebox_override("pressed", _button_style(Color("1d1529"), GOLD_L, 2))
	button.add_theme_stylebox_override("focus", _button_style(Color(0, 0, 0, 0), GOLD, 1))
	button.add_theme_color_override("font_color", Color("9ca4ba"))
	button.add_theme_color_override("font_hover_color", Color("f0e6d2"))
	button.add_theme_color_override("font_pressed_color", GOLD_L)
	button.add_theme_color_override("font_focus_color", Color("f0e6d2"))


func _button_style(fill: Color, border: Color, width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(width)
	style.content_margin_left = 34.0
	style.content_margin_right = 20.0
	return style


func set_actions_enabled(enabled: bool) -> void:
	for button: Button in [_play, _settings, _quit]:
		button.disabled = not enabled
		button.focus_mode = Control.FOCUS_ALL if enabled else Control.FOCUS_NONE


func focus_settings() -> void:
	_settings.grab_focus()

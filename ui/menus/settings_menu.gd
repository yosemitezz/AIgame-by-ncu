extends Control
class_name SettingsMenu

signal closed

const GOLD := Color("e0b048")
const GOLD_L := Color("ecbc40")
const BRASS := Color("94683e")

@onready var _master: HSlider = %MasterSlider
@onready var _music: HSlider = %MusicSlider
@onready var _sfx: HSlider = %SfxSlider
@onready var _window: OptionButton = %WindowOption
@onready var _back: Button = %BackButton
@onready var _master_value: Label = %MasterValue


func _ready() -> void:
	theme = PixelThemeFactory.make()
	theme.default_font = preload("res://presentation/pixel_font.gd").create()
	_style_menu()
	_ensure_bus("Music")
	_ensure_bus("SFX")
	_master.set_value_no_signal(db_to_linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Master"))) * 100.0)
	_music.set_value_no_signal(db_to_linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Music"))) * 100.0)
	_sfx.set_value_no_signal(db_to_linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("SFX"))) * 100.0)
	_window.clear()
	_window.add_item("窗口")
	_window.add_item("全屏")
	_window.selected = 1 if get_window().mode == Window.MODE_FULLSCREEN else 0
	_master.value_changed.connect(_on_master)
	_music.value_changed.connect(_on_music)
	_sfx.value_changed.connect(_on_sfx)
	_window.item_selected.connect(_on_window)
	_back.pressed.connect(close_menu)
	visible = false
	_on_master(_master.value)


func _ensure_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) >= 0:
		return
	AudioServer.add_bus()
	AudioServer.set_bus_name(AudioServer.bus_count - 1, bus_name)


func _style_menu() -> void:
	var panel := _style(Color("0d0814"), Color("c08a4a"), 1)
	panel.set_content_margin_all(14)
	$Center/Panel.add_theme_stylebox_override("panel", panel)
	var heading := $Center/Panel/VBox/Label as Label
	heading.add_theme_color_override("font_color", GOLD_L)
	heading.add_theme_font_size_override("font_size", 24)
	for button: Button in [_back, _window]:
		button.add_theme_stylebox_override("normal", _style(Color("1a1428"), BRASS, 1))
		button.add_theme_stylebox_override("hover", _style(Color("2a2038"), GOLD, 1))
		button.add_theme_stylebox_override("pressed", _style(Color("1d1529"), GOLD_L, 1))
		button.add_theme_stylebox_override("focus", _style(Color(0, 0, 0, 0), GOLD, 1))
		button.add_theme_color_override("font_color", Color("d6ccba"))
		button.add_theme_color_override("font_hover_color", GOLD_L)
		button.add_theme_color_override("font_pressed_color", GOLD_L)
	var rail := _style(Color("242030"), Color.TRANSPARENT, 0)
	rail.content_margin_top = 2.0
	rail.content_margin_bottom = 2.0
	var fill := _style(BRASS, Color.TRANSPARENT, 0)
	fill.content_margin_top = 2.0
	fill.content_margin_bottom = 2.0
	theme.set_stylebox("slider", "HSlider", rail)
	theme.set_stylebox("grabber_area", "HSlider", fill)
	theme.set_stylebox("grabber_area_highlight", "HSlider", fill)


func _style(fill: Color, border: Color, width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(width)
	return style


func open_menu() -> void:
	visible = true
	_back.grab_focus()


func close_menu() -> void:
	visible = false
	closed.emit()


func _on_master(value: float) -> void:
	_master_value.text = "%d%%" % int(value)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), linear_to_db(value * 0.01))


func _on_music(value: float) -> void:
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), linear_to_db(value * 0.01))


func _on_sfx(value: float) -> void:
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"), linear_to_db(value * 0.01))


func _on_window(index: int) -> void:
	get_window().mode = Window.MODE_FULLSCREEN if index == 1 else Window.MODE_WINDOWED

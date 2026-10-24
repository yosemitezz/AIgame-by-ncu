extends Control
class_name TitleMenu

signal play_pressed
signal settings_pressed
signal quit_pressed

@onready var _play: Button = %PlayButton
@onready var _settings: Button = %SettingsButton
@onready var _quit: Button = %QuitButton


func _ready() -> void:
	theme = PixelThemeFactory.make()
	_play.pressed.connect(func() -> void: play_pressed.emit())
	_settings.pressed.connect(func() -> void: settings_pressed.emit())
	_quit.pressed.connect(func() -> void: quit_pressed.emit())
	_play.grab_focus()
	_play.focus_neighbor_bottom = _settings.get_path()
	_settings.focus_neighbor_top = _play.get_path()
	_settings.focus_neighbor_bottom = _quit.get_path()
	_quit.focus_neighbor_top = _settings.get_path()

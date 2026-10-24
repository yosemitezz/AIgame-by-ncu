extends Control
class_name SettingsMenu

signal closed

@onready var _master: HSlider = %MasterSlider
@onready var _music: HSlider = %MusicSlider
@onready var _sfx: HSlider = %SfxSlider
@onready var _window: OptionButton = %WindowOption
@onready var _back: Button = %BackButton
@onready var _master_value: Label = %MasterValue


func _ready() -> void:
	theme = PixelThemeFactory.make()
	_window.clear()
	_window.add_item("Windowed")
	_window.add_item("Fullscreen")
	_master.value_changed.connect(_on_master)
	_back.pressed.connect(func() -> void:
		visible = false
		closed.emit()
	)
	visible = false
	_on_master(_master.value)


func open_menu() -> void:
	visible = true
	_back.grab_focus()


func _on_master(value: float) -> void:
	_master_value.text = "%d%%" % int(value)

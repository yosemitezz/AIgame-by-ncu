extends Control
class_name PauseMenu

signal resume_pressed
signal settings_pressed
signal retry_pressed
signal title_pressed

@onready var _resume: Button = %ResumeButton
@onready var _settings: Button = %SettingsButton
@onready var _retry: Button = %RetryButton
@onready var _title: Button = %TitleButton


func _ready() -> void:
	theme = PixelThemeFactory.make()
	_resume.pressed.connect(func() -> void: resume_pressed.emit())
	_settings.pressed.connect(func() -> void: settings_pressed.emit())
	_retry.pressed.connect(func() -> void: retry_pressed.emit())
	_title.pressed.connect(func() -> void: title_pressed.emit())
	visible = false


func open_menu() -> void:
	visible = true
	_resume.grab_focus()


func close_menu() -> void:
	visible = false

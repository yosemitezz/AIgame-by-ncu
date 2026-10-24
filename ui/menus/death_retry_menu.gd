extends Control
class_name DeathRetryMenu

signal retry_pressed
signal checkpoint_pressed
signal title_pressed

@onready var _retry: Button = %RetryButton
@onready var _checkpoint: Button = %CheckpointButton
@onready var _title: Button = %TitleButton
@onready var _blurb: Label = %BlurbLabel


func _ready() -> void:
	theme = PixelThemeFactory.make()
	_retry.pressed.connect(func() -> void: retry_pressed.emit())
	_checkpoint.pressed.connect(func() -> void: checkpoint_pressed.emit())
	_title.pressed.connect(func() -> void: title_pressed.emit())
	visible = false


func open_menu(message := "Fell in the Bellkeep.") -> void:
	_blurb.text = message
	visible = true
	_retry.grab_focus()

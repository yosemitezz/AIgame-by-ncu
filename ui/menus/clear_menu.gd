extends Control
class_name ClearMenu

signal continue_pressed
signal title_pressed

@onready var _continue: Button = %ContinueButton
@onready var _title: Button = %TitleButton
@onready var _title_label: Label = %TitleLabel


func _ready() -> void:
	theme = PixelThemeFactory.make()
	_continue.pressed.connect(func() -> void: continue_pressed.emit())
	_title.pressed.connect(func() -> void: title_pressed.emit())
	visible = false


func open_menu(title := "Bellkeep Quiet.") -> void:
	_title_label.text = title
	visible = true
	_continue.grab_focus()

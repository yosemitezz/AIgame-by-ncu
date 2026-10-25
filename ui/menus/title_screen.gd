extends Control
class_name TitleScreen

@onready var _title: TitleMenu = %TitleMenu
@onready var _settings: SettingsMenu = %SettingsMenu
var _starting: bool = false

func _ready() -> void:
    _title.play_pressed.connect(_start_game)
    _title.settings_pressed.connect(_open_settings)
    _title.quit_pressed.connect(get_tree().quit)
    _settings.closed.connect(_on_settings_closed)

func _open_settings() -> void:
    _title.set_actions_enabled(false)
    _settings.open_menu()

func _on_settings_closed() -> void:
    _title.set_actions_enabled(true)
    _title.focus_settings()

func _unhandled_input(event: InputEvent) -> void:
    if _settings.visible and event.is_action_pressed("ui_cancel"):
        _settings.close_menu()
        get_viewport().set_input_as_handled()

func _start_game() -> void:
    if _starting:
        return
    _starting = true
    get_tree().change_scene_to_file("res://main.tscn")

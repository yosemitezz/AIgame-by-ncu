extends Control
## HUD + menu gallery driven by a mock state clock (preview only).

@onready var _hud: BattleHUD = %BattleHud
@onready var _title: TitleMenu = %TitleMenu
@onready var _pause: PauseMenu = %PauseMenu
@onready var _settings: SettingsMenu = %SettingsMenu
@onready var _death: DeathRetryMenu = %DeathRetryMenu
@onready var _clear: ClearMenu = %ClearMenu
@onready var _back: Button = %BackButton
@onready var _note: Label = %NoteLabel

var _t := 0.0
var _section_idx := 0
const SECTIONS := ["fixed", "random", "rest"]


func _ready() -> void:
	theme = PixelThemeFactory.make()
	_back.pressed.connect(func() -> void:
		get_tree().change_scene_to_file("res://scenes/showcase_hub.tscn")
	)
	_title.play_pressed.connect(func() -> void:
		_title.visible = false
		_note.text = "Title → Play (preview). HUD listening to mock state."
	)
	_title.settings_pressed.connect(func() -> void: _settings.open_menu())
	_pause.settings_pressed.connect(func() -> void: _settings.open_menu())
	_pause.resume_pressed.connect(func() -> void: _pause.close_menu())
	_settings.closed.connect(func() -> void: _back.grab_focus())
	_death.retry_pressed.connect(func() -> void:
		_death.visible = false
		_note.text = "Retry requested (no gameplay restart here)."
	)
	_clear.continue_pressed.connect(func() -> void:
		_clear.visible = false
	)
	_title.visible = true
	_apply_mock(0.75, 0.55, 0.82, "I", "fixed", 0)
	_note.text = "P pause · R death · C clear · mock bars animate · UI does not own HP"


func _process(delta: float) -> void:
	_t += delta
	var pulse := 0.55 + 0.35 * sin(_t * 1.4)
	var boss := 0.85 - fmod(_t * 0.04, 0.7)
	if int(_t) % 8 == 0 and int(_t - delta) % 8 != 0:
		_section_idx = (_section_idx + 1) % SECTIONS.size()
	_apply_mock(pulse, 0.4 + 0.3 * cos(_t), boss, "II" if boss < 0.45 else "I", SECTIONS[_section_idx], int(_t * 2.0))


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().change_scene_to_file("res://scenes/showcase_hub.tscn")
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_P:
				_pause.open_menu()
			KEY_R:
				_death.open_menu()
			KEY_C:
				_clear.open_menu()


func _apply_mock(hp_ratio: float, mp_ratio: float, boss_ratio: float, phase: String, section: String, beat: int) -> void:
	var hint := "Rest — narrative space" if section == "rest" else "Parry on cyan flashes"
	_hud.apply_state({
		"hp": int(100 * hp_ratio),
		"max_hp": 100,
		"mp": int(50 * mp_ratio),
		"max_mp": 50,
		"boss_hp": int(1000 * boss_ratio),
		"boss_max": 1000,
		"boss_name": "BELL TITAN",
		"zone": "Bellkeep Outer",
		"hint": hint,
		"phase": phase,
		"section": section,
		"beat": beat,
		"shards": 3,
		"outcome": "",
	})

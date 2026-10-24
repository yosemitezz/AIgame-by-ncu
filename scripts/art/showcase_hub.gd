extends Control
## Hub for art-only showcase scenes. Does not touch combat simulation.

@onready var _status: Label = %StatusLabel
@onready var _buttons: VBoxContainer = %NavButtons

const PAGES := [
	{"id": "hero", "title": "Hero Contact", "scene": "res://scenes/showcase_hero.tscn"},
	{"id": "vfx", "title": "VFX Board", "scene": "res://scenes/showcase_vfx.tscn"},
	{"id": "hud", "title": "HUD / Menus", "scene": "res://scenes/showcase_hud.tscn"},
	{"id": "world", "title": "Env Layers", "scene": "res://scenes/showcase_world.tscn"},
]


func _ready() -> void:
	theme = PixelThemeFactory.make()
	for page in PAGES:
		var btn := Button.new()
		btn.text = page["title"]
		btn.focus_mode = Control.FOCUS_ALL
		btn.pressed.connect(_open.bind(page["scene"], page["title"]))
		_buttons.add_child(btn)
	if _buttons.get_child_count() > 0:
		(_buttons.get_child(0) as Control).grab_focus()
	_status.text = "Art preview · cursor/art-ui · A/D or arrows switch focus · Enter open"


func _open(path: String, title: String) -> void:
	_status.text = "Opening %s…" % title
	get_tree().change_scene_to_file(path)

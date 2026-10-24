extends Node2D
## VFX board: slash / parry / dash ghost / debris / charge / burst + zone legend.

@onready var _grid: GridContainer = %VfxGrid
@onready var _legend: Label = %Legend
@onready var _back: Button = %BackButton

const GROUPS := [
	{"folder": "slash", "prefix": "slash", "count": 3, "label": "slash"},
	{"folder": "parry", "prefix": "parry", "count": 3, "label": "parry spark"},
	{"folder": "dash", "prefix": "dash_ghost", "count": 3, "label": "dash ghost"},
	{"folder": "hit", "prefix": "debris", "count": 3, "label": "hit debris"},
	{"folder": "charge", "prefix": "charge", "count": 3, "label": "charge"},
	{"folder": "burst", "prefix": "burst", "count": 4, "label": "burst"},
]


func _ready() -> void:
	_back.pressed.connect(func() -> void:
		get_tree().change_scene_to_file("res://scenes/showcase_hub.tscn")
	)
	_back.grab_focus()
	_legend.text = "Amber hatch = telegraph only · Coral outline = real damage · Cyan = parry/reflected · Never cover safe lanes"
	for group in GROUPS:
		for i in group["count"]:
			var tex_path := "res://assets/vfx/%s/%s_%d.png" % [group["folder"], group["prefix"], i]
			var holder := VBoxContainer.new()
			var spr := TextureRect.new()
			spr.texture = load(tex_path) as Texture2D
			spr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			spr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			spr.custom_minimum_size = Vector2(96, 96)
			spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			var lab := Label.new()
			lab.text = "%s %d" % [group["label"], i]
			holder.add_child(spr)
			holder.add_child(lab)
			_grid.add_child(holder)
	_add_zone("res://assets/vfx/zones/telegraph_warn.png", "WARN telegraph")
	_add_zone("res://assets/vfx/zones/damage_arcane.png", "DAMAGE zone")


func _add_zone(path: String, title: String) -> void:
	var holder := VBoxContainer.new()
	var spr := TextureRect.new()
	spr.texture = load(path) as Texture2D
	spr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	spr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	spr.custom_minimum_size = Vector2(160, 48)
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var lab := Label.new()
	lab.text = title
	holder.add_child(spr)
	holder.add_child(lab)
	_grid.add_child(holder)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().change_scene_to_file("res://scenes/showcase_hub.tscn")

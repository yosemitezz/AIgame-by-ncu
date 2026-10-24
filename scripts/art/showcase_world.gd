extends Node2D
## Environment layer demo — backdrop / architecture / floor / foreground / checkpoint.
## Not a greybox level; proves tiles read as a traversable strip.

@onready var _back: Button = %BackButton
@onready var _caption: Label = %Caption


func _ready() -> void:
	_back.pressed.connect(func() -> void:
		get_tree().change_scene_to_file("res://scenes/showcase_hub.tscn")
	)
	_back.grab_focus()
	_caption.text = "Far night → mid brick → floor → foliage FG → checkpoint. Side-view tiles per COLLAB."
	_build_strip()


func _build_strip() -> void:
	var layer_demo := load("res://assets/art/environment/layer_demo.png") as Texture2D
	var big := Sprite2D.new()
	big.texture = layer_demo
	big.centered = false
	big.position = Vector2(80, 180)
	big.scale = Vector2(4, 4)
	big.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(big)

	var hero := Sprite2D.new()
	hero.texture = load("res://assets/art/characters/hero/hero_run_0.png") as Texture2D
	hero.centered = false
	hero.position = Vector2(260, 260)
	hero.scale = Vector2(3, 3)
	hero.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(hero)

	var enemy := Sprite2D.new()
	enemy.texture = load("res://assets/art/characters/enemies/enemy_sentry.png") as Texture2D
	enemy.centered = false
	enemy.position = Vector2(520, 290)
	enemy.scale = Vector2(3, 3)
	enemy.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(enemy)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().change_scene_to_file("res://scenes/showcase_hub.tscn")

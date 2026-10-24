extends Node2D
## Plays hero pose cycle for art review. Animation names match handoff contract.

@onready var _sprite: Sprite2D = %HeroSprite
@onready var _label: Label = %PoseLabel
@onready var _back: Button = %BackButton

const POSES := [
	"idle_0", "idle_1", "run_0", "run_1", "windup_0", "attack_0",
	"recover_0", "hurt_0", "dash_0", "parry_0", "jump_0", "death_0",
]

var _index := 0
var _timer := 0.0


func _ready() -> void:
	_back.pressed.connect(func() -> void:
		get_tree().change_scene_to_file("res://scenes/showcase_hub.tscn")
	)
	_back.grab_focus()
	_show_pose()


func _process(delta: float) -> void:
	_timer += delta
	if _timer >= 0.55:
		_timer = 0.0
		_index = (_index + 1) % POSES.size()
		_show_pose()
	if Input.is_action_just_pressed("ui_cancel"):
		get_tree().change_scene_to_file("res://scenes/showcase_hub.tscn")


func _show_pose() -> void:
	var pose: String = POSES[_index]
	var path := "res://assets/art/characters/hero/hero_%s.png" % pose
	_sprite.texture = load(path) as Texture2D
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_label.text = "state frame: %s  |  pivot target (20,44)  |  canvas 40x48" % pose

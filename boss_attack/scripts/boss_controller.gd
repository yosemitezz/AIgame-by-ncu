extends Node2D
class_name BossController

signal health_changed(current: float, maximum: float)
signal defeated

var max_health := 3200.0
var health := 3200.0
var _hit_flash := 0.0

@onready var sprite: Sprite2D = get_node_or_null("Sprite2D")


func configure(config: Dictionary) -> void:
	max_health = float(config.get("combat", {}).get("boss_max_health", max_health))
	health = max_health
	health_changed.emit(health, max_health)


func set_visual_texture(texture: Texture2D) -> void:
	if sprite != null:
		sprite.texture = texture
		sprite.visible = texture != null
	queue_redraw()


func take_damage(amount: float) -> void:
	if health <= 0.0:
		return
	health = maxf(0.0, health - amount)
	_hit_flash = 0.12
	health_changed.emit(health, max_health)
	queue_redraw()
	if health <= 0.0:
		defeated.emit()


func _process(delta: float) -> void:
	if _hit_flash > 0.0:
		_hit_flash = maxf(0.0, _hit_flash - delta)
		queue_redraw()


func _draw() -> void:
	if sprite == null or sprite.texture == null:
		var color := Color("#ff5b6e") if _hit_flash <= 0.0 else Color.WHITE
		var points := PackedVector2Array([
			Vector2(-34, 18), Vector2(-26, -12), Vector2(-10, -27),
			Vector2(0, -40), Vector2(12, -24), Vector2(29, -14),
			Vector2(35, 19), Vector2(14, 31), Vector2(-12, 31),
		])
		draw_colored_polygon(points, color)
		draw_circle(Vector2(-12, -8), 4.0, Color("#fff3c4"))
		draw_circle(Vector2(12, -8), 4.0, Color("#fff3c4"))
		draw_line(Vector2(-8, 12), Vector2(8, 12), Color("#64162d"), 3.0)

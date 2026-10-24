extends RefCounted
## Integration-owned adapter. Sprite timing is supplied by actual combat phases.
const Renderer = preload("res://presentation/actor_renderer.gd")

static func paint(canvas: Node2D, kind: String, state: String, frame: int, facing: int) -> void:
    Renderer.paint(canvas, kind, state, frame, facing)

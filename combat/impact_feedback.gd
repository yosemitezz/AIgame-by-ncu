extends Node
## Directional kick / trauma decay adapted from CodingQuests PlayerCamera.gd,
## commit 7ccc10925a07960772d83db970d56fef875a983d (MIT).
## See third_party/codingquests/LICENSE and THIRD_PARTY_NOTICES.md.
## Hit-stop is deliberately actor-local: music and projectiles keep their clocks.
const Sounds = preload("res://audio/impact_sfx.gd")
var game: Node
var sounds: Node
## Camera limits in native pixels (the game renders at 640x360). Raised from 3.4 / 4 for heavier hits.
const MAX_KICK: float = 11.0
const MAX_OFFSET: float = 13.0
## Camera zoom punch: every blow pushes the frame in a little, then it eases back. Heavy hits push harder.
const MAX_PUNCH: float = 0.075
var _punch: float = 0.0
var reduced_motion: bool = false
var _kick: Vector2 = Vector2.ZERO
var _trauma: float = 0.0
var _time: float = 0.0
var impact_count: int = 0

func configure(owner_game: Node) -> void:
    game = owner_game
    sounds = Sounds.new()
    add_child(sounds)

func request(source: Node, target: Node, heavy: bool = false, parry: bool = false, variant: String = "") -> void:
    if is_instance_valid(game) and bool(game.story_safe):
        return
    var duration: float = 0.1 if variant == "break" else (0.06 if variant == "reflect" else (0.08 if parry else (0.115 if heavy else 0.058)))
    if is_instance_valid(source) and source.has_method("set_impact_freeze"):
        source.set_impact_freeze(duration)
    if is_instance_valid(target) and target != source and target.has_method("set_impact_freeze"):
        target.set_impact_freeze(duration)
    var direction := Vector2.RIGHT
    if source is Node2D and target is Node2D:
        direction = (target.global_position - source.global_position).normalized()
    elif is_instance_valid(source) and source.get("facing") != null:
        direction = Vector2(float(source.get("facing")), 0)
    add_kick(direction, 10.0 if variant == "break" else (4.4 if variant == "reflect" else (7.0 if parry else (7.5 if heavy else 3.6))))
    _punch = minf(MAX_PUNCH, _punch + (0.06 if variant == "break" else (0.03 if variant == "reflect" else (0.045 if parry else (0.07 if heavy else 0.026)))))
    _trauma = clampf(_trauma + (1.0 if variant == "break" else (0.75 if parry else (0.6 if heavy else 0.4))), 0, 1.0)
    impact_count += 1
    if is_instance_valid(sounds):
        sounds.play_impact("break" if variant == "break" else ("reflect" if variant == "reflect" else ("parry" if parry else ("heavy" if heavy else "light"))))

func add_kick(direction: Vector2, amount: float) -> void:
    if direction.length() > 0.001:
        _kick = (_kick + direction.normalized() * amount).limit_length(MAX_KICK)

func sample_camera(delta: float) -> Vector2:
    # Adapted decay/noise from PlayerCamera; capped at MAX_OFFSET native pixels, no roll/zoom.
    # Kick decays slower than before so a heavy blow visibly rocks the frame, then settles.
    _kick = _kick.move_toward(Vector2.ZERO, _kick.length() * 9.0 * delta + 6.0 * delta)
    _time += delta
    _trauma = maxf(_trauma - 1.8 * delta, 0.0)
    var shake: float = _trauma * _trauma
    var offset: Vector2 = _kick + Vector2(_noise(_time * 42, 1), _noise(_time * 42, 13)) * 11.0 * shake
    return Vector2.ZERO if reduced_motion else offset.limit_length(MAX_OFFSET)

func sample_zoom(delta: float) -> float:
    ## Zoom factor for the camera (1.0 = none). Decays fast so it reads as a punch, not a zoom.
    _punch = maxf(_punch - (0.45 * delta + _punch * 7.0 * delta), 0.0)
    return 1.0 if reduced_motion else 1.0 + _punch

func _noise(t: float, seed_offset: float) -> float:
    return sin(t + seed_offset) * cos(t * 0.7 + seed_offset * 2.0)

func play_action(kind: String) -> void:
    if is_instance_valid(sounds):
        sounds.play_impact(kind)

func clear() -> void:
    _kick = Vector2.ZERO
    _punch = 0.0
    _trauma = 0

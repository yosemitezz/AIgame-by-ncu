## Legacy node name retained for main/F3; no SCREEN_UV or screen texture is sampled.
extends CanvasLayer
## Background-only native-pixel motion accents; camera lead is returned, never applied here.
const MAX_MARKS: int = 64
var enabled_by_user: bool = true
var _background: Node2D
var game: Node
var _marks: Array[Dictionary] = []
var _lead: float = 0.0
var _clock: float = 0.0
var _spawn_clock: float = 0.0
var _last_at: Vector2 = Vector2.INF
var _rng := RandomNumberGenerator.new()

func setup(owner_game: Node) -> void:
	configure(owner_game)

func configure(owner_game: Node) -> void:
	game = owner_game
	process_mode = Node.PROCESS_MODE_PAUSABLE
	layer = -10
	if not is_instance_valid(_background):
		_background = Node2D.new()
		_background.name = "BackgroundSpeedLines"
		_background.z_as_relative = false
		_background.z_index = 1
		_background.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		game.add_child(_background)
		_background.draw.connect(func() -> void: _draw_background(_background))
	_rng.seed = 20261025

func _level() -> int:
	var value: Variant = game.get("speed_effects_level") if is_instance_valid(game) else null
	return clampi(int(value), 0, 2) if value != null else 1

func _blocked() -> bool:
	if not is_instance_valid(game) or not is_instance_valid(game.get("player")):
		return true
	if not enabled_by_user or _level() == 0 or bool(game.get("story_safe")) or bool(game.get("_paused")) or get_tree().paused:
		return true
	var overlay: Variant = game.get("_overlay")
	if overlay != null and String(overlay) != "":
		return true
	var impact: Variant = game.get("impact")
	return impact != null and is_instance_valid(impact) and bool(impact.get("reduced_motion"))

func clear() -> void:
	_marks.clear()
	_lead = 0.0
	_spawn_clock = 0.0
	_last_at = Vector2.INF
	if is_instance_valid(_background):
		_background.queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_PAUSED:
		clear()

func sample_camera_lead(delta: float) -> float:
	if _blocked():
		clear()
		return 0.0
	var player: Node2D = game.get("player")
	var dash: bool = float(player.get("dash_timer")) > 0.0
	var attack: bool = String(player.get("attack_phase")) == "active"
	var facing: float = -1.0 if int(player.get("facing")) < 0 else 1.0
	var target: float = facing * (24.0 if dash else (12.0 if attack else 0.0))
	_lead = move_toward(_lead, target, (480.0 if absf(target) > absf(_lead) else 360.0) * maxf(delta, 0.0))
	return clampf(_lead, -24.0, 24.0)

func _process(delta: float) -> void:
	if _blocked():
		clear()
		return
	_clock += delta
	for index: int in range(_marks.size() - 1, -1, -1):
		_marks[index]["life"] = float(_marks[index]["life"]) - delta
		if float(_marks[index]["life"]) <= 0.0:
			_marks.remove_at(index)
	var player: Node2D = game.get("player")
	var velocity: Vector2 = player.get("velocity")
	var dash: bool = float(player.get("dash_timer")) > 0.0
	var attack: bool = String(player.get("attack_phase")) == "active"
	var moving: bool = absf(velocity.x) > 140.0 or dash or attack
	_spawn_clock -= delta
	if moving and _spawn_clock <= 0.0 and (_last_at == Vector2.INF or _last_at.distance_to(player.global_position) >= 6.0):
		_spawn_clock = 0.018 if _level() == 2 else 0.035
		_last_at = player.global_position
		var direction: float = -1.0 if int(player.get("facing")) < 0 else 1.0
		for index: int in (4 if _level() == 2 else 2):
			if _marks.size() >= MAX_MARKS:
				break
			var offset := Vector2(-direction * _rng.randf_range(100, 290), _rng.randf_range(-150, -70) if index % 2 == 0 else _rng.randf_range(18, 50))
			_marks.append({"at": (player.global_position + offset).round(), "life": 0.12, "max": 0.12, "d": direction, "length": _rng.randi_range(12, 30) if dash else _rng.randi_range(6, 18), "edge": index % 3 == 2})
	if is_instance_valid(_background):
		_background.queue_redraw()

func is_active() -> bool:
	return not _marks.is_empty()

func _exit_tree() -> void:
	if is_instance_valid(_background):
		_background.queue_free()

func _draw_background(canvas: CanvasItem) -> void:
	for mark: Dictionary in _marks:
		var alpha: float = float(mark["life"]) / float(mark["max"]) * (0.25 if _level() == 2 else 0.16)
		var at: Vector2 = mark["at"]
		var back: Vector2 = Vector2(-float(mark["d"]) * float(mark["length"]), 0)
		canvas.draw_line(at, (at + back).round(), Color(0.48, 0.59, 0.66, alpha), 1.0, false)
		if bool(mark["edge"]):
			canvas.draw_line(at, at + Vector2(0, -3), Color(0.48, 0.59, 0.66, alpha), 1.0, false)

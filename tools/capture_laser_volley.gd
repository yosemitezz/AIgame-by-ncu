extends SceneTree
## Static validation frames for half-beat volleys and one-shot center re-aim.
## No input replay and no audio playback; artifacts stay ignored.
const Planner = preload("res://combat/friend_rhythm/laser_formation_planner.gd")
const Hazard = preload("res://combat/boss_hazard.gd")

const WINDOW: float = 0.5 * 60.0 / 203.0
const OUTPUT_DIR: String = "res://artifacts/laser-volley"

class Clock extends Node:
	var time: float = 0.0
	func get_score_time() -> float: return time

class ProbePlayer extends Node2D:
	var dead: bool = false
	var health: int = 8
	func receive_hit(_amount: int, _at: Vector2) -> void: pass

class ProbeBoss extends Node:
	var dead: bool = false
	var hazard_generation: int = 1
	var player: Node2D
	func get_laser_arena() -> Rect2:
		return Rect2(player.global_position - Vector2(360.0, 240.0), Vector2(720.0, 440.0))

class CaptureGame extends Node2D:
	var music: Node
	var player: ProbePlayer
	var story_safe: bool = false
	var _paused: bool = false
	var outcome: String = ""
	func emit_fx(_kind: String, _at: Vector2, _direction: Vector2 = Vector2.ZERO, _power: float = 1.0) -> void: pass
	func damage_player(_amount: int, _at: Vector2) -> void: pass

func _initialize() -> void:
	call_deferred("run")

func config() -> Dictionary:
	return {"line_thickness": 9.0, "patterns": {"diamond": {"safe_radius": 44.0, "safe_offsets": [[0.0, 0.0]]}}}

func formation() -> Dictionary:
	var lasers: Array[Dictionary] = [
		{"time": 9.5, "damage_time": 10.5, "source_index": 0},
		{"time": 9.6, "damage_time": 10.6, "source_index": 1},
		{"time": 11.5, "damage_time": 12.5, "source_index": 2},
		{"time": 11.6, "damage_time": 12.6, "source_index": 3},
	]
	return {"index": 0, "occurrence": 0, "pattern": "diamond", "active_until": 12.8, "lasers": lasers}

func capture(frame_name: String) -> void:
	var directory: String = ProjectSettings.globalize_path(OUTPUT_DIR)
	DirAccess.make_dir_recursive_absolute(directory)
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	image.save_png(directory + "/" + frame_name + ".png")
	print("CAPTURE ", frame_name, " -> ", OUTPUT_DIR, "/", frame_name, ".png")

func run() -> void:
	root.size = Vector2i(800, 450)
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.07, 0.06, 0.12)
	backdrop.size = Vector2(800, 450)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(backdrop)
	var game := CaptureGame.new()
	var clock := Clock.new()
	var player := ProbePlayer.new()
	player.position = Vector2(360.0, 240.0)
	var boss := ProbeBoss.new()
	boss.player = player
	game.music = clock
	game.player = player
	root.add_child(game)
	game.add_child(clock)
	game.add_child(player)
	game.add_child(boss)
	var arena: Rect2 = boss.get_laser_arena()
	var lines: Array[Dictionary] = Planner.build_lines(formation(), config(), arena)
	clock.time = 8.0
	var hazard: Variant = Hazard.new()
	game.add_child(hazard)
	hazard.configure_lines(game, boss, lines, arena, 1, "diamond", WINDOW)
	hazard.set_physics_process(false)

	clock.time = 9.7
	hazard._physics_process(1.0 / 60.0)
	await process_frame
	await process_frame
	await capture("volley-warning")

	clock.time = 10.6
	hazard._physics_process(1.0 / 60.0)
	await process_frame
	await process_frame
	await capture("volley-fire")

	player.position = Vector2(500.0, 240.0)
	clock.time = 11.6
	hazard._physics_process(1.0 / 60.0)
	await process_frame
	await process_frame
	await capture("volley-reaim")

	game.free()
	await process_frame
	quit(0)

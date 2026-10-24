extends Node2D

const CONFIG_PATH := "res://data/battle_config.json"
const MOVES_PATH := "res://data/boss_moves.json"
const ASSETS_PATH := "res://data/asset_slots.tres"

@onready var boss: BossController = $Boss
@onready var player: PlayerCombat = $Player
@onready var director: BattleDirector = $BattleDirector
@onready var projectiles: ProjectileSystem = $Projectiles
@onready var hud: RhythmHUD = $UI/RhythmHUD
@onready var move_slots: BossMoveSlots = $BossMoveSlots

var config: Dictionary = {}
var assets: BattleAssetSlots
var heavy_judge := HeavyJudge.new()
var _battle_over := false
var _arena_rect := Rect2(84.0, 38.0, 542.0, 310.0)
var _laser_formation_config: Dictionary = {}


func _ready() -> void:
	config = _load_json(CONFIG_PATH)
	if config.is_empty():
		_fail_startup("Battle config could not be loaded.")
		return
	var arena: Dictionary = config.get("arena", {})
	_arena_rect = Rect2(
		float(arena.get("left", 84.0)),
		float(arena.get("top", 38.0)),
		float(arena.get("right", 626.0)) - float(arena.get("left", 84.0)),
		float(arena.get("bottom", 348.0)) - float(arena.get("top", 38.0))
	)
	assets = load(ASSETS_PATH) as BattleAssetSlots

	player.configure(config, _arena_rect)
	boss.configure(config, _arena_rect)
	projectiles.configure(config, _arena_rect)
	projectiles.set_player(player)
	projectiles.set_boss_origin(boss.global_position)
	boss.set_battle_context(player, projectiles)

	if assets != null:
		player.set_visual_texture(assets.player_texture)
		boss.set_visual_texture(assets.boss_texture)
		projectiles.set_projectile_texture(assets.boss_projectile_texture)

	if not move_slots.load_config(MOVES_PATH):
		for error in move_slots.errors:
			push_error("BossMoveSlots: %s" % error)
		_fail_startup("Boss move slot contract failed. See log.")
		return
	var fixed_pattern := move_slots.get_fixed_pattern()
	boss.set_fixed_parameters(fixed_pattern.get("parameters", {}))
	_laser_formation_config = move_slots.get_laser_formations()

	director.configure(config)
	if not director.initialize():
		_fail_startup("Chart parser failed. See log.")
		return
	heavy_judge.setup(director.chart.heavy_groups, float(config.get("heavy_window_seconds", 0.125)))
	hud.set_context(director, director.chart, player, boss, config)
	_connect_events()
	queue_redraw()
	director.start()


func _process(_delta: float) -> void:
	if not director.running:
		return
	projectiles.set_chart_time(director.current_chart_time)
	boss.advance_to(director.current_chart_time)
	for result in heavy_judge.update(director.current_chart_time):
		if bool(result["success"]):
			hud.on_heavy_success()
		else:
			hud.on_heavy_fail()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_R:
			get_tree().reload_current_scene()
		elif event.physical_keycode == KEY_ESCAPE:
			get_tree().quit()


func _connect_events() -> void:
	director.phase_started.connect(_on_phase_started)
	director.phase_ended.connect(_on_phase_ended)
	director.timing_group.connect(_on_timing_group)
	director.laser_warning.connect(_on_laser_warning)
	director.song_completed.connect(_on_song_completed)
	player.block_started.connect(_on_block_started)
	player.sword_active.connect(_on_sword_active)
	player.defeated.connect(_on_player_defeated)
	boss.defeated.connect(_on_boss_defeated)
	move_slots.slot_requested.connect(_on_slot_requested)


func _on_phase_started(_phase: Dictionary) -> void:
	projectiles.begin_phase()


func _on_phase_ended(_phase: Dictionary) -> void:
	projectiles.enter_rest()


func _on_timing_group(group: Dictionary, phase_index: int) -> void:
	var phrase_value: Variant = group.get("action_phrase_index")
	if phrase_value == null or int(group.get("action_note_index", 0)) != 1:
		return
	var phrase: Dictionary = director.chart.action_phrases[int(phrase_value)]
	var pattern: Dictionary
	if str(phrase.get("mode", "basic")) == "fast":
		pattern = move_slots.get_fast_pattern(int(phrase.get("sequence_index", 0)))
	else:
		pattern = move_slots.get_normal_pattern(int(phrase.get("sequence_index", 0)))
	if pattern.is_empty():
		return
	if boss.begin_attack(pattern, float(phrase["start_time"]), player.global_position):
		hud.set_attack_name(str(pattern.get("display_name", pattern.get("pattern_id", ""))))


func _on_slot_requested(slot: Dictionary, context: Dictionary) -> void:
	projectiles.execute_slot(slot, context)


func _on_laser_warning(laser: Dictionary) -> void:
	if laser.has("fixed_attack_index"):
		if bool(laser.get("fixed_primary", false)):
			var fixed_pattern := move_slots.get_fixed_pattern()
			boss.begin_fixed_one(fixed_pattern, float(laser["time"]), int(laser["fixed_attack_index"]))
			hud.set_attack_name("固定段招式1")
		return
	var formation_index: Variant = laser.get("formation_index")
	if formation_index == null or int(laser.get("formation_line_index", -1)) != 0:
		return
	var formation: Dictionary = director.chart.laser_formations[int(formation_index)]
	var lines := LaserFormationPlanner.build_lines(formation, _laser_formation_config, _arena_rect)
	for line in lines:
		projectiles.queue_laser_geometry(line)


func _on_block_started() -> void:
	heavy_judge.register_block(director.get_clock_time())


func _on_sword_active() -> void:
	var range_limit := float(config.get("combat", {}).get("sword_range", 62.0))
	if player.global_position.distance_to(boss.global_position) <= range_limit:
		boss.take_damage(float(config.get("combat", {}).get("sword_damage", 105.0)))


func _on_player_defeated() -> void:
	_end_battle("PLAYER DOWN", Color("#ff6782"))


func _on_boss_defeated() -> void:
	_end_battle("BOSS DEFEATED", Color("#65ffd0"))


func _on_song_completed() -> void:
	if boss.health > 0.0 and player.health > 0.0:
		_end_battle("CHART COMPLETE", Color("#ffdb63"))


func _end_battle(text: String, color: Color) -> void:
	if _battle_over:
		return
	_battle_over = true
	director.stop()
	hud.show_outcome(text, color)


func _fail_startup(message: String) -> void:
	hud.show_outcome(message, Color("#ff6782"))
	director.stop()


func _load_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Cannot open %s" % path)
		return {}
	var value: Variant = JSON.parse_string(file.get_as_text())
	if not value is Dictionary:
		push_error("JSON root is not an object: %s" % path)
		return {}
	return value as Dictionary


func _draw() -> void:
	if assets != null and assets.arena_background_texture != null:
		draw_texture_rect(assets.arena_background_texture, Rect2(Vector2.ZERO, Vector2(640, 360)), false)
	else:
		draw_rect(Rect2(Vector2.ZERO, Vector2(640, 360)), Color("#071127"), true)
		for index in 13:
			var x := 84.0 + float(index) * 45.2
			draw_line(Vector2(x, 38), Vector2(x, 348), Color(0.11, 0.2, 0.36, 0.32), 1.0)
		for index in 8:
			var y := 38.0 + float(index) * 44.3
			draw_line(Vector2(84, y), Vector2(626, y), Color(0.11, 0.2, 0.36, 0.32), 1.0)
	draw_rect(_arena_rect, Color(0.18, 0.33, 0.55, 0.4), false, 1.0)


extends Control
class_name RhythmHUD

var director: BattleDirector
var chart: ChartParser
var player: PlayerCombat
var boss: BossController
var config: Dictionary = {}

var _feedback_kind := ""
var _feedback_timer := 0.0
var _hit_sfx: AudioStreamPlayer
var _miss_sfx: AudioStreamPlayer
var _outcome_text := ""
var _outcome_color := Color.WHITE


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hit_sfx = AudioStreamPlayer.new()
	_hit_sfx.name = "HeavyHitSfx"
	_hit_sfx.stream = _make_tone(880.0, 0.09, 0.25)
	add_child(_hit_sfx)
	_miss_sfx = AudioStreamPlayer.new()
	_miss_sfx.name = "HeavyMissSfx"
	_miss_sfx.stream = _make_tone(150.0, 0.12, 0.2)
	add_child(_miss_sfx)


func set_context(
	director_value: BattleDirector,
	chart_value: ChartParser,
	player_value: PlayerCombat,
	boss_value: BossController,
	config_value: Dictionary
) -> void:
	director = director_value
	chart = chart_value
	player = player_value
	boss = boss_value
	config = config_value


func on_heavy_success() -> void:
	_feedback_kind = "HIT"
	_feedback_timer = 0.32
	if DisplayServer.get_name() != "headless":
		_hit_sfx.play()
	queue_redraw()


func on_heavy_fail() -> void:
	_feedback_kind = "MISS"
	_feedback_timer = 0.32
	if DisplayServer.get_name() != "headless":
		_miss_sfx.play()
	queue_redraw()


func show_outcome(text: String, color: Color) -> void:
	_outcome_text = text
	_outcome_color = color
	queue_redraw()


func _process(delta: float) -> void:
	_feedback_timer = maxf(0.0, _feedback_timer - delta)
	if _feedback_timer <= 0.0:
		_feedback_kind = ""
	queue_redraw()


func _draw() -> void:
	var font := ThemeDB.fallback_font
	if not _outcome_text.is_empty():
		draw_rect(Rect2(168, 134, 304, 92), Color(0.015, 0.025, 0.055, 0.9), true)
		draw_rect(Rect2(168, 134, 304, 92), _outcome_color, false, 2.0)
		draw_string(font, Vector2(184, 178), _outcome_text, HORIZONTAL_ALIGNMENT_CENTER, 272, 25, _outcome_color)
		draw_string(font, Vector2(184, 204), "Press R to restart", HORIZONTAL_ALIGNMENT_CENTER, 272, 13, Color("#edf5ff"))
	if director == null or chart == null or player == null or boss == null:
		return
	var now := director.current_chart_time
	var white := Color("#edf5ff")
	var muted := Color("#93a6c7")

	_draw_boss_health(font, white, muted)
	_draw_player_health(font, white, muted)
	_draw_heavy_track(font, now)

	var phase_text := "REST - no new barrage"
	if director.active_phase_index >= 0:
		phase_text = "PHASE %d / %d" % [director.active_phase_index + 1, chart.phase_count]
	draw_string(font, Vector2(292, 62), phase_text, HORIZONTAL_ALIGNMENT_CENTER, 170, 11, muted)
	draw_string(font, Vector2(290, 352), "A/D/S/W x2: dodge   SHIFT: heavy block   J / LMB: sword", HORIZONTAL_ALIGNMENT_CENTER, 300, 10, Color(0.65, 0.76, 0.9, 0.8))
	draw_string(font, Vector2(584, 351), "TRAINING", HORIZONTAL_ALIGNMENT_RIGHT, 52, 9, Color(1.0, 0.72, 0.35, 0.8))

	if _feedback_timer > 0.0:
		var feedback_color := Color("#65ffd0") if _feedback_kind == "HIT" else Color("#ff6782")
		draw_string(font, Vector2(16, 318), _feedback_kind, HORIZONTAL_ALIGNMENT_LEFT, 58, 18, feedback_color)

func _draw_boss_health(font: Font, white: Color, muted: Color) -> void:
	var ratio := boss.health / maxf(boss.max_health, 1.0)
	draw_rect(Rect2(160, 14, 320, 9), Color("#18223d"), true)
	draw_rect(Rect2(160, 14, 320.0 * ratio, 9), Color("#ff526d"), true)
	draw_string(font, Vector2(160, 10), "BOSS", HORIZONTAL_ALIGNMENT_LEFT, 60, 9, muted)
	draw_string(font, Vector2(354, 10), "%d / %d" % [ceili(boss.health), ceili(boss.max_health)], HORIZONTAL_ALIGNMENT_RIGHT, 126, 9, white)


func _draw_player_health(font: Font, white: Color, muted: Color) -> void:
	var ratio := player.health / maxf(player.max_health, 1.0)
	draw_rect(Rect2(16, 334, 206, 7), Color("#18223d"), true)
	draw_rect(Rect2(16, 334, 206.0 * ratio, 7), Color("#50e3c2"), true)
	draw_string(font, Vector2(16, 330), "HP %d" % ceili(player.health), HORIZONTAL_ALIGNMENT_LEFT, 100, 9, white)
	draw_string(font, Vector2(140, 330), "dash" if not player.is_dashing() else "DASH", HORIZONTAL_ALIGNMENT_RIGHT, 82, 9, muted)


func _draw_heavy_track(font: Font, now: float) -> void:
	var track := Rect2(15, 84, 58, 215)
	var bottom := track.end.y - 7.0
	var lead := float(config.get("heavy_lead_seconds", 2.0))
	var window := float(config.get("heavy_window_seconds", 0.125))
	draw_rect(track, Color(0.02, 0.04, 0.09, 0.78), true)
	draw_rect(track, Color(0.3, 0.44, 0.68, 0.5), false, 1.0)
	draw_line(Vector2(track.position.x + 6, bottom), Vector2(track.end.x - 6, bottom), Color("#fff0a8"), 2.0)
	draw_string(font, Vector2(track.position.x + 2, track.position.y - 7), "HEAVY", HORIZONTAL_ALIGNMENT_CENTER, track.size.x - 4, 9, Color("#ffcf70"))

	for index in chart.heavy_groups.size():
		var group: Dictionary = chart.heavy_groups[index]
		var delta := float(group["time"]) - now
		if delta > lead or delta < -window:
			continue
		var progress := 1.0 - clampf(delta / lead, 0.0, 1.15)
		var y := lerpf(track.position.y + 8.0, bottom, progress)
		var lane_offset := float(index % 3) * 6.0
		var marker_rect := Rect2(track.position.x + 8.0 + lane_offset, y - 4.0, 28.0, 8.0)
		var in_window := absf(delta) <= window
		var color := Color("#ffdb63")
		if in_window:
			color = Color("#fff8d5")
			draw_rect(marker_rect.grow(3.0), Color(1.0, 0.95, 0.65, 0.35), true)
		draw_rect(marker_rect, color, true)
		draw_line(Vector2(marker_rect.position.x, y), Vector2(marker_rect.end.x, y), Color("#7a3717"), 1.0)

	if _feedback_kind != "":
		var line_color := Color("#65ffd0") if _feedback_kind == "HIT" else Color("#ff6782")
		draw_line(Vector2(track.position.x + 4, bottom), Vector2(track.end.x - 4, bottom), line_color, 4.0)


func _make_tone(frequency: float, duration: float, volume: float) -> AudioStreamWAV:
	var mix_rate := 22050
	var sample_count := maxi(int(duration * mix_rate), 1)
	var bytes := PackedByteArray()
	bytes.resize(sample_count * 2)
	for index in sample_count:
		var envelope := 1.0 - float(index) / float(sample_count)
		var sample := int(sin(TAU * frequency * float(index) / float(mix_rate)) * 32767.0 * volume * envelope)
		bytes.encode_s16(index * 2, sample)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = mix_rate
	stream.stereo = false
	stream.data = bytes
	return stream


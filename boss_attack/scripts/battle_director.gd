extends Node
class_name BattleDirector

signal chart_ready(stats: Dictionary)
signal phase_started(phase: Dictionary)
signal phase_ended(phase: Dictionary)
signal timing_group(group: Dictionary, phase_index: int)
signal heavy_group(group: Dictionary, phase_index: int)
signal laser_warning(laser: Dictionary)
signal laser_damage(laser: Dictionary)
signal rest_started(phase: Dictionary)
signal song_completed
signal clock_started(manual_clock: bool)

var chart := ChartParser.new()
var running := false
var manual_clock := false
var current_chart_time := 0.0
var song_duration_seconds := 418.516
var active_phase_index := -1

var music_path := "res://audio/if_infinity.ogg"
var chart_path := "res://data/if_infinity.chart.json"
var configured_bpm := 203.0
var configured_offset_ms := 245.0
var phase_gap_beats := 4.0
var fast_interval_threshold_beats := 1.01

var _player: AudioStreamPlayer
var _manual_elapsed := 0.0
var _schedule: Array[Dictionary] = []
var _schedule_index := 0
var _initialized := false
var _completed := false


func configure(config: Dictionary) -> void:
	configured_bpm = float(config.get("bpm", configured_bpm))
	configured_offset_ms = float(config.get("offset_ms", configured_offset_ms))
	phase_gap_beats = float(config.get("phase_gap_beats", phase_gap_beats))
	fast_interval_threshold_beats = float(config.get("fast_interval_threshold_beats", fast_interval_threshold_beats))
	song_duration_seconds = float(config.get("song_duration_seconds", song_duration_seconds))
	music_path = str(config.get("music_path", music_path))
	chart_path = str(config.get("chart_path", chart_path))


func initialize() -> bool:
	_player = AudioStreamPlayer.new()
	_player.name = "Music"
	_player.bus = &"Master"
	add_child(_player)
	_player.finished.connect(_on_music_finished)

	chart.fast_interval_threshold_beats = fast_interval_threshold_beats
	if not chart.parse_file(chart_path, configured_bpm, configured_offset_ms, phase_gap_beats):
		for error in chart.errors:
			push_error("ChartParser: %s" % error)
		return false
	_build_schedule()
	_initialized = true
	chart_ready.emit(chart.get_stats())
	return true


func start() -> void:
	if not _initialized or running:
		return
	running = true
	_completed = false
	_schedule_index = 0
	current_chart_time = 0.0
	_manual_elapsed = 0.0
	if _player.stream == null and ResourceLoader.exists(music_path):
		_player.stream = load(music_path) as AudioStream
	manual_clock = DisplayServer.get_name() == "headless" or _player.stream == null
	if not manual_clock:
		_player.play()
	clock_started.emit(manual_clock)


func stop() -> void:
	running = false
	if _player != null and _player.playing:
		_player.stop()


func get_clock_time() -> float:
	if manual_clock:
		return current_chart_time
	if _player == null or not _player.playing:
		return current_chart_time
	var position := _player.get_playback_position()
	position += AudioServer.get_time_since_last_mix()
	position -= AudioServer.get_output_latency()
	return maxf(position, 0.0)


func advance_to(chart_time: float) -> void:
	if not running:
		return
	current_chart_time = maxf(current_chart_time, chart_time)
	while _schedule_index < _schedule.size():
		var event: Dictionary = _schedule[_schedule_index]
		if float(event["time"]) > current_chart_time + 0.000001:
			break
		_dispatch(event)
		_schedule_index += 1


func _process(delta: float) -> void:
	if not running:
		return
	if manual_clock:
		_manual_elapsed += delta
		advance_to(_manual_elapsed)
		if _manual_elapsed >= song_duration_seconds:
			_finish_song()
	else:
		advance_to(get_clock_time())


func _build_schedule() -> void:
	_schedule.clear()
	for phase in chart.phases:
		_add_event(float(phase["start_time"]), 0, "phase_started", phase)
		_add_event(float(phase["end_time"]), 6, "phase_ended", phase)
		for group in phase["timing_groups"]:
			var context := {"phase_index": int(phase["index"])}
			_add_event(float(group["time"]), 3, "timing_group", {"group": group, "context": context})
			if bool(group["is_heavy"]):
				_add_event(float(group["time"]), 3, "heavy_group", {"group": group, "context": context})
	for laser in chart.lasers:
		_add_event(float(laser["time"]), 1, "laser_warning", laser)
		_add_event(float(laser["damage_time"]), 4, "laser_damage", laser)
	_schedule.sort_custom(_sort_events)


func _add_event(time_value: float, priority: int, event_type: String, payload: Variant) -> void:
	_schedule.append({
		"time": time_value,
		"priority": priority,
		"type": event_type,
		"payload": payload,
	})


func _dispatch(event: Dictionary) -> void:
	var payload: Variant = event["payload"]
	match str(event["type"]):
		"phase_started":
			var phase := payload as Dictionary
			active_phase_index = int(phase["index"])
			phase_started.emit(phase)
		"timing_group":
			var timing := payload as Dictionary
			timing_group.emit(timing["group"], int((timing["context"] as Dictionary)["phase_index"]))
		"heavy_group":
			var heavy := payload as Dictionary
			heavy_group.emit(heavy["group"], int((heavy["context"] as Dictionary)["phase_index"]))
		"laser_warning":
			laser_warning.emit(payload as Dictionary)
		"laser_damage":
			laser_damage.emit(payload as Dictionary)
		"phase_ended":
			var ended := payload as Dictionary
			active_phase_index = -1
			phase_ended.emit(ended)
			if bool(ended.get("is_rest_after", false)):
				rest_started.emit(ended)


func _sort_events(a: Dictionary, b: Dictionary) -> bool:
	if is_equal_approx(float(a["time"]), float(b["time"])):
		return int(a["priority"]) < int(b["priority"])
	return float(a["time"]) < float(b["time"])


func _on_music_finished() -> void:
	if running:
		_finish_song()


func _finish_song() -> void:
	if _completed:
		return
	_completed = true
	running = false
	song_completed.emit()

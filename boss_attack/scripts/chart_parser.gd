extends RefCounted
class_name ChartParser

## Converts the task chart's note array into immutable scheduling data.
## BPM and offset are supplied by battle config; chart metadata and audio
## records are deliberately ignored as gameplay timing sources.

var bpm: float = 203.0
var offset_ms: float = 245.0
var max_idle_beats: float = 4.0

var errors: Array[String] = []
var notes: Array[Dictionary] = []
var timing_groups: Array[Dictionary] = []
var heavy_groups: Array[Dictionary] = []
var lasers: Array[Dictionary] = []
var phases: Array[Dictionary] = []

var note_count: int = 0
var timed_note_count: int = 0
var unique_time_count: int = 0
var normal_timing_group_count: int = 0
var heavy_group_count: int = 0
var laser_count: int = 0
var phase_count: int = 0
var chart_end_time: float = 0.0

var _beats_by_key: Dictionary = {}
var _event_beats: Dictionary = {}
var _timed_note_total: int = 0


func parse_file(path: String, configured_bpm: float = 203.0, configured_offset_ms: float = 245.0, gap_beats: float = 4.0) -> bool:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		errors.append("Cannot open chart: %s" % path)
		return false
	return parse_text(file.get_as_text(), configured_bpm, configured_offset_ms, gap_beats)


func parse_text(text: String, configured_bpm: float = 203.0, configured_offset_ms: float = 245.0, gap_beats: float = 4.0) -> bool:
	_clear()
	bpm = configured_bpm
	offset_ms = configured_offset_ms
	max_idle_beats = gap_beats
	if bpm <= 0.0:
		errors.append("BPM must be greater than zero")
		return false
	if max_idle_beats <= 0.0:
		errors.append("Phase gap must be greater than zero")
		return false

	var json := JSON.new()
	var parse_error := json.parse(text)
	if parse_error != OK:
		errors.append("Invalid JSON at line %d: %s" % [json.get_error_line(), json.get_error_message()])
		return false
	var document: Variant = json.data
	if not document is Dictionary:
		errors.append("Chart root must be an object")
		return false
	var raw_notes: Variant = (document as Dictionary).get("note", [])
	if not raw_notes is Array:
		errors.append("Chart note field must be an array")
		return false

	_build_timing_data(raw_notes as Array)
	if errors.is_empty():
		_build_groups()
		_build_phases()
	note_count = (raw_notes as Array).size()
	timed_note_count = _timed_note_total
	unique_time_count = _beats_by_key.size()
	normal_timing_group_count = timing_groups.size()
	heavy_group_count = heavy_groups.size()
	laser_count = lasers.size()
	phase_count = phases.size()
	chart_end_time = _find_chart_end_time()
	return errors.is_empty()


func get_stats() -> Dictionary:
	return {
		"notes": note_count,
		"timed_notes": timed_note_count,
		"unique_times": unique_time_count,
		"timing_groups": normal_timing_group_count,
		"heavy_groups": heavy_group_count,
		"lasers": laser_count,
		"phases": phase_count,
		"bpm": bpm,
		"offset_ms": offset_ms,
		"chart_end_time": chart_end_time,
	}


func beat_to_seconds(value: float) -> float:
	return value * 60.0 / bpm + offset_ms / 1000.0


func _clear() -> void:
	errors.clear()
	notes.clear()
	timing_groups.clear()
	heavy_groups.clear()
	lasers.clear()
	phases.clear()
	_beats_by_key.clear()
	_event_beats.clear()
	_timed_note_total = 0
	note_count = 0
	timed_note_count = 0
	unique_time_count = 0
	normal_timing_group_count = 0
	heavy_group_count = 0
	laser_count = 0
	phase_count = 0
	chart_end_time = 0.0


func _build_timing_data(raw_notes: Array) -> void:
	for index in raw_notes.size():
		var entry: Variant = raw_notes[index]
		if not entry is Dictionary:
			errors.append("Note %d is not an object" % index)
			continue
		var note := entry as Dictionary
		# Sound records are not playable timing events, even when they carry a beat.
		if note.has("sound"):
			continue
		var beat: Variant = note.get("beat")
		if not _valid_beat(beat):
			errors.append("Note %d has an invalid beat" % index)
			continue

		var beat_array := beat as Array
		var beat_key := _beat_key(beat_array)
		var beat_value := _beat_value(beat_array)
		var start_time := beat_to_seconds(beat_value)
		_beats_by_key[beat_key] = true
		_event_beats[beat_key] = beat_value
		_timed_note_total += 1

		var normalized := {
			"source_index": index,
			"beat": beat_array.duplicate(true),
			"beat_key": beat_key,
			"beat_float": beat_value,
			"time": start_time,
			"column": int(note.get("column", -1)),
			"is_laser": note.has("endbeat"),
		}
		if note.has("endbeat"):
			var endbeat: Variant = note.get("endbeat")
			if not _valid_beat(endbeat):
				errors.append("Laser %d has an invalid endbeat" % index)
				continue
			var end_array := endbeat as Array
			var end_key := _beat_key(end_array)
			var end_value := _beat_value(end_array)
			if end_value < beat_value:
				errors.append("Laser %d ends before it starts" % index)
				continue
			normalized["endbeat"] = end_array.duplicate(true)
			normalized["endbeat_key"] = end_key
			normalized["endbeat_float"] = end_value
			normalized["damage_time"] = beat_to_seconds(end_value)
			_event_beats[end_key] = end_value
			lasers.append(normalized)
		else:
			notes.append(normalized)

	notes.sort_custom(_sort_events)
	lasers.sort_custom(_sort_events)


func _build_groups() -> void:
	var groups_by_key: Dictionary = {}
	for note in notes:
		var key: String = note["beat_key"]
		if not groups_by_key.has(key):
			groups_by_key[key] = {
				"beat": note["beat"].duplicate(true),
				"beat_key": key,
				"beat_float": note["beat_float"],
				"time": note["time"],
				"columns": [],
				"notes": [],
				"is_heavy": false,
			}
		var group: Dictionary = groups_by_key[key]
		(group["columns"] as Array).append(note["column"])
		(group["notes"] as Array).append(note)

	for group_variant in groups_by_key.values():
		var group := group_variant as Dictionary
		var columns: Array = group["columns"]
		group["is_heavy"] = columns.has(1) and columns.has(2) and columns.has(3)
		timing_groups.append(group)

	timing_groups.sort_custom(_sort_events)
	for group in timing_groups:
		if group["is_heavy"]:
			heavy_groups.append(group)


func _build_phases() -> void:
	var beat_values: Array[float] = []
	for value in _event_beats.values():
		beat_values.append(float(value))
	beat_values.sort()
	if beat_values.is_empty():
		return

	var ranges: Array[Dictionary] = []
	var start_beat := beat_values[0]
	var end_beat := beat_values[0]
	for index in range(1, beat_values.size()):
		var next_beat := beat_values[index]
		if next_beat - end_beat > max_idle_beats:
			ranges.append({"start_beat": start_beat, "end_beat": end_beat})
			start_beat = next_beat
		end_beat = next_beat
	ranges.append({"start_beat": start_beat, "end_beat": end_beat})

	for index in ranges.size():
		var range_data: Dictionary = ranges[index]
		var phase := {
			"index": index,
			"start_beat": range_data["start_beat"],
			"end_beat": range_data["end_beat"],
			"start_time": beat_to_seconds(range_data["start_beat"]),
			"end_time": beat_to_seconds(range_data["end_beat"]),
			"gap_to_next_beats": 0.0,
			"is_rest_after": false,
			"timing_groups": [],
			"heavy_groups": [],
			"lasers": [],
		}
		if index + 1 < ranges.size():
			var next_start: float = ranges[index + 1]["start_beat"]
			var gap: float = next_start - float(range_data["end_beat"])
			phase["gap_to_next_beats"] = gap
			phase["is_rest_after"] = gap > max_idle_beats
		phases.append(phase)

	for group in timing_groups:
		var phase_index := _phase_index_for_time(group["time"])
		if phase_index >= 0:
			(phases[phase_index]["timing_groups"] as Array).append(group)
			if group["is_heavy"]:
				(phases[phase_index]["heavy_groups"] as Array).append(group)
	for laser in lasers:
		var phase_index := _phase_index_for_time(laser["time"])
		if phase_index >= 0:
			(phases[phase_index]["lasers"] as Array).append(laser)


func _phase_index_for_time(value: float) -> int:
	for index in phases.size():
		var phase: Dictionary = phases[index]
		var is_last := index == phases.size() - 1
		if value >= phase["start_time"] and (is_last or value < phases[index + 1]["start_time"]):
			return index
	return -1


func _find_chart_end_time() -> float:
	var latest := 0.0
	for note in notes:
		latest = maxf(latest, float(note["time"]))
	for laser in lasers:
		latest = maxf(latest, float(laser["damage_time"]))
	return latest


func _valid_beat(value: Variant) -> bool:
	if not value is Array:
		return false
	var beat := value as Array
	if beat.size() != 3:
		return false
	for part in beat:
		if not (part is int or part is float):
			return false
	if int(beat[2]) == 0:
		return false
	return true


func _beat_key(beat: Array) -> String:
	return "%d:%d:%d" % [int(beat[0]), int(beat[1]), int(beat[2])]


func _beat_value(beat: Array) -> float:
	return float(beat[0]) + float(beat[1]) / float(beat[2])


func _sort_events(a: Dictionary, b: Dictionary) -> bool:
	if is_equal_approx(float(a["time"]), float(b["time"])):
		return int(a.get("source_index", 0)) < int(b.get("source_index", 0))
	return float(a["time"]) < float(b["time"])


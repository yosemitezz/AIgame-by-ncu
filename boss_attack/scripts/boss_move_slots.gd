extends Node
class_name BossMoveSlots

signal slot_requested(slot: Dictionary, context: Dictionary)

const EXPECTED_SLOTS := {
	"move_1": {"name": "招式1", "type": "normal"},
	"move_2": {"name": "招式2", "type": "normal"},
	"move_3": {"name": "招式3", "type": "normal"},
	"move_4": {"name": "招式4", "type": "normal"},
	"fixed_1": {"name": "固定段招式1", "type": "fixed"},
	"fixed_2": {"name": "固定段招式2", "type": "fixed"},
}

var slots: Dictionary = {}
var errors: Array[String] = []
var normal_cycle: Array[String] = []
var fast_cycle: Array[String] = []
var fast_patterns: Dictionary = {}
var laser_formations: Dictionary = {}


func load_config(path: String) -> bool:
	slots.clear()
	errors.clear()
	normal_cycle.clear()
	fast_cycle.clear()
	fast_patterns.clear()
	laser_formations.clear()
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		errors.append("Cannot open boss move config: %s" % path)
		return false
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		errors.append("Boss move config root must be an object")
		return false
	var document := parsed as Dictionary
	var raw_slots: Variant = document.get("slots", [])
	if not raw_slots is Array:
		errors.append("Boss move slots must be an array")
		return false

	for value in raw_slots as Array:
		if not value is Dictionary:
			errors.append("Boss move slot must be an object")
			continue
		var slot := value as Dictionary
		var slot_id := str(slot.get("move_slot", ""))
		if not EXPECTED_SLOTS.has(slot_id):
			errors.append("Unknown move slot: %s" % slot_id)
			continue
		if slots.has(slot_id):
			errors.append("Duplicate move slot: %s" % slot_id)
			continue
		var expected: Dictionary = EXPECTED_SLOTS[slot_id]
		if str(slot.get("display_name", "")) != str(expected["name"]):
			errors.append("%s has the wrong display name" % slot_id)
		if str(slot.get("segment_type", "")) != str(expected["type"]):
			errors.append("%s has the wrong segment type" % slot_id)
		if bool(slot.get("enabled", false)) and str(slot.get("pattern_id", "")).is_empty():
			errors.append("%s is enabled without a pattern_id" % slot_id)
		slots[slot_id] = slot.duplicate(true)

	for required_id in EXPECTED_SLOTS:
		if not slots.has(required_id):
			errors.append("Missing move slot: %s" % required_id)
	normal_cycle = _string_array(document.get("normal_cycle", []), "normal_cycle")
	fast_cycle = _string_array(document.get("fast_cycle", []), "fast_cycle")
	var raw_fast: Variant = document.get("fast_patterns", {})
	fast_patterns = (raw_fast as Dictionary).duplicate(true) if raw_fast is Dictionary else {}
	var raw_lasers: Variant = document.get("laser_formations", {})
	laser_formations = (raw_lasers as Dictionary).duplicate(true) if raw_lasers is Dictionary else {}
	for slot_id in normal_cycle:
		if not slots.has(slot_id):
			errors.append("normal_cycle references missing slot %s" % slot_id)
	for pattern_id in fast_cycle:
		if not fast_patterns.has(pattern_id):
			errors.append("fast_cycle references missing pattern %s" % pattern_id)
	return errors.is_empty()


func request_slot(slot_id: StringName, context: Dictionary) -> bool:
	if not slots.has(slot_id):
		return false
	var slot: Dictionary = slots[slot_id]
	if not bool(slot.get("enabled", false)):
		return false
	slot_requested.emit(slot, context)
	return true


func select_for_timing_group(phase_index: int, beat_value: float, context: Dictionary = {}) -> Dictionary:
	for slot_id in EXPECTED_SLOTS:
		var slot: Dictionary = slots.get(slot_id, {})
		if slot.is_empty() or not bool(slot.get("enabled", false)):
			continue
		if str(slot.get("segment_type", "")) != "normal":
			continue
		var phase_indices: Array = slot.get("phase_indices", [])
		if not phase_indices.is_empty() and not phase_indices.has(phase_index):
			continue
		var start_value: Variant = slot.get("start_beat")
		var end_value: Variant = slot.get("end_beat")
		if start_value != null and beat_value < float(start_value):
			continue
		if end_value != null and beat_value > float(end_value):
			continue
		var request_context := context.duplicate(true)
		request_context["phase_index"] = phase_index
		request_context["beat"] = beat_value
		slot_requested.emit(slot, request_context)
		return slot
	return {}


func get_fixed_slots() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for slot_id in ["fixed_1", "fixed_2"]:
		if slots.has(slot_id):
			result.append(slots[slot_id])
	return result


func has_enabled_slots() -> bool:
	for slot in slots.values():
		if bool((slot as Dictionary).get("enabled", false)):
			return true
	return false


func get_normal_pattern(cycle_index: int) -> Dictionary:
	if normal_cycle.is_empty():
		return {}
	var slot_id := normal_cycle[posmod(cycle_index, normal_cycle.size())]
	return (slots.get(slot_id, {}) as Dictionary).duplicate(true)


func get_fast_pattern(cycle_index: int) -> Dictionary:
	if fast_cycle.is_empty():
		return {}
	var pattern_id := fast_cycle[posmod(cycle_index, fast_cycle.size())]
	return (fast_patterns.get(pattern_id, {}) as Dictionary).duplicate(true)


func get_fixed_pattern() -> Dictionary:
	return (slots.get("fixed_1", {}) as Dictionary).duplicate(true)


func get_laser_formations() -> Dictionary:
	return laser_formations.duplicate(true)


func _string_array(value: Variant, field_name: String) -> Array[String]:
	var result: Array[String] = []
	if not value is Array:
		errors.append("%s must be an array" % field_name)
		return result
	for entry in value:
		result.append(str(entry))
	return result


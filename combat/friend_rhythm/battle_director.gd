# Adapted from yosemitezz/AIgame-by-ncu boss_attack, PR #1 by zjuan-ctrl
# and final PR #3 (head fff7526a3dc687c9625dece860a79695c00db8d0).
# MIT source only. See third_party/friend-boss-pr1/LICENSE.
# No private recording or source chart is loaded by this port.
extends RefCounted
## Pure chart cursor. MusicDirector remains the only audio/section authority.
## The caller invalidates on rest, death, scene reset or attack cancellation.
const Parser = preload("res://combat/friend_rhythm/chart_parser.gd")
signal event_dispatched(event: Dictionary, version: int)
var chart: RefCounted = Parser.new()
var generation: int = 0
var running: bool = false
var current_chart_time: float = 0.0
var errors: Array[String] = []
var _schedule: Array[Dictionary] = []
var _schedule_index: int = 0

func load_document(document: Dictionary, bpm: float = 112.0) -> bool:
    invalidate()
    errors.clear()
    if not chart.parse_text(JSON.stringify(document), bpm, 0.0, 4.0):
        errors.assign(chart.errors)
        _schedule.clear()
        return false
    _build_schedule()
    current_chart_time = 0.0
    return true

func restart_at(chart_time: float = 0.0) -> int:
    generation += 1
    running = true
    current_chart_time = maxf(0.0, chart_time)
    _schedule_index = 0
    # Seeking/cancelling never catches up old attack cues.
    while _schedule_index < _schedule.size() and float(_schedule[_schedule_index]["time"]) < current_chart_time - 0.000001:
        _schedule_index += 1
    return generation

func invalidate() -> void:
    generation += 1
    running = false
    _schedule_index = _schedule.size()

func advance_to(chart_time: float, expected_generation: int = -1) -> void:
    if not running or (expected_generation >= 0 and expected_generation != generation):
        return
    var dispatch_generation: int = generation
    current_chart_time = maxf(current_chart_time, chart_time)
    while running and generation == dispatch_generation and _schedule_index < _schedule.size():
        var event: Dictionary = _schedule[_schedule_index]
        if float(event["time"]) > current_chart_time + 0.000001:
            break
        # Consume before callbacks: rest/defeat may invalidate reentrantly.
        _schedule_index += 1
        event_dispatched.emit(event.duplicate(true), dispatch_generation)

func schedule_snapshot() -> Array[Dictionary]:
    return _schedule.duplicate(true)

func _build_schedule() -> void:
    _schedule.clear()
    for phase in chart.phases:
        _add_event(float(phase["start_time"]), 0, "phase_started", phase)
        _add_event(float(phase["end_time"]), 6, "phase_ended", phase)
    # Derived PR3 phrase/fixed/formation data drives execution, not a renamed
    # generic random attack pool. Same-time fixed geometry precedes movement.
    for event in chart.fixed_attack_events:
        _add_event(float(event["time"]), 1, "fixed_attack", event)
    for formation in chart.laser_formations:
        _add_event(float(formation["start_time"]), 1, "laser_formation", formation)
    for phrase in chart.action_phrases:
        _add_event(float(phrase["start_time"]), 2, "action_phrase", phrase)
    for group in chart.timing_groups:
        _add_event(float(group["time"]), 3, "timing_group", group)
    _schedule.sort_custom(_sort_events)

func _add_event(time_value: float, priority: int, event_type: String, payload: Dictionary) -> void:
    _schedule.append({"time": time_value, "priority": priority, "type": event_type, "payload": payload, "order": _schedule.size()})

func _sort_events(a: Dictionary, b: Dictionary) -> bool:
    if is_equal_approx(float(a["time"]), float(b["time"])):
        if int(a["priority"]) == int(b["priority"]):
            return int(a["order"]) < int(b["order"])
        return int(a["priority"]) < int(b["priority"])
    return float(a["time"]) < float(b["time"])

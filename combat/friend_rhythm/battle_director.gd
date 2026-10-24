# Adapted from zjuan-ctrl, AIgame-by-ncu PR #1, commit 4e79620503bc9fd05a2154018ec97ec76f227557.
# Original source MIT, Copyright (c) 2026 yosemitezz. See root THIRD_PARTY_NOTICES.md.
# No private recording or reference chart is included.
extends RefCounted
## Pure adaptation of BattleDirector._build_schedule/_sort_events/advance_to.
## The existing MusicDirector supplies time. This module never plays audio,
## advances delta, applies damage, or owns fixed/random/rest phase decisions.
const Parser = preload("res://combat/friend_rhythm/chart_parser.gd")
signal timing_group(group: Dictionary, phase_index: int, version: int)
signal dispatched(event: Dictionary, version: int)
var chart = Parser.new()
var generation: int = 0
var running: bool = false
var current_chart_time: float = 0.0
var _schedule: Array[Dictionary] = []
var _schedule_index: int = 0

func load_document(document: Dictionary, bpm: float) -> bool:
    invalidate()
    if not chart.parse_text(JSON.stringify(document), bpm, 0.0, 4.0):
        return false
    _build_schedule()
    return true

func restart_at(chart_time: float = 0.0) -> int:
    generation += 1
    running = true
    current_chart_time = maxf(0.0, chart_time)
    _schedule_index = 0
    # Never catch up old attacks after a parry, freeze, or large clock jump.
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
    var version: int = generation
    current_chart_time = maxf(current_chart_time, chart_time)
    while running and generation == version and _schedule_index < _schedule.size():
        var event: Dictionary = _schedule[_schedule_index]
        if float(event["time"]) > current_chart_time + 0.000001:
            break
        # Consume before callbacks: rest/cancel can invalidate from a listener.
        _schedule_index += 1
        dispatched.emit(event.duplicate(true), version)
        if not running or generation != version:
            return
        if str(event["type"]) == "timing_group":
            timing_group.emit(event["payload"]["group"], int(event["payload"]["phase_index"]), version)

func _build_schedule() -> void:
    _schedule.clear()
    for phase: Dictionary in chart.phases:
        _add_event(float(phase["start_time"]), 0, "phase_started", phase)
        _add_event(float(phase["end_time"]), 6, "phase_ended", phase)
        for group: Dictionary in phase["timing_groups"]:
            _add_event(float(group["time"]), 3, "timing_group", {"group": group, "phase_index": phase["index"]})
    _schedule.sort_custom(_sort_events)

func _add_event(at: float, priority: int, kind: String, payload: Dictionary) -> void:
    _schedule.append({"time": at, "priority": priority, "type": kind, "payload": payload.duplicate(true)})

func _sort_events(a: Dictionary, b: Dictionary) -> bool:
    if is_equal_approx(float(a["time"]), float(b["time"])):
        return int(a["priority"]) < int(b["priority"])
    return float(a["time"]) < float(b["time"])

extends SceneTree
## Pure final-PR planning tests; no main gameplay, song, video or playthrough.
const Parser = preload("res://combat/friend_rhythm/chart_parser.gd")
const Slots = preload("res://combat/friend_rhythm/boss_move_slots.gd")
const Planner = preload("res://combat/friend_rhythm/boss_attack_planner.gd")
const Lasers = preload("res://combat/friend_rhythm/laser_formation_planner.gd")
const Director = preload("res://combat/friend_rhythm/battle_director.gd")
const MainBoss = preload("res://combat/boss.gd")
const Hazard = preload("res://combat/boss_hazard.gd")
const Patterns = preload("res://combat/friend_rhythm/projectile_patterns.gd")
var passed: int = 0
var failed: int = 0

func check(value: bool, label: String) -> void:
    if value:
        passed += 1
        print("PASS ", label)
    else:
        failed += 1
        push_error("FAIL " + label)

func _initialize() -> void:
    var file: FileAccess = FileAccess.open("res://data/main_boss_chart.json", FileAccess.READ)
    if file == null:
        check(false, "original chart exists")
        quit(1)
        return
    var document: Dictionary = JSON.parse_string(file.get_as_text())
    var sections: Dictionary = document["sections"]
    var slots: Node = Slots.new()
    check(slots.load_config("res://data/authored_boss_moves.json"), "PR3 four normal/four fast source config loads")
    check(slots.normal_cycle.size() == 4 and slots.fast_cycle.size() == 4, "one final four/four cycle, no duplicate PR2 pool")
    check(not bool(slots.slots["fixed_2"]["enabled"]), "unprovided second fixed slot stays disabled")
    var bpm: float = 112.0
    var spb: float = 60.0 / bpm
    var arena: Rect2 = Rect2(0, 0, 640, 360)
    var boss_at: Vector2 = Vector2(100, 260)
    var player_at: Vector2 = Vector2(510, 280)
    var normal: RefCounted = Parser.new()
    check(normal.parse_text(JSON.stringify(sections["random"]), bpm, 0.0, 4.0), "original normal placeholder parses")
    check(normal.timing_groups.size() == 8 and normal.paired_note_groups.size() == 4, "real parser groups equal-spaced notes into pairs")
    check(normal.action_phrases.size() == 4, "real parser emits four basic action phrases")
    var fast: RefCounted = Parser.new()
    check(fast.parse_text(JSON.stringify(sections["final"]), bpm, 0.0, 4.0), "original accelerated placeholder parses")
    check(fast.action_phrases.size() == 4, "real parser combines pairs into four accelerated phrases")
    check(fast.laser_formations.size() == 4, "real parser groups four distinct laser formations")
    var expected_formations: Array[String] = ["diamond", "parallel", "grid", "rotating"]
    var geometry: Dictionary = slots.get_laser_formations()
    for i: int in 4:
        var normal_pattern: Dictionary = slots.get_normal_pattern(i)
        var plan: Dictionary = Planner.build_plan(normal_pattern, 3.0, spb, boss_at, player_at, arena)
        check(not plan["actions"].is_empty(), "normal %d produces real source action list" % i)
        check(plan["locked_player"] == player_at and is_equal_approx(float(plan["end_time"]), 3.0 + 4.0 * spb), "normal %d locks target and four-beat window" % i)
        var fast_pattern: Dictionary = slots.get_fast_pattern(i)
        var fast_plan: Dictionary = Planner.build_plan(fast_pattern, 1.0, spb, boss_at, player_at, arena)
        check(fast_plan["actions"].size() >= 4, "fast %d preserves four source sub-actions" % i)
        var formation: Dictionary = fast.laser_formations[i]
        check(str(formation["pattern"]) == expected_formations[i], "formation %d follows final PR3 cycle" % i)
        var lines: Array[Dictionary] = Lasers.build_lines(formation, geometry, arena)
        check(lines.size() == 4, "formation %d has four resolved infinite-line records" % i)
        var finite: bool = true
        var warned: bool = true
        for line: Dictionary in lines:
            finite = finite and (line["origin"] as Vector2).is_finite() and is_finite(float(line["angle_radians"]))
            warned = warned and float(line["damage_time"]) > float(line["warning_time"])
        check(finite and warned, "formation %d has finite geometry and real warning lead" % i)
        var repeated: Dictionary = formation.duplicate(true)
        repeated["occurrence"] = 1
        var moved: Array[Dictionary] = Lasers.build_lines(repeated, geometry, arena)
        check(moved[0]["origin"] != lines[0]["origin"] or moved[0]["angle_radians"] != lines[0]["angle_radians"], "formation %d varies safe region next occurrence" % i)
    var locked: Dictionary = Planner.build_plan(slots.get_normal_pattern(0), 0.0, spb, boss_at, player_at, arena)
    player_at = Vector2(30, 30)
    check(locked["locked_player"] == Vector2(510, 280), "later player movement cannot retarget stored source plan")
    var fixed: RefCounted = Parser.new()
    check(fixed.parse_text(JSON.stringify(sections["fixed"]), bpm, 0.0, 4.0), "original fixed placeholder parses")
    check(fixed.fixed_attack_events.size() == 2 and fixed.laser_formations.is_empty(), "paired source lasers form two cube cues, not duplicate formations")
    var parameters: Dictionary = slots.get_fixed_pattern()["parameters"]
    var cube_x: Dictionary = Planner.build_fixed_cube(parameters, 0.0, spb, boss_at, arena, 0, false)
    var cube_plus: Dictionary = Planner.build_fixed_cube(parameters, 2.0 * spb, spb, boss_at, arena, 1, true)
    check(not bool(cube_x["diamond"]) and bool(cube_plus["diamond"]), "fixed source plan carries independent X and plus orientations")
    check(float(cube_x["flight_end_time"]) < float(cube_x["damage_time"]) and float(cube_x["damage_time"]) < float(cube_x["active_until"]), "cube flight, warning, contact and tail remain ordered")
    check(cube_x["to"] != cube_plus["to"], "fixed target lanes vary between occurrences")
    var empty_parameters: Dictionary = {"target_lanes": []}
    check((Planner.build_fixed_cube(empty_parameters, 0.0, spb, boss_at, arena, 0, true)["to"] as Vector2).is_finite(), "empty optional lane list has finite safe fallback")
    for kind: String in ["ring", "fan", "side_spray"]:
        var shots: Array[Dictionary] = Patterns.vectors(kind, {"count": 3, "speed": 150.0, "ttl_seconds": 2.0}, boss_at, Vector2(510, 280))
        check(shots.size() == (6 if kind == "side_spray" else 3), "source %s resolves exact bounded projectile attempts" % kind)
        check((shots[0]["velocity"] as Vector2).is_finite() and float(shots[0]["ttl_seconds"]) == 2.0, "source %s retains finite motion and ttl" % kind)
    check(Patterns.vectors("side_spray", {"count": 100000}, boss_at, player_at).size() == 48, "malformed count cannot create unbounded attempts")
    check(Patterns.vectors("unknown", {}, boss_at, player_at).is_empty(), "unknown pattern cannot silently spawn another move")
    var director: RefCounted = Director.new()
    check(director.load_document(sections["final"], bpm), "pure director builds actual final PR3 derived schedule")
    var emitted: Array[Dictionary] = []
    director.event_dispatched.connect(func(event: Dictionary, _version: int) -> void: emitted.append(event))
    var version: int = director.restart_at()
    director.advance_to(0.0, version)
    var types: Array[String] = []
    for event: Dictionary in emitted:
        types.append(str(event["type"]))
    check(types == ["phase_started", "laser_formation", "action_phrase", "timing_group"], "same-beat phase, geometry, move and timing priority is deterministic")
    var before: int = emitted.size()
    director.advance_to(-1.0, version)
    check(emitted.size() == before, "backward clock cannot duplicate cues")
    director.invalidate()
    director.advance_to(100.0, version)
    check(emitted.size() == before, "rest/cancel invalidates every old future cue")
    var renewed: int = director.restart_at(4.0 * spb)
    director.advance_to(100.0, version)
    check(emitted.size() == before, "obsolete generation cannot dispatch after restart")
    director.advance_to(4.0 * spb, renewed)
    var late_events: Array[Dictionary] = emitted.slice(before)
    var only_current: bool = true
    for event: Dictionary in late_events:
        only_current = only_current and float(event["time"]) >= 4.0 * spb - 0.00001
    check(only_current and not late_events.is_empty(), "seek resumes current phrase without replaying old damage")
    var cancel_director: RefCounted = Director.new()
    check(cancel_director.load_document(sections["final"], bpm), "reentrant cancellation fixture loads")
    var reentrant: Array[String] = []
    cancel_director.event_dispatched.connect(func(event: Dictionary, _version: int) -> void:
        reentrant.append(str(event["type"]))
        if str(event["type"]) == "laser_formation":
            cancel_director.invalidate())
    cancel_director.restart_at()
    cancel_director.advance_to(100.0)
    check(reentrant == ["phase_started", "laser_formation"], "callback rest/defeat cancels same-tick remaining attacks")
    var invalid: RefCounted = Parser.new()
    check(not invalid.parse_text(JSON.stringify({"note": [{"beat": [0, 0, 0], "column": 0}]})), "zero denominator is rejected")
    check(not invalid.parse_text(JSON.stringify({"note": [{"beat": [0, 0.5, 1], "column": 0}]})), "fractional triple components cannot alias an integer key")
    check(not invalid.parse_text(JSON.stringify({"note": [{"beat": [0, 0, -1], "column": 0}]})), "negative denominator is rejected")
    var handoff: RefCounted = Parser.new()
    var coincident: Dictionary = {"note": [
        {"beat": [73, 0, 4], "column": 0}, {"beat": [73, 0, 2], "column": 1},
        {"beat": [73, 0, 4], "endbeat": [75, 0, 4], "column": 0},
        {"beat": [73, 0, 2], "endbeat": [75, 0, 2], "column": 3}]}
    check(handoff.parse_text(JSON.stringify(coincident), bpm, 0.0, 4.0), "final handoff coincident distinct-key fixture parses")
    check(handoff.timing_groups.size() == 2, "equal note seconds never merge distinct raw three-component keys")
    check(handoff.fixed_attack_events.size() == 1 and handoff.fixed_attack_events[0]["lasers"].size() == 2, "same-time different-key long notes create exactly one cube cue")
    check(handoff.laser_formations.is_empty() and handoff.notes.size() == 2, "fixed trigger excludes all paired lasers but preserves coincident normal notes")
    var threshold_notes: Array[Dictionary] = []
    for index: int in 4:
        threshold_notes.append({"beat": [index, index, 10], "column": 0})
    check(handoff.parse_text(JSON.stringify({"note": threshold_notes}), bpm) and handoff.action_phrases.size() == 1 and handoff.action_phrases[0]["mode"] == "fast", "recommended exact1.1-beat boundary forms a fast four-note phrase")
    var beyond_notes: Array[Dictionary] = []
    for index: int in 4:
        beyond_notes.append({"beat": [index, index * 101, 1000], "column": 0})
    check(handoff.parse_text(JSON.stringify({"note": beyond_notes}), bpm) and handoff.action_phrases.size() == 2 and handoff.action_phrases[0]["mode"] == "basic", "interval beyond1.1 remains basic")
    var tail_notes: Array[Dictionary] = []
    for index: int in 6:
        tail_notes.append({"beat": [index, 0, 1], "column": 0})
    check(handoff.parse_text(JSON.stringify({"note": tail_notes}), bpm) and handoff.action_phrases.size() == 2 and handoff.action_phrases[1]["mode"] == "basic", "leftover fast pair explicitly keeps a two-note basic fallback")
    var separated: Array[Dictionary] = []
    for at: int in [0, 1, 2, 5, 6, 7]:
        separated.append({"beat": [at, 0, 1], "column": 0})
    check(handoff.parse_text(JSON.stringify({"note": separated}), bpm) and handoff.action_phrases.size() == 1 and handoff.action_phrases[0]["mode"] == "fast", "same-phase equal-interval pairs follow source combination rule without an invented adjacency restriction")
    var end_notes: Array[Dictionary] = []
    var ends: Array[int] = [10, 4, 5, 6]
    for index: int in 4:
        end_notes.append({"beat": [index, 0, 1], "endbeat": [ends[index], 0, 1], "column": index})
    check(handoff.parse_text(JSON.stringify({"note": end_notes}), bpm) and is_equal_approx(float(handoff.laser_formations[0]["active_until"]), 10.0 * spb + 0.7), "formation shared tail follows latest end even when end order crosses")
    var main_arena: Rect2 = MainBoss.LASER_ARENA
    for i: int in 4:
        var main_lines: Array[Dictionary] = Lasers.build_lines(fast.laser_formations[i], geometry, main_arena)
        var all_clipped: bool = true
        for line: Dictionary in main_lines:
            var clipped: Array[Vector2] = Hazard.clipped_line(line["origin"], float(line["angle_radians"]), main_arena)
            all_clipped = all_clipped and clipped.size() == 2
            if clipped.size() == 2:
                line["a"] = clipped[0].round()
                line["b"] = clipped[1].round()
                all_clipped = all_clipped and main_arena.grow(1.0).has_point(line["a"]) and main_arena.grow(1.0).has_point(line["b"])
        check(all_clipped, "main formation %d warning/contact segments clip to actual arena" % i)
        var safe_samples: int = 0
        for x: int in range(2700, 3291, 8):
            var intersects: bool = false
            for line: Dictionary in main_lines:
                intersects = intersects or Hazard.line_hits_player(Vector2(x, 300), line)
            if not intersects:
                safe_samples += 1
        check(safe_samples >= 4, "main formation %d leaves multiple real-body grounded safe positions" % i)
    var horizontal: Dictionary = {"a": Vector2(2660, 287), "b": Vector2(3330, 287), "thickness": 9.0}
    check(Hazard.line_hits_player(Vector2(3000, 300), horizontal), "shown horizontal line contacts main 14x26 player body")
    check(not Hazard.line_hits_player(Vector2(3000, 340), horizontal), "line cannot hit a body beyond shown width")
    check(not Hazard.line_hits_player(Vector2(3500, 300), horizontal), "finite clipped line cannot damage beyond its visible endpoint")
    var owner_stub: Node = Node.new()
    var cube_hazard: Node2D = Hazard.new()
    cube_hazard.configure_cube(null, owner_stub, cube_x, arena, 7)
    check(cube_hazard.kind == "cube_x" and cube_hazard.lines.size() == 2, "actual carrier resolves X cube into two beam records")
    var snapshot: Dictionary = cube_hazard.get_geometry_snapshot()
    var original_a: Vector2 = cube_hazard.lines[0]["a"]
    snapshot["lines"][0]["a"] = Vector2(-9999, -9999)
    check(cube_hazard.lines[0]["a"] == original_a, "warning geometry snapshots cannot mutate actual damage records")
    check(cube_hazard.source_generation == 7, "hazard retains its cancel generation")
    cube_hazard.free()
    owner_stub.free()
    # The cancellation callback intentionally captures its director; disconnect
    # before release to avoid a RefCounted -> Callable -> RefCounted cycle.
    for connection: Dictionary in cancel_director.event_dispatched.get_connections():
        cancel_director.event_dispatched.disconnect(connection["callable"])
    for connection: Dictionary in director.event_dispatched.get_connections():
        director.event_dispatched.disconnect(connection["callable"])
    slots.free()
    print("MAIN AUTHORED BOSS: %d passed, %d failed" % [passed, failed])
    quit(1 if failed > 0 else 0)

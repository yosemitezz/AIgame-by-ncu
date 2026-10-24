extends SceneTree
## Virtual 60Hz source-to-physical-emission accounting; no level input playback or real-time song wait.
const Player = preload("res://actors/player.gd")
const Music = preload("res://audio/music_director.gd")
const Projectile = preload("res://combat/projectile.gd")
const Planner = preload("res://combat/friend_rhythm/boss_attack_planner.gd")
const DT: float = 1.0 / 60.0
var passed: int = 0
var failed: int = 0
var expected_actions: Dictionary = {}
var expected_plans: Dictionary = {}
var expected_fixed: Dictionary = {}
var expected_formations: Dictionary = {}
var game: CoverageGame

class CountedBoss:
    extends "res://combat/boss.gd"
    func _on_authored_event(event: Dictionary, version: int) -> void:
        game.bump_event(str(event["type"]))
        if str(event["type"]) == "laser_formation" and int(event["payload"].get("index", -1)) == 11:
            game.formation11 = {"dispatch_score": game.music.get_score_time(), "dispatch_chart": game.music.get_chart_time(), "start_time": event["payload"]["start_time"], "active_until": event["payload"]["active_until"], "lasers": event["payload"]["lasers"].duplicate(true)}
        super._on_authored_event(event, version)
    func _begin_authored_pattern(pattern: Dictionary, start_score_time: float, locked_target: Vector2 = Vector2.INF, prepared: Dictionary = {}) -> bool:
        var accepted: bool = super._begin_authored_pattern(pattern, start_score_time, locked_target, prepared)
        if accepted:
            game.record_plan(attack_serial, str(pattern.get("pattern_id", "")), start_score_time)
        else:
            game.bump("plan_refused")
        return accepted
    func _execute_authored_action(action: Dictionary, score: float) -> void:
        game.record_action(action)
        super._execute_authored_action(action, score)
        game.current_action = {}
    func _trace_skipped(kind: String, pattern: String, score: float) -> void:
        game.skip_reasons[kind] = int(game.skip_reasons.get(kind, 0)) + 1
        super._trace_skipped(kind, pattern, score)

class CoverageGame extends Node2D:
    signal warning_issued(kind: String, at: Vector2, duration: float)
    signal animation_event(actor: Node, state: String, frame: int, facing: int)
    var music: Node
    var boss: Node2D
    var player: Node2D
    var story_safe: bool = false
    var _paused: bool = false
    var outcome: String = ""
    var owner_test: SceneTree
    var stats: Dictionary = {"projectile_requests": 0, "projectile_success": 0, "projectile_rejected_budget": 0, "projectile_rejected_safety": 0, "hazard_requests": 0, "hazard_success": 0, "hazard_rejected_budget": 0, "hazard_rejected_safety": 0}
    var event_counts: Dictionary = {}
    var skip_reasons: Dictionary = {}
    var pattern_counts: Dictionary = {}
    var serial_to_phrase: Dictionary = {}
    var executed: Dictionary = {}
    var current_action: Dictionary = {}
    var requests_by_pattern: Dictionary = {}
    var actions_by_pattern: Dictionary = {}
    var successes_by_pattern: Dictionary = {}
    var refused_by_pattern: Dictionary = {}
    var hazard_counts: Dictionary = {}
    var hazard_records: Dictionary = {}
    var sections: Array[Dictionary] = []
    var safety_pending: Dictionary = {}
    var shots: Array[Node2D] = []
    var hazards: Array[Node2D] = []
    var max_shots: int = 0
    var max_hazards: int = 0
    var geometry_ok: bool = true
    var formation11: Dictionary = {}
    func bump(key: String, amount: int = 1) -> void:
        stats[key] = int(stats.get(key, 0)) + amount
    func bump_event(kind: String) -> void:
        event_counts[kind] = int(event_counts.get(kind, 0)) + 1
    func announce(_text: String, _seconds: float = 3.0) -> void: pass
    func emit_fx(_kind: String, _at: Vector2, _direction: Vector2 = Vector2.ZERO, _power: float = 1.0) -> void: pass
    func on_boss_phase(section: String) -> void:
        sections.append({"section": section, "time": music.get_chart_time()})
        if section == "random":
            music.request_advance()
    func hero_attack(_source: Node2D, _damage: int, _reach: float, _combo: int) -> void: pass
    func on_boss_defeated() -> void: bump("unexpected_victory")
    func damage_player(amount: int, at: Vector2) -> void:
        bump("damage_requests")
        player.receive_hit(amount, at)
    func record_plan(serial: int, pattern: String, start: float) -> void:
        var lookup: String = "%s|%.6f" % [pattern, start]
        var candidates: Array = owner_test.expected_plans.get(lookup, [])
        if candidates.is_empty():
            bump("unmatched_plan")
            serial_to_phrase[serial] = -1
        else:
            serial_to_phrase[serial] = int(candidates.pop_front())
        pattern_counts[pattern] = int(pattern_counts.get(pattern, 0)) + 1
        bump("plans_started")
    func action_key(action: Dictionary) -> String:
        return "%d/%d" % [int(serial_to_phrase.get(int(action["source_serial"]), -1)), int(action["source_index"])]
    func record_action(action: Dictionary) -> void:
        var key: String = action_key(action)
        executed[key] = int(executed.get(key, 0)) + 1
        var pattern: String = str(action["source_pattern"])
        actions_by_pattern[pattern] = int(actions_by_pattern.get(pattern, 0)) + 1
        current_action = {"key": key, "pattern": pattern, "type": str(action["type"])}
        bump("actions_executed")
    func spawn_projectile(at: Vector2, velocity: Vector2, friendly: bool = false, style: String = "default") -> Node2D:
        bump("projectile_requests")
        var pattern: String = str(current_action.get("pattern", "unknown"))
        requests_by_pattern[pattern] = int(requests_by_pattern.get(pattern, 0)) + 1
        if story_safe:
            bump("projectile_rejected_safety")
            refused_by_pattern[pattern + ":safety"] = int(refused_by_pattern.get(pattern + ":safety", 0)) + 1
            return null
        if get_tree().get_nodes_in_group("projectiles").size() >= 180:
            bump("projectile_rejected_budget")
            refused_by_pattern[pattern + ":budget"] = int(refused_by_pattern.get(pattern + ":budget", 0)) + 1
            return null
        var shot: Node2D = Projectile.new()
        shot.configure(self, at, velocity, friendly, style)
        add_child(shot)
        shot.set_physics_process(false)
        shots.append(shot)
        bump("projectile_success")
        successes_by_pattern[pattern] = int(successes_by_pattern.get(pattern, 0)) + 1
        max_shots = maxi(max_shots, shots.size())
        return shot
    func spawn_boss_hazard(hazard: Node2D) -> bool:
        bump("hazard_requests")
        if story_safe or _paused or outcome != "":
            bump("hazard_rejected_safety")
            hazard.free()
            return false
        if get_tree().get_nodes_in_group("boss_hazards").size() >= 24:
            bump("hazard_rejected_budget")
            hazard.free()
            return false
        add_child(hazard)
        hazard.set_physics_process(false)
        hazards.append(hazard)
        max_hazards = maxi(max_hazards, hazards.size())
        var geometry: Dictionary = hazard.get_geometry_snapshot()
        var kind: String = str(geometry["kind"])
        hazard_counts[kind] = int(hazard_counts.get(kind, 0)) + 1
        var key: String = ""
        if not (geometry["cube"] as Dictionary).is_empty():
            key = "fixed|%.6f" % float(geometry["cube"]["start_time"])
            geometry_ok = geometry_ok and geometry["lines"].size() == 2
        elif not (geometry["lines"] as Array).is_empty():
            key = "formation|%d" % int(geometry["lines"][0]["formation_index"])
        else:
            geometry_ok = false
        hazard_records[key] = {"kind": kind, "lines": geometry["lines"].size(), "count": int(hazard_records.get(key, {}).get("count", 0)) + 1}
        for line: Dictionary in geometry["lines"]:
            var segment: Vector2 = (line["b"] as Vector2) - (line["a"] as Vector2)
            geometry_ok = geometry_ok and segment.length() > 20.0 and float(line["warning_time"]) < float(line["damage_time"]) and float(line["active_until"]) >= float(line["damage_time"])
            if kind == "cube_x":
                geometry_ok = geometry_ok and absf(segment.x) > 1.0 and absf(segment.y) > 1.0
            elif kind == "cube_plus":
                geometry_ok = geometry_ok and (absf(segment.x) < 1.0 or absf(segment.y) < 1.0)
        bump("hazard_success")
        return true
    func clear_boss_hazards() -> void:
        for hazard: Node2D in hazards:
            if is_instance_valid(hazard):
                hazard.clear()
    func set_story_safe(value: bool) -> void:
        story_safe = value
        if value:
            var reason: String = "eof" if not music.running else ("rest" if music.current_section == "rest" else "other_safety")
            if is_instance_valid(boss):
                for action: Dictionary in boss._authored_actions:
                    safety_pending[action_key(action)] = reason
            bump("safety_" + reason)
            for hazard: Node2D in hazards:
                if is_instance_valid(hazard) and not hazard._cleared:
                    bump("hazards_cleared_" + reason)
            for shot: Node2D in shots:
                if is_instance_valid(shot) and not shot._cleared:
                    bump("projectiles_cleared_" + reason)
            clear_boss_hazards()
            for shot: Node2D in shots:
                if is_instance_valid(shot):
                    shot.clear()
    func tick_objects(delta: float) -> void:
        var live_shots: Array[Node2D] = []
        for shot: Node2D in shots:
            if not is_instance_valid(shot): continue
            if not shot._cleared:
                shot._physics_process(delta)
            if shot._cleared:
                shot.free()
                bump("projectile_disposed")
            else:
                live_shots.append(shot)
        shots = live_shots
        var live_hazards: Array[Node2D] = []
        for hazard: Node2D in hazards:
            if not is_instance_valid(hazard): continue
            if not hazard._cleared:
                hazard._physics_process(delta)
            if hazard._cleared:
                hazard.free()
                bump("hazard_disposed")
            else:
                live_hazards.append(hazard)
        hazards = live_hazards

func check(ok: bool, label: String) -> void:
    if ok:
        passed += 1
        print("PASS ", label)
    else:
        failed += 1
        push_error("FAIL " + label)

func _initialize() -> void: call_deferred("run")

func safety_reason(time: float, start: float, rest_start: float, rest_end: float, duration: float) -> String:
    if start >= rest_start and start < rest_end: return "rest_phrase"
    if start >= duration or time >= duration: return "eof_pending"
    if time >= rest_start and time < rest_end: return "rest_pending"
    return "eligible"

func build_expected() -> Dictionary:
    var chart: RefCounted = game.boss.friend_director.chart
    var spb: float = game.music.seconds_per_beat()
    var rest_start: float = game.music._transport.random_end
    var rest_end: float = game.music._transport.rest_end
    var duration: float = game.music._transport.duration
    var modes: Dictionary = {"basic": 0, "fast": 0}
    var per_pattern: Dictionary = {}
    var raw_actions: int = 0
    var raw_shots: int = 0
    for phrase: Dictionary in chart.action_phrases:
        var mode: String = str(phrase["mode"])
        modes[mode] = int(modes.get(mode, 0)) + 1
        var sequence: int = int(phrase["sequence_index"])
        var pattern: Dictionary
        if mode == "fast":
            pattern = game.boss.friend_slots.get_fast_pattern(sequence)
            pattern["pattern_id"] = game.boss.friend_slots.fast_cycle[posmod(sequence, game.boss.friend_slots.fast_cycle.size())]
        else:
            pattern = game.boss.friend_slots.get_normal_pattern(sequence)
        var id: String = str(pattern["pattern_id"])
        var start: float = float(phrase["start_time"])
        var lookup: String = "%s|%.6f" % [id, start]
        if not expected_plans.has(lookup): expected_plans[lookup] = []
        expected_plans[lookup].append(int(phrase["index"]))
        var row: Dictionary = per_pattern.get(id, {"phrases": 0, "actions": 0, "shots": 0})
        row["phrases"] += 1
        var plan: Dictionary = Planner.build_plan(pattern, start, spb, Vector2(2900, 300), Vector2(3270, 300), game.boss.PLAN_ARENA)
        for index: int in plan["actions"].size():
            var action: Dictionary = plan["actions"][index]
            var count: int = int(action.get("count", 3))
            var shots: int = count * (2 if action["type"] == "side_spray" else 1) if action["type"] in ["ring", "fan", "side_spray"] else 0
            var key: String = "%d/%d" % [int(phrase["index"]), index]
            expected_actions[key] = {"time": float(action["time"]), "pattern": id, "type": action["type"], "shots": shots, "reason": safety_reason(float(action["time"]), start, rest_start, rest_end, duration)}
            row["actions"] += 1
            row["shots"] += shots
            raw_actions += 1
            raw_shots += shots
        per_pattern[id] = row
    for fixed: Dictionary in chart.fixed_attack_events:
        expected_fixed["fixed|%.6f" % float(fixed["time"])] = {"time": float(fixed["time"]), "reason": safety_reason(float(fixed["time"]), float(fixed["time"]), rest_start, rest_end, duration)}
    for formation: Dictionary in chart.laser_formations:
        expected_formations["formation|%d" % int(formation["index"])] = {"time": float(formation["start_time"]), "lines": formation["lasers"].size(), "pattern": formation["pattern"], "reason": safety_reason(float(formation["start_time"]), float(formation["start_time"]), rest_start, rest_end, duration)}
    return {"phrases": chart.action_phrases.size(), "modes": modes, "fixed": chart.fixed_attack_events.size(), "formations": chart.laser_formations.size(), "actions": raw_actions, "projectiles": raw_shots, "patterns": per_pattern, "rest_start": rest_start, "rest_end": rest_end, "duration": duration}

func run() -> void:
    var started: int = Time.get_ticks_msec()
    game = CoverageGame.new()
    game.owner_test = self
    game.visible = false
    root.add_child(game)
    game.player = Player.new()
    game.player.configure(game)
    game.add_child(game.player)
    game.player.revive(Vector2(3270, 300))
    game.player.invuln = 1000000.0
    game.player.set_physics_process(false)
    var floor_body: StaticBody2D = StaticBody2D.new()
    var floor_shape: CollisionShape2D = CollisionShape2D.new()
    var floor_rect: RectangleShape2D = RectangleShape2D.new()
    floor_rect.size = Vector2(1000, 20)
    floor_shape.shape = floor_rect
    floor_shape.position = Vector2(3000, 310)
    floor_body.add_child(floor_shape)
    game.add_child(floor_body)
    game.music = Music.new()
    game.add_child(game.music)
    game.music.configure(game, "res://data/full_song_timeline.json")
    game.music._dummy = true
    game.music.set_process(false)
    game.boss = CountedBoss.new()
    game.add_child(game.boss)
    game.boss.configure(game, Vector2(2900, 300))
    game.boss.health = 24
    game.boss._cube_rng.seed = 20261024
    game.boss.set_physics_process(false)
    var expected: Dictionary = build_expected()
    check(expected["phrases"] == 228 and expected["modes"]["basic"] == 141 and expected["modes"]["fast"] == 87, "source contains228 phrases:141normal and87fast")
    check(expected["fixed"] == 24 and expected["formations"] == 48, "source contains24fixed cues and48laser formations")
    check(game.music._device_dummy and game.music.is_full_song(), "real full-song runtime uses Dummy with no physical playback")
    await physics_frame
    game.boss.start_encounter()
    var frames: int = 0
    var max_frames: int = int(ceil(float(expected["duration"]) / DT)) + 5
    while game.music.running and frames < max_frames:
        game.music._process(DT)
        game.boss._physics_process(DT)
        game.tick_objects(DT)
        frames += 1
        if frames % 1000 == 0:
            await process_frame
    game.tick_objects(0.0)
    var missing: Array[Dictionary] = []
    var duplicates: Array[String] = []
    var cancellations: Dictionary = {}
    var expected_physical_shots: int = 0
    for key: String in expected_actions:
        var row: Dictionary = expected_actions[key]
        var count: int = int(game.executed.get(key, 0))
        if count > 1: duplicates.append(key)
        if count == 1:
            expected_physical_shots += int(row["shots"])
        elif count == 0:
            var reason: String = str(row["reason"])
            if reason == "eligible":
                reason = str(game.safety_pending.get(key, ""))
                if reason.is_empty() and float(row["time"]) < float(expected["rest_start"]) and float(row["time"]) + DT + 0.000001 >= float(expected["rest_start"]): reason = "frame_boundary_rest"
                if reason.is_empty() and float(row["time"]) < float(expected["duration"]) and float(row["time"]) + DT + 0.000001 >= float(expected["duration"]): reason = "frame_boundary_eof"
            if reason.is_empty() or reason == "eligible":
                missing.append({"key": key, "pattern": row["pattern"], "type": row["type"], "time": row["time"]})
            else:
                cancellations[reason] = int(cancellations.get(reason, 0)) + 1
    var missing_hazards: Array[String] = []
    for table: Dictionary in [expected_fixed, expected_formations]:
        for key: String in table:
            var row: Dictionary = table[key]
            if row["reason"] != "eligible": continue
            if not game.hazard_records.has(key):
                missing_hazards.append(key)
            else:
                game.geometry_ok = game.geometry_ok and int(game.hazard_records[key]["count"]) == 1
                if row.has("lines"): game.geometry_ok = game.geometry_ok and int(game.hazard_records[key]["lines"]) == int(row["lines"])
    check(frames < max_frames and not game.music.running and game.story_safe, "bounded virtual60Hz reaches living Boss EOF safety")
    check(game.music.get_transport_generation() == 1, "random threshold queues immediately: exactly one chart pass, no replay epoch")
    check(missing.is_empty() and duplicates.is_empty() and int(game.stats.get("unmatched_plan", 0)) == 0, "every eligible source action executes once or has an explicit safety-boundary cancellation")
    check(missing_hazards.is_empty() and game.geometry_ok, "all source fixed/laser cues produce matching real geometry once")
    check(int(game.stats.get("projectile_requests", 0)) == expected_physical_shots, "actual projectile spawn requests equal source count for executed ring/fan/spray actions")
    check(int(game.stats.get("projectile_success", 0)) == expected_physical_shots and int(game.stats.get("projectile_rejected_budget", 0)) == 0 and int(game.stats.get("hazard_rejected_budget", 0)) == 0, "real TTL/geometry cleanup avoids hidden budget rejection")
    check(game.hazard_counts.has("cube_x") and game.hazard_counts.has("cube_plus"), "real fixed carriers include both seeded X/plus geometry")
    for kind: String in ["diamond", "parallel", "grid", "rotating"]:
        check(game.hazard_counts.has(kind), "real laser geometry includes " + kind)
    for pattern: String in expected["patterns"]:
        check(int(game.pattern_counts.get(pattern, 0)) == int(expected["patterns"][pattern]["phrases"]), "real phrase start count matches source pool " + pattern)
    check(game.shots.is_empty() and game.hazards.is_empty() and game.boss._authored_actions.is_empty() and game.player.health == game.player.max_health, "rest and EOF leave no live danger, queued action or hidden player damage")
    var duel_status: Dictionary = game.boss.get_navigation_status()
    var extra_attacks: int = int(duel_status.get("extra_attacks", 0))
    var extra_hits: int = int(duel_status.get("extra_hits", 0))
    var duel_enabled: bool = duel_status.get("duel_enabled", false) == true
    check(duel_enabled, "new melee remains enabled during the unchanged full-source accounting")
    if extra_attacks > 0:
        check(missing.is_empty() and duplicates.is_empty() and int(game.stats.get("projectile_success", 0)) == expected_physical_shots and missing_hazards.is_empty(), "actual extra melee coexists with complete source actions, shots and hazards")
    var elapsed_ms: int = Time.get_ticks_msec() - started
    check(elapsed_ms < 60000, "seven-minute source is verified in bounded wall time under60s")
    var report: Dictionary = {"schema": 1, "virtual_step_seconds": DT, "virtual_frames": frames, "wall_ms": elapsed_ms, "source": expected, "actual": game.stats, "events": game.event_counts, "patterns": game.pattern_counts, "projectile_requests_by_pattern": game.requests_by_pattern, "actions_by_pattern": game.actions_by_pattern, "projectile_success_by_pattern": game.successes_by_pattern, "projectile_refused_by_pattern_and_reason": game.refused_by_pattern, "hazard_geometry_counts": game.hazard_counts, "hazard_geometry_records": game.hazard_records, "geometry_valid": game.geometry_ok, "peak_live_projectiles": game.max_shots, "peak_live_hazards": game.max_hazards, "source_projectiles_for_executed_actions": expected_physical_shots, "safety_cancellations": cancellations, "runtime_skip_reasons": game.skip_reasons, "formation11": game.formation11, "missing_actions": missing, "duplicate_actions": duplicates, "missing_hazards": missing_hazards, "sections": game.sections, "transport_generation": game.music.get_transport_generation(), "extra_attacks": extra_attacks, "extra_hits": extra_hits, "duel_enabled": duel_enabled, "duel_fixture_note": "Player immunity isolates source emission; extra_hits counts accepted HP contacts only. Zero extra attacks is reported without forcing a gap.", "checks": {"passed": passed, "failed": failed}}
    var output: FileAccess = FileAccess.open("res://artifacts/full-song-coverage.json", FileAccess.WRITE)
    if output != null:
        output.store_string(JSON.stringify(report, "  ") + "\n")
        output.close()
    else:
        check(false, "coverage JSON output opens on D")
    print("FULL_SONG_COVERAGE: %d passed, %d failed; %d virtual frames in %dms; source shots%d actual%d" % [passed, failed, frames, elapsed_ms, expected_physical_shots, int(game.stats.get("projectile_success", 0))])
    game.free()
    await process_frame
    quit(1 if failed > 0 else 0)

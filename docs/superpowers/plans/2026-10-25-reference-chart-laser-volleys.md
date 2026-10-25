# Reference Chart + Multi-Volley Center-Tracking Lasers Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the shipped chart with the reference chart and make each laser formation fire half-beat volleys that lock onto the player's position once, at each volley's warning start.

**Architecture:** The chart is data. `laser_formation_planner.gd` records each line's offset from the arena center; `BossHazard` clusters lines by damage time (half a beat) and re-bases each cluster to `get_laser_arena().get_center()` exactly once at the cluster's warning start; `combat/boss.gd` passes the half-beat window and caches the arena. One hazard per formation is preserved.

**Tech Stack:** Godot 4.7, GDScript, headless `SceneTree` tests driven by `tools/verify_main.ps1`.

**Spec:** `docs/superpowers/specs/2026-10-25-reference-chart-and-laser-volleys-design.md`

## Global Constraints

- Work only inside `D:\code\aigame-ncu-integrate`; never `cd` to the original repository root.
- Never commit `IF_story(1)/`, its ZIP, private audio, renders, credentials, logs, or absolute paths.
- Copy exactly one file from the reference: `boss_attack/data/if_infinity.chart.json`. The OGG, BPM 203, offset 245 ms, section beats, caps (24 hazards / 180 projectiles) and calibration stay unchanged.
- One `BossHazard` per source formation. Cubes never track. A volley already in warning when the hazard is created never moves. One warn and one fire SFX per hazard.
- `main.gd`, `combat/boss.gd`, `combat/boss_hazard.gd` and `tools/verify_main.ps1` already carry uncommitted work from other features. Edit them as needed, but never stage them wholesale; report their working-tree changes instead. Never revert them.
- Commit only feature-owned, clean files: the chart, `data/full_song_timeline.json`, docs, the clean tests/tools, and new files.
- Full-suite output must print `0 failed` with no `SCRIPT ERROR`, `ERROR`, `FAIL `, leaked nodes, or timeout.
- Every GDScript file uses tabs for indentation, matching the repository.

---

### Task 1: Replace the chart and update every hardcoded baseline

**Files:**
- Modify: `boss_attack/data/if_infinity.chart.json` (replace bytes)
- Modify: `data/full_song_timeline.json:7`
- Modify: `tools/audit_friend_chart.gd:23`
- Modify: `tests/full_song_boss_test.gd:82`
- Modify: `tests/full_song_offset_test.gd:57,62,64`
- Modify: `tests/full_song_transport_test.gd:75,77`
- Modify: `tests/heavy_judge_test.gd:109-135`
- Modify: `tests/main_full_song_test.gd:116`
- Modify: `docs/full-song-runtime.md:5`
- Modify: `docs/friend-boss-main-integration.md` (append note)
- Modify: `docs/friend-handoff-compatibility.md` (append note)

**Interfaces:**
- Consumes: the reference chart at `IF_story(1)/IF_story/IF/boss_attack/data/if_infinity.chart.json` (SHA256 `5caa2721292be473c7d8ca760c8948d1aab43b42fc82a80fb02e352369aebe5f`, 59615 bytes).
- Produces: parser counts used by every later task: 1703 notes / 1702 timed / 121 heavy / 331 long / 36 cubes / 259 ordinary / 67 formations / 237 phrases (114 basic, 123 fast) / 17 phases / end 409.530714285714 s.

- [ ] **Step 1: Copy only the chart and verify identity**

```bash
cp "IF_story(1)/IF_story/IF/boss_attack/data/if_infinity.chart.json" boss_attack/data/if_infinity.chart.json
sha256sum boss_attack/data/if_infinity.chart.json
wc -c boss_attack/data/if_infinity.chart.json
git status --porcelain boss_attack/data/if_infinity.chart.json
```

Expected: hash `5caa2721292be473c7d8ca760c8948d1aab43b42fc82a80fb02e352369aebe5f`, size `59615`, and the only tracked change under `boss_attack/` is the chart. No OGG or other file changed.

- [ ] **Step 2: Update the timeline hash**

In `data/full_song_timeline.json`, replace line 7 only:

```json
  "expected_chart_sha256": "5caa2721292be473c7d8ca760c8948d1aab43b42fc82a80fb02e352369aebe5f",
```

`expected_audio_sha256` stays `007d002c1a5472af2ef78e62e5027c89b28cfb0f15b4cd5880ce75c6b66547b5`.

- [ ] **Step 3: Update the audit dictionary**

Replace the dictionary at `tools/audit_friend_chart.gd:23`:

```gdscript
    var expected: Dictionary = {"notes":1703,"timed_notes":1702,"unique_times":1048,"timing_groups":839,"heavy_groups":121,"endbeat_records":331,"ordinary_lasers":259,"phases":17,"paired_note_groups":360,"action_phrases":237,"fixed_attack_events":36,"laser_formations":67,"basic_phrases":114,"fast_phrases":123}
```

- [ ] **Step 4: Update the five non-coverage test baselines**

`tests/full_song_boss_test.gd:82`:

```gdscript
    check(game.music.is_full_song() and game.boss.friend_director.chart.action_phrases.size() == 237, "actual main Boss loads complete source director")
```

`tests/full_song_offset_test.gd:57` and `:62`:

```gdscript
    check(before.size() == 121, "fixture exposes all 121 heavy groups")
```

```gdscript
    check(after.size() == 121 and music._full_chart != chart_before, "chart is re-parsed instead of mutated")
```

`tests/full_song_offset_test.gd:64`:

```gdscript
    check(music._full_chart.timed_note_count == 1702 and music._full_chart.action_phrases.size() == 237, "chart counts and phrases are unchanged")
```

`tests/full_song_transport_test.gd:75,77`:

```gdscript
    check(music._full_chart.timed_note_count == 1702 and music._full_chart.action_phrases.size() == 237, "complete source chart is parsed without short-placeholder truncation")
```

```gdscript
    check(heavy.size() == 121 and not str(heavy[0]["id"]).is_empty(), "121 source heavy groups expose stable exact-key IDs")
```

Leave `tests/full_song_transport_test.gd:78` (`heavy[0]["time"] == 73.0 * 60.0 / 203.0 + 0.245`) unchanged.

`tests/heavy_judge_test.gd:109-135` becomes:

```gdscript
    # Read-only validation of the reference chart; no audio read/copied.
    var parser: RefCounted = Parser.new()
    var parsed: bool = parser.parse_file("res://boss_attack/data/if_infinity.chart.json", 203.0, 0.0, 4.0)
    check(parsed and parser.heavy_groups.size() == 121, "reviewed parser exposes all 121 source heavy groups")
    var full_groups: Array[Dictionary] = []
    full_groups.assign(parser.heavy_groups)
    judge.setup(full_groups, 0.125, 121)
    var times: Array[float] = []
    for group: Dictionary in full_groups:
        times.append(float(group["time"]))
    times.sort()
    for time: float in times:
        judge.register_block(time)
    var all_results: Array[Dictionary] = judge.update(times.back() + 3.0 if not times.is_empty() else 1.0)
    var ids: Dictionary = {}
    var all_success: bool = all_results.size() == 121
    for result: Dictionary in all_results:
        ids[result["id"]] = true
        all_success = all_success and result["success"] and absf(float(result["error_seconds"])) <= 0.125001 and int(result["id"]) >= 0 and int(result["id"]) < 121 and int(result["generation"]) == 121
    check(all_success and ids.size() == 121, "full-song long frame gap yields 121 independent retained results and bounded unique IDs")
    check(judge.update(times.back() + 4.0 if not times.is_empty() else 2.0).is_empty(), "full-song results never emit twice")
    judge.setup(full_groups, 0.125, 122)
    var fresh: Array[Dictionary] = judge.update(times.back() + 5.0 if not times.is_empty() else 3.0)
    var all_miss: bool = fresh.size() == 121
    for result: Dictionary in fresh:
        all_miss = all_miss and not result["success"] and result["generation"] == 122
    check(all_miss, "new song loop has no accepted-input carry from prior 121 marks")
```

`tests/main_full_song_test.gd:116`:

```gdscript
    check(int(stats["timed_notes"]) == 1702 and music.get_heavy_groups().size() == 121 and int(stats["action_phrases"]) == 237,"main parsed full1702/121/237 source chart")
```

- [ ] **Step 5: Update the runtime doc's baseline sentence**

Replace `docs/full-song-runtime.md:5` with:

```markdown
`data/full_song_timeline.json` explicitly sets 203 BPM and +245 ms. Chart metadata and its audio-note offset do not override that configuration. The reference source chart contains 1702 timed notes, 121 heavy groups and 237 action phrases, with its last event at 409.530714 seconds. The OGG is approximately 418.515737 seconds long. These matching counts and coverage do not prove subjective listening alignment on a particular sound device.
```

- [ ] **Step 6: Append the replacement note to both handoff docs**

Append this single line at the end of `docs/friend-boss-main-integration.md`:

```markdown
Later update (2026-10-25): the shipped chart was replaced by the reference chart (`5caa2721292be473c7d8ca760c8948d1aab43b42fc82a80fb02e352369aebe5f`, 59615 bytes). The earlier byte-identity statement describes the previous handoff only.
```

Append the same line to `docs/friend-handoff-compatibility.md`. Do not rewrite their historical statements.

- [ ] **Step 7: Run the focused gate**

```bash
powershell.exe -NoProfile -Command "& ./tools/verify_main.ps1 -Only @('source-chart','full_song_transport_test','full_song_offset_test','heavy_judge_test','main_full_song_test','full_song_boss_test')"
```

Expected: every check prints `0 failed`; no `SCRIPT ERROR`, `ERROR`, or `FAIL ` in output. `full_song_coverage_test` is expected to fail until Task 4 and is not in this gate.

- [ ] **Step 8: Commit the data and baseline updates**

```bash
git add boss_attack/data/if_infinity.chart.json data/full_song_timeline.json tools/audit_friend_chart.gd tests/full_song_boss_test.gd tests/full_song_offset_test.gd tests/full_song_transport_test.gd tests/heavy_judge_test.gd tests/main_full_song_test.gd docs/full-song-runtime.md docs/friend-boss-main-integration.md docs/friend-handoff-compatibility.md docs/superpowers/specs/2026-10-25-reference-chart-and-laser-volleys-design.md
git commit -m "Replace the Boss chart with the beat-grouped reference score"
```

---

### Task 2: Record each line's center offset and prove exact re-basing

**Files:**
- Modify: `combat/friend_rhythm/laser_formation_planner.gd:70-82`
- Create: `tests/laser_tracking_test.gd`

**Interfaces:**
- Consumes: `Planner.build_lines(formation, config, arena_rect) -> Array[Dictionary]` (existing).
- Produces: every line gains `"center_offset": Vector2` with `origin == arena_rect.get_center() + center_offset`. All existing keys stay unchanged.

- [ ] **Step 1: Create the failing planner test**

Create `tests/laser_tracking_test.gd`:

```gdscript
extends SceneTree
## Synthetic checks for half-beat volley clustering and one-shot center re-aim.
const Planner = preload("res://combat/friend_rhythm/laser_formation_planner.gd")
const Hazard = preload("res://combat/boss_hazard.gd")

const WINDOW: float = 0.5 * 60.0 / 203.0

var passed: int = 0
var failed: int = 0

func _initialize() -> void:
    call_deferred("run")

func check(value: bool, label: String) -> void:
    if value:
        passed += 1
        print("PASS ", label)
    else:
        failed += 1
        push_error("FAIL " + label)

func config() -> Dictionary:
    return {"line_thickness": 9.0, "patterns": {
        "diamond": {"safe_radius": 44.0, "safe_offsets": [[0.0, 0.0]]},
        "parallel": {"line_offsets": [-36.0, -12.0, 12.0, 36.0], "safe_offsets": [[0.0, 0.0]]},
        "grid": {"vertical_half_gap": 64.0, "horizontal_half_gap": 43.0, "safe_offsets": [[0.0, 0.0]]},
        "rotating": {"safe_radius": 38.0, "safe_offsets": [[0.0, 0.0]]},
    }}

func formation(pattern: String, index: int = 0) -> Dictionary:
    var lasers: Array[Dictionary] = []
    for line: int in 4:
        lasers.append({"time": 9.0 + float(line) * 0.1, "damage_time": 10.0 + float(line) * 0.1, "source_index": line})
    return {"index": index, "occurrence": 0, "pattern": pattern, "lasers": lasers}

func arena_at(center: Vector2) -> Rect2:
    return Rect2(center - Vector2(360.0, 220.0), Vector2(720.0, 440.0))

func run() -> void:
    var arena: Rect2 = arena_at(Vector2(400, 280))
    var center: Vector2 = arena.get_center()
    for pattern: String in ["diamond", "parallel", "grid", "rotating"]:
        var lines: Array[Dictionary] = Planner.build_lines(formation(pattern), config(), arena)
        var ok: bool = lines.size() == 4
        for line: Dictionary in lines:
            var carries_offset: bool = typeof(line.get("center_offset")) == TYPE_VECTOR2
            ok = ok and carries_offset
            if carries_offset:
                var offset: Vector2 = line["center_offset"]
                var origin: Vector2 = line["origin"]
                ok = ok and origin.is_equal_approx(center + offset)
        check(ok, pattern + " lines carry an exact center offset")

    var center_a: Vector2 = Vector2(400, 280)
    var center_b: Vector2 = Vector2(520, 300)
    var lines_a: Array[Dictionary] = Planner.build_lines(formation("diamond"), config(), arena_at(center_a))
    var lines_b: Array[Dictionary] = Planner.build_lines(formation("diamond"), config(), arena_at(center_b))
    var rebase_ok: bool = true
    for index: int in 4:
        var offset_a: Vector2 = lines_a[index]["center_offset"]
        var rebased: Vector2 = center_b + offset_a
        var built: Vector2 = lines_b[index]["origin"]
        rebase_ok = rebase_ok and rebased.is_equal_approx(built)
        rebase_ok = rebase_ok and is_equal_approx(float(lines_a[index]["angle_radians"]), float(lines_b[index]["angle_radians"]))
        for other: int in 4:
            var origin_a: Vector2 = lines_a[index]["origin"]
            var origin_b: Vector2 = lines_a[other]["origin"]
            var other_offset: Vector2 = lines_a[other]["center_offset"]
            var moved_a: Vector2 = center_b + offset_a
            var moved_b: Vector2 = center_b + other_offset
            rebase_ok = rebase_ok and is_equal_approx(origin_a.distance_to(origin_b), moved_a.distance_to(moved_b))
    check(rebase_ok, "re-basing to a new center preserves distances and angles")

    var grid: Array[Dictionary] = Planner.build_lines(formation("grid"), config(), arena)
    var offsets: Array[Vector2] = []
    for line: Dictionary in grid:
        offsets.append(line["center_offset"])
    check(offsets[0].is_equal_approx(Vector2(-64.0, -240.0)) and offsets[1].is_equal_approx(Vector2(64.0, -240.0)) and offsets[2].is_equal_approx(Vector2(-380.0, -43.0)) and offsets[3].is_equal_approx(Vector2(-380.0, 43.0)), "grid keeps its full-arena offsets")

    print("LASER_TRACKING_TEST: %d passed, %d failed" % [passed, failed])
    quit(1 if failed > 0 else 0)
```

- [ ] **Step 2: Run it and confirm the planner checks fail**

```bash
"D:\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe" --headless --audio-driver Dummy --path . --script res://tests/laser_tracking_test.gd
```

Expected: `FAIL diamond lines carry an exact center offset` (and the other three patterns, the re-base check, and the grid offsets), with `0 passed, 6 failed`.

- [ ] **Step 3: Add the offset to every emitted line**

In `combat/friend_rhythm/laser_formation_planner.gd`, add one key to the dictionary appended at line 70:

```gdscript
		lines.append({
			"formation_index": int(formation.get("index", -1)),
			"line_index": index,
			"pattern": pattern,
			"angle_radians": deg_to_rad(angle_degrees),
			"origin": origin,
			"center_offset": origin - center,
			"thickness": thickness,
			"warning_time": float(record["time"]),
			"damage_time": float(record["damage_time"]),
			"active_until": float(formation.get("active_until", record["damage_time"] + 0.7)),
			"damage": float(record.get("damage", 6.0)),
			"source_index": int(record.get("source_index", -1)),
		})
```

- [ ] **Step 4: Re-run and confirm all planner checks pass**

```bash
"D:\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe" --headless --audio-driver Dummy --path . --script res://tests/laser_tracking_test.gd
```

Expected: `LASER_TRACKING_TEST: 6 passed, 0 failed`.

- [ ] **Step 5: Run the full-song tests that exercise the planner**

```bash
powershell.exe -NoProfile -Command "& ./tools/verify_main.ps1 -Only @('full_song_coverage_test','full_song_boss_test')"
```

Expected: `full_song_boss_test` passes. `full_song_coverage_test` still fails only on the old baselines (228/24/48), so the PowerShell command exits nonzero; no geometry or planner failure appears.

- [ ] **Step 6: Commit the planner and the new test**

```bash
git add combat/friend_rhythm/laser_formation_planner.gd tests/laser_tracking_test.gd
git commit -m "Record laser line center offsets for per-volley re-aim"
```

---

### Task 3: Cluster volleys and re-aim each one exactly once

**Files:**
- Modify: `combat/boss_hazard.gd:5-23` (state and signature), `:63-100` (snapshot and physics), add helpers
- Modify: `tests/laser_tracking_test.gd` (append fixtures and hazard checks)

**Interfaces:**
- Consumes: lines from Task 2 (each with `center_offset`).
- Produces:
  - `configure_lines(p_game, owner_boss, records, arena, version, formation_kind = "laser", half_beat_seconds = 0.0) -> void`.
  - `get_geometry_snapshot()["tracking"] = {"window": float, "clusters": int, "aimed": int}`.
  - `_build_clusters() -> void`, `_aim_due_clusters(owner_boss: Node, now: float) -> void`, `_aimed_count() -> int`.

- [ ] **Step 1: Extend the test with deterministic fixtures and seven hazard checks**

Append these inner classes after `const WINDOW` in `tests/laser_tracking_test.gd`:

```gdscript
class Clock extends Node:
    var time: float = 0.0
    func get_score_time() -> float:
        return time

class ProbePlayer extends Node2D:
    var dead: bool = false
    var health: int = 8
    func receive_hit(_amount: int, _at: Vector2) -> void:
        pass

class ProbeBoss extends Node:
    var dead: bool = false
    var hazard_generation: int = 1
    var player: Node2D
    func get_laser_arena() -> Rect2:
        return Rect2(player.global_position - Vector2(360.0, 240.0), Vector2(720.0, 440.0))

class GameProbe extends Node:
    var music: Node
    var player: ProbePlayer
    var story_safe: bool = false
    var _paused: bool = false
    var outcome: String = ""
    var damage_requests: int = 0
    func emit_fx(_kind: String, _at: Vector2, _direction: Vector2 = Vector2.ZERO, _power: float = 1.0) -> void:
        pass
    func damage_player(amount: int, at: Vector2) -> void:
        damage_requests += 1
        player.receive_hit(amount, at)
```

Add `var games: Array[Node] = []` beside `passed`/`failed`, then add these helpers before `run()`:

```gdscript
func make_fixture(created_at: float) -> Dictionary:
    var game := GameProbe.new()
    var clock := Clock.new()
    var player := ProbePlayer.new()
    player.position = Vector2(400, 300)
    var boss := ProbeBoss.new()
    boss.player = player
    game.music = clock
    game.player = player
    game.add_child(clock)
    game.add_child(player)
    game.add_child(boss)
    root.add_child(game)
    games.append(game)
    clock.time = created_at
    return {"game": game, "clock": clock, "player": player, "boss": boss}

func volley_formation() -> Dictionary:
    var lasers: Array[Dictionary] = [
        {"time": 9.5, "damage_time": 10.5, "source_index": 0},
        {"time": 9.6, "damage_time": 10.6, "source_index": 1},
        {"time": 11.5, "damage_time": 12.5, "source_index": 2},
        {"time": 11.6, "damage_time": 12.6, "source_index": 3},
    ]
    return {"index": 0, "occurrence": 0, "pattern": "diamond", "lasers": lasers}

func make_hazard(fixture: Dictionary) -> Variant:
    var game: GameProbe = fixture["game"]
    var boss: ProbeBoss = fixture["boss"]
    var arena: Rect2 = boss.get_laser_arena()
    var lines: Array[Dictionary] = Planner.build_lines(volley_formation(), config(), arena)
    var hazard: Variant = Hazard.new()
    game.add_child(hazard)
    hazard.configure_lines(game, boss, lines, arena, 1, "diamond", WINDOW)
    hazard.set_physics_process(false)
    fixture["hazard"] = hazard
    return hazard

func line_count(hazard: Variant) -> int:
    var value: Array = hazard.lines
    return value.size()

func step(fixture: Dictionary, at: float) -> void:
    var clock: Clock = fixture["clock"]
    clock.time = at
    var hazard: Variant = fixture["hazard"]
    hazard._physics_process(1.0 / 60.0)

func point_at(line: Variant, key: String) -> Vector2:
    var value: Vector2 = line[key]
    return value

func same_geometry(left: Variant, right: Variant) -> bool:
    var left_dict: Dictionary = left
    var right_dict: Dictionary = right
    if left_dict.size() != right_dict.size():
        return false
    if typeof(left_dict.get("center_offset")) == TYPE_VECTOR2:
        var left_offset: Vector2 = left_dict["center_offset"]
        var right_offset: Vector2 = right_dict["center_offset"]
        if not left_offset.is_equal_approx(right_offset):
            return false
    for key: String in ["origin", "a", "b", "angle_radians", "thickness", "warning_time", "damage_time", "active_until"]:
        if typeof(left_dict.get(key)) == TYPE_VECTOR2:
            if not point_at(left_dict, key).is_equal_approx(point_at(right_dict, key)):
                return false
        elif not is_equal_approx(float(left_dict[key]), float(right_dict[key])):
            return false
    return true
```

Then insert the hazard checks inside `run()` immediately before the final `print("LASER_TRACKING_TEST: ...")` line:

```gdscript
    var fixture: Dictionary = make_fixture(8.0)
    var hazard: Variant = make_hazard(fixture)
    var spawn: Dictionary = hazard.get_geometry_snapshot()
    check(int(spawn["tracking"]["clusters"]) == 2 and int(spawn["tracking"]["aimed"]) == 0 and is_equal_approx(float(spawn["tracking"]["window"]), WINDOW), "four lines cluster into two half-beat volleys")
    var spawn_lines: Array = spawn["lines"]

    var game: GameProbe = fixture["game"]
    game.player.global_position = Vector2(460, 300)
    var aimed_center: Vector2 = Vector2(460, 280)
    step(fixture, 9.5)
    var first: Dictionary = hazard.get_geometry_snapshot()
    var first_lines: Array = first["lines"]
    var first_ok: bool = int(first["tracking"]["aimed"]) == 1
    for index: int in [0, 1]:
        var offset: Vector2 = first_lines[index]["center_offset"]
        first_ok = first_ok and point_at(first_lines[index], "origin").is_equal_approx(aimed_center + offset)
        first_ok = first_ok and (point_at(first_lines[index], "a") - point_at(spawn_lines[index], "a")).is_equal_approx(Vector2(60.0, 0.0))
        first_ok = first_ok and (point_at(first_lines[index], "b") - point_at(spawn_lines[index], "b")).is_equal_approx(Vector2(60.0, 0.0))
    for index: int in [2, 3]:
        first_ok = first_ok and same_geometry(first_lines[index], spawn_lines[index])
    check(first_ok, "first volley re-centers once on the moved player")

    game.player.global_position = Vector2(340, 300)
    step(fixture, 11.5)
    var second: Dictionary = hazard.get_geometry_snapshot()
    var second_lines: Array = second["lines"]
    var second_ok: bool = int(second["tracking"]["aimed"]) == 2
    for index: int in [2, 3]:
        var offset: Vector2 = second_lines[index]["center_offset"]
        second_ok = second_ok and point_at(second_lines[index], "origin").is_equal_approx(Vector2(340, 280) + offset)
        second_ok = second_ok and (point_at(second_lines[index], "a") - point_at(spawn_lines[index], "a")).is_equal_approx(Vector2(-60.0, 0.0))
    for index: int in [0, 1]:
        second_ok = second_ok and same_geometry(second_lines[index], first_lines[index])
    check(second_ok, "second volley re-centers while the first stays put")

    game.player.global_position = Vector2(520, 300)
    step(fixture, 11.8)
    var frozen: Dictionary = hazard.get_geometry_snapshot()
    var frozen_ok: bool = int(frozen["tracking"]["aimed"]) == 2
    for index: int in 4:
        frozen_ok = frozen_ok and same_geometry(frozen["lines"][index], second_lines[index])
    check(frozen_ok, "later movement never re-aims an aimed volley")

    var late: Dictionary = make_fixture(9.8)
    var late_hazard: Variant = make_hazard(late)
    var late_spawn: Array = late_hazard.get_geometry_snapshot()["lines"]
    var late_aimed: bool = int(late_hazard.get_geometry_snapshot()["tracking"]["aimed"]) == 1
    var late_game: GameProbe = late["game"]
    late_game.player.global_position = Vector2(460, 300)
    step(late, 10.0)
    var late_after: Array = late_hazard.get_geometry_snapshot()["lines"]
    var late_ok: bool = late_aimed
    for index: int in [0, 1]:
        late_ok = late_ok and same_geometry(late_after[index], late_spawn[index])
    check(late_ok, "a volley already in warning when created never moves")

    var cube_fixture: Dictionary = make_fixture(8.0)
    var cube_game: GameProbe = cube_fixture["game"]
    var cube_boss: ProbeBoss = cube_fixture["boss"]
    var cube_plan: Dictionary = {"from": Vector2(400, 120), "to": Vector2(400, 280), "start_time": 8.0, "flight_end_time": 9.0, "damage_time": 9.2, "active_until": 9.9, "diamond": false, "thickness": 7.0}
    var cube: Variant = Hazard.new()
    cube_game.add_child(cube)
    cube.configure_cube(cube_game, cube_boss, cube_plan, cube_boss.get_laser_arena(), 1)
    cube.set_physics_process(false)
    var cube_spawn: Array = cube.get_geometry_snapshot()["lines"]
    check(int(cube.get_geometry_snapshot()["tracking"]["clusters"]) == 0 and cube_spawn.size() == 2, "cubes never cluster and keep their two authored lines")
    cube_game.player.global_position = Vector2(520, 300)
    cube_fixture["hazard"] = cube
    step(cube_fixture, 9.05)
    var cube_ok: bool = true
    for index: int in 2:
        cube_ok = cube_ok and same_geometry(cube.get_geometry_snapshot()["lines"][index], cube_spawn[index])
    check(cube_ok, "cubes never re-aim")

    var one: Dictionary = make_fixture(8.0)
    var one_hazard: Variant = make_hazard(one)
    var one_ok: bool = one_hazard.get_child_count() == 0 and line_count(one_hazard) == 4
    step(one, 9.5)
    step(one, 11.5)
    one_ok = one_ok and one_hazard.get_child_count() == 0 and line_count(one_hazard) == 4
    check(one_ok, "two volleys stay inside one hazard and spawn no child")
```

Replace the final lines of `run()` with:

```gdscript
    for game_node: Node in games:
        game_node.free()
    await process_frame
    print("LASER_TRACKING_TEST: %d passed, %d failed" % [passed, failed])
    quit(1 if failed > 0 else 0)
```

- [ ] **Step 2: Run the test and confirm the hazard checks fail**

```bash
"D:\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe" --headless --audio-driver Dummy --path . --script res://tests/laser_tracking_test.gd
```

Expected: the six planner checks pass; the seven hazard checks fail (`tracking` missing, geometry never moves). No `SCRIPT ERROR`.

- [ ] **Step 3: Implement hazard state, clustering, re-aim and the snapshot field**

In `combat/boss_hazard.gd`, add three fields after `_fire_fx_done`:

```gdscript
var _track_window: float = 0.0
var _created_at: float = 0.0
var _clusters: Array[Dictionary] = []
```

Replace the signature and the tail of `configure_lines`:

```gdscript
func configure_lines(p_game: Node, owner_boss: Node, records: Array[Dictionary], arena: Rect2, version: int, formation_kind: String = "laser", half_beat_seconds: float = 0.0) -> void:
	game = p_game
	source = weakref(owner_boss)
	source_generation = version
	arena_rect = arena
	kind = formation_kind
	var clip_bounds: Rect2 = arena.grow(BEAM_OVERSCAN)
	for record: Dictionary in records:
		var line: Dictionary = record.duplicate(true)
		var segment: Array[Vector2] = clipped_line(line["origin"], float(line["angle_radians"]), clip_bounds)
		if segment.size() != 2:
			continue
		line["a"] = segment[0].round()
		line["b"] = segment[1].round()
		_first_warning = minf(_first_warning, float(line["warning_time"]))
		_first_damage = minf(_first_damage, float(line["damage_time"]))
		lines.append(line)
	_track_window = maxf(0.0, half_beat_seconds)
	var music_node: Node = game.get("music") if is_instance_valid(game) else null
	_created_at = float(music_node.get_score_time()) if is_instance_valid(music_node) else 0.0
	clock_time = _created_at
	_build_clusters()
```

Add the three helpers after `configure_cube`:

```gdscript
func _build_clusters() -> void:
	_clusters.clear()
	if _track_window <= 0.0:
		return
	var order: Array[int] = []
	for index: int in lines.size():
		if typeof(lines[index].get("center_offset")) == TYPE_VECTOR2:
			order.append(index)
	if order.is_empty():
		return
	order.sort_custom(func(left: int, right: int) -> bool: return float(lines[left]["damage_time"]) < float(lines[right]["damage_time"]))
	var cluster: Dictionary = {}
	var anchor: float = 0.0
	for index: int in order:
		var damage: float = float(lines[index]["damage_time"])
		if cluster.is_empty() or damage - anchor > _track_window:
			if not cluster.is_empty():
				_finish_cluster(cluster)
				_clusters.append(cluster)
			cluster = {"indices": [], "warning": float(lines[index]["warning_time"])}
			anchor = damage
		var indices: Array = cluster["indices"]
		indices.append(index)
		cluster["warning"] = minf(float(cluster["warning"]), float(lines[index]["warning_time"]))
	if not cluster.is_empty():
		_finish_cluster(cluster)
		_clusters.append(cluster)

func _finish_cluster(cluster: Dictionary) -> void:
	var warning: float = float(cluster["warning"])
	cluster["aim_at"] = maxf(warning, _created_at)
	cluster["aimed"] = warning <= _created_at + 0.000001

func _aim_due_clusters(owner_boss: Node, now: float) -> void:
	for cluster: Dictionary in _clusters:
		if bool(cluster["aimed"]) or now + 0.000001 < float(cluster["aim_at"]):
			continue
		var arena: Rect2 = arena_rect
		if is_instance_valid(owner_boss) and owner_boss.has_method("get_laser_arena"):
			arena = owner_boss.get_laser_arena()
		var center: Vector2 = arena.get_center()
		var bounds: Rect2 = arena.grow(BEAM_OVERSCAN)
		var indices: Array = cluster["indices"]
		for index: int in indices:
			var line: Dictionary = lines[index]
			var offset: Vector2 = line["center_offset"]
			var origin: Vector2 = center + offset
			var segment: Array[Vector2] = clipped_line(origin, float(line["angle_radians"]), bounds)
			if segment.size() != 2:
				continue
			line["origin"] = origin
			line["a"] = segment[0].round()
			line["b"] = segment[1].round()
		arena_rect = arena
		cluster["aimed"] = true
```

- [ ] **Step 4: Add the tracking snapshot and call the aim loop**

Replace `get_geometry_snapshot()`:

```gdscript
func get_geometry_snapshot() -> Dictionary:
	return {"kind": kind, "lines": lines.duplicate(true), "cube": cube.duplicate(true), "generation": source_generation, "clock": clock_time, "tracking": {"window": _track_window, "clusters": _clusters.size(), "aimed": _aimed_count()}}

func _aimed_count() -> int:
	var count: int = 0
	for cluster: Dictionary in _clusters:
		if bool(cluster["aimed"]):
			count += 1
	return count
```

In `_physics_process`, insert the aim call immediately after the clock read:

```gdscript
	clock_time = float(game.music.get_score_time())
	_aim_due_clusters(owner_boss, clock_time)
	_trigger_sfx()
```

- [ ] **Step 5: Run the tracking test until all checks pass**

```bash
"D:\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe" --headless --audio-driver Dummy --path . --script res://tests/laser_tracking_test.gd
```

Expected: `LASER_TRACKING_TEST: 13 passed, 0 failed`, no `SCRIPT ERROR`, no leaked-node message.

- [ ] **Step 6: Run the hazard-dependent suite**

```bash
powershell.exe -NoProfile -Command "& ./tools/verify_main.ps1 -Only @('full_song_boss_test','boss_room_test','main_authored_boss_test','main_boss_runtime_test')"
```

Expected: every check prints `0 failed`.

- [ ] **Step 7: Commit the test additions only**

`combat/boss_hazard.gd` is dirty with unrelated work, so it stays unstaged and is reported.

```bash
git add tests/laser_tracking_test.gd
git commit -m "Prove volley clustering, one-shot re-aim and cube exclusion"
```

---

### Task 4: Wire the half-beat window into the Boss and gate density in coverage

**Files:**
- Modify: `combat/boss.gd:1092-1097` and the constants near `:12`
- Modify: `tests/full_song_coverage_test.gd:221-264, 298-299, 333-352, 364-371`
- Modify: `tools/verify_main.ps1:11`
- Modify: `docs/full-song-runtime.md:21-35, 40-41`

**Interfaces:**
- Consumes: `BossHazard.configure_lines(..., half_beat_seconds)` from Task 3; `game.music.seconds_per_beat()`.
- Produces: every full-song formation hazard reports `tracking.window == seconds_per_beat() * 0.5` and `tracking.clusters == expected volleys`; cubes report `tracking.clusters == 0`.

- [ ] **Step 1: Add the Boss constant and wire the cached arena plus half beat**

Add beside the other constants near `combat/boss.gd:12`:

```gdscript
const LASER_TRACK_HALF_BEAT: float = 0.5
```

Replace `_spawn_authored_formation`'s body between the formation copy and the hazard spawn:

```gdscript
func _spawn_authored_formation(event: Dictionary) -> void:
	if not game.has_method("spawn_boss_hazard"):
		return
	var formation: Dictionary = event.duplicate(true)
	formation["occurrence"] = int(event.get("occurrence", 0)) + _authored_cycle * (1 if _uses_full_song() else maxi(1, int(ceil(float(friend_director.chart.laser_formations.size()) / 4.0))))
	var arena: Rect2 = get_laser_arena()
	var lines: Array[Dictionary] = FriendLasers.build_lines(formation, friend_slots.get_laser_formations(), arena)
	for line: Dictionary in lines:
		for key: String in ["warning_time", "damage_time", "active_until"]:
			line[key] = float(line[key]) + _loop_origin_score
	if _uses_full_song():
		var future: Array[Dictionary] = []
		for line: Dictionary in lines:
			var now: float = float(game.music.get_score_time())
			var warning_lateness: float = now - float(line["warning_time"])
			# Source-authored short warnings remain intact at normal cadence.
			# The minimum remaining lead is only a stale-frame recovery policy.
			if warning_lateness <= _stale_window() or float(line["damage_time"]) - now >= float(game.music.timeline.get("minimum_remaining_warning_seconds", 0.15)):
				future.append(line)
			else:
				_trace_skipped("laser_line", str(formation["pattern"]), float(game.music.get_score_time()))
		lines = future
		if lines.is_empty():
			return
	var half_beat: float = 0.0
	if is_instance_valid(game) and is_instance_valid(game.music) and game.music.has_method("seconds_per_beat"):
		half_beat = float(game.music.seconds_per_beat()) * LASER_TRACK_HALF_BEAT
	var hazard: Node2D = BossHazard.new()
	hazard.configure_lines(game, self, lines, arena, hazard_generation, str(formation["pattern"]), half_beat)
	if not game.spawn_boss_hazard(hazard):
		_trace_skipped("hazard_capacity", str(formation["pattern"]), float(game.music.get_score_time()))
	else:
		_danmaku_burst(global_position + Vector2(0, -30), arena.get_center() - global_position, 1.5, "boss_cast")
```

- [ ] **Step 2: Update coverage baselines and add the volley oracle**

In `tests/full_song_coverage_test.gd`, add `"volleys": volleys` to `expected_formations`. Replace lines 262-263:

```gdscript
    for formation: Dictionary in chart.laser_formations:
        var damages: Array[float] = []
        for laser: Dictionary in formation["lasers"]:
            damages.append(float(laser["damage_time"]))
        damages.sort()
        var volleys: int = 0
        var anchor: float = 0.0
        for damage: float in damages:
            if volleys == 0 or damage - anchor > spb * 0.5:
                volleys += 1
                anchor = damage
        expected_formations["formation|%d" % int(formation["index"])] = {"time": float(formation["start_time"]), "lines": formation["lasers"].size(), "pattern": formation["pattern"], "reason": safety_reason(float(formation["start_time"]), float(formation["start_time"]), rest_start, rest_end, duration), "volleys": volleys}
```

Replace the first `check` pair (lines 298-299):

```gdscript
    check(expected["phrases"] == 237 and expected["modes"]["basic"] == 114 and expected["modes"]["fast"] == 123, "source contains237 phrases:114normal and123fast")
    check(expected["fixed"] == 36 and expected["formations"] == 67, "source contains36fixed cues and67laser formations")
```

- [ ] **Step 3: Record the tracking snapshot in the coverage fixture**

In `spawn_boss_hazard`, replace the `hazard_records[key] = ...` line with:

```gdscript
        var tracking: Dictionary = geometry.get("tracking", {})
        hazard_records[key] = {"kind": kind, "lines": geometry["lines"].size(), "count": int(hazard_records.get(key, {}).get("count", 0)) + 1, "tracking": tracking.duplicate(true)}
```

- [ ] **Step 4: Gate the volley counts and tracking window**

Replace the hazard verification loop at lines 334-342 with:

```gdscript
    var half_beat: float = game.music.seconds_per_beat() * 0.5
    var missing_hazards: Array[String] = []
    for table: Dictionary in [expected_fixed, expected_formations]:
        for key: String in table:
            var row: Dictionary = table[key]
            if row["reason"] != "eligible": continue
            if not game.hazard_records.has(key):
                missing_hazards.append(key)
            else:
                var record: Dictionary = game.hazard_records[key]
                var tracking: Dictionary = record.get("tracking", {})
                game.geometry_ok = game.geometry_ok and int(record["count"]) == 1
                if row.has("lines"):
                    game.geometry_ok = game.geometry_ok and int(record["lines"]) == int(row["lines"])
                    game.geometry_ok = game.geometry_ok and int(tracking.get("clusters", -1)) == int(row["volleys"])
                    game.geometry_ok = game.geometry_ok and absf(float(tracking.get("window", -1.0)) - half_beat) <= 0.000001
                else:
                    game.geometry_ok = game.geometry_ok and int(tracking.get("clusters", -1)) == 0
```

Add one check after the existing "all source fixed/laser cues" check:

```gdscript
    check(int(game.skip_reasons.get("laser_line", 0)) == 0, "reference chart never drops a laser line as stale")
```

- [ ] **Step 5: Register the new test**

Add `'laser_tracking_test'` to the `$checks` array in `tools/verify_main.ps1:11`, immediately after `'full_song_coverage_test'`:

```powershell
'full_song_coverage_test','laser_tracking_test','audio_calibration_test'
```

`tools/verify_main.ps1` is dirty; leave the edit uncommitted and report it.

- [ ] **Step 6: Run the coverage gate and inspect the report**

```bash
powershell.exe -NoProfile -Command "& ./tools/verify_main.ps1 -Only @('full_song_coverage_test','laser_tracking_test')"
```

Expected: `0 failed` in both. Then read `artifacts/full-song-coverage.json` and confirm:

- `source.phrases` = 237, `source.modes.basic` = 114, `source.modes.fast` = 123;
- `source.fixed` = 36, `source.formations` = 67;
- `missing_hazards` is empty;
- `actual.hazard_rejected_budget` = 0;
- `runtime_skip_reasons` has no `laser_line`;
- `wall_ms` < 60000;
- `hazard_geometry_records` has 67 `formation|*` keys, each `count` 1 and `tracking.clusters` matching the oracle.

If any formation exceeds the 24-hazard cap or reports a missing hazard, stop and investigate hazard lifetime/dispatch. Do not raise the cap or relax the check.

- [ ] **Step 7: Refresh the runtime doc's count table from the report**

In `docs/full-song-runtime.md`, replace the table at lines 23-33 and the totals sentence at line 35 with the exact values from the coverage report:

- one row per key in `source.patterns` (`phrases` and `shots`), in the same pattern order as the existing table;
- the `Total` row uses `source.phrases` (237) and `source.projectiles`;
- line 35 becomes: `Additional source geometry comprises 36 fixed cubes and 67 laser formations. Fixed-cube orientation is seeded in the test only; the live encounter retains its configured random X/+ choice. The undefined fixed_2 slot remains empty.`

Then add the tracking rule after line 35:

```markdown
Laser formations fire beat-clustered volleys: source lines whose damage times fall within half a beat (`0.5 * 60 / 203` s) fire together, and each volley re-centers once on the player's arena center at the start of its own warning. A warning already visible when the hazard is created never moves, and cubes never track.
```

Replace the milestone sentence at line 40 with the report's actual totals: the phrase count from `source.phrases`, the distinct action count from `source.actions`, the requested/successful projectile count from `source.projectiles`, the fixed count from `source.fixed`, and the formation count from `source.formations`, plus the report's `hazard_geometry_counts` X/plus split, its per-pattern counts from `pattern_counts`, peak live objects from `peak_live_projectiles` and `peak_live_hazards`, and its budget/cancellation figures from `actual` and `safety_cancellations`. Keep the final 147.783ms-warning sentence unchanged.

- [ ] **Step 8: Commit the clean coverage and doc files**

```bash
git add tests/full_song_coverage_test.gd docs/full-song-runtime.md
git commit -m "Gate reference-chart laser volleys in full-song coverage"
```

`combat/boss.gd` and `tools/verify_main.ps1` remain uncommitted because they carry unrelated work.

---

### Task 5: Capture the volley and re-aim as validation evidence

**Files:**
- Create: `tools/capture_laser_volley.gd`

**Interfaces:**
- Consumes: `BossHazard` from Task 3, `Planner` from Task 2, and the same synthetic fixture style as `tests/laser_tracking_test.gd`.
- Produces: `artifacts/laser-volley/volley-warning.png`, `volley-fire.png`, `volley-reaim.png` (ignored evidence, never committed).

- [ ] **Step 1: Write the static capture tool**

Create `tools/capture_laser_volley.gd`:

```gdscript
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
    return {"index": 0, "occurrence": 0, "pattern": "diamond", "lasers": lasers}

func capture(frame_name: String) -> void:
    var directory: String = ProjectSettings.globalize_path(OUTPUT_DIR)
    DirAccess.make_dir_recursive_absolute(directory)
    await RenderingServer.frame_post_draw
    var image: Image = root.get_texture().get_image()
    image.save_png(directory + "/" + frame_name + ".png")
    print("CAPTURE ", frame_name, " -> ", OUTPUT_DIR, "/", frame_name, ".png")

func run() -> void:
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
```

If `DirectoryAccess.create_directory_recursive` is unavailable in this Godot build, use `DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))` instead; the rest is unchanged.

- [ ] **Step 2: Run the capture tool with a real rendering driver**

```bash
"D:\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe" --path . --script res://tools/capture_laser_volley.gd
```

Expected: three `CAPTURE ...` lines and a zero exit code. The tool needs a windowed/rendering run because `get_texture().get_image()` is empty in `--headless`.

- [ ] **Step 3: Inspect the three images**

Read `artifacts/laser-volley/volley-warning.png`, `volley-fire.png`, and `volley-reaim.png`. Confirm:

- warning frame shows four diamond lanes around the player position with the coral warning rails;
- fire frame shows four simultaneous fired beams;
- re-aim frame shows the second volley crossing at the moved player position (x ≈ 500) while the first volley's lanes stay at the old position.

If a frame is blank, fix the capture setup (size/visual layer) instead of treating it as evidence.

- [ ] **Step 4: Commit the tool**

```bash
git add tools/capture_laser_volley.gd
git commit -m "Add a static laser volley capture tool"
```

---

### Task 6: Full verification and report

- [ ] **Step 1: Run the focused contract set**

```bash
powershell.exe -NoProfile -Command "& ./tools/verify_main.ps1 -Only @('source-chart','full_song_transport_test','full_song_offset_test','full_song_boss_test','full_song_coverage_test','main_full_song_test','heavy_judge_test','laser_tracking_test')"
```

Expected: every check prints `0 failed`; no `SCRIPT ERROR`, `ERROR`, `FAIL `, leaked, or timeout.

- [ ] **Step 2: Run the real-OGG subset**

```bash
powershell.exe -NoProfile -Command "& ./tools/verify_main.ps1 -LocalScore -Only @('full_song_transport_test','full_song_boss_test','full_song_coverage_test','full_song_offset_test','main_full_song_test','audio_calibration_test','boss_room_test','laser_tracking_test','source-chart')"
```

Expected: every check prints `0 failed`.

- [ ] **Step 3: Run the full suite**

```bash
powershell.exe -NoProfile -Command "& ./tools/verify_main.ps1"
```

Expected: every check prints `0 failed`; no `SCRIPT ERROR`, `ERROR`, `FAIL `, leaked nodes, or timeout.

- [ ] **Step 4: Confirm the Boss-room presentation still renders**

```bash
"D:\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe" --path . --script res://tools/capture_boss_redhair.gd --idle-only
```

Expected: the capture completes with no error and the ignored Boss idle image still shows the red-haired katana Boss. Inspect the image.

- [ ] **Step 5: Report**

Report:

- the committed files and the uncommitted feature-owned edits (`main.gd` untouched; `combat/boss.gd`, `combat/boss_hazard.gd`, `tools/verify_main.ps1` carry this feature plus unrelated in-progress work and remain in the working tree);
- coverage evidence: 67 formation hazards, zero missing, zero budget rejections, zero stale laser-line skips, peak live hazards, wall time;
- the three capture images and their paths;
- explicitly untested paths: interactive keyboard/gamepad dodging, subjective beat feel, long play sessions, and real-device calibration.

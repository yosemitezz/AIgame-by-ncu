# Boss Room Migration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Mount the ported infinite Boss room, five-tap audio calibration, and pre-score offset application on the current branch without changing the Boss's existing skill set.

**Architecture:** A new `levels/boss_room.gd` owns the camera-following room, its five one-way platform layers, the heavy-group cursor, and the calibration lifecycle. `combat/audio_calibration.gd` and `ui/calibration_overlay.gd` are ported as isolated modules. `main.gd` swaps `BossChamber` for `BossRoom`, owns the calibration gate, and applies the measured offset through new `FullTransport.set_offset_ms` / `MusicDirector.replace_offset_ms` APIs before the score starts.

**Tech Stack:** Godot 4.7 GDScript, `SceneTree` headless fixtures, PowerShell runner (`tools/verify_main.ps1`), OGG source chart (`res://data/full_song_timeline.json`).

**Spec:** `docs/superpowers/specs/2026-10-25-boss-room-and-skill-update-design.md` (sections 7, 8, 10, 11, 12, 13; this plan deliberately excludes sections 5–6 heavy clash/parry/fade and section 9 sustain; they are a later slice).

## Global Constraints

- Run every command from `D:\code\aigame-ncu-integrate`; never `cd` to the original repository root.
- `main.gd`, `tests/room_transition_test.gd`, `tests/main_scene_migration_test.gd`, `tools/capture_*.gd`, and `tools/verify_main.ps1` already contain unrelated uncommitted changes. Edit them in place, but **do not `git add` or commit them**; only new files and the two audio files in Task 1 may be committed.
- Keep `levels/boss_chamber.gd` untouched; it is no longer mounted but its tests (`boss_navigation_test`, `room_geometry_test`) must keep passing.
- Full-song time authority stays `MusicDirector`; no room or UI owns a gameplay clock.
- Calibration must complete (or auto-skip) synchronously before `music.start_score()`; `replace_offset_ms` must run before the score starts.
- Calibration auto-skips synchronously for non-full-song, fewer than five regular heavy groups, headless display, and Dummy audio (`music._dummy`).
- Chinese UI strings are rendered with `presentation/pixel_font.gd`; every glyph must exist (verified: all strings below pass).
- Every test must print `N passed, 0 failed`; `verify_main.ps1` fails on `SCRIPT ERROR:`, `ERROR:`, `FAIL `, or leaked nodes.
- Do not add the private recording, rendered assets, credentials, or personal paths.

---

### Task 1: Full-song offset application

**Files:**
- Modify: `audio/full_song_transport.gd`
- Modify: `audio/music_director.gd:120-180` (`_configure_full_song`, `get_full_song_status` neighbours)
- Test: `tests/full_song_offset_test.gd` (create)

**Interfaces:**
- Consumes: `FullTransport.configure(config, duration)`, `SourceParser.parse_file(path, bpm, offset_ms, gap_beats)`, `MusicDirector.timeline`, `MusicDirector._full_chart`, `MusicDirector._transport`, `MusicDirector._audio`.
- Produces: `FullTransport.set_offset_ms(value_ms: float) -> bool`; `MusicDirector.replace_offset_ms(value_ms: float) -> bool`.

- [ ] **Step 1: Write the failing test**

Create `tests/full_song_offset_test.gd`:

```gdscript
extends SceneTree
const Transport = preload("res://audio/full_song_transport.gd")
const Music = preload("res://audio/music_director.gd")

class TestGame extends Node2D:
    var story_safe: bool = false
    func set_story_safe(value: bool) -> void: story_safe = value
    func announce(_message: String, _seconds: float = 3.0) -> void: pass
    func on_boss_defeated() -> void: pass

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

func load_config() -> Dictionary:
    var file: FileAccess = FileAccess.open("res://data/full_song_timeline.json", FileAccess.READ)
    return JSON.parse_string(file.get_as_text())

func run() -> void:
    var config: Dictionary = load_config()
    var duration: float = 418.51573696145124
    var transport: RefCounted = Transport.new()
    check(transport.configure(config, duration), "transport accepts the shipping boundaries")
    var old_fixed: float = transport.fixed_end
    var old_rest: float = transport.rest_end
    check(transport.set_offset_ms(345.0), "offset applies while stopped")
    check(is_equal_approx(transport.offset_ms, 345.0) and is_equal_approx(transport.offset_seconds, 0.345), "offset is stored in both units")
    check(is_equal_approx(transport.fixed_end, old_fixed + 0.1) and is_equal_approx(transport.rest_end, old_rest + 0.1), "all four boundaries shift by the exact delta")
    check(is_equal_approx(transport.beat_time(200.0), old_fixed + 0.1), "beat mapping uses the new offset")
    transport.start()
    check(not transport.set_offset_ms(245.0) and is_equal_approx(transport.offset_ms, 345.0), "running transport rejects offset edits")
    transport.stop()
    var short: RefCounted = Transport.new()
    check(short.configure(config, 88.0), "short-but-valid song configures")
    check(not short.set_offset_ms(1000.0) and is_equal_approx(short.offset_ms, 245.0), "offset that pushes rest past the audio is rejected atomically")

    var game := TestGame.new()
    root.add_child(game)
    var music: Node = Music.new()
    game.add_child(music)
    music.configure(game, "res://data/full_song_timeline.json")
    music.set_process(false)
    music._dummy = true
    check(music.is_full_song(), "director loads the shipping full song")
    var before: Array[Dictionary] = music.get_heavy_groups()
    var chart_before: RefCounted = music._full_chart
    check(before.size() == 107, "fixture exposes all 107 heavy groups")
    check(music.replace_offset_ms(345.0), "director applies a stopped-session offset")
    check(is_equal_approx(float(music.get_full_song_status()["offset_ms"]), 345.0), "status reports the new offset")
    check(is_equal_approx(float(music.timeline["offset_ms"]), 345.0), "timeline commits the new offset")
    var after: Array[Dictionary] = music.get_heavy_groups()
    check(after.size() == 107 and music._full_chart != chart_before, "chart is re-parsed instead of mutated")
    check(is_equal_approx(float(after[0]["time"]) - float(before[0]["time"]), 0.1), "every heavy group shifts by exactly 100 ms")
    check(music._full_chart.timed_note_count == 1171 and music._full_chart.action_phrases.size() == 228, "chart counts and phrases are unchanged")
    var committed_chart: RefCounted = music._full_chart
    check(music.replace_offset_ms(345.0), "equal offset is an idempotent success")
    check(music._full_chart == committed_chart, "equal offset does not re-parse")
    check(music.replace_offset_ms(-10.0), "negative offset clamps to zero")
    check(is_equal_approx(float(music.timeline["offset_ms"]), 0.0), "clamped offset is committed")
    check(is_equal_approx(float(music.get_heavy_groups()[0]["time"]), 73.0 * 60.0 / 203.0), "clamped chart starts at the raw source beat")
    music.start_score()
    var running_chart: RefCounted = music._full_chart
    check(not music.replace_offset_ms(300.0) and music._full_chart == running_chart, "running score rejects and preserves the chart")
    music.stop_score()
    music._full_chart_path = "res://data/missing_offset_chart.json"
    var missing_chart: RefCounted = music._full_chart
    check(not music.replace_offset_ms(300.0), "unparseable replacement is rejected")
    check(music._full_chart == missing_chart and is_equal_approx(float(music.timeline["offset_ms"]), 0.0), "failed replacement leaves chart, timeline and offset untouched")

    var original_game := TestGame.new()
    root.add_child(original_game)
    var original: Node = Music.new()
    original_game.add_child(original)
    original.configure(original_game, "res://data/music_timeline.json")
    original.set_process(false)
    check(not original.is_full_song() and not original.replace_offset_ms(300.0), "original-score mode rejects calibration offsets")

    game.queue_free()
    original_game.queue_free()
    await process_frame
    print("Full song offset: %d passed, %d failed" % [passed, failed])
    quit(1 if failed else 0)
```

- [ ] **Step 2: Run the test and confirm it fails**

Run: `powershell -ExecutionPolicy Bypass -File tools/verify_main.ps1 -Only full_song_offset_test`

Expected: FAIL — `full_song_offset_test` is not yet registered, or once registered the calls `set_offset_ms` / `replace_offset_ms` do not exist. Register the name in Task 4; until then run directly:

```bash
"D:/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe" --headless --audio-driver Dummy --path "D:/code/aigame-ncu-integrate" --script res://tests/full_song_offset_test.gd
```

Expected: FAIL with `Invalid call. Nonexistent function 'set_offset_ms'`.

- [ ] **Step 3: Implement `FullTransport.set_offset_ms`**

In `audio/full_song_transport.gd`, add the field next to `offset_seconds`:

```gdscript
var offset_ms: float = 245.0
var _config: Dictionary = {}
```

At the start of `configure`, cache the dictionary and keep both offset units in sync:

```gdscript
func configure(config: Dictionary, song_duration: float) -> bool:
    _config = config.duplicate(true)
    bpm = float(config.get("bpm", 203.0))
    offset_ms = float(config.get("offset_ms", 245.0))
    offset_seconds = offset_ms / 1000.0
    duration = song_duration
    error = ""
    if not is_finite(bpm) or bpm <= 0.0 or not is_finite(duration):
        error = "Invalid tempo or duration"
        return false
    fixed_end = beat_time(float(config.get("fixed_end_beat", 200.0)))
    random_start = beat_time(float(config.get("random_start_beat", 200.0)))
    random_end = beat_time(float(config.get("random_end_beat", 264.0)))
    rest_end = beat_time(float(config.get("rest_end_beat", 296.0)))
    if not (fixed_end > 0.0 and is_equal_approx(fixed_end, random_start) and random_end > random_start and rest_end > random_end and duration > rest_end):
        error = "Invalid full-song gameplay boundaries"
        return false
    return true
```

Add after `beat_time`:

```gdscript
func set_offset_ms(value_ms: float) -> bool:
    if running or not is_finite(value_ms):
        return false
    var next_offset: float = value_ms / 1000.0
    var seconds_per_beat: float = 60.0 / bpm
    var next_fixed: float = float(_config.get("fixed_end_beat", 200.0)) * seconds_per_beat + next_offset
    var next_random_start: float = float(_config.get("random_start_beat", 200.0)) * seconds_per_beat + next_offset
    var next_random_end: float = float(_config.get("random_end_beat", 264.0)) * seconds_per_beat + next_offset
    var next_rest_end: float = float(_config.get("rest_end_beat", 296.0)) * seconds_per_beat + next_offset
    if not (next_fixed > 0.0 and is_equal_approx(next_fixed, next_random_start) and next_random_end > next_random_start and next_rest_end > next_random_end and duration > next_rest_end):
        return false
    offset_ms = value_ms
    offset_seconds = next_offset
    fixed_end = next_fixed
    random_start = next_random_start
    random_end = next_random_end
    rest_end = next_rest_end
    return true
```

- [ ] **Step 4: Implement `MusicDirector.replace_offset_ms`**

Add directly after `get_heavy_groups()` in `audio/music_director.gd`:

```gdscript
func replace_offset_ms(value_ms: float) -> bool:
    if not _full or _full_chart_path.is_empty() or running or not is_finite(value_ms):
        return false
    var clamped: float = clampf(value_ms, 0.0, 1000.0)
    var current: float = float(timeline.get("offset_ms", 245.0))
    if is_equal_approx(clamped, current):
        return true
    var chart: RefCounted = SourceParser.new()
    chart.fast_interval_threshold_beats = float(timeline.get("fast_interval_threshold_beats", 1.1))
    if not chart.parse_file(_full_chart_path, bpm, clamped, 4.0):
        return false
    if _audio == null or _audio.stream == null or _audio.stream.get_length() + 0.000001 < float(chart.chart_end_time):
        return false
    if not _transport.set_offset_ms(clamped):
        return false
    timeline["offset_ms"] = clamped
    _full_chart = chart
    return true
```

- [ ] **Step 5: Run the test and confirm it passes**

Run the direct Godot command from Step 2.

Expected: `Full song offset: <n> passed, 0 failed`.

- [ ] **Step 6: Commit the two audio files only**

```bash
git add -- audio/full_song_transport.gd audio/music_director.gd tests/full_song_offset_test.gd
git commit -m "Allow calibration to shift full-song chart offset before start"
```

---

### Task 2: Calibration math module

**Files:**
- Create: `combat/audio_calibration.gd`
- Test: `tests/audio_calibration_test.gd` (create)

**Interfaces:**
- Consumes: nothing from earlier tasks.
- Produces: `Calibration.SAMPLE_COUNT`, `SEARCH_AFTER_SECONDS`, `PREVIEW_LEAD_SECONDS`, `MAX_TAP_DISTANCE_SECONDS`; `configure(heavy_groups: Array[Dictionary], current_offset_ms: float) -> bool`; `preview_start_seconds() -> float`; `register_tap(audio_position: float) -> bool`; `is_complete() -> bool`; `adjusted_offset_ms() -> float`; fields `base_offset_ms`, `sample_times`, `tap_positions`, `last_error_seconds`.

- [ ] **Step 1: Write the failing test**

Create `tests/audio_calibration_test.gd`:

```gdscript
extends SceneTree
const Calibration = preload("res://combat/audio_calibration.gd")

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

func groups(times: Array[float]) -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    for at: float in times:
        result.append({"time": at})
    return result

func run() -> void:
    var calibration: RefCounted = Calibration.new()
    check(Calibration.SAMPLE_COUNT == 5 and is_equal_approx(Calibration.SEARCH_AFTER_SECONDS, 35.0), "module constants match the spec")
    var fixture: Array[Dictionary] = groups([10.0, 34.9, 40.74, 41.18, 41.62, 42.06, 42.50, 50.0])
    check(calibration.configure(fixture, 245.0), "first regular five-group run after 35 s is selected")
    check(calibration.sample_times == [40.74, 41.18, 41.62, 42.06, 42.50], "selected cluster is the actual chart run")
    check(is_equal_approx(calibration.preview_start_seconds(), 38.74), "preview starts two seconds before the first sample")
    check(is_equal_approx(calibration.base_offset_ms, 245.0), "base offset is retained")
    check(not calibration.is_complete() and is_equal_approx(calibration.adjusted_offset_ms(), 245.0), "incomplete calibration reports the base offset")

    var irregular: RefCounted = Calibration.new()
    check(not irregular.configure(groups([36.0, 36.1, 36.5, 37.0, 38.2]), 245.0), "irregular five-group runs are rejected")
    var short_fixture: RefCounted = Calibration.new()
    check(not short_fixture.configure(groups([40.0, 41.0, 42.0, 43.0]), 245.0), "fewer than five groups is rejected")

    check(calibration.register_tap(40.80), "tap inside 350 ms is accepted")
    check(not calibration.register_tap(41.60), "tap farther than 350 ms from the next sample is rejected")
    check(calibration.tap_positions == [40.80], "rejected tap does not advance progress")
    check(calibration.register_tap(41.27) and calibration.register_tap(41.71) and calibration.register_tap(42.15) and calibration.register_tap(42.59), "remaining four taps are accepted")
    check(calibration.is_complete(), "five accepted taps complete the sample")
    check(is_equal_approx(calibration.adjusted_offset_ms(), 335.0), "mean 90 ms lateness is added to the base offset")
    check(is_equal_approx(calibration.last_error_seconds, 0.09), "mean error is reported in seconds")
    check(not calibration.register_tap(43.0), "a sixth tap is rejected")

    print("Audio calibration: %d passed, %d failed" % [passed, failed])
    quit(1 if failed else 0)
```

- [ ] **Step 2: Run the test and confirm it fails**

```bash
"D:/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe" --headless --audio-driver Dummy --path "D:/code/aigame-ncu-integrate" --script res://tests/audio_calibration_test.gd
```

Expected: FAIL — `res://combat/audio_calibration.gd` does not exist.

- [ ] **Step 3: Create the module**

Create `combat/audio_calibration.gd`:

```gdscript
extends RefCounted
## Measures the residual gap between chart beats and the sound the player hears.
## The selected run is the first five regular heavy groups after 35 seconds,
## which is the 40.74-42.51 second cluster in the source chart.

const SAMPLE_COUNT: int = 5
const SEARCH_AFTER_SECONDS: float = 35.0
const PREVIEW_LEAD_SECONDS: float = 2.0
const MAX_TAP_DISTANCE_SECONDS: float = 0.35

var base_offset_ms: float = 245.0
var sample_times: Array[float] = []
var tap_positions: Array[float] = []
var last_error_seconds: float = 0.0

func configure(heavy_groups: Array[Dictionary], current_offset_ms: float) -> bool:
    base_offset_ms = current_offset_ms
    sample_times.clear()
    tap_positions.clear()
    last_error_seconds = 0.0
    var candidates: Array[float] = []
    for group: Dictionary in heavy_groups:
        if not group.has("time"):
            continue
        var at: float = float(group["time"])
        if is_finite(at) and at >= SEARCH_AFTER_SECONDS:
            candidates.append(at)
    candidates.sort()
    if candidates.size() < SAMPLE_COUNT:
        return false
    for start: int in range(0, candidates.size() - SAMPLE_COUNT + 1):
        var run: Array[float] = candidates.slice(start, start + SAMPLE_COUNT)
        var interval: float = run[1] - run[0]
        var regular: bool = interval > 0.0
        for index: int in range(1, run.size()):
            regular = regular and absf((run[index] - run[index - 1]) - interval) <= 0.025
        if regular:
            sample_times = run
            tap_positions.clear()
            return true
    return false

func preview_start_seconds() -> float:
    return maxf(0.0, sample_times[0] - PREVIEW_LEAD_SECONDS) if not sample_times.is_empty() else 0.0

func register_tap(audio_position: float) -> bool:
    if tap_positions.size() >= SAMPLE_COUNT or not is_finite(audio_position):
        return false
    var expected: float = sample_times[tap_positions.size()]
    if absf(audio_position - expected) > MAX_TAP_DISTANCE_SECONDS:
        return false
    tap_positions.append(audio_position)
    last_error_seconds = 0.0
    for index: int in tap_positions.size():
        last_error_seconds += tap_positions[index] - sample_times[index]
    last_error_seconds /= float(tap_positions.size())
    return true

func is_complete() -> bool:
    return tap_positions.size() == SAMPLE_COUNT

func adjusted_offset_ms() -> float:
    if not is_complete():
        return base_offset_ms
    var total_error: float = 0.0
    for index: int in SAMPLE_COUNT:
        total_error += tap_positions[index] - sample_times[index]
    last_error_seconds = total_error / float(SAMPLE_COUNT)
    return base_offset_ms + last_error_seconds * 1000.0
```

- [ ] **Step 4: Run the test and confirm it passes**

Expected: `Audio calibration: <n> passed, 0 failed`.

- [ ] **Step 5: Commit the module and its test**

```bash
git add -- combat/audio_calibration.gd tests/audio_calibration_test.gd
git commit -m "Port the five-tap boss-room audio calibration math"
```

---

### Task 3: Infinite Boss room, overlay, and room tests

**Files:**
- Create: `ui/calibration_overlay.gd`
- Create: `levels/boss_room.gd`
- Test: `tests/boss_room_test.gd` (create)

**Interfaces:**
- Consumes: `combat/audio_calibration.gd` (Task 2), `presentation/pixel_font.gd`, `AudioServer`, `InputMap.climb_down`.
- Produces: `BossRoom` signals `calibration_complete(offset_ms: float)`, `heavy_clash_requested(event_time: float)`, `heavy_history_cleared`; methods `setup(game)`, `start_room_entry()`, `begin_battle(boss)`, `get_room_spec()`, `get_map_bounds(center) -> Rect2`, `room_at(feet)`, `platform_layer_y(layer) -> float`; constant `PLATFORM_LAYER_COUNT`.

- [ ] **Step 1: Write the failing test**

Create `tests/boss_room_test.gd`:

```gdscript
extends SceneTree
const Room = preload("res://levels/boss_room.gd")
const Overlay = preload("res://ui/calibration_overlay.gd")

class MusicProbe extends Node:
    var running: bool = false
    var full: bool = true
    var now: float = 0.0
    var generation: int = 1
    var groups: Array[Dictionary] = []
    var timeline: Dictionary = {"offset_ms": 245.0, "music_volume_db": -8.0}
    var _dummy: bool = true
    var _audio: AudioStreamPlayer
    func is_full_song() -> bool: return full
    func get_chart_time() -> float: return now
    func get_transport_generation() -> int: return generation
    func get_heavy_groups() -> Array[Dictionary]: return groups.duplicate(true)

class GameProbe extends Node:
    var player: Node2D
    var music: Node
    var story_safe: bool = false

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

func make_room() -> Dictionary:
    var game := GameProbe.new()
    game.player = Node2D.new()
    game.add_child(game.player)
    game.music = MusicProbe.new()
    game.add_child(game.music)
    root.add_child(game)
    var room := Room.new()
    root.add_child(room)
    room.setup(game)
    return {"game": game, "music": game.music, "room": room}

func run() -> void:
    var fixture: Dictionary = make_room()
    var game: GameProbe = fixture["game"]
    var music: MusicProbe = fixture["music"]
    var room: Node2D = fixture["room"]
    check(room.active, "setup activates the room without starting calibration")
    check(not room.calibrating and not room.battle_running, "setup never starts a calibration or battle")
    check(Room.SPAWN == Vector2(2706, 300) and Room.BOSS_POSITION == Vector2(2990, 300), "spawn and boss anchors use the chamber baseline")
    check(Room.platform_layer_y(0) == 0.0 and Room.platform_layer_y(1) == 150.0 and Room.platform_layer_y(2) == 300.0 and Room.platform_layer_y(3) == 450.0 and Room.platform_layer_y(4) == 600.0, "five layer centres are 0/150/300/450/600")
    var spec: Dictionary = room.get_room_spec()
    check(spec["id"] == "boss" and spec["title"] == "THE HOLLOW BELFRY", "room spec keeps the Boss identity")
    check(spec["spawn"] == Room.SPAWN and spec["checkpoint"] == Room.SPAWN and spec["portal_at"] == Room.SPAWN, "spawn, checkpoint and portal share the entry anchor")
    check(spec["boss_spawn"] == Room.BOSS_POSITION and spec["fall_limit"] == 720.0, "boss anchor and fall limit are room-specific")
    check(spec["bounds"] == Room.WORLD_BOUNDS and spec["platforms"].is_empty(), "legacy solid platforms are gone from the spec")
    check(spec["shard_indices"] == [11], "the old chamber shard stays collectable")
    check(room.get_map_bounds(Vector2(3000, 200)) == Rect2(2580, -120, 840, 640), "map window follows the player")
    check(room.room_at(Vector2(-9999, -9999))["title"] == "THE HOLLOW BELFRY", "room record is unconditional in the infinite room")
    check(room.climb_at(Vector2.ZERO).is_empty() and not room.water_at(Vector2.ZERO) and room.portal_at(Vector2.ZERO).is_empty(), "traversal queries stay inert")
    check(room.interaction_hint(Vector2.ZERO) == "" and not room.try_interact(Vector2.ZERO) and room.get_opened_ids().is_empty(), "interaction queries stay inert")
    check(not room.has_method("get_attack_bounds"), "Boss attack arena is not overridden by the room")

    game.player.position = Vector2(0, 300)
    room._update_platforms()
    check(room._platforms.size() == 45, "nine cells per layer surround the player")
    var platforms_ok: bool = true
    var y_values: Dictionary = {}
    for body: StaticBody2D in room._platforms.values():
        platforms_ok = platforms_ok and body.collision_layer == 1 and body.collision_mask == 0
        y_values[body.position.y] = true
        var shape_node: CollisionShape2D = body.get_child(0) as CollisionShape2D
        platforms_ok = platforms_ok and shape_node != null and shape_node.one_way_collision
        platforms_ok = platforms_ok and is_equal_approx(shape_node.one_way_collision_margin, 4.0)
    check(platforms_ok, "every cell is a layer-1 mask-0 one-way body")
    check(y_values.keys().size() == 5, "bodies exist on exactly five layers")
    check(room._platforms["2:0"].position.x == 100.0, "cell x is index times spacing plus half width")

    game.player.position = Vector2(2000, 300)
    room._update_platforms()
    check(room._platforms.size() == 45 and not room._platforms.has("0:-4") and room._platforms.has("0:6"), "cells outside the surround are removed")
    check(room._platforms["2:6"].position.x == 1300.0, "window re-centres on the new player x")

    if not InputMap.has_action("climb_down"):
        InputMap.add_action("climb_down")
    Input.action_press("climb_down")
    room._update_platforms()
    var all_disabled: bool = true
    for body: StaticBody2D in room._platforms.values():
        all_disabled = all_disabled and (body.get_child(0) as CollisionShape2D).disabled
    Input.action_release("climb_down")
    check(all_disabled, "drop-through disables every platform shape")
    room._update_platforms()
    var all_enabled: bool = true
    for body: StaticBody2D in room._platforms.values():
        all_enabled = all_enabled and not (body.get_child(0) as CollisionShape2D).disabled
    check(all_enabled, "releasing drop-through restores every platform shape")

    music.running = true
    music.now = 0.0
    music.generation = 1
    music.groups = [{"time": 1.0}, {"time": 2.0}, {"time": 3.0}]
    var requests: Array[float] = []
    var clears: Array[int] = [0]
    room.heavy_clash_requested.connect(func(at: float) -> void: requests.append(at))
    room.heavy_history_cleared.connect(func() -> void: clears[0] += 1)
    room.begin_battle(null)
    room._process_heavy_groups()
    check(requests.is_empty(), "future groups do not fire early")
    music.now = 1.0
    room._process_heavy_groups()
    room._process_heavy_groups()
    check(requests == [1.0], "each group is emitted once")
    music.generation = 2
    music.now = 1.5
    room._process_heavy_groups()
    check(clears[0] == 1, "generation change clears history")
    check(requests == [1.0], "historical group from the previous epoch is skipped")
    music.now = 2.0
    room._process_heavy_groups()
    check(requests == [1.0, 2.0], "new epoch emits its first due group")
    game.story_safe = true
    music.now = 3.0
    room._process_heavy_groups()
    check(requests == [1.0, 2.0], "rest advances the cursor without emitting")
    game.story_safe = false
    room._process_heavy_groups()
    check(requests == [1.0, 2.0], "leaving rest does not replay a backlog")
    music.now = 0.5
    room._process_heavy_groups()
    check(clears[0] == 2, "backward jump also clears history")

    music.full = false
    var emitted: Array[float] = []
    room.calibration_complete.connect(func(value: float) -> void: emitted.append(value))
    room.start_room_entry()
    check(emitted.size() == 1 and not room.calibrating, "non-full-song skips calibration synchronously")
    music.full = true
    music.groups = [{"time": 40.74}, {"time": 41.18}, {"time": 41.62}, {"time": 42.06}, {"time": 42.50}]
    room.start_room_entry()
    check(emitted.size() == 2 and not room.calibrating, "Dummy audio skips calibration synchronously")

    var overlay: Control = Overlay.new()
    root.add_child(overlay)
    await process_frame
    var strings: Array[String] = ["节拍校准", "听到重鼓时按任意键；每轮重新校准。", "重鼓  %d / %d", "校准完成：%.0f ms", "没有采足 5 下，马上重新播放。", "已跳过校准。"]
    var glyphs_ok: bool = true
    for text: String in strings:
        for index: int in text.length():
            var codepoint: int = text.unicode_at(index)
            if codepoint == 32:
                continue
            glyphs_ok = glyphs_ok and overlay._font.has_char(codepoint)
    check(glyphs_ok, "overlay text is fully covered by the pixel font")

    game.queue_free()
    room.queue_free()
    overlay.queue_free()
    await process_frame
    print("Boss room: %d passed, %d failed" % [passed, failed])
    quit(1 if failed else 0)
```

- [ ] **Step 2: Run the test and confirm it fails**

```bash
"D:/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe" --headless --audio-driver Dummy --path "D:/code/aigame-ncu-integrate" --script res://tests/boss_room_test.gd
```

Expected: FAIL — `res://levels/boss_room.gd` and `res://ui/calibration_overlay.gd` do not exist.

- [ ] **Step 3: Create the calibration overlay**

Create `ui/calibration_overlay.gd`:

```gdscript
extends Control
## Full-screen calibration panel. It never reads input; the room owns taps and skip.

const PixelFont = preload("res://presentation/pixel_font.gd")

var _font: Font
var _tap_count: int = 0
var _target_count: int = 5
var _message: String = ""
var _result: String = ""

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _font = PixelFont.create()
    visible = false

func present(prompt: String = "") -> void:
    visible = true
    _tap_count = 0
    _result = ""
    _message = prompt
    queue_redraw()

func dismiss() -> void:
    visible = false
    _message = ""
    _result = ""
    queue_redraw()

func set_progress(count: int, total: int = 5) -> void:
    _tap_count = clampi(count, 0, total)
    _target_count = maxi(1, total)
    queue_redraw()

func set_retry(message: String) -> void:
    _message = message
    _result = ""
    queue_redraw()

func show_result(message: String) -> void:
    _result = message
    queue_redraw()

func _draw() -> void:
    if not visible or _font == null:
        return
    var viewport: Vector2 = size if size.x > 0.0 else get_viewport_rect().size
    var panel := Rect2(Vector2(82, 74), Vector2(maxf(320.0, viewport.x - 164.0), 188))
    draw_rect(Rect2(Vector2.ZERO, viewport), Color(0.01, 0.015, 0.03, 0.44))
    draw_rect(panel, Color(0.025, 0.035, 0.06, 0.96))
    draw_rect(panel, Color("6fe8d8"), false, 1.0)
    _text(Vector2(panel.position.x + 18, panel.position.y + 25), "节拍校准", 16, Color("f4f1dd"))
    _text(Vector2(panel.position.x + 18, panel.position.y + 49), "听到重鼓时按任意键；每轮重新校准。", 11, Color("b8c2ca"))
    if not _message.is_empty():
        _text(Vector2(panel.position.x + 18, panel.position.y + 73), _message, 10, Color("f0b45f"))
    var spacing: float = 38.0
    var start_x: float = panel.position.x + (panel.size.x - spacing * (float(_target_count) - 1.0)) * 0.5
    for index: int in _target_count:
        var center := Vector2(start_x + spacing * float(index), panel.position.y + 112)
        var filled: bool = index < _tap_count
        var ink: Color = Color("73f6df") if filled else Color("465263")
        draw_colored_polygon(PackedVector2Array([center + Vector2(0, -7), center + Vector2(7, 0), center + Vector2(0, 7), center + Vector2(-7, 0)]), ink)
    _text(Vector2(panel.position.x + 18, panel.position.y + 142), "重鼓  %d / %d" % [_tap_count, _target_count], 11, Color("f4f1dd"))
    if not _result.is_empty():
        draw_rect(Rect2(panel.position.x + 14, panel.position.y + 150, panel.size.x - 28, 1), Color("2f5a5a"))
        _text(Vector2(panel.position.x + 18, panel.position.y + 170), _result, 12, Color("73f6df"))

func _text(at: Vector2, value: String, font_size: int, ink: Color) -> void:
    draw_string(_font, at.round(), value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, ink)
```

- [ ] **Step 4: Create the infinite room**

Create `levels/boss_room.gd`:

```gdscript
extends Node2D
## Infinite camera-following Boss room. It never mounts the dungeon or owns a gameplay clock.

signal calibration_complete(offset_ms: float)
signal heavy_clash_requested(event_time: float)
signal heavy_history_cleared

const Calibration = preload("res://combat/audio_calibration.gd")
const CalibrationOverlay = preload("res://ui/calibration_overlay.gd")

const ROOM_ID: String = "boss"
const SPAWN: Vector2 = Vector2(2706, 300)
const BOSS_POSITION: Vector2 = Vector2(2990, 300)
const WORLD_BOUNDS: Rect2 = Rect2(2580, -160, 840, 720)
const FALL_LIMIT: float = 720.0
const PLATFORM_SPACING: float = 200.0
const PLATFORM_WIDTH: float = 200.0
const PLATFORM_HEIGHT: float = 12.0
const PLATFORM_BASE_Y: float = 300.0
const PLATFORM_LAYER_COUNT: int = 5
const PLATFORM_LAYER_SPACING: float = 150.0
const PLATFORM_SURROUND: float = 700.0
const DRAW_INTERVAL: float = 0.1
const DRAW_MOVE: float = 8.0

const DARK: Color = Color("0f0b16")
const FAR: Color = Color("1a1524")
const MID: Color = Color("241d30")
const MASON: Color = Color("322b3c")
const STONE: Color = Color("41394b")
const LIP: Color = Color("786b7e")
const GOLD: Color = Color("c08a4a")
const GOLD_LOW: Color = Color("7d5a3c")

const ROOMS: Array[Dictionary] = [{
    "id": ROOM_ID,
    "title": "THE HOLLOW BELFRY",
    "hint": "Close the distance / Parry the golden rain",
}]

var game: Node
var music: Node
var boss: Node2D
var active: bool = false
var calibrating: bool = false
var battle_running: bool = false
var _calibration: RefCounted
var _preview: AudioStreamPlayer
var _overlay: Control
var _overlay_generation: int = 0
var _preview_started_frame: int = -1
var _heavy_groups: Array[Dictionary] = []
var _heavy_cursor: int = 0
var _transport_generation: int = -1
var _last_chart_time: float = -1.0
var _platforms: Dictionary = {}
var _clock: float = 0.0
var _draw_clock: float = 0.0
var _last_draw_at: Vector2 = Vector2(INF, INF)

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_PAUSABLE
    z_index = -20
    texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    var canvas := CanvasLayer.new()
    canvas.layer = 40
    add_child(canvas)
    _overlay = CalibrationOverlay.new()
    canvas.add_child(_overlay)

func setup(owner_game: Node) -> void:
    game = owner_game
    music = owner_game.get("music")
    active = true

func get_room_spec() -> Dictionary:
    return {
        "id": ROOM_ID,
        "title": "THE HOLLOW BELFRY",
        "bounds": WORLD_BOUNDS,
        "spawn": SPAWN,
        "checkpoint": SPAWN,
        "boss_spawn": BOSS_POSITION,
        "portal_at": SPAWN,
        "fall_limit": FALL_LIMIT,
        "platforms": [],
        "shard_indices": [11],
    }

func get_map_bounds(center: Vector2) -> Rect2:
    return Rect2(center - Vector2(420, 320), Vector2(840, 640))

func room_at(_feet: Vector2) -> Dictionary:
    return ROOMS[0].duplicate()

func climb_at(_feet: Vector2) -> Dictionary: return {}
func water_at(_feet: Vector2) -> bool: return false
func portal_at(_feet: Vector2) -> Dictionary: return {}
func interaction_hint(_feet: Vector2) -> String: return ""
func try_interact(_feet: Vector2) -> bool: return false
func get_opened_ids() -> Array[String]: return []
func restore_opened_ids(_ids: Array) -> void: pass
func reset_interactions() -> void: pass

func start_room_entry() -> void:
    active = true
    calibrating = false
    battle_running = false
    _heavy_groups.clear()
    _heavy_cursor = 0
    _transport_generation = -1
    _last_chart_time = -1.0
    _clear_preview()
    var groups: Array[Dictionary] = []
    if is_instance_valid(music) and music.has_method("get_heavy_groups"):
        groups.assign(music.call("get_heavy_groups"))
    _calibration = Calibration.new()
    var base_offset: float = 245.0
    if is_instance_valid(music) and music.get("timeline") is Dictionary:
        base_offset = float(music.timeline.get("offset_ms", 245.0))
    if not _is_full_song():
        _skip_calibration("没有可校准的重拍，跳过校准。", false)
        return
    if groups.is_empty() or not _calibration.configure(groups, base_offset):
        _skip_calibration("没有可校准的重拍，跳过校准。", false)
        return
    if DisplayServer.get_name() == "headless" or AudioServer.get_driver_name() == "Dummy" or bool(music.get("_dummy")):
        _skip_calibration("当前音频设备不可用，跳过校准。", false)
        return
    calibrating = true
    if is_instance_valid(_overlay):
        _overlay.present("校准会在每次进入或重试时重新开始。")
    _start_preview()

func _is_full_song() -> bool:
    return is_instance_valid(music) and music.has_method("is_full_song") and bool(music.call("is_full_song"))

func _start_preview() -> void:
    if not calibrating or _calibration == null:
        return
    _clear_preview()
    var stream: AudioStream = null
    if is_instance_valid(music) and music.get("_audio") is AudioStreamPlayer:
        var source: AudioStreamPlayer = music.get("_audio")
        if is_instance_valid(source):
            stream = source.stream
    if stream == null:
        _skip_calibration("没有可用的音频文件，跳过校准。", true)
        return
    _preview = AudioStreamPlayer.new()
    _preview.name = "CalibrationPreview"
    _preview.bus = "Music"
    var volume_db: float = -8.0
    if is_instance_valid(music) and music.get("timeline") is Dictionary:
        volume_db = float(music.timeline.get("music_volume_db", -8.0))
    _preview.volume_db = volume_db
    _preview.stream = stream
    add_child(_preview)
    _preview.play(_calibration.preview_start_seconds())
    _preview_started_frame = Engine.get_process_frames()
    if is_instance_valid(_overlay):
        _overlay.set_progress(0, Calibration.SAMPLE_COUNT)

func _skip_calibration(reason: String, visible: bool) -> void:
    if not active:
        return
    calibrating = false
    _clear_preview()
    if visible and is_instance_valid(_overlay):
        _overlay.present("")
        _overlay.show_result(reason)
        _overlay_generation += 1
        get_tree().create_timer(2.2).timeout.connect(_hide_overlay_after_result.bind(_overlay_generation))
    calibration_complete.emit(_calibration.base_offset_ms if _calibration != null else 245.0)

func _finish_calibration(offset_ms: float) -> void:
    if not calibrating:
        return
    calibrating = false
    _clear_preview()
    var rounded: float = roundf(offset_ms)
    if is_instance_valid(_overlay):
        _overlay.show_result("校准完成：%.0f ms" % rounded)
        _overlay_generation += 1
        get_tree().create_timer(1.1).timeout.connect(_hide_overlay_after_result.bind(_overlay_generation))
    calibration_complete.emit(rounded)

func _hide_overlay_after_result(generation: int) -> void:
    if generation != _overlay_generation or not is_instance_valid(_overlay):
        return
    _overlay.dismiss()

func begin_battle(owner_boss: Node2D) -> void:
    boss = owner_boss
    battle_running = true
    calibrating = false
    _clear_preview()
    _overlay_generation += 1
    if is_instance_valid(_overlay):
        _overlay.dismiss()
    _heavy_groups.clear()
    if is_instance_valid(music) and music.has_method("get_heavy_groups"):
        _heavy_groups.assign(music.call("get_heavy_groups"))
    _heavy_cursor = 0
    _transport_generation = int(music.call("get_transport_generation")) if is_instance_valid(music) else -1
    _last_chart_time = -1.0

func _process(delta: float) -> void:
    if not active:
        return
    if calibrating:
        _process_calibration()
    elif battle_running:
        _process_heavy_groups()
    _update_platforms()
    _update_draw(delta)

func _process_calibration() -> void:
    if _preview == null or not is_instance_valid(_preview):
        return
    if not _preview.playing:
        if Engine.get_process_frames() > _preview_started_frame + 1:
            if _calibration.is_complete():
                _finish_calibration(_calibration.adjusted_offset_ms())
            else:
                _overlay.set_retry("没有采足 5 下，马上重新播放。")
                _start_preview()
        return
    var now: float = _preview_clock()
    _overlay.set_progress(_calibration.tap_positions.size(), Calibration.SAMPLE_COUNT)
    var finish_at: float = float(_calibration.sample_times.back()) + 0.75 if not _calibration.sample_times.is_empty() else INF
    if now >= finish_at:
        if _calibration.is_complete():
            _finish_calibration(_calibration.adjusted_offset_ms())
        else:
            _overlay.set_retry("没有采足 5 下，马上重新播放。")
            _start_preview()

func _preview_clock() -> float:
    if _preview == null or not is_instance_valid(_preview):
        return 0.0
    if not _preview.playing:
        return 0.0
    return maxf(0.0, _preview.get_playback_position() + AudioServer.get_time_since_last_mix() - AudioServer.get_output_latency())

func _unhandled_input(event: InputEvent) -> void:
    if not active or not calibrating or _calibration == null:
        return
    var key_event: InputEventKey = event as InputEventKey
    if key_event != null and key_event.pressed and not key_event.echo and key_event.physical_keycode in [KEY_ESCAPE, KEY_BACKSPACE]:
        _skip_calibration("已跳过校准。", true)
        get_viewport().set_input_as_handled()
        return
    var pressed: bool = false
    if key_event != null:
        pressed = key_event.pressed and not key_event.echo
    elif event is InputEventMouseButton:
        pressed = event.pressed
    elif event is InputEventJoypadButton:
        pressed = event.pressed
    if not pressed:
        return
    var accepted: bool = _calibration.register_tap(_preview_clock())
    get_viewport().set_input_as_handled()
    if not accepted:
        return
    _overlay.set_progress(_calibration.tap_positions.size(), Calibration.SAMPLE_COUNT)
    if _calibration.is_complete():
        _finish_calibration(_calibration.adjusted_offset_ms())

func _process_heavy_groups() -> void:
    if not is_instance_valid(music) or not bool(music.get("running")):
        return
    var now: float = float(music.call("get_chart_time"))
    var generation: int = int(music.call("get_transport_generation"))
    if generation != _transport_generation or now + 0.05 < _last_chart_time:
        _transport_generation = generation
        _heavy_cursor = 0
        heavy_history_cleared.emit()
        while _heavy_cursor < _heavy_groups.size():
            if float(_heavy_groups[_heavy_cursor].get("time", INF)) >= now - 0.000001:
                break
            _heavy_cursor += 1
    var safe: bool = is_instance_valid(game) and bool(game.get("story_safe"))
    while _heavy_cursor < _heavy_groups.size():
        var event_time: float = float(_heavy_groups[_heavy_cursor].get("time", INF))
        if event_time > now + 0.000001:
            break
        _heavy_cursor += 1
        if safe or event_time < 0.0:
            continue
        heavy_clash_requested.emit(event_time)
    _last_chart_time = now

func _update_platforms() -> void:
    if not is_instance_valid(game):
        return
    var player: Node2D = game.get("player")
    if not is_instance_valid(player):
        return
    var center: Vector2 = player.global_position
    var first_index: int = int(floor((center.x - PLATFORM_SURROUND) / PLATFORM_SPACING))
    var last_index: int = int(ceil((center.x + PLATFORM_SURROUND) / PLATFORM_SPACING))
    var drop_through: bool = InputMap.has_action("climb_down") and Input.is_action_pressed("climb_down")
    for key: Variant in _platforms.keys():
        var parts: PackedStringArray = str(key).split(":")
        var layer: int = int(parts[0]) if parts.size() == 2 else -1
        var index: int = int(parts[1]) if parts.size() == 2 else -1
        if layer < 0 or layer >= PLATFORM_LAYER_COUNT or index < first_index or index > last_index:
            var old: Node = _platforms[key]
            _platforms.erase(key)
            if is_instance_valid(old):
                old.queue_free()
    for layer: int in PLATFORM_LAYER_COUNT:
        for index: int in range(first_index, last_index + 1):
            var key: String = "%d:%d" % [layer, index]
            if not _platforms.has(key) or not is_instance_valid(_platforms[key]):
                _platforms[key] = _make_platform(layer, index)
            var body: StaticBody2D = _platforms[key]
            var shape_node: CollisionShape2D = body.get_child(0) as CollisionShape2D
            shape_node.disabled = drop_through

func _make_platform(layer: int, index: int) -> StaticBody2D:
    var body := StaticBody2D.new()
    body.name = "InfinitePlatform_%d_%d" % [layer, index]
    body.position = Vector2(float(index) * PLATFORM_SPACING + PLATFORM_WIDTH * 0.5, platform_layer_y(layer))
    body.collision_layer = 1
    body.collision_mask = 0
    var shape_node := CollisionShape2D.new()
    var shape := RectangleShape2D.new()
    shape.size = Vector2(PLATFORM_WIDTH, PLATFORM_HEIGHT)
    shape_node.shape = shape
    shape_node.one_way_collision = true
    shape_node.one_way_collision_margin = 4.0
    body.add_child(shape_node)
    add_child(body)
    return body

static func platform_layer_y(layer: int) -> float:
    return PLATFORM_BASE_Y + float(layer - 2) * PLATFORM_LAYER_SPACING

func _update_draw(delta: float) -> void:
    _clock += delta
    _draw_clock += delta
    var player: Node2D = game.get("player") if is_instance_valid(game) else null
    var moved: bool = not is_instance_valid(player) or player.global_position.distance_to(_last_draw_at) > DRAW_MOVE
    if _draw_clock < DRAW_INTERVAL and not moved:
        return
    _draw_clock = 0.0
    if is_instance_valid(player):
        _last_draw_at = player.global_position
    queue_redraw()

func _draw() -> void:
    if not active:
        return
    var visible_rect: Rect2 = get_viewport().get_canvas_transform().affine_inverse() * Rect2(Vector2.ZERO, get_viewport_rect().size)
    visible_rect = visible_rect.grow(96.0)
    draw_rect(visible_rect, DARK)
    var first_row: int = int(floor(visible_rect.position.y / 20.0))
    var last_row: int = int(ceil(visible_rect.end.y / 20.0))
    for row: int in range(first_row, last_row + 1):
        var y: float = float(row) * 20.0
        draw_rect(Rect2(visible_rect.position.x, y, visible_rect.size.x, 1), FAR)
        var offset: float = 20.0 if row % 2 else 0.0
        var first_col: int = int(floor((visible_rect.position.x - offset) / 40.0))
        var last_col: int = int(ceil((visible_rect.end.x - offset) / 40.0))
        for col: int in range(first_col, last_col + 1):
            draw_rect(Rect2(float(col) * 40.0 + offset, y + 1.0, 1.0, 19.0), FAR)
    var first_pillar: int = int(floor(visible_rect.position.x / 320.0))
    var last_pillar: int = int(ceil(visible_rect.end.x / 320.0))
    for index: int in range(first_pillar, last_pillar + 1):
        _draw_lancet(float(index * 320) + 16.0, -40.0, 252.0, FAR)
    var first_torch: int = int(floor(visible_rect.position.x / 480.0))
    var last_torch: int = int(ceil(visible_rect.end.x / 480.0))
    for index: int in range(first_torch, last_torch + 1):
        _draw_torch(float(index * 480) + 24.0, -14.0)
    for layer: int in PLATFORM_LAYER_COUNT:
        var layer_y: float = platform_layer_y(layer)
        _draw_platform(Rect2(visible_rect.position.x, layer_y - PLATFORM_HEIGHT * 0.5, visible_rect.size.x, PLATFORM_HEIGHT))

func _draw_platform(area: Rect2) -> void:
    draw_rect(area, DARK)
    draw_rect(Rect2(area.position.x, area.position.y, area.size.x, 4), LIP)
    draw_rect(Rect2(area.position.x, area.position.y + 4, area.size.x, 4), STONE)
    var row_count: int = maxi(1, int((area.size.y - 8) / 18))
    for row: int in range(row_count):
        var y: float = area.position.y + 9 + row * 18
        var offset: int = 18 if row % 2 else 0
        for col: int in range(int(area.size.x / 36) + 1):
            var left: float = maxf(area.position.x + 2, area.position.x + col * 36 - offset + 2)
            var right: float = minf(area.end.x - 2, area.position.x + col * 36 - offset + 34)
            if right > left:
                draw_rect(Rect2(left, y, right - left, minf(14, area.end.y - y)), MASON if row < 2 else MID)
    if area.size.y <= 16:
        for x: int in range(int(area.position.x) + 8, int(area.end.x) - 8, 24):
            draw_rect(Rect2(x, area.position.y + 4, 1, 8), DARK)

func _draw_lancet(x: float, top: float, height: float, tint: Color) -> void:
    draw_rect(Rect2(x, top + 32, 12, height - 32), tint)
    draw_rect(Rect2(x + 84, top + 32, 12, height - 32), tint)
    for step: int in range(4):
        var inset: float = 8.0 + float(step) * 8.0
        draw_rect(Rect2(x + inset, top + 24.0 - float(step) * 8.0, 96.0 - inset * 2.0, 8.0), tint)

func _draw_torch(x: float, y: float) -> void:
    draw_rect(Rect2(x - 4, y - 10, 8, 10), MASON)
    draw_rect(Rect2(x - 2, y - 14, 4, 6), GOLD_LOW)
    var flicker: int = 2 if int(_clock * 8.0 + x) % 3 == 0 else 0
    draw_rect(Rect2(x - 2, y - 19 - flicker, 4, 6 + flicker), GOLD)
    draw_rect(Rect2(x, y - 18 - flicker, 2, 4), Color("d7c898"))

func _clear_preview() -> void:
    if _preview != null and is_instance_valid(_preview):
        _preview.stop()
        _preview.queue_free()
    _preview = null
```

- [ ] **Step 5: Run the test and confirm it passes**

Expected: `Boss room: <n> passed, 0 failed`.

- [ ] **Step 6: Commit the room, overlay, and room test**

```bash
git add -- ui/calibration_overlay.gd levels/boss_room.gd tests/boss_room_test.gd
git commit -m "Port the infinite boss room and calibration overlay"
```

---

### Task 4: Mount the room and gate the start on calibration

**Files:**
- Modify: `main.gd` (`_ready`, `_mount_room`, `_finish_room_preparation`, `_start_boss`, `_physics_process`, `_unhandled_input`, `_portal_target`, `_refresh_hud`)
- Modify: `tests/room_transition_test.gd:69-95`
- Modify: `tests/main_scene_migration_test.gd:129`
- Modify: `tools/capture_review.gd:57`
- Modify: `tools/capture_rooms.gd:67`
- Modify: `tools/capture_boss_redhair.gd:26`
- Modify: `tools/verify_main.ps1:6`
- Test: existing `room_transition_test`, `main_scene_migration_test`; rerun `boss_room_test`, `full_song_offset_test`, `audio_calibration_test`

**Interfaces:**
- Consumes: `BossRoom.setup/start_room_entry/begin_battle/get_map_bounds`, `BossRoom.calibration_complete`, `MusicDirector.replace_offset_ms`.
- Produces: `main._start_boss(calibrate: bool = true)`, `main._on_boss_calibration_complete(offset_ms: float)`, `main._begin_boss_battle()`, `main._calibrating: bool`.

- [ ] **Step 1: Update the two expectations the room swap invalidates**

In `tests/room_transition_test.gd`, replace:

```gdscript
    check(game.room_id == "boss" and game.level.get_script().resource_path.ends_with("boss_chamber.gd"), "black interval mounts actual independent Boss scene")
```

with:

```gdscript
    check(game.room_id == "boss" and game.level.get_script().resource_path.ends_with("boss_room.gd"), "black interval mounts actual independent Boss scene")
```

Replace:

```gdscript
    check(game._hud.state["room_id"] == "boss" and game._hud.state["room_bounds"] == game.level.WORLD_BOUNDS, "HUD receives actual room bounds")
```

with:

```gdscript
    check(game._hud.state["room_id"] == "boss" and game._hud.state["room_bounds"] == game.level.get_map_bounds(game.player.position), "HUD receives the moving Boss-room bounds")
```

Replace the first masonry block:

```gdscript
    var masonry_disabled: bool = true
    for body: Node in game.level.get_children():
        if body is StaticBody2D: masonry_disabled = masonry_disabled and body.collision_layer == 0
    check(masonry_disabled, "infinite Boss room keeps its artwork without old solid walls or floor")
```

with:

```gdscript
    check(_all_platforms_are_one_way(game.level), "infinite Boss room exposes only layer-1 one-way platforms")
```

Replace the retry masonry block:

```gdscript
    masonry_disabled = true
    for body: Node in game.level.get_children():
        if body is StaticBody2D: masonry_disabled = masonry_disabled and body.collision_layer == 0
    check(masonry_disabled, "Boss retry keeps retired masonry non-solid")
```

with:

```gdscript
    check(_all_platforms_are_one_way(game.level), "Boss retry keeps the one-way platform contract")
```

Add this helper before `func run()`:

```gdscript
func _all_platforms_are_one_way(room: Node) -> bool:
    var found: bool = false
    for body: Node in room.get_children():
        if body is StaticBody2D:
            found = true
            if body.collision_layer != 1 or body.collision_mask != 0:
                return false
            for child: Node in body.get_children():
                if child is CollisionShape2D and not child.one_way_collision:
                    return false
    return found
```

In `tests/main_scene_migration_test.gd`, replace:

```gdscript
    check(game.level.get_script().resource_path == "res://levels/boss_chamber.gd", "main mounts the real Boss chamber script")
```

with:

```gdscript
    check(game.level.get_script().resource_path == "res://levels/boss_room.gd", "main mounts the infinite Boss room script")
```

- [ ] **Step 2: Run the two tests and confirm they fail**

```bash
powershell -ExecutionPolicy Bypass -File tools/verify_main.ps1 -Only room_transition_test,main_scene_migration_test
```

Expected: FAIL — main still mounts `boss_chamber.gd` and reports static room bounds.

- [ ] **Step 3: Swap the mounted script and wire the calibration signal**

In `main.gd`, add next to the other preloads:

```gdscript
const BossRoom = preload("res://levels/boss_room.gd")
```

Add next to the room state fields:

```gdscript
var _calibrating: bool = false
```

In `_ready`, replace both lines that pick the room:

```gdscript
    level = BossChamber.new() if room_id == "boss" else Level.new()
```

with:

```gdscript
    level = BossRoom.new() if room_id == "boss" else Level.new()
```

Immediately after `level.setup(self)` in `_ready`, insert:

```gdscript
    if level.has_signal("calibration_complete"):
        level.connect("calibration_complete", _on_boss_calibration_complete)
```

Keep the old body-disable loop but guard it:

```gdscript
    if room_id == "boss" and level is BossChamber:
        for body: Node in level.get_children():
            if body is StaticBody2D: body.collision_layer = 0
```

In `_mount_room`, add `_calibrating = false` beside the `boss = null` reset, replace the room construction line with `BossRoom`, guard the body loop the same way, and after `level.setup(self)` insert:

```gdscript
    if level.has_signal("calibration_complete"):
        level.connect("calibration_complete", _on_boss_calibration_complete)
```

- [ ] **Step 4: Split Boss start into calibration and battle**

Replace the whole current `_start_boss` function with:

```gdscript
func _start_boss(calibrate: bool = true) -> void:
    if boss_started or outcome != "": return
    # Kept as a synchronous integration hook; normal play only calls this after
    # the portal's full-black mount and preparation have completed.
    if room_id != "boss": _mount_room("boss")
    var status: Dictionary = music.get_full_song_status()
    if status.get("requested", false) and not status.get("ready", false):
        set_story_safe(true)
        player.set_physics_process(true)
        announce("Score unavailable. E returns to the dungeon; R retries.", 60.0)
        return
    if calibrate and level.has_method("start_room_entry"):
        _calibrating = true
        set_story_safe(true)
        player.set_physics_process(false)
        level.start_room_entry()
        if _calibrating:
            announce("校准：跟随重鼓按任意键；ESC 跳过。", 60.0)
        return
    set_story_safe(false)
    player.set_physics_process(true)
    _begin_boss_battle()

func _on_boss_calibration_complete(offset_ms: float) -> void:
    if room_id != "boss" or boss_started or outcome != "": return
    _calibrating = false
    if music.has_method("replace_offset_ms"):
        music.replace_offset_ms(offset_ms)
    set_story_safe(false)
    player.set_physics_process(true)
    _begin_boss_battle()

func _begin_boss_battle() -> void:
    boss = Boss.new()
    boss.process_mode = Node.PROCESS_MODE_PAUSABLE
    boss.z_index = 2
    add_child(boss)
    boss.configure(self, room_spec["boss_spawn"])
    boss.set_infinite_room(true)
    boss_started = true
    boss.start_encounter()
    if level.has_method("begin_battle"):
        level.begin_battle(boss)
    if is_instance_valid(chapter): chapter.event("boss_enter")
    _refresh_hud()
```

- [ ] **Step 5: Let the room own the prepared-Boss unlock**

Replace `_finish_room_preparation` with:

```gdscript
func _finish_room_preparation() -> void:
    _room_prepare = 0.0
    if is_instance_valid(chapter) and chapter.blocked(): return
    if room_id == "boss":
        player.reset_direction_taps()
        _start_boss()
        _refresh_hud()
        return
    set_story_safe(false)
    player.set_physics_process(true)
    player.reset_direction_taps()
    announce("The portal returns you to the dungeon threshold.", 3.0)
    _refresh_hud()
```

- [ ] **Step 6: Gate physics, input, portal and HUD bounds**

In `_physics_process`, change:

```gdscript
    if _reloading or _paused or room_flow.active or _room_prepare > 0.0 or not is_instance_valid(player) or (is_instance_valid(chapter) and chapter.blocked()):
```

to:

```gdscript
    if _reloading or _paused or _calibrating or room_flow.active or _room_prepare > 0.0 or not is_instance_valid(player) or (is_instance_valid(chapter) and chapter.blocked()):
```

At the top of `_unhandled_input`, insert:

```gdscript
    if _calibrating: return
```

At the top of `_portal_target`, insert:

```gdscript
    if _calibrating: return ""
```

In `_refresh_hud`, replace the emitted `"room_bounds": room_spec.get("bounds", Level.WORLD_BOUNDS)` with a precomputed value. Immediately before `hud_updated.emit(` insert:

```gdscript
    var shown_bounds: Rect2 = room_spec.get("bounds", Level.WORLD_BOUNDS)
    if level.has_method("get_map_bounds"):
        shown_bounds = level.get_map_bounds(player.global_position)
```

Then change `"room_bounds": room_spec.get("bounds", Level.WORLD_BOUNDS)` to `"room_bounds": shown_bounds` inside the dictionary.

- [ ] **Step 7: Make captures bypass calibration and register the new tests**

In `tools/capture_review.gd`, change `game._start_boss()` to `game._start_boss(false)`.
In `tools/capture_rooms.gd`, change `game._start_boss()` to `game._start_boss(false)`.
In `tools/capture_boss_redhair.gd`, change `game._start_boss()` to `game._start_boss(false)`.

In `tools/verify_main.ps1`, inside the `$checks` array, insert after `'full_song_coverage_test',`:

```powershell
'audio_calibration_test','full_song_offset_test','boss_room_test',
```

- [ ] **Step 8: Run the focused suite**

```bash
powershell -ExecutionPolicy Bypass -File tools/verify_main.ps1 -Only audio_calibration_test,full_song_offset_test,boss_room_test,room_transition_test,main_scene_migration_test,full_song_transport_test,main_full_song_test
```

Expected: every listed check prints PASS and the overall script exits 0.

- [ ] **Step 9: Do not commit shared files**

`main.gd`, the updated tests, the capture tools and the runner already contain unrelated local edits. Leave them uncommitted for review; do not `git add` them.

---

### Task 5: Full verification and manual room check

**Files:**
- No source changes expected.

- [ ] **Step 1: Run the complete headless suite**

```bash
powershell -ExecutionPolicy Bypass -File tools/verify_main.ps1
```

Expected: every check PASS, no `SCRIPT ERROR:`, `ERROR:`, `FAIL `, or leaked-node output. This suite takes several minutes because it decodes the OGG repeatedly.

- [ ] **Step 2: Run the full-song suite with the real 12 MB OGG**

```bash
powershell -ExecutionPolicy Bypass -File tools/verify_main.ps1 -LocalScore -Only full_song_transport_test,full_song_boss_test,full_song_coverage_test,main_full_song_test,audio_calibration_test,full_song_offset_test
```

Expected: all PASS; `full_song_offset_test` confirms the 107 heavy groups shift by exactly the requested delta.

- [ ] **Step 3: Manual playtest on a real audio device**

Launch the project normally (no `BELLKEEP_USE_PLACEHOLDER`), defeat the elite, enter the Boss portal, and confirm:

1. Five platform layers exist on screen and the camera follows the player left/right without a room edge.
2. Holding `S`/`Down` drops the player through every layer; releasing restores collisions.
3. The calibration panel appears, five taps advance `重鼓 n / 5`, and the resulting offset is applied before the Boss's first beat.
4. Pressing `ESC` during calibration skips immediately with the current offset and starts the fight.
5. On retry (`R`), calibration restarts; on Dummy/headless it silently skips.
6. The Boss still fires its existing wave volleys and laser/cube formations; the room change did not remove skills.

If any step fails, capture the console log and stop; do not adjust calibration math or room geometry without returning to the spec.

- [ ] **Step 4: Report results**

Report: focused suite result, full suite result, full-song result, and the manual playtest outcomes (or state explicitly which manual steps could not be performed).

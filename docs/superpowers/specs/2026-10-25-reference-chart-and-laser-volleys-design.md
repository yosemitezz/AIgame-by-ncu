# Reference Chart + Multi-Volley Center-Tracking Lasers — Design

- Date: 2026-10-25
- Branch: `feat/polish-story-local-20261025`
- Reference source: `IF_story(1)/IF_story/IF/boss_attack/data/if_infinity.chart.json`
  (read-only, never mounted at runtime, never committed)
- Scope: the bellkeeper Boss chart and laser formations only.

## 1. Goal

Replace the shipped private chart with the reference chart, and make each laser formation fire
as beat-clustered **multi-beam volleys that re-center on the player once, at each volley's
warning start**. The player sees four beams lock onto the current position, gets the full warning
window to move, and the next volley locks onto the new position.

This is the user's "激光阵多发且中心追踪，借鉴卡点" request. "多发" comes from the reference
chart's beat-synced re-grouping; "中心追踪" is the new per-volley re-aim. Neither is synthesized
procedurally, and no extra beams are invented.

## 2. Non-goals

- Do not merge charts, generate notes, or derive a laser-only chart.
- Do not change the OGG, BPM (203), base offset (245 ms), section beats, or transport.
- Do not change heavy clash, parry, guard, damage, health, sustain, fade, room flow, or camera.
- Do not change calibration UI or math; the reference chart selects the same five samples.
- Do not change the one-hazard-per-formation contract, the 24-hazard cap, the 180-projectile cap,
  or the coverage test's completeness guarantees.
- Do not port other files from `IF_story(1)` or commit that directory.
- Do not add or copy private audio, credentials, local paths, or logs.

## 3. Verified current state

### 3.1 The two charts are the same song, grouped differently

Both charts end at 409.530714285714 s and fit the existing 418.51573696145124 s OGG. They share the
song timeline and the first source cues, but the reference adds sub-beat notes and reorganises long
notes into simultaneous volleys:

| Stat | Shipped chart | Reference chart |
|---|---|---|
| Bytes | 41269 | 59615 |
| SHA256 | `133082afb6234f693576d78db4c228fcb882a6027049df3dd687e0f198df3b27` | `5caa2721292be473c7d8ca760c8948d1aab43b42fc82a80fb02e352369aebe5f` |
| Notes | 1172 | 1703 |
| Timed notes | 1171 | 1702 |
| Unique times | 862 | 1048 |
| Timing groups | 703 | 839 |
| Paired note groups | 315 | 360 |
| Heavy groups | 107 | 121 |
| Long notes (`endbeat`) | 230 | 331 |
| Fixed cube events | 24 | 36 |
| Ordinary lasers | 182 | 259 |
| Laser formations | 48 | 67 |
| Action phrases | 228 | 237 |
| Basic / fast phrases | 141 / 87 | 114 / 123 |
| Phases | 21 | 17 |
| First heavy | beat `73:0:4`, t=21.821354679803 s | same |

The first source formation proves the intent. The shipped chart streams four separate beams at
88.028, 90.393, 92.757 and 95.122 s. The reference fires the same four lanes together at
88.028-88.250 s (damage 89.137-89.211 s), then repeats that four-beam volley at 90.393 (parallel),
92.757 (grid) and 95.122 s (rotating). That is the beat-synced (卡点) pattern the user asked for.

### 3.2 The runtime pipeline already accepts the reference chart

- `chart_parser.gd` parses the reference chart with no errors and the counts above.
- `_build_laser_formations` groups four consecutive ordinary lasers per phase. The reference
  yields 67 formations, 176 half-beat volleys, and at most 4 volleys per formation
  (tolerance `0.5 * 60 / 203 = 0.14778325123153` s).
- `laser_formation_planner.gd`, `boss.gd` dispatch, `BossHazard` warning/damage/clear, and
  `main.spawn_boss_hazard` are chart-agnostic.
- `AudioCalibration` selects the same samples on both charts: 40.7376, 41.1810, 41.6243,
  42.0677, 42.5110 s; preview 38.7376 s. No calibration change is needed.
- Full-song offset application re-parses this same path, so it inherits the replacement with no
  code change.

### 3.3 What is missing

1. The shipped chart file and its SHA256 baseline.
2. A way to translate a line to a new center (`center_offset`).
3. Per-volley re-aim inside `BossHazard`.
4. Baseline updates in six tests, the audit tool, and the runtime doc.
5. Tests proving clustering, one-shot re-aim, immovable live warnings, and cube exclusion.

## 4. Locked decisions

| Topic | Decision | Why |
|---|---|---|
| Chart source | Replace the whole shipped chart with the reference chart | User chose "整体换参考谱面". |
| Chart identity | Byte-identical copy; new SHA256 `5caa2721292be473c7d8ca760c8948d1aab43b42fc82a80fb02e352369aebe5f` | The runtime validates the hash and the stats are audited. |
| Audio | Unchanged OGG, BPM, offset, boundaries | The chart fits the existing audio and calibration. |
| Tracking trigger | Each volley re-centers once at the start of its own warning | User chose "开火瞬间重新对心"; the warning must stay dodgeable. |
| Warning immobility | A volley already in warning when the hazard is created never moves | A visible warning must never jump. |
| Volley granularity | Lines with `damage_time` within half a beat are one volley | Matches the reference's quarter/eighth-note bursts. |
| Hazard granularity | One `BossHazard` per source formation | Preserves coverage semantics and the hazard cap accounting. |
| Cubes | No tracking | Cube geometry is authored around its landing point, not the player. |
| SFX | One warn and one fire event per hazard, as today | Avoid a wall of overlapping laser sounds. |
| Arena | `boss.get_laser_arena()` at aim time; fall back to the stored arena | Infinite room = player-centered; fixed room = fixed. |
| Caps | Unchanged (24 hazards, 180 projectiles) | The coverage test is the density gate; no silent cap raise. |

## 5. Architecture

```
reference chart.json
  └─ chart_parser (unchanged) ──> friend_director events
        ├─ heavy groups        (121, calibration + heavy clash)
        ├─ action phrases      (237, existing waves/actions)
        ├─ fixed_attack        (36, existing cubes)
        └─ laser_formation     (67)
              └─ boss._spawn_authored_formation
                    ├─ FriendLasers.build_lines -> lines + center_offset
                    ├─ stale filter (unchanged)
                    └─ one BossHazard(game, boss, lines, arena, gen, pattern, half_beat)
                          ├─ cluster lines by damage_time (half beat)
                          ├─ at cluster warning start: origin = new_center + center_offset
                          │     re-clip a/b; mark cluster aimed once
                          ├─ damage: existing line_hits_player(a, b)
                          └─ draw: existing warning/fired-beam presentation
```

Only three production files change: the planner (offset), the hazard (clusters and re-aim), and
the Boss (pass the half-beat window and cache the arena). The chart is data.

## 6. Chart replacement

### 6.1 Procedure

1. Copy the reference chart bytes over the shipped chart:
   `boss_attack/data/if_infinity.chart.json`.
2. Do not copy or add anything else from `IF_story(1)` (no OGG, manifests, other charts, or
   source code). Do not touch `boss_attack/audio/if_infinity.ogg`.
3. Verify `sha256sum boss_attack/data/if_infinity.chart.json` is
   `5caa2721292be473c7d8ca760c8948d1aab43b42fc82a80fb02e352369aebe5f` and the size is 59615.
4. Update `data/full_song_timeline.json` `expected_chart_sha256` to that value. Every other
   timeline key stays byte-identical, including `expected_audio_sha256`
   (`007d002c1a5472af2ef78e62e5027c89b28cfb0f15b4cd5880ce75c6b66547b5`).
5. The chart contains no absolute paths, credentials, or personal data; its metadata matches the
   existing shipped chart's schema (`creator: "zjuan"`, song `_temp_1792766979`).

### 6.2 Baseline updates

| File | Change |
|---|---|
| `data/full_song_timeline.json` | `expected_chart_sha256` -> `5caa2721292be473c7d8ca760c8948d1aab43b42fc82a80fb02e352369aebe5f` |
| `tools/audit_friend_chart.gd` | `notes:1703, timed_notes:1702, unique_times:1048, timing_groups:839, heavy_groups:121, endbeat_records:331, ordinary_lasers:259, phases:17, paired_note_groups:360, action_phrases:237, fixed_attack_events:36, laser_formations:67, basic_phrases:114, fast_phrases:123` |
| `tests/full_song_coverage_test.gd` | phrases 237 (114 basic / 123 fast); fixed 36; formations 67 |
| `tests/full_song_boss_test.gd` | action phrases 237 |
| `tests/full_song_offset_test.gd` | heavy groups 121; timed notes 1702; phrases 237 |
| `tests/full_song_transport_test.gd` | timed notes 1702; phrases 237; heavy groups 121; first heavy beat 73 assertion unchanged |
| `tests/heavy_judge_test.gd` | 121 groups, 121 results/IDs, generation fixture 121 -> 122, labels updated |
| `tests/main_full_song_test.gd` | 1702 timed notes / 121 heavy / 237 phrases |
| `docs/full-song-runtime.md` | counts, end time, and the new tracking rule |

Docs `docs/friend-boss-main-integration.md` and `docs/friend-handoff-compatibility.md` keep their
historical statements but get one appended line: the shipped chart was later replaced by the
reference chart (`5caa2721292be473c7d8ca760c8948d1aab43b42fc82a80fb02e352369aebe5f`, 59615 bytes); the earlier byte-identity statement describes the
previous handoff only.

### 6.3 What does not change

- `data/authored_boss_moves.json`, patterns, safe offsets, line thickness, damage values.
- Calibration samples/preview (verified identical), UI, and offset application.
- Section boundaries, random gate, rest window, stale windows, caps.

## 7. Multi-volley center tracking

### 7.1 Planner: `combat/friend_rhythm/laser_formation_planner.gd`

Keep the signature and every existing field. Add one field per emitted line:

```
"center_offset": origin - center,
```

`center` is `arena_rect.get_center()`, i.e. the arena the formation was authored against. Because
every pattern origin is `center` plus a pattern-specific translation (including the grid's
`arena_rect.position ± gap` form, which is `center ± size/2 ± gap`), re-basing a line on a new
center is exact:

```
new_origin = new_center + center_offset
```

Angles, thickness, timings, `formation_index`, and line count are unchanged.

### 7.2 Hazard: `combat/boss_hazard.gd`

New state:

```
var _track_window: float = 0.0          # seconds; half a beat, 0 disables tracking
var _created_at: float = 0.0            # score time when configure ran
var _clusters: Array[Dictionary] = []   # one record per volley
```

`configure_lines` gains a trailing optional parameter:

```
func configure_lines(p_game: Node, owner_boss: Node, records: Array[Dictionary], arena: Rect2,
        version: int, formation_kind: String = "laser", half_beat_seconds: float = 0.0) -> void
```

After storing the existing fields and clipping each line to `arena.grow(BEAM_OVERSCAN)`:

```
_track_window = maxf(0.0, half_beat_seconds)
var music_node: Variant = game.get("music") if is_instance_valid(game) else null
_created_at = float(music_node.get_score_time()) if is_instance_valid(music_node) else 0.0
clock_time = _created_at
_build_clusters()
```

`configure_cube` keeps calling `configure_lines` without the new argument. Its lines have no
`center_offset`, so they never enter a cluster.

Cluster construction (`_build_clusters`):

- Only lines with a `Vector2` `center_offset` participate.
- Sort their indices by `damage_time`.
- Start a cluster at the first index; start a new cluster when
  `damage_time - anchor_damage > _track_window`; update `anchor_damage` to the new cluster's first
  damage time.
- Each cluster stores `indices`, `warning = min(warning_time)`,
  `aim_at = max(warning, _created_at)`, `aimed = bool`.
- `aimed` is true at creation when `warning <= _created_at + 0.000001`. Such a volley was already
  on screen (or would be on the first draw) and keeps the spawn-center geometry. This is also the
  common case for the first volley, because the Boss builds lines from the player-centered arena
  at that same moment.
- Clusters are built in damage order, but the aim loop is order-independent.

Aim loop, called as `_aim_due_clusters(owner_boss, clock_time)` from `_physics_process` after the
clock is read and before SFX/damage/draw:

```
func _aim_due_clusters(owner_boss: Node, now: float) -> void:
    for cluster in _clusters:
        if bool(cluster["aimed"]) or now + 0.000001 < float(cluster["aim_at"]):
            continue
        var arena: Rect2 = arena_rect
        if is_instance_valid(owner_boss) and owner_boss.has_method("get_laser_arena"):
            arena = owner_boss.get_laser_arena()
        var center: Vector2 = arena.get_center()
        var bounds: Rect2 = arena.grow(BEAM_OVERSCAN)
        for index in cluster["indices"]:
            var line: Dictionary = lines[index]
            var origin: Vector2 = center + (line["center_offset"] as Vector2)
            var segment: Array[Vector2] = clipped_line(origin, float(line["angle_radians"]), bounds)
            if segment.size() != 2:
                continue
            line["origin"] = origin
            line["a"] = segment[0].round()
            line["b"] = segment[1].round()
        arena_rect = arena
        cluster["aimed"] = true
```

Properties this guarantees:

- **Exactly once.** `aimed` flips on the first frame at or after `aim_at`; later player movement
  does not move that volley.
- **No visible jumps.** A volley's warning first becomes visible at `warning_time`; the aim runs
  in the same physics frame before `queue_redraw`, so its first drawn warning is already final.
  Clusters visible at creation never aim.
- **No line loss.** Re-aim rewrites geometry only; line count, indices, and `_hits` keys are
  stable. A failed clip leaves that line untouched but still retires the cluster.
- **SFX stays once per hazard.** `_first_warning`/`_first_damage`, `_warn_fx_done`, `_fire_fx_done`
  and `_trigger_sfx` are unchanged. The first-line origin is rewritten before its fire event if
  its cluster re-aimed.
- **Damage is unchanged.** `line_hits_player` still tests the player body against the current
  `a`/`b`; the hit is applied once per `damage_time` window as today.
- **Teardown is unchanged.** `story_safe`, Boss death, generation mismatch, pause, outcome, and
  player death still clear the hazard. Pause freezes the aim loop with everything else.

`get_geometry_snapshot()` adds:

```
"tracking": {"window": _track_window, "clusters": _clusters.size(), "aimed": _aimed_count()}
```

`_aimed_count()` returns the number of clusters whose `aimed` flag is true. This is additive;
existing consumers (`full_song_coverage_test`) read only `kind`, `lines`, `cube`, `generation`,
and `clock`.

### 7.3 Boss wiring: `combat/boss.gd`

In `_spawn_authored_formation`:

- Cache `var arena: Rect2 = get_laser_arena()` once and use it for `build_lines`, the hazard, and
  the cast FX center (replacing the current double call).
- Compute the window from the sole clock:

```
const LASER_TRACK_HALF_BEAT: float = 0.5

var half_beat: float = 0.0
if is_instance_valid(game) and is_instance_valid(game.music) and game.music.has_method("seconds_per_beat"):
    half_beat = float(game.music.seconds_per_beat()) * LASER_TRACK_HALF_BEAT
hazard.configure_lines(game, self, lines, arena, hazard_generation, str(formation["pattern"]), half_beat)
```

- The stale-line filter, `_loop_origin_score`, `_danmaku_burst`, skip traces, and
  `spawn_boss_hazard` return handling stay as they are. Tracking applies in full-song and in the
  normal random/final flow whenever the music exposes `seconds_per_beat`.

## 8. Tests

### 8.1 New: `tests/laser_tracking_test.gd`

Register as `laser_tracking_test` in `tools/verify_main.ps1`. Fixtures are synthetic and
deterministic: a `Clock` exposing `get_score_time()/set time`, a `ProbeBoss` with `dead`,
`hazard_generation`, and `get_laser_arena()` returning
`Rect2(player.global_position - Vector2(360, 240), Vector2(720, 440))`, and a `Game` exposing
`music`, `player` (`dead`, `health`), `story_safe`, `_paused`, `outcome`, `emit_fx`, and
`damage_player`.

Planner checks:

1. For each pattern (`diamond`, `parallel`, `grid`, `rotating`), every line has a `Vector2`
   `center_offset` and `origin == center + center_offset`.
2. Re-basing four lines from center C to C2 (`C2 + offset`) preserves every pairwise distance and
   every `angle_radians`.
3. With a fixture config whose `safe_offsets` is `[[0.0, 0.0]]` and a 720x440 arena, grid offsets
   keep their full-arena relationship: vertical lines have
   `center_offset == Vector2(±64, -240)`; horizontal lines have
   `center_offset == Vector2(-380, ±43)`.

Hazard checks:

4. A four-line fixture with warnings `9.5, 9.6, 11.5, 11.6` and damage times
   `10.5, 10.6, 12.5, 12.6` (window 0.147783) builds two clusters; `tracking.clusters == 2`,
   `aimed == 0` at creation time 8.0.
5. Move the player from `(400,300)` to `(460,300)`, set clock 9.5, step: lines 0-1 shift by
   exactly +60 in x, so each `origin == new_center + center_offset` and `a/b` also shift by +60;
   lines 2-3 are unchanged; `aimed == 1`.
6. Move the player to `(340,300)`, set clock 11.5, step: lines 2-3 shift by -120 from their
   spawn geometry to `new_center + center_offset`; lines 0-1 stay at the 460 center; `aimed == 2`.
7. Move the player again at clock 11.8 and step: both volleys are byte-identical to the previous
   snapshot (one-shot aim).
8. A fixture created at clock 9.8 whose first warning is 9.5 keeps its spawn geometry after the
   player moves and the clock advances (already-warning volley never moves).
9. A cube hazard (`configure_cube`) never changes geometry, has `tracking.clusters == 0`, and its
   two lines keep the authored X/plus geometry.
10. A two-volley formation configures exactly one hazard node containing all four lines; stepping
    through both volleys never spawns a child hazard.

### 8.2 Updated: full-song coverage `tests/full_song_coverage_test.gd`

- Baselines 237 / 114 / 123, 36 fixed, 67 formations.
- `build_expected` stores per-formation `volleys`, computed from the chart's damage times with the
  same half-beat rule.
- `spawn_boss_hazard` records `geometry["tracking"]` per hazard. The final checks require:
  - every formation's `tracking.clusters` equals its expected `volleys`;
  - every formation's `tracking.window` is within 0.000001 of `music.seconds_per_beat() * 0.5`;
  - every cube's `tracking.clusters == 0`;
  - `geometry_ok`, no missing hazards, and `hazard_rejected_budget == 0`.
- `hazard_records[key]` gains `volleys`, so the existing report's
  `hazard_geometry_records` exposes them; no schema version change.

### 8.3 Other baseline tests

Update the six files listed in §6.2. Their assertions stay semantically identical; only the chart
counts and labels change. `full_song_transport_test` still proves the 245 ms offset is applied
exactly once and that the first heavy is beat 73.

### 8.4 Existing tests that must keep passing unchanged

`combat_timing_test`, `friend_controls_test`, `main_authored_boss_test`, `main_boss_runtime_test`,
`boss_blink_test`, `boss_parry_test`, `boss_duel_runtime_test`, `boss_navigation_test`,
`room_geometry_test`, `room_transition_test`, `chapter_integration_test`, `parry_integration_test`,
`hit_vfx_contract_test`, `impact_feedback_test`, `audio_calibration_test`, `boss_room_test`,
`heavy_lane_test`, `heavy_judge_test` (baseline only), and `source-chart`.

## 9. Verification

1. Focused data/contract checks:
   `source-chart`, `full_song_transport_test`, `full_song_offset_test`,
   `full_song_boss_test`, `full_song_coverage_test`, `main_full_song_test`, `heavy_judge_test`,
   `laser_tracking_test`.
2. `tools/verify_main.ps1` full suite; every check must print `0 failed` with no `SCRIPT ERROR`,
   `ERROR`, `FAIL `, leaked nodes, or timeout.
3. `-LocalScore` real-OGG subset: `full_song_transport_test`, `full_song_boss_test`,
   `full_song_coverage_test`, `full_song_offset_test`, `main_full_song_test`,
   `audio_calibration_test`, `boss_room_test`, `laser_tracking_test`, `source-chart`.
4. Coverage report evidence: 67 formation hazards, zero missing hazards, zero
   `hazard_rejected_budget`, `skip_reasons["laser_line"] == 0`, wall time < 60 s, peak live hazards
   printed. If the reference density trips the 24-hazard cap, investigate hazard lifetime and
   dispatch; do not raise the cap or relax the test.
5. New `tools/capture_laser_volley.gd` (static, no input replay) writes:
   - `artifacts/laser-volley/volley-warning.png` — the real formation-0 diamond volley in its
     warning state around the player;
   - `artifacts/laser-volley/volley-fire.png` — the same volley firing;
   - `artifacts/laser-volley/volley-reaim.png` — a second volley after the player moved, showing
     the cross re-centered on the new position.
   Inspect all three images; they are validation evidence only and stay ignored.
6. Run `tools/capture_boss_redhair.gd --idle-only` to confirm the Boss-room presentation did not
   regress.

Not covered by headless verification, and must be stated as such in the report: interactive
keyboard/gamepad dodging, long play sessions, subjective beat-feel, and real-device calibration.
The user performs those.

## 10. Risks and mitigations

| Risk | Mitigation |
|---|---|
| Replacing the chart shifts gate/calibration behavior | Calibration samples are verified identical; section beats and offset are unchanged; transport/offset/coverage tests pin the counts and timing. |
| More formations/cubes trip the 24-hazard cap | Coverage test fails on any budget rejection or missing hazard; investigate lifetime/dispatch, never widen the gate. |
| A warning visibly jumps to a new position | Clusters already warning at creation are `aimed` immediately; future clusters aim before their first draw; one-shot `aimed` prevents later motion. Covered by test 8. |
| Re-aim changes damage unexpectedly | Only `origin/a/b` change; timings and thickness are untouched; damage still runs through the existing `line_hits_player`. |
| Re-aim causes line loss or duplicate hazards | Geometry-only update inside the existing hazard; line count and `_hits` keys are stable; test 10 and coverage assert one hazard and full line counts. |
| Tracking makes the fight unfair | Each volley keeps its full chart warning lead (the first reference volley has 1.18 s) and locks at warning start, so movement after the warning is a valid dodge and the beams do not chase. |
| Chart replacement breaks hardcoded baselines | The timeline hash, the audit dictionary, and all six test baselines are updated in the same change; `source-chart` is the first gate. |
| Committing unrelated in-progress work | Only feature-owned, clean files are committed (chart, timeline, docs, clean tests/tools, new files). `main.gd`, `combat/boss.gd`, `combat/boss_hazard.gd` and `tools/verify_main.ps1` already carry other uncommitted work and stay in the working tree; they are reported, never reverted. |
| Private reference data leaks | Only the chart JSON is copied; the `IF_story(1)` tree, OGG, renders, logs, and paths are never staged. |

## 11. Acceptance criteria

1. `boss_attack/data/if_infinity.chart.json` is byte-identical to the reference chart
   (`5caa2721292be473c7d8ca760c8948d1aab43b42fc82a80fb02e352369aebe5f`, 59615 bytes), and the timeline hash matches; the OGG is untouched.
2. The parser reports 1703 notes / 1702 timed / 121 heavy / 331 long / 36 cubes / 259 ordinary /
   67 formations / 237 phrases (114 basic, 123 fast) / 17 phases / end 409.530714285714 s.
3. Calibration still selects 40.7376, 41.1810, 41.6243, 42.0677, 42.5110 s.
4. Each formation still spawns exactly one hazard with all its source lines.
5. The 67 formations split into 176 half-beat volleys (max 4 per formation). Every volley is
   centered on the player at its warning start: the first volley at spawn (that instant), later
   volleys by exactly one re-aim on `get_laser_arena().get_center()`. Earlier volleys and
   already-visible warnings never move, and cubes never track.
6. The replacement chart fires four simultaneous beams at 88.028 s (diamond), then 90.393
   (parallel), 92.757 (grid) and 95.122 s (rotating).
7. Full suite and the real-OGG subset pass with `0 failed`; coverage reports no missing hazards,
   no budget rejections, no stale laser-line skips, and < 60 s wall time.
8. Heavy clash, parry, guard, damage, fade, rooms, camera, and calibration UI are unchanged.
9. The three capture images show the simultaneous volley and the re-centered second volley.

## 12. File-by-file change list

New:

- `tests/laser_tracking_test.gd`
- `tools/capture_laser_volley.gd`

Data/docs:

- `boss_attack/data/if_infinity.chart.json` — reference bytes.
- `data/full_song_timeline.json` — chart SHA256.
- `docs/full-song-runtime.md` — counts and tracking rule.
- `docs/friend-boss-main-integration.md`, `docs/friend-handoff-compatibility.md` — appended
  replacement note.

Production:

- `combat/friend_rhythm/laser_formation_planner.gd` — `center_offset`.
- `combat/boss_hazard.gd` — clusters, one-shot re-aim, tracking snapshot.
- `combat/boss.gd` — cached arena, half-beat window, `LASER_TRACK_HALF_BEAT`.

Tests/tools:

- `tools/audit_friend_chart.gd` — expected dictionary.
- `tools/verify_main.ps1` — register `laser_tracking_test`.
- `tests/full_song_coverage_test.gd` — baselines, volley oracle, tracking gate.
- `tests/full_song_boss_test.gd`, `tests/full_song_offset_test.gd`,
  `tests/full_song_transport_test.gd`, `tests/heavy_judge_test.gd`,
  `tests/main_full_song_test.gd` — baselines.

Untouched:

- `audio/*`, the existing draw/SFX code inside `combat/boss_hazard.gd`, `combat/projectile.gd`,
  `combat/audio_calibration.gd`, `ui/calibration_overlay.gd`, `levels/boss_room.gd`,
  `main.gd` behavior, chapter/story files, `data/authored_boss_moves.json`.

## 13. Implementation order

1. Chart replacement, timeline hash, audit dictionary, the five non-coverage test baselines, and
   docs. Gate: `source-chart`, `full_song_transport_test`, `full_song_offset_test`,
   `heavy_judge_test`, `main_full_song_test`, `full_song_boss_test`.
2. Failing planner test, then `center_offset`.
3. Failing hazard tests (clusters, one-shot aim, warning immobility, cube exclusion), then the
   hazard tracking implementation and snapshot field.
4. Boss wiring (half-beat + cached arena), the coverage baselines, and the volley oracle; run
   `full_song_coverage_test` as the density gate.
5. Capture tool and image review.
6. `-LocalScore` subset, full suite, report with explicitly untested manual paths.

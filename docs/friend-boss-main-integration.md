# Friend final Boss integration in the main game

Status: connected to the main `combat/boss.gd` and `combat/boss_hazard.gd`. The main entry remains `play.cmd` / `main.tscn`. No second game, audio clock, player or damage authority is created.

## Source, licensing and placeholder score

- MIT logic comes from friend [PR1](https://github.com/yosemitezz/AIgame-by-ncu/pull/1), author zjuan-ctrl, and final [PR3](https://github.com/yosemitezz/AIgame-by-ncu/pull/3), head `fff7526a3dc687c9625dece860a79695c00db8d0`. PR2 is contained in PR3, so there is one final four-normal/four-fast pool. Source headers and `third_party/friend-boss-pr1/LICENSE` preserve attribution. The original `boss_attack` subproject and its source files remain untouched.
- `data/main_boss_chart.json` is a newly authored, redistributable short test score: fixed 8, random 16, final 16 beats at the existing placeholder tempo 112. No private source notes, audio or metadata were copied. `data/authored_boss_moves.json` retains the MIT source action timings/cycles and separately marks the main adaptation.
- The lead verified that the newly attached source chart is byte-identical to the pre-existing source chart (SHA256 `133082afb6234f693576d78db4c228fcb882a6027049df3dd687e0f198df3b27`). It adds no new schema semantics. This integration did not read, copy, execute or upload its recording or private chart.

## Actual execution

The source `ChartParser` derives equal-spacing pairs and basic/fast action phrases, same-time long-note cube triggers, and four-line ordinary laser formations. Main Boss consumes the versioned `BattleDirector` schedule. Random section phrases select the four normal source plans; final section phrases select the four fast plans. Each actual aim, reposition, dash, ring, fan and side-spray action is executed by the main Boss; vectors from the source projectile math go through the existing main projectile/reflection/cap path.

Fixed section starts source cube cues at beats0 and2. At each launch a random orientation is chosen and locked for that carrier: a0-degree square fires45/135-degree X lines; a45-degree diamond fires0/90-degree plus lines. Target lanes, flight2beats, warning2beats, thickness10 and hold0.9s remain configurable. This replaces the old generic fixed random-pool scheduler; it does not add a melee merely to satisfy the old beat 4 fixture.

Final phrases also run actual diamond/parallel/grid/rotating source formations. `boss_hazard.gd` clips the original infinite lines to the visible Boss arena and uses those same endpoints/widths for warning, active rendering and the actual14x26 player body test. Each line records one successful damage instance, all lines in a formation share latest-end+0.7s, and occurrence-based safe-center changes carry across loops. Geometry tests sample reachable grounded safe positions. Coral lines are not projectile reflections.

The source aim/dash targets are locked when a plan is prepared. Upcoming phrases get0.8beat of visible path preparation where needed; the first normal/final plan already starts with its own aim. Main sidescroller reposition/dash keeps floor height while executing source horizontal destinations. At a four-beat boundary, a previous plan's ring atbeat 4 is consumed before the next plan's teleport atbeat 0. The queue is bounded and discards damage cues older than0.20s rather than bursting stale attacks after a stalled frame.

## Preserved gameplay contracts

MusicDirector alone owns latency-compensated time and phases. Fixed starts come from `beat`; sub-beat source actions and hazards only read `music.get_score_time()`. Boss-local impact freeze holds its real presentation/reaction clock while music continues. There is no Engine.time_scale write and no source AudioStreamPlayer.

Boss 48 HP and main contact damage 1 are retained. Fixed/random health is sealed at the existing threshold; random loops until that threshold queues the next full phrase boundary. Rest disables damage in both directions, invalidates all future action versions, cancels melee/dashes/reactions, and clears old projectile/hazard geometry. Defeat clears attacks and callbacks once. The source document's100HP/3200Boss/damage 6 and replacement controls are not imported.

Authored dashes reuse `_try_melee_contact`, the same front-facing contact, unique source/token guards and Player acceptance callback. `charge_dash_ring` is explicitly an armored unparryable coral charge; `fan_then_dash` uses ordinary interruptible contact; the other source dash patterns use parryable armor. Ordinary success cancels pending source actions and hazards, armor retains later segments, and the third posture contact opens the existing break/recovery window. Missing music beats and heavy notes never deduct health or replace contact parry.

## Final handoff versus PR code

| Item | Source code / final handoff | Main adaptation |
| --- | --- | --- |
| Timing group | Exact original three-component beat key | Preserved; `[73,0,4]` and `[73,0,2]` stay distinct |
| Fixed cube grouping | PR code grouped beat key; final handoff requires same event time | Uses absolute1e-6-second tolerance; all qualifying long records leave ordinary laser pool; coincident ordinary notes remain |
| Fast boundary | PR code1.01; final recommendation1.1beats | Parser default1.1; different phases or pair intervals never combine; source combination does not add a boundary-adjacency restriction |
| Last accelerated pair | Final handoff permits explicit basic fallback | Retains a two-note basic phrase |
| Cube flag | Old source naming/drawing was inconsistent | `diamond=true` physically means45-degree diamond/plus; false means0-degree square/X; snapshot includes orientation degrees |
| Offset units | Parser seconds = beat*60/BPM + offset_ms/1000 | Positive offset delays cues; placeholder offset0. Metadata/audio records are ignored |
| Column | Source1+2+3 marks heavy metadata; endbeat marks a laser | Not one bullet per note/column; action phrases and formations drive gameplay |
| Rest | Handoff ordinary rest could retain lasers | Existing main narrative rest takes priority: all old attacks become harmless |
| View/controls | Handoff suggests another640x360/top-down shell | Existing800x450 side view and current controls remain |
| Heavy judgement | Suggested HUD lead/125ms window; rewards unresolved | No imported heavy input, miss damage or perfect-parry replacement |

## Interfaces and evidence

`Boss.get_authored_status()` returns section/pattern/serial/queued_actions/dash_active/cycle/hazard_generation/pattern_count/action_count and a bounded trace. `get_presentation_pose()` returns state/progress/strike/armored/contact_serial from actual stages; active release takes priority over ordinary hurt. `get_warning_geometry()` deep-copies locked path geometry. Hazards join `boss_hazards` and expose `get_geometry_snapshot()` with clipped records and immutable launch orientation.

Main API: four-argument `spawn_projectile` with null at 180 cap, Projectile.lifetime, `spawn_boss_hazard` with 24 cap and `clear_boss_hazards`. Source actions consume capped/refused spawn attempts rather than retrying every frame. Root owns main/player/projectile/music files; this module does not modify them.

Validation uses bounded headless logic and real main runtime fixtures, never a playthrough, source recording or video. Actually read skills: `godot-gdscript-headless-testing`, `godot-audio`, `game-feel`. Existing music contract30/30 passes after connection. `main_authored_boss_test.gd` additionally checks source plans, parser handoff edge cases, source geometry, shared render/contact records, safe samples, generation cancellation and finite queues. The independent main runtime test owns real scene action/contact/clear verification.


Final bounded verification:

| Check | Result |
| --- | --- |
| `main_authored_boss_test.gd` source plans/handoff/geometry | 86 passed, 0 failed |
| Independent `main_boss_runtime_test.gd` actual main scene | 62 passed, 0 failed, including post-victory death pose |
| Existing `music_contract_test.gd` | 30 passed, 0 failed |
| Lead read-only source-chart audit | 14 passed, 0 failed; dynamically 228 phrases = 141 basic + 87 fast; 230 raw endbeat records / 182 ordinary lasers |

These runs have explicit process exit and error-log checks. No private source data is included in the main runtime configuration. The legacy parry suite's old fixed-beat 4 generic-slash fixture must be updated to the new fixed cube schedule; the actual contact/recoil/armor assertions passed and main runtime coverage verifies the replacement schedule. The parser retains source same-phase/equal-pair-interval combination without adding an unrequested pair-boundary adjacency rule. Counts are recomputed from data rather than hardcoded.

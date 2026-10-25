# Full-song runtime

The main encounter uses the already committed selected OGG at `res://boss_attack/audio/if_infinity.ogg`; it is byte-identical to the user-selected recording. No duplicate audio is added. See THIRD_PARTY_NOTICES.md for the recording's separate attribution and license scope.

`data/full_song_timeline.json` explicitly sets 203 BPM and +245 ms. Chart metadata and its audio-note offset do not override that configuration. The reference source chart contains 1702 timed notes, 121 heavy groups and 237 action phrases, with its last event at 409.530714 seconds. The OGG is approximately 418.515737 seconds long. These matching counts and coverage do not prove subjective listening alignment on a particular sound device.

The macro gameplay gates are configurable adaptations: fixed from the beginning to beat 200; health-gated random from 200 to 264 (eight complete eight-beat phrases); safe rest from 264 to 296; final from 296 through the recording's end. The chosen rest lies in a source-chart gap. An unmet health gate repeats the random segment; meeting it queues the transition at the segment boundary. Narrative rest disables both sides and clears existing attacks. Ordinary chart gaps do not independently award victory. Song completion safely clears the encounter and offers retry if the Boss is still alive.

MusicDirector is the single time authority. Runtime score time remains monotonic while source-chart position can return to the configured random loop start; a new generation invalidates old cues and heavy-mark history. Source timestamps already include the configured offset and are mapped to runtime action timestamps once. Audio sampling uses playback position with mix/output-latency compensation. Player/Boss local hit-stop never changes the music clock.

The left heavy lane previews each heavy group two seconds before its timestamp. Pressing left Shift within ±125 ms produces an independent cosmetic result for every matching group. It does not guarantee a combat parry: actual contact and the existing combat window still determine defense. Misses cause no damage. Input timestamps refresh the same latency-compensated MusicDirector sample before judging; they do not reuse a stale render-frame timestamp. Holding Shift or OS key-repeat does not create extra presses. The lane hides during map/pause and clears stale history on restart or transport generation changes.

`BELLKEEP_USE_PLACEHOLDER=1` selects the original generated score for development fixtures. `tools/verify_main.ps1` scopes and restores this setting by default; `-LocalScore` allows the shipping full-score selection. An optional ignored `.local/local_score.json` can supply a `local_full_song` wrapper with `timeline_path` and `audio_path` for local experimentation. No local absolute path is required by the public default.

Still outside this milestone: the unspecified second fixed attack, extra weapons, final narrative sequence and subsequent melee/mobility tuning. No full playthrough or exported package is implied by bounded automated checks.

## Barrage accounting and cancellation contract

Each source phrase keeps its original normal/fast classification in every macro phase. Contact recoil cancels that melee sequence; independent ring, fan, side-spray, fixed-cube and laser plans keep their own absolute timestamps. Actor-local hit-stop does not stop their music cursor. Narrative rest, encounter teardown and transport generation changes clear old danger. Expired catch-up actions, insufficient catch-up warnings and capacity refusals are reported separately, rather than silently counted as successful emissions.

The deterministic coverage fixture advances the actual main Boss, Projectile and BossHazard implementations over the full recording in virtual 60 Hz steps. It does not play through the level, simulate player inputs or wait for the recording in real time. Its no-interruption accounting expects:

| Source pattern | Phrases | Projectile emissions |
| --- | ---: | ---: |
| normal 1: charge / dash / ring | 29 | 232 |
| normal 2: side sweep / spray | 29 | 522 |
| normal 3: fan / dash | 28 | 84 |
| normal 4: dash / double ring | 28 | 448 |
| fast 1 | 31 | 496 |
| fast 2 | 31 | 372 |
| fast 3: two dashes | 31 | 0 |
| fast 4 | 30 | 840 |
| Total | 237 | 2994 |

Additional source geometry comprises 36 fixed cubes and 67 laser formations. Fixed-cube orientation is seeded in the test only; the live encounter retains its configured random X/+ choice. The undefined fixed_2 slot remains empty.

Laser formations fire beat-clustered volleys: source lines whose damage times fall within half a beat (`0.5 * 60 / 203` s) fire together, and each volley re-centers once on the player's arena center at the start of its own warning. A warning already visible when the hazard is created never moves, and cubes never track.
## Verified milestone

The selected-source validation copy uses committed baseline `b73ab5210a67b02b1c9e53291e050f97fb5a4e8c` plus only this milestone's files. Concurrent uncommitted hero/recoil/smear work is preserved outside the commit and is not part of these results.

The full-song emission accounting matches all 237 phrases, all 922 distinct actions, all 2994 requested/successful projectiles, all 36 fixed cubes and all 67 laser formations. The deterministic seed yields 18 X and 18 + cubes; the four laser geometries appear 17 diamond, 17 parallel, 17 grid and 16 rotating times. Peak live objects are 46/180 projectiles and 6/24 hazards, with no budget rejection, duplicate or missing event. Rest deliberately clears nine already-emitted projectiles; EOF leaves no live danger. The 147.783ms source-warning regression is retained: an on-time short warning must not be mistaken for a stale catch-up event.

Checks cover source parsing, complete event accounting, heavy-marker bounds/glyphs/input, real main-scene wiring, repeat/EOF and pause behavior, source rewind overshoot, delayed seek acknowledgment, input arriving before the render update, contact-parry compatibility and startup. Tests use the Dummy audio device and injected real-backend sample values; they decode the actual selected OGG but do not claim a full listening/device-latency or difficulty acceptance test. The editor's warning that the retained `boss_attack` folder contains another project is expected; no runtime script errors or leaked-object warnings are accepted.

Run `tools/verify_main.ps1` with the full-song checks, or inspect the generated `artifacts/full-song-coverage.json` and `artifacts/unified-*-console.log` files. No export, recording or automated level playthrough was produced for this milestone.
Final selected-source results: 18 named checks including import-independent startup; 625 assertions passed, zero failed. The focused full-song checks are transport 38, Boss 28, continuous emission accounting 24, actual main scene 25, heavy judge 35 and heavy lane 62. Independent final review reported no remaining findings. The local coldbrew-builder workflow was used; implementation, heavy feedback/UI and independent review had separate file ownership.

# Boss duel milestone

Built on integrate/vfx-primary at 797978f, including the concurrently committed player shadow, smear and hit-recoil work. This change preserves the side-scrolling dungeon, player controls, selected recording and friend-authored source schedule.

## Combat and movement

- Normal/fast source dashes now use physical travel and blade contact. Side reposition and center moves travel through collisions instead of assigning a distant position. Normal targets lock at phrase start; fast_3 locks again only at its specified second aim.
- During a source gap of at least 1.65 seconds, beat-led close combat adds draw, first cut, retreat, second draw/cut and recovery. New contacts have separate tokens and telemetry. A source phrase preempts the extra sequence while keeping its own event times.
- Pursuit is 188 logical pixels/second with a 58-pixel stopping distance. Close-combat selection uses 105 pixels horizontally and 30 vertically. Draw is 0.32 seconds; cuts are 0.22 seconds each, retreat 0.16, second draw 0.18 and recovery 0.28. These are original adaptation values, not measurements from a commercial reference.
- Jump launch is 460 pixels/second at gravity 950, with a 104-pixel rise and 180-pixel horizontal planning limit. Actual collider travel and landing checks govern movement. The original 290-pixel launch only reached about 44 pixels, below the lowest 48-pixel shelf.
- The real arena has continuous floor y=300, side shelves y=252 and upper shelf y=210. A planned head arc rejects solid walls/ceilings; one-way shelves remain passable from below. Locked landing warnings and recovery precede re-entry.
- Ordinary parries cancel the current contact sequence and open the existing recoil/recovery window. Armored cuts retain their next contact and accumulate posture; three accepted contacts break guard. Contact identity prevents repeat rewards. Local impact pauses never set Engine.time_scale or replace the music clock.

## Pixel presentation and damage

The native 128x128 frame and feet anchor (48,116) are unchanged. The atlas grows from 62/15 to 78 frames/19 states, adding retreat, jump, slam and land. The two cuts now use distinct whole-body anticipation, sweep and follow-through. Cut frames 0 and 3 are non-damaging; frames 1 and 2 are active. Slam uses its own blade progress rather than the entire flight progress.

Damage and the restrained one-pixel edge read the same feet-local guard/tip landmarks, including facing. Moving-segment tests cover between-frame sweeps; wall queries block contact through solids. Cancellation, transport changes, safety, pause and local freeze reset sweep history. Long frame gaps do not create a giant compensation hit.

## Source preservation

The 203 BPM/+245ms clock and original normal/fast timestamps remain authoritative. Extra melee does not remove rings, fans, sprays, fixed cubes or laser formations. fixed_2 remains explicitly empty. Encounter death, narrative rest and transport reset are global cleanup boundaries; a contact parry is not.

Full-song physical emission regression at virtual 60Hz keeps these source counts:

| Plan | Projectiles |
| --- | ---: |
| charge_dash_ring | 288 |
| side_sweep_spray | 630 |
| fan_then_dash | 105 |
| dash_double_ring | 560 |
| fast_1 | 352 |
| fast_2 | 264 |
| fast_3 | 0 (two locked dashes by design) |
| fast_4 | 588 |
| Total | 2787 |

The other baseline totals are 228 phrases, 862 actions, 24 fixed cubes and 48 laser formations. Final run evidence is recorded below; a virtual timeline regression is not a seven-minute playthrough or listening approval.

## Workflow and verification

Actual skills used: coldbrew-builder, godot-animation, godot-2d-movement, godot-physics and godot-gdscript-headless-testing. Applicable rules: one animation authority, physics-step kinematic movement, explicit collision queries and bounded tests with nonzero failure exits plus both output streams.

Separate owners implement Boss runtime, shared geometry, pixel poses and terrain tests; independent review is read-only. Only the selected files enter the validated snapshot and commit. No hero/general VFX, map, music asset, default branch or other worktree is modified by this milestone. The pixel contact sheet was visually inspected; final feel and challenge remain for the user to play.

## Verified result

All 33 named verification checks passed on the selected-source copy of 797978f plus this milestone, including the short startup. Focused results: shared geometry 38, duel runtime 21, real-terrain navigation 52, pixel mapping 38, main visual integration 103, main Boss integration 77, and full-song emission accounting 26; zero failed. The old main Boss fixture was updated to wait for actual active blade frames, preserving its unblockable, ordinary-parry, armor, guard-break and victory-safety assertions.

The full-source fixture executed 44 extra melee decisions with the system enabled while preserving all 228/862/2787/24/48 source totals. Peak live objects were 46 of 180 projectiles and 6 of 24 hazards; no missing/duplicate event or capacity rejection. The fixture protects the player to isolate emissions, so its zero accepted-HP extra_hits is not a damage acceptance result; the separate physical leap/contact fixtures verify damage.

Independent final review reported no remaining findings. It identified a real navigation issue with overhead platforms; separate near-feet and target-layer probes now handle upward and downward pursuit. Temporary collision exceptions apply only to the departure one-way platform and clear on landing or cancellation. A stationary-target leap regression also verified the 36-pixel landing offset needed to align the visible forward blade.

Local evidence: artifacts/boss-duel-final/full-song-coverage.json, the unified check logs and boss-duel-contact-2x.png. Main play entry remains play.cmd. No playthrough, long recording, export, complete listening test or subjective difficulty approval was performed. fixed_2, new weapons and unfinished story work remain outside this milestone.

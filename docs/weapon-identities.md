# Three weapon identities — local milestone

Baseline: main a8b1bcc8aab620ae3ec2a50e34cd806e78e65c01. Branch: feat/weapon-identities-local-20261024. This revision is local only; it does not authorize future main publication. Entry remains the root play.cmd.

## Controls and moves

J attacks; a fresh press queues the next strike, including during actor-local hit stop. Q cycles forward, K backward, 1/2/3 select light/heavy/two-handed. Switching waits for the current strike, resets the old weapon's chain, and retains the queued attack. Left Shift guards; double-tap a WASD direction to evade. These keys are unchanged.

| Sword | Combo | Effective geometry and action |
| --- | --- | --- |
| Light | 1 / 2 | Point-led narrow thrust and advancing stab, maximum forward reach 180 / 204px and half-height 12 / 14px. |
| Light | 3 | Committed spiral advance, 228px maximum thrust reach, 20px half-height; .11s anticipation / .32s active / .23s recovery. Ground speed560px/s; 60Hz fixture travel177.74px, air152.15px with gravity retained. |
| Heavy | 1 / 2 / 3 | Descending cleave, rising return, overhead execution; reach168 / 184 / 206px. Anticipation.12/.14/.20s; active.12/.13/.17s; recovery.22/.24/.32s. Only third contact releases energy. |
| Two-handed | 1 / 2 / 3 | Opposed full revolutions with feet pivot, torso turn and rear sword path; horizontal radii236 / 256 / 280px, vertical78 / 88 / 104px. Active.20/.22/.26s. Front and back contacts are real, walls still occlude. |

All active stages have eight authored pixel frames, with separate ground/air poses, four anticipation/recovery frames, the existing knight costume and stable feet anchor(66,108) on144x128 cells. See docs/weapon-motion.md and the ignored contact sheets for actual pose evidence.

## Damage and ownership

- AttackProfile supplies weapon kind, angle/extension keys, timing, active-frame mapping and visible primary geometry. Main owns one damage ledger per actor/attack serial. A drill does **one hit per target per attack**, independent of frame rate; no continuous damage ticks and no extra invincibility.
- Thrust collision includes the interval between prior and current attack positions. A grounded auto-advance checks floor ahead; body collision stops at walls, and recovery brakes the committed speed. Deliberate airborne moves retain gravity. The existing freely repeatable air jump feature is preserved.
- A sword wave has an independent source serial, immutable damage/direction, target ledger and pausable lifetime. Its body12x58px sweeps terrain before target contacts, speed640px/s, lifetime.65s(max416px travel), damage2, maximum3live. It does not consume the180hostile-shot budget, so it cannot suppress friend-authored barrages. A later equipment swap does not alter released energy. An already invulnerable target may reject it; a rejected contact is not retried on every overlapping frame.
- Before the first forward contact pose, cancelling heavy3 emits no energy. Repeated release calls cannot duplicate it. Rest, death, room transfer and retry clear it; pause freezes its motion and lifetime.
- Accepted hits alone trigger the existing single impact service: actor-local player holds are light40ms / heavy81ms / two-handed112ms for a regular strike, with weapon-specific capped directional camera kicks and short synthesized sounds. Empty swings may whoosh but do not shake, zoom or freeze. The wave holds the target, not an unrelated later player swing. No Engine.time_scale or music-clock changes.

## Collaboration and validation

Controller owns player/profile/melee geometry/data and its focused test; motion owns the original joint rig, generated hero sheets/renderer and shared VFX; lead owns wave, root integration, feedback, documentation/Git; reviewer is read-only. Existing user knight/weapon history, all map/portal/Boss logic, friend score, selected music and main history remain intact.

Skills actually applied: coldbrew-core/builder; Godot2Dmovement/physics; Godotanimation; game-feel; GodotGDScriptheadless-testing; independent source review. Tests use explicit failure exit codes and bounded processes, D-drive caches/logs. No playthrough, repeated demo or recording.

The four old fixtures were adapted only where the requested design changes their specification: light no longer overhead-cleaves; active sprites now8frames; great now reaches behind; light3 duration/lunge differs; direct mid-strike equipment changes defer. Old sheet/feedback byte hashes were replaced by resource-grid/anchor/API invariants. Damage ledgers, collision walls, input maps, music safety and room lifecycle assertions remain.

Evidence lives in artifacts/weapon-identity-controller.json, weapon-motion/, weapon-*-console.log and the final milestone manifest. Automated geometry/state tests and static frame review do not establish subjective combat feel, real speaker latency or difficulty. The player performs that acceptance.
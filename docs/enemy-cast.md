# Enemy cast: six distinct readable opponents

This Stage3 changes only `actors/enemy.gd`, the `ENEMIES` roster in `levels/bellkeep.gd`, this document and the new cast fixture. Root retains damage acceptance, projectile collision/core styles, music, VFX and Boss logic. Presentation is supplied independently as80x80 cells with feet anchor40,76. No new story, weapon system or Boss behavior is added.

## Identity and finite casts

| kind | Health | Behavior |
|---|---:|---|
| sentry |3|Bone guard:0.52s tell,48px front blade,0.12s contact window and0.42s recovery |
| wisp |2|Water-seed spirit:0.66s tell; one aimed seed then two side beads at0.28s,3 total |
| elite |9|The existing progression guard:0.58s tell,72px heavy slash; below half health adds one3-shot slow rune fan |
| lantern |4|Lantern monk:0.72s tell; four rays at -54/-28/28/54 degrees, then -60/-34/34/60 at0.34s; the center remains open |
| jailer |6|Chain jailer:0.68s directional tell,92px single parryable sweep,0.12s contact window,0.62s recovery |
| bat |2|Winged imp:0.55s tell; one75px/s head seed, then four140px/s petals after0.30s if the seed is still valid and hostile |

Angles are relative to the locked aim. Aim and facing lock at cast start instead of following the player during a tell. Melee checks real current contact during its short window and resolves once per attack_serial. Accepted parries supply the real blade contact/token and cause recoil; an invisible missed beat never deals damage. Existing receive_hit/react/knockback/stun/launch behavior, flash, death callback and elite identity remain. Both wisps and bats float instead of acquiring ground gravity.

The11 authored positions remain distributed through the nave, crypt and library: sentry390, lantern748, wisp1080, bat1512, sentry1630, elite2240 on the original deck; lantern760/wisp1100/jailer1556 below; jailer1480/bat1304 in the library. Every entry now has explicit patrol bounds. There is still exactly one kind=elite for gate progression, not several renamed elites.

## Safety and budgets

Every cast start and release rechecks target life, story safety, pause/outcome, source visibility, distance360px, patrol bounds,120px home-height band, spatial room identity and an unobstructed world-layer1 chest ray. The camera visibility rectangle includes a96px margin. Walkers retain floor-ahead checks; no map-wide pursuit or cross-floor firing is introduced.

The root global cap remains180 projectiles and rejects the181st. Source hostile caps are wisp6, lantern12, bat6 and elite8. A returned shot receives stable enemy_source_id metadata and a2.4s lifetime. Rejected root spawns and rejected source-budget attempts still consume their finite layer; no retry loop can trap a cast. Reflected friendly shots are excluded from hostile source budgets and never evicted or cleared by the enemy.

A WeakRef director lane is shared by blocking casts: lantern fan, bat bloom, jailer sweep and low-health elite fan. At most one owns it; other blocking casters wait. The bounded lease covers windup/release and the2.4s shot lifetime, with a3.8s maximum measured only in unpaused physics delta. Pause/menu time never expires a live lease or clears a volley; there is no wall-clock deadline. Normal recovery releases when its shots are gone. Damage reactions, death, rest, leaving the visible room or exiting the tree cancel pending layers, clear only that source's hostile shots and release ownership. An exhausted lease, freed/queued/dead/offscreen owner, or an owner with neither a cast nor hostile shots cannot keep the lane permanently. No global time scale or music clock is changed.

Bat bloom retains a weak reference to its head. A reflected, wall-cleared or freed head does not produce children. A surviving hostile head is cleared before four children are attempted. Bloom is also suppressed if the player is within52px of its opening point. Rest or source interruption cancels the pending bloom; friendly reflected heads survive.

## Presentation contract

Public fields: kind, facing, attack_serial, animation_state, frame, cast_phase and cast_progress. States idle/run/windup/attack/recover/hurt/dead use four samples; bat/wisp run means flying displacement. cast_phase is none/windup/release/recover, and progress follows actual elapsed stage time. Hurt/dead override cast presentation. Warnings use mob_sentry/mob_wisp/mob_elite/mob_lantern/mob_jailer/mob_bat with actual facing and windup duration. Collision cores remain separate from decorative wings, lanterns and chain ends.

The controller emits existing-style wisp_seed/elite_rune and new lantern_fan/bat_seed/bat_bloom names. Root owns style admission and projectile core/tail drawing. No damage is applied by these visual events. Jailer contact uses the existing enemy_slash visual hook and real horizontal blade segment rather than spawning a damaging decorative chain.

## Verification

`tests/main_enemy_cast_test.gd` runs bounded FSM and physics-query fixtures, not a level playthrough. It checks all six reactions/health configs, exactly11 distributed entries and one elite, real stage-driven frame values, finite delayed layers and central fan gaps, bat reflection/wall cancellation, single-token melee, source limits,181st rejection, room/patrol/LOS/offscreen gates, interruption/death/stale lease cleanup and story-rest cancellation. Initial cast result:78 passed,0 failed. A separate pause/resume fixture passes arbitrary large menu-time values through the isolated lease seam while frozen, verifies unchanged cast/serial/source count, then resumes the delayed fan and releases the director only through active physics expiry; no real sleep is used. Evidence is the ignored `artifacts/main_enemy_cast_test.log`; the isolated enemy parse log is `artifacts/main-enemy-parse.log`.

The local game-ai skill was applied to separate finite decisions, movement and cast state. Existing contact/parry regression is also run before handoff. Human difficulty and visual-readability playtesting remains with the user; no manual game session or input bot was used here.

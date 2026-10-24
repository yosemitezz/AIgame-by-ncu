# Main project consolidation

Selected branch: integrate/vfx-primary. Baseline d6133d9586a5a175410f25fceb2384f264defb22 includes the new longer hero, unlimited air jumps, light wings, angular FX, heavy camera punch and layered original impact sounds. These remain in this project. The dungeon and interfaces are selectively migrated from e895c4477237c47ad14ed75ed7a7a8b4460c38fd; its older hero atlas, movement, impact sound and FX implementations do not replace the new baseline.

Milestone 1 moves the flooded crypt, archive, chain shafts, doors, shortcut and spatially triggered checkpoint into the real main scene. Native viewport 800x450, window 1600x900, nearest filtering and integer scaling; map and pause use the same state. Space jumps, W/up climbs, S/down climbs or crouches away from chains, E interacts, Tab shows the map. J/K/Shift keep combat input. Main damage ledger is the only per-swing authority; dynamic arc queries and visible primary sword envelope share a profile. Each milestone is validated and committed separately.

Milestone 2 connects the final friend PR3 action planner, paired/accelerating groups, cube X/+ and laser geometry to the actual Boss. PR2 is already contained in PR3 and is not run as a third duplicate system. Original subproject files and user work remain intact. Its commercial song and song chart are not copied or changed; runtime uses the existing redistributable generated score and an original configurable timeline. Source details and remaining slots are documented with the integration.

Milestone 3 updates and expands the dungeon enemy cast with distinct pixel silhouettes, animation and readable bounded barrages. Story identities, final dialogue and forced rescue are not set by this migration.

Validation evidence is kept in ignored artifacts on D, not committed. The user plays; checks are bounded scripts/startup and frozen visual frames. main/default branch is unchanged.

## Stage 1 evidence

Import and short startup exit 0. Focused results: dungeon114/0, player50/0, main scene54/0, integration24/0, hit reaction30/0, impact18/0, music30/0, parry controller49/0, Boss parry45/0, parry integration18/0, hero motion42/0, visual migration87/0, font48/0 with no missing glyph. These passed in bounded individual/resumed runs; no route playthrough or subjective acceptance is claimed. Source hero atlas and heavy impact service remain byte-identical to the selected newer baseline. Real regression found and fixed a near elevated enemy miss by extending the shared first-cut contact angle; the initial quarter of the active swing remains harmless. Existing tests now create valid swings, use actual presentation owners, and assert nonempty before cleanup.

A new unassigned ut_hud_test.gd was observed during concurrent work and preserved outside this milestone, without executing or staging it. Friends' PR1/PR3 pure planner test is63/0 but runtime Boss integration is a separate pending milestone. New enemy types, extra weapons and full story are still pending. No export or full-game FPS/latency measurement is claimed.

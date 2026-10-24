# Bellkeep dungeon: three connected decks

This revision owns only the level script and its two layout tests. Root owns player climbing, camera, 800x450 viewport, gameplay gates, persistence and UI. The stable earlier playable checkout and Cursor artwork are untouched. Boss design remains with the user's friend.

## Dimensions and continuity

Native side-view pixel world; upper library floor48, original nave floor300, lower crypt floor500. Player metrics remain180px/s, jump340, gravity900: single-jump apex64.2px and theoretical level-ground range136px. Lower required gaps are80px. The current controller uses72% movement in water; both pools end32px before takeoff edges. Ground acceleration restores full speed within about5px after leaving water, so both required jumps start dry at the normal136px theoretical range. No swim/drowning mechanic is introduced.

Original tutorial, optional ledges, elite gallery, first15 shard coordinates/indices and six enemy positions are retained. Original main-floor top edges remain; some slabs are24px thick to expose the room beneath. The1000..1332 slab is split at1160..1192 for a32px return-chain shaft. The main route stays independently traversable. Boss bounds2660..3330, trigger2640, spawn2990/250, elite gate2580 and fight gates2625/3365 remain unchanged. Ten appended shards and five appended enemies make25 pickups and11 authored encounters.

## Explicit route graph

- Start/tutorial -> original cloister route -> shrine -> elite -> Boss remains available.
- At the first72px gap, entry_chain548 descends into the crypt. Open the iron door676, cross the first shallow pool and80px gap, then choose the library chain1376 or continue through the second pool and gap. The lower lever1712 opens shortcut_hatch1762. Climb to the original shrine approach; this forms a complete parallel return loop rather than a disconnected bonus floor.
- archive_chain1376 and return_chain1176 connect the crypt/nave to a library balcony at48. Its E-operated door and relic shard cluster reward the detour. Either chain returns to the nave or crypt; no required key sits behind its own lock.

Lower slabs: (440,500,512,80), (1032,500,384,80), (1496,500,312,80). Library slabs: (1128,48,32,20), (1192,48,168,20), (1392,48,184,20). The32px holes align with the two library chains. All thin ledges are one-way; floors and interaction doors are solid.

## Stable interaction API

- climb_at(feet) -> dictionary id/kind/rect or empty. Rects represent reachable feet positions and include both endpoints. entry_chain=(536,244,24,256); shrine_chain=(1750,244,24,256); archive_chain=(1364,4,24,496); return_chain=(1164,4,24,496). Existing72px gaps and new32px holes remain physically open. The tops extend44/56px above landing surfaces: an actor starting at rest can move sideways before gravity carries its feet below the lip.
- water_at(feet) -> bool, inclusive surface/floor/end edges. Pools=(700,488,220,12) and(1148,486,236,14).
- try_interact(feet) -> bool opens one nearest closed door/lever within36px. It does not read input. Root calls it on E. interaction_hint(feet) returns a contextual Chinese hint or empty.
- get_opened_ids()/restore_opened_ids(ids)/reset_interactions() expose stable IDs crypt_door, shortcut_hatch, archive_door. Root owns retry metadata. Level alone owns these new door colliders and their displayed state; root still owns the existing elite/Boss gates. Opening is deferred safely through collision-shape state, with no duplicate reward or lock toggle.
- CHECKPOINT_RECT=(1824,240,72,72), WORLD_BOUNDS=(-40,-160,3520,860), FALL_LIMIT=720. Root must use the spatial shrine check, vertical camera follow and the new fall bound. An upper/lower x-coordinate alone does not activate a checkpoint. room_at(feet) distinguishes the library/crypt from legacy x zones.

## Pixel environment

The crypt is filled with1px masonry seams, iron grilles, arches, muted torch clusters, wet wall streaks, low-value rubble and two shallow animated water strips. The library has stepped stone borders, shelves with individually clustered book spines, railings, warm lamps and an original reliquary silhouette. Functional chains have brighter alternating links and anchor plates than background chains. Collision lips retain the old readable gray highlights. All graphics are original flat integer-grid primitives; no3D render or commercial asset is used. These details are replaceable without changing the interaction geometry.

## Source milestone verification

The following tests describe the verified source milestone before selective migration. They are not additional test files copied into the main project; its new standalone runner is documented below.

level_layout_test checks terrain overlap, original shard stability, all pickup support, enemy support, old main-route gaps and unchanged Boss coordinates. dungeon_layout_test starts its graph from the single SPAWN-supporting floor, then traverses jump/fall/climb edges; it does not mark every solid floor reachable. Door fixtures verify actual blocked/clear ray paths, exact36px interaction boundary, stable restore/reset and no duplicate opening. Region fixtures check chain endpoints and water edges. Four actual Player instances use the real14x26 collider to traverse the shafts, actively attach and release through real input at both endpoints, then use actual controller gravity/air adjustment to reach upper side landings. These are focused physics fixtures, not an automated gameplay run or a manual playtest.


## Main-project migration

The tested dungeon level is selectively migrated from commit `e895c4477237c47ad14ed75ed7a7a8b4460c38fd` into the existing main project. Only the level and this documentation are copied, not a source working tree. The geometry/interaction script retains source Git blob `69600bbb92549db733f7c3eac469ffaf2c53d15e`. Existing main combat, audio, VFX, Boss, controller and HUD owners adapt their own files. No story or new creature category is added.

`tests/main_dungeon_migration_test.gd` is the migration-specific short runner: one SPAWN seed, actual constructed terrain and gate bodies, pure-data room/map exposure, precise door/climb/water boundaries, restored stable IDs and clear climb shafts. It exits nonzero on failure and writes ignored evidence under artifacts/. Run after ordinary main-project resource import; it does not start the playable scene or change other source files.

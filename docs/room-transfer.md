# Separate room lifecycle

Dungeon and Boss combat now instantiate different Node2D scene trees. The dungeon's collision floor ends at2626 with a real terminal wall; the old arena platforms are not instantiated there. The Boss chamber independently creates its floor, three one-way shelves, side walls and solid roof. It retains the existing combat coordinate system, not the old dungeon tree or hidden enemies.

At the dungeon threshold2560/300, defeating the elite unlocks the portal. E first asks for confirmation; another independent E within3s confirms. An0.8s transition owns movement/damage lock. At40% the old level, mobs, Boss, projectiles, hazards and gates are detached and retired; pending Boss source callbacks are disabled before deferred free. At100%, after the new room has been present across physical frames, the sole score and Boss start. An unavailable explicit score remains safe and offers return/retry.

Boss entry is2706/300. R after Boss defeat reloads this room and starts a fresh encounter after preparation; dungeon shrine/elite/doors/shards remain in session metadata. E after victory returns from any position via the same confirmation/transition. F5 clears room and chapter session progress and begins in the dungeon. R/F5 during transition cancel its cursor before deferred reload. Existing checkpoints remain session-local; this is not a new disk-save system.

Room bounds, camera, shard ownership and map content now come from the active room. Global shard index11 belongs to the Boss chamber, so existing shard indices are not reordered. Boss HUD/map contains its own platforms and entrance; the dungeon map retains its exploration record. All voices, weapon work and story identities are outside this change.

For the faster player, sentry speed55->70, wisp/jailer42->52, elite88->108, lantern32->40 and bat65->82. Ground acceleration650->850; aggro reach360->420 remains constrained by same-room, screen and line-of-sight checks. Shared post-attack cadence padding650ms->480ms and elite recovery550ms->480ms improve re-entry. HP, damage, warning lengths, projectile counts, source plans, caps and blocking-lane leases remain unchanged.

Verification:38 named checks passed on the selected snapshot, including short startup; room lifecycle32, geometry32, navigation52, room HUD28, main scene61, integration24, impact18 and main Boss77. The existing full-source accounting still228 phrases/862 actions/2787 shots/24 cubes/48 laser formations. Scene reference checker reports312 files/zero errors/zero warnings. Independent room source review reported no findings.

Three800x450 GPU-rendered static frames were visually inspected: portal confirmation, independent Boss map and preparation blackout. Actors were frozen and music stopped; no playthrough/recording or audio-device listening test was performed. Evidence is in artifacts/response-rooms-final. Pending climax blink is a separate change, not part of these room results.

Skills actually used: coldbrew-builder, godot-nodes-scenes, godot-2d-movement, godot-gdscript-headless-testing and godot-ui-control. Separate owners handled movement/timing, room geometry/HUD, integration and read-only review. Concurrent uncommitted weapons are preserved and excluded using selected-source index blobs.

# Bellkeep: first complete level

Ownership: this file and `levels/bellkeep.gd` belong to the level task. Combat, progression, checkpoint activation, enemy gates, shard pickups, Boss entry and outcomes belong to the root game. Cursor can replace the functional environmental art after coordinating the code boundary. No final art assets or HUD files are authored here.

## Technical frame

Godot 4.7.2, orthographic side view, native 640x360, nearest filtering, integer pixel clusters. All architecture is authored from flat rectangles and stepped silhouettes in GDScript; no 3D renders, commercial assets, or inherited demo content. No external images or fonts. Collision layer 1 is world terrain. Thin ledges are one-way from below; ground is solid.

Movement design basis: speed 180 px/s, jump -340 px/s, gravity 900 px/s². A full uncut jump has a 64.2px apex and 136px theoretical same-height travel. Required ground gaps are 72/80/84/72px (53–62% of theoretical travel). Optional ascending ledges rise by 44, 44, 44 and 24px. Their gaps are 22/36/54px; descending branch gaps are 40/32/50px. No required dash or air jump is used to justify mandatory geometry. Air jump and dash let the player correct mistakes.

## Authored sequence

| World x | Experience | Spatial treatment |
|---|---|---|
| 0–274 | Safe awakening and movement | Wide uninterrupted nave with cyan wayfinding; spawn (90,260) above floor300 |
| 274–510 | First melee/parry lesson | One ground sentry at390; enough floor before the first72px jump |
| 510–1000 | Jump development and optional ascent | Broken cloister; parallel upper one-way ledges offer shards and a view of the belfry |
| 1000–1726 | Mixed combat and traversal | Floating wisps, one sentry,80/84px gaps and a lower optional ledge; no enemy placed in a gap |
| 1798–2090 | Rest and checkpoint | Continuous floor; cyan shrine at1860, no enemy in the rest pocket |
| 2090–2470 | Elite examination | Flat broad court; elite at2240. Root owns the post-elite passage gate |
| 2470–2640 | Anticipation | Quiet belfry approach with one visible entrance arch |
| 2640–3380 | Multi-phase Boss climax | Broad solid floor, three optional aerial interception ledges, giant cracked bell backdrop |
| 3380 | Outcome/exit landmark | Open arch is a visual destination; root owns victory/backstab/fade/restart |

The golden path is continuous from left to right. Cyan shard placement rewards the optional upper path, but no shard is required for progression. No branch can trap the player: ledges are one-way and return to the same lower route. Main gaps are deliberately visible against the sky below their pale collision lips. Falling is handled by the root game and returns the player to a checkpoint rather than embedding a separate death system here.

## Data interface

`SPAWN`, `CHECKPOINT`, `BOSS_TRIGGER_X`, `BOSS_POSITION`, `LEVEL_END`, `WORLD_BOUNDS`; typed `PLATFORMS`, `ENEMIES`, `SHARDS`, `ZONES` arrays. `setup(game)` is idempotent and constructs terrain physics only. Six enemies are provided as data, not spawned by the level. Twelve shards sit24px above ledges/floor; collect against the player's torso (feet minus16px) or use a feet radius of at least26px. `ZONES` contains ordered x/title/hint dictionaries for the HUD. There is no hidden progression state in the level.

## Functional art direction

Deep indigo sky and flat ruined castle silhouette; blue-gray masonry; pale continuous top lips identify actual collision surfaces. Cyan is safe guidance and player energy; muted gold is stationary lamp/bell trim. Active hostile gold projectiles are brighter and own their VFX through combat. Repeated arches and torn purple banners lead toward the single broken moon and suspended cracked bell. Foreground geometry has readable value separation; background arches remain low contrast and do not imply collision.

Palette constants are in the level script. Environmental animation is limited to two-state shrine/candle pixels at8Hz or lower. No interpolation, bloom, particle veil or camera effect is used to hide the pixel grid.

## Verification and limits

Required gap and ascending ledge metrics were computed against the controller contract. Script parsing and integration checks are delegated to lead using the installed Godot binary; user playtesting remains necessary for feel, accessibility and difficulty. Do not claim the geometry was manually played. Final visual art is intentionally left to Cursor; the original procedural scene is a functional, replaceable foundation.

## Elite gallery (added on cursor/gameplay-vfx)

Three optional one-way ledges over the elite court (x 2110-2488, rises of 44 px, gaps 44/42 px) with three extra shards (indices 12-14, appended so saved indices stay valid). Not required for progression. 	ests/level_layout_test.gd checks chained-jump reachability, overlaps, shard and enemy placement and zone order arithmetically; it is not a playthrough.


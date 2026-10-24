# Dungeon and pixel UI milestone

The stable combat fusion parent is 90319f4e61d372ed8a231e82c28ef617e8515862.
The new branch extends the original route with a lower flooded ossuary and upper archive,
four climb chains, three doors/mechanisms, ten appended rewards and five appended enemies.
The original fifteen shard indices, tutorial route and Boss coordinates remain intact.
Boss fine design remains owned by the user's collaborator; Boss/music/timeline source is unchanged.

Logical resolution increases from 640x360 to 800x450; default display is 1600x900, nearest
filtering and integer scaling. Hero native 64x64 cells and anchors remain unchanged,
while new armor/cape/helmet details and climbing poses are authored on the pixel grid.
The camera follows vertically and stays within authored world bounds. Shrine and Boss
entry checks use actual 2D regions, preventing another floor at the same x from triggering them.

The HUD derives panels from its full canvas edges, bottom and center. It uses 12/24px
OFL pixel text, compact real HP/posture information, a keyboard pause/settings screen,
win/death pages and a TAB map built directly from authored collision/chain/water/door data.
Map/pause share one root overlay state. E opens the nearest eligible door or mechanism;
opened stable ids survive retry and reset on a new journey. No unimplemented RPG statistics
or new story identities are presented.

Mobs have finite telegraphed layers, locked aim and a center/gap lane. Their styles are
amber shard, pink seed and yellow-green rune; reflected shots become cyan. Source caps,
180 global cap, age/wall cleanup and offscreen cancellation bound cost. A full cap rejects
new shots and preserves already reflected ones. All tails remain in the single FxLayer.

Validation: all eighteen tools/verify.ps1 checks passed, including 416 layout assertions,
93 actual-player dungeon probes, 38 traversal and 38 mob probes, legacy contact/music
contracts, font coverage from real interface text, integration and short startup. The
static 180-shot x 60-tick CPU probe is logged under ignored artifacts/dungeon-integration-console.log.
These are bounded checks and fixed visual studies, not a playthrough or a claim about
subjective feel, frame rate on every system, difficulty or real audio latency.

## References, original implementation

- https://www.hollowknight.com/ : broad inspiration for an interconnected exploration route;
  no map, art, characters or code are copied.
- https://docs.godotengine.org/en/stable/tutorials/rendering/multiple_resolutions.html :
  integer scaling and edge-relative GUI layout.
- Existing repository THIRD_PARTY_NOTICES and font OFL notices still apply unchanged.

Skills used: local level-design, godot-2d-movement, godot-animation, game-feel,
godot-gdscript-headless-testing, game-ui-ux and godot-ui-control, with the existing
coldbrew builder/core workflow. Roles were non-overlapping level, traversal, mob,
presentation, integration and read-only review.

Fixed OpenGL snapshots were captured once with frozen actors (no route/input play):
artifacts/dungeon-01-water-crypt.png through dungeon-06-combat-death.png. All six
were viewed for pixel edges, room silhouettes, map/HUD placement and normal-color
death text. Capture exited 0 with no script/engine errors. The 180-shot x 60-tick
probe took 30.507 ms total CPU on this machine; this is not a full-game FPS benchmark.
Independent read-only review closed its reported issues and found no remaining P1/P2.

At final remote inspection integrate/vfx-primary advanced to
2e2efbbadbf952e66c40141307a2426aad261469 (camera blur and forward-step additions).
Those newer edits are preserved in their own branch and not claimed as merged here.
This milestone retains the already reviewed 205b8e7 presentation baseline and its
runtime compatibility fixes; new source working files are not overwritten.

Follow-up narrative interface check: integration 51/0, dungeon integration 47/0, short startup PASS; independent review has no findings. Only events, visual parameters and a separate session completion record were added. No rescue trigger, automatic corruption mapping or new Boss behavior is implemented.

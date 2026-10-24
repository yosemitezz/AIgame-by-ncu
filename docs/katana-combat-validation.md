# Wide melee, full-body animation and katana Boss

Base: 251e4786db7314ea59bac5d75d864cb786a1888a. PR1 source adapter milestone:
9804e9732374d9f149768c37cf8a424107af064f. The existing game entry remains play.cmd.
No new map or story encounter is introduced in this milestone.

## Actual attack and visual boundary

Hero maximum forward radii change from 42/47/55 to 180/204/228 logical pixels;
vertical ellipse radii are 72/84/96, origin is feet+(0,-24). These values exclude
the target hurt shape. They are maxima, not a continuously active rectangle.
Angle keys, current physics sweep interval and the shared profile determine the live
sector. Raised quarter is harmless, the final active endpoint is queried, and root
still owns one accepted hit per target per attack serial. MeleeQuery uses actual
hurt shapes, rejects rear centers and ray-checks world walls. Visual primary sword
geometry reads exactly that same world polygon and leading edge. The actual range
has grown; visual reduction is not used to hide the mismatch.

Ground advance is limited by wall/floor probes; jump/air control, parry, Shift,
climb and input buffers remain owned by the controller. Forty-eight new original
hero poses cover three windup/cut/recover families and separate airborne cuts.
Waist/shoulder commitment, knees, support feet and cloth change in the pixel source.
Native 128x96 cells/feet anchor48,88 retain the original body size.

## Boss and friend logic

An original adult swordwoman uses 15 clips/62 cells at native128x128, anchor48,116,
including approach, draw, two cuts, recovery, casting, ordinary and armored recoil,
guard collapse/recovery and falling. Both first contact cut frames have actual
blade pixels across local x14..60/y-26..-18. The pose reads the real authoritative
stage and freezes with that actor. Short early collapse holds through the counter
window; ordinary hurt cannot hide a still-live windup or cut. Snapshots copy the
pose rather than rereading a later live actor.

PR1 by zjuan-ctrl is adapted as four MIT modules: precise beat grouping, cue cursor
and cancellation generation, six-slot eligibility and projectile geometry. They are
called by the main Boss. Existing MusicDirector remains the only score clock, with
fixed beat starts, health-gated phrase loops and safe rests. Source ports include
full MIT notice/provenance. Original private audio and reference chart are excluded.
In the pinned PR1 baseline the final move/chart values were absent. The newly
received PR3 now adds authored attacks and laser arrays; it is not integrated here.
Our data/boss_moves.json remains an explicitly original temporary configuration,
not those newer authored moves.
Laser and heavy-note judging from the independent subproject are not claimed here.
Rain preview and release share a locked source; victory/rest invalidate future cues
and clear old attacks. No original PR launcher/player/audio/damage engine runs.

## Pixel speed presentation

The played251 version had no fullscreen blur shader; its afterimages expanded by
34%/20% while fading and lingered with a .34s ribbon. Ghosts now stay native size,
use short outlines, owner cap5 and displacement/time sampling; ribbon life is .14s.
Background-only direction streaks and short camera lead provide speed cues while
actors, bullets and HUD remain crisp. F3 cycles standard/strong/off. F2 disables
camera feedback, including the short lead. Map/pause clears motion decoration but
keeps live frozen blade/warnings; no SFX replay on resume. Story-safe clears attacks.
Clash white core lasts .033s with radius<=18native; colored rings/sparks continue.

## Evidence and limits

All23 verification checks pass across the initial import/core run and its resumed
remainder. The old impact test was corrected to begin an actual next attack after a
parry canceled the preceding one; production active-phase protection stays enabled.
Latest relevant checks: profile44, friend43, Boss parry45, music30, mob50, speed19,
fused FX65, visual mapping260; real-scene wide melee validates150px contact, wall,
rear/outside misses, serial dedupe, phase/rest and F3. There are no remaining failed
assertions. The Image.load_from_file warning belongs only to the raster-inspection
test, not runtime texture loading or a supplied export (no executable is packaged).

Four frozen OpenGL studies under artifacts/combat-01..04 show the larger sword,
real blade parry, Boss guard break and crisp speed layers. They are not playthroughs.
The root viewed actual images and native contact sheets; excitement, difficulty,
real audio latency and final aesthetic acceptance require the user's playtest.

Official reference actually viewed: https://azurlane-anime.jp/character/28.html and
its official character/images/28_m.jpg (face/hair value hierarchy only). Snowbreak's
https://snowbreak.amazingseasun.com/en/index.html was consulted but static character
image links were unavailable; no claim of visual review. References stay in ignored
.local/references. No commercial character pixels, 3D renders or private music ship.
All production frames are original editable integer-pixel source, not imagegen;
this respects the required all-D deterministic sprite pipeline.

Skills: create-game-assets/raster pipeline, godot-animation, godot-2d-movement,
game-feel, godot-gdscript-headless-testing, existing coldbrew builder/core. Team split:
Boss source adapter, geometry/controller, hero pose source, Boss pose/FX/speed,
root wiring/validation/Git, independent read-only review.

PR3 pending integration: https://github.com/yosemitezz/AIgame-by-ncu/pull/3, head fff7526a3dc687c9625dece860a79695c00db8d0, merge ad7d9bd1fc06223428a8029349308a4318040d27. This is newer than the PR1 adapter validated in this milestone and must be compared separately; no claim that the friend still has all slots empty.

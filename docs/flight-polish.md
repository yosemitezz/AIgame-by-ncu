# Flight and sword-form polish

Local stage after8a1b103; the player controller, movement, immunity, cooldown and attack geometry/configuration are unchanged. The actor still has the same167native144x128cells and66,108foot anchor. No whole-image rotation is used.

## Flight staging

The three directional air-dodge clips remain at155/159/163, each4frames. The four drawings now brace/spread, throw the shoulder, extend through propulsion, then release into a glide. Front knee, trailing boot, head counter-tilt, cape and arm extension change with that weight transfer. Vertical poses keep the head above the hip. The game-owned170ms dash clock still decides motion; `ActorRenderer.flight_progress(actor)` only reads it.

`LightWings` now draws a bent shoulder/elbow/wrist wing. Six primaries grow along the wrist with overlapping cool-shadow/ivory feather planes and small brass joints. The fan spreads before pressure, compresses during drive and releases for the finish. A subtle rear layer gives depth while remaining behind the character. Three dim wake strokes replace the old five44pxjetlines; their individual stroke length is at most26px and residual lifetime100ms. Facing/direction changes interpolate the presentation vector without changing movement. Pause holds the effect; story safety, room handoff or death clears it.

All three original ground/air/guard sequences use coherent new original sword forms:

- Light:43rig-pixel point sword, narrow1.27pxblade, shallow steel cup and knuckle bow. It is a rapier silhouette, not another crossguard sword with a different colour.
- Heavy:44rig-pixel straight iron slab,10.2pxsource thickness (about8.6native pixels), bevel band, blunt heel and inset pins. It has a weighty two-hand grip and no borrowed character art.
- Two-handed:49rig-pixel tapered double edge, long12pxgrip and broad crossguard, distinct from the iron slab.

During free jump/rise/apex/fall and repeated air jumps, the hand carries the point naturally behind the body: the heavy blade hangs lower, the rapier trails lightly and the two-handed blade holds a stable rear axis. Attack windup returns the weapon to the front before the effective stroke. The existing light drill, heavy third-strike energy and two-handed circular strike mechanics are retained.

The latest weapon-form request intentionally supersedes the earlier7c536d1pixel/tip/parrybyte-preservation requirement. Every sword draw and exported attack/flight tip is regenerated; we do not claim those pixels stayed identical. Weapon design, source blade/grip/width metadata and actual flight hand/tip landmarks are exported in the manifest. Physics, timings, collision and per-target damage rules remain protected separately.

## Evidence and limits

`tests/flight_polish_test.gd` covers all3flightdirections, blade alignment, natural rear carry, distinct weapon forms, visibly different body phases, elbow/wrist feather geometry, bounded rear-only wings, read-only state, pause and safety cleanup. A first test caught the heavy blade's initial descent angle being too horizontal; its actual pose was corrected, then the focused phase tests passed. A GPU-only self-crossing wing surface was also caught and fixed by pixel hull/degenerate rejection; near-closed wing draws are included in final fixed frames.

`artifacts/polish-flight/` holds pre-change screenshots, current weapon carry/contact sheets,501cell raster QA, and three800x450fixedphases plus a three-direction stage sheet. Captures freeze physics/AI/music and contain no input playback. They demonstrate pose and silhouette changes, not subjective continuous game feel. The user performs playtesting.
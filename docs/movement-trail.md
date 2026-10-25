# Velocity-layered motion history

`MotionBlur` keeps its existing main-scene name and creates `MotionBlur/MovementTrail` as the sole moving-hero trail owner. A separate native-world canvas sits behind actors; it never samples screen pixels, enemies, warnings or HUD. Attack/parry/Boss afterimages remain with their existing effect owner.

Run, air movement and dash have different intervals, spacing, opacity and lifetime. Snapshots retain real past positions, authored frame region, facing, sword and direction. Both minimum time and minimum distance must pass, and a new observation must actually move. Nothing emits repeatedly at one point. Capture timestamps retain their true age; long frames or held poses never rejuvenate an expired observation. Eight snapshots are the maximum; dash lives at most190ms. Stopping accelerates fade so the residual set is gone within60ms.

The old silhouette's rear portion gets two tiny2px displaced samples. This is local after-edge blur, never whole-screen blur or blur on the live hero's face/body. Horizontal, vertical and diagonal presentation vectors follow observed history. Large position discontinuities, room changes, death, narrative safety, pause, overlays, retries and explicit service clearing discard history and anchor positions.

F3 / existing speed-effects setting controls these trails and background speed marks. F2 controls camera impact and camera lead only. Ownership remains declared while F3 is off, so old dash ghosts cannot reappear as a fallback. `data/motion_effects.json` has strength0..1.5(default1), interval/distance/lifetime/budget tuning; it changes no movement, invulnerability or audio clock.

Validation: `tests/movement_trail_test.gd` is a bounded state/history fixture. Static800x450comparison uses `tools/capture_movement_trail.gd`, with input/AI/music stopped; evidence in ignored `artifacts/movement-trail/`. These frames establish composition and historical positions, not subjective motion feel or a playthrough.
# Combat animation and impact presentation revision

## Visual contract

The hero is newly drawn from integer-grid joints, body, hood, cloak, hands and blade poses in `tools/generate_combat_frames.py`. No rendered models, translated frame copies, external character art or antialiasing were used. Cursor's committed source assets remain unchanged.

- Native frame: 64x64 pixels. Feet anchor: (28,58). Visible body height remains about 42px, so the existing collider and level metrics remain unchanged.
- Hero atlas: 70 cells, 8 columns. Four idle frames, six articulated run frames, four frames each for jump/fall/dash/parry/hurt/dead; three attacks each contain windup/attack/recover with four frames per stage.
- Each attack has separately authored shoulder, elbow, sword angle, hip, knees, feet and cloak. Cut 1 descends, cut 2 rises, cut 3 braces and thrusts with a front-foot commitment. Repeated settle poses across clips are intentional, not invented unique-frame counts.
- Colors: eleven visible RGB palette colors; transparency is real alpha. Nearest filtering and integer draw positions. No whole-character image rotation/scale animation.
- The shader-free hit flash is restricted to the struck actor silhouette; no full-screen flash.

## Runtime adapter

`presentation/actor_renderer.gd` exposes static `paint(canvas,kind,state,frame,facing)` for the existing integration painter. Hero states `windup`, `attack`, `recover` select the actual combo 1..3 and phase frame 0..3. Other enemy/Boss kinds retain their original atlas and a brief silhouette hit flash, without fractional scale.

Additional helpers: `hero_region(state,frame,combo)`, `weapon_tip_local(combo,frame)`, `silhouette_texture()`. Blade-tip positions are generated from the same pose data as the actual drawn sword, not an unrelated visual arc.

`presentation/combat_vfx.gd` is a presentation-only Node2D. `configure(game)` attaches `warning_issued`; root forwards `emit_fx` to `emit_effect(kind,at,direction,power)`. `clear_hostile()` clears warning tells, enemy arcs, all stale blade arcs/trails; ambient pickups and friendly dash silhouettes are not treated as hostile. It never changes health, animation stage, Engine.time_scale or tree pause.

`slash` power 1/2/3 selects the hero combo. Its sprite frame is bound to the real player owner, attack_serial and normalized ACTIVE-phase progress. Local hit-stop freezes the crescent with the body/blade; recovery, cancellation, owner destruction or a new attack removes that crescent immediately. The already-sampled tip trail alone fades for 0.16s. Enemy and Boss swings must use `enemy_slash`. Threat tells are amber outlines, projectiles remain owned by gameplay. Hit feedback uses a 5-frame core/stroke strip plus 4–7 short debris chips. Parry uses a hollow diamond and hard cross, leaving the playfield visible. Dash snapshots the actual hero pose and retains at most three low-alpha silhouettes for 0.15 seconds.

Budgets: 64 effect entries, 72 debris chips, 3 dash ghosts, 12 warnings, 8 points per blade trail. These are caps, not target particle counts.

## Actual open-source adaptation

The crescent geometry and start/update/end blade-trail lifecycle were adapted from `CodingQuests/godot-hitbox-hurtbox`, pinned commit `7ccc10925a07960772d83db970d56fef875a983d`, `scripts/WeaponController.gd`. MIT copyright 2026 CodingQuests; retained license: `third_party/codingquests/LICENSE`.

`make_arc_points` in the pixel generator preserves the source's outer radius `offset + size.x * 0.5`, inner radius `outer * 0.45`, clamped span up to 130 degrees and 10-step outer/inner polygon. It is rounded and rasterized at five authored sweep angles rather than drawn as a smooth scaled polygon. The third combo uses an original thrust stroke for a distinct shape.

`_start_trail`, `_update_trail`, `_end_trail` in CombatVFX follow real ACTIVE-phase serial changes, sample actual sword-tip coordinates, cap at eight points (source cap twelve) and fade only after active ends over 0.16 seconds. No upstream demo project or code was executed.

## Evidence and limits

Local ignored evidence is generated to `artifacts/feel-*`: combo/motion/VFX contact sheets, native-pose before/after comparison, asset hashes/palette/unique-frame report, and Godot parse log. These are fixed pose inspections rather than gameplay. Parent integration verifies runtime capture, local hit-stop and timing logic. Actual responsiveness and difficulty remain for the user's own play test.

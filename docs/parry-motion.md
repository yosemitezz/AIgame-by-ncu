# Blade-contact animation and color-flow revision

## Actual poses and stage binding

`tools/generate_parry_frames.py` authors 24 integer-pixel actor poses: hero ready/recoil/recover (four frames each), Boss recoil/guard break/guard recovery (four frames each). Arms, sword/halberd angle, hood/helm, torso, knees and cloak are redrawn from pose coordinates. No whole-body image translation/rotation is used as a substitute for animation. Existing feel frames and Cursor source images are unchanged.

Hero canvas/feet anchor stay 64x64/(28,58); Boss stay 80x80/(40,76). Hero parry phases use `parry_phase` and `get_parry_progress()`. Boss uses `reaction_state` and `reaction_progress`: ordinary `parry_recoil` then `parry_recover` returns the deflected weapon without kneeling; only `guard_break` lowers the body into a knee, followed by `guard_recover`. Collapse occurs near the beginning of the actual break stage and then holds, rather than waiting until the counter window is nearly over.

The renderer never owns these timers and does not advance actor poses from an unrelated visual age. Pauses/local actor holds preserve the corresponding real stage progress.

## Contact effects and restrained gradient flow

The root's accepted contact dispatches exactly one semantic event at a real world position:

| Event | Strip size / lifetime | Short directional rays |
| --- | --- | --- |
| `blade_parry` | 80px, 160ms | 8 orange/gold |
| `projectile_parry` | 40px, 140ms | 4; compact circular reflection |
| `guard_break` | 96px, 250ms | 10; broken expansion ring |

The white core exists only in the first of six strip frames. Orange/gold contact remains central. The cyan → blue → violet → pink → gold flow is restricted to narrow blade-edge bands and hollow outer ribbons. All gradient samples are discrete pixel colors, with no fullscreen overlay, bloom or whole-body glow. Debris expires after 100–180ms, within the existing global effect budget.

`unblockable_charge` tells use coral plus an X. `armored_slash` tells use a gold edge and three violet pips. An armored clash and a posture break remain different visual reactions.

This layer adds no reward, contact acceptance, damage, sound, camera shake, pause or time-scale changes. Root/controller/Boss own those behaviors.

## Evidence

Ignored local files under `artifacts/`:

- `parry-hero-contact.png`, `parry-boss-contact.png`: all authored actor stages.
- `parry-gradient-contact.png`: all contact strip frames at nearest scale.
- `parry-static-keyframes.png`: a labeled static pose study, not a gameplay screenshot.
- `parry-renderer-parse.log`, `parry-vfx-parse.log`: Godot script checks.

Artwork and source are original and use the repository MIT license. The reference was used to identify motion properties; no video image or commercial asset was incorporated. Actual game integration is checked by the lead with bounded tests and fixed scene captures; user play feel is not claimed from contact sheets alone.

# Three-weapon ink and confirmed-contact polish

This local presentation revision follows the original weapon-profile geometry without changing reach, damage, body movement, input or musical time. The primary shapes remain bound to actor attack serial and actual active progress. Paused or locally frozen progress never emits additional boundary fragments.

Light thrusts use a tapered one-pixel centre needle and a short sharp tip. The old closed collision-hull box is no longer drawn. The third drill keeps two subdued spiral wakes behind the leading point, inside the original hull. Body and sword-hand pose remain visible.

Heavy cleaves use a narrow warm strip inset from the exact swept outer contour. The current head of the stroke is bright, and the trailing section falls off quickly. The old full-bright radial rod from the torso to the far radius is removed. The independently colliding third-hit sword wave remains owned by the root projectile module.

The two-handed sword uses the same contour contract with a thinner golden orbit strip. Only the actual swept interval is drawn, rather than a complete luminous circle. A short steel-white leading section gives direction without painting the centre of the circle over the character.

All three primary strokes detach into world-fixed recovery afterglow, quadratically fading from16%alpha to zero within75ms. Cancelling an active strike removes its contour immediately. Grounded lunge decoration is a few heel chips and a weak short afterimage, not overlapping large rings and bars. Airborne dash onset belongs to the articulated wings; this layer no longer adds a duplicate launch ring.

`weapon_hit_light`, `weapon_hit_heavy`, `weapon_hit_great` and `weapon_hit_wave` are supplied by the root ONLY after confirmed damage, at its actual contact intersection. FxLayer alone owns these cores; the root suppresses the legacy generic body-centre `hit` emitted synchronously by receive_hit while resolving that weapon damage. The four new families use a small white pixel core, directional cool needles / warm chips / golden radial cuts / compressed wave cuts, at most18px core-ray extent,130–180mslife and4–7shortparticles. They do not request shake, freeze or sound; the existing confirmed-impact service remains authoritative. Same-contact duplicate emission within20msis visually coalesced, and storage is capped.

`tests/attack_polish_test.gd` checks real shared polygons, local-hold sampling, empty-swing absence of impact shapes, short recovery, contact-point anchoring, deduplication, pause/rest rejection and cleanup/caps. Static evidence is written to `artifacts/polish-vfx/`; frames disable player/AI/audio and are not a playthrough or proof of subjective impact quality. The separate contact overview is explicitly an event fixture, not a damage test. User playtesting remains the final continuous-action readability check.

Applied skill: game-feel (layered brief feedback, feedback separated from critical simulation). This revision deliberately keeps music independent and uses no Engine.time_scale writes.
When MotionBlur declares the dedicated movement-trail owner, legacy hero movement-only afterimages/body ribbons/smear stand down. Attack, parry and Boss/other-actor afterimages remain. The ownership declaration remains true while F3 disables the new trail, so old movement trails cannot silently reappear.

Comparison board: left BEFORE, right AFTER; top-to-bottom light/heavy/two-handed,2xNEAREST crops. The after frame also includes newly requested weapon silhouettes authored by the flight/rig owner. Contact cores have at most18pxray extent; their4–7chips may travel beyond that during their at-most200mslifetimes.

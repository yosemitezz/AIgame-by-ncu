# Hero attack revision: articulated full-body sword work

Original integer-grid drawings in `tools/generate_hero_attack_revision.py`, under the repository MIT license. This revision preserves our broken-crown helmet, pale plate, cyan slit and plum cloak family. It uses no external game art, rendered models, image rotation or whole-frame movement. It writes only the new `presentation/hero_attack_frames` family.

## Runtime layout

- Native cell128x96, fixed feet origin/anchor(48,88),8 atlas columns,48 cells. The larger transparent cell provides room for the blade and cloth; the armored character is not enlarged to fill it. Normal armor core remains approximately44px high, with the original small crown and torn cloth extending beyond the core.
- Atlas files: hero_atlas.png, hero_flash.png, hero_silhouette.png. Nearest filtering, integer drawing positions; no MSDF, filtering or baked bloom.
- States are cut_1_windup, cut_1_attack, cut_1_recover, cut_1_air_attack, followed by the same four states for combos2 and3. Each has4 frames. Manifest start/count fields, rather than a hardcoded row calculation, identify cells.
- The renderer must select the actual windup/active/recovery stage from the actor and map progress to floor(progress*4), clamped0..3. Airborne active cuts use cut_N_air_attack instead of a planted attack pose. No wall-clock animation should advance a held contact frame.

## Matching the combat profile

Contact begins at active progress.25, so frame1 is already fully extended. Four authored active samples represent0/.25/.5/.75:

| Combo | Body action | Blade angles, degrees |
|---|---|---|
|1|Coil through the rear hip, step into a horizontal cut, lower the forward shoulder and settle across the front knee|-78,-18,18,42|
|2|Fold sideways into a loaded low blade, reverse the chest and hips, then open into an ascending return cut|72,18,-18,-46|
|3|Compress the knees into an overhead load, plant a long forward step and hinge the torso deeply into a heavy long cut|-64,-8,4,26|

Angles are for facing right: zero points right, positive points down. These are the same samples as data/hero_attack_profiles.json. The final active endpoint angles62/-68/50 appear at the start of recovery so the last quarter continues into follow-through. Main energy radii180x72/204x84/228x96 and their broad polygons remain owned by the combat profile/VFX layer. The assets never reduce that energy arc. Visible steel is40/40/42px; its actual rendered hand and tip coordinates are recorded independently instead of presenting a guessed damage endpoint as physical steel.

Each pose redraws hip, shoulder, elbow, knees, boots, helmet and armor overlaps. Feet spread under load, the shoulder/hip axes separate, the cape lags the direction change, and the final heavy cut bends the chest forward over the supporting leg. Airborne cuts have separately tucked knees and free boots; they do not stamp on an invisible floor. Recovery returns the body in stages instead of just pulling the sword back.

## Manifest and validation evidence

manifest.hero.frame_data[state][frame] includes canvas-space hip, shoulder, head, both knees/feet, elbow, hand and tip; hand_local and tip_local are relative to the fixed anchor. body_axes supplies the actual body geometry; steel_length_pixels, blade_angle_degrees, cloth_lag_pixels, planted_feet and airborne identify the presentation decisions. weapon_tips[state] repeats the actual local steel tip list for existing adapters.

asset-report.json checks48 distinct RGBA frames, four distinct body drawings within every state, changed pixels between every adjacent frame, binary alpha, at most32 opaque colors, no clipped frame, a planted boot at feet line88 in every grounded pose, and both airborne boots above the ground line. The current drawings use10 opaque colors. It also records shared energy-profile radii and deterministic PNG SHA-256 hashes.

Fixed visual evidence is hero_attack_contact_native.png, hero_attack_contact_2x.png and hero_active_contact_2x.png. Only preview sheets are enlarged, by exact nearest-neighbor2x. Static contact sheets were visually inspected; no game was played and no actor/controller/FX/Boss/rendering file was edited.

Scope note: the previous idle weapon remains the shorter pre-existing art. The integration owner may address that resting-weapon transition separately; this task changes only the new attack family and does not silently alter other animation states.

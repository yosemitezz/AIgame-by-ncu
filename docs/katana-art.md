# Original katana swordswoman animation family

A (ink-silver tied hair / twin coat hem) was selected after lead visual review. The artwork is original integer-grid drawing, with an adult approximately 6.5-head proportion, closed high-neck light armor, small narrow eyes, two separate wine-red coat tails, copper hardware, and a slender curved katana. Reference images informed only broad face contrast and grouped hair masses; no commercial pixels or distinctive character ornaments are copied. No 3D or whole-frame rotation is used.

## Runtime contract

- Native cell 128x128, feet anchor `(48,116)`, eight columns, native scale 1 and nearest filtering. The approved standing main body is 67px high. Collider and gameplay scale are unchanged.
- `boss_atlas.png`, `boss_flash.png`, `boss_silhouette.png`: 62 cells, 55 unique pose images. Every frame is drawn from joints plus independently keyed wrists, knees, hair and coat panels. Reversed recovery poses intentionally reuse their corresponding recoil anatomy.
- `manifest.json` has `canvas`, `anchor`, `columns`, `atlas`, `flash`, `total_frames`, and both `states` and `boss.states`. Each state descriptor contains `start`, `count`, `frames`. Frame landmarks are local to the feet anchor: `hand`, `support_hand`, `guard`, `weapon_tip`, `guard_point`, plus the full joint dictionary. Each frame has a stable `name` and stage-normalized `progress`.
- Pure controller interface: `get_presentation_pose() -> {state, progress, strike, armored, contact_serial}`. Renderer chooses a cell from real stage progress; local freeze holds the same cell. The asset manifest specifies no wall-clock durations and does not change Boss logic.
- States/counts: idle 4, approach 6, shift 4, draw 4, cut_a 4, cut_b 4, recover 4, cast 4, parry_recoil 4, parry_recover 4, armored_recoil 4, guard_break 4, guard_recover 4, hurt 4, dead 4.

Cut A/B frame zero is already fully extended because real contact happens at release. Cut A starts with guard `(14,-25)` and tip `(73,-21)`; B starts at `(14,-19)` to `(73,-25)`. Both cover the actual local x=14..60 contact interval within y=-26..-18, checked against actual blade-colored raster pixels, not just the metadata. Anticipation lives in `draw`. Later frames articulate the waist, shoulders, forearms, cape tails and reverse-cut edge while preserving a readable forward blade.

Approach has six alternating supported foot poses. Shift changes stance and trailing cloth; draw coils the waist/shoulders. Recover withdraws a foot and lowers the katana. Ordinary parry recoil moves the hips and rear support foot; armored recoil keeps both legs in the approved stance and sends the reaction through the arm. Guard break collapses toward a low single-knee support with the weapon lowered, then guard recovery rebuilds stance. Death progresses from collapse into three directly drawn horizontal poses, never a rotated upright sprite.

## Evidence and validation

Generator: `tools/generate_katana_boss.py`. It writes all products under `presentation/katana_frames` on D drive, without API/network calls or external images.

- `katana-keyposes-2x.png`: nearest-neighbor key poses for side-by-side silhouette review.
- `katana-motion-contact.png` and `katana-reaction-contact.png`: every native frame in its real state order; both were inspected visually.
- `family-report.json`: per-frame hashes, palette count, binary alpha, landmarks, unclipped cell bounds, and first-cut actual raster contact coverage. All 62 frames pass, at most 19 opaque colors per frame and alpha only 0/255; both first cuts cover all 47 required x columns.
- `seed-candidates-contact.png`, `seed_a/b/c.png`, `seed-manifest.json`, `seed-report.json`: retained visual decision record; only A has an animation family.

MIT under repository LICENSE. Skills actually read: create-game-assets and godot-animation. Original procedure-drawn pixel source follows the user's all-D, native-pixel preference. Runtime renderer/Ghost integration and real-game checks belong to the lead; this art task does not modify them or run a playthrough.

# Dungeon hero and presentation contract

Original integer-grid pixel drawings in `tools/generate_dungeon_hero.py`, MIT under the repository LICENSE. No external character art, rendered models or commercial sprites are included. Previous authored joint/weapon pose tables are retained, while the broken crown helm, pale enamel faceplate, cyan slit, overlapping ivory armor, copper seams and torn plum cape are redrawn as a coherent family.

- Native cells: 64 × 64, feet anchor (28, 58); nearest filtering. Runtime never enlarges the source sprite; viewport owns integer scaling.
- Hero atlas: 82 authored cells, including six climb and six climb_idle poses. Current controller four-phase frame values map to source samples 0, 2, 3, 5, completing the alternating hand/foot cycle. climb_idle keeps the planted grasp. No wall-clock motion advances a held climb pose.
- Existing real windup/active/recover phases and all weapon-tip coordinates are preserved. The three cuts retain their shoulder, elbow, knee and cape movement. Twelve parry_ready/recoil/recover cells use this same armor family and real parry progress.
- Hero textures and manifest live only in `presentation/dungeon_frames`. Boss/monster art and Cursor source files are unchanged.
- VFX keeps the preferred large flowing slash/ribbon family. `water_splash` produces one flat water ring and at most ten falling drops. `mob_sentry`, `mob_wisp`, `mob_elite` warnings draw different thin weapon/seed/rune signs. Projectile styles `default`, `sentry_shard`, `wisp_seed`, `elite_rune` preserve visible cores and distinguish amber shards (#f4b95f), pink-violet seed beads (#ed88d9) and yellow-green rune diamonds (#cce675); reflected tails always become cyan (#73f6df), matching `Projectile.core_color()`. Presentation only: no input, damage, actor movement, camera or music writes.

Evidence: `presentation/dungeon_frames/dungeon-hero-comparison.png`, `dungeon-hero-contact.png`, and `asset-report.json`. Generated deterministically with Pillow at integer coordinates. Visual review uses a static contact sheet; user playtesting remains outstanding.

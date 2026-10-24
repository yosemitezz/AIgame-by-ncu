# Three sword motion contract

Local weapon identity revision retains the knight, crimson cape, movement clips,
parry clips, 144 x 128 native cell, feet anchor (66,108), and nearest pixel rendering.
No 3D render or external character asset is used. `tools/hero_rig.py` re-rasterizes
joint poses, armour, fabric and steel for every frame; `tools/generate_hero_atlas.py`
exports three sheets and their flash/silhouette variants.

Each sword has 155 original cells: every ground/air attack has four anticipation,
eight active and four recovery poses. `feel_frames/manifest.json` exports state
ranges, per-weapon steel tips and hip/shoulder/hand/foot landmarks. The player is
the phase/frame authority; presentation never advances a held strike on its own clock.

- Light: point-led first/second thrust, hip-to-shoulder extension, then a launched
  drill with tucked alternating knees, armour/shoulder twist and a braced finish.
  Air finishers have separate free-leg counterbalance. The thin twin helix stays
  inside the actual pointed energy hull; the previous-to-current movement interval
  has a short, low-opacity world trail.
- Heavy: descending, reverse rising and committed overhead cleaves. The third
  pose compresses the body and drives from the rear foot. The real third-hit wave
  is owned by `combat/sword_wave.gd`, rather than an extra decorative VFX ring.
- Two-handed greatsword: planted pivot, chest turn and reverse/full orbit. The steel
  passes behind the body using draw order, and foreshortens in the depth portion
  of its orbit. The actual circular attack is still pure 2D swept geometry.

Visible energy boundaries come directly from `AttackProfile.world_polygon`, with
weapon kind `thrust`, `arc` or `spin`. Steel follows the same authored angle keys;
its short physical blade and the energy reach are intentionally distinct. A spin
shows only its current damage sector, never a full damaging-looking ring at startup.
Mode palettes are icy blue, ember orange and pale gold. Large filled halos, secondary
star rings and swing-only screen kicks were removed from the primary weapon branch.
The root impact service handles accepted contact feedback; this module never writes
health, velocity, immunity, music time or global time scale.

Validation: `tests/weapon_motion_test.gd` checks nonempty eight-frame mappings,
landmark articulation, front/rear steel poses, current-contour identity and cancellation.
`tools/build_weapon_contact_sheet.py` creates fixed ground/air contact sheets.
`tools/capture_weapon_contacts.gd` renders three static 800 x 450 game keyframes
with AI, player physics, input playback and music disabled after a terrain-only
fixture contact. Local evidence is in ignored `artifacts/weapon-motion/`.
Motion readability has been inspected in those fixed frames; subjective timing,
weight and difficulty are for the user to play and judge.

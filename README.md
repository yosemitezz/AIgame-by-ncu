# AIgame-by-ncu

Public teamwork repo. **Art / UI preview** lives on branch `cursor/art-ui`.

## What this branch adds

Original western-fantasy **2D pixel** pack + Godot 4.7 showcase (not a web frontend):

- `assets/art` — hero poses, enemies, environment tiles
- `assets/vfx` — slash, parry sparks, dash ghosts, debris, charge/burst, warn vs damage zones
- `ui` — HUD + title / pause / settings / death / clear menus (presentation only)
- `scenes/showcase_*.tscn` — openable art review scenes
- `docs/art` — art direction + integration handoff

Gameplay simulation, collisions, boss AI, and music timeline are **other owners** — see `COLLABORATION.md`.

## Quick start (art preview)

1. Install **Godot 4.7.x**
2. Open `project.godot`
3. Run main scene `scenes/showcase_hub.tscn`
4. Optional regenerate: `python tools/art/generate_pixel_pack.py` (needs Pillow)

## Do not

- Upload commercial music, secrets, or old private project dumps
- Treat this preview `project.godot` as final combat config without Integration review

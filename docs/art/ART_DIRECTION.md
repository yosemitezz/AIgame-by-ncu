# Bellkeep — Art Direction (cursor/art-ui)

Western fantasy **pure 2D pixel**. References inform properties only: Dead Cells tension (anticipation / recovery), Hollow Knight restraint (quiet HUD, readable silhouettes), Terraria boss telegraph clarity (warn ≠ damage). No commercial asset reuse. Previous demos are rejected; this pack is a new visual system.

## Technical frame

| Item | Contract |
|------|----------|
| Engine | Godot 4.7.x, 2D only |
| View | Side-view sprites (per `COLLABORATION.md` side-scroller). Camera mode locked by Integration — art will redo facings if view changes |
| Base canvas | Hero `40×48`, enemies `32×32`, tiles `16×16`, HUD chrome sliced from pixel panels |
| Pivot | Hero feet `(20, 44)` — matches collab body anchor note |
| Filter | Nearest-neighbor everywhere (`default_texture_filter=0`, integer stretch) |
| Palette | Locked 32-swatch strip in `assets/previews/palette.png` |
| Outline | 1px ink `#121018` clusters, no soft glow crutches |

## Palette roles

- **Ink / shade / stone / ash / bone** — structure & UI chrome
- **Cloak blue** — hero identity
- **Copper / gold** — interactive metal, phase pips, focus
- **Blood / ember** — damage & danger fill
- **Arcane cyan** — real hit / parry / music-active feedback
- **Warn amber hatch** — telegraph only (never the damage volume)
- **MP blue** — resource bar only

## Motion character

Snappy windup → committed strike → short recover. Dash leaves cyan afterimages (3 frames). Parry is a hard spark burst (shape, not particle spam). Rest music section: UI copy softens; no hostile zone art.

## Explicit exclusions

- 3D / 2.5D / Blender beauty renders as production sprites
- HD UI over pixel actors
- Bloom stacks hiding weak silhouettes
- Copying Dead Cells / Hollow Knight / Terraria sheets
- Private commercial music in-repo

## Visual target (approved seed for this milestone)

1. `assets/previews/hero_contact_sheet.png`
2. `assets/previews/vfx_contact_sheet.png`
3. `assets/previews/hud_mock.png`

Judge at 1× and 4× nearest. Expand families only after these stay coherent.

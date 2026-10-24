# Art / UI handoff — cursor/art-ui

## Ownership (this branch)

| Path | Owner |
|------|-------|
| `assets/art/**` | Cursor art |
| `assets/vfx/**` | Cursor art |
| `assets/ui/**` (chrome PNGs) | Cursor art |
| `assets/previews/**` | Cursor art (review only) |
| `ui/**` (Godot Controls) | Cursor art |
| `scenes/showcase_*.tscn` | Cursor art |
| `scripts/art/**` | Cursor art |
| `tools/art/**` | Cursor art |
| `docs/art/**` | Cursor art |
| `project.godot` | **Bootstrap art preview** — Integration replaces `run/main_scene` when gameplay lands; coordinate before rewriting display/stretch/filter |

Do **not** edit: `actors/*`, `combat/*`, `audio/*`, `levels/*`, music timeline, input map gameplay actions, move/attack numbers.

## Open the preview

1. Godot **4.7.x** → Import / Open `project.godot`
2. Main scene: `scenes/showcase_hub.tscn`
3. Pages: Hero · VFX · HUD/Menus · Env Layers
4. Regenerate pixels: `python tools/art/generate_pixel_pack.py`

## Animation state names (requested from combat)

Match / emit via `animation_event` / `state_changed`:

| state | frames now | notes |
|-------|------------|-------|
| `idle` | 0–1 | subtle breath stand-in |
| `run` | 0–1 | |
| `windup` | 0 | anticipation |
| `attack` | 0 | active frames — combat owns hitbox timing |
| `recover` | 0 | |
| `hurt` | 0 | |
| `death` | 0 | |
| `dash` | 0 | + `assets/vfx/dash/dash_ghost_*.png` |
| `parry` | 0 | + parry sparks |
| `jump` | 0 | side-view; drop if camera changes |

Facing: `1` right / `-1` left. Flip sprite; do not bake mirrored sheets yet.

## VFX kinds for `vfx_requested` / `emit_fx`

| kind | folder | power |
|------|--------|-------|
| `slash` | `assets/vfx/slash/` | scales flash only |
| `parry` | `assets/vfx/parry/` | |
| `dash_ghost` | `assets/vfx/dash/` | |
| `debris` | `assets/vfx/hit/` | |
| `charge` | `assets/vfx/charge/` | |
| `burst` | `assets/vfx/burst/` | |
| `telegraph` | `zones/telegraph_warn.png` | amber |
| `damage_zone` | `zones/damage_arcane.png` | cyan |

Combat decides parry success & damage. Art must not invent HP or phase.

## HUD binding

```gdscript
$BattleHud.bind_game(game)  # connects hud_updated / boss_phase_changed / warning_issued
```

`hud_updated` dictionary keys used: `hp`, `max_hp`, `mp`, `max_mp`, `boss_hp`, `boss_max`, `boss_name`, `zone`, `hint`, `phase`, `section`, `beat`, `shards`, `outcome`.

Music sections `fixed` | `random` | `rest` | `final` — HUD label only; rest copy leaves narrative space.

## Verified / not verified

| Item | Status |
|------|--------|
| Pixel pack generated (Pillow) | Verified |
| Contact sheets written | Verified |
| Godot reference check script | Run on commit |
| Opened in Godot editor | **Not verified** (no Godot binary on this agent host) |
| Gamepad focus on all menus | Coded; needs editor/device pass |
| Integer scale on real displays | Needs human check |
| Combat integration | Not started — awaiting Integration main scene |

## Rights

All PNGs in this milestone are original programmatic pixel art (MIT with repository LICENSE). No third-party sheets, no private MP3s.

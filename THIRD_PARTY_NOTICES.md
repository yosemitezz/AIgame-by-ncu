# Third-party notices — combat feel revision

## CodingQuests — godot-hitbox-hurtbox

- Repository: https://github.com/CodingQuests/godot-hitbox-hurtbox
- Pinned commit: `7ccc10925a07960772d83db970d56fef875a983d`
- Source files read: `scripts/WeaponController.gd`, `scripts/PlayerCamera.gd`, `scripts/GameManager.gd`, `LICENSE`, `THIRD_PARTY_ASSETS.md`.
- License: MIT, Copyright (c) 2026 CodingQuests; full text in `third_party/codingquests/LICENSE`.
- Adopted: crescent outer/inner arc construction and bounded tip history in the pixel slash/VFX implementation; directional camera kick, exponential-like decay and sine-product noise in `combat/impact_feedback.gd`.
- Changes: raster/grid alignment and combo-specific timing; short capped effect histories; native camera displacement capped at 4 pixels, no rotation/zoom; actor-local freeze in place of global Engine.time_scale, so the existing music clock and projectile simulation continue.
- Not imported: project scripts as a package, autoloads, hitbox framework, demos, Kenney images, external assets or executable tools. Only static code was read before adapting the listed logic.

The project's own MIT LICENSE remains intact. New frame art and synthesized impact sounds are original programmatic work; Cursor's committed original pixel pack is retained under its existing repository license. Source authors' compatibility descriptions and screenshots are not treated as our runtime or aesthetic verification.

## Fusion Pixel Font

The bundled 12px zh-Hans project font is from TakWolf/fusion-pixel-font release 2026.10.16 under SIL OFL 1.1. Full original OFL and component notices are retained in assets/fonts/. It is a project resource, not a system installation or a commercial game font. See docs/pixel-font.md for official source URL and file hash.

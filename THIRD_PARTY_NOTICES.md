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

## Friend Boss rhythm PR #1 (MIT source adaptation)

Adapted from https://github.com/yosemitezz/AIgame-by-ncu/pull/1 by zjuan-ctrl, head 4e79620503bc9fd05a2154018ec97ec76f227557, merged upstream as 57f61ea993478d71e3de6d139597d976bb2b888b. The original subproject remains preserved upstream. Its exact beat grouping, cue cursor/generation, six-slot eligibility and projectile geometry algorithms are adapted in combat/friend_rhythm and used by the main Boss. Source license: third_party/friend-boss-pr1/LICENSE.

Private audio/if_infinity.ogg and the reference chart are explicitly excluded from that source license and are not included in this branch or its ancestry. The runtime keeps the distributable generated music and original placeholder cue data. Final move parameters remain unprovided; data/boss_moves.json is our temporary original configuration, not the friend's finished six moves. No PR launcher, original player controls or independent damage/audio engine is executed.

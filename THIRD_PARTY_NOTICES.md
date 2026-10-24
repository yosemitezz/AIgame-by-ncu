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


## Friend Boss PR1 / PR2 / PR3

Source: yosemitezz/AIgame-by-ncu pull requests 1, 2 and 3 by zjuan-ctrl. PR1 head4e79620503bc9fd05a2154018ec97ec76f227557; final PR3 headfff7526a3dc687c9625dece860a79695c00db8d0 contains PR2 head6ca9ca81e260d62d2556cb5d6e9f767c2e46c233. Final code is adapted once, not three overlapping controllers. Original MIT text is retained at third_party/friend-boss-pr1/LICENSE.

Adapted parser, action planner, slot configuration and laser geometry live in combat/friend_rhythm; combat/boss.gd and boss_hazard.gd call them using the main MusicDirector clock and existing damage/parry safety rules. Differences follow the supplied handoff: configurable1.1-beat fast threshold, exact note keys but tolerance-grouped fixed triggers, random fixed cube orientation and explicit source balance conversion. The supplied source chart is audited read-only in its original pre-existing subproject; no song, audio reference chart, demo art or subproject file is newly copied or modified by this milestone. Main runtime uses its generated redistributable score and original configurable short-score data.

New six-enemy frame families and their editable generator are original pixel artwork. The main baseline heavy-hit camera zoom and layered synthesized sounds remain unchanged; the earlier CodingQuests note describes the earlier adaptation, not a claim that the current camera has no zoom.

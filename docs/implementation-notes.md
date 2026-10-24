# Implementation and evidence

## Baseline and isolation

Original repository baseline: `8f676ac555596dd5c43f1eef0378b90774df6b4e`, containing MIT LICENSE. LICENSE remains untouched. Gameplay and Cursor art work use independent Git work directories; no resets, deletes or force pushes. Only project-owned source is staged. Local logs/screenshots/caches are ignored. The private listening song was not accessed or copied.

## Actually used skills

- `coldbrew-core`, `coldbrew-builder`: inspect baseline, ownership, bounded implementation, validation and deliverables.
- `create-game-assets`: exact pixel frame dimensions, palette roles, provenance manifest, native-scale contact sheets.
- `godot-animation`: six-frame sprite state mapping and externally replaceable painter.
- `godot-2d-movement`: CharacterBody2D, coyote/buffered jump, air control, world collision.
- `game-feel`: transient slash, impact particles, decay camera shake, readable tells. The music clock is not slowed by impact effects.
- `level-design`: movement-derived jump metrics, safe teaching, optional upper route, checkpoint, elite and climax.
- `godot-gdscript-headless-testing`: import before checks, explicit pass/fail counters and quit codes, error-log scanning.
- `godot-audio`, `audio-design`: original in-memory synthesized music, separate Music bus, phrase transitions and clock.
- `review-agent`: independent read-only defect-first review; review findings lead to specific corrections.

These were read from installed local skill sources. No unrelated skill source or old game implementation was adopted.

## Runtime boundaries

Presentation emits `hud_updated`, `boss_phase_changed`, `warning_issued`, `vfx_requested`, `animation_event`. These do not drive damage. Pixel placeholders are deterministic integer-grid drawings, listed in `assets/art/placeholder_manifest.json`; generator is inspectable source. They are replaceable functional assets for Cursor.

The rhythm clock uses compensated audio playback time with a deterministic Dummy-audio fallback. A missed beat has no damage path. Contact order on a swept projectile selects front shield before body only when the shield is reached first. Reflection does not extend the input window. Rest cancels Boss windups/charges, player attacks and all existing projectile nodes before dispatching the next downbeat.

## Checks and limits

`tools/verify.ps1` runs import, integration, music contract and startup checks. Integration covers actual scene/enemy/geometry creation, two-sided rest immunity, front/back projectile ordering, revive, checkpoint/elite progression, actual projectile clearing, Boss defeat and scene reload. Music contract covers looping, threshold queueing, exact phrase transitions, pending attacks and terminal callback behavior.

`tools/capture_review.gd` produces six fixed-pose review images: teaching, upper path, checkpoint/elite, Boss starfall, rest, chapter end. Rendering uses real OpenGL, not a model render or composited mockup. Hero/Boss contact sheets were visually inspected. A narration overlay found covering the hero was moved above the action. This is visual review, not a completed gameplay run.

Independent review identified a nonfinal Boss overkill route that could skip the rest/final music sections; the implementation now holds the configured health threshold until the final section. Gate references are cleared after freeing to keep rendered frames safe.

Not verified: user comfort, encounter difficulty, controller support, accessibility options, native executable export, and real audio-output latency/listening quality. The first chapter runs from the Godot project/launcher; no export templates are required. Cross-session saves and later connected chapters are future work.

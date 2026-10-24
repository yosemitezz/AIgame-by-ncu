# Parry, posture and pixel HUD milestone

Baseline: b262ed4dbcee82b69bcf195a6fe5edfe5b15a0d6. This commit is independently reversible. No Claude implementation was supplied or merged. Cursor remote was a2c857b; its separate checkout has active uncommitted hero/world edits, which are untouched and excluded.

Implemented contact-driven melee parry, distinct projectile reflection, ready/recoil/recover poses, and one feedback event per accepted source/token. Ordinary Boss cuts are interrupted; armored parryable double cuts retain later contacts until posture break. Unblockable charge is a separate property with coral-X warnings. Three posture pips create a 0.9s counter window and 0.18s recovery, followed by a reset lock. Timings are original tuning, not measured reference-video frame data. No perfect-parry subsystem was added.

White/orange-gold directional blade sparks are accompanied by narrow cyan/violet/pink/gold flow bands. Break and reflection have different effects/sounds. Camera impact is contact-driven, graded and capped at 4 native pixels; F2 disables it. Actor-local holds leave the music clock and projectile simulation independent.

The HUD uses an original black/white frame and bundled Fusion Pixel Font 12px/24px (SIL OFL 1.1), not commercial-game font files. It displays only implemented health, Boss health/posture and encounter state; no invented LV/EXP/TP resources. Full font notices are retained in assets/fonts/.

Final Godot 4.7.2 verification: import and startup PASS; chapter22, music30, combat46, impact17, controller49, Boss45, actual-contact integration18 and font48 assertions all PASS (275 total). Font sample has no missing glyphs; 12px CJK advance12/digits6, 24px advance24/digits12. All final test error logs are empty. Independent read-only review: No findings. Evidence is in ignored artifacts/*-console.log and font-glyph-report.json.

Static pose/effect contact sheets were inspected: parry-hero-contact.png, parry-boss-contact.png, parry-gradient-contact.png, parry-static-keyframes.png. No playthrough, repeated demonstration or video asset copying was performed. Reference observations supported phase separation, focused blade sparks and armor distinction; exact timings and all shipped art remain original. Subjective feel, difficulty, real audio output and in-motion display comfort still need user feedback.

Run the existing play.cmd. No new export/package is required for this milestone.

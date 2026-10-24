# Red-haired katana Boss — local visual revision

Base: local three-weapon commit7c536d1121c792093711992e4056b57a443856ff. Branch: feat/boss-redhair-local-20261024. Local only; no remote publication. Root play.cmd remains the entry.

The original adult swordswoman has a taller, separately re-authored head/shoulder/waist/leg construction, a narrow adult profile, layered auburn/red/copper hair, fitted dark armor and independently moving coat tails. The native128x128 cell, feet anchor48,116 and all19clips/78frames remain. Idle head moves up13px, shoulders14px, hips5px; torso grows9px and legs5px. Standing drawing is82px. No whole-image scaling or 3D input.

Idle/approach/shift/draw/two cuts/recover/cast/retreat/jump/slam/landing, ordinary and armored parry recoil, break/recovery, hurt and death all share the new identity. Existing blink visibility/reveal still uses those same controller clips. Hair has five warm levels; face and weapon remain small, sharp native pixels. Ghost and flash sheets use the same new alpha mask.

The fixture tests/fixtures/boss_blade_contract_7c536d1.json stores the previous version's exact hand/support, guard, tip, guard point, feet, frame mapping, phase progress and contact flags. All78rows are compared directly, both facings are checked through the real BladeGeometry module, and all300steel-line samples remain covered by drawn steel. All78raster cells change. This replaces the old historical requirement to preserve silver-haired reaction images byte-for-byte; it does not relax gameplay geometry.

Boss AI, body collider, health/damage, parry/guard-break logic, friend chart/barrage counts,203BPM/+245ms audio,04:25–05:03 blink window, rooms/portals and the new three-weapon attack profiles are outside this visual revision. Taller artwork keeps the old collision specification; no attack range is increased by the redesign.

Motion owns the original katana generator and Boss sheets; flight presentation is a separate owner on hero-only assets/renderer/wings; lead owns immutable baselines/tests, documentation, safe local commit; independent reviewer reads source and actual native-size game frames. Applied workflow: builder/core, Godot animation and bounded headless checks. The user performs continuous combat playtesting.

Local evidence: artifacts/boss-redhair/before-* snapshots, new contact/compare sheets and static800x450Boss-room frames. These are static pose fixtures with AI/audio/input playback disabled. A contact sheet or passing geometry check does not establish subjective beauty, animation timing or live-barrage readability.
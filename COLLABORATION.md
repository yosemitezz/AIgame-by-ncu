# Collaboration contract

Fresh Godot 4.7 2D pixel side-scroller. Baseline main: 8f676ac555596dd5c43f1eef0378b90774df6b4e. Preserve LICENSE. No old project code or Blender renders. All source/assets are original. Selected private listening track must never enter repository.

## Ownership
- Integration: project.godot, main.tscn, main.gd, assets/art/pixel_actor.gd (functional pixel placeholder), ui/hud.gd, tools/, tests/, README.md.
- Combat agent: actors/player.gd, actors/enemy.gd, combat/projectile.gd only.
- Boss/music agent: combat/boss.gd, audio/music_director.gd, data/music_timeline.json only.
- Level agent: levels/bellkeep.gd, docs/level-design.md only.
- Reviewer: read only, report defects; no edits or Git mutations.
- Cursor (`cursor/art-ui`): owns `assets/art/` (final art; `assets/art/pixel_actor.gd` stays with Integration until coordinated), `assets/vfx/`, `assets/ui/`, `assets/previews/`, `ui/` (except `ui/hud.gd`, Integration), `scenes/showcase_*.tscn`, `scripts/art/`, `tools/art/`, `docs/art/`. Does not edit combat/level/music owners' files or the gameplay `project.godot`. Handoff: `docs/art/HANDOFF.md`.

Do not reset user changes, force push, modify LICENSE, or edit another owner's file. Lead handles commits and pushes.

## Shared runtime API
Root Node2D `game` exposes `player`, `boss`, `story_safe: bool`, `checkpoint: Vector2`, `score: int`, `music: Node`.
- game.hero_attack(source: Node2D, damage: int, reach: float, combo: int) -> void
- game.emit_fx(kind: String, at: Vector2, direction: Vector2 = Vector2.ZERO, power: float = 1.0) -> void
- game.damage_player(amount: int, origin: Vector2) -> void
- game.spawn_projectile(at: Vector2, velocity: Vector2, friendly: bool = false) -> Node2D
- game.on_enemy_defeated(enemy: Node2D) -> void
- game.on_boss_defeated() -> void
- game.set_story_safe(value: bool) -> void (clears hostile projectiles when true)
- game.announce(text: String, seconds: float = 3.0) -> void
- game.on_boss_phase(phase: String) -> void
Enemies and boss group `enemies`, projectiles group `projectiles`; enemy `receive_hit(damage:int, origin:Vector2)`.

Player: extends CharacterBody2D. configure(game); facing:int, health:int, max_health:int, invuln:float, parry_timer:float, dash_timer:float, animation_state:String. receive_hit(amount, origin)->bool; revive(at:Vector2); parry_success()->void. Signals health_changed(current, maximum), died, state_changed(state, frame, facing), parried. Inputs move_left, move_right, jump, dash, attack, parry. Feet origin at bottom center. Collider 14x26 centered (0,-13). Sprite drawing calls preload('res://assets/art/pixel_actor.gd').paint(self,'hero',animation_state,frame,facing), body 40x48 anchor (20,44). Frames hand/program-authored pixels, no 3D.

Enemy: configure(game,kind,at), kind 'sentry'/'wisp'/'elite', health, max_health, dead, receive_hit; enemy defeated callback once. Uses same pixel painter kind and state.

Projectile: configure(game,at,velocity,friendly), friendly:bool, clear()->void, reflect()->void; proximity hit must first honor parry_timer then player invulnerability. Hostile gold, friendly cyan. No beat-miss damage.

Boss: configure(game,at), health, max_health, phase:String, dead; receive_hit; start_encounter(); group enemies. Uses game.music signals and game.story_safe. Defeat callback once. Contact windows determine parry; boss melee can call player.parry_success() and stagger if in reach and parry_timer>0. Must chase/reposition, telegraph, multi-pattern, respect music phases. Draw via pixel painter kind 'boss'.

Music director: signal beat(index:int); signal section_changed(section:String); signal phrase_boundary(index:int); configure(game); start_score(); stop_score(); request_advance(); current_section:String ('fixed','random','rest','final'); bpm:float; total_beats:int. fixed attack start only on beat events, health threshold queues random exit at phrase boundary, otherwise loops. Rest must disable both damages and clear old attacks. Original generated distributable synth placeholder, timeline JSON config, never copy private song.

Level: extends Node2D. const SPAWN:Vector2; CHECKPOINT:Vector2; BOSS_TRIGGER_X:float; BOSS_POSITION:Vector2; LEVEL_END:float. const PLATFORMS:Array (Rect2), ENEMIES:Array (dict kind, at), SHARDS:Array (Vector2), ZONES:Array (dict x,title,hint). setup(game) builds world physics & original pixel architectural drawing, no mobs spawned (lead reads ENEMIES). Floor around y=300; jump max height~68 from -340 and gravity900; speed180 (safe required gaps <=100, steps <=54), dash420. Main route continuous to boss at x~3000. Optional upper route. Level owns geometry and art only; lead owns gates/progression.

HUD presentation signals emitted by root: hud_updated(state:Dictionary), boss_phase_changed(phase:String), warning_issued(kind:String,at:Vector2,duration:float), vfx_requested(kind:String,at:Vector2,direction:Vector2,power:float), animation_event(actor:Node,state:String,frame:int,facing:int). Functional HUD listens state dict hp/max_hp/shards/zone/hint/boss_hp/boss_max/phase/beat/section/outcome. VFX may connect signal without altering damage logic.

Actual split: gameplay uses its independent work directory on feat/pixel-bellkeep-20261024. The original checkout remains on cursor/art-ui. Always inspect branch/worktree before writing; do not switch another editor's checkout.

## Combat feel revision ownership

User feedback authorizes improving the integrated game's combat/animation/effects, while preserving the Cursor checkout and its committed asset source files. Baseline before revision is ff65e9e. Committed art/UI history integrated from 0fdf07b (containing remote art milestone 1dd72ed) in gameplay worktree only. Main/default branch stays unchanged.

- Combat revision: actors/player.gd, actors/enemy.gd, tests/combat_feel_test.gd.
- Motion/VFX revision: presentation/actor_renderer.gd, presentation/combat_vfx.gd, presentation/feel_frames/, tools/generate_combat_frames.py, docs/feel-frames.md. New assets only; do not overwrite Cursor asset sources.
- Lead integration: main.gd, combat/boss.gd, combat/projectile.gd, combat/impact_feedback.gd, audio/impact_sfx.gd, assets/art/pixel_actor.gd (existing integration adapter), ui/hud.gd, tests/impact_feedback_test.gd, launch/test scripts and delivery docs.
- Independent reviewer: read only.

New combat API: actor set_impact_freeze(seconds:float), public combat_freeze:float (local actor freeze only; no Engine.time_scale or scene pause); player public attack_serial:int, attack_phase:String ('windup','active','recover','none'), combo:int. During active window player calls game.hero_attack each physics tick; root deduplicates targets per attack_serial. Capture input before local freeze and retain one queued combo intent through hit-stop. Presentation mapping windup/attack/recover uses actual combat stage timing. game.request_impact(source:Node,target:Node,heavy:bool=false,parry:bool=false) centralizes local freeze, small capped camera impulse and short original sound. Music, projectiles, and the rest safety state continue on their own clock. story_safe overrides pending attacks and local freeze.

One playable entry remains play.cmd in this gameplay directory. Do not operate Cursor agent or Cursor worktree. No manual/automated playthrough; only bounded logic tests and fixed keyframe captures.

Committed Cursor damage-zone palette update a2c857b is integrated. New uncommitted hero art changes detected in the Cursor checkout are deliberately excluded and left untouched. Presentation revision lives in a separate new directory; no user art source files are rewritten.

## Parry contact / posture revision

Baseline b262ed4 on feat/combat-feel-20261024. Cursor remote still a2c857b; its ongoing uncommitted hero/world artwork is excluded and left untouched. No reference attachment was visible. User requests colorful gradient flowing parry effects in the existing 2D pixel style.

- Controller agent: actors/player.gd, actors/enemy.gd, tests/parry_controller_test.gd only. Extend parry_success(target:Node=null, contact:Vector2=Vector2.INF, kind:String='melee', token:int=-1)->bool; genuine current parry window, front contact, safe/dead/paused and per-source/token duplicate guards. Keep legacy defaults for existing tests. Success emits one game.on_parry_contact(self,target,contact,kind) if method exists; fallback old fx+request only for minimal mocks. Public parry_phase ('ready','recoil','recover','none'), stage timing/progress. New animations parry_recoil/parry_recover. Enemy supplies actual contact and unique attack serial.
- Boss agent: combat/boss.gd, tests/boss_parry_test.gd only. Unique attack serial, slash is parryable; charge explicitly unblockable (coral warning kind unblockable_charge), projectile patterns retain reflection. On accepted contact cancel pending/windup/charge/release, add posture once, close-range recoil then recovery; 3 posture pips causes guard break/counter window then safe reset. No large knockback or repeat reward/lock. Determine would-break before calling player.parry_success(self,contact,'guard_break' if threshold else 'melee',serial). Expose guard_posture/guard_max/reaction_state/reaction_progress. Preserve beat/phrase rules and rest cleanup.
- Motion/VFX agent: presentation/actor_renderer.gd, presentation/combat_vfx.gd, presentation/parry_frames/, tools/generate_parry_frames.py, docs/parry-motion.md only. Draw explicit hero and Boss rebound/break poses; directional blade-contact sparks and restrained cyan/violet/pink/gold gradient flow. Events blade_parry, projectile_parry, guard_break; existing parry remains mock compatibility. Do not edit previous feel_frames generator/source or Cursor-owned source assets. Follow actual parry/reaction progress, not unrelated age for poses. Unblockable warnings coral; no fullscreen bloom.
- Lead: main.gd, combat/projectile.gd, combat/impact_feedback.gd, audio/impact_sfx.gd, ui/hud.gd, tests/parry_integration_test.gd, verification/docs/commit.
- Reviewer: independent read only after implementation.

Root on_parry_contact(defender,source,contact,kind) dispatches exactly one VFX/sound/local hold for genuine accepted contact. No perfect-parry mechanic is added. Projectile reflection and melee clashes are distinct. No Engine.time_scale writes; music remains independent. Same play.cmd entry, bounded tests and static keyframes only.


## Unified main migration

User selected this integrate/vfx-primary checkout as the main project. Baseline d6133d9586a5a175410f25fceb2384f264defb22 includes newer layered sounds and the longer hero; preserve those commits and source assets. Lead owns main/project/HUD/projectile/enemy integration and delivery. Player agent owns player/attack profile/query; Level owns bellkeep; Motion owns actor renderer/katana and FX; Boss owns boss/friend_rhythm/authored config/hazards; independent reviewer is read only. Source milestone e895 is selectively ported, not merged wholesale. No edits to other checkouts, main branch or original boss_attack subproject/audio/chart. Runtime music remains the distributable placeholder.

## Current Boss duel milestone (after 06b06ad)

The selected main worktree is integrate/vfx-primary. Preserve all concurrent player, ghost-shadow, smear and general VFX work. No main-branch merge, reset, clean or force push. The owner's later explicit approval for the already tracked selected recording supersedes the historical private-recording restriction for that one file only; this milestone does not edit or copy audio.

- Boss runtime: combat/boss.gd, data/boss_duel_profile.json, tests/boss_duel_runtime_test.gd.
- Shared blade geometry: combat/boss_blade_geometry.gd and its geometry test; maintain the existing full-song emission coverage without reducing expectations.
- Boss presentation: presentation/katana_visual.gd, presentation/katana_frames, the original katana generator and a focused visual test. No hero/general VFX files.
- Terrain validation: read-only level audit and tests/boss_navigation_test.gd; no level edits.
- Lead: this contract, verification runner, milestone documentation, selected-source validation and Git.
- Independent review: read-only implementation review.

The friend source plans remain authoritative for event times and projectile counts. New close-combat actions have separate identity/telemetry and fit available recovery gaps. The visible pixel blade and its contact sweep use the same guard/tip frame landmarks. Ordinary contact cancellation must not invalidate independent fixed/laser/barrage plans; narrative rest, death and transport generation changes remain global cleanup boundaries. All checks are bounded automation or static keyframes; the user performs playtesting.
## Current response / rooms / climax release

The user requested main publication for this verified wave, including concurrent knight/three-sword commit118edf6. Automatic approval did not recognize that later authorization and rejected main publication. Keep main unchanged until that blocker is resolved; do not infer future main-publishing authorization. Current verified code stays on integrate/vfx-primary. Root play.cmd is the complete-game entry, and boss_attack remains the preserved friend subproject. No force push, reset/clean, branch deletion or credential persistence is part of this work.

## Local three-weapon revision (after verified main a8b1bcc)

The earlier main-publication block was resolved with the user's later explicit authorization; main a8b1bcc contains the verified ff3151a tree. That approval covered the previous wave only. This new weapon revision stays LOCAL on feat/weapon-identities-local-20261024; do not push without a new instruction.

Controller: actors/player.gd, combat/attack_profile.gd, combat/melee_query.gd, data/hero_attack_profiles.json and weapon_identity_controller_test. Motion: hero_rig/generate_hero_atlas, hero-only feel/parry sheets, actor_renderer/combat_vfx, vfx/fx_layer and weapon_motion_test/contact capture. Lead: main.gd, combat/sword_wave.gd, data/hero_sword_wave.json, impact_feedback, integration tests, docs and local Git. Regression: four existing migration/weapon/animation fixtures and verification list. Independent reviewer: read only. Boss/map/music/source-project files are outside this revision.

## Local redhair Boss / wing-flight presentation revision

Baseline7c536d1; current local branch feat/boss-redhair-local-20261024. No push/main approval is implied. Katana art owner edits generate_katana_boss and katana_frames only; hero-flight owner edits hero_rig/generate_hero_atlas, hero-only sheets/actor_renderer/light_wings and necessary ghost snapshot fields only. Lead owns immutable contract fixtures, focused tests/verification and docs/local Git. Review is read only. Do not alter Boss logic/geometry, player physics/input/mobility, three-weapon profiles/attacks, music/score or maps. Keep all existing user changes and prior branch history.

## Local flight/VFX/chapter polish 2026-10-25

Current branch feat/polish-story-local-20261025 preserves the upstream README-only8a6dd7d cleanup and all local8a1b103/7c536d1 history. User explicitly requested new three-weapon silhouettes and inertial rear carry; old weapon-raster equality is intentionally superseded, while movement/range/damage/timing remain protected. Flight owns hero rig/renderer/wings and hero sheets. Attack VFX owns fx_layer/combat_vfx. MovementTrail owns motion_blur/new history backend. Root owns hit-contact integration, main/HUD hooks, local saves and local Git. Story state owns data-driven chapter; chapter visuals own new eye/aura/overlay; controller owns orchestration. Independent review is read only. No push/main publication is authorized this wave. User's original amnesia/eye-trust/kill-corruption/Boss-rescue/ambush ending is the narrative authority; friend backstory is deferred, not canon.

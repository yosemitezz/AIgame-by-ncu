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

## Selective combat fusion

Pinned sources: our contact/posture/HUD milestone 63017fc7b4fcac87892dca68b066210ec610e592; user-preferred VFX branch 206f0b77c6e68ab803b41829ab61dab759f190e5; common ancestor a2c857b. Both histories are retained in this merge. Source gameplay-vfx checkout has an uncommitted vfx/fx_layer.gd edit; only committed source is used and that checkout is untouched.

Static comparison: source branch adds vfx/fx_layer.gd (layered swept crescents, flowing hue ramps, additive highlights, larger frame snapshots/body ribbons and projectile tails); its actor attack scripts are unchanged from the ancestor. Adopt that visual layer as the single VFX owner; retain current phase-driven sprites, contact/parry/posture logic, local impact service, music and pixel HUD. Retain the source's compatible optional elite gallery and append-only shard indices.

- Fusion VFX owner: vfx/fx_layer.gd, tests/fused_fx_test.gd. Adapt to actual phase/serial, current parry/armor events, rest cleanup and snapshot metadata; fix projectile cache typing; no damage/time/camera/audio writes. It is the only instantiated effect layer. Legacy presentation/combat_vfx.gd remains an uninstantiated historical source.
- Cadence owner: actors/player.gd, tests/combat_feel_test.gd, tests/fused_cadence_test.gd. Target original preferred branch total cut times .27/.29/.37, keeping windup/active/recover and genuine contact windows. Input/parry/rest behavior retained.
- Lead: main.gd wiring, combat/impact_feedback.gd, tests/impact_feedback_test.gd, tools/verify.ps1, fixed capture/validation/docs, merge commit and push.
- Independent reviewer: read-only final diff and source safety check.

Single authorities: actor owns input/attack serial; root hero_attack owns accepted damage/deduplication; on_parry_contact owns accepted parry dispatch; ImpactFeedback owns sound/local hold/camera; FxLayer listens once to presentation signals. No parallel old/new effect nodes, no global time-scale writes. Cursor source worktrees and main/default branch are not edited.

## Fused gradient presentation milestone

The fusion keeps the preferred `integrate/vfx-primary` presentation at commit
`205b8e74f151c845c7279e69a90e0b23c415f839`, including six slash personalities,
four hit looks and running ribbons. This commit descends from `cursor/gameplay-vfx`
`6e189a954c84e2b76f3dd5127933416a7fae90bb` and retains the stable gameplay history
`63017fc7b4fcac87892dca68b066210ec610e592`. Source working directories are read only.

Runtime authority: player owns input/attack phases, root owns hit deduplication,
ImpactFeedback owns local hold/camera/audio, FxLayer owns all active effect drawing,
and MusicDirector owns its independent score clock. The former CombatVFX script is
retained as source history and is not instantiated. Projectile nodes draw only their
hit-readable cores. Attack VFX follow the real phase/serial and never apply damage.

Fusion file owners: motion agent `vfx/fx_layer.gd`, `tests/fused_fx_test.gd`;
combat agent `actors/player.gd`, cadence tests; lead wiring/tests/docs/Git;
independent reviewer reads only. Future dungeon work uses separate level, traversal,
and mob owners. Boss design remains with the user's collaborator; only required
compatibility fixes are in scope. Do not edit other working directories or main.


## Dungeon depths / full pixel UI milestone

Developed on feat/dungeon-depths-20261024 from the verified fusion 90319f4. Stable
playable worktree remains untouched during this implementation. Owners: level
levels/bellkeep.gd + layout docs/tests; traversal actors/player.gd + traversal test;
mobs actors/enemy.gd + barrage test; presentation actor_renderer, dungeon_frames,
hero generator, FxLayer; lead main/project/projectile/HUD/integration/tools/docs/Git;
reviewer read only. No Cursor source working files are imported.

Level APIs: climb_at(feet)->{id,kind,rect}, water_at(feet)->bool,
try_interact(feet)->bool, interaction_hint(feet)->String, room_at(feet)->Dictionary,
get_opened_ids/restore_opened_ids/reset_interactions. Foot bounds include climb endpoints.
Root owns E interaction, one pause/map overlay, spatial shrine/Boss triggers and retry
metadata. Controller owns climbing and shallow-water speed; action input still has one
owner. Projectile style is an optional fourth root spawn argument; cap returns null.
Mobs must consume finite layers even if capacity rejects a shot. Fine Boss design is out
of this milestone. Narrative proposals are recorded in docs/story-direction.md only.


## Katana / wide-melee milestone

User explicitly authorizes the new Boss appearance/animation and adaptation of friend
PR1. Fine final moves remain unprovided. Preserve upstream integrate/vfx-primary and
all Cursor/integrate uncommitted hero/UI files; never wholesale merge the PR's audio.
New own branch feat/boss-katana-art-20261024 is based on251e478. Root updates the old
playable worktree only by clean, inactive, checked fast-forward after verification.

Owners: Boss agent combat/boss.gd, friend_rhythm and temporary move data; combat
agent player/Profile/Query; hero artist new hero_attack_frames+generator; Boss/FX
artist katana_frames+generator, FxLayer, SpeedFeedback, outline shader; root visual
adapters, main, HUD, integration/tests/docs/Git. Reviewer is read only. Shape source
is data/hero_attack_profiles.json; no independent VFX hit radius. Root is the only
hit ledger/damage entry and Impact the only hit-stop/shake/audio service. Renderer
reads get_presentation_pose and immutable ghost snapshots. F3 controls presentation
only. New mob species are a subsequent milestone, not a reason to delay this one.

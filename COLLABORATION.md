# Collaboration contract

Fresh Godot 4.7 2D pixel side-scroller. Baseline main: 8f676ac555596dd5c43f1eef0378b90774df6b4e. Preserve LICENSE. No old project code or Blender renders. All source/assets are original. Selected private listening track must never enter repository.

## Ownership
- Integration: project.godot, main.tscn, main.gd, assets/art/pixel_actor.gd (functional pixel placeholder), ui/hud.gd, tools/, tests/, README.md.
- Combat agent: actors/player.gd, actors/enemy.gd, combat/projectile.gd only.
- Boss/music agent: combat/boss.gd, audio/music_director.gd, data/music_timeline.json only.
- Level agent: levels/bellkeep.gd, docs/level-design.md only.
- Reviewer: read only, report defects; no edits or Git mutations.
- Cursor (`cursor/art-ui`): owns `assets/art/`, `assets/vfx/`, `assets/ui/`, `assets/previews/`, `ui/`, `scenes/showcase_*.tscn`, `scripts/art/`, `tools/art/`, `docs/art/`. Bootstrapped art-preview `project.godot` + main showcase scene until Integration lands gameplay main; coordinate before rewriting project settings. Does not edit combat/level/music owners' files. Handoff: `docs/art/HANDOFF.md`.

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

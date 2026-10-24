# Art / UI contract for Cursor

Native frame: 640x360, integer scaling, nearest filtering, no 3D renders. Fantasy palette: deep navy #0c1025, slate #394462, muted stone #77839c; hostile telegraphs gold #e9bb68, parry/reflected shots cyan #72ece2, damage coral #ef7678. Keep hostile bullets visually separate from decoration. No mandatory specific protagonist identity.

## Character animation
Foot origin = (0,0), facing +1 right/-1 left. Hero and sentry frame 40x48, pixel anchor (20,44); 14x26 physics collider at (0,-13). Boss frame 80x80 anchor (40,76). Keep silhouette anchored; opacity is presentation only, never damage logic.

State names: idle, run, jump, fall, dash, attack, parry, hurt, dead. Frames are zero-based. Placeholder uses six frames/state; run may cycle eight; final art can map externally. Public actor fields `animation_state`, `frame`, `facing`; player also `combo` 1..3. Attack active windows belong to gameplay code. Suggested eventual files: `assets/art/hero/<state>.png`, `assets/art/boss/<state>.png`, matching SpriteFrames resource. Functional painter lives at `assets/art/pixel_actor.gd` and is explicitly replaceable after coordination.

## Root presentation signals
- `hud_updated(state: Dictionary)` keys hp/max_hp/shards/zone/hint/boss_hp/boss_max/phase/beat/section/outcome.
- `boss_phase_changed(phase: String)`.
- `warning_issued(kind: String, at: Vector2, duration: float)` for readable ground/aim warnings.
- `vfx_requested(kind: String, at: Vector2, direction: Vector2, power: float)`; kinds hit, parry, dash, jump, death, pickup, checkpoint, burst.
- `animation_event(actor: Node, state: String, frame: int, facing: int)`.

Presentation must not trigger damage or change beat/phrase progression. Root `story_safe` prohibits both sides' damage and clears existing hostile attacks. A parry is a contact during the player's parry window. Never damage for missing a music beat.

UI proposed owner: `ui/`; final sprite owner: `assets/art/`; effects owner: `assets/vfx/`. Integration may initially create functional pixel placeholders in these directories. Read current Git status and coordinate before editing those same files. Suggested branch `cursor/art-ui` with a separate directory; no force pushes.

# Boss Room + Heavy-Clash Skill Update — Design

- Date: 2026-10-25
- Branch: `feat/polish-story-local-20261025`
- Source of the ported layer: `IF_story(1)/IF_story/IF/` (read-only reference, never mounted at runtime)
- Scope: the bellkeeper Boss only. No story-layer port, no other enemies, no dungeon changes.

## 1. Goal

Update the current Boss encounter so that the music chart drives a real, damage-bearing
**heavy clash** skill, while keeping every skill the current branch already ships:

- blink / source cut (`_try_start_blink`, `_begin_authorized_*`)
- duel double slash (`_try_duel_on_beat`)
- authored chart actions (`aim`, `teleport`, `center`, `dash`, `ring`, `fan`, `side_spray`)
- guard posture, parry recoil, guard break, armor
- health seal at 50 % during `fixed` / `random`
- phase/rest/final boundaries, room flow, chapter integration

The heavy clash is an **additional beat-timed skill**. It is not a replacement for the authored
chart actions and not a replacement for ordinary parry.

To host that skill the Boss gets the attachment's camera-following infinite room, a five-tap
audio calibration, passive sustain, and phrase-boundary projectile cleanup. Those are supporting
pieces, not the goal by themselves.

## 2. Non-goals

- Do not port the IF story layer (`story/`, dialogue, eye, aura, save, chapter).
- Do not replace `combat/boss.gd` with the attachment's older, simpler Boss.
- Do not disable ordinary parry inside the Boss room. The attachment does; this branch does not.
- Do not migrate health to floats or to a half-heart HUD.
- Do not touch dungeon level geometry, enemies, weapons, or chapter story data.
- Do not commit the listening song, rendered 3D assets, credentials, local logs, or personal paths.

## 3. Verified current state

The current branch already has:

- `main.gd` full-song integration, `room_id` / `room_flow` / `_room_prepare`, `story_safe`,
  `boss_started`, `outcome`, `_heavy_lane`, `on_parry_contact`, `damage_player`.
- `combat/boss.gd`: infinite-room support (`set_infinite_room`), player-centred attack arena,
  chart-authored actions, blink, duel, guard posture, integer health, health seal.
- `actors/player.gd`: integer health `8/8`, ordinary parry (`parry_success`, `PARRY_WINDOW`),
  dash-invuln, `set_boss_room_mode` (flight + wings only).
- `audio/music_director.gd`: sole time authority; full-song transport, generation counter,
  `sample_input_chart_time`, `get_heavy_groups` (107 groups), rest safety.
- `ui/heavy_lane.gd`: cosmetic ±125 ms preview, never damages or consumes input.
- `levels/boss_chamber.gd`: finite chamber mounted for `room_id == "boss"`.
- `combat/projectile.gd`: no fade state.

The branch does not have: `levels/boss_room.gd`, `combat/audio_calibration.gd`,
`ui/calibration_overlay.gd`, `boss.perform_heavy_clash`, `no_hit_stun`, heavy pose,
`player.HEAVY_PARRY_WINDOW`, parry press history, `main.heal_player`, passive boss-room heal,
`main.fade_boss_projectiles`, `full_song_transport.set_offset_ms`,
`music_director.replace_offset_ms`.

## 4. Locked decisions and deliberate adaptations

| Topic | Attachment | This design | Why |
|---|---|---|---|
| Ordinary parry in Boss room | Disabled (`kind != "heavy_clash"` rejected) | **Kept enabled** | Current guard posture, blade, duel, and a large test suite depend on it. Heavy clash is additive. |
| Health / damage | `float`, 0.5 per hit, half-heart HUD | **Integer**, 1 per hit, 8 hearts | Avoid a branch-wide health migration; everything already treats health as `int`. |
| Sustain | 1 HP / 4 s plus 1 HP on heavy success | Same numbers, integer | Keeps the attachment's intended pace without float health. |
| Boss room | `levels/boss_room.gd`, infinite 5-layer platforms | Port, palette-matched to `boss_chamber.gd` | Needed to host the new skill; visual continuity with the current Boss. |
| Boss arena | Room-owned `get_attack_bounds` | **Keep** current player-centred `get_attack_arena` (720×440) | It is already tuned by authored actions, blink, and duel tests. The room does not re-route it. |
| `BossChamber` | Replaced | **File kept**, no longer mounted by `main` | Existing geometry/navigation tests still load it directly. |
| Calibration | Always on entry | On entry, **auto-skip** for non-full-song, headless, Dummy driver, or <5 regular heavy groups | Headless tests and placeholder mode must start instantly; real-device players still calibrate. |
| Heavy clash cadence | Every chart heavy group | Every chart heavy group | That is the skill-set update the user asked for. |
| Heavy clash during Boss parry/guard reaction | Fires anyway | **Skip** that group (`perform_heavy_clash` returns false) | Preserves the player's parry reward and avoids an unavoidable hit during recoil. |
| Hit stun in Boss room | `_hurt_timer = 0`, `hurt_flash = 0` | `_hurt_timer = 0`, **keep `hurt_flash`** | No stagger, but hits still read visually. |

## 5. Architecture overview

```
MusicDirector (sole time authority)
  ├─ FullTransport.chart_time / generation / offset
  ├─ SourceParser.heavy_groups + action phrases
  └─ signals: beat, section_changed, transport_changed

levels/boss_room.gd (BossRoom)
  ├─ calibration (audio preview + RefCounted math + overlay)
  ├─ heavy cursor: emits heavy_clash_requested(event_time)
  ├─ infinite platform bodies around the player
  └─ signals: calibration_complete, heavy_clash_requested, heavy_history_cleared

main.gd
  ├─ owns BossRoom mount, calibration gate, Boss creation
  ├─ _on_heavy_clash_requested → boss.perform_heavy_clash(player)
  ├─ _process_heavy_resolutions → player.parry_success(..., "heavy_clash", token, event_time)
  ├─ heal_player / passive 4 s heal
  └─ fade_boss_projectiles

combat/boss.gd
  ├─ perform_heavy_clash(target) -> bool
  ├─ no_hit_stun
  ├─ heavy pose (time/facing) + gold arc
  └─ phrase-boundary projectile fade calls

actors/player.gd
  ├─ parry press history sampled from music chart time
  ├─ consume_parry_press_within → perfect / good / miss
  ├─ parry_success(..., "heavy_clash", ..., judged_time)
  └─ receive_hit(..., bypass_invuln)
```

## 6. Skill-set update: heavy clash

### 6.1 Boss API (`combat/boss.gd`)

New fields:

```
var no_hit_stun: bool = false
var _heavy_pose_time: float = 0.0
var _heavy_pose_facing: int = 1
const HEAVY_POSE_SECONDS: float = 0.20
```

`perform_heavy_clash(target: Node2D) -> bool`:

1. Reject when `dead`, `not _active`, `target` invalid, `game.story_safe`,
   `_reaction_blocks_attacks`, `_posture_lockout > 0.0`, or `not _uses_full_song()`.
2. `var direction: int = int(target.facing)` (the player's facing, i.e. toward the Boss).
3. `_cancel_contact_sequence()` — this is the existing preemption primitive. It cancels the
   current blink/duel/blade and the current serial's non-projectile authored actions, clears
   `_authored_dash` / `_authored_shift` / `_warning_geometry`, and retains `ring` / `fan` /
   `side_spray` projectiles (those are retired separately by projectile fade).
4. `facing = -direction` (face the player); `_heavy_pose_facing = direction`.
5. `_heavy_pose_time = HEAVY_POSE_SECONDS`.
6. `global_position = target.global_position + Vector2(float(direction) * 58.0, 0.0)`;
   `velocity = Vector2.ZERO`.
7. `attack_serial += 1`; `contact_token = attack_serial * 8`;
   `attack_parryable = true`; `attack_armored = true`.
8. `game.emit_fx("enemy_dash", global_position + Vector2(0, -26), Vector2(facing, 0), 1.0)`;
   `game.emit_fx("enemy_slash", global_position + Vector2(facing * 20, -26), Vector2(facing, 0), 1.5)`;
   `queue_redraw()`.
9. Return `true`.

The attachment does not clear an in-flight authored dash/shift. This port does, through
`_cancel_contact_sequence()`, so no phantom dash finishes after the teleport.

Integration points:

- `_physics_process`: decrement `_heavy_pose_time` at the existing `_hurt_timer` decay site
  (`combat/boss.gd:365`) with `_heavy_pose_time = maxf(0.0, _heavy_pose_time - delta)`. That site
  is only reached while the fight is live, so hit-stop still freezes presentation, and a hit never
  freezes the pose.
- `_physics_process` movement chain: insert `elif _heavy_pose_time > 0.0:` immediately before the
  final `else: _pursue_player()` branch (`combat/boss.gd:427`), holding `velocity = Vector2.ZERO`
  (and `velocity.y = 0.0` in the infinite room) and `animation_state = "draw"`. Without this branch
  the Boss would walk into the player during the pose.
- `_begin_attack`, `_begin_authored_pattern`, and `_try_duel_on_beat`: add
  `_heavy_pose_time > 0.0` to their reject gates. The authored-phrase path runs every physics
  frame, so without this gate the next chart phrase re-arms an attack inside the clash pose.
- `_cancel_all_attacks`: clear `_heavy_pose_time = 0.0` (safety, rest, outcome, transport epoch).
- `_draw`: after `Pixels.paint`, when `_heavy_pose_time > 0.0`, draw the gold telegraph on the
  side that faces the player using the existing windup convention (`combat/boss.gd:1683-1692`):
  five 3×3 rects at `Vector2(-float(_heavy_pose_facing) * (26 + i * 6), -25)` for `i in 5`, plus a
  gold bar across the head. The Boss faces `-direction` while `_heavy_pose_facing` stores the
  player's `direction`, so the player-facing side is `-_heavy_pose_facing`. Draw with
  `Color(ink, _heavy_pose_time / HEAVY_POSE_SECONDS)` so the telegraph fades with the pose.
- `get_presentation_pose`: insert `elif _heavy_pose_time > 0.0: state = "heavy_clash"` immediately
  after the existing `reaction` branch and before the `blink` branch. The rest of the priority
  chain is unchanged.
- `receive_hit`: change the stagger gate to `_hurt_timer > 0.0 and not no_hit_stun`; at the end set
  `_hurt_timer = 0.0 if no_hit_stun else 0.09` and keep `hurt_flash = 0.11`.
- `main` sets `boss.no_hit_stun = true` only in the Boss room.

### 6.2 Player API (`actors/player.gd`)

Constants and fields:

```
const HEAVY_PARRY_WINDOW: float = 0.095
const HEAVY_PERFECT_WINDOW: float = 0.040
var boss_room_mode: bool = false
var _parry_press_times: Array[float] = []
var last_parry_grade: String = ""
```

Press sampling:

- In `_capture_input`, on `Input.is_action_just_pressed("parry")`, still set `_parry_buffer = 0.12`
  and additionally call `_record_parry_press()` when `boss_room_mode`, not `dead`, not
  `story_safe`, and not paused.
- `_record_parry_press()` reads `music.sample_input_chart_time()` (falling back to
  `get_chart_time()`), then calls `record_parry_press_at(at)`.
- `record_parry_press_at(at)` appends and prunes entries older than `at - 3 × HEAVY_PARRY_WINDOW`.
- `consume_parry_press_within(event_time, half_window = HEAVY_PARRY_WINDOW) -> String`: find the
  press closest to `event_time` within `half_window`. When one exists, remove exactly that entry
  and return `"perfect"` (≤ `HEAVY_PERFECT_WINDOW`) or `"good"`. When none exists, remove nothing
  and return `"miss"`.
- `has_parry_press_within` is a read-only query used by tests.
- `clear_parry_press_history()` clears the array, `last_parry_grade`, and `_parry_seen` (the
  transport epoch invalidates every outstanding heavy token).

`parry_success` gains `judged_time: float = NAN` as the fifth parameter. The heavy branch runs
before the `parry_timer <= 0.0` gate and pre-checks the token, so a duplicate resolution never
consumes a press:

```
if kind == "heavy_clash":
    if not boss_room_mode or not is_instance_valid(target):
        return false
    if token >= 0:
        var key: String = "%d:%d" % [target.get_instance_id(), token]
        if _parry_seen.has(key):
            return false
    var at: float = judged_time
    if not is_finite(at):
        var music_node: Variant = game.get("music")
        at = float(music_node.get_chart_time()) if is_instance_valid(music_node) else 0.0
    last_parry_grade = consume_parry_press_within(at)
    if last_parry_grade == "miss":
        return false
elif parry_timer <= 0.0:
    return false
```

The restructure details (current `parry_success` is `actors/player.gd:906`):

- Keep the dead/story-safe clear-and-return and the `game`/`_parry_paused()` guards first.
- Move the `parry_timer <= 0.0` check into the `elif` shown above, so it gates only non-heavy kinds.
- Extend the kind whitelist at `actors/player.gd:912` to include `"heavy_clash"` (or bypass it in
  the heavy branch).
- For `heavy_clash`, skip the default-contact, contact-distance, and facing checks; `main`
  supplies a real finite contact and token.
- The existing token-dedupe block at `actors/player.gd:928-934` records the token for heavy too.
- Keep the normal `_cancel_attack`, recoil, `invuln = max(invuln, 0.18)`, `parried` signal, and
  `game.on_parry_contact` call.

**Do not** add the attachment's `if boss_room_mode and kind != "heavy_clash": return false` line.

`receive_hit(amount: int, origin: Vector2, bypass_invuln: bool = false)`:

- Reject when `dead`, `amount <= 0`, or `story_safe`.
- Reject when `invuln > 0.0` **unless** `bypass_invuln`.
- Everything else unchanged (integer damage, 0.8 s invuln, knockback, `health_changed`).

`set_boss_room_mode(enabled)` sets `boss_room_mode = enabled`, clears press history and
`last_parry_grade`, and keeps the existing flight/wing behaviour.

### 6.3 Main lifecycle (`main.gd`)

New state:

```
const BossRoom = preload("res://levels/boss_room.gd")
const HEAVY_RESOLVE_GRACE: float = 0.020
var _calibrating: bool = false
var _heavy_resolutions: Array[Dictionary] = []
var _heavy_generation: int = -1
var _boss_heal_clock: float = 0.0
```

`HEAVY_RESOLVE_GRACE` keeps judgement one input-capture margin past the far edge of the window, so
a press stamped at +95 ms is already in `player._parry_press_times` when the resolution runs. It is
not extra leniency: grading still measures the distance from `entry.time`.

Mount:

- `_mount_room("boss")` creates `BossRoom` instead of `BossChamber`.
- Do **not** blanket-disable `StaticBody2D` collision for the Boss room; those bodies are the
  infinite platforms. Guard the old disable loop with `level is BossChamber` so it can never
  reach `BossRoom`.
- Connect `calibration_complete`, `heavy_clash_requested`, `heavy_history_cleared` after
  `level.setup(self)` and before `start_room_entry()` can emit.
- Clear `_heavy_resolutions`, reset `_heavy_generation = -1`, reset `_boss_heal_clock = 0.0`,
  `_calibrating = false`. `_mount_room` for either room clears pending heavy state.
- `player.set_boss_room_mode(room_id == "boss")` stays where it is today.

Start sequence:

- `_finish_room_preparation`: the dungeon branch keeps today's `set_story_safe(false)` /
  `player.set_physics_process(true)` / tap reset. For `room_id == "boss"`, reset direction taps
  and call `_start_boss()` **without** unlocking: `_start_boss` owns the story-safe and physics
  state from that point, and calibration keeps the player locked until it completes.
- `_start_boss(calibrate: bool = true)`:
  1. Return if `boss_started` or `outcome != ""`.
  2. Mount the Boss room if `room_id != "boss"`.
  3. Unavailable score (`requested` and not `ready`): `set_story_safe(true)`, announce the same
     retry message as today, `player.set_physics_process(true)` so `E`/`R` remain usable, return.
  4. If `calibrate` and `level.has_method("start_room_entry")`: set `_calibrating = true`,
     `set_story_safe(true)`, `player.set_physics_process(false)`, call
     `level.start_room_entry()`, then announce the calibration prompt only if `_calibrating` is
     still true, and return. A silent skip inside `start_room_entry()` has already completed and
     started the battle synchronously, so announcing afterwards would cover the live fight.
  5. Otherwise call `_begin_boss_battle()`.
- `_on_boss_calibration_complete(offset_ms)`:
  1. Return if `room_id != "boss"`, `boss_started`, or `outcome != ""`.
  2. `_calibrating = false`.
  3. `music.replace_offset_ms(offset_ms)` when available (no-op when already equal or
     non-full-song). This must run before the score starts.
  4. `set_story_safe(false)`; `player.set_physics_process(true)`.
  5. `_begin_boss_battle()`.
- `_begin_boss_battle()`:
  1. Create the Boss as today: `Boss.new()`, `process_mode = PROCESS_MODE_PAUSABLE`,
     `z_index = 2`, add child, `configure(self, room_spec["boss_spawn"])`,
     `set_infinite_room(true)`, `no_hit_stun = true`.
  2. `boss_started = true` (as today, before `start_encounter`, so no re-entrant start).
  3. `boss.start_encounter()` — this is what calls `music.start_score()` and increments the
     transport generation.
  4. `if level.has_method("begin_battle"): level.begin_battle(boss)` (BossChamber has no such
     method; this keeps capture/tests that mount other rooms from crashing).
  5. `_heavy_generation = music.get_transport_generation()` (after the start, never before),
     `_boss_heal_clock = 0.0`, clear `_heavy_resolutions`.
  6. `chapter.event("boss_enter")`; `_refresh_hud()`.

Heavy requests:

```
func _on_heavy_clash_requested(event_time: float) -> void:
    if room_id != "boss" or not boss_started or _calibrating: return
    if not is_instance_valid(player) or not is_instance_valid(boss) or boss.dead: return
    if story_safe or outcome != "" or player.dead: return
    var token: int = 1000000 + int(event_time * 1000.0)
    if boss.perform_heavy_clash(player):
        _heavy_resolutions.append({"time": event_time,
            "resolve_at": event_time + Player.HEAVY_PARRY_WINDOW + HEAVY_RESOLVE_GRACE,
            "token": token,
            "generation": music.get_transport_generation()})
```

Resolution:

- Call `_process_heavy_resolutions()` from `_process(delta)`, after the room-flow/prepare handling
  and clock updates. Idle runs after every `_physics_process` of the frame, so the player has
  already captured (and timestamped) a press made in that tick; resolving inside
  `main._physics_process` would run before the child player's capture and could reject a press
  that was physically inside the window.
- The function returns immediately while `_reloading`, `_paused`, `_calibrating`,
  `room_flow.active`, `_room_prepare > 0.0`, `chapter.blocked()`, `story_safe`, or `outcome != ""`.
  `_process` already handles the first two; the rest are explicit inside the function.
- `var now: float = music.get_chart_time()`; `var generation: int =
  music.get_transport_generation()`. Adopt a new generation into `_heavy_generation` and clear
  player press history, but do **not** clear the whole queue: entries carry their own
  `generation`, and an entry emitted after a loop reset in the same idle tick is valid.
- Drop an entry (without judging it) when `entry.generation != generation`, `story_safe`,
  `outcome != ""`, `boss.dead`, `player.dead`, or `boss`/`player` is invalid.
- Pop every remaining entry with `now + 0.000001 >= entry.resolve_at`.
- Contact = `player.global_position + Vector2(player.facing * 18, -16)`.
- `accepted = player.parry_success(boss, contact, "heavy_clash", int(entry.token), entry.time)`.
- Success: `last_parry_kind = player.last_parry_grade` (`"perfect"` / `"good"`) and
  `_parry_notice_time = 0.4`, then `heal_player(1)`. `parry_success` already called
  `game.on_parry_contact`, which emits the blade-parry FX, the parry impact request, the
  `parry_contacted` signal, and the chapter parry event; do not request a second impact.
- Miss: `last_parry_kind = "miss"`, `_parry_notice_time = 0.4`,
  `damage_player(1, boss.global_position, true, true)` (story rescue still allowed,
  invulnerability bypassed).

Safety/cleanup:

- `set_story_safe(true)` clears `_heavy_resolutions` (it already clears projectiles/hazards).
- `_on_heavy_history_cleared` clears `_heavy_resolutions` and calls
  `player.clear_parry_press_history()`.
- `begin_room_transition`, `_mount_room`, `on_boss_defeated`, `_on_score_completed`, and `_reload`
  clear pending heavy state.
- `_portal_target()` returns `""` while `_calibrating`.
- `_physics_process(_delta)` (`main.gd:258`) renames its parameter to `delta`, adds
  `_calibrating` to the first early-return guard, and calls `_process_boss_heal(delta)`
  immediately after the `outcome` guard (`main.gd:261-263`), before the dungeon clamps.
- `_process(delta)` (`main.gd:310`) calls `_process_heavy_resolutions()` after the clock and notice
  updates (`main.gd:324-325`).
- `_unhandled_input` returns early while `_calibrating` (the room owns calibration taps and skip).
- `_refresh_hud` reports `room_bounds = level.get_map_bounds(player.global_position)` when the
  level exposes `get_map_bounds` (BossRoom), otherwise `room_spec["bounds"]` as today.

### 6.4 Projectile hygiene

`combat/projectile.gd`:

```
var _retiring: bool = false
var _fade_left: float = 0.0
var _fade_total: float = 0.0

func fade_out(seconds: float) -> void
func can_damage() -> bool   # false while retiring
```

- `fade_out` is idempotent (a second call keeps the existing timer), sets `_retiring`, and clamps
  the duration to `maxf(seconds, 0.05)`. It never retargets friendliness; `main` decides which
  shots fade.
- While retiring, the projectile keeps its current velocity, `can_damage()` returns false,
  reflection and parry checks are rejected, and `modulate.a` follows the remaining fraction. It
  frees itself when the timer expires.
- A wall/body hit during retirement frees it immediately without spark, damage, or a parry hook.

`main.gd`:

```
func fade_boss_projectiles(seconds: float) -> void
```

iterates a snapshot of the real `projectiles` group, requires `is_instance_valid(node)`,
`is_ancestor_of(node)`, and `not bool(node.friendly)`, then calls `fade_out`. Friendly and
reflected shots are never touched.

`combat/boss.gd` calls `game.fade_boss_projectiles(0.30)` at the start of `_begin_attack` and
`_begin_authored_pattern`, and `0.20` inside `perform_heavy_clash`. Lasers/cubes
(`boss_hazards`) are untouched.

## 7. Infinite Boss room (`levels/boss_room.gd`)

Constants:

```
SPAWN = Vector2(2706, 300)
BOSS_POSITION = Vector2(2990, 300)
PLATFORM_SPACING = 200.0
PLATFORM_WIDTH = 200.0
PLATFORM_HEIGHT = 12.0
PLATFORM_BASE_Y = 300.0
PLATFORM_LAYER_COUNT = 5
PLATFORM_LAYER_SPACING = 150.0
PLATFORM_SURROUND = 700.0
```

`platform_layer_y(layer) = 300 + (layer - 2) * 150` gives the layer **centre** y at
0, 150, 300, 450, 600. Each body is 12 px tall, so its one-way top surface sits 6 px above the
centre. Layer 2 is the old chamber floor height (floor top at `y = 300`), so chapter
rescue/shock coordinates (`y = 300`, `x ∈ [2680, 3310]`) keep working.

Contract used by `main`:

- `_ready()`: `process_mode = PROCESS_MODE_PAUSABLE`, `z_index = -20`, build a `CanvasLayer` with
  `layer = 40` holding the hidden calibration overlay, so it draws over the HUD.
  Nothing in `_ready()` starts calibration.
- `setup(game)`: store `game`/`music` and mark `active = true`; build/keep the overlay reference.
  Does not start calibration or move the player.
- `start_room_entry()`: begin calibration, or emit a silent complete (see §8). May emit
  `calibration_complete` synchronously.
- `begin_battle(boss)`: `battle_running = true`, `calibrating = false`, dismiss the overlay and
  invalidate its result timer, load heavy groups from the music director, reset cursor /
  `_cursor_generation` / `_last_chart_time`.
- `get_room_spec()`: id `boss`, title `THE HOLLOW BELFRY`, bounds
  `Rect2(2580, -160, 840, 720)`, `spawn`/`checkpoint`/`portal_at` = `SPAWN`,
  `boss_spawn` = `BOSS_POSITION`, `fall_limit = 720`, `platforms = []`, **`shard_indices = [11]`**
  (the old chamber shard `Level.SHARDS[11]` at `(2914, 186)` must remain collectable).
- `get_map_bounds(center) -> Rect2`: `Rect2(center - Vector2(420, 320), Vector2(840, 640))`
  so the minimap window follows the player.
- `room_at(_feet)` returns the single room record (title + hint) unconditionally.
- `climb_at`, `water_at`, `portal_at`, `interaction_hint`, `try_interact` return empty/false;
  `get_opened_ids` returns `[]`; `restore_opened_ids`, `reset_interactions` are no-ops.
- `get_attack_bounds` is deliberately **not** added because the Boss keeps its own arena.

Platforms:

- Create/remove `StaticBody2D` cells in `_process` for indices within `PLATFORM_SURROUND` of the
  player's x, across all five layers (≈ 40 bodies at 200 px spacing).
- Each body: `collision_layer = 1`, `collision_mask = 0`, one rectangle shape, position
  `Vector2(index * PLATFORM_SPACING + PLATFORM_WIDTH * 0.5, platform_layer_y(layer))`,
  `one_way_collision = true`, `one_way_collision_margin = 4.0`.
- When `climb_down` is held, disable every platform shape with `set_deferred("disabled", true)`;
  re-enable on release. No platforms exist outside the five layers.
- Platform lifecycle runs in `_process`, never during physics flushing, so adding/removing bodies
  cannot disturb the physics server mid-step in `_physics_process`. A test may drive the same
  refresh synchronously.

Heavy cursor:

- `_process_heavy_groups()` runs only when `battle_running` and `music.running`.
- Read `music.get_chart_time()` and `music.get_transport_generation()`.
- On generation change or a backward jump (`now + 0.05 < _last_chart_time`): reset the cursor,
  skip all historical groups, and emit `heavy_history_cleared` **before** any new request.
- Emit `heavy_clash_requested(event_time)` once per group whose time is `<= now`, then advance the
  cursor. No group is ever emitted twice.
- While `main.story_safe` is true, advance the cursor without emitting, so rest/safe stretches do
  not build a backlog of clashes that fire the moment safety lifts. The main-side handler also
  rejects.

Drawing:

- The drawn window is the real visible world rect, computed each redraw as
  `get_viewport().get_canvas_transform().affine_inverse() * Rect2(Vector2.ZERO, get_viewport_rect().size)`,
  grown by 96 px on each side. It is never assumed to be centred on the player.
- Backdrop filled with the current chamber palette (`DARK`, `FAR`, `MID`, `MASON`, `STONE`, `LIP`,
  `GOLD`).
- Brick courses every 20 px, faint pillar/lancet silhouettes at 320 px intervals, torches at
  480 px intervals.
- Five horizontal platform bands with the lip/stone/masonry treatment copied from
  `boss_chamber.gd`.
- Redraw at ~10 Hz and whenever the player moves > 8 px; never per physics frame.

`main._mount_room` keeps `BossChamber` untouched and only disables its collisions when that
specific script is mounted.

## 8. Calibration

### 8.1 Math (`combat/audio_calibration.gd`)

Port the attachment's `RefCounted` module without a global `class_name`:

- `SAMPLE_COUNT = 5`, `SEARCH_AFTER_SECONDS = 35.0`, `PREVIEW_LEAD_SECONDS = 2.0`,
  `MAX_TAP_DISTANCE_SECONDS = 0.35`.
- `configure(heavy_groups, current_offset_ms)`: collect groups at or after 35 s, sort, find the
  first run of five with a regular interval (each step within 25 ms of the first). Current chart
  cluster: 40.74–42.51 s.
- `preview_start_seconds() = sample_times[0] - 2.0`.
- `register_tap(audio_position)`: accepts a tap within 350 ms of the next expected sample, records
  the error; rejects anything else.
- `adjusted_offset_ms() = base + mean(tap - expected) * 1000`, rounded by the caller for display.

### 8.2 UI (`ui/calibration_overlay.gd`)

Port the attachment's full-screen panel using `PixelFont`:

- prompt, five diamonds, `重鼓 n / 5`, retry message, result line.
- `present`, `dismiss`, `set_progress`, `set_retry`, `show_result`.
- `mouse_filter = IGNORE`, no input handling; the room owns taps and skip.

### 8.3 Runtime (`BossRoom`)

- `start_room_entry()` silent auto-skip paths (all emit `calibration_complete(base_offset)`
  synchronously **inside** the call, before returning):
  - non-full-song timeline;
  - fewer than five regular heavy groups after `configure()`;
  - `DisplayServer.get_name() == "headless"`;
  - `AudioServer.get_driver_name() == "Dummy"` or `music._dummy`.
- Missing preview stream on a real device (`music._audio == null` or `music._audio.stream == null`
  despite a full timeline) → visible skip message, then the same synchronous
  `calibration_complete(base_offset)`.
- Otherwise: present the panel, create an `AudioStreamPlayer` on bus `Music` that reuses the
  already-loaded `music._audio.stream` (no second OGG load or SHA pass), set
  `volume_db = float(music.timeline.get("music_volume_db", -8.0))`, and play from
  `preview_start_seconds()`. `calibrating = true`.
- Preview clock = `playback_position + AudioServer.get_time_since_last_mix() -
  AudioServer.get_output_latency()`. Do **not** add any stored `device_latency_adjust_ms`: the
  preview plays through the same output path as the score, so the measured tap error already
  includes device latency.
- Tap handling in `_unhandled_input`: `ESC` / `BACKSPACE` are checked **first** and skip with the
  base offset; otherwise any pressed key, mouse button, or joypad button feeds
  `register_tap(preview_clock())`. Both paths consume the event.
- If the preview ends with fewer than five taps, replay it (attachment behaviour) and show
  `没有采足 5 下，马上重新播放。`.
- On completion, show the result for 1.1 s (generation-guarded timer), stop the preview, and emit
  `calibration_complete(rounded_offset_ms)` once. `begin_battle` and `dismiss` invalidate that
  timer so a late completion cannot re-enter the battle.

### 8.4 Offset application (`audio/music_director.gd`, `audio/full_song_transport.gd`)

`FullTransport`:

- Add `var offset_ms: float = 245.0`; cache the configure dictionary (`bpm`, `offset_ms`, the four
  `*_beat` values) in `configure`.
- `set_offset_ms(value_ms) -> bool`: reject while `running`; compute the new `offset_seconds` and
  re-derive `fixed_end`, `random_start`, `random_end`, `rest_end` through `beat_time()`. Apply the
  same validation as `configure`: `fixed_end > 0`, `is_equal_approx(fixed_end, random_start)`,
  `random_end > random_start`, `rest_end > random_end`, `duration > rest_end`. On rejection the
  old offset stays in place.
- On success, commit `offset_ms`/`offset_seconds` and all four boundaries together.

`MusicDirector.replace_offset_ms(value_ms) -> bool`:

- Reject when not full-song, when `_full_chart_path` is empty, or while `running`.
- Clamp to `[0, 1000]` ms; return true immediately when equal to the current value.
- Parse a replacement chart from `_full_chart_path` first with
  `parse_file(_full_chart_path, bpm, new_offset_ms, 4.0)` (same BPM and 4.0 step as
  `_configure_full_song`), then reject when `_audio.stream.get_length() + 0.000001 <
  chart.chart_end_time`. This shifts every heavy group, phrase, laser, and phase by the same
  delta.
- Only after a successful parse, call `transport.set_offset_ms(...)`. If it rejects, discard the
  parsed chart and return false.
- Commit on success: write `timeline["offset_ms"]`, replace `_full_chart`, and refresh the
  status/offset reporting. Leave `_full_chart_path` unchanged.
- Any failure leaves the old chart, offset, timeline, and boundaries byte-for-byte untouched.

Calibration runs before `start_score()`, so the transport is not running and no note is replayed
or skipped. `_begin_boss_battle` captures `_heavy_generation` after `start_encounter()` begins the
score, so the first request of the calibrated chart is never mistaken for stale.

## 9. Health and sustain

- Keep integer health `8/8`.
- All Boss-room damage is 1 (authored actions already use 1; heavy miss uses 1).
- `main.damage_player(amount: int, origin: Vector2, allow_story_rescue: bool = true,
  bypass_invuln: bool = false)`: after the story-rescue attempt, forward `bypass_invuln` to
  `player.receive_hit(amount, origin, bypass_invuln)`. Existing callers keep their behaviour.
- Add `main.heal_player(amount: int) -> int`: clamps to `max_health`, emits `health_changed` only
  on an actual change, and refuses when dead or `outcome != ""`.
- Add `_process_boss_heal(delta)` called from `_physics_process` after the guards:
  - requires `room_id == "boss"`, `boss_started`, not `_calibrating`, `outcome == ""`, and a live
    player (tree/`_paused` pause already returns earlier);
  - `_boss_heal_clock += delta`; while it reaches 4.0, subtract 4.0 and heal 1 (keep the
    remainder); a full-health player still advances the clock.
- Rest (`story_safe`) does **not** stop passive healing; pause/outcome/death does.
- Heavy success heals 1 immediately.
- Reset `_boss_heal_clock` on mount and on entering `_begin_boss_battle`.

## 10. Retry and end

- `R` keeps the current branch behaviour: scene reload from the Boss checkpoint
  (`chapter.prepare_reload(false)` when the chapter is active). Calibration reruns on the fresh
  mount; under Dummy/non-full-song it silently skips.
- The song's `completed` path stays safe, retryable, and never awards victory.
- Boss defeat → `on_boss_defeated` → `set_story_safe(true)` (clears projectiles, hazards, heavy
  resolutions), chapter victory, existing ending flow.
- Returning to the dungeon via the portal/chapter clears all heavy state and leaves
  `player.set_boss_room_mode(false)`.

## 11. File-by-file change list

New:

- `levels/boss_room.gd`
- `combat/audio_calibration.gd`
- `ui/calibration_overlay.gd`
- `tests/boss_room_test.gd`
- `tests/heavy_clash_test.gd`
- `tests/player_heavy_parry_test.gd`
- `tests/audio_calibration_test.gd`
- `tests/projectile_fade_test.gd`
- `tests/full_song_offset_test.gd`

Modified:

- `combat/boss.gd` — heavy clash, no-hit-stun, heavy pose, projectile fade calls.
- `combat/projectile.gd` — fade state.
- `actors/player.gd` — boss-room mode flag, press history, heavy parry branch, bypass invuln.
- `main.gd` — BossRoom mount, calibration lifecycle, heavy lifecycle, heal, fade, HUD bounds,
  input/physics gates, `_start_boss(calibrate)`, capture-tool-compatible synchronous start.
- `audio/music_director.gd` — `replace_offset_ms`.
- `audio/full_song_transport.gd` — `set_offset_ms`.
- `ui/heavy_lane.gd` — `WINDOW_SECONDS = 0.095` and the `±95ms` label.
- `ui/hud.gd` — extend the parry-notice label map (`ui/hud.gd:155`) with the heavy grades
  `perfect` / `good` / `miss` mapping to `完美格挡` / `格挡成功` / `重击命中`, and add those three
  strings to `ROOM_STRINGS` so the glyph check covers them; clamp every boss-map marker inside the
  moving `room_bounds` window.
- `tools/verify_main.ps1` — register the new checks.
- `tools/capture_boss_redhair.gd`, `tools/capture_review.gd`, `tools/capture_rooms.gd` — call
  `_start_boss(false)` so frozen captures never enter calibration.
- `tests/main_scene_migration_test.gd` — expect `res://levels/boss_room.gd`.
- `tests/room_transition_test.gd` — expect `res://levels/boss_room.gd`; keep the `[11]` shard and
  spawn assertions; replace `room_bounds == level.WORLD_BOUNDS` with
  `level.get_map_bounds(player.position)`; replace the "all StaticBodies are layer 0" assertion
  with "every StaticBody2D is a layer-1, mask-0, one-way platform".
- `tests/heavy_lane_test.gd` — 0.095 window and label.
- `docs/full-song-runtime.md` — heavy clash is authoritative, not cosmetic.

Untouched:

- `levels/boss_chamber.gd`, `combat/boss_hazard.gd`, `combat/friend_rhythm/*`,
  chapter/story files, dungeon level files.

## 12. Tests

New:

1. `boss_room_test.gd`
   - `get_room_spec` contract, including `shard_indices == [11]`; `platform_layer_y` values
     (0/150/300/450/600).
   - Platform creation within ±700, removal outside, drop-through disables shapes, layer-1
     one-way bodies.
   - Heavy cursor: one emit per group; generation change emits history-cleared and skips old
     groups; backward jump resets; no duplicate emits; a stretch of `story_safe` advances the
     cursor without emitting.
   - Silent auto-skip under headless/Dummy emits the base offset synchronously and exactly once.
   - The overlay panel glyphs (`重鼓 n / 5`, retry, result) exist in the pixel font.
2. `heavy_clash_test.gd`
   - `perform_heavy_clash` teleports to `player + facing × 58`, faces the player, sets the pose,
     increments the serial, returns true.
   - It cancels an injected authored dash/shift/action and blink/duel; retained ring/fan/spray
     actions survive.
   - It returns false while reaction-blocked, posture-locked, dead, story-safe, or non-full-song.
   - `no_hit_stun` allows two hits inside 90 ms and still sets `hurt_flash`.
   - `_try_duel_on_beat`, `_begin_attack`, and `_begin_authored_pattern` do not start during the
     pose.
   - Main-side resolution: an entry stamped with the previous transport generation is dropped,
     while a new-generation entry queued in the same tick still resolves; resolving the same
     token twice consumes only one press; a press recorded in the physics tick resolves correctly
     from the idle call site.
3. `player_heavy_parry_test.gd`
   - 95 ms acceptance, 96 ms rejection; 40 ms perfect, 41 ms good.
   - Consuming removes the press and returns the grade; a second consume is a miss; a miss removes
     nothing.
   - Heavy `parry_success` succeeds with no `parry_timer`, wrong facing/contact, and a valid token;
     duplicates are rejected without consuming a second press; it fails outside boss-room mode.
   - Ordinary melee parry still succeeds in boss-room mode.
   - `receive_hit(..., true)` bypasses invuln; the default path does not.
   - `set_boss_room_mode` clears history, grade, and token memory.
4. `audio_calibration_test.gd`
   - First regular five-run after 35 s is selected (40.74–42.51 s fixture).
   - Fewer than five groups rejects; irregular runs are skipped.
   - Tap acceptance/rejection, preview lead, adjusted offset math.
5. `projectile_fade_test.gd`
   - Fade marks no damage/reflection, keeps motion, sets alpha, frees after the duration.
   - `fade_boss_projectiles` only touches hostile projectiles owned by main.
6. `full_song_offset_test.gd`
   - `set_offset_ms` recomputes all four boundaries; rejects while running and on invalid
     boundaries.
   - `replace_offset_ms` shifts every heavy group by the delta, updates the status offset, and
     rejects while running; chart stats stay 1171/107/228.

Test fixtures:

- `verify_main.ps1` always runs `--headless --audio-driver Dummy` with
  `BELLKEEP_USE_PLACEHOLDER=1`, so a fresh `main.tscn` loads `music_timeline.json` and is **not**
  a full song. Tests that need real heavy groups must use one of the two established seams:
  - `main_full_song_test` pattern: clear `BELLKEEP_USE_PLACEHOLDER` in `_initialize` before
    instantiating `main.tscn`, set `music._dummy = true` and `music.set_process(false)`, drive
    `music._process(delta)` by hand, and restore the variable before `quit`.
  - `full_song_boss_test` pattern: build a standalone `Music`, call
    `configure(game, "res://data/full_song_timeline.json")`, then set `_dummy = true` and
    `set_process(false)`. This is the fixture for `heavy_clash_test`; `player_heavy_parry_test`
    uses a lightweight music probe exposing `get_chart_time()` (optionally
    `sample_input_chart_time()`), or calls `record_parry_press_at()` directly.
- `boss_room_test` uses a probe game/music (`is_full_song() == true`,
  `get_heavy_groups()` returning fixture groups) for the cursor and synchronous-skip assertions;
  it does not load the recording.
- No new test depends on audio output or real wall-clock playback, and every new test keeps the
  `N passed, 0 failed` summary contract.

Updated:

- `main_scene_migration_test` — mount `boss_room.gd`.
- `room_transition_test` — mount `boss_room.gd`; HUD bounds via `get_map_bounds`; platforms are
  layer 1 / mask 0 / one-way; shard `[11]` and spawn `(2706, 300)` unchanged.
- `heavy_lane_test` — 0.095 window and `±95ms` label.
- `verify_main.ps1` — add the six new test names.

Existing tests that must keep passing unchanged: `boss_parry_test`, `boss_duel_runtime_test`,
`boss_navigation_test`, `room_geometry_test`, `full_song_boss_test`, `main_full_song_test`,
`chapter_integration_test`, `impact_feedback_test`, `parry_integration_test`, `integration_test`,
`main_boss_runtime_test`, `hit_vfx_contract_test`, `heavy_judge_test`.

## 13. Verification

- Focused: `tools/verify_main.ps1 -Only boss_room_test,heavy_clash_test,player_heavy_parry_test,audio_calibration_test,projectile_fade_test,full_song_offset_test,main_scene_migration_test,room_transition_test,heavy_lane_test`.
- Regression on the full-song core: `full_song_transport_test,full_song_boss_test,main_full_song_test,boss_parry_test,boss_duel_runtime_test,boss_navigation_test,room_geometry_test,chapter_integration_test`.
- Full suite before merge.
- Visual: run `tools/capture_boss_redhair.gd` and inspect the new heavy arc plus the infinite
  platform backdrop; run `tools/capture_rooms.gd` for the Boss-room map HUD.
- Live device: manual calibration on a real audio driver, then confirm heavy grades and heal/damage
  over at least one fixed→random cycle. Headless Dummy runs only prove wiring and math.

## 14. Risks and mitigations

| Risk | Mitigation |
|---|---|
| Re-parsing the chart shifts every event | Calibration runs only before `start_score`; `replace_offset_ms` is rejected while running; `full_song_offset_test` asserts all groups shift by exactly the delta and chart counts are unchanged. |
| Calibration blocks automated tests | Silent synchronous auto-skip for non-full-song, headless, Dummy, and short charts; frozen capture tools use `_start_boss(false)`. |
| A last-moment press is judged before it is recorded | Resolution runs from main's idle `_process`, after every child `_physics_process` capture in the frame; the 20 ms margin covers the chart-time edge. |
| Heavy clash every heavy group is much harder | The clash is parryable with a 95 ms window, is skipped during Boss parry/guard reaction, and every success heals 1. If playtesting shows it is too dense, the next lever is a chart-time filter in the room, not a Boss rewrite. |
| Phantom dash after teleport | `perform_heavy_clash` clears `_authored_dash`/`_authored_shift` via `_cancel_contact_sequence`; covered by `heavy_clash_test`. |
| Next chart phrase re-arms during the clash pose | `_begin_authored_pattern`, `_begin_attack`, and `_try_duel_on_beat` all reject while `_heavy_pose_time > 0.0`; covered by `heavy_clash_test`. |
| Stale projectiles overlap the clash | Hostile projectiles fade at every phrase start and at the clash; friendly/reflected shots are untouched. |
| Loop double-hits | Every resolution is stamped with the transport generation at request time and dropped if the generation changed; the room cursor reset plus `heavy_history_cleared` clear history before new requests. |
| Platform collisions disabled on mount | The mount-time collision disable is restricted to `BossChamber`; `BossRoom` keeps its one-way platforms. |
| Chapter rescue coordinates vs. infinite room | The room uses the old chamber baseline (y = 300, x around 2706–2990), so chapter rescue/shock clamps stay valid; platforms follow the player anyway. |
| `no_hit_stun` removes hit feedback | Only `_hurt_timer` is zeroed; `hurt_flash` and the hit FX remain. |

## 15. Acceptance criteria

1. Entering the Boss room mounts `levels/boss_room.gd` with five one-way platform layers that
   follow the player; `S` drops through.
2. Every chart heavy group during `fixed` / `random` / `final` (and not during story safety)
   triggers `perform_heavy_clash`; the Boss teleports adjacent, faces the player, shows a gold
   heavy arc, and no previously authored dash continues.
3. A left-Shift press within ±95 ms of the event resolves the clash: `perfect` ≤ 40 ms, `good`
   otherwise. Success heals 1 and shows the grade; miss deals 1 damage even through invulnerability.
4. Ordinary melee/projectile parry, guard posture, blink, duel, and all authored chart actions
   still work in the Boss room.
5. Boss hits do not stagger it in the Boss room, but still flash.
6. Hostile projectiles fade out at authored phrase boundaries and at heavy clashes; reflected
   shots never fade.
7. With a full song and a real audio driver, five taps calibrate and shift the chart offset before
   the score starts; Dummy/headless/non-full-song/short-chart paths skip synchronously inside
   `start_room_entry()` and still start the Boss in the same call.
8. The player heals 1 every 4 s of live Boss-room gameplay and on each heavy success; pause,
   outcome, and death stop the heal.
9. The old chamber shard (`shard_indices == [11]`) is still drawn and collectable in the Boss room.
10. The Boss-room minimap window follows the player and keeps the player/portal/boss markers
    clamped inside the window instead of pinning the old chamber rectangle.
11. Existing full-song, parry, duel, navigation, chapter, and transport tests pass; the two tests
    that name `boss_chamber.gd` are intentionally updated to `boss_room.gd`.

## 16. Implementation order

1. Transport/music offset API + calibration math + tests (no gameplay dependency).
2. Projectile fade + tests.
3. Player heavy press parsing, heavy parry branch, bypass-invuln + tests.
4. Boss heavy clash, no-hit-stun, pose, preemption + tests.
5. `BossRoom` platforms, heavy cursor, calibration runtime + tests.
6. `main` wiring: mount, calibration lifecycle, heavy resolution, heal, HUD/input gates.
7. Update existing tests, capture tools, runner, and docs.
8. Focused suite, capture review, full suite.

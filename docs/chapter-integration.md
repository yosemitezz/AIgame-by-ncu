# Chapter main-scene adapter

`flow/chapter_controller.gd` applies the pure story runner to the existing game. It owns only narrative locks, companion/overlay nodes, local snapshot persistence and presentation cues. No movement, attack, Boss chart, health balance or audio timeline is replaced.

Main hooks:

1. Add `chapter_enabled` (default `BELLKEEP_DISABLE_STORY != 1`), `chapter_persist=true`, `chapter_locked=false`, `chapter:Node`; call `ChapterController.restore_run(self)` before reading existing tree metadata. Create/add/configure the controller after player/music/HUD are ready.
2. Call `chapter.tick(delta)` before ordinary game process. Gate gameplay physics, portals and map-opening with `chapter.blocked()`. Also ignore the immediate continue edge when `chapter.consume_interact_guard()` is true.
3. Before `player.receive_hit`, call `chapter.try_rescue(amount,origin,allow_story_rescue)`. The pit/fall path explicitly passes false. Existing invulnerability, dead, safety, positive-damage and real Boss-room checks remain prerequisites.
4. Emit actual event notifications for jump/air-jump, accepted hit, parry, opened door, checkpoint, weapon switch and Boss entry. Upward knockback is not a jump. Enemy events carry deterministic spawn IDs; the same spawn cannot farm a reward after retry.
5. Record ordinary earned Boss victory first, then call `chapter.on_boss_defeated()`. Suppress the old victory UI/shadow layer when this controller is enabled; the new overlay owns only narrative death. Ordinary defeat is unchanged.
6. Route `handle_input` before normal scene keys. E/Enter advances, Backspace skips, Escape remains the existing pause, V replays the completed ending, and Enter/R returns a completed chapter to the dungeon. F5 explicitly starts over. `prepare_reload(full)` must run before scene reload; `set_paused` composes music pause with the narrative lock.
7. `set_story_safe(false)` and room preparation must respect `chapter_locked`. A completed chapter may return to the dungeon; the Boss portal must not silently start the already-won battle again.

Rescue is conditional on the first genuinely lethal Boss hit. It is not a forced loss. The old attack plans are canceled once for narrative safety and are not replayed; `set_score_paused` freezes the existing song cursor, no stop/start occurs. Recovery restores half player HP and a brief existing-style recovery shield, preserves Boss HP and score time, then gives a short safe reengage cue. `chapter_pose` metadata asks the existing Boss renderer for a temporary hurt pose without changing AI or damage. The root should let `KatanaVisual.describe` read that presentation metadata.

The explicit default `conditional` policy also supports a short post-victory assistance scene for a player who wins without the rescue; no skillful run is invalidated. The policy remains editable. Backstory, names and motives remain unknown. No rejected friend-reference canon is introduced here.

`res://.local/chapter-save.json` contains versioned narrative flags plus the existing run checkpoint/doors/shards/room/weapon metadata, all in the project's D-drive local folder. Effects are consumed before a snapshot is written; replay does not heal/reward again. Baseline combat fixtures can set `BELLKEEP_DISABLE_STORY=1`; the dedicated actual-main integration fixture explicitly enables story and disables user-file persistence.

Validation evidence (2026-10-25): `tests/chapter_integration_test.gd` runs the actual `main.tscn`, story enabled and user-file persistence disabled. It passed **41 assertions**, exit 0, with empty stderr in Godot 4.7.2 headless. Logs: `artifacts/chapter-story/integration-out.log` and `integration-err.log` (local artifacts). It covers real Boss-lethal interception, safety cleanup, music-cursor preservation, pause composition, finite rescue, once-only recovery, rest overlap, actual jump versus recoil, earned win versus narrative death, blood progression, replay without rewards, completed room return, ordinary dungeon death R passthrough with completion retained, input guard and test-owned save cleanup. Wrong chapter/version, malformed blocking cursor and truncated JSON cannot apply run progress.

Rest safety and narrative locks are separate: narrative unlock resumes living actor physics during a musical rest but keeps damage safety until the existing music section changes. Closing pause also immediately synchronizes the graph pause flag so the next continue/skip edge works.

This is logic verification, not a player hand-feel or full-song listening verdict. Visual timing, final dialogue and the editable no-lethal post-win assistance policy still need the user's review. The original backstory remains undefined. No Git or remote publication is performed by this adapter task.

After chapter completion, an ordinary dungeon defeat passes R back to the original root retry and rejects ending replay/return shortcuts; it cannot reopen control on a still-dead player.

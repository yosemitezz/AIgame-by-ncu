# Story direction: confirmed scope and replaceable ending

This is a design handoff, not a declaration that the current ending implements all of it.

## Confirmed by the user

- The protagonist has lost their memory.
- The narrator is an embodied flying eye, talkative and comic, but its combat instruction is reliable and helps the protagonist grow stronger.
- The narrator has been using the protagonist from the beginning.
- After the Boss is defeated, the exhausted protagonist blacks out. The last impression is the eye's cold gaze and mocking words, followed by an explicit "你死亡" announcement.
- This replaces the earlier preference for leaving the protagonist's survival ambiguous.
- Ordinary combat death uses normal text color. The final betrayal death announcement turns red and has stylized pixel blood flowing downward. Preserve the strong contrast without a fullscreen flash; sound and camera controls remain available.
- The proposed boastful line was rejected and is not used. Mocking dialogue remains undecided; do not invent a replacement catchphrase.

## Keep open

The eye's identity and motive, the precise betrayal mechanism, and what lies beyond the door are not settled. Dialogue examples, a sword-bound narrator, a search for a body, seal mythology, blade/impact sound cues and other suggestions are not approved canon. Do not hard-code them.

## Presentation/runtime boundary

Boss victory and chapter completion must remain completed when the narrative death is shown. It must not be routed through ordinary combat defeat or imply that the player has to win the same Boss again. Reserve separate outcomes for combat defeat and completed-chapter narrative death. The exact continuation/title flow and final dialogue need a later story pass.

The dungeon milestone retains replaceable teaching/ending placeholders and the already working safe ending. It adds no new betrayal identity or motive. A later story implementation should replace those placeholders through a narrative interface, preserve the score/rest safety contract, and not alter combat success records.

The current UI now renders ordinary combat death in the normal text color. The distinct red narrative-death/blood presentation is reserved for the later ending pass; this milestone does not pretend that scene has been implemented.

## User's foreshadowing direction: trigger design still open

The user proposed a first near-death Boss encounter in which the Boss does not finish
the protagonist. Dizziness/blackened vision precedes the flying eye's rescue; the Boss
responds with surprise and pain when the protagonist returns. Clean starting armor
progressively gains dark wisps after mob kills, then a demonic death aura after the Boss,
hinting at corruption and eventual possession.

This is a direction for a later story/presentation pass. Do not force a deliberate loss,
claim a winnable fight is secretly unwinnable, turn "near death" into a real death that
erases victory, or decide the rescue trigger/health restoration/identity/motive here.
The Boss collaborator retains fine encounter design. Suggested hand reaches, a weak
acting eye, wisps entering armor seams and alternate first-victory triggers are not canon.

## Available integration interface

- Root `narrative_event(kind, payload)` publishes real `enemy_defeated` and `chapter_complete` events.
- `emit_narrative_event(kind, payload)` can relay later agreed story cues; payload is copied.
- `corruption_visual` defaults to zero. `set_corruption_visual(amount)` clamps 0..1 and emits
  `corruption_visual_changed(amount)`. It changes no damage, input, Boss phase or music rule.
- No automatic per-kill mapping, black-aura renderer or rescue trigger is implemented yet.
- `chapter_complete` is stored independently in running-session metadata. Explicit replay
  keeps it; only F5/new journey clears it. Narrative death must preserve that record.

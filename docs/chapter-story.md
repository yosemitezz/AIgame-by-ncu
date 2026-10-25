# Chapter one — user's original direction

Authority: the latest user instruction relayed by the parent on2026-10-25, `主要根据我的改`. The friend's reference is optional deferred material, not this chapter's established background. Identities, past relationships, motivation and the exact betrayal/possession mechanism remain unknown. Every sentence below is an editable first draft of the user's direction, not individual line-by-line approval. Runtime text uses stable IDs in data/chapter_story.json.

## Story delivered by the graph

The amnesiac knight starts with clean armor in the actual dungeon. A physically present flying eye is talkative and funny, yet gives reliable advice based on actual movement, jumping, dodging, accepted hits, genuine parries, weapon changes, climbs, doors and checkpoints. It helps the knight grow stronger while using the knight from the beginning; its exact reason is withheld. Two short follow-up barks, after the elite falls and on Boss entry, read only as encouragement on first hearing and double as the eye's claim on the knight later. The hero speaks under the HUD's `旅人` label, not a second-person `你` speaker tag.

Each unique defeated enemy adds a small dark aura, initially subtle enough to read as growth. After the Boss falls, the knight is covered in much heavier darkness, foreshadowing corruption and an impending takeover without declaring its mechanism complete.

The first genuine lethal Boss contact can become a once-only near-death rescue. The Boss stops instead of finishing the knight. Dizziness/black vision precede the eye's rescue; when the knight goes forward again, the Boss is surprised and pained. There is no newly asserted explanation for the Boss's restraint. A skilled player is never required to lose: configurable `conditional` policy uses a brief post-victory assist worded for any remaining health after a direct first win; `lethal_only` omits that alternative.

After an earned victory has already been recorded, fatigue gives way to a sudden ambush/blackout. The last visible eye is cold, with the short replaceable mockery draft `刀不错。人，更听话。` The final `你死亡` is red with flowing pixel blood. Ordinary combat death stays its normal color. Victory and chapter completion remain intact; the ending never sends the player back to re-fight a won Boss. No extra background reveal, finishing-stroke/fusion sequence or completion statistic is scheduled.

## Pure runtime API

flow/chapter_story.gd extends RefCounted. It does not write actors, music, HUD, health, damage, rooms or files. The root applies its queued commands.

- `configure(saved = {}, options = {})`: restore versioned state; options.rescue_policy may override `conditional` or `lethal_only`.
- `begin_chapter()`: a short, safe, skippable opening, once per fresh chapter.
- `event(id, context = {})`: actual actions and nonblocking barks. Short aliases move/jump/attack/dodge/parry/interact/boss_enter are supported; attack means accepted hit, parry means accepted contact, interact means successful interaction. Explicit moved/jumped/air_jumped/attack_hit/dodged/parried/weapon_changed/climbed/door_opened/checkpoint/boss_entered also work.
- `event('enemy_defeated', {'id': stable_authored_spawn_id, 'kind': kind})`: deduplicate authored enemies across ordinary retries; do not use an instance ID or a changing current position. Corruption starts0, increments0.045 per unique kill up to0.62, then becomes1 after Boss victory.
- `can_rescue(in_boss, lethal)` and `request_rescue({'in_boss': true, 'lethal': true})`: genuine lethal Boss contact only, intercepted before normal player death. Omitted lethal defaults false.
- `boss_defeated()`: retain victory immediately, then start fatigue/ambush. It never resets Boss health or creates a compulsory losing battle.
- `tick(delta, paused = false, transition = false)`: sole narrative clock. Pause/transport freeze the graph, terminal blood cursor and advance/skip input.
- `advance()` / `skip()`: continue or safely finish a sequence. Rescue skip still delivers exactly one restore/shock; ending skip still keeps victory and reaches narrative death.
- `replay_ending()`: reopens only presentation, without repeating heals or completion rewards.
- `dismiss_completed()`: close a watched ending, clear its terminal screen/safety and enter explore while retaining completion, seen flags, corruption and rescue. Dismissal is idempotent and serialized; retry does not resurrect a dismissed red screen.
- `snapshot()` / `restore(saved)`: chapter/version validation; preserve shown tutorials, stable kill IDs, rescue/completion and exact safe cursor. `synchronize_commands()` restores a fresh root's safety lock once without reapplying consumed rewards.
- `prepare_retry()`: clear interrupted presentation while preserving shown tutorials and earned state. F5/new chapter uses a fresh state.

## Command ownership and integration order

Call `take_commands()` once, apply its queue in order, then snapshot/persist. Do not persist an unconsumed once-only reward queue or connect a second health/audio authority. Root owns crash-safe persistence/acknowledgment policy. The queue is not a global account transaction log.

| Command | Root responsibility |
| --- | --- |
| narrative_lock | Lock controls and both damages, clear old attacks/projectiles, pause the same music cursor, keep pause UI available. |
| rescue_restore | Restore the still-alive knight once; retain Boss progress and musical time. |
| boss_shock | Show the Boss's surprised/pained response, compatible with existing presentation. |
| narrative_unlock | Restore control and prior encounter transport/safety. A simultaneous music rest remains safe. |
| chapter_complete | Retain earned Boss/level victory before the ending. |
| narrative_death | Distinct from combat defeat; keep completion and show the red death screen. |

The root binds Enter/E to continue, Backspace to skip and Esc to pause. After completion Enter/R returns to the dungeon rather than restarting the won Boss; V replays the ending; F5 starts a new chapter. UI hints are editable data.

## Presentation contract

Phases scheduled by this chapter are opening, explore, rescue, aftermath, betrayal and narrative_dead. presentation() supplies progress, node/scene IDs, line ID/text/speaker, friendly/concerned/cold eye mood, corruption, blackout/faint, dizzy, closeup, bloodred/narrative_dead/chapter_complete, ending_dismissed, can_skip and hints. Terminal death_elapsed/node_elapsed advance only through tick and pause correctly, so blood drips must not use an independent unpaused clock.

The generic optional fields thread_pull/body_controlled/fusion_progress/vessel_complete/memory_fragment/completion_label remain false, zero or empty for compatibility with the separate renderer. No active node schedules those presentations. A rescue_flare is only a single bounded local light pulse from the eye, not a screen flash.

## Validation

The original70 mechanical branch/skip/replay/restore/idempotence/pause test meanings are retained. tests/chapter_story_test.gd additionally rejects withdrawn background in runtime data, checks the user's restraint/rescue/return-to-fight sequence, the two double-meaning follow-up barks, the traveler speaker label, earned-win fatigue/ambush/cold mockery, red Chinese death without an extra completion reveal, and a direct winner who never loses. Current pure-state result:92 passed,0 failed. These are bounded state fixtures, not gameplay or subjective writing acceptance. Parent/root still owns real actor/audio/UI integration and its separate tests.
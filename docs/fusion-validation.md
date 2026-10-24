# Gradient combat fusion

Source presentation is the committed `integrate/vfx-primary` revision
205b8e74f151c845c7279e69a90e0b23c415f839, descended from
cursor/gameplay-vfx 6e189a954c84e2b76f3dd5127933416a7fae90bb.
The stable gameplay parent is 63017fc7b4fcac87892dca68b066210ec610e592.
All three histories are retained. No external editor working files are imported.

The fusion uses one FxLayer for slash, contact burst, warnings, ghosts, running
ribbons and projectile tails. It keeps the six slash and four hit variants.
The actor controller, root damage ledger, ImpactFeedback and MusicDirector remain
separate authorities. The former pixel VFX node is not instantiated.

Three-cut totals are 270/290/370 ms. The first damage contact begins at about
69/81/106 ms after input in the absence of local hit holds. Windup, active and
recovery still drive sprite poses; buffered attacks and confirmed dash cancellation
remain intact. Local hit holds do not change Engine.time_scale or the music clock.
Camera impact is capped at six logical pixels and can be toggled with F2.

Compatibility corrections include typed projectile trail records, enemy slash world
ownership, full pose snapshots, safe-section cleanup, independent warning kinds,
and removal of approximate contact deduplication in the presentation layer.
Only the gameplay source/token ledger decides whether a parry was accepted.

Validation is bounded logic/import/startup testing plus fixed keyframes. It does
not establish manual game feel, real audio latency, difficulty or video-reference
frame matching. The user performs the playtest. Run tools/verify.ps1 to reproduce
checks; ignored local evidence is under artifacts/.

Validation result: all 14 verify checks passed. After the two review corrections, source FX (37 assertions), fused FX (46 assertions) and the short startup check passed again with no engine/script errors. Independent review reports no remaining findings in this fusion scope.

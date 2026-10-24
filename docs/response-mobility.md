# Response and timing milestone

This selected-source change is based on 82b5a5d. Concurrent uncommitted weapon work is preserved in the live worktree and excluded from this commit. Room separation is a subsequent milestone.

Movement tuning: run180->232 logical px/s, dodge420->520, ground acceleration2800/brake3400/turn4000, air acceleration1700/brake1550/turn2600. Ground full reversal measured150ms versus200ms; air233ms versus288ms. Jump launch370/gravity1040 gives about66px theoretical height, preserving existing routes. Coyote grace120ms, jump buffer140ms, recovery cancel40ms. Existing infinite air jumps, light wings, shadow feedback and attack profiles are retained. Cross-direction dodges still move promptly but cannot continuously renew the230ms dodge invulnerability: another grant requires100ms of exposed time. Ladder-grip input consumes the initial vertical tap to prevent accidental dodge during a single readjustment.

The source dash previously started its blade anticipation after the absolute release cue. At203BPM this delayed active steel by73.89-147.78ms depending on the authored dash duration. The anticipation now occurs before release; the source release enters the first active manifest frame. Source aim/dash/fire timestamps and203BPM/+245ms remain intact.

The bounded timing fixture uses the real action executor and virtual60Hz. Eight patterns/31 actions/101 projectile births/8 blade releases: maximum action dispatch15.189ms, p9514.532ms; blade activation maximum/p9513.300ms; projectile birth maximum/p9515.189ms. Physical travel to a target300px away takes longer and is reported separately, not mislabeled as scheduling delay.

`data/audio_calibration.json` adds a default0ms device latency adjustment, limited to +/-200ms, applied once to the AudioServer-compensated audible clock. It does not edit the chart offset. Timing trace/report data distinguish source timestamps, dispatch, first active blade and projectile birth. Virtual/Dummy checks do not establish real output latency or subjective hearing alignment; those remain user acceptance tasks.

Skills used: godot-2d-movement, godot-gdscript-headless-testing, and the existing coldbrew-builder workflow. Music/Boss timing, movement, selected-source integration and independent review have separate ownership. No manual or automated playthrough is performed.

Selected-source verification: all35 named checks passed, including short startup; complete source accounting still228 phrases/862 actions/2787 shots/24 cubes/48 laser formations. Independent source review reported no findings. Runtime speaker/Bluetooth alignment and subjective feel remain unverified.

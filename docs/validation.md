# First-chapter validation

Validated gameplay milestone: `857f615264d7559ef93fab5fe72e8993e287d154` with Godot 4.7.2. A separate detached clean checkout was imported from committed source with no prior `.godot` cache.

| Check | Result |
| --- | --- |
| Clean source import | PASS, exit 0, no engine/script errors |
| Integration assertions | 22 passed, 0 failed |
| Music/phase/clock assertions | 30 passed, 0 failed |
| Bounded headless startup | PASS, exit 0, no engine/script errors |
| Hero and Boss pixel contact sheets | Visually inspected |
| Six fixed scene screenshots | Real OpenGL captures, six successful PNG writes |
| Independent defect-first review | No findings after fixes |
| Original LICENSE | Preserved; clean checkout matches |

Regression cases include main-route jump reach, front/back projectile contact order, rest damage immunity and clearing of actual projectiles, revive, shrine/elite checkpoints, Boss completion, scene reload, nonfinal overkill, musical phrase loops and the latency-corrected audio wrap clock. Review also checked that all actors expose animation frames and state/frame/facing change events for Cursor.

The scene captures are fixed visual setups, not evidence of a manual or automated complete playthrough. No repeated gameplay was performed. Logs and PNGs remain in ignored `artifacts/` directories. `tools/verify.ps1` reproduces the logical checks with per-process 60-second limits and error/leak scanning.

Still unverified: user play feel, difficulty, real audio-device listening/latency, controller input, and executable export. Art/UI remain explicitly replaceable program-authored pixel placeholders for Cursor. Saves persist across retries in a running session, not across closing the game. The deliverable is one complete chapter; additional connected chapters are not included in this milestone.

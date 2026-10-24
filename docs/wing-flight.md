# Wing-powered airborne presentation

This is a local visual revision after7c536d1. Jump/air-jump/dodge movement, collision, windows, attack profiles, weapon sequences and music are byte-identical to that baseline. The existing unlimited-air-jump choice is preserved.

The six old air-jump somersault cells are now upright wing-launch, forward-drive and recovery poses. Rise/apex/fall balance the same knight body. Three four-frame clips append after the original155cells: `air_dash_side`155, `air_dash_up`159, `air_dash_down`163. All three swords keep144x128cells and feet anchor66,108, with no whole-sprite rotation. Actual cardinal `dash_direction` selects the clip; the optional renderer vector only chooses a pose and grants no new movement.

`ActorRenderer.hero_region_for(actor,state,frame)` is the shared sprite/ghost region entry. Wing roots read each clip frame's exported shoulder landmark; existing attack landmarks bind the root during air-combo transitions without changing those cells. Both ghost renderers preserve the captured direction/region.

`LightWings.presentation_state` is read-only. An initial airborne dash can show90%wing spread even when gameplay `wing_amount` is zero. Other states use the original wing amount and landing fold. Five dim directional streaks have at most44pixel length and100ms residual lifetime. Wing geometry stays behind the character.

`tests/fixtures/wing_flight_contract_7c536d1.json` stores the original protected pixels/landmarks/runtime hashes. The original141cells per weapon, across colour/flash/silhouette, total1269protectedcell comparisons. Ground dash, idle, run, all ground/air attacks and all six parry PNGs remain exact. `tests/wing_flight_visual_test.gd` checks routing, no inversion, shoulder attachment, immutable gameplay and independent ghost poses. Static contact and runtime evidence live in ignored `artifacts/wing-flight/`; these are fixed frames, not playthroughs or proof of subjective feel.

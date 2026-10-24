# Adult red-haired katana duelist

This local art revision reconstructs the original pure 2D Boss as a tall adult
woman in fitted, covered western-fantasy armour. The navy steel, burgundy twin
coat hems, small gold fasteners and narrow katana remain original project art.
The current style is A; B/C are retained archived seed PNGs, never runtime choices.
No external character image, 3D render, resampled body or whole-sheet scaling is used.

Upright anatomy changes independently: head y55 to42, shoulders69 to55, hips86 to81,
knees up2 pixels, feet unchanged. The standing body including hair is82 native
pixels high, with a narrow adult profile, readable nose/chin and one-pixel jade eye.
Longer torso and legs, a slimmer waist/greaves and newly solved elbows create the
stature. Collapse poses blend these changes down; prone death art is separately
redrawn and keeps its support on the floor. Hair and split coat hems have their
existing per-pose movement lag, now rendered in auburn, crimson and copper layers.

Hair palette: #341521, #6e2330, #ae3d3e, #e66c4e, #ffc382. The old generator colour
key `silver` is retained internally for compatibility and now denotes the crimson
mid-light. Maximum per-frame palette is21 colours, alpha strictly0/255, nearest
rendering at128x128 with feet anchor(48,116). All78 cells across19 clips update:
idle, approach, shift, draw, both cuts, recovery, cast, ordinary/armoured parry,
posture break/recovery, hurt, death, retreat, jump, slam and landing.

Combat mapping is immutable against
`tests/fixtures/boss_blade_contract_7c536d1.json`: state order, start indices, counts,
frame names/progress, hands/support, guard, tip, guard point, hit-window flags and
both feet match the pre-revision commit exactly. The generator asserts that
contract before exporting the family; earlier pixel-hash protection of silver
reaction art has been replaced by this original geometry contract. The three
atlases retain matching alpha masks. The runtime renderer and all Boss logic,
physical body, navigation, music and damage code are unchanged. This is an art
replacement; the small existing physical body is intentionally distinct from the
full hair/coat silhouette.

Rebuild with `python tools/generate_katana_boss.py`. It exports the atlas family,
metadata, archived-seed documentation and native/nearest-only previews. Ignored local
evidence in `artifacts/boss-redhair/` includes the3x before/after and all78 contact
sheets. `tools/capture_boss_redhair.gd` renders four fixed800x450 actual Boss-room
poses (idle, active cut, parry recoil, posture break) with AI, physics, input replay
and audio progression disabled. These static frames were inspected for silhouette,
red-hair consistency, sword visibility, pose support and scene contrast. The user
still judges beauty and motion quality during play; logic tests cannot establish
subjective appeal.

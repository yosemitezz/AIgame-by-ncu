"""Builds the hero atlas, silhouette, flash and parry sheets from tools/hero_rig.py for the three swords.

Only the hero parts of presentation/feel_frames and presentation/parry_frames are touched; enemy, effect and
Boss sheets stay owned by generate_combat_frames.py / generate_parry_frames.py. Run after editing the rig:

    python tools/generate_hero_atlas.py

light keeps the original file names; heavy and great add the _heavy / _great suffix.
"""
import json
import sys
from pathlib import Path

from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
import hero_rig as R  # noqa: E402

ROOT = Path(__file__).resolve().parents[1]
FEEL = ROOT / 'presentation/feel_frames'
PARRY = ROOT / 'presentation/parry_frames'
COLS = 8
WEAPON_IDS = ('light', 'heavy', 'great')


def tint(atlas, color):
    out = Image.new('RGBA', atlas.size, color)
    out.putalpha(atlas.getchannel('A'))
    return out


def suffix(wid):
    return '' if wid == 'light' else '_' + wid


def build_weapon(wid):
    R.use_weapon(wid)
    states = R.atlas_states()
    total = sum(n for _, n, _ in states)
    rows = -(-total // COLS)
    atlas = Image.new('RGBA', (COLS * R.W, rows * R.H))
    mapping, tips, poses, flight, index = {}, {}, {}, {}, 0
    for name, n, build in states:
        mapping[name] = {'start': index, 'count': n}
        pts, joints, flight_joints = [], [], []
        for f in range(n):
            pose = build(f)
            im, skeleton, tip = R.render(pose)
            joints.append({key: [round(value[0]*R.SC,2),round(value[1]*R.SC,2)] for key,value in skeleton.items() if key in ("hip","shoulder","hand","foot_f","foot_b")})
            if name in ('jump','apex','fall','air_jump') or name.startswith('air_dash_'):
                record = {key:[round(skeleton[key][0]*R.SC,2),round(skeleton[key][1]*R.SC,2)] for key in ('hip','shoulder','head','hand','foot_f','foot_b')}
                record['wing_root']=[round((skeleton['shoulder'][0]-4)*R.SC,2),round((skeleton['shoulder'][1]+3)*R.SC,2)]
                record['rotation_degrees']=pose['rot']
                record['weapon_tip']=[round(tip[0]*R.SC,2),round(tip[1]*R.SC,2)]
                flight_joints.append(record)
            atlas.alpha_composite(im, ((index % COLS) * R.W, (index // COLS) * R.H))
            pts.append([round(tip[0] * R.SC), round(tip[1] * R.SC)])
            index += 1
        if name.startswith(('cut_', 'air_cut_')):
            tips[name] = pts
            poses[name] = joints
        if flight_joints:
            flight[name]=flight_joints
    ps = R.PARRY_STATES
    sheet = Image.new('RGBA', (4 * R.W, len(ps) * R.H))
    for row, state in enumerate(ps):
        for f in range(4):
            im, _, _ = R.render(R.parry(state, f))
            sheet.alpha_composite(im, (f * R.W, row * R.H))
    return atlas, mapping, total, tips, sheet, poses, flight


def main():
    results = {wid: build_weapon(wid) for wid in WEAPON_IDS}
    R.use_weapon('light')

    feel_weapons, parry_weapons = {}, {}
    for wid, (atlas, _, _, tips, sheet, poses, flight) in results.items():
        s = suffix(wid)
        atlas.save(FEEL / f'hero_atlas{s}.png')
        tint(atlas, '#63c5d2').save(FEEL / f'hero_silhouette{s}.png')
        tint(atlas, '#e8fff0').save(FEEL / f'hero_flash{s}.png')
        feel_weapons[wid] = {'weapon_design': R.WEAPONS[wid].get('design',wid), 'blade_length_source_px':R.WEAPONS[wid]['blade'], 'grip_length_source_px':R.WEAPONS[wid]['grip'], 'max_blade_width_source_px':max(R.WEAPONS[wid]['wfun'](i/20) for i in range(21)), 'motion': {'light':'point thrust / drill advance', 'heavy':'descending / rising / overhead cleaves', 'great':'two-handed pivot / reverse / full orbit'}[wid], 'active_frames':8, 'atlas': f'hero_atlas{s}.png', 'flash': f'hero_flash{s}.png',
                             'silhouette': f'hero_silhouette{s}.png', 'weapon_tips': tips, 'pose_joints':poses, 'flight_pose_joints':flight}
        sheet.save(PARRY / f'hero_parry{s}.png')
        tint(sheet, '#e8fff0').save(PARRY / f'hero_flash{s}.png')
        parry_weapons[wid] = {'parry': f'hero_parry{s}.png', 'flash': f'hero_flash{s}.png'}

    _, mapping, total, tips, sheet, _, _ = results['light']
    source = ('Dark-fantasy knight joint rig in tools/hero_rig.py (bascinet, pauldron, crimson cape and tabard, '
              'three independently posed swords: light thrust/drill, heavy cleaves, great orbit), eight active frames per attack, re-rasterised per frame at 4x then reduced with NEAREST.')
    manifest_path = FEEL / 'manifest.json'
    info = json.loads(manifest_path.read_text(encoding='utf-8'))
    info['hero'].update({'canvas': [R.W, R.H], 'anchor': list(R.ANCHOR), 'columns': COLS, 'states': mapping,
                         'flight_clips': {'air_dash_side': 'horizontal wing drive', 'air_dash_up':'upright ascent', 'air_dash_down':'controlled dive'}, 'total_frames': total, 'weapon_tips': tips, 'weapons': feel_weapons, 'source': source})
    manifest_path.write_text(json.dumps(info, indent=2) + '\n', encoding='utf-8', newline='\n')

    pm_path = PARRY / 'manifest.json'
    pm = json.loads(pm_path.read_text(encoding='utf-8'))
    pm['hero'].update({'canvas': [R.W, R.H], 'anchor': list(R.ANCHOR), 'weapons': parry_weapons, 'source': source})
    pm_path.write_text(json.dumps(pm, indent=2) + '\n', encoding='utf-8', newline='\n')
    print('hero frames', total, 'atlas', results['light'][0].size, 'parry sheet', sheet.size)


if __name__ == '__main__':
    main()

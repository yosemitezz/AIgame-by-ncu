"""Builds the hero atlas, silhouette, flash and parry sheets from tools/hero_rig.py.

Only the hero parts of presentation/feel_frames and presentation/parry_frames are touched; enemy, effect and
Boss sheets stay owned by generate_combat_frames.py / generate_parry_frames.py. Run after editing the rig:

    python tools/generate_hero_atlas.py
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


def tint(atlas, color):
    out = Image.new('RGBA', atlas.size, color)
    out.putalpha(atlas.getchannel('A'))
    return out


def main():
    states = R.atlas_states()
    total = sum(n for _, n, _ in states)
    rows = -(-total // COLS)
    atlas = Image.new('RGBA', (COLS * R.W, rows * R.H))
    mapping, tips, index = {}, {}, 0
    for name, n, build in states:
        mapping[name] = {'start': index, 'count': n}
        pts = []
        for f in range(n):
            im, _, tip = R.render(build(f))
            atlas.alpha_composite(im, ((index % COLS) * R.W, (index // COLS) * R.H))
            pts.append([round(tip[0] * R.SC), round(tip[1] * R.SC)])
            index += 1
        if name.startswith(('cut_', 'air_cut_')):
            tips[name] = pts
    atlas.save(FEEL / 'hero_atlas.png')
    tint(atlas, '#63c5d2').save(FEEL / 'hero_silhouette.png')
    tint(atlas, '#e8fff0').save(FEEL / 'hero_flash.png')

    manifest_path = FEEL / 'manifest.json'
    info = json.loads(manifest_path.read_text(encoding='utf-8'))
    info['hero'].update({'canvas': [R.W, R.H], 'anchor': list(R.ANCHOR), 'columns': COLS, 'states': mapping,
                         'total_frames': total, 'weapon_tips': tips})
    info['hero']['source'] = 'Joint rig in tools/hero_rig.py, re-rasterised per frame at 4x then reduced with NEAREST.'
    manifest_path.write_text(json.dumps(info, indent=2) + '\n', encoding='utf-8')

    ps = R.PARRY_STATES
    sheet = Image.new('RGBA', (4 * R.W, len(ps) * R.H))
    for row, state in enumerate(ps):
        for f in range(4):
            im, _, _ = R.render(R.parry(state, f))
            sheet.alpha_composite(im, (f * R.W, row * R.H))
    sheet.save(PARRY / 'hero_parry.png')
    tint(sheet, '#e8fff0').save(PARRY / 'hero_flash.png')
    pm_path = PARRY / 'manifest.json'
    pm = json.loads(pm_path.read_text(encoding='utf-8'))
    pm['hero'].update({'canvas': [R.W, R.H], 'anchor': list(R.ANCHOR)})
    pm_path.write_text(json.dumps(pm, indent=2) + '\n', encoding='utf-8')
    print('hero frames', total, 'atlas', atlas.size, 'parry sheet', sheet.size)


if __name__ == '__main__':
    main()

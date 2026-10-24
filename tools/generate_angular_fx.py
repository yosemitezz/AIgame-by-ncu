"""Angular combat effect sheets: faceted blade crescents, an ice-crystal thrust and a hexagram impact.

Replaces the rounded slash_1..3.png and hit.png written by generate_combat_frames.py with the same frame
sizes (96x96 x5 for slashes, 48x48 x5 for hit), so no code or manifest change is needed. Every shape is a
straight-edged polygon drawn without anti-aliasing at native resolution; nothing here is a circle or a smooth arc.
Run after generate_combat_frames.py:  python tools/generate_angular_fx.py
"""
from pathlib import Path
from PIL import Image, ImageDraw
import math

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'presentation/feel_frames'
P = {'ink': '#101626', 'deep': '#1d3b57', 'body': '#294e63', 'fold': '#4a98aa', 'edge': '#8bc6c9', 'ice': '#b5ecf2',
     'white': '#eff6d8', 'gold': '#d0a65b', 'pale': '#fff1bd', 'cyan': '#71ece1', 'coral': '#e5797b'}


def pt(x, y):
    return (round(x), round(y))


def shard(d, c, ang, length, width, fill, edge=None):
    """A thin kite: pointed tip, widest at 30 percent of its length, flat tail."""
    u = (math.cos(ang), math.sin(ang))
    n = (-u[1], u[0])
    tail = (c[0] - u[0] * length * 0.25, c[1] - u[1] * length * 0.25)
    mid = (c[0] + u[0] * length * 0.2, c[1] + u[1] * length * 0.2)
    tip = (c[0] + u[0] * length, c[1] + u[1] * length)
    poly = [pt(*tail), pt(mid[0] + n[0] * width, mid[1] + n[1] * width), pt(*tip), pt(mid[0] - n[0] * width, mid[1] - n[1] * width)]
    d.polygon(poly, fill=fill)
    d.line([pt(*tail), pt(*tip)], fill=edge or P['white'], width=1)


def crescent(combo, f, smooth=False):
    """Blade-shaped crescent built from four straight facets with sharp tips and crystal creases."""
    im = Image.new('RGBA', (96, 96))
    d = ImageDraw.Draw(im)
    rotation = [-0.9, -0.5, 0.05, 0.6, 1.0][f]
    height = [16, 28, 40, 28, 16][f]
    flip = -1 if combo == 2 else 1
    r_out = 8 + 22
    span = max(0.4, min(1.0, height / 40.0)) * math.radians(136)
    steps = 14 if smooth else 4   # smooth = round blade crescent, otherwise four straight facets
    thick = r_out * (0.34 + 0.2 * (height / 40.0))
    outer, inner = [], []
    for i in range(steps + 1):
        a = -span * 0.5 + span * i / steps + rotation
        k = math.sin(math.pi * i / steps)
        outer.append((42 + math.cos(a) * r_out, 48 + math.sin(a) * r_out * flip))
        # The inner edge pinches to the same point at both tips, so the crescent ends in blades.
        inner.append((42 + math.cos(a) * (r_out - thick * k), 48 + math.sin(a) * (r_out - thick * k) * flip))
    d.polygon([pt(*p) for p in outer + inner[::-1]], fill=P['body'])
    # Crystal creases: a line across every facet, alternating light and dark panels.
    for i in range(1, steps):
        if smooth:
            break
        d.line([pt(*inner[i]), pt(*outer[i])], fill=P['fold'] if i % 2 else P['deep'], width=1)
    for i in range(steps):
        if smooth:
            break
        mid_o = ((outer[i][0] + outer[i + 1][0]) / 2, (outer[i][1] + outer[i + 1][1]) / 2)
        mid_i = ((inner[i][0] + inner[i + 1][0]) / 2, (inner[i][1] + inner[i + 1][1]) / 2)
        d.polygon([pt(*outer[i]), pt(*outer[i + 1]), pt(*mid_i)], fill=P['fold'] if i % 2 == 0 else P['deep'])
    edge = [pt(*p) for p in outer]
    d.line(edge, fill=P['edge'], width=5 if f < 3 else 3)
    d.line(edge, fill=P['white'], width=2 if f < 3 else 1)
    for i, p in enumerate(edge):
        d.rectangle((p[0] - 1, p[1] - 1, p[0] + 1, p[1] + 1), fill=P['pale'])
    # Ice shards thrown off the leading tip.
    tip = outer[-1]
    base = math.atan2(outer[-1][1] - outer[-2][1], outer[-1][0] - outer[-2][0])
    if f >= 1:
        for k, (da, ln, wd) in enumerate([(0.0, 9, 2), (0.6, 7, 2), (-0.6, 7, 2)][: 1 + f // 2]):
            sx = tip[0] + math.cos(base) * (3 + 4 * k)
            sy = tip[1] + math.sin(base) * (3 + 4 * k)
            shard(d, (sx, sy), base + da, ln, wd, P['ice'] if k % 2 == 0 else P['cyan'])
    return im


def spear(f):
    """Finisher: a long faceted crystal lance with a hexagonal head and trailing shards."""
    im = Image.new('RGBA', (96, 96))
    d = ImageDraw.Draw(im)
    fronts = [55, 71, 84, 89, 91]
    length = [12, 31, 48, 35, 12]
    end = fronts[f]
    start = end - length[f]
    y = 48 + (f % 2)
    # Lance body: elongated hexagon.
    half = 6 if f in (1, 2, 3) else 4
    neck = start + (end - start) * 0.35
    body = [(start, y), (neck, y - half), (end - 8, y - half + 1), (end + 2, y), (end - 8, y + half - 1), (neck, y + half)]
    d.polygon([pt(*p) for p in body], fill=P['body'])
    d.polygon([pt(neck, y - half), pt(end - 8, y - half + 1), pt(end + 2, y), pt(end - 8, y), pt(neck, y - 1)], fill=P['fold'])
    d.polygon([pt(neck, y + half), pt(end - 8, y + half - 1), pt(end + 2, y), pt(end - 8, y), pt(neck, y + 1)], fill=P['deep'])
    d.line([pt(start + 2, y), pt(end + 2, y)], fill=P['white'], width=1)
    d.line([pt(*p) for p in body] + [pt(*body[0])], fill=P['edge'], width=1)
    # Hexagonal head glint at the tip.
    if f in (1, 2, 3):
        hx = end - 4
        hexa = [pt(hx + math.cos(a) * 7, y + math.sin(a) * 7) for a in [math.pi / 6 + i * math.pi / 3 for i in range(6)]]
        d.line(hexa + [hexa[0]], fill=P['pale'], width=1)
    # Shards peeling off behind the tip.
    for k in range(3):
        sy = y - 10 + k * 10
        sx = max(8, start - 4 - k * 6)
        if f >= 1:
            shard(d, (sx + 10, sy), math.pi, 12 - k * 2, 2, P['ice'] if k != 1 else P['cyan'])
    return im


def hit(f):
    """Impact: a spinning hexagram with spiky crystal arms, replacing the soft ring-and-lines burst."""
    size = 48
    im = Image.new('RGBA', (size, size))
    d = ImageDraw.Draw(im)
    c = size // 2
    radius = [4, 9, 14, 19, 21][f]
    spin = f * 0.18
    if f < 2:
        # White-hot jagged core.
        d.polygon([pt(c - 2, c - 2), pt(c - 8, c - 11), pt(c + 1, c - 4), pt(c + 11, c - 7), pt(c + 4, c + 1), pt(c + 8, c + 10), pt(c - 1, c + 3), pt(c - 11, c + 7)], fill=P['white'])
    width = 2 if f < 3 else 1
    for tri in range(2):
        pts = [pt(c + math.cos(spin + math.pi / 2 + tri * math.pi / 3 + i * 2 * math.pi / 3) * radius,
                  c + math.sin(spin + math.pi / 2 + tri * math.pi / 3 + i * 2 * math.pi / 3) * radius) for i in range(3)]
        d.line(pts + [pts[0]], fill=P['gold'] if tri == 0 else P['pale'], width=width)
    if f >= 1:
        rr = min(radius + 1, 21)
        d.ellipse((c - rr, c - rr, c + rr, c + rr), outline=P['cyan'] if f < 3 else P['gold'], width=1)
        dd = max(3, radius - 3)
        d.line([pt(c, c - dd), pt(c + dd, c), pt(c, c + dd), pt(c - dd, c), pt(c, c - dd)], fill=P['white'], width=1)
    # Six crystal arms between the star points.
    if f >= 1:
        for k in range(6):
            a = spin + k * math.pi / 3
            shard(d, (c + math.cos(a) * radius * 0.3, c + math.sin(a) * radius * 0.3), a, radius * 0.5 + 2, 2 if f < 3 else 1, P['gold'] if k % 2 else P['pale'])
    return im


def main():
    # Light cut: round crescent. Second cut: faceted crescent. Finisher: crystal lance. Hit: hexagram inside a round shock.
    for combo in (1, 2):
        sheet = Image.new('RGBA', (96 * 5, 96))
        for f in range(5):
            sheet.alpha_composite(crescent(combo, f, smooth=(combo == 1)), (96 * f, 0))
        sheet.save(OUT / f'slash_{combo}.png')
    sheet = Image.new('RGBA', (96 * 5, 96))
    for f in range(5):
        sheet.alpha_composite(spear(f), (96 * f, 0))
    sheet.save(OUT / 'slash_3.png')
    sheet = Image.new('RGBA', (48 * 5, 48))
    for f in range(5):
        sheet.alpha_composite(hit(f), (48 * f, 0))
    sheet.save(OUT / 'hit.png')
    print('angular fx written')


if __name__ == '__main__':
    main()

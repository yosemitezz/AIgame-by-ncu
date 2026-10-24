"""Joint rig for Bellkeep's hero, a dark-fantasy knight. Every frame is re-rasterised from joint positions, never rotated art.

Why a rig: legs, arms and blade are long (leg 27, arm 23), the torso has two segments plus a shoulder twist,
and each cut is described by where the sword arm points, so windups coil and active frames throw the whole
body through the cut. Knight bulk comes from armour pieces (pauldron, cuirass, tabard, cape), not from new
skeleton lengths. The hero can carry three swords (light, heavy, great); use_weapon() selects the sword spec
that every sword draw, floor clamp, smear and returned tip uses.

Local coordinates: x forward (hero faces +x, the game mirrors for -x), y down, origin at the feet
contact point on the ground. Frames are drawn at 4x and reduced with NEAREST so edges stay hard.
No external sheet, no 3D, no model output.
"""
import math
import json
from pathlib import Path
from PIL import Image, ImageDraw

W, H = 144, 128
ANCHOR = (66, 108)
K = 4
SC = 0.84
P = {'ink': '#0d1019', 'shade': '#33405a', 'cloak': '#7a2234', 'fold': '#a63348', 'edge': '#d4636a',
     'plate': '#6f7f93', 'metal': '#c3cfdc', 'white': '#f2f6fa', 'gold': '#c9a24f', 'skin': '#3a2a24',
     'cyan': '#8fe3ff', 'darkgold': '#6e5a2e', 'night': '#1b2230', 'wine': '#4e1623', 'leather': '#3a2a24',
     'ember': '#c8601e',
     'bl': '#c3cfdc', 'bl_dark': '#8c9db0', 'bl_hi': '#ffffff', 'sm1': '#8fb9d6', 'sm2': '#cfeaf7', 'smw': '#ffffff'}
FLOW = [(65, 224, 217), (72, 191, 237), (92, 151, 242), (122, 115, 228), (163, 103, 217), (205, 116, 205),
        (235, 139, 177), (246, 170, 137), (248, 207, 115)]

THIGH, SHIN = 14.2, 14.0
SEG_A, SEG_B = 8.5, 9.5           # waist-to-chest, chest-to-shoulder
UPPER, FORE = 12.0, 11.0
GRIP, BLADE = 6.0, 32.0           # light sword defaults, kept for reference; drawing uses SPEC
STAND_HIP = -(THIGH + SHIN) + 0.8

WEAPONS = {
    'light': dict(blade=32.0, grip=6.0, gw=2.6, guard=6.0, gthick=1.0, gbend=0.9, gat=1.6, pom=1.5, two=False, hb_dist=4.0,
                  steps=9, wfun=lambda t: 1.9 * (1 - t ** 3) + 0.35, bow=lambda t: 0.5 * math.sin(math.pi * t),
                  cut=False, fuller='hi', smear_w=12.0,
                  colors=dict(bl='#c3cfdc', bl_dark='#8c9db0', bl_hi='#ffffff', cyan='#8fe3ff',
                              sm1='#8fb9d6', sm2='#cfeaf7', smw='#ffffff')),
    'heavy': dict(blade=28.0, grip=6.0, gw=3.2, guard=9.0, gthick=1.8, gbend=0.8, gat=1.4, pom=2.5, two=False, hb_dist=4.0,
                  steps=9, wfun=lambda t: 4.6 * (1 - 0.30 * t * t), bow=lambda t: 0.9 * math.sin(math.pi * t),
                  cut=True, fuller='dark', smear_w=15.0,
                  colors=dict(bl='#8d9bab', bl_dark='#3d4859', bl_hi='#c3cfdc', cyan='#ff9a4a',
                              sm1='#9a2f2f', sm2='#ff9a4a', smw='#ffd9a0')),
    'great': dict(blade=46.0, grip=11.0, gw=2.8, guard=10.0, gthick=1.5, gbend=1.0, gat=1.6, pom=2.0, two=True, hb_dist=6.0,
                  steps=14, wfun=lambda t: 0.35 + 2.85 * (1 - t) ** 0.85, bow=lambda t: 0.0,
                  cut=False, fuller='hi', smear_w=14.0, ricasso=3.4,
                  colors=dict(bl='#b9c6d4', bl_dark='#6f7f93', bl_hi='#f0f6fb', cyan='#ffe9a0',
                              sm1='#b79a4e', sm2='#ffe9a0', smw='#fffbe8')),
}
ATTACK_DATA = json.loads((Path(__file__).resolve().parents[1] / 'data/hero_attack_profiles.json').read_text(encoding='utf-8'))

SPEC = WEAPONS['light']
WEAPON_ID = 'light'


def use_weapon(wid):
    """Select the active sword spec (light | heavy | great) and its colour family."""
    global SPEC, WEAPON_ID
    SPEC, WEAPON_ID = WEAPONS[wid], wid
    P.update(SPEC['colors'])


def sword_reach():
    return SPEC['gat'] + SPEC['gthick'] - 0.2 + SPEC['blade'] + 1.6


use_weapon('light')


def rad(d): return math.radians(d)
def vdir(deg): return (math.sin(rad(deg)), -math.cos(rad(deg)))      # angle from straight up, forward +
def adir(deg): return (math.cos(rad(deg)), math.sin(rad(deg)))       # standard angle, y down
def add(a, b): return (a[0] + b[0], a[1] + b[1])
def mul(a, s): return (a[0] * s, a[1] * s)
def lerp(a, b, t): return a + (b - a) * t
def lerp2(a, b, t): return (lerp(a[0], b[0], t), lerp(a[1], b[1], t))
def smooth(t): t = max(0.0, min(1.0, t)); return t * t * (3 - 2 * t)


def ik(a, t, l1, l2, prefer):
    dx, dy = t[0] - a[0], t[1] - a[1]
    d = max(abs(l1 - l2) + 0.05, min(l1 + l2 - 0.05, math.hypot(dx, dy)))
    base = math.atan2(dy, dx)
    c = (l1 * l1 + d * d - l2 * l2) / (2 * l1 * d)
    ang = math.acos(max(-1.0, min(1.0, c)))
    end = (a[0] + d * math.cos(base), a[1] + d * math.sin(base))
    best = None
    for s in (1, -1):
        j = (a[0] + l1 * math.cos(base + s * ang), a[1] + l1 * math.sin(base + s * ang))
        score = prefer(j)
        if best is None or score > best[0]:
            best = (score, j)
    return best[1], end


class Pen:
    def __init__(self):
        self.im = Image.new('RGBA', (W * K, H * K), (0, 0, 0, 0))
        self.d = ImageDraw.Draw(self.im)

    def px(self, p): return ((ANCHOR[0] + p[0] * SC) * K, (ANCHOR[1] + p[1] * SC) * K)

    def poly(self, pts, fill, ink=1.0):
        xy = [self.px(p) for p in pts]
        if ink:
            self.d.polygon(xy, fill=P['ink'])
            self.d.line(xy + [xy[0]], fill=P['ink'], width=max(K, int(1.6 * ink * K)), joint='curve')
        self.d.polygon(xy, fill=P.get(fill, fill))

    def circle(self, c, r, fill, ink=1.0):
        x, y = self.px(c)
        if ink:
            o = (r * SC + ink) * K
            self.d.ellipse((x - o, y - o, x + o, y + o), fill=P['ink'])
        o = r * SC * K
        self.d.ellipse((x - o, y - o, x + o, y + o), fill=P.get(fill, fill))

    def capsule(self, a, b, w0, w1, fill, ink=1.0):
        dx, dy = b[0] - a[0], b[1] - a[1]
        l = max(0.001, math.hypot(dx, dy))
        nx, ny = -dy / l, dx / l
        quad = [(a[0] + nx * w0 / 2, a[1] + ny * w0 / 2), (b[0] + nx * w1 / 2, b[1] + ny * w1 / 2),
                (b[0] - nx * w1 / 2, b[1] - ny * w1 / 2), (a[0] - nx * w0 / 2, a[1] - ny * w0 / 2)]
        if ink:
            self.circle(a, w0 / 2, 'ink', 0)
            self.circle(b, w1 / 2, 'ink', 0)
            self.circle(a, w0 / 2 + ink, 'ink', 0)
            self.circle(b, w1 / 2 + ink, 'ink', 0)
            self.poly(quad, 'ink', ink)
        self.poly(quad, fill, 0)
        self.circle(a, w0 / 2, fill, 0)
        self.circle(b, w1 / 2, fill, 0)

    def line(self, a, b, color, w=1.0):
        self.d.line([self.px(a), self.px(b)], fill=P.get(color, color), width=max(K, int(w * SC * K)))

    def result(self):
        out = self.im.resize((W, H), Image.Resampling.NEAREST)
        out.paste((0, 0, 0, 0), (0, ANCHOR[1] + 1, W, H))
        return out


def base_pose(**kw):
    p = dict(hip=(0.0, STAND_HIP), lean=6.0, curve=4.0, twist=0.0, head=0.0, ff=(9.0, 0.0), fb=(-8.0, 0.0),
             ffa=0.0, fba=0.0, arm=40.0, ext=0.55, blade=70.0, hb=None, wind=(-1.0, -0.25), scarf=1.0, phase=0.0,
             smear=None, rot=0.0, two_hand=False, glow=False, droop=0.0, elbow_up=False, sash=0.6, kneel=False)
    p.update(kw)
    return p


def skeleton(p):
    hip = p['hip']
    waist = add(hip, mul(vdir(p['lean']), SEG_A))
    chest_deg = p['lean'] + p['curve']
    shoulder = add(waist, mul(vdir(chest_deg), SEG_B))
    neck = add(shoulder, mul(vdir(chest_deg), 2.2))
    head = add(neck, mul(vdir(chest_deg + p['head']), 6.8))
    phi = rad(p['twist'] * 75.0)
    sep = 3.2 * math.sin(phi)
    sh_n = add(shoulder, (sep, 0.4))
    sh_f = add(shoulder, (-sep, -0.2))
    ank = lambda f, a: (f[0] - 2.2 * math.sin(rad(a)), f[1] - 2.4 * math.cos(rad(a)))
    knee_f, ank_f = ik(add(hip, (2.0, 0)), ank(p['ff'], p['ffa']), THIGH, SHIN, lambda j: j[0] - 0.35 * j[1])
    knee_b, ank_b = ik(add(hip, (-2.0, 0)), ank(p['fb'], p['fba']), THIGH, SHIN, lambda j: j[0] - 0.35 * j[1])
    reach = lerp(9.0, UPPER + FORE - 0.3, p['ext'])
    hand = add(sh_n, mul(adir(p['arm']), reach))
    prefer_e = (lambda j: -j[1]) if p['elbow_up'] else (lambda j: j[1] - 0.2 * j[0])
    elbow, hand = ik(sh_n, hand, UPPER, FORE, prefer_e)
    if SPEC['two']:
        hb_t = add(hand, mul(adir(p['blade'] + 180), SPEC['hb_dist']))     # two-handed sword: back hand on the grip
    elif p['hb'] is None:
        hb_t = add(sh_f, (4.0, 13.0))
    elif p['two_hand']:
        hb_t = add(hand, mul(adir(p['blade'] + 180), SPEC['hb_dist']))
    else:
        hb_t = add(sh_f, p['hb'])
    elbow_b, hand_b = ik(sh_f, hb_t, UPPER, FORE, lambda j: j[1] - 0.2 * j[0])
    S = dict(hip=hip, waist=waist, shoulder=shoulder, neck=neck, head=head, sh_n=sh_n, sh_f=sh_f,
             knee_f=knee_f, ank_f=ank_f, knee_b=knee_b, ank_b=ank_b, foot_f=p['ff'], foot_b=p['fb'],
             elbow=elbow, hand=hand, elbow_b=elbow_b, hand_b=hand_b)
    rot = p['rot']
    if rot:
        c = add(hip, (0, -9.0))
        cs, sn = math.cos(rad(rot)), math.sin(rad(rot))
        for k, v in list(S.items()):
            dx, dy = v[0] - c[0], v[1] - c[1]
            S[k] = (c[0] + dx * cs - dy * sn, c[1] + dx * sn + dy * cs)
    return S


def draw_cape(pen, S, p, rot):
    """Two-layer crimson cape from the shoulders, trailing along `wind`, with a ragged lower hem."""
    base0 = add(S['neck'], (-1.2, 0.8))
    wx, wy = p['wind']
    wy += 0.6 if p['scarf'] < 1.25 else 0.2           # hangs a little under its own weight
    n = math.hypot(wx, wy) or 1
    wx, wy = wx / n, wy / n
    layers = ((0.8, 1.6, 1.3, 2.6, 3.8, 2.2, 'wine'), (1.0, 1.9, 0.0, 3.0, 4.8, 0.0, 'cloak'))
    for layer, (ln, amp, off, hw0, hw1, dy0, fill) in enumerate(layers):
        start = add(base0, (0.3, dy0))
        pts, cur = [start], start
        segs = max(3, int(round(6 * ln * p['scarf'])))
        for i in range(segs):
            u = (i + 1) / segs
            wave = amp * math.sin(p['phase'] + off + i * 0.8) * u
            cur = (cur[0] + wx * 3.1 - wy * wave * 0.45, cur[1] + wy * 3.1 + wx * wave * 0.45 + p['droop'] * u * 0.7 + 0.35 * u)
            pts.append(cur)
        top, bot, d = [], [], (1.0, 0.0)
        for i, q in enumerate(pts):
            u = i / (len(pts) - 1)
            hw = lerp(hw0, hw1, u)
            if i == 0:
                d = (pts[1][0] - q[0], pts[1][1] - q[1])
            else:
                d = (q[0] - pts[i - 1][0], q[1] - pts[i - 1][1])
            l = math.hypot(*d) or 1
            d = (d[0] / l, d[1] / l)
            nx, ny = -d[1], d[0]
            top.append((q[0] + nx * hw, q[1] + ny * hw))
            bot.append((q[0] - nx * hw, q[1] - ny * hw))
        t_end, b_end = top[-1], bot[-1]
        hem = [add(lerp2(t_end, b_end, k / 4), mul(d, o)) for k, o in ((1, 2.0), (2, 0.3), (3, 1.7))]
        pen.poly(top + [add(t_end, mul(d, 0.8))] + hem + [add(b_end, mul(d, 0.6))] + bot[::-1], fill, 0.8)
        if layer == 1:
            pen.line(lerp2(top[1], bot[1], 0.5), lerp2(top[-2], bot[-2], 0.5), 'fold', 0.8)
            pen.line(top[1], top[-2], 'edge', 0.6)


def draw_boot(pen, foot, ang, back):
    u = adir(ang)
    v = (-u[1], u[0])
    loc = lambda a, b: (foot[0] + u[0] * a + v[0] * b, foot[1] + u[1] * a + v[1] * b)
    pts = [loc(-3.6, -6.0), loc(2.0, -6.0), loc(2.8, -2.6), loc(7.8, -1.0), loc(8.4, 0.0), loc(-3.6, 0.0)]
    pen.poly(pts, 'shade' if back else 'plate', 0.9)
    pen.poly([loc(4.5, -1.6), loc(8.2, -0.8), loc(8.4, 0.0), loc(4.0, 0.0)], 'metal', 0)
    if not back:
        pen.line(loc(-3.0, -5.0), loc(1.4, -5.0), 'gold', 0.5)


def draw_leg(pen, hip, knee, ank, foot, ang, back):
    shade, plate = ('night', 'shade') if back else ('plate', 'plate')
    pen.capsule(hip, knee, 6.4, 5.2, shade)
    pen.capsule(knee, ank, 5.0, 3.8, plate)
    pen.circle(knee, 2.6, 'metal' if not back else 'plate', 0.7)
    draw_boot(pen, foot, ang, back)


def draw_arm(pen, sh, elbow, hand, back):
    pen.capsule(sh, elbow, 4.8, 4.0, 'night' if back else 'shade')
    pen.capsule(elbow, hand, 4.2, 3.4, 'plate' if not back else 'shade')
    if not back:
        pen.circle(elbow, 2.1, 'metal', 0.6)


def draw_gauntlet(pen, hand, back=False):
    pen.circle(hand, 2.5, 'plate' if not back else 'shade', 0.7)
    pen.circle((hand[0] + 0.3, hand[1] - 0.6), 1.2, 'metal', 0)


def draw_sword(pen, hand, ang, glow):
    sp = SPEC
    u = adir(ang)
    n = (-u[1], u[0])
    L, G = sp['blade'], sp['grip']
    # Grip with wrap, then pommel.
    pen.capsule(add(hand, mul(u, -G)), add(hand, mul(u, 1.2)), sp['gw'], sp['gw'], 'leather', 0.8)
    for k in range(int(G / 1.8)):
        c = add(hand, mul(u, -G + 1.4 + k * 1.8))
        pen.line(add(c, mul(n, -sp['gw'] * 0.4)), add(c, mul(n, sp['gw'] * 0.4)), 'darkgold', 0.6)
    pc = add(hand, mul(u, -G - sp['pom'] * 0.5))
    pen.circle(pc, sp['pom'], 'gold', 0.8)
    pen.circle((pc[0] - 0.3, pc[1] - 0.4), sp['pom'] * 0.4, 'metal', 0)
    # Crossguard.
    hw = sp['guard'] / 2
    g_front, g_back = [], []
    for s in (-1.0, -0.5, 0.0, 0.5, 1.0):
        a = sp['gat'] + sp['gbend'] * s * s
        g_front.append(add(add(hand, mul(u, a)), mul(n, s * hw)))
        g_back.append(add(add(hand, mul(u, a + sp['gthick'])), mul(n, s * hw)))
    pen.poly(g_front + g_back[::-1], 'gold', 0.7)
    # Blade.
    b0 = sp['gat'] + sp['gthick'] - 0.2
    steps = sp['steps']
    mid, front, back = [], [], []
    for i in range(steps + 1):
        t = i / steps
        c = add(add(hand, mul(u, b0 + L * t)), mul(n, -sp['bow'](t)))
        w = sp['wfun'](t)
        mid.append(c)
        front.append(add(c, mul(n, -w * 0.45)))
        back.append(add(c, mul(n, w * 0.55)))
    if sp['cut']:
        back = back[:int(steps * 0.82) + 1]
        tip = add(front[-1], mul(u, 1.4))
    else:
        tip = add(add(hand, mul(u, b0 + L + 1.6)), mul(n, 0.0))
    pen.poly(front + [tip] + back[::-1], 'bl', 0.8)
    if sp.get('ricasso'):
        r = sp['ricasso'] / L
        j = max(1, int(r * steps + 0.5))
        pen.poly([front[0], front[j], back[j], back[0]], 'bl_dark', 0)
    j0, j1 = 1, len(front) - 2
    if sp['fuller'] == 'hi':
        pen.line(add(front[j0], mul(n, 0.2)), front[j1], 'bl_hi', 0.8)
    else:
        pen.line(mid[j0], mid[int(steps * 0.8)], 'bl_dark', 1.2)
        pen.line(add(front[j0], mul(n, 0.3)), front[int(steps * 0.75)], 'bl_hi', 0.6)
    if glow:
        pen.line(back[2], back[len(back) - 3 if sp['cut'] else -3], 'cyan', 0.6)
    return tip


def draw_smear(pen, S, p):
    a0, a1 = p['smear']
    hand = S['hand']
    L = SPEC['blade'] + 3.0
    steps = 9
    sw = SPEC['smear_w']
    outer = [add(hand, mul(adir(lerp(a0, a1, i / steps)), L)) for i in range(steps + 1)]
    inner = [add(hand, mul(adir(lerp(a0, a1, i / steps)), L - sw * (0.25 + 0.75 * (i / steps)))) for i in range(steps + 1)]
    pen.poly(outer + inner[::-1], 'sm1', 0)
    pen.poly([outer[i] for i in range(steps // 2, steps + 1)] + [inner[i] for i in range(steps, steps // 2 - 1, -1)], 'sm2', 0)
    pen.line(outer[1], outer[-1], 'smw', 0.7)


def draw_head(pen, S, p, rot):
    hc = S['head']
    tilt = rot + p['head'] + p['lean'] + p['curve']
    f = vdir(tilt)                         # up direction of the head
    r = (-f[1], f[0])                      # forward direction of the face
    loc = lambda a, b: (hc[0] + r[0] * a + f[0] * b, hc[1] + r[1] * a + f[1] * b)
    # Crimson plume swept back along the wind.
    wx, wy = p['wind']
    wy += 0.3
    nn = math.hypot(wx, wy) or 1
    wd = (wx / nn, wy / nn)
    wob = math.sin(p['phase'] * 1.3)
    q0 = loc(-1.0, 6.4)
    q1 = add(q0, add(mul(wd, 4.0), (0.0, -0.4)))
    q2 = add(q1, add(mul(wd, 4.0), (0.0, 0.9 + 0.5 * wob)))
    q3 = add(q2, add(mul(wd, 3.4), (0.0, 1.8 + 0.6 * wob)))
    pen.capsule(q0, q1, 3.4, 2.8, 'cloak', 0.8)
    pen.capsule(q1, q2, 2.8, 1.9, 'cloak', 0.8)
    pen.capsule(q2, q3, 1.9, 0.9, 'fold', 0.7)
    pen.line(q0, q2, 'fold', 0.7)
    # Gorget and closed bascinet.
    pen.circle(S['neck'], 3.0, 'shade', 0.7)
    pen.poly([loc(-5.2, -5.5), loc(-5.8, 0.5), loc(-4.2, 4.8), loc(-0.5, 7.0), loc(3.5, 6.2), loc(6.0, 3.0), loc(6.6, -1.0),
              loc(6.2, -5.5), loc(3.0, -7.0), loc(-3.0, -7.0)], 'plate', 0.9)
    pen.poly([loc(-5.2, -5.5), loc(-5.8, 0.5), loc(-4.2, 4.8), loc(-2.0, 4.0), loc(-2.8, -0.5), loc(-3.0, -6.6)], 'shade', 0)
    pen.poly([loc(-1.5, 6.0), loc(2.5, 5.6), loc(4.6, 3.4), loc(1.0, 4.2)], 'metal', 0)
    pen.line(loc(-5.4, 3.2), loc(6.2, 3.2), 'gold', 0.6)                       # brow band
    pen.poly([loc(1.0, 1.0), loc(6.8, 1.2), loc(6.8, -0.9), loc(1.0, -0.9)], 'ink', 0)    # visor slit
    pen.poly([loc(5.2, 0.5), loc(6.4, 0.5), loc(6.4, -0.3), loc(5.2, -0.3)], 'ember', 0)  # dim ember glint
    pen.line(loc(4.4, -2.6), loc(4.4, -5.2), 'ink', 0.5)                       # breaths
    pen.circle(loc(-1.0, 6.4), 1.2, 'gold', 0.5)                               # plume mount


def draw_torso(pen, S, p):
    hip, waist, sh, neck = S['hip'], S['waist'], S['shoulder'], S['neck']
    phi = rad(p['twist'] * 75.0)
    wide = 3.4 + 2.4 * abs(math.sin(phi))
    def side(a, b, wa, wb):
        dx, dy = b[0] - a[0], b[1] - a[1]
        l = math.hypot(dx, dy) or 1
        nx, ny = -dy / l, dx / l
        return [(a[0] + nx * wa, a[1] + ny * wa), (b[0] + nx * wb, b[1] + ny * wb), (b[0] - nx * wb, b[1] - ny * wb), (a[0] - nx * wa, a[1] - ny * wa)]
    pen.poly(side(hip, waist, 4.4, 4.0), 'shade', 0.9)
    pen.poly(side(waist, sh, 4.0 + 0.0, wide + 1.2), 'shade', 0.9)
    # Breastplate faces forward more as the twist opens it.
    mid = lerp2(waist, sh, 0.55)
    face = (0.4 + 0.6 * max(0.0, math.sin(phi) * 1.4)) * (.72 + .28 * p.get('roll', 1.0))
    pen.poly(side(lerp2(waist, sh, 0.15), lerp2(waist, sh, 0.92), 2.0 + 1.5 * face, 2.6 + 1.8 * face), 'plate', 0.7)
    pen.line(lerp2(waist, sh, 0.2), lerp2(waist, sh, 0.85), 'gold', 0.5)
    pen.line(add(lerp2(waist, sh, 0.7), (-1.6, 0.0)), add(lerp2(waist, sh, 0.7), (1.6, 0.0)), 'metal', 0.5)
    pen.circle(mid, 0.8, 'metal', 0)
    # Belt with buckle.
    bdir = vdir(p['lean'])
    pen.poly(side(add(hip, mul(bdir, 0.6)), add(hip, mul(bdir, 2.6)), 4.8, 4.8), 'leather', 0.7)
    pen.circle(add(add(hip, mul(bdir, 1.6)), mul(adir(p['lean']), 3.0)), 1.2, 'gold', 0.5)


def draw_tabard(pen, S, p):
    """Crimson surcoat flap hanging over the belt; sways a little with wind and phase."""
    hip = S['hip']
    bdir = vdir(p['lean'])
    fw = adir(p['lean'])
    bc = add(add(hip, mul(bdir, 1.2)), mul(fw, 1.5))
    tl, tr = add(bc, mul(fw, -3.0)), add(bc, mul(fw, 3.0))
    wx = p['wind'][0]
    sway = 1.0 * math.sin(p['phase'] * 1.3) * p['sash']
    off = lambda k: (wx * 1.6 * p['sash'] + sway * k, 0.0)
    bl = add(add(tl, (0.0, 9.0)), off(0.6))
    br = add(add(tr, (0.0, 9.0)), off(1.0))
    bm = add(add(bc, (0.0, 11.5)), off(0.8))
    pen.poly([tl, tr, br, bm, bl], 'cloak', 0.8)
    pen.line(lerp2(tl, tr, 0.5), bm, 'fold', 0.7)
    pen.line(bl, bm, 'gold', 0.5)
    pen.line(bm, br, 'gold', 0.5)


def draw_shoulder(pen, S, rot):
    s = S['sh_n']
    pen.poly([(s[0] - 2.0, s[1] - 3.6), (s[0] - 5.4, s[1] - 7.6), (s[0] + 1.2, s[1] - 4.4)], 'plate', 0.7)   # spike
    pen.circle(s, 4.6, 'gold', 0.8)                                       # rim
    pen.circle((s[0], s[1] + 0.2), 3.8, 'plate', 0)
    pen.circle((s[0] - 0.4, s[1] - 0.8), 2.2, 'metal', 0)
    pen.circle((s[0] + 1.6, s[1] + 1.4), 0.7, 'gold', 0)                  # rivet


def _render_once(p):
    pen = Pen()
    S = skeleton(p)
    rot = p['rot']
    sp = SPEC
    ang = p['blade'] + rot
    reach = sword_reach()
    floor_y = -1.5
    if S['hand'][1] + math.sin(rad(ang)) * reach > floor_y:
        s_t = max(-1.0, min(1.0, (floor_y - S['hand'][1]) / reach))
        c_sign = 1.0 if math.cos(rad(ang)) >= 0 else -1.0
        ang = math.degrees(math.atan2(s_t, c_sign * math.sqrt(max(0.0, 1 - s_t * s_t))))
    if sp['two']:
        tgt = add(S['hand'], mul(adir(ang), -sp['hb_dist']))
        S['elbow_b'], S['hand_b'] = ik(S['sh_f'], tgt, UPPER, FORE, lambda j: j[1] - 0.2 * j[0])
    if p['smear']:
        draw_smear(pen, S, p)
    draw_cape(pen, S, p, rot)
    rear_sword = bool(p.get('back_sword', False))
    if rear_sword:
        tip = draw_sword(pen, S['hand'], ang, p['glow'])
    draw_leg(pen, S['hip'], S['knee_b'], S['ank_b'], S['foot_b'], p['fba'] + rot, True)
    draw_arm(pen, S['sh_f'], S['elbow_b'], S['hand_b'], True)
    draw_torso(pen, S, p)
    draw_head(pen, S, p, rot)
    draw_leg(pen, S['hip'], S['knee_f'], S['ank_f'], S['foot_f'], p['ffa'] + rot, False)
    draw_tabard(pen, S, p)
    draw_shoulder(pen, S, rot)
    draw_arm(pen, S['sh_n'], S['elbow'], S['hand'], False)
    if not rear_sword:
        tip = draw_sword(pen, S['hand'], ang, p['glow'])
    draw_gauntlet(pen, S['hand'])
    if p['two_hand'] or sp['two']:
        draw_gauntlet(pen, S['hand_b'])
    return pen.result(), S, tip


def render(p):
    """Render one pose. If the active sword would leave the cell (under 1 px margin), shorten only the blade."""
    global SPEC
    full = SPEC
    if p.get('sword_scale'):
        SPEC = dict(full, blade=full['blade'] * p['sword_scale'])
    active_spec = SPEC
    try:
        for k in range(12):
            im, S, tip = _render_once(p)
            bb = im.getchannel('A').getbbox()
            if bb is None or min(bb[0], bb[1], W - bb[2], H - bb[3]) >= 1 or k == 11:
                return im, S, tip
            SPEC = dict(active_spec, blade=active_spec['blade'] - 2.0 * (k + 1))
    finally:
        SPEC = full


# ----------------------------------------------------------------------------------------------- poses

def stance(width, shift=0.0, crouch=0.0, **kw):
    """Grounded stance: feet are pinned to the floor and the hip drops by `crouch`."""
    fx, bx = shift + width * 0.55, shift - width * 0.45
    kw.setdefault('hip', (shift * 0.55, STAND_HIP + crouch))
    return base_pose(ff=(fx, 0.0), fb=(bx, 0.0), **kw)


def airborne(front_up, back_up, **kw):
    kw.setdefault('hip', (0.0, -34.0))
    return base_pose(ff=(7.0, min(front_up, -1.0)), fb=(-5.0, min(back_up, -1.0)), ffa=35, fba=45, **kw)


def idle(f, n=6):
    t = 2 * math.pi * f / n
    return stance(17, 1.0, crouch=1.4 + 0.9 * math.sin(t), lean=7 + 1.2 * math.sin(t), curve=4,
                  arm=62 + 4 * math.sin(t), ext=0.72, blade=48 + 3 * math.sin(t), hb=(5, 14), phase=t * 1.0,
                  wind=(-1, -0.35 + 0.15 * math.sin(t)), head=-2 * math.sin(t))


def run(f, n=8):
    t = 2 * math.pi * f / n
    A, B = 15.0, 8.5

    def foot(ph):
        ph = ph % (2 * math.pi)
        if ph < math.pi:
            return (A * math.cos(ph), 0.0), 0.0
        u = (ph - math.pi) / math.pi
        s = smooth(u)
        return (lerp(-A, A, s), -B * math.sin(math.pi * u)), 22.0 * math.sin(math.pi * u)
    ff, fa = foot(t)
    fb, ba = foot(t + math.pi)
    bob = -2.2 * (0.5 - 0.5 * math.cos(2 * t))
    return base_pose(hip=(2.0, -23.2 + bob + 0.8), lean=17, curve=5, ff=ff, fb=fb, ffa=fa, fba=ba, arm=165 + 10 * math.sin(t),
                     ext=0.7, blade=168 + 6 * math.sin(t), hb=(-4 + 9 * math.cos(t + math.pi), 9 - 3 * math.sin(t)), twist=0.25 * math.sin(t),
                     wind=(-1, -0.04 + 0.1 * math.sin(t)), scarf=1.35, phase=t * 2, head=-6, glow=True, sash=1.0)


def crouch_pose(c, f=0, hold=False):
    t = f * 1.6
    return base_pose(hip=(-1.0, STAND_HIP + 12.5 * c), lean=lerp(6, 24, c), curve=lerp(4, 10, c), head=lerp(0, -14, c),
                     ff=(lerp(9, 15, c), 0), fb=(lerp(-8, -9, c), 0), arm=lerp(62, 108, c), ext=0.6, blade=lerp(48, 150, c),
                     hb=(lerp(5, 3, c), 12), phase=t, wind=(-1, lerp(-0.35, -0.05, c)), twist=-0.25 * c,
                     ffa=0, fba=0, scarf=lerp(1, 1.2, c))


def crouch_walk(f, n=6):
    t = 2 * math.pi * f / n
    c = 0.95
    p = crouch_pose(c, f)
    p['ff'] = (15 + 6 * math.cos(t), -max(0, 4 * math.sin(t)))
    p['fb'] = (-9 - 6 * math.cos(t), -max(0, -4 * math.sin(t)))
    p['hip'] = (p['hip'][0], p['hip'][1] + 0.6 * math.sin(2 * t))
    p['twist'] = 0.2 * math.sin(t)
    return p


def jump_rise(f):
    # Upright lift: the shoulder leads, trailing boot extends rather than tucking into a roll.
    k = [1.0, .55, .15][f]
    return airborne(front_up=lerp(-17,-13,1-k), back_up=lerp(-5,-2,1-k),
                    hip=(lerp(0,2,1-k),lerp(-33,-35,1-k)), lean=lerp(8,15,1-k), curve=2,
                    arm=lerp(-62,-30,1-k), ext=.62, blade=lerp(-66,-22,1-k), hb=(-7,8),
                    wind=(-.6,1.0), scarf=1.3, phase=f*1.4, twist=.18, head=-6)


def apex(f):
    return airborne(front_up=-13+f, back_up=-4-f, hip=(1,-36), lean=12-f*2, curve=2,
                    arm=-16+f*3, ext=.65, blade=5+f*3, hb=(-6,11),
                    wind=(-1,.12), phase=f*1.1, scarf=1.2, twist=.12, head=-4)


def fall(f):
    k = [.2,.6,1.0][f]
    return airborne(front_up=lerp(-12,-4,k), back_up=lerp(-8,-2,k),
                    hip=(0,lerp(-36,-31,k)), lean=lerp(14,5,k), curve=2,
                    arm=lerp(12,36,k), ext=.65, blade=lerp(22,45,k), hb=(-7,9),
                    wind=(-.6,-1), scarf=1.3, phase=f*1.3, twist=.15, head=-4, droop=-.8)


def land(f):
    c = [0.8, 1.0, 0.6][f]
    return base_pose(hip=(0, STAND_HIP + 11 * c), lean=lerp(6, 22, c), curve=lerp(4, 10, c), ff=(14, 0), fb=(-12, 0), arm=95,
                     ext=0.55, blade=135, hb=(2, 14), wind=(-0.5, -0.8), phase=f * 1.7, head=-10 * c, twist=-0.2)


def air_jump(f, n=6):
    # Wing-powered launch, drive, then balance. No whole-body spin or upside-down frame.
    u = f / (n-1)
    drive = math.sin(math.pi*u)
    return airborne(front_up=-14-7*drive, back_up=-4-5*drive,
                    hip=(2*drive,-34-3*drive), lean=12+18*drive, curve=3+3*drive,
                    arm=lerp(-38,10,u), ext=.65+.18*drive, blade=lerp(-28,18,u),
                    hb=(-8,8), rot=0, wind=(-.8,.9-.7*u), phase=f*1.2,
                    scarf=1.25+.2*drive, head=-6-10*drive, twist=.18+.2*drive)


def air_dash(mode, f):
    # Re-articulated poses keep the head above the hip in every cardinal flight.
    # The feet anchor/collider is unchanged; only the air-only atlas cells are new.
    drive = [0.55,1.0,.9,.45][f]
    if mode == 'up':
        return base_pose(hip=(0,-35), lean=-7+8*drive, curve=2,
                         ff=(5,-16-3*drive), fb=(-8,-4), ffa=24, fba=18,
                         arm=-65-5*drive, ext=.72, blade=-84, hb=(-5,3),
                         wind=(-.3,1), scarf=1.5, phase=f*1.25, head=3,
                         twist=.18, glow=True, rot=0)
    if mode == 'down':
        return base_pose(hip=(0,-40), lean=18+13*drive, curve=3,
                         ff=(9,-10-4*drive), fb=(-13,-8), ffa=34, fba=20,
                         arm=15, ext=.3, blade=68, hb=(-5,7),
                         wind=(-.2,-1), scarf=1.45, phase=f*1.25,
                         head=-14, twist=.25, glow=True, rot=0)
    return base_pose(hip=(2,-34), lean=30+20*drive, curve=3,
                     ff=(9-7*drive,-13-4*drive), fb=(-17-3*drive,-6-3*drive),
                     ffa=34, fba=22, arm=-7, ext=.85+.08*drive, blade=-3,
                     hb=(-8,7), wind=(-1,.03), scarf=1.65,
                     phase=f*1.25, head=-24, twist=.45, glow=True, rot=0)


def dash(f):
    lean = [48, 56, 60, 52][f]
    return base_pose(hip=(4, -19), lean=lean, curve=3, ff=(21 + (f % 2), 0), fb=(-14 - (f % 3), -3 - (f % 2) * 2), ffa=5, fba=40,
                     arm=170, ext=0.9, blade=176, hb=(-7, 6), wind=(-1, 0.0), scarf=1.7, phase=f * 1.9, head=-30, twist=0.5,
                     glow=True, sash=1.4, droop=-0.5)


def parry(state, f):
    """Guard poses: blade stands vertical in front, recoil pushes the whole body back on its heels."""
    if state == 'parry_ready':
        k = [0.0, 0.55, 0.85, 1.0][f]
        return stance(15, 1.0, crouch=lerp(1, 4, k), lean=lerp(6, 3, k), arm=lerp(40, -40, k), ext=lerp(0.6, 0.85, k),
                      blade=lerp(60, -78, k), hb=(lerp(5, 8, k), lerp(14, 3, k)), two_hand=k > 0.7, twist=-0.15,
                      glow=True, phase=f * 1.1, wind=(-1, -0.2))
    if state == 'parry_recoil':
        k = [0.3, 0.8, 1.0, 0.9][f]
        return stance(19, -4.0 * k, crouch=2 + 6 * k, lean=lerp(0, -12, k), curve=-3, arm=-88 - 24 * k, ext=0.8, blade=-102 - 30 * k,
                      hb=(3, 2), two_hand=True, twist=-0.5 * k, glow=True, phase=f * 1.4, wind=(-0.6, -0.6), head=6 * k)
    k = [1.0, 0.65, 0.3, 0.0][f]
    return stance(16, lerp(0, -2, k), crouch=lerp(1.5, 5, k), lean=lerp(7, -5, k), arm=lerp(55, -112, k), ext=lerp(0.65, 0.8, k),
                  blade=lerp(50, -128, k), hb=(4, 10), two_hand=k > 0.5, twist=-0.3 * k, phase=f * 1.3, wind=(-1, -0.3))


def hurt(f):
    k = [0.5, 1.0, 0.85, 0.6][f]
    return base_pose(hip=(-5 * k, STAND_HIP + 6 * k), lean=-16 * k, curve=-8 * k, head=-12 * k, ff=(7, 0), fb=(-17, -2 * k), ffa=0, fba=25,
                     arm=lerp(30, 110, k), ext=0.4, blade=lerp(40, 118, k), hb=(-7, 6), wind=(-1, -0.7), phase=f * 2.1, twist=-0.6 * k, scarf=1.2)


def dead(f):
    k = [0.35, 0.7, 0.92, 1.0][f]
    return base_pose(hip=(-6 * k, lerp(STAND_HIP, -7.0, k)), lean=lerp(-6, -76, k), curve=lerp(0, -8, k), head=lerp(0, 18, k), ff=(lerp(7, 15, k), 0),
                     fb=(lerp(-15, -22, k), 0), ffa=0, fba=0, arm=lerp(70, 160, k), ext=0.4, blade=lerp(60, 175, k), hb=(-6, 8), wind=(-1, 0.35),
                     phase=f, twist=-0.4 * k, scarf=lerp(1, 0.7, k), droop=2.0 * k)


# Cut 1: high-to-low diagonal. Cut 2: low-to-high rising reverse. Cut 3: wide spin finisher.
# Rows are (arm angle, extension, blade angle, lean, curve, twist, hip x, crouch, front foot x, back foot x, hand_b, smear)
CUTS = {
    1: {'windup': [(-125, .62, -150, 4, 3, -.35, -1, 2, 12, -10, (-3, 6), None),
                   (-142, .55, -170, 0, 0, -.7, -3, 4, 12, -12, (-2, 4), None),
                   (-155, .5, 180, -6, -4, -.95, -4, 6, 13, -13, (-2, 2), None),
                   (-160, .48, 175, -9, -6, -1.0, -5, 7, 13, -14, (-3, 1), None)],
          'attack': [(-105, .95, -112, 4, 2, -.2, 2, 5, 22, -9, (-5, 6), (-150, -105)),
                     (-40, 1.0, -48, 14, 7, .5, 8, 7, 28, -8, (-6, 8), (-120, -40)),
                     (22, 1.0, 20, 24, 10, .95, 11, 8, 30, -8, (-7, 8), (-60, 22)),
                     (62, .98, 66, 28, 12, 1.0, 12, 8, 30, -8, (-7, 9), (-10, 66))],
          'recover': [(70, .9, 74, 26, 12, .85, 12, 8, 29, -8, (-6, 9), None),
                      (58, .8, 62, 20, 9, .55, 10, 6, 26, -7, (-5, 10), None),
                      (42, .7, 52, 14, 7, .3, 7, 4, 22, -7, (-4, 11), None),
                      (30, .62, 42, 9, 5, .1, 4, 2, 17, -7, (-3, 12), None)]},
    2: {'windup': [(60, .75, 72, 8, 3, .15, 2, 4, 19, -9, (-4, 9), None),
                   (82, .68, 96, 12, 4, .35, 3, 7, 20, -10, (-5, 8), None),
                   (100, .6, 118, 16, 4, .5, 3, 9, 21, -11, (-6, 7), None),
                   (112, .58, 128, 18, 3, .6, 3, 10, 21, -12, (-6, 6), None)],
          'attack': [(80, .95, 92, 18, 7, .55, 7, 9, 30, -10, (-6, 8), (122, 80)),
                     (22, 1.0, 14, 16, 8, .15, 8, 8, 30, -9, (-6, 7), (80, 12)),
                     (-52, 1.0, -62, 8, 7, -.4, 6, 6, 28, -8, (-4, 6), (14, -62)),
                     (-118, .92, -130, -2, 3, -.85, 3, 5, 24, -8, (-3, 4), (-60, -130))],
          'recover': [(-130, .85, -146, -6, 0, -.9, 1, 5, 22, -8, (-3, 4), None),
                      (-108, .75, -126, -2, 1, -.65, 1, 4, 20, -8, (-3, 5), None),
                      (-76, .66, -92, 2, 2, -.4, 1, 3, 18, -8, (-3, 7), None),
                      (-44, .6, -60, 5, 3, -.15, 0, 2, 16, -8, (-3, 9), None)]},
    3: {'windup': [(-150, .65, -168, 2, 0, -.5, -2, 6, 14, -12, (-4, 6), None),
                   (-168, .55, 178, -6, -5, -.9, -5, 9, 14, -14, (-3, 5), None),
                   (176, .5, 168, -12, -8, -1.0, -7, 12, 15, -15, (-3, 4), None),
                   (170, .48, 162, -15, -10, -1.0, -8, 13, 15, -16, (-3, 3), None)],
          'attack': [(-120, 1.0, -132, 6, 4, -.6, 0, 9, 26, -14, (-6, 6), (-175, -120)),
                     (-40, 1.0, -48, 18, 8, .1, 7, 10, 32, -12, (-6, 7), (-130, -40)),
                     (28, 1.0, 22, 28, 12, .8, 14, 11, 36, -11, (-8, 8), (-60, 28)),
                     (62, 1.0, 58, 32, 13, 1.0, 17, 11, 38, -10, (-8, 9), (-10, 62))],
          'recover': [(60, 1.0, 64, 30, 12, .95, 17, 11, 38, -10, (-7, 9), None),
                      (52, .92, 58, 26, 11, .7, 15, 10, 36, -10, (-6, 10), None),
                      (46, .85, 54, 22, 9, .5, 13, 9, 33, -10, (-6, 10), None),
                      (40, .78, 50, 16, 7, .3, 10, 7, 28, -9, (-5, 11), None)]},
}


def attack_profile(combo):
    """The visible steel direction samples the same authored keys as its energy sweep."""
    result = dict(ATTACK_DATA['combos'][str(combo)])
    result.update(ATTACK_DATA['weapons'][WEAPON_ID].get('combos', {}).get(str(combo), {}))
    return result


def key_value(keys, t):
    for i in range(1, len(keys)):
        a, b = keys[i - 1], keys[i]
        if t <= b[0]:
            return lerp(a[1], b[1], max(0, min(1, (t - a[0]) / max(.000001, b[0] - a[0]))))
    return keys[-1][1]


def _cut_ground_air(kw, air, hx, crouch, front, back, f):
    if air:
        # Free legs tuck and counterbalance the sword; feet are never pasted onto a floor.
        return airborne(front_up=-18 + 3 * math.sin(f * .8), back_up=-9 - 6 * math.cos(f * .9),
                        hip=(hx * .55, -34 + crouch * .23), **kw)
    return base_pose(hip=(hx, STAND_HIP + crouch), ff=(front, 0.0), fb=(back, 0.0), **kw)


def light_cut(combo, phase, f, air=False):
    t = f / (7 if phase == 'attack' else 3)
    drill = combo == 3
    low = combo == 2
    if phase == 'windup':
        q = smooth(t)
        kw = dict(lean=lerp(6, -12 if drill else -6, q), curve=lerp(3, -5, q),
                  twist=lerp(.2, -.95 if drill else -.65, q), arm=lerp(5, -164 if drill else -145, q),
                  ext=lerp(.7, .25, q), blade=lerp(0, -6 if low else 6, q), hb=(-7, 8),
                  wind=(-1, -.1), scarf=1.1, head=4 * q, phase=f * .7)
        return _cut_ground_air(kw, air, -6*q, 4+5*q, 12+3*q, -11-5*q, f)
    if phase == 'attack':
        profile = attack_profile(combo)
        extension = key_value(profile.get('thrust_keys', [[0,.1],[.25,.58],[.5,1],[1,.78]]), t)
        # Hips leave the heel before the shoulder and point fully extend.
        drive = smooth(min(1, t * 2.6))
        rotation = (t * math.tau * 1.8) if drill else (t * 2.3)
        kw = dict(lean=lerp(5, 48 if drill else 32, drive), curve=lerp(2, 9, drive),
                  twist=math.sin(rotation) * (.95 if drill else .4), arm=-4 + (-10 if low else 4) * (1-drive),
                  ext=lerp(.2, 1, extension), blade=-4 if low else 1,
                  hb=(-10, 2 + (math.cos(rotation) * 12 if drill else 7)),
                  wind=(-1, -.12 + .3*math.sin(rotation)), scarf=1.6 if drill else 1.25,
                  phase=f * 1.2, head=-18 if drill else -9, glow=True,
                  roll=math.cos(rotation) if drill else 1.0)
        p = _cut_ground_air(kw, air, 2+9*drive, 5+4*drive, 24+5*drive, -15-3*drive, f)
        if drill and .24 < t < .84:
            # The launched drill tucks both knees and alternates the near/far shin.
            # Joints are re-authored; no whole-sheet transform or invulnerability is involved.
            roll = math.sin((t-.24)/.60*math.tau*1.6)
            p['ff'] = (-4+9*roll, -5-9*max(0,roll))
            p['fb'] = (-19-6*roll, -5-9*max(0,-roll))
            p['ffa'] = 25+35*roll
            p['fba'] = 25-35*roll
            p['twist'] = roll
            p['roll'] = roll
            p['curve'] = 8+5*roll
        return p
    q = smooth(t)
    kw = dict(lean=lerp(43 if drill else 30, 9, q), curve=lerp(10, 4, q), twist=lerp(.8,.1,q),
              arm=lerp(-4, 48, q), ext=lerp(1,.6,q), blade=lerp(0,42,q), hb=(3,11),
              wind=(-1, -.6+.7*q), scarf=lerp(1.5,1.0,q), head=lerp(-17,-2,q), phase=5+f)
    return _cut_ground_air(kw, air, lerp(12,3,q), lerp(9,2,q), lerp(30,17,q), -12, f)


def heavy_cut(combo, phase, f, air=False):
    # Existing knight silhouette, newly articulated into three deliberately different sword paths.
    table = CUTS[combo][phase]
    v = f * (len(table)-1) / (7 if phase == 'attack' else 3)
    i, j = int(v), min(len(table)-1, int(v)+1)
    q = v - int(v)
    row=[]
    for a,b in zip(table[i],table[j]):
        if isinstance(a,(int,float)): row.append(lerp(a,b,q))
        elif isinstance(a,tuple) and isinstance(b,tuple): row.append(lerp2(a,b,q))
        else: row.append(a)
    a,e,b,lean,curve,tw,hx,cr,ffx,fbx,hb,smear=row
    if phase == 'attack':
        b = key_value(attack_profile(combo)['angle_keys'], f/7)
        a = b - (8 if combo == 3 else 3)
        cr += 3 if combo == 3 else 1
        lean += 5 if combo == 3 else 2
        smear = (b - (28 if combo != 2 else -28), b)
    kw = dict(lean=lean,curve=curve,twist=tw,arm=a,ext=e,blade=b,hb=hb,
              smear=smear if phase=='attack' else None,glow=phase=='attack',two_hand=combo==3,
              phase=f*1.2+combo,wind=(-1,-.25 if phase=='attack' else .1),scarf=1.5 if phase=='attack' else 1.1,
              head=-lean*.35,elbow_up=a < -60 and phase=='windup',sash=1.0)
    return _cut_ground_air(kw,air,hx,cr,ffx,fbx,f)


def great_cut(combo, phase, f, air=False):
    t=f/(7 if phase=='attack' else 3)
    reverse=-1 if combo==2 else 1
    if phase=='windup':
        q=smooth(t)
        kw=dict(lean=lerp(7,-10,q),curve=-4,twist=-reverse*(.25+.7*q),arm=lerp(40,165*reverse,q),
                ext=lerp(.65,.52,q),blade=lerp(48,175*reverse,q),two_hand=True,
                wind=(-1,.3),scarf=1.25,head=4,phase=f*.9)
        return _cut_ground_air(kw,air,-5*q,5+5*q,13+q,-13-2*q,f)
    if phase=='attack':
        deg=key_value(attack_profile(combo)['angle_keys'],t)
        theta=rad(deg)
        # Horizontal orbit: foreshorten the sword as it passes in front of/behind the chest,
        # keeping steel above the floor instead of rotating a whole bitmap through the ground.
        projected=math.degrees(math.atan2(math.sin(theta)*.46,math.cos(theta)))
        drive=math.sin(theta)
        kw=dict(lean=12+11*math.cos(theta),curve=5+3*drive,twist=math.cos(theta)*reverse,
                arm=projected,ext=.78+.2*abs(math.cos(theta)),blade=projected,
                two_hand=True,wind=(-math.cos(theta),-.15-.65*math.sin(theta)),scarf=1.45,
                phase=f*1.4,head=-5-6*math.cos(theta),glow=True,
                sword_scale=.62+.38*abs(math.cos(theta)),back_sword=math.sin(theta)>0,
                smear=(projected-25*reverse,projected))
        p=_cut_ground_air(kw,air,4*math.cos(theta),6+3*abs(drive),14+7*math.cos(theta),-13-5*math.cos(theta),f)
        if not air:
            p['ffa']=18*max(0,drive)
            p['fba']=-18*max(0,-drive)
        return p
    q=smooth(t)
    kw=dict(lean=lerp(21,7,q),curve=lerp(9,3,q),twist=lerp(reverse*.95,.1,q),arm=lerp(15,48,q),
            ext=lerp(.9,.65,q),blade=lerp(8,48,q),two_hand=True,wind=(-1,-.6+.7*q),
            scarf=lerp(1.5,1,q),head=lerp(-10,-1,q),phase=f*1.1)
    return _cut_ground_air(kw,air,lerp(7,1,q),lerp(9,2,q),lerp(24,17,q),-12,f)


def cut(combo, phase, f, air=False):
    return {'light':light_cut,'heavy':heavy_cut,'great':great_cut}[WEAPON_ID](combo,phase,f,air)


def atlas_states():
    """(name, frame count, builder) in atlas order. Builder maps frame index to a pose."""
    out = [('idle', 6, lambda f: idle(f)), ('run', 8, lambda f: run(f)),
           ('jump', 3, jump_rise), ('apex', 2, apex), ('fall', 3, fall), ('land', 3, land), ('air_jump', 6, air_jump),
           ('crouch_in', 3, lambda f: crouch_pose([0.35, 0.7, 0.92][f], f)), ('crouch', 4, lambda f: crouch_pose(1.0 + 0.0 * f, f)),
           ('crouch_out', 3, lambda f: crouch_pose([0.7, 0.35, 0.1][f], f)), ('crouch_walk', 6, crouch_walk),
           ('dash', 4, dash), ('hurt', 4, hurt), ('dead', 4, dead)]
    for combo in (1, 2, 3):
        for phase in ('windup', 'attack', 'recover'):
            out.append((f'cut_{combo}_{phase}', 8 if phase == 'attack' else 4, lambda f, c=combo, ph=phase: cut(c, ph, f)))
    for combo in (1, 2, 3):
        for phase in ('windup', 'attack', 'recover'):
            out.append((f'air_cut_{combo}_{phase}', 8 if phase == 'attack' else 4, lambda f, c=combo, ph=phase: cut(c, ph, f, air=True)))
    # Append only: original 155 frame indices remain stable for all weapon actions.
    for mode in ('side','up','down'):
        out.append((f'air_dash_{mode}',4,lambda f,m=mode:air_dash(m,f)))
    return out


PARRY_STATES = ['parry_ready', 'parry_recoil', 'parry_recover']


def parry_builder(state):
    return lambda f: parry(state, f)


def crouch_tweak(p):
    return p


if __name__ == '__main__':
    im, S, tip = render(idle(0))
    print(im.size, tip)

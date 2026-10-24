"""Joint rig for Bellkeep's hero. Every frame is re-rasterised from joint positions, never rotated art.

Why a rig: the previous hand-placed frames had ~15 px legs and a 22 px blade, so cuts barely moved the
body. Here legs, arms and blade are long (leg 27, arm 23, blade 32), the torso has two segments plus a
shoulder twist, and each cut is described by where the sword arm points, so windups coil and active
frames throw the whole body through the cut.

Local coordinates: x forward (hero faces +x, the game mirrors for -x), y down, origin at the feet
contact point on the ground. Frames are drawn at 4x and reduced with NEAREST so edges stay hard.
No external sheet, no 3D, no model output.
"""
import math
from PIL import Image, ImageDraw

W, H = 144, 128
ANCHOR = (66, 108)
K = 4
SC = 0.84
P = {'ink': '#101626', 'shade': '#24354e', 'cloak': '#326e89', 'fold': '#4a98aa', 'edge': '#8bc6c9',
     'plate': '#7a98ae', 'metal': '#b5d6da', 'white': '#eff6d8', 'gold': '#d0a65b', 'skin': '#c8bf93',
     'cyan': '#71ece1', 'darkgold': '#6e624b', 'night': '#182338'}
FLOW = [(65, 224, 217), (72, 191, 237), (92, 151, 242), (122, 115, 228), (163, 103, 217), (205, 116, 205),
        (235, 139, 177), (246, 170, 137), (248, 207, 115)]

THIGH, SHIN = 14.2, 14.0
SEG_A, SEG_B = 8.5, 9.5           # waist-to-chest, chest-to-shoulder
UPPER, FORE = 12.0, 11.0
GRIP, BLADE = 6.0, 32.0
STAND_HIP = -(THIGH + SHIN) + 0.8


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
    if p['hb'] is None:
        hb_t = add(sh_f, (4.0, 13.0))
    elif p['two_hand']:
        hb_t = add(hand, mul(adir(p['blade'] + 180), 4.0))
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


def draw_scarf(pen, S, p, rot):
    base = add(S['neck'], (-1.5, 0.5))
    wx, wy = p['wind']
    n = math.hypot(wx, wy) or 1
    wx, wy = wx / n, wy / n
    for tail, (length, amp, off) in enumerate(((10, 1.9, 0.0), (6, 1.3, 2.2))):
        pts, cur = [base], base
        segs = int(length * p['scarf'])
        for i in range(max(2, segs)):
            u = (i + 1) / max(2, segs)
            wave = amp * math.sin(p['phase'] + off + i * 0.85) * u
            cur = (cur[0] + wx * 3.7 + -wy * wave * 0.5, cur[1] + wy * 3.7 + wx * wave * 0.5 + p['droop'] * u * 0.7)
            pts.append(cur)
        top, bot = [], []
        for i, q in enumerate(pts):
            u = i / (len(pts) - 1)
            hw = lerp(2.3, 0.7, u) if tail == 0 else lerp(1.7, 0.5, u)
            if i == 0:
                d = (pts[1][0] - q[0], pts[1][1] - q[1])
            else:
                d = (q[0] - pts[i - 1][0], q[1] - pts[i - 1][1])
            l = math.hypot(*d) or 1
            nx, ny = -d[1] / l, d[0] / l
            top.append((q[0] + nx * hw, q[1] + ny * hw))
            bot.append((q[0] - nx * hw, q[1] - ny * hw))
        pen.poly(top + bot[::-1], 'fold' if tail == 0 else 'cloak', 0.8)
        pen.line(top[1], top[-2], 'edge', 0.8)
        pen.circle(pts[-1], 0.9, 'cyan', 0)


def draw_boot(pen, foot, ang, back):
    u = adir(ang)
    v = (-u[1], u[0])
    loc = lambda a, b: (foot[0] + u[0] * a + v[0] * b, foot[1] + u[1] * a + v[1] * b)
    pts = [loc(-3.6, -6.0), loc(2.0, -6.0), loc(2.8, -2.6), loc(7.8, -1.0), loc(8.4, 0.0), loc(-3.6, 0.0)]
    pen.poly(pts, 'shade' if back else 'plate', 0.9)
    pen.poly([loc(4.5, -1.6), loc(8.2, -0.8), loc(8.4, 0.0), loc(4.0, 0.0)], 'metal', 0)


def draw_leg(pen, hip, knee, ank, foot, ang, back):
    shade, plate = ('night', 'shade') if back else ('shade', 'plate')
    pen.capsule(hip, knee, 6.4, 5.2, shade)
    pen.capsule(knee, ank, 5.0, 3.8, plate)
    pen.circle(knee, 2.6, 'metal' if not back else 'plate', 0.7)
    draw_boot(pen, foot, ang, back)


def draw_arm(pen, sh, elbow, hand, back):
    pen.capsule(sh, elbow, 4.8, 4.0, 'night' if back else 'cloak')
    pen.capsule(elbow, hand, 4.0, 3.2, 'plate' if not back else 'shade')
    pen.circle(hand, 2.3, 'gold' if not back else 'darkgold', 0.7)


def draw_sword(pen, hand, ang, glow):
    u = adir(ang)
    n = (-u[1], u[0])
    pen.capsule(add(hand, mul(u, -GRIP)), add(hand, mul(u, 1.2)), 2.6, 2.6, 'night', 0.8)
    for k in range(3):
        c = add(hand, mul(u, -GRIP + 1.4 + k * 1.8))
        pen.line(add(c, mul(n, -1.1)), add(c, mul(n, 1.1)), 'gold', 0.6)
    pen.poly([add(add(hand, mul(u, 1.6)), mul(n, 3.2)), add(add(hand, mul(u, 2.4)), mul(n, 3.2)),
              add(add(hand, mul(u, 2.4)), mul(n, -3.2)), add(add(hand, mul(u, 1.6)), mul(n, -3.2))], 'gold', 0.7)
    front, back = [], []
    steps = 9
    for i in range(steps + 1):
        t = i / steps
        along = 2.6 + BLADE * t
        bow = 2.4 * math.sin(math.pi * t) * (1 - 0.35 * t)
        w = 1.9 * (1 - t ** 3) + 0.35
        c = add(add(hand, mul(u, along)), mul(n, -bow))
        front.append(add(c, mul(n, -w * 0.45)))
        back.append(add(c, mul(n, w * 0.55)))
    tip = add(add(hand, mul(u, 2.6 + BLADE + 1.6)), mul(n, 0.0))
    pen.poly(front + [tip] + back[::-1], 'metal', 0.8)
    pen.line(add(front[1], mul(n, 0.2)), front[-2], 'white', 0.8)
    if glow:
        pen.line(back[2], back[-3], 'cyan', 0.6)
    return tip


def draw_smear(pen, S, p):
    a0, a1 = p['smear']
    hand = S['hand']
    L = BLADE + 3.0
    steps = 9
    outer = [add(hand, mul(adir(lerp(a0, a1, i / steps)), L)) for i in range(steps + 1)]
    inner = [add(hand, mul(adir(lerp(a0, a1, i / steps)), L - 12.0 * (0.25 + 0.75 * (i / steps)))) for i in range(steps + 1)]
    pen.poly(outer + inner[::-1], 'fold', 0)
    pen.poly([outer[i] for i in range(steps // 2, steps + 1)] + [inner[i] for i in range(steps, steps // 2 - 1, -1)], 'edge', 0)
    pen.line(outer[1], outer[-1], 'white', 0.7)


def draw_head(pen, S, p, rot):
    hc = S['head']
    tilt = rot + p['head'] + p['lean'] + p['curve']
    f = vdir(tilt)                         # up direction of the head
    r = (-f[1], f[0])                      # forward direction of the face
    r = (r[0], r[1])
    loc = lambda a, b: (hc[0] + r[0] * a + f[0] * b * -1 * -1, hc[1] + r[1] * a + f[1] * b)
    # Hood with a long swept-back point.
    wx, wy = p['wind']
    peak = (hc[0] + wx * 12.5 - 0.0, hc[1] + wy * 4.0 - 2.5)
    pen.poly([loc(-5.5, 1.5), loc(-3.0, 5.8), loc(2.5, 6.8), loc(6.0, 3.5), loc(7.2, -1.5), loc(5.5, -5.5),
              loc(0.0, -7.2), loc(-5.0, -5.0)], 'shade', 0.9)
    pen.poly([loc(-4.0, 4.2), peak, loc(-5.5, -4.5)], 'cloak', 0.8)
    pen.poly([loc(0.5, 4.8), loc(5.4, 3.0), loc(6.6, -1.2), loc(4.4, -4.4), loc(0.2, -4.0)], 'skin', 0.5)
    pen.poly([loc(-0.5, -4.4), loc(4.8, -4.8), loc(6.8, -1.6), loc(3.2, -2.4)], 'shade', 0)
    pen.poly([loc(4.0, -1.8), loc(6.6, -1.8), loc(6.6, -0.4), loc(4.0, -0.4)], 'ink', 0)
    pen.poly([loc(4.6, -1.6), loc(6.2, -1.6), loc(6.2, -0.8), loc(4.6, -0.8)], 'cyan', 0)
    pen.poly([loc(-1.0, 4.2), loc(5.6, 3.0), loc(6.0, 5.2), loc(0.0, 6.6)], 'fold', 0.5)       # face wrap


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
    pen.poly(side(waist, sh, 4.0 + 0.0, wide + 1.2), 'cloak', 0.9)
    # Chest plate faces forward more as the twist opens it.
    mid = lerp2(waist, sh, 0.55)
    face = 0.4 + 0.6 * max(0.0, math.sin(phi) * 1.4)
    pen.poly(side(lerp2(waist, sh, 0.15), lerp2(waist, sh, 0.92), 2.0 + 1.5 * face, 2.6 + 1.8 * face), 'plate', 0.7)
    pen.line(lerp2(waist, sh, 0.2), lerp2(waist, sh, 0.85), 'cyan', 0.6)
    pen.circle(mid, 0.9, 'metal', 0)
    # Belt and sash tails.
    bdir = vdir(p['lean'])
    pen.poly(side(add(hip, mul(bdir, 0.6)), add(hip, mul(bdir, 2.6)), 4.8, 4.8), 'gold', 0.7)
    wx, wy = p['wind']
    for i, (ln, sg) in enumerate(((10, 1), (7, 2))):
        a = add(hip, (-1.5 * sg, 0.8))
        b = (a[0] + wx * ln * p['sash'] * 0.8 - 0.8, a[1] + 3.5 + wy * 2 + ln * 0.5 * (1 - abs(wx) * 0.3))
        pen.capsule(a, b, 3.4, 1.4, 'darkgold' if i else 'gold', 0.7)


def draw_shoulder(pen, S, rot):
    s = S['sh_n']
    pen.circle(s, 4.1, 'plate', 0.8)
    pen.circle((s[0] + 0.3, s[1] - 0.4), 2.7, 'metal', 0)
    pen.poly([(s[0] - 2.0, s[1] - 3.6), (s[0] - 5.4, s[1] - 7.6), (s[0] + 1.2, s[1] - 4.4)], 'plate', 0.7)


def render(p):
    pen = Pen()
    S = skeleton(p)
    rot = p['rot']
    if p['smear']:
        draw_smear(pen, S, p)
    draw_scarf(pen, S, p, rot)
    draw_leg(pen, S['hip'], S['knee_b'], S['ank_b'], S['foot_b'], p['fba'] + rot, True)
    draw_arm(pen, S['sh_f'], S['elbow_b'], S['hand_b'], True)
    draw_torso(pen, S, p)
    draw_head(pen, S, p, rot)
    draw_leg(pen, S['hip'], S['knee_f'], S['ank_f'], S['foot_f'], p['ffa'] + rot, False)
    draw_shoulder(pen, S, rot)
    draw_arm(pen, S['sh_n'], S['elbow'], S['hand'], False)
    if p['two_hand']:
        pen.circle(S['hand_b'], 2.2, 'gold', 0.6)
    ang = p['blade'] + rot
    reach = 2.6 + BLADE + 1.6
    floor_y = -1.5
    if S['hand'][1] + math.sin(rad(ang)) * reach > floor_y:
        s_t = max(-1.0, min(1.0, (floor_y - S['hand'][1]) / reach))
        c_sign = 1.0 if math.cos(rad(ang)) >= 0 else -1.0
        ang = math.degrees(math.atan2(s_t, c_sign * math.sqrt(max(0.0, 1 - s_t * s_t))))
    tip = draw_sword(pen, S['hand'], ang, p['glow'])
    return pen.result(), S, tip


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
    k = [1.0, 0.55, 0.15][f]
    return airborne(front_up=lerp(-17, -23, 1 - k), back_up=lerp(2.0, -6, 1 - k), hip=(0, lerp(-31, -34, 1 - k)), lean=lerp(10, 2, 1 - k),
                    curve=3, arm=lerp(-118, -70, 1 - k), ext=0.8, blade=lerp(-128, -80, 1 - k), hb=(lerp(-8, 6, 1 - k), lerp(-6, -2, 1 - k)),
                    wind=(-0.35, 0.95), scarf=1.2, phase=f * 1.4, twist=0.3)


def apex(f):
    t = f * 1.1
    return airborne(front_up=-20 + f, back_up=-15, hip=(0, -37), lean=-2, curve=4, arm=-35, ext=0.7, blade=-12, hb=(5, 10),
                    wind=(-0.9, 0.05), phase=t, scarf=1.0, twist=0.15, head=2)


def fall(f):
    k = [0.2, 0.6, 1.0][f]
    return airborne(front_up=lerp(-8, 3, k), back_up=lerp(-3, 6, k), hip=(0, lerp(-36, -31, k)), lean=lerp(0, -4, k), curve=0,
                    arm=lerp(-70, -112, k), ext=0.9, blade=lerp(-52, -95, k), hb=(-6, -8), wind=(-0.25, -1.0), scarf=1.3,
                    phase=f * 1.3, twist=0.2, head=3, droop=-1.5)


def land(f):
    c = [0.8, 1.0, 0.6][f]
    return base_pose(hip=(0, STAND_HIP + 11 * c), lean=lerp(6, 22, c), curve=lerp(4, 10, c), ff=(14, 0), fb=(-12, 0), arm=95,
                     ext=0.55, blade=135, hb=(2, 14), wind=(-0.5, -0.8), phase=f * 1.7, head=-10 * c, twist=-0.2)


def air_jump(f, n=6):
    u = f / (n - 1)
    ang = -360.0 * smooth(u) * 0.97
    return airborne(front_up=-24, back_up=-20, hip=(0, -36), lean=18, curve=8, arm=lerp(-20, 30, u), ext=0.5, blade=lerp(10, 60, u),
                    hb=(6, 8), rot=ang, wind=(-0.5, 0.6), phase=f * 1.8, scarf=1.4, head=-8)


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


def cut(combo, phase, f, air=False):
    a, e, b, lean, curve, tw, hx, cr, ffx, fbx, hb, smear = CUTS[combo][phase][f]
    kw = dict(lean=lean, curve=curve, twist=tw, arm=a, ext=e, blade=b, hb=hb, smear=smear, glow=(phase == 'attack'),
              two_hand=(combo == 3 and phase != 'recover'), phase=f * 1.2 + combo, wind=(-1, -0.2 if phase == 'attack' else 0.1),
              scarf=1.5 if phase == 'attack' else 1.1, head=-lean * 0.35, elbow_up=(a < -60 and phase == 'windup'), sash=1.0)
    if air:
        return airborne(front_up=-18 + (f % 2), back_up=-12, hip=(hx * 0.5, -33 + cr * 0.25), **kw)
    return stance(ffx - fbx, (ffx + fbx) * 0.5 - 0.0, crouch=cr, **{**kw, 'hip': (hx, STAND_HIP + cr)}) if False else \
        base_pose(hip=(hx, STAND_HIP + cr), ff=(ffx, 0.0), fb=(fbx, 0.0), **kw)


def atlas_states():
    """(name, frame count, builder) in atlas order. Builder maps frame index to a pose."""
    out = [('idle', 6, lambda f: idle(f)), ('run', 8, lambda f: run(f)),
           ('jump', 3, jump_rise), ('apex', 2, apex), ('fall', 3, fall), ('land', 3, land), ('air_jump', 6, air_jump),
           ('crouch_in', 3, lambda f: crouch_pose([0.35, 0.7, 0.92][f], f)), ('crouch', 4, lambda f: crouch_pose(1.0 + 0.0 * f, f)),
           ('crouch_out', 3, lambda f: crouch_pose([0.7, 0.35, 0.1][f], f)), ('crouch_walk', 6, crouch_walk),
           ('dash', 4, dash), ('hurt', 4, hurt), ('dead', 4, dead)]
    for combo in (1, 2, 3):
        for phase in ('windup', 'attack', 'recover'):
            out.append((f'cut_{combo}_{phase}', 4, lambda f, c=combo, ph=phase: cut(c, ph, f)))
    for combo in (1, 2, 3):
        for phase in ('windup', 'attack', 'recover'):
            out.append((f'air_cut_{combo}_{phase}', 4, lambda f, c=combo, ph=phase: cut(c, ph, f, air=True)))
    return out


PARRY_STATES = ['parry_ready', 'parry_recoil', 'parry_recover']


def parry_builder(state):
    return lambda f: parry(state, f)


def crouch_tweak(p):
    return p


if __name__ == '__main__':
    im, S, tip = render(idle(0))
    print(im.size, tip)

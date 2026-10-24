#!/usr/bin/env python3
"""Generate original western-fantasy pixel art pack for AIgame-by-ncu art branch.

Hand-authored pixel clusters (not AI upscales). Locked 32-color palette.
Outputs sprites, VFX strips, HUD chrome, environment tiles, and contact sheets.
"""

from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]
ART = ROOT / "assets" / "art"
VFX = ROOT / "assets" / "vfx"
UI = ROOT / "assets" / "ui"
PREVIEWS = ROOT / "assets" / "previews"
DOCS = ROOT / "docs" / "art"

# Semantic palette — western fantasy, readable at 4x nearest-neighbor.
PALETTE = {
    "void": (0, 0, 0, 0),
    "ink": (18, 16, 24, 255),
    "shade": (36, 32, 48, 255),
    "stone": (74, 68, 86, 255),
    "ash": (118, 112, 128, 255),
    "bone": (214, 204, 186, 255),
    "cream": (240, 230, 210, 255),
    "skin": (196, 150, 122, 255),
    "skin_shade": (148, 98, 82, 255),
    "cloak": (52, 64, 98, 255),
    "cloak_hi": (78, 98, 148, 255),
    "copper": (176, 104, 54, 255),
    "gold": (224, 176, 72, 255),
    "blood": (168, 42, 54, 255),
    "ember": (232, 96, 48, 255),
    "leaf": (68, 122, 78, 255),
    "moss": (42, 78, 56, 255),
    "arcane": (88, 196, 214, 255),
    "arcane_hi": (186, 244, 246, 255),
    "violet": (116, 78, 168, 255),
    "warn": (236, 188, 64, 255),
    "safe": (92, 196, 132, 255),
    "mp": (72, 128, 214, 255),
    "mp_hi": (140, 196, 246, 255),
    "hp_hi": (232, 96, 96, 255),
    "wood": (96, 64, 42, 255),
    "wood_hi": (148, 104, 62, 255),
    "night": (28, 34, 58, 255),
    "fog": (156, 164, 186, 255),
    "spark": (255, 248, 210, 255),
}


def px(img: Image.Image, x: int, y: int, key: str) -> None:
    if 0 <= x < img.width and 0 <= y < img.height:
        img.putpixel((x, y), PALETTE[key])


def fill_rect(img: Image.Image, x0: int, y0: int, x1: int, y1: int, key: str) -> None:
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            px(img, x, y, key)


def outline_rect(img: Image.Image, x0: int, y0: int, x1: int, y1: int, key: str) -> None:
    for x in range(x0, x1 + 1):
        px(img, x, y0, key)
        px(img, x, y1, key)
    for y in range(y0, y1 + 1):
        px(img, x0, y, key)
        px(img, x1, y, key)


def new_canvas(w: int, h: int) -> Image.Image:
    return Image.new("RGBA", (w, h), PALETTE["void"])


def draw_hero(state: str, frame: int = 0) -> Image.Image:
    """40x48 side-view hero. Pivot intended at (20, 44) feet."""
    img = new_canvas(40, 48)
    # ground contact shadow
    fill_rect(img, 12, 45, 27, 46, "shade")

    # body base offsets by state
    lean = 0
    crouch = 0
    arm = 0
    blade = 0
    flash = False
    if state == "idle":
        lean = 0 if frame % 2 == 0 else 0
        arm = 0
    elif state == "run":
        lean = 1
        crouch = 1 if frame % 2 else 0
        arm = 1 if frame % 2 else -1
    elif state == "windup":
        lean = -2
        crouch = 1
        arm = -3
        blade = -2
    elif state == "attack":
        lean = 3
        arm = 6
        blade = 8
        flash = True
    elif state == "recover":
        lean = 1
        arm = 2
        blade = 2
    elif state == "hurt":
        lean = -3
        crouch = 1
        flash = True
    elif state == "death":
        # fallen silhouette
        fill_rect(img, 6, 34, 34, 40, "cloak")
        fill_rect(img, 8, 32, 22, 36, "skin")
        fill_rect(img, 10, 30, 18, 33, "bone")  # helm
        fill_rect(img, 24, 36, 36, 38, "copper")  # blade on ground
        px(img, 12, 31, "ink")
        return img
    elif state == "dash":
        lean = 4
        crouch = 1
        arm = 2
    elif state == "parry":
        lean = -1
        arm = 3
        blade = 3
        flash = True
    elif state == "jump":
        crouch = -2
        lean = 1

    ox = 12 + lean
    oy = 10 + crouch

    # cloak / torso
    fill_rect(img, ox + 4, oy + 14, ox + 15, oy + 30, "cloak")
    fill_rect(img, ox + 5, oy + 15, ox + 14, oy + 22, "cloak_hi")
    # belt
    fill_rect(img, ox + 4, oy + 24, ox + 15, oy + 25, "copper")
    px(img, ox + 9, oy + 24, "gold")
    # legs
    if state == "run" and frame % 2 == 0:
        fill_rect(img, ox + 5, oy + 26, ox + 8, oy + 34, "shade")
        fill_rect(img, ox + 11, oy + 26, ox + 14, oy + 32, "shade")
        fill_rect(img, ox + 4, oy + 34, ox + 8, oy + 36, "ink")
        fill_rect(img, ox + 12, oy + 32, ox + 16, oy + 34, "ink")
    elif state == "run":
        fill_rect(img, ox + 5, oy + 26, ox + 8, oy + 32, "shade")
        fill_rect(img, ox + 11, oy + 26, ox + 14, oy + 34, "shade")
        fill_rect(img, ox + 4, oy + 32, ox + 8, oy + 34, "ink")
        fill_rect(img, ox + 12, oy + 34, ox + 16, oy + 36, "ink")
    else:
        fill_rect(img, ox + 5, oy + 26, ox + 8, oy + 34, "shade")
        fill_rect(img, ox + 11, oy + 26, ox + 14, oy + 34, "shade")
        fill_rect(img, ox + 4, oy + 34, ox + 8, oy + 36, "ink")
        fill_rect(img, ox + 11, oy + 34, ox + 15, oy + 36, "ink")

    # head / bell-helm (identity: small bell crest)
    fill_rect(img, ox + 6, oy + 6, ox + 13, oy + 14, "bone")
    fill_rect(img, ox + 7, oy + 8, ox + 12, oy + 12, "skin")
    fill_rect(img, ox + 7, oy + 8, ox + 12, oy + 9, "skin_shade")
    px(img, ox + 8, oy + 10, "ink")  # eye
    # helm crest bell
    fill_rect(img, ox + 8, oy + 2, ox + 11, oy + 5, "copper")
    px(img, ox + 9, oy + 1, "gold")
    px(img, ox + 10, oy + 5, "gold")

    # sword arm + blade
    ax = ox + 14 + arm
    ay = oy + 16
    fill_rect(img, ax, ay, ax + 3, ay + 6, "skin")
    bx = ax + 2 + blade
    by = ay - 1
    if state in ("windup", "parry"):
        fill_rect(img, bx - 1, by - 6, bx + 1, by + 2, "ash")
        fill_rect(img, bx, by - 8, bx, by + 1, "bone")
        px(img, bx, by + 2, "copper")
    else:
        fill_rect(img, bx, by - 1, bx + 10, by + 1, "bone")
        fill_rect(img, bx + 1, by, bx + 9, by, "cream")
        px(img, bx - 1, by, "copper")
        px(img, bx + 10, by, "spark")

    if flash:
        for dx, dy in ((-1, 0), (1, 0), (0, -1), (0, 1), (2, -1)):
            px(img, bx + 6 + dx, by + dy, "arcane_hi")

    # backpack lantern (readable silhouette cue)
    fill_rect(img, ox + 2, oy + 16, ox + 4, oy + 22, "wood")
    px(img, ox + 3, oy + 17, "gold")

    # ink outline accents
    for x, y in (
        (ox + 4, oy + 14),
        (ox + 15, oy + 14),
        (ox + 6, oy + 6),
        (ox + 13, oy + 6),
    ):
        px(img, x, y, "ink")

    return img


def draw_enemy(kind: str) -> Image.Image:
    img = new_canvas(32, 32)
    if kind == "sentry":
        fill_rect(img, 8, 10, 23, 28, "stone")
        fill_rect(img, 10, 12, 21, 20, "ash")
        fill_rect(img, 12, 14, 19, 18, "violet")
        px(img, 14, 16, "arcane_hi")
        px(img, 17, 16, "arcane_hi")
        fill_rect(img, 14, 4, 17, 10, "copper")
        outline_rect(img, 8, 10, 23, 28, "ink")
    elif kind == "wisp":
        fill_rect(img, 12, 10, 19, 20, "arcane")
        fill_rect(img, 13, 12, 18, 18, "arcane_hi")
        px(img, 14, 14, "ink")
        px(img, 17, 14, "ink")
        for x, y in ((10, 8), (21, 9), (11, 22), (20, 21), (15, 6)):
            px(img, x, y, "violet")
    else:  # elite
        fill_rect(img, 6, 8, 25, 28, "shade")
        fill_rect(img, 8, 10, 23, 24, "cloak")
        fill_rect(img, 10, 6, 21, 12, "bone")
        fill_rect(img, 12, 8, 19, 11, "blood")
        px(img, 14, 9, "spark")
        px(img, 17, 9, "spark")
        fill_rect(img, 22, 14, 28, 16, "gold")
        outline_rect(img, 6, 8, 25, 28, "ink")
    fill_rect(img, 10, 29, 21, 30, "shade")
    return img


def draw_slash(frame: int) -> Image.Image:
    img = new_canvas(48, 32)
    # crescent slash — shape > particle count
    arcs = [
        [(8, 16), (16, 8), (28, 6), (38, 12), (42, 20)],
        [(10, 18), (18, 10), (30, 8), (40, 14), (44, 22)],
        [(12, 20), (20, 14), (32, 12), (40, 18)],
    ]
    colors = ["arcane_hi", "arcane", "cloak_hi"]
    path = arcs[min(frame, 2)]
    col = colors[min(frame, 2)]
    for i, (x, y) in enumerate(path):
        fill_rect(img, x, y, x + 2, y + 2, col)
        if i:
            px(img, x - 1, y + 1, "spark" if frame == 0 else "bone")
    if frame == 0:
        fill_rect(img, 30, 10, 36, 14, "cream")
    return img


def draw_parry_spark(frame: int) -> Image.Image:
    img = new_canvas(24, 24)
    cx, cy = 12, 12
    rays = [
        [(0, -1), (0, -2), (0, -3), (1, -2)],
        [(1, 0), (2, 0), (3, 0), (2, 1)],
        [(0, 1), (0, 2), (0, 3), (-1, 2)],
        [(-1, 0), (-2, 0), (-3, 0), (-2, -1)],
        [(1, -1), (2, -2), (3, -3)],
        [(-1, 1), (-2, 2)],
    ]
    active = rays[: 2 + frame * 2]
    for ray in active:
        for i, (dx, dy) in enumerate(ray):
            key = "spark" if i == 0 else ("gold" if i == 1 else "copper")
            px(img, cx + dx, cy + dy, key)
    px(img, cx, cy, "cream")
    if frame >= 1:
        for dx, dy in ((-4, -3), (4, -2), (-3, 4), (5, 3)):
            px(img, cx + dx, cy + dy, "warn")
    return img


def draw_dash_ghost(frame: int) -> Image.Image:
    img = draw_hero("dash", 0)
    # fade body toward arcane afterimage
    out = new_canvas(40, 48)
    alpha = [140, 90, 50][min(frame, 2)]
    for y in range(img.height):
        for x in range(img.width):
            r, g, b, a = img.getpixel((x, y))
            if a:
                out.putpixel((x, y), (88, 196, 214, alpha))
    # motion streaks
    for i in range(3 - frame):
        fill_rect(out, 2 + i * 2, 18 + i, 6 + i * 2, 28 + i, "arcane")
    return out


def draw_hit_debris(frame: int) -> Image.Image:
    img = new_canvas(24, 24)
    bits = [
        (10, 10, "bone"),
        (14, 8, "ash"),
        (8, 14, "copper"),
        (16, 14, "gold"),
        (12, 16, "blood"),
        (6, 8, "stone"),
    ]
    spread = frame + 1
    for i, (x, y, c) in enumerate(bits):
        px(img, x + (i % 3) * spread - spread, y + (i % 2) * spread - 1, c)
        if frame > 0:
            px(img, x + spread, y - spread, "spark")
    return img


def draw_charge(frame: int) -> Image.Image:
    img = new_canvas(32, 32)
    radius = 3 + frame * 2
    cx, cy = 16, 16
    for y in range(32):
        for x in range(32):
            d = abs(x - cx) + abs(y - cy)  # diamond for pixel clarity
            if d == radius:
                px(img, x, y, "violet" if frame < 2 else "arcane")
            elif d == radius - 1 and frame >= 1:
                px(img, x, y, "arcane_hi")
    if frame >= 2:
        for a in range(-2, 3):
            px(img, cx + a, cy, "spark")
            px(img, cx, cy + a, "spark")
    return img


def draw_burst(frame: int) -> Image.Image:
    img = new_canvas(48, 48)
    cx, cy = 24, 24
    rings = [4, 8, 12, 16]
    r = rings[min(frame, 3)]
    for y in range(48):
        for x in range(48):
            d = max(abs(x - cx), abs(y - cy))
            if d == r:
                px(img, x, y, "gold" if frame < 2 else "ember")
            elif d == r - 1:
                px(img, x, y, "spark")
    if frame >= 2:
        for ang in range(0, 8):
            px(img, cx + (ang % 3) * 4 - 4, cy + (ang // 3) * 4 - 4, "warn")
    return img


def draw_warn_zone() -> Image.Image:
    """Telegraph — amber hatch, must stay distinct from real hitbox cyan."""
    img = new_canvas(64, 16)
    for x in range(64):
        for y in range(16):
            if (x + y) % 4 == 0:
                px(img, x, y, "warn")
            elif y in (0, 15) or x in (0, 63):
                px(img, x, y, "ember")
    return img


def draw_hitbox_zone() -> Image.Image:
    img = new_canvas(64, 16)
    outline_rect(img, 0, 0, 63, 15, "arcane")
    for x in range(2, 62, 4):
        px(img, x, 8, "arcane_hi")
    return img


def draw_hud_panel(kind: str) -> Image.Image:
    if kind == "hp_bar":
        img = new_canvas(96, 12)
        fill_rect(img, 0, 0, 95, 11, "ink")
        outline_rect(img, 0, 0, 95, 11, "bone")
        fill_rect(img, 2, 2, 70, 9, "blood")
        fill_rect(img, 2, 2, 70, 4, "hp_hi")
        fill_rect(img, 71, 2, 93, 9, "shade")
        return img
    if kind == "mp_bar":
        img = new_canvas(96, 10)
        fill_rect(img, 0, 0, 95, 9, "ink")
        outline_rect(img, 0, 0, 95, 9, "ash")
        fill_rect(img, 2, 2, 55, 7, "mp")
        fill_rect(img, 2, 2, 55, 3, "mp_hi")
        fill_rect(img, 56, 2, 93, 7, "shade")
        return img
    if kind == "boss_bar":
        img = new_canvas(200, 14)
        fill_rect(img, 0, 0, 199, 13, "ink")
        outline_rect(img, 0, 0, 199, 13, "gold")
        fill_rect(img, 3, 3, 150, 10, "violet")
        fill_rect(img, 3, 3, 150, 5, "arcane")
        fill_rect(img, 151, 3, 196, 10, "shade")
        # phase pips
        for i, x in enumerate((8, 20, 32)):
            fill_rect(img, x, 1, x + 6, 2, "gold" if i < 2 else "stone")
        return img
    if kind == "button":
        img = new_canvas(72, 20)
        fill_rect(img, 0, 0, 71, 19, "cloak")
        fill_rect(img, 2, 2, 69, 10, "cloak_hi")
        outline_rect(img, 0, 0, 71, 19, "bone")
        return img
    if kind == "button_focus":
        img = new_canvas(72, 20)
        fill_rect(img, 0, 0, 71, 19, "copper")
        fill_rect(img, 2, 2, 69, 10, "gold")
        outline_rect(img, 0, 0, 71, 19, "spark")
        return img
    if kind == "button_disabled":
        img = new_canvas(72, 20)
        fill_rect(img, 0, 0, 71, 19, "shade")
        outline_rect(img, 0, 0, 71, 19, "stone")
        return img
    # shard icon
    img = new_canvas(12, 12)
    fill_rect(img, 4, 1, 7, 10, "arcane")
    px(img, 5, 2, "arcane_hi")
    px(img, 3, 5, "arcane")
    px(img, 8, 5, "arcane")
    return img


def draw_tile(kind: str) -> Image.Image:
    img = new_canvas(16, 16)
    if kind == "floor":
        fill_rect(img, 0, 0, 15, 15, "stone")
        fill_rect(img, 0, 0, 15, 3, "ash")
        for x in (2, 7, 12):
            px(img, x, 6, "shade")
        outline_rect(img, 0, 0, 15, 15, "ink")
    elif kind == "brick":
        fill_rect(img, 0, 0, 15, 15, "wood")
        fill_rect(img, 1, 1, 14, 6, "wood_hi")
        fill_rect(img, 1, 9, 14, 14, "wood_hi")
        outline_rect(img, 0, 0, 15, 15, "ink")
    elif kind == "backdrop":
        fill_rect(img, 0, 0, 15, 15, "night")
        px(img, 3, 4, "fog")
        px(img, 10, 8, "fog")
        px(img, 7, 2, "gold")
    elif kind == "checkpoint":
        fill_rect(img, 6, 2, 9, 14, "bone")
        fill_rect(img, 4, 2, 11, 5, "gold")
        px(img, 8, 3, "spark")
        fill_rect(img, 5, 14, 10, 15, "stone")
    else:  # foliage foreground
        fill_rect(img, 6, 8, 9, 15, "wood")
        fill_rect(img, 2, 2, 13, 10, "moss")
        fill_rect(img, 4, 3, 11, 8, "leaf")
        px(img, 7, 4, "safe")
    return img


def save(img: Image.Image, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    img.save(path)


def checkerboard(size: tuple[int, int], tile: int = 8) -> Image.Image:
    image = Image.new("RGBA", size, (80, 80, 90, 255))
    draw = ImageDraw.Draw(image)
    for y in range(0, size[1], tile):
        for x in range(0, size[0], tile):
            if (x // tile + y // tile) % 2:
                draw.rectangle((x, y, x + tile - 1, y + tile - 1), fill=(100, 100, 112, 255))
    return image


def contact_sheet(images: list[tuple[str, Image.Image]], out: Path, cell: int = 128, cols: int = 5) -> None:
    pad = 8
    label_h = 16
    rows = (len(images) + cols - 1) // cols
    sheet = Image.new("RGBA", (cols * (cell + pad * 2), rows * (cell + label_h + pad * 2)), (24, 22, 32, 255))
    draw = ImageDraw.Draw(sheet)
    font = ImageFont.load_default()
    for i, (name, img) in enumerate(images):
        c, r = i % cols, i // cols
        left = c * (cell + pad * 2) + pad
        top = r * (cell + label_h + pad * 2) + pad
        bg = checkerboard((cell, cell))
        scale = max(1, cell // max(img.width, img.height))
        scaled = img.resize((img.width * scale, img.height * scale), Image.Resampling.NEAREST)
        x = (cell - scaled.width) // 2
        y = (cell - scaled.height) // 2
        bg.alpha_composite(scaled, (x, y))
        sheet.alpha_composite(bg, (left, top))
        draw.text((left, top + cell + 2), name[:22], fill=(240, 230, 210, 255), font=font)
    save(sheet, out)


def build_palette_strip() -> Image.Image:
    keys = [k for k in PALETTE if k != "void"]
    img = new_canvas(len(keys) * 12, 24)
    for i, key in enumerate(keys):
        fill_rect(img, i * 12, 0, i * 12 + 11, 23, key)
    return img


def main() -> None:
    for d in (ART, VFX, UI, PREVIEWS, DOCS):
        d.mkdir(parents=True, exist_ok=True)

    hero_states = [
        ("idle", 0),
        ("idle", 1),
        ("run", 0),
        ("run", 1),
        ("windup", 0),
        ("attack", 0),
        ("recover", 0),
        ("hurt", 0),
        ("death", 0),
        ("dash", 0),
        ("parry", 0),
        ("jump", 0),
    ]
    hero_imgs: list[tuple[str, Image.Image]] = []
    for state, frame in hero_states:
        img = draw_hero(state, frame)
        name = f"hero_{state}_{frame}"
        save(img, ART / "characters" / "hero" / f"{name}.png")
        hero_imgs.append((name, img))

    # horizontal strip for engine import
    strip = new_canvas(40 * len(hero_states), 48)
    for i, (_, img) in enumerate(hero_imgs):
        strip.alpha_composite(img, (i * 40, 0))
    save(strip, ART / "characters" / "hero" / "hero_strip.png")

    enemy_imgs = []
    for kind in ("sentry", "wisp", "elite"):
        img = draw_enemy(kind)
        save(img, ART / "characters" / "enemies" / f"enemy_{kind}.png")
        enemy_imgs.append((kind, img))

    vfx_imgs = []
    for i in range(3):
        img = draw_slash(i)
        save(img, VFX / "slash" / f"slash_{i}.png")
        vfx_imgs.append((f"slash_{i}", img))
    for i in range(3):
        img = draw_parry_spark(i)
        save(img, VFX / "parry" / f"parry_{i}.png")
        vfx_imgs.append((f"parry_{i}", img))
    for i in range(3):
        img = draw_dash_ghost(i)
        save(img, VFX / "dash" / f"dash_ghost_{i}.png")
        vfx_imgs.append((f"dash_{i}", img))
    for i in range(3):
        img = draw_hit_debris(i)
        save(img, VFX / "hit" / f"debris_{i}.png")
        vfx_imgs.append((f"debris_{i}", img))
    for i in range(3):
        img = draw_charge(i)
        save(img, VFX / "charge" / f"charge_{i}.png")
        vfx_imgs.append((f"charge_{i}", img))
    for i in range(4):
        img = draw_burst(i)
        save(img, VFX / "burst" / f"burst_{i}.png")
        vfx_imgs.append((f"burst_{i}", img))

    save(draw_warn_zone(), VFX / "zones" / "telegraph_warn.png")
    save(draw_hitbox_zone(), VFX / "zones" / "damage_arcane.png")
    vfx_imgs.append(("warn", draw_warn_zone()))
    vfx_imgs.append(("damage", draw_hitbox_zone()))

    for kind in ("hp_bar", "mp_bar", "boss_bar", "button", "button_focus", "button_disabled", "shard"):
        save(draw_hud_panel(kind), UI / "chrome" / f"{kind}.png")

    for kind in ("floor", "brick", "backdrop", "checkpoint", "foliage"):
        save(draw_tile(kind), ART / "environment" / f"tile_{kind}.png")

    # mini environment strip proving layers (far / mid / near)
    env = new_canvas(160, 72)
    for x in range(0, 160, 16):
        env.alpha_composite(draw_tile("backdrop"), (x, 0))
        env.alpha_composite(draw_tile("backdrop"), (x, 16))
    for x in range(0, 160, 16):
        env.alpha_composite(draw_tile("brick"), (x, 32))
    for x in range(0, 160, 16):
        env.alpha_composite(draw_tile("floor"), (x, 48))
    env.alpha_composite(draw_tile("checkpoint"), (72, 36))
    env.alpha_composite(draw_tile("foliage"), (16, 40))
    env.alpha_composite(draw_tile("foliage"), (128, 40))
    env.alpha_composite(draw_hero("idle", 0), (40, 16))
    save(env, ART / "environment" / "layer_demo.png")

    save(build_palette_strip(), PREVIEWS / "palette.png")
    contact_sheet(hero_imgs, PREVIEWS / "hero_contact_sheet.png", cell=120, cols=6)
    contact_sheet(vfx_imgs, PREVIEWS / "vfx_contact_sheet.png", cell=96, cols=6)
    contact_sheet(enemy_imgs + [("layer", env)], PREVIEWS / "world_contact_sheet.png", cell=160, cols=2)

    # HUD mock composition (raster preview; live UI is Godot Controls)
    hud = Image.new("RGBA", (320, 180), PALETTE["night"])
    hud.alpha_composite(draw_hud_panel("hp_bar"), (12, 12))
    hud.alpha_composite(draw_hud_panel("mp_bar"), (12, 28))
    hud.alpha_composite(draw_hud_panel("boss_bar"), (60, 8))
    hud.alpha_composite(draw_hud_panel("shard"), (12, 44))
    hud.alpha_composite(draw_hud_panel("button"), (20, 140))
    hud.alpha_composite(draw_hud_panel("button_focus"), (100, 140))
    hud.alpha_composite(draw_hud_panel("button_disabled"), (180, 140))
    hud.alpha_composite(draw_hero("parry", 0), (140, 70))
    hud.alpha_composite(draw_slash(0), (170, 78))
    hud.alpha_composite(draw_parry_spark(1), (200, 70))
    # section chip
    fill_rect(hud, 250, 40, 310, 54, "shade")
    outline_rect(hud, 250, 40, 310, 54, "arcane")
    save(hud, PREVIEWS / "hud_mock.png")

    print(f"Wrote art pack under {ROOT}")


if __name__ == "__main__":
    main()

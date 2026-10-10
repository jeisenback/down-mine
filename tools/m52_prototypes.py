"""M52 prototypes: candidate art for the old mine's tiles, drawn from the
pack's palette, rendered next to today's code-drawn tiles and on a mock
scene. Nothing in the game reads these; they are for choosing a direction.
    python3 tools/m52_prototypes.py
writes docs/m52-prototypes/*.png.
"""
import os
from PIL import Image, ImageDraw

T = 16
OUT = "docs/m52-prototypes"

# Pack palette (tools/make_props.py).
D = (50, 44, 30, 255)      # dark wood / outline
B0 = (96, 86, 60, 255)     # wood
B1 = (136, 122, 82, 255)   # light wood
W = (168, 150, 99, 255)    # wood highlight
G = (128, 128, 120, 255)   # metal
GH = (178, 177, 175, 255)  # metal highlight
S = (74, 77, 77, 255)      # dark metal
A = (43, 38, 26, 255)      # ash
CODE_TIMBER = (115, 77, 38, 255)  # today's code-drawn timber (0.45, 0.3, 0.15)
VOID = (10, 9, 12, 255)    # dark open cave behind everything
BG_SHEET = (27, 25, 25)

TILES = Image.open("assets/deep_night/tiles.png").convert("RGBA")
PROPS = Image.open("assets/custom/props.png").convert("RGBA")


def lerp(c0, c1, t):
    return tuple(int(round(a + (b - a) * t)) for a, b in zip(c0[:3], c1[:3])) + (255,)


def rock(region, color):
    """The mine's own layer tile: pack texture tinted toward the layer colour."""
    x0, y0 = region
    img = Image.new("RGBA", (T, T))
    for x in range(T):
        for y in range(T):
            p = TILES.getpixel((x0 + x, y0 + y))
            if p[:3] == BG_SHEET:
                img.putpixel((x, y), color)
            else:
                img.putpixel((x, y), lerp(p, color, 0.35))
    return img


CLAY = rock((0, 64), (127, 77, 56, 255))      # SPECKLE_GREEN tinted Clay
STONE = rock((104, 64), (115, 115, 122, 255))  # SPECKLE_BLUE tinted Stone


def blank():
    return Image.new("RGBA", (T, T), (0, 0, 0, 0))


def rect(img, x0, y0, x1, y1, c):
    for x in range(x0, x1 + 1):
        for y in range(y0, y1 + 1):
            if 0 <= x < T and 0 <= y < T:
                img.putpixel((x, y), c)


def line(img, x0, y0, x1, y1, c, thick=1):
    n = max(abs(x1 - x0), abs(y1 - y0), 1)
    for i in range(n + 1):
        x = round(x0 + (x1 - x0) * i / n)
        y = round(y0 + (y1 - y0) * i / n)
        for dx in range(thick):
            for dy in range(thick):
                if 0 <= x + dx < T and 0 <= y + dy < T:
                    img.putpixel((x + dx, y + dy), c)


# --- variant A: today's code-drawn tiles --------------------------------

def a_frame():
    img = blank()
    for x in range(T):
        for y in range(T):
            if x < 2 or x >= T - 2 or 7 <= y < 9:
                img.putpixel((x, y), CODE_TIMBER)
    return img


def a_post():
    img = blank()
    for x in range(T):
        for y in range(T):
            if 7 <= x < 9 or y < 3:
                img.putpixel((x, y), CODE_TIMBER)
    return img


def a_plank():
    img = STONE.copy()
    for x in range(T):
        for y in range(T):
            if 1 <= y < 4 or 6 <= y < 9 or 11 <= y < 14:
                img.putpixel((x, y), CODE_TIMBER)
    return img


def a_debris():
    img = STONE.copy()
    for x in range(T):
        for y in range(T):
            if 3 <= y < 5 or 11 <= y < 13 or 7 <= x < 9:
                img.putpixel((x, y), CODE_TIMBER)
    return img


# --- variant B: pack timber, shaded, outlined -----------------------------

def beam_h(img, y, x0=0, x1=T - 1):
    """A horizontal 4px beam: outline, highlight, body, shadow."""
    rect(img, x0, y, x1, y, D)
    rect(img, x0, y + 1, x1, y + 1, W)
    rect(img, x0, y + 2, x1, y + 2, B1)
    rect(img, x0, y + 3, x1, y + 3, D)


def beam_v(img, x, y0=0, y1=T - 1):
    """A vertical 4px post: outline, highlight, body, outline."""
    rect(img, x, y0, x, y1, D)
    rect(img, x + 1, y0, x + 1, y1, W)
    rect(img, x + 2, y0, x + 2, y1, B1)
    rect(img, x + 3, y0, x + 3, y1, D)


def b_frame():
    img = blank()
    beam_v(img, 0)
    beam_v(img, T - 4)
    rect(img, 4, 6, T - 5, 6, D)
    rect(img, 4, 7, T - 5, 7, B1)
    rect(img, 4, 8, T - 5, 8, B0)
    rect(img, 4, 9, T - 5, 9, D)
    return img


def b_post():
    img = blank()
    beam_v(img, 6)
    beam_h(img, 0, 0, T - 1)
    line(img, 5, 4, 2, 7, D)       # corbel braces under the cap
    line(img, 10, 4, 13, 7, D)
    line(img, 5, 5, 3, 7, B0)
    line(img, 10, 5, 12, 7, B0)
    return img


def b_plank():
    img = blank()
    for i, y in enumerate((0, 5, 10)):
        rect(img, 0, y, T - 1, y + 3, B1)
        rect(img, 0, y, T - 1, y, W)
        rect(img, 0, y + 3, T - 1, y + 3, B0)
        rect(img, 0, y + 4, T - 1, y + 4, D)
        gap = (5, 11, 3)[i]
        rect(img, gap, y, gap, y + 3, D)
        img.putpixel(((gap + 3) % T, y + 1), D)   # nail
        img.putpixel(((gap + 9) % T, y + 1), D)
    rect(img, 0, 15, T - 1, 15, D)
    return img


def b_debris():
    img = STONE.copy()
    rect(img, 0, 13, T - 1, 15, lerp(STONE.getpixel((3, 3)), (0, 0, 0, 255), 0.35))  # rubble shadow
    line(img, 0, 3, 15, 10, D, 4)
    line(img, 0, 3, 15, 10, B1, 2)
    line(img, 0, 2, 15, 9, W, 1)
    line(img, 1, 12, 15, 5, D, 3)
    line(img, 1, 12, 15, 5, B0, 1)
    for x, y in ((2, 7), (12, 14), (8, 13), (5, 1), (13, 1)):
        img.putpixel((x, y), lerp(STONE.getpixel((x, y)), (255, 255, 255, 255), 0.25))
    return img


# --- variant C: heavy rustic, iron-banded, braced --------------------------

def c_frame():
    img = blank()
    for x0 in (0, T - 5):
        rect(img, x0, 0, x0 + 4, T - 1, D)
        rect(img, x0 + 1, 0, x0 + 3, T - 1, B0)
        rect(img, x0 + 1, 0, x0 + 1, T - 1, B1)
        for y in (3, 8, 13):
            img.putpixel((x0 + 2, y), D)   # grain knots
    line(img, 5, 1, 10, 14, D, 2)   # X brace across the middle
    line(img, 10, 1, 5, 14, D, 2)
    line(img, 5, 1, 10, 14, B0, 1)
    line(img, 10, 1, 5, 14, B0, 1)
    return img


def c_post():
    img = blank()
    rect(img, 5, 0, 10, T - 1, D)
    rect(img, 6, 0, 9, T - 1, B0)
    rect(img, 6, 0, 6, T - 1, B1)
    rect(img, 0, 0, T - 1, 3, D)
    rect(img, 0, 1, T - 1, 2, B0)
    rect(img, 0, 1, T - 1, 1, B1)
    rect(img, 4, 7, 11, 8, S)      # iron strap
    rect(img, 4, 7, 11, 7, GH)
    img.putpixel((5, 8), D)
    img.putpixel((10, 8), D)
    return img


def c_plank():
    img = blank()
    rect(img, 0, 0, T - 1, T - 1, A)  # dark underside shows through the gaps
    for y in (0, 5, 10):
        rect(img, 0, y, T - 1, y + 3, B0)
        rect(img, 0, y, T - 1, y, B1)
        rect(img, 0, y + 3, T - 1, y + 3, D)
        for x in range(2 + y % 3, T - 1, 6):
            img.putpixel((x, y + 1), B1)
            img.putpixel((x + 1, y + 2), D)
    rect(img, 7, 0, 7, 3, D)
    rect(img, 2, 5, 2, 8, D)
    rect(img, 12, 10, 12, 13, D)
    return img


def c_debris():
    img = STONE.copy()
    dark = lerp(STONE.getpixel((3, 3)), (0, 0, 0, 255), 0.45)
    light = lerp(STONE.getpixel((3, 3)), (255, 255, 255, 255), 0.22)
    for cx, cy, r in ((3, 11, 3), (9, 13, 2), (13, 10, 2), (6, 7, 2)):  # tumbled stones
        for x in range(cx - r, cx + r + 1):
            for y in range(cy - r, cy + r + 1):
                if (x - cx) ** 2 + (y - cy) ** 2 <= r * r and 0 <= x < T and 0 <= y < T:
                    img.putpixel((x, y), dark if (x + y) % 2 else STONE.getpixel((x, y)))
        if 0 <= cx - 1 < T and 0 <= cy - r < T:
            img.putpixel((cx - 1, cy - r), light)
    line(img, 0, 1, 11, 9, D, 3)
    line(img, 0, 1, 11, 9, B0, 1)
    line(img, 15, 2, 4, 12, D, 3)
    line(img, 15, 2, 4, 12, B1, 1)
    rect(img, 10, 8, 12, 9, D)
    img.putpixel((11, 8), W)    # splintered end
    return img


VARIANTS = [
    ("A  today (code-drawn)", a_frame, a_post, a_plank, a_debris),
    ("B  pack timber, shaded", b_frame, b_post, b_plank, b_debris),
    ("C  heavy rustic, braced", c_frame, c_post, c_plank, c_debris),
]


# --- sheets ----------------------------------------------------------------

def zoom(img, k):
    return img.resize((img.width * k, img.height * k), Image.NEAREST)


def on_cell(tile, base):
    """A tile as the game shows it: decor over the dark open cell, solid as is."""
    cell = base.copy()
    cell.alpha_composite(tile)
    return cell


def tiles_sheet():
    k = 10
    pad = 12
    label_w = 190
    names = ["shaft frame", "gallery post", "plank floor", "collapse debris"]
    w = label_w + len(names) * (T * k + pad) + pad
    h = 28 + len(VARIANTS) * (T * k + pad) + pad
    sheet = Image.new("RGBA", (w, h), (32, 30, 34, 255))
    d = ImageDraw.Draw(sheet)
    for i, n in enumerate(names):
        d.text((label_w + i * (T * k + pad) + pad, 8), n, fill=(220, 220, 220, 255))
    void = Image.new("RGBA", (T, T), VOID)
    for r, (label, *fns) in enumerate(VARIANTS):
        y = 28 + r * (T * k + pad) + pad
        d.text((10, y + T * k // 2 - 6), label, fill=(240, 240, 240, 255))
        for i, fn in enumerate(fns):
            tile = fn()
            shown = on_cell(tile, void) if i < 2 else tile
            sheet.alpha_composite(zoom(shown, k), (label_w + i * (T * k + pad) + pad, y))
    return sheet


def crop(img, box):
    return img.crop(box)


def scene(frame, post, plank, debris):
    cols, rows = 22, 10
    img = Image.new("RGBA", (cols * T, rows * T), VOID)

    def put(tile, c, r, base=None):
        cell = tile if base is None else on_cell(tile, base)
        img.alpha_composite(cell, (c * T, r * T))

    void = Image.new("RGBA", (T, T), VOID)
    for c in range(cols):
        for r in range(rows):
            put(CLAY, c, r)
    # The shaft: cols 2-4 open, frame on the edge columns, old ladder in the middle.
    for r in range(rows):
        for c in (2, 3, 4):
            put(void, c, r)
        put(frame, 2, r, void)
        put(frame, 4, r, void)
    ladder = PROPS.crop((24, 0, 35, 64))
    img.alpha_composite(ladder, (3 * T + 2, 0 * T))
    img.alpha_composite(ladder.crop((0, 0, 11, 32)), (3 * T + 2, 7 * T))   # a piece missing between
    # The lift cage in the shaft's right edge column, on a plank floor.
    put(plank, 4, 9)
    rails = PROPS.crop((62, 0, 81, 64))
    img.alpha_composite(rails.crop((0, 8, 19, 64)), (4 * T - 1, 9 * T - 56 + 8 - 4))
    img.alpha_composite(PROPS.crop((82, 0, 97, 16)), (4 * T - 1 + 1, 9 * T - 16))
    # A gallery off the shaft: two open rows, floor row, caves under part of it.
    for c in range(5, cols):
        for r in (3, 4):
            put(void, c, r)
        put(STONE if False else CLAY, c, 5)
    for c in range(9, 13):         # a cave under the floor: planks span it
        for r in (6, 7):
            put(void, c, r)
        put(plank, c, 5)
    put(plank, 4, 5, None)         # landing at the shaft's edge
    for c in (10, 16):             # posts every six tiles
        for r in (3, 4):
            put(post, c, r, void)
    for c in (13, 14):             # a collapsed section, two rows
        for r in (3, 4):
            put(debris, c, r)
    tent = PROPS.crop((0, 66, 19, 80))
    img.alpha_composite(tent, (20 * T - 4, 5 * T - 14))   # the camp at the far end
    return img


def main():
    os.makedirs(OUT, exist_ok=True)
    tiles_sheet().save(f"{OUT}/tiles_compare.png")
    for (label, *fns), name in zip(VARIANTS, ("A_today", "B_pack_timber", "C_heavy_rustic")):
        sc = scene(*[fn() for fn in fns])
        sc = zoom(sc, 3)
        banner = Image.new("RGBA", (sc.width, 22), (32, 30, 34, 255))
        ImageDraw.Draw(banner).text((8, 5), label, fill=(240, 240, 240, 255))
        full = Image.new("RGBA", (sc.width, sc.height + 22))
        full.alpha_composite(banner, (0, 0))
        full.alpha_composite(sc, (0, 22))
        full.save(f"{OUT}/scene_{name}.png")
    print("wrote", OUT)


main()

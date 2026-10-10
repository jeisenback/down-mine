"""Redraw prototypes, round 2: new shapes for the Stalker, Burrower and
Snuffer (hooded wraith, armoured centipede-worm, light-eating jellyfish),
not recolours. Each shape is built from primitives (ellipses, polygons,
lines) into a mask, then shaded (light from the top left), outlined and
given its features. Rendered large and at game scale next to today's pack
art; nothing in the game reads these.
    python3 tools/redraw_shapes.py
writes docs/redraw/proto_shapes.png.
"""
from PIL import Image, ImageDraw

TILES = Image.open("assets/deep_night/tiles.png").convert("RGBA")
PLAYER = Image.open("assets/deep_night/player.png").convert("RGBA")
BG_SHEET = (27, 25, 25)

# k outline, a shadow, b body, c light, e eye, m bone / accent, g tendril
PAL = {
    "Stalker": dict(k=(12, 16, 24), a=(30, 44, 58), b=(52, 76, 96), c=(104, 140, 158), e=(245, 74, 56), m=(226, 230, 216), v=(6, 8, 12)),
    "Burrower": dict(k=(20, 12, 6), a=(66, 44, 20), b=(120, 82, 34), c=(188, 140, 68), e=(240, 70, 46), m=(228, 214, 178)),
    "Fuel": dict(k=(14, 22, 38), a=(40, 70, 120), b=(70, 130, 210), c=(150, 205, 250), w=(236, 246, 255), n=(110, 72, 36), N=(160, 112, 60)),
    "Ore": dict(k=(18, 14, 10), a=(48, 42, 36), b=(84, 76, 64), c=(132, 120, 100), y=(232, 192, 80), Y=(255, 238, 150)),
    "Snuffer": dict(k=(18, 34, 46), a=(46, 74, 92), b=(88, 134, 152), c=(190, 226, 236), e=(214, 66, 204), g=(76, 112, 128)),
}


def mask_canvas(w, h):
    m = Image.new("L", (w, h), 0)
    return m, ImageDraw.Draw(m)


def shade(mask, pal, keep=None):
    """RGBA from a mask: top edge light, bottom/right edge shadowed, the rest
    body colour, a 1px dark outline around it. `keep` maps (x, y) to a fixed
    colour (features that bypass shading)."""
    w, h = mask.size
    px = mask.load()

    def on(x, y):
        return 0 <= x < w and 0 <= y < h and px[x, y] > 0

    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    for x in range(w):
        for y in range(h):
            if on(x, y):
                if not on(x, y - 1) or (not on(x - 1, y) and (x + y) % 2 == 0):
                    c = pal["c"]
                elif not on(x, y + 1) or not on(x + 1, y):
                    c = pal["a"]
                else:
                    c = pal["b"]
                out.putpixel((x, y), c + (255,))
    for x in range(w):
        for y in range(h):
            if not on(x, y) and any(on(x + dx, y + dy) for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                out.putpixel((x, y), pal["k"] + (255,))
    for (x, y), c in (keep or {}).items():
        if 0 <= x < w and 0 <= y < h:
            out.putpixel((x, y), c + (255,))
    return out


# --- Stalker: a hooded wraith, 14x14 with its outline. -----------------------

def stalker(arm_l, arm_r, hem_phase, bob=0):
    pal = PAL["Stalker"]
    m, d = mask_canvas(14, 14)
    d.ellipse((4, 1 + bob, 9, 6 + bob), fill=255)                       # the hood
    d.polygon([(3, 5 + bob), (10, 5 + bob), (12, 12), (1, 12)], fill=255)  # the cloak
    for x in range(1, 13):                                              # a tattered hem
        cut = (0, 2, 0, 1, 3, 0, 2, 1, 0, 3, 1, 0)[(x + hem_phase) % 12]
        for y in range(12 - cut + 1, 13):
            m.putpixel((x, y), 0)
    d.line([(3, 7 + bob)] + arm_l, fill=255)                            # long arms
    d.line([(10, 7 + bob)] + arm_r, fill=255)
    keep = {}
    for x in range(5, 9):                                               # the dark under the hood
        for y in range(3 + bob, 6 + bob):
            keep[(x, y)] = pal["v"]
    keep[(5, 4 + bob)] = pal["e"]
    keep[(8, 4 + bob)] = pal["e"]
    keep[(6, 5 + bob)] = pal["m"]                                       # bared teeth
    keep[(7, 5 + bob)] = pal["m"]
    for end in (arm_l[-1], arm_r[-1]):                                  # claws
        keep[end] = pal["m"]
    return shade(m, pal, keep)


STALKER = [
    stalker([(1, 11)], [(12, 11)], 0),
    stalker([(0, 10)], [(13, 9)], 4, bob=-1),
    stalker([(5, 10), (8, 11)], [(13, 4)], 8),     # lunging: one arm reaching high
]


# --- Burrower: an armoured, many-legged worm, 20x11, head to the right. ------

def burrower(pincer_open, leg_phase, ripple):
    pal = PAL["Burrower"]
    m, d = mask_canvas(25, 11)
    boxes = [(1, 4, 5, 8), (4, 3, 9, 8), (8, 2, 13, 8), (12, 2, 16, 8)]
    for i, (x0, y0, x1, y1) in enumerate(boxes):
        o = ripple if i % 2 else 0
        d.ellipse((x0, y0 + o, x1, y1 + o), fill=255)
    d.line([(5, 6), (14, 5)], fill=255)                                 # join the segments
    d.ellipse((15, 1, 21, 9), fill=255)                                 # a distinct, bigger head
    for x in (4, 7, 10, 13):                                            # legs
        if (x + leg_phase) % 2 == 0:
            d.line([(x, 8 + ripple), (x - 1, 10)], fill=255)
        else:
            d.line([(x, 8), (x + 1, 10)], fill=255)
    top = [(21, 1), (22, 1), (23, 2), (23, 3)] if pincer_open else [(21, 3), (22, 3), (23, 4)]
    bot = [(21, 9), (22, 9), (23, 8), (23, 7)] if pincer_open else [(21, 7), (22, 7), (23, 6)]
    for pt in top + bot:                                                # the mandibles
        m.putpixel(pt, 255)
    keep = {pt: pal["m"] for pt in top + bot}
    for x in (5, 9, 13, 15):                                            # ring grooves between segments
        for y in range(2, 9):
            if m.getpixel((x, y)) > 0 and (x, y) not in keep:
                keep[(x, y)] = pal["a"]
    for x in (17, 18, 19):                                              # the head plate catches the light
        keep[(x, 2)] = pal["c"]
        keep[(x, 3)] = pal["c"]
    keep[(18, 5)] = pal["e"]
    keep[(19, 5)] = pal["e"]
    return shade(m, pal, keep)


BURROWER = [burrower(True, 0, 0), burrower(False, 1, 1), burrower(True, 0, 1)]


# --- Snuffer: a light-eating jellyfish, 14x17. --------------------------------

def snuffer(wave, glow):
    pal = PAL["Snuffer"]
    m, d = mask_canvas(14, 17)
    d.ellipse((2, 2, 11, 9), fill=255)                                  # the bell
    for x in range(2, 12, 2):                                           # a scalloped skirt
        d.point((x, 10), fill=255)
    keep = {}
    for i, x in enumerate((3, 5, 8, 10)):                               # tendrils, swaying wide
        for y in range(11, 16):
            off = (0, 1, 0, -1)[(y + wave * 2 + i) % 4]
            keep[(x + off, y)] = pal["g"] if y < 14 else pal["a"]
    for x, y in ((4, 4), (8, 3), (9, 6), (4, 7)):                       # glowing flecks
        if glow:
            keep[(x, y)] = pal["c"]
    keep[(6, 5)] = pal["k"]                                             # a slit eye, ringed dark
    keep[(7, 5)] = pal["k"]
    keep[(6, 6)] = pal["e"]
    keep[(7, 6)] = pal["e"]
    return shade(m, pal, keep)


SNUFFER = [snuffer(0, True), snuffer(1, False), snuffer(2, True)]

# --- Fuel: a glass oil flask with glowing fuel, 11x14. --------------------------

def fuel(pulse):
    pal = PAL["Fuel"]
    m, d = mask_canvas(11, 14)
    d.ellipse((1, 6, 9, 12), fill=255)                                  # the flask's belly
    d.rectangle((3, 2, 6, 7), fill=255)                                 # its neck
    keep = {}
    for x in range(4, 6):                                               # the cork
        keep[(x, 0)] = pal["n"]
        keep[(x, 1)] = pal["N"]
    keep[(3, 1)] = pal["n"]
    keep[(6, 1)] = pal["n"]
    for y in range(8, 12):                                              # the fuel inside, glowing
        for x in range(2, 9):
            if m.getpixel((x, y)) > 0 and (x - 5) ** 2 / 14 + (y - 10) ** 2 / 5 <= 1:
                keep[(x, y)] = pal["b"]
    for x, y in ((3, 9), (4, 9), (3, 10)):
        keep[(x, y)] = pal["w"] if pulse else pal["c"]                  # the glint
    if pulse == 2:
        keep[(5, 4)] = pal["c"]                                         # a bubble rising
    return shade(m, pal, keep)


FUEL = [fuel(0), fuel(1), fuel(2)]


# --- Ore: a cluster of dark shards laced with gold, 11x10. -----------------------

def ore(glint):
    pal = PAL["Ore"]
    m, d = mask_canvas(13, 12)
    d.polygon([(1, 9), (1, 6), (2, 4), (4, 5), (4, 9)], fill=255)       # a short shard leaning left
    d.polygon([(5, 9), (5, 4), (6, 1), (8, 4), (8, 9)], fill=255)       # the tall centre shard
    d.polygon([(9, 9), (9, 6), (10, 4), (11, 6), (11, 9)], fill=255)    # a short shard on the right
    d.rectangle((1, 9, 11, 10), fill=255)                               # the rock slab they grow from
    keep = {}
    for x, y in ((6, 5), (7, 6), (6, 7), (2, 7), (10, 7), (3, 6), (8, 8)):   # gold veins
        if m.getpixel((x, y)) > 0:
            keep[(x, y)] = pal["y"]
    keep[(6, 3)] = pal["Y"]
    if glint:
        keep[(6, 2)] = pal["Y"]                                         # a glint on the tallest shard
        keep[(7, 3)] = pal["Y"]
    return shade(m, pal, keep)


ORE = [ore(False), ore(True), ore(False)]

SHAPES = {"Stalker": STALKER, "Burrower": BURROWER, "Snuffer": SNUFFER, "Fuel": FUEL, "Ore": ORE}
CURRENT = {"Stalker": ((112, 120), 3), "Burrower": ((184, 120), 3), "Snuffer": ((160, 64), 4), "Fuel": ((32, 136), 3), "Ore": ((64, 88), 1)}
BG = (32, 30, 34, 255)
CELL_BG = (60, 56, 62, 255)
CAVE = (20, 18, 24, 255)


def current_frame(name, i):
    (x0, y0), count = CURRENT[name]
    i = min(i, count - 1)
    if name == "Snuffer":
        box = (x0 + (i % 2) * 8, y0 + (i // 2) * 8, x0 + (i % 2) * 8 + 8, y0 + (i // 2) * 8 + 8)
    else:
        box = (x0 + i * 8, y0, x0 + i * 8 + 8, y0 + 8)
    im = TILES.crop(box)
    px = im.load()
    for x in range(8):
        for y in range(8):
            if px[x, y][:3] == BG_SHEET:
                px[x, y] = (0, 0, 0, 0)
    return im


def zoom(im, k):
    return im.resize((im.width * k, im.height * k), Image.NEAREST)


def main():
    k = 12
    pad = 10
    label_w = 90
    rows = list(SHAPES)
    cw, ch = 25 * k, 17 * k
    cell_w = 3 * (cw + pad) + pad
    w = label_w + 2 * cell_w
    scale_h = 16 * 4 + 40
    h = 34 + len(rows) * (ch + pad * 2) + scale_h + 30
    sheet = Image.new("RGBA", (w, h), BG)
    d = ImageDraw.Draw(sheet)
    d.text((label_w + pad, 8), "today (pack art, 8x8)", fill=(240, 240, 240, 255))
    d.text((label_w + cell_w + pad, 8), "new shapes", fill=(240, 240, 240, 255))
    for ri, name in enumerate(rows):
        y = 34 + ri * (ch + pad * 2)
        d.text((10, y + ch // 2 - 6), name, fill=(220, 220, 220, 255))
        for fi in range(3):
            for ci, im in enumerate((current_frame(name, fi), SHAPES[name][fi])):
                cell = Image.new("RGBA", (cw, ch), CELL_BG)
                cell.alpha_composite(zoom(im, k), ((cw - im.width * k) // 2, (ch - im.height * k) // 2))
                sheet.alpha_composite(cell, (label_w + ci * cell_w + pad + fi * (cw + pad), y))
    y0 = 34 + len(rows) * (ch + pad * 2) + 10
    d.text((10, y0), "actual game scale (x4), with the 16x16 player for size", fill=(190, 190, 190, 255))
    player = PLAYER.crop((0, 0, 16, 16))
    for ci in range(2):
        strip = Image.new("RGBA", (cell_w - pad, 16 * 4 + 12), CAVE)
        strip.alpha_composite(zoom(player, 4), (6, 6))
        for i, name in enumerate(rows):
            im = current_frame(name, 0) if ci == 0 else SHAPES[name][0]
            strip.alpha_composite(zoom(im, 4), (96 + i * 118, 6 + (16 * 4 - im.height * 4) // 2))
        sheet.alpha_composite(strip, (label_w + ci * cell_w + pad, y0 + 18))
    sheet.save("docs/redraw/proto_shapes.png")
    print("wrote docs/redraw/proto_shapes.png", sheet.size)


main()

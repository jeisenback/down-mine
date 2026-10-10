"""Redraw prototypes: creatures and pickups (Stalker, Burrower, Snuffer, fuel
star, ore chunk), darker and grittier, in two moods drawn from the same
8x8 frame grids: V1 cool and desaturated, V2 warm and ember-lit. Rendered
next to the pack's current art. Nothing in the game reads these.
    python3 tools/redraw_prototypes.py
writes docs/redraw/proto_creatures_pickups.png.
"""
from PIL import Image, ImageDraw

TILES = Image.open("assets/deep_night/tiles.png").convert("RGBA")
BG_SHEET = (27, 25, 25)

# name -> list of 8x8 frames ('.' transparent)
FRAMES = {
    "Fuel": [
        ["...kk...", "..kBBk..", ".kBwwBk.", "kBwwwbBk"[:8], ".kBwwbk.", "..kbbk..", "...kk...", "........"],
        ["...kk...", "..kBBk..", ".kBwwbk.", "kBwwwbbk"[:8], ".kBwwbk.", "..kbbk..", "...kk...", "........"],
        ["........", "........", "...kk...", "..kBwk..", "..kwBk..", "...kk...", "........", "........"],
    ],
    "Ore": [
        ["........", "..kkkk..", ".kRRrrk.", "kRyRrrRk", "kRRrrYrk", "krrrRrrk", ".krrrrk.", "..kkkk.."],
    ],
}

PALETTES = {
    "V1": {
        "Fuel": dict(k=(14, 26, 48), b=(58, 110, 200), B=(110, 170, 240), w=(226, 240, 255)),
        "Ore": dict(k=(22, 18, 12), r=(70, 62, 50), R=(104, 92, 72), y=(236, 200, 90), Y=(255, 236, 150)),
    },
    "V2": {
        "Fuel": dict(k=(40, 20, 8), b=(190, 100, 24), B=(240, 160, 50), w=(255, 238, 170)),
        "Ore": dict(k=(20, 16, 12), r=(58, 70, 62), R=(90, 112, 96), y=(220, 130, 70), Y=(250, 190, 120)),
    },
}

# Creatures keep the pack's silhouettes and frames: every colour is mapped to
# one of three tones (dark, mid, light), eyes get their own colour, the
# silhouette gets a dark outline where the frame has room, and undersides
# are shaded. (outline, [dark, mid, light], eye)
RESTYLE = {
    "V1": {
        "Stalker": ((18, 24, 32), [(44, 66, 84), (66, 96, 116), (126, 164, 180)], (235, 72, 60)),
        "Burrower": ((24, 16, 8), [(104, 70, 28), (170, 122, 48), (214, 170, 92)], (225, 60, 40)),
        "Snuffer": ((40, 60, 72), [(96, 130, 146), (176, 214, 224), (226, 246, 250)], (200, 60, 190)),
    },
    "V2": {
        "Stalker": ((20, 14, 12), [(52, 36, 34), (86, 60, 54), (150, 112, 96)], (255, 150, 50)),
        "Burrower": ((20, 18, 16), [(120, 108, 90), (190, 176, 150), (232, 224, 200)], (210, 40, 40)),
        "Snuffer": ((24, 44, 36), [(70, 110, 86), (150, 210, 170), (214, 246, 222)], (240, 120, 60)),
    },
}
CREATURES = ("Stalker", "Burrower", "Snuffer")
FRAME_COUNT = {"Stalker": 3, "Burrower": 3, "Snuffer": 4}


def is_eye(rgb):
    r, g, b = rgb[:3]
    return (r > 150 and g < 110 and b < 110) or (r > 150 and b > 150 and g < 100)


def restyle(name, variant):
    """The pack's frames for a creature, restyled: list of RGBA images."""
    outline, tones, eye = RESTYLE[variant][name]
    frames = [current_frame(name, i) for i in range(FRAME_COUNT[name])]
    colours = sorted({f.getpixel((x, y))[:3] for f in frames for x in range(8) for y in range(8)
                      if f.getpixel((x, y))[3] > 0 and not is_eye(f.getpixel((x, y)))},
                     key=lambda c: 0.3 * c[0] + 0.59 * c[1] + 0.11 * c[2])
    tone_of = {c: min(2, i * 3 // max(len(colours), 1)) for i, c in enumerate(colours)}
    out = []
    for f in frames:
        px = f.load()
        im = Image.new("RGBA", (8, 8), (0, 0, 0, 0))
        for x in range(8):
            for y in range(8):
                if px[x, y][3] == 0:
                    continue
                c = px[x, y][:3]
                if is_eye(c):
                    im.putpixel((x, y), eye + (255,))
                    continue
                t = tone_of[c]
                below = y + 1 >= 8 or px[x, y + 1][3] == 0
                if below and t > 0:
                    t -= 1                       # the underside sits in shadow
                im.putpixel((x, y), tones[t] + (255,))
        for x in range(8):
            for y in range(8):
                if px[x, y][3] == 0 and any(0 <= x + dx < 8 and 0 <= y + dy < 8 and px[x + dx, y + dy][3] > 0
                                            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                    im.putpixel((x, y), outline + (255,))
        out.append(im)
    return out


# the pack's current frames: name -> (x, y) of the strip, frames across, size
CURRENT = {
    "Stalker": ((112, 120), 3, 8),
    "Burrower": ((184, 120), 3, 8),
    "Snuffer": ((160, 64), 4, 8),   # a 2x2 sheet read left to right, top to bottom
    "Fuel": ((32, 136), 3, 8),
    "Ore": ((64, 88), 1, 8),
}

BG = (32, 30, 34, 255)
CELL_BG = (60, 56, 62, 255)
CAVE = (20, 18, 24, 255)


def current_frame(name, i):
    (x0, y0), _, s = CURRENT[name]
    if name == "Snuffer":
        box = (x0 + (i % 2) * s, y0 + (i // 2) * s, x0 + (i % 2) * s + s, y0 + (i // 2) * s + s)
    else:
        box = (x0 + i * s, y0, x0 + i * s + s, y0 + s)
    im = TILES.crop(box)
    px = im.load()
    for x in range(im.width):
        for y in range(im.height):
            if px[x, y][:3] == BG_SHEET:
                px[x, y] = (0, 0, 0, 0)
    return im


def drawn_frame(grid, palette):
    assert len(grid) == 8 and all(len(r) == 8 for r in grid), grid
    im = Image.new("RGBA", (8, 8), (0, 0, 0, 0))
    for y, row in enumerate(grid):
        for x, ch in enumerate(row):
            if ch != ".":
                im.putpixel((x, y), palette[ch] + (255,))
    return im


def zoom(im, k):
    return im.resize((im.width * k, im.height * k), Image.NEAREST)


def main():
    k = 12
    pad = 8
    label_w = 110
    names = list(CREATURES) + list(FRAMES)
    counts = {**FRAME_COUNT, **{n: len(f) for n, f in FRAMES.items()}}
    max_frames = max(counts.values())
    cols = [("today (pack)", None), ("V1  cool, desaturated", "V1"), ("V2  warm, ember-lit", "V2")]
    cell_w = max_frames * (8 * k + pad) + pad
    row_h = 8 * k + pad * 2
    w = label_w + len(cols) * cell_w
    h = 30 + len(names) * row_h + 8 * 3 * 4 + 40
    sheet = Image.new("RGBA", (w, h), BG)
    d = ImageDraw.Draw(sheet)
    for ci, (title, _) in enumerate(cols):
        d.text((label_w + ci * cell_w + pad, 8), title, fill=(240, 240, 240, 255))
    def frame_images(name, variant):
        if variant is None:
            return [current_frame(name, i) for i in range(counts[name])]
        if name in CREATURES:
            return restyle(name, variant)
        return [drawn_frame(g, PALETTES[variant][name]) for g in FRAMES[name]]

    for ri, name in enumerate(names):
        y = 30 + ri * row_h
        d.text((10, y + 8 * k // 2 - 6), name, fill=(220, 220, 220, 255))
        for ci, (_, variant) in enumerate(cols):
            for fi, im in enumerate(frame_images(name, variant)):
                cell = Image.new("RGBA", (8 * k, 8 * k), CELL_BG)
                cell.alpha_composite(zoom(im, k))
                sheet.alpha_composite(cell, (label_w + ci * cell_w + pad + fi * (8 * k + pad), y))
    # Actual in-game scale (x3) on a cave background, first frame of each.
    y0 = 30 + len(names) * row_h + 10
    d.text((10, y0 - 6), "game scale (x3), first frame of each", fill=(190, 190, 190, 255))
    for ci, (_, variant) in enumerate(cols):
        strip = Image.new("RGBA", (cell_w - pad, 8 * 3 + 8), CAVE)
        for si, name in enumerate(names):
            strip.alpha_composite(zoom(frame_images(name, variant)[0], 3), (6 + si * (8 * 3 + 14), 4))
        sheet.alpha_composite(strip, (label_w + ci * cell_w + pad, y0 + 10))
    sheet.save("docs/redraw/proto_creatures_pickups.png")
    print("wrote docs/redraw/proto_creatures_pickups.png", sheet.size)


main()

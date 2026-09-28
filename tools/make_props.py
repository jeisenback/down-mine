"""Draws the custom prop sprites (milestone 39) into assets/custom/props.png.

Every colour is taken from the Deep Night tileset so the props sit with
the pack's art. Sprites are text grids (one character per pixel, '.'
transparent) or small shape rules. Run from the repo root:
    python3 tools/make_props.py
then re-import in Godot. Sheet regions are listed in SPRITES and must
match the region_rect values in the scenes.
"""
from PIL import Image

PALETTE = {
    "d": (50, 44, 30),     # dark wood / outline
    "b": (96, 86, 60),     # wood
    "B": (136, 122, 82),   # light wood
    "W": (168, 150, 99),   # wood highlight
    "y": (237, 230, 200),  # pale glass
    "Y": (219, 214, 139),  # warm glass
    "o": (227, 192, 113),  # flame
    "f": (202, 90, 77),    # flame core
    "g": (128, 128, 120),  # metal
    "G": (178, 177, 175),  # metal highlight
    "s": (74, 77, 77),     # dark metal
    "r": (174, 53, 39),    # cloth dark
    "R": (202, 90, 77),    # cloth
    "P": (224, 101, 85),   # cloth highlight
    "O": (202, 164, 77),   # gold
    "n": (80, 148, 80),    # canvas green light
    "m": (51, 105, 61),    # canvas green
    "M": (26, 71, 39),     # canvas green dark
    "k": (14, 43, 17),     # green outline
    "e": (204, 209, 166),  # egg light
    "E": (186, 195, 129),  # egg
    "x": (106, 113, 64),   # egg spots, slime
    "a": (43, 38, 26),     # ash
    "A": (32, 31, 31),     # ash dark
    "h": (137, 194, 118, 110),  # gas light (translucent)
    "H": (105, 158, 88, 90),    # gas
}

LAMP = [
    "..ddd..",
    ".dBBBd.",
    "dBWWWBd",
    "dyyyyyd",
    "dyyoyyd",
    "dyofoyd",
    "dyofoyd",
    "dyyyyyd",
    "dBBBBBd",
    "..dbd..",
    "..dbd..",
    "..dbd..",
    "..dbd..",
    ".dbbbd.",
    "dbbbbbd",
]

def support():
    """15 wide x 17 tall: a cap beam on a post, with knee braces."""
    w, h = 15, 17
    grid = [["."] * w for _ in range(h)]
    grid[0] = list("d" * w)
    grid[1] = list("dWWWBBBWBBBBWWd")
    grid[2] = list("dbbbbbbbbbbbbbd")
    grid[3] = list("d" * w)
    for y in range(4, h):
        grid[y][5:10] = list("dBBbd")
    for i in range(4):  # braces from under the beam ends down to the post
        y = 4 + i
        grid[y][1 + i], grid[y][2 + i] = "d", "B"
        grid[y][13 - i], grid[y][12 - i] = "d", "b"
    grid[h - 1][4:11] = list("ddddddd")
    return ["".join(r) for r in grid]



def ladder(height=64):
    """11 wide: two rails, a rung every 8 px."""
    rows = []
    for y in range(height):
        rail = "dBb"
        if y % 8 == 2:
            mid = "WWWWW"
        elif y % 8 == 3:
            mid = "bbbbb"
        else:
            mid = "....."
        rows.append(rail + mid + rail)
    return rows


def flag():
    """14 wide x 34 tall: pole with a gold knob, a red pennant."""
    w, h = 14, 34
    grid = [["."] * w for _ in range(h)]
    for y in range(h):
        grid[y][0], grid[y][1], grid[y][2] = "s", "G", "g"
    grid[0][0:3] = ["O", "O", "O"]
    top, bottom, tip_x = 1, 19, 13  # pennant rows and tip column
    mid = (top + bottom) / 2
    for y in range(top, bottom):
        reach = int(3 + (tip_x - 3) * (1 - abs(y + 0.5 - mid) / (mid - top)))
        for x in range(3, max(4, reach)):
            edge = x == reach - 1 or y in (top, bottom - 1)
            shade = "r" if edge else ("P" if y < mid - 3 else "R")
            grid[y][x] = shade
    return ["".join(r) for r in grid]


def pad(rows, width):
    return [r.ljust(width, ".") for r in rows]


def blank(w, h):
    return [["."] * w for _ in range(h)]


def join(grid):
    return ["".join(r) for r in grid]


ANCHOR = [
    ".dgGgd.",
    "dg...gd",
    "dG...Gd",
    ".dgGgd.",
    "...s...",
    "...s...",
    "sgGGGgs",
    "sssssss",
]

BEACON = [
    "..ddd..",
    ".dOOOd.",
    "dyyyyyd",
    "dyoooyd",
    "dyofoyd",
    "dyyyyyd",
    ".dOOOd.",
]

BELL = [
    "...s...",
    "..dOd..",
    ".dOoOd.",
    ".dOoOd.",
    "dOOoOOd",
    "ddddddd",
    "...O...",
]

CRATE = [
    "ddddddd",
    "dWBBBbd",
    "dBWBbbd",
    "dBBWbbd",
    "dBbbWbd",
    "dbbbbWd",
    "ddddddd",
]

CAMPFIRE = pad([
    ".......o",
    "......oo",
    "......ofo",
    ".....oofo.o",
    "....oofffoo",
    "....offYffo",
    "...ooffYYffo",
    "...offfYYfffo",
    "....offffffo",
    ".dbBBbd..dbBBbd",
    "dbBWWBbddbBWWBbd",
    ".dbbbbbddbbbbbd",
], 16)

RELIC = [
    "....dOd....",
    "...dOoOd...",
    "...dOOOd...",
    "....dOd....",
    "..ddOOOdd..",
    "..dOoOOOd..",
    "..dOOoOOd..",
    "..dOOOoOd..",
    "...dOOOd...",
    "...dOdOd...",
    ".sgggggggs.",
    ".sGGgggggs.",
    "..sgggggs..",
    "..sgGgggs..",
    ".sgggggggs.",
    "sssssssssss",
]

SCRAP = [
    "......yyG.",
    "..yyyyyGGg",
    "yyyGyGGgg.",
    ".GGgg.....",
]


def tent(w, h, light, mid, dark, outline):
    """A-frame tent: lit left face, shaded right face, dark door flap."""
    grid = blank(w, h)
    apex = w // 2
    for y in range(h):
        half = round((y + 1) * (w / 2) / h)
        for x in range(apex - half, apex + half + 1):
            if not 0 <= x < w:
                continue
            edge = x in (apex - half, apex + half) or y == h - 1
            door = y > h // 2 and abs(x - apex) <= (y - h // 2) // 2
            grid[y][x] = outline if edge else ("d" if door else (light if x < apex else mid))
        if 0 <= apex < w and y > 0 and grid[y][apex] not in (outline, "d"):
            grid[y][apex] = dark
    return join(grid)


def lift_rails():
    """19 x 64: head beam and pulley, two metal rails, cable, braces."""
    w, h = 19, 64
    grid = blank(w, h)
    grid[0] = list("d" * w)
    grid[1] = list("dWWBBBBBBWBBBBBBWWd")
    grid[2] = list("d" * w)
    grid[3][7:12] = list("dgGgd")
    grid[4][7:12] = list("dG.Gd")
    grid[5][7:12] = list("dgGgd")
    for y in range(3, h):
        grid[y][0:3] = list("sGg")
        grid[y][16:19] = list("sgs")
    for y in range(6, 48):
        grid[y][9] = "g"
    for y in (20, 36):
        for x in range(3, 16):
            grid[y][x] = "s"
    return join(grid)


def lift_cage():
    rows = ["s" * 15, "sGgggggggggggGs"]
    rows += ["sg.s.s.s.s.s.gs"] * 12
    rows += ["sGgggggggggggGs", "s" * 15]
    return rows


def vault_door():
    """16 x 32 riveted plate with a gold band and lock."""
    w, h = 16, 32
    grid = blank(w, h)
    for y in range(h):
        for x in range(w):
            edge = x in (0, w - 1) or y in (0, h - 1)
            grid[y][x] = "s" if edge else ("G" if x == 1 else "g")
    for y in range(3, h - 2, 6):
        grid[y][2], grid[y][w - 3] = "G", "G"
    for y in range(14, 18):
        for x in range(1, w - 1):
            grid[y][x] = "O" if y in (14, 17) else "o"
    grid[15][7:9] = ["d", "d"]
    grid[16][7:9] = ["d", "d"]
    return join(grid)


def gallery_post():
    return ["dBb"] * 64


def gallery_beam():
    """88 x 7 beam sagging and cracked in the middle."""
    w, h = 88, 7
    grid = blank(w, h)
    for x in range(w):
        drop = 2 if 41 <= x <= 46 else (1 if 37 <= x <= 50 else 0)
        if x == 44:
            continue  # the crack
        column = ["d", "W", "B", "b", "b"]
        for i, ch in enumerate(column):
            grid[i + drop][x] = ch
    return join(grid)


def eggs():
    """29 x 12: three speckled eggs on slime."""
    w, h = 29, 12
    grid = blank(w, h)
    for cx, rx, ry in ((3.5, 3.5, 4.5), (14.5, 4.5, 6.0), (25.5, 3.5, 4.5)):
        cy = h - 1 - ry
        for y in range(h):
            for x in range(w):
                dx, dy = (x + 0.5 - cx) / rx, (y + 0.5 - cy) / ry
                if dx * dx + dy * dy <= 1.0:
                    edge = dx * dx + dy * dy > 0.7
                    lit = dx < 0 and dy < 0
                    grid[y][x] = "x" if edge else ("e" if lit else "E")
    for x, y in ((13, 3), (16, 6), (3, 6), (26, 5)):
        grid[y][x] = "x"
    for x in range(w):
        grid[h - 1][x] = "x" if grid[h - 1][x] == "." else grid[h - 1][x]
    return join(grid)


def scorch():
    w, h = 33, 5
    grid = blank(w, h)
    for y in range(h):
        half = [8, 13, 15, 16, 16][y]
        for x in range(16 - half, 16 + half + 1):
            grid[y][x] = "A" if (x + y) % 3 else "a"
    for x, y in ((9, 2), (20, 1), (25, 3), (14, 3)):
        grid[y][x] = "f"
    grid[2][20] = "o"
    return join(grid)


def gas_cloud():
    """64 x 64 translucent puffs with dithered edges."""
    import math
    w = h = 64
    grid = blank(w, h)
    puffs = [(32, 32, 16), (20, 26, 11), (44, 28, 12), (26, 42, 11), (40, 42, 12), (32, 18, 9)]
    for y in range(h):
        for x in range(w):
            for cx, cy, r in puffs:
                d = math.hypot(x + 0.5 - cx, y + 0.5 - cy)
                if d <= r:
                    if d > r - 2 and (x + y) % 2:
                        continue  # dithered rim
                    lit = (x - cx) + (y - cy) < -r * 0.4
                    grid[y][x] = "h" if lit else ("H" if grid[y][x] != "h" else "h")
                    break
    return join(grid)


# name -> (grid, x, y) position on the sheet
SPRITES = {
    "lamp": (LAMP, 0, 0),
    "support": (support(), 8, 0),
    "ladder": (ladder(), 24, 0),
    "flag": (flag(), 36, 0),
    "anchor": (ANCHOR, 52, 0),
    "beacon": (BEACON, 52, 10),
    "bell": (BELL, 52, 20),
    "lift_rails": (lift_rails(), 62, 0),
    "lift_cage": (lift_cage(), 82, 0),
    "vault_door": (vault_door(), 98, 0),
    "relic": (RELIC, 82, 18),
    "gallery_post": (gallery_post(), 116, 0),
    "tent": (tent(19, 14, "W", "B", "b", "d"), 0, 66),
    "crate": (CRATE, 20, 66),
    "outpost_tent": (tent(25, 19, "n", "m", "M", "k"), 28, 66),
    "campfire": (CAMPFIRE, 54, 66),
    "gallery_beam": (gallery_beam(), 0, 90),
    "eggs": (eggs(), 0, 100),
    "scorch": (scorch(), 30, 100),
    "scrap": (SCRAP, 64, 100),
    "gas_cloud": (gas_cloud(), 0, 120),
}


def main():
    sheet = Image.new("RGBA", (128, 192), (0, 0, 0, 0))
    for name, (grid, ox, oy) in SPRITES.items():
        width = len(grid[0])
        for y, row in enumerate(grid):
            assert len(row) == width, (name, y, len(row), width)
            for x, ch in enumerate(row):
                if ch != ".":
                    colour = PALETTE[ch]
                    sheet.putpixel((ox + x, oy + y), colour if len(colour) == 4 else colour + (255,))
        print(f"{name}: region Rect2({ox}, {oy}, {width}, {len(grid)})")
    sheet.save("assets/custom/props.png")


if __name__ == "__main__":
    main()

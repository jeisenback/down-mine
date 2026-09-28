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
    """11 wide: two rails, a rung every 16 px."""
    rows = []
    for y in range(height):
        rail = "dBb"
        if y % 16 == 6:
            mid = "WWWWW"
        elif y % 16 == 7:
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


# name -> (grid, x, y) position on the sheet
SPRITES = {
    "lamp": (LAMP, 0, 0),
    "support": (support(), 8, 0),
    "ladder": (ladder(), 24, 0),
    "flag": (flag(), 36, 0),
}


def main():
    sheet = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
    for name, (grid, ox, oy) in SPRITES.items():
        width = len(grid[0])
        for y, row in enumerate(grid):
            assert len(row) == width, (name, y)
            for x, ch in enumerate(row):
                if ch != ".":
                    sheet.putpixel((ox + x, oy + y), PALETTE[ch] + (255,))
        print(f"{name}: region Rect2({ox}, {oy}, {width}, {len(grid)})")
    sheet.save("assets/custom/props.png")


if __name__ == "__main__":
    main()

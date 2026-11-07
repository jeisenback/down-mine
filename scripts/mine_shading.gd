extends RefCounted
class_name MineShading

## Soft shading on the edges of rock that face open ground (M89): a faint highlight on a top edge, as
## if lit from the lantern's side, and shadow on undersides and the sides of a wall, so a tunnel reads
## as relief instead of flat tiles. One overlay tile per combination of exposed sides (16 masks, drawn
## once into a texture); MineGrid puts the right one on every rock cell that touches open ground and
## keeps them current as rock is dug or refilled. Purely cosmetic: the overlay has no collision and
## never changes what is lit.

const NORTH := 1
const EAST := 2
const SOUTH := 4
const WEST := 8
const MASKS := 16

## How far in from an edge the shading reaches, in pixels, and its strongest alpha there.
const TOP_REACH := 3
const TOP_ALPHA := 0.42
const BOTTOM_REACH := 5
const BOTTOM_ALPHA := 0.6
const SIDE_REACH := 3
const SIDE_ALPHA := 0.4
const HIGHLIGHT := Color(1.0, 0.93, 0.75)

static func mask(north_open: bool, east_open: bool, south_open: bool, west_open: bool) -> int:
	return (NORTH if north_open else 0) | (EAST if east_open else 0) | (SOUTH if south_open else 0) | (WEST if west_open else 0)

## The overlay's colour at pixel (x, y) of the tile for `sides`: transparent except along an exposed
## edge, where it fades in toward the edge. A highlight on the top, shadow elsewhere (the stronger
## wins at a corner).
static func shade_color(sides: int, x: int, y: int) -> Color:
	var size := MineGrid.TILE_SIZE
	var light := 0.0
	var dark := 0.0
	if sides & NORTH:
		light = _fade(y, TOP_REACH) * TOP_ALPHA
	if sides & SOUTH:
		dark = maxf(dark, _fade(size - 1 - y, BOTTOM_REACH) * BOTTOM_ALPHA)
	if sides & EAST:
		dark = maxf(dark, _fade(size - 1 - x, SIDE_REACH) * SIDE_ALPHA)
	if sides & WEST:
		dark = maxf(dark, _fade(x, SIDE_REACH) * SIDE_ALPHA)
	if light > dark:
		return Color(HIGHLIGHT.r, HIGHLIGHT.g, HIGHLIGHT.b, light)
	if dark > 0.0:
		return Color(0.0, 0.0, 0.02, dark)
	return Color(0, 0, 0, 0)

## 1 at the edge (distance 0) falling to 0 at `reach` pixels in.
static func _fade(distance: int, reach: int) -> float:
	return clampf(1.0 - float(distance) / float(reach), 0.0, 1.0)

## The atlas: one tile per mask, in mask order (tile 0 is empty).
static func build_image() -> Image:
	var size := MineGrid.TILE_SIZE
	var image := Image.create(size * MASKS, size, false, Image.FORMAT_RGBA8)
	for sides in range(MASKS):
		for x in range(size):
			for y in range(size):
				image.set_pixel(sides * size + x, y, shade_color(sides, x, y))
	return image

## The mask for cell (x, y) of a generated layout's kinds (column-major, GRID_HEIGHT per column):
## a side is exposed when the cell next to it is empty. Off the grid counts as rock.
static func layout_mask(kinds: PackedByteArray, x: int, y: int) -> int:
	var height := MineGrid.GRID_HEIGHT
	var width := MineGrid.GRID_WIDTH
	return mask(
		y > 0 and kinds[x * height + y - 1] == MineLayout.Kind.EMPTY,
		x < width - 1 and kinds[(x + 1) * height + y] == MineLayout.Kind.EMPTY,
		y < height - 1 and kinds[x * height + y + 1] == MineLayout.Kind.EMPTY,
		x > 0 and kinds[(x - 1) * height + y] == MineLayout.Kind.EMPTY)

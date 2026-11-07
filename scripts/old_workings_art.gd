extends RefCounted
class_name OldWorkingsArt

## Pixel art for the old workings' decor (M90), drawn in code like the shading overlay: the props
## sheet has no rails, rubble heaps or cobwebs. Each is one 16 by 16 tile for the decor layer.
## Rails and rubble sit low in the tile (the miner stands above them); a cobweb hangs in the top
## left corner.

const SIZE := 16
const STEEL := Color(0.62, 0.64, 0.7)
const STEEL_DARK := Color(0.36, 0.38, 0.44)
const RUST := Color(0.55, 0.34, 0.2)
const RUST_DARK := Color(0.36, 0.22, 0.14)
const WOOD := Color(0.42, 0.28, 0.16)
const WOOD_DARK := Color(0.27, 0.18, 0.1)
const STONE := Color(0.42, 0.38, 0.34)
const STONE_DARK := Color(0.28, 0.25, 0.22)
const STONE_LIGHT := Color(0.56, 0.51, 0.45)
const WEB := Color(0.88, 0.88, 0.92)

static func _blank() -> Image:
	var image := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	return image

## A length of track seen from the side: a rail on sleepers. A worn one is rusted, has a missing
## piece of rail and only one sleeper left.
static func rail(worn: bool) -> Image:
	var image := _blank()
	var top := RUST if worn else STEEL
	var bottom := RUST_DARK if worn else STEEL_DARK
	for x in range(SIZE):
		if worn and x >= 5 and x <= 8:
			continue # a broken piece
		image.set_pixel(x, 12, top)
		image.set_pixel(x, 13, bottom)
	var sleepers := [10] if worn else [2, 10]
	for x in sleepers:
		for dx in range(2):
			image.set_pixel(x + dx, 14, WOOD)
			image.set_pixel(x + dx, 15, WOOD_DARK)
	return image

## A heap of fallen stones on the floor.
static func rubble() -> Image:
	var image := _blank()
	var rows := {15: Vector2i(1, 14), 14: Vector2i(2, 13), 13: Vector2i(4, 11), 12: Vector2i(6, 9)}
	for y: int in rows:
		var span: Vector2i = rows[y]
		for x in range(span.x, span.y + 1):
			var pick: int = (x * 7 + y * 13) % 5 # a fixed speckle, so every heap is the same
			var colour := STONE
			if pick == 0 or y == 12:
				colour = STONE_LIGHT
			elif pick == 1:
				colour = STONE_DARK
			image.set_pixel(x, y, colour)
	return image

## A corner web: three one-pixel strands (along the top, the diagonal and down the side) joined by
## two loops, in the top left of the tile.
static func cobweb() -> Image:
	var image := _blank()
	var strand := Color(WEB.r, WEB.g, WEB.b, 0.55)
	var loop := Color(WEB.r, WEB.g, WEB.b, 0.34)
	for i in range(9):
		image.set_pixel(i, 0, strand) # along the top
		image.set_pixel(0, i, strand) # down the side
	for i in range(7):
		image.set_pixel(i, i, strand) # the diagonal
	for p in [Vector2i(4, 1), Vector2i(3, 2), Vector2i(2, 3), Vector2i(1, 4),
			Vector2i(7, 1), Vector2i(6, 2), Vector2i(6, 3), Vector2i(5, 4), Vector2i(4, 5), Vector2i(3, 6), Vector2i(2, 6), Vector2i(1, 7)]:
		image.set_pixel(p.x, p.y, loop)
	return image

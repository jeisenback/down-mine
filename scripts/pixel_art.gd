extends RefCounted
class_name PixelArt

## The Deep Night sheets ship fully opaque on a flat background colour.
## Keyed results are cached per source texture, since enemies spawn
## mid-run and re-keying a whole sheet each time would hitch.
const SHEET_BG_COLOR := Color8(27, 25, 25)

static var _keyed_cache: Dictionary = {}

static func keyed(texture: Texture2D) -> Texture2D:
	if _keyed_cache.has(texture):
		return _keyed_cache[texture]
	var image := texture.get_image()
	image.decompress()
	image.convert(Image.FORMAT_RGBA8)
	for x in range(image.get_width()):
		for y in range(image.get_height()):
			if image.get_pixel(x, y).is_equal_approx(SHEET_BG_COLOR):
				image.set_pixel(x, y, Color(0, 0, 0, 0))
	var result := ImageTexture.create_from_image(image)
	_keyed_cache[texture] = result
	return result

## The player sheet's shirt: main, shadow, and mid-shade reds. NPCs swap
## these for their own colour so each reads as a different person while
## skin, hair and boots stay natural.
const SHIRT_MAIN := Color8(198, 91, 79)
const SHIRT_SHADOW := Color8(174, 49, 35)
const SHIRT_MID := Color8(178, 84, 74)

static var _shirt_cache: Dictionary = {}

static func with_shirt(texture: Texture2D, shirt: Color) -> Texture2D:
	var key := [texture, shirt]
	if _shirt_cache.has(key):
		return _shirt_cache[key]
	var image := keyed(texture).get_image()
	var swaps := {
		SHIRT_MAIN: shirt,
		SHIRT_SHADOW: shirt.darkened(0.35),
		SHIRT_MID: shirt.darkened(0.15),
	}
	for x in range(image.get_width()):
		for y in range(image.get_height()):
			var pixel := image.get_pixel(x, y)
			for from in swaps:
				if pixel.is_equal_approx(from):
					image.set_pixel(x, y, swaps[from])
					break
	var result := ImageTexture.create_from_image(image)
	_shirt_cache[key] = result
	return result

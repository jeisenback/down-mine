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

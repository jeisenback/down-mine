extends RefCounted
class_name PixelArt

## The Deep Night sheets ship fully opaque on a flat background colour; the
## tileset builder keys it out (mine.gd). Creatures, pickups, the miner and
## every placed or event object are drawn in code now (art_sprite.gd).
const SHEET_BG_COLOR := Color8(27, 25, 25)

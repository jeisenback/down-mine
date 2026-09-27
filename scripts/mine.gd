extends TileMap
class_name MineGrid

signal tile_dug(noise_amount: float)

const TILE_SIZE := 16
const GRID_WIDTH := 40
const GRID_HEIGHT := 60
const SURFACE_ROWS := 4
const DIG_NOISE := 6.0

var source_id: int = 0

func _ready() -> void:
	_build_tileset()
	_generate_layout()

func _build_tileset() -> void:
	var image := Image.create(TILE_SIZE, TILE_SIZE, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.35, 0.3, 0.25))
	var texture := ImageTexture.create_from_image(image)

	var atlas := TileSetAtlasSource.new()
	atlas.texture = texture
	atlas.texture_region_size = Vector2i(TILE_SIZE, TILE_SIZE)
	atlas.create_tile(Vector2i(0, 0))

	var new_tileset := TileSet.new()
	new_tileset.tile_size = Vector2i(TILE_SIZE, TILE_SIZE)
	source_id = new_tileset.add_source(atlas)

	var physics_layer := 0
	new_tileset.add_physics_layer()
	var tile_data := atlas.get_tile_data(Vector2i(0, 0), 0)
	var polygon := PackedVector2Array([
		Vector2(-TILE_SIZE / 2.0, -TILE_SIZE / 2.0),
		Vector2(TILE_SIZE / 2.0, -TILE_SIZE / 2.0),
		Vector2(TILE_SIZE / 2.0, TILE_SIZE / 2.0),
		Vector2(-TILE_SIZE / 2.0, TILE_SIZE / 2.0),
	])
	tile_data.add_collision_polygon(physics_layer)
	tile_data.set_collision_polygon_points(physics_layer, 0, polygon)

	tile_set = new_tileset

func _generate_layout() -> void:
	for x in range(GRID_WIDTH):
		for y in range(GRID_HEIGHT):
			if y >= SURFACE_ROWS:
				set_cell(0, Vector2i(x, y), source_id, Vector2i(0, 0))

func is_solid(cell: Vector2i) -> bool:
	return get_cell_source_id(0, cell) != -1

func dig_at_world(world_pos: Vector2) -> bool:
	var cell := local_to_map(to_local(world_pos))
	if is_solid(cell):
		set_cell(0, cell, -1)
		tile_dug.emit(DIG_NOISE)
		return true
	return false

func world_to_cell(world_pos: Vector2) -> Vector2i:
	return local_to_map(to_local(world_pos))

func cell_to_world(cell: Vector2i) -> Vector2:
	return to_global(map_to_local(cell))

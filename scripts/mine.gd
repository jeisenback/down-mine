extends TileMap
class_name MineGrid

signal tile_dug(noise_amount: float)

const TILE_SIZE := 16
const GRID_WIDTH := 40
const GRID_HEIGHT := 60
const SURFACE_ROWS := 4
const DIG_NOISE := 6.0

# Depth bands: each gets its own tile look, per the PRD's "layers have
# their own hazards and look" pillar. Hazard variety comes later; for
# now this just makes depth legible at a glance.
const TOPSOIL_ROWS_END := 20
const STONE_ROWS_END := 40
const LAYER_ATLAS_COORDS := [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)]
const LAYER_COLORS := [
	Color(0.42, 0.32, 0.22), # topsoil
	Color(0.45, 0.45, 0.48), # stone
	Color(0.22, 0.16, 0.2),  # deep rock
]

# Cellular-automata cave carving: start from a random fill below the
# solid crust, then smooth a few times so pockets read as caves rather
# than noise. Standard 4/5-neighbor rule.
const INITIAL_FILL := 0.45
const CA_ITERATIONS := 5

const FUEL_DEPOSIT_COUNT := 8
const FuelPickupScene := preload("res://scenes/FuelPickup.tscn")

var source_id: int = 0

func _ready() -> void:
	_build_tileset()
	_generate_layout()

func _build_tileset() -> void:
	var atlas_width := LAYER_ATLAS_COORDS.size()
	var image := Image.create(TILE_SIZE * atlas_width, TILE_SIZE, false, Image.FORMAT_RGBA8)
	for i in range(atlas_width):
		image.fill_rect(Rect2i(i * TILE_SIZE, 0, TILE_SIZE, TILE_SIZE), LAYER_COLORS[i])
	var texture := ImageTexture.create_from_image(image)

	var atlas := TileSetAtlasSource.new()
	atlas.texture = texture
	atlas.texture_region_size = Vector2i(TILE_SIZE, TILE_SIZE)

	var new_tileset := TileSet.new()
	new_tileset.tile_size = Vector2i(TILE_SIZE, TILE_SIZE)
	var physics_layer := 0
	new_tileset.add_physics_layer()
	source_id = new_tileset.add_source(atlas)

	var polygon := PackedVector2Array([
		Vector2(-TILE_SIZE / 2.0, -TILE_SIZE / 2.0),
		Vector2(TILE_SIZE / 2.0, -TILE_SIZE / 2.0),
		Vector2(TILE_SIZE / 2.0, TILE_SIZE / 2.0),
		Vector2(-TILE_SIZE / 2.0, TILE_SIZE / 2.0),
	])
	for i in range(atlas_width):
		var atlas_coords := Vector2i(i, 0)
		atlas.create_tile(atlas_coords)
		var tile_data := atlas.get_tile_data(atlas_coords, 0)
		tile_data.add_collision_polygon(physics_layer)
		tile_data.set_collision_polygon_points(physics_layer, 0, polygon)

	tile_set = new_tileset

func _generate_layout() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()

	var solid := _make_grid(false)
	for x in range(GRID_WIDTH):
		for y in range(GRID_HEIGHT):
			if y < SURFACE_ROWS:
				solid[x][y] = false
			elif y == SURFACE_ROWS:
				solid[x][y] = true # a crust the player always has to dig through
			else:
				solid[x][y] = rng.randf() < INITIAL_FILL
	_reinforce_boundaries(solid)

	for i in range(CA_ITERATIONS):
		solid = _smooth(solid)
		_reinforce_boundaries(solid)
		for x in range(GRID_WIDTH):
			solid[x][SURFACE_ROWS] = true

	for x in range(GRID_WIDTH):
		for y in range(GRID_HEIGHT):
			if solid[x][y]:
				var layer_index := _layer_index_for_row(y)
				set_cell(0, Vector2i(x, y), source_id, LAYER_ATLAS_COORDS[layer_index])

	_scatter_fuel_deposits(solid, rng)

func _make_grid(default_value: bool) -> Array:
	var grid: Array = []
	grid.resize(GRID_WIDTH)
	for x in range(GRID_WIDTH):
		var column: Array = []
		column.resize(GRID_HEIGHT)
		column.fill(default_value)
		grid[x] = column
	return grid

func _reinforce_boundaries(grid: Array) -> void:
	for x in range(GRID_WIDTH):
		grid[x][GRID_HEIGHT - 1] = true
	for y in range(SURFACE_ROWS, GRID_HEIGHT):
		grid[0][y] = true
		grid[GRID_WIDTH - 1][y] = true

func _smooth(grid: Array) -> Array:
	var new_grid := _make_grid(false)
	for x in range(GRID_WIDTH):
		for y in range(GRID_HEIGHT):
			if y < SURFACE_ROWS:
				new_grid[x][y] = false
				continue
			var wall_count := _count_wall_neighbors(grid, x, y)
			if grid[x][y]:
				new_grid[x][y] = wall_count >= 4
			else:
				new_grid[x][y] = wall_count >= 5
	return new_grid

func _count_wall_neighbors(grid: Array, x: int, y: int) -> int:
	var count := 0
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			if dx == 0 and dy == 0:
				continue
			var nx := x + dx
			var ny := y + dy
			if nx < 0 or nx >= GRID_WIDTH or ny < 0 or ny >= GRID_HEIGHT:
				count += 1 # treat out-of-bounds as solid, keeps caves from opening at the edges
			elif grid[nx][ny]:
				count += 1
	return count

func _layer_index_for_row(y: int) -> int:
	if y < TOPSOIL_ROWS_END:
		return 0
	elif y < STONE_ROWS_END:
		return 1
	return 2

## Places fuel pickups on open cave floors (an open cell with solid rock
## directly beneath it), the PRD's "found fuel" reward for exploring caves
## instead of digging straight down.
func _scatter_fuel_deposits(solid: Array, rng: RandomNumberGenerator) -> void:
	var floor_cells: Array = []
	for x in range(1, GRID_WIDTH - 1):
		for y in range(SURFACE_ROWS + 1, GRID_HEIGHT - 1):
			if not solid[x][y] and solid[x][y + 1]:
				floor_cells.append(Vector2i(x, y))
	floor_cells.shuffle()
	var count: int = min(FUEL_DEPOSIT_COUNT, floor_cells.size())
	for i in range(count):
		var cell: Vector2i = floor_cells[i]
		var pickup := FuelPickupScene.instantiate()
		pickup.position = map_to_local(cell)
		add_child(pickup)

func is_solid(cell: Vector2i) -> bool:
	return get_cell_source_id(0, cell) != -1

func dig_at_world(world_pos: Vector2) -> bool:
	return dig_cells([world_to_cell(world_pos)]) > 0

## Digs every solid cell in the list, emitting noise scaled to how much
## was actually cleared. Used for multi-tile digs (a tall notch, a step)
## so a bigger dig costs more noise than a single tile.
func dig_cells(cells: Array) -> int:
	var dug_count := 0
	for cell in cells:
		if is_solid(cell):
			set_cell(0, cell, -1)
			dug_count += 1
	if dug_count > 0:
		tile_dug.emit(DIG_NOISE * dug_count)
	return dug_count

## All cells in one column between two world-space y bounds, inclusive.
func cells_in_column(world_x: float, y_top: float, y_bottom: float) -> Array:
	var top_cell := world_to_cell(Vector2(world_x, y_top))
	var bottom_cell := world_to_cell(Vector2(world_x, y_bottom))
	var cells: Array = []
	for y in range(top_cell.y, bottom_cell.y + 1):
		cells.append(Vector2i(top_cell.x, y))
	return cells

func world_to_cell(world_pos: Vector2) -> Vector2i:
	return local_to_map(to_local(world_pos))

func cell_to_world(cell: Vector2i) -> Vector2:
	return to_global(map_to_local(cell))

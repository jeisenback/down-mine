extends TileMap
class_name MineGrid

signal tile_dug(noise_amount: float)
## The player dug out a gas rock (milestone 29); Main releases a cloud.
signal gas_released(world_pos: Vector2)

const TILE_SIZE := 16
const GRID_WIDTH := 80
const GRID_HEIGHT := 300
const SURFACE_ROWS := 4
const DIG_NOISE := 6.0

# Depth bands: each gets its own tile look, per the PRD's "layers have
# their own hazards and look" pillar. Hazard variety comes later; for
# now this just makes depth legible at a glance. Fractions (must sum to
# ~1.0) instead of hardcoded rows, so bands scale with GRID_HEIGHT.
const LAYER_FRACTIONS := [0.2857, 0.3571, 0.3572]
const LAYER_ATLAS_COORDS := [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)]
const LAYER_COLORS := [
	Color(0.42, 0.32, 0.22), # topsoil
	Color(0.45, 0.45, 0.48), # stone
	Color(0.22, 0.16, 0.2),  # deep rock
]

# 16x16 fill regions in the Deep Night tileset (8x8 pack, so each layer
# tile is a 2x2 block of its art). The sheet's flat background colour also
# fills the gaps in these textures; those pixels get the layer colour
# above instead, so solid rock still reads apart from empty cave.
const TILESET_TEXTURE := preload("res://assets/deep_night/tiles.png")
const LAYER_TEXTURE_REGIONS := [
	Rect2i(0, 64, 16, 16),   # green speckle
	Rect2i(104, 64, 16, 16), # blue-grey speckle
	Rect2i(8, 120, 16, 16),  # grey stone block
]

# Bedrock: indestructible, forms the map's outer walls/floor so digging
# can never open a path out of the generated area.
const BEDROCK_ATLAS_COORDS := Vector2i(3, 0)
const BEDROCK_COLOR := Color(0.05, 0.05, 0.06)

# Mine decay (milestone 21, PRD: "tunnels collapse and floors crumble").
# Each tick, one tunnel cell the player dug refills with rock and one cave
# floor near the player drops away - but only in darkness, so every light
# (lantern, lamps, base, miners) protects the ground around it and nothing
# collapses on the player. Ticks speed up as the run goes on. Floors under
# pickups and NPCs never crumble, so nothing is left floating.
const DECAY_INTERVAL_START := 4.0
const DECAY_INTERVAL_END := 1.5
const DECAY_RAMP_TIME := 480.0 # seconds into the run to reach the end interval
const CRUMBLE_RADIUS_TILES := 20
const CRUMBLE_SAMPLE_TRIES := 20
const DECAY_NOISE := 3.0 # per collapse or crumble (PRD: collapses are loud)

# Reinforced rock around the run base (milestone 18): the tileset's iron
# grate (8x16, drawn twice across) over dark earth. Burrowers must chew
# through it; the player digs it like normal rock. Walls wear back to
# plain rock over time, faster when the base's light is low.
const WALL_ATLAS_COORDS := Vector2i(4, 0)
const WALL_COLOR := Color(0.2, 0.15, 0.1)

# Layer identity (milestone 29, PRD: layers have "their own hazards").
# Stone holds gas pockets: rock tinted green, readable before you dig it,
# that releases a gas cloud when the player digs it out. Deep rock is
# unstable: decay ticks run faster while the player is down there.
const GAS_ATLAS_COORDS := Vector2i(5, 0)
const GAS_TINT := Color(0.45, 0.85, 0.25)
const GAS_TINT_STRENGTH := 0.45
const GAS_LAYER := 1
const GAS_POCKET_COUNT := 60
const UNSTABLE_LAYER := 2
const UNSTABLE_DECAY_MULTIPLIER := 0.5 # interval x0.5 = twice as fast
const WALL_TEXTURE_REGION := Rect2i(80, 120, 8, 16)
const WALL_DECAY_INTERVAL_LIT := 40.0  # seconds per wall lost, base light full
const WALL_DECAY_INTERVAL_DARK := 8.0  # ...and with the base light out

# Cellular-automata cave carving: start from a random fill below the
# solid crust, then smooth a few times so pockets read as caves rather
# than noise. Standard 4/5-neighbor rule. Fill is denser near the
# surface (tighter caves) and sparser deeper down (bigger caverns),
# matching "layers get more dangerous/rewarding with depth".
const LAYER_INITIAL_FILL := [0.62, 0.56, 0.53]
const CA_ITERATIONS := 3

const FUEL_DEPOSIT_COUNT := 80
const FuelPickupScene := preload("res://scenes/FuelPickup.tscn")

const ORE_DEPOSIT_COUNT := 60
const ORE_VALUE_BY_LAYER := [10, 25, 50] # topsoil/stone/deep - deeper = higher value
const OrePickupScene := preload("res://scenes/OrePickup.tscn")

# One lost miner per run, on a cave floor in this row band - deep enough
# to be a detour, shallow enough to escort back (milestone 13).
const LOST_MINER_MIN_ROW := 20
const LOST_MINER_MAX_ROW := 70

var source_id: int = 0
## Where Main should place this run's lost miner, or (-1, -1) if no floor
## cell fits the band.
var lost_miner_cell := Vector2i(-1, -1)
## Floor cells no pickup or NPC has claimed yet (shuffled).
var _spare_floor_cells: Array = []
var _wall_cells: Array[Vector2i] = []
var _wall_decay_timer: float = 0.0
## Cells the player has dug (tunnels that can collapse).
var _dug_cells: Array[Vector2i] = []
## Floor cells with a pickup or NPC standing on them; these never crumble.
var _reserved_floors: Dictionary = {}
var _decay_timer: float = 0.0
var _run_time: float = 0.0

func _ready() -> void:
	_build_tileset()
	_generate_layout()

func _build_tileset() -> void:
	var colors := LAYER_COLORS + [BEDROCK_COLOR, WALL_COLOR, LAYER_COLORS[GAS_LAYER]]
	var atlas_width := colors.size()
	var image := Image.create(TILE_SIZE * atlas_width, TILE_SIZE, false, Image.FORMAT_RGBA8)
	for i in range(atlas_width):
		image.fill_rect(Rect2i(i * TILE_SIZE, 0, TILE_SIZE, TILE_SIZE), colors[i])
	var source_image := TILESET_TEXTURE.get_image()
	source_image.decompress()
	for i in range(LAYER_TEXTURE_REGIONS.size()):
		var region: Rect2i = LAYER_TEXTURE_REGIONS[i]
		for x in range(TILE_SIZE):
			for y in range(TILE_SIZE):
				var pixel := source_image.get_pixel(region.position.x + x, region.position.y + y)
				if not pixel.is_equal_approx(PixelArt.SHEET_BG_COLOR):
					image.set_pixel(i * TILE_SIZE + x, y, pixel)
	for x in range(TILE_SIZE):
		for y in range(TILE_SIZE):
			var grate_x := WALL_TEXTURE_REGION.position.x + x % WALL_TEXTURE_REGION.size.x
			var pixel := source_image.get_pixel(grate_x, WALL_TEXTURE_REGION.position.y + y)
			if not pixel.is_equal_approx(PixelArt.SHEET_BG_COLOR):
				image.set_pixel(WALL_ATLAS_COORDS.x * TILE_SIZE + x, y, pixel)
	# Gas rock: the stone tile, tinted green.
	for x in range(TILE_SIZE):
		for y in range(TILE_SIZE):
			var stone := image.get_pixel(GAS_LAYER * TILE_SIZE + x, y)
			image.set_pixel(GAS_ATLAS_COORDS.x * TILE_SIZE + x, y, stone.lerp(GAS_TINT, GAS_TINT_STRENGTH))
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
				solid[x][y] = rng.randf() < LAYER_INITIAL_FILL[_layer_index_for_row(y)]
	_reinforce_boundaries(solid)

	for i in range(CA_ITERATIONS):
		solid = _smooth(solid)
		_reinforce_boundaries(solid)
		for x in range(GRID_WIDTH):
			solid[x][SURFACE_ROWS] = true

	for x in range(GRID_WIDTH):
		for y in range(GRID_HEIGHT):
			if not solid[x][y]:
				continue
			if _is_boundary(x, y):
				set_cell(0, Vector2i(x, y), source_id, BEDROCK_ATLAS_COORDS)
			else:
				var layer_index := _layer_index_for_row(y)
				set_cell(0, Vector2i(x, y), source_id, LAYER_ATLAS_COORDS[layer_index])
	_place_gas_pockets(rng)

	var floor_cells := _find_floor_cells(solid)
	floor_cells.shuffle()
	_scatter_fuel_deposits(floor_cells)
	_scatter_ore_deposits(floor_cells)
	_spare_floor_cells = floor_cells.slice(min(FUEL_DEPOSIT_COUNT + ORE_DEPOSIT_COUNT, floor_cells.size()))
	_pick_lost_miner_cell()

func _is_boundary(x: int, y: int) -> bool:
	return x == 0 or x == GRID_WIDTH - 1 or y == GRID_HEIGHT - 1

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
	# Full height, including surface rows, so the entrance shaft can't be
	# walked off the side of the map before any digging happens.
	for y in range(0, GRID_HEIGHT):
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
	var relative := float(y - SURFACE_ROWS) / float(GRID_HEIGHT - SURFACE_ROWS)
	var cumulative := 0.0
	for i in range(LAYER_FRACTIONS.size()):
		cumulative += LAYER_FRACTIONS[i]
		if relative < cumulative:
			return i
	return LAYER_FRACTIONS.size() - 1

## Open cells with solid rock directly beneath them - valid places to stand
## a pickup on a cave floor. Shared by fuel and ore scattering below.
func _find_floor_cells(solid: Array) -> Array:
	var floor_cells: Array = []
	for x in range(1, GRID_WIDTH - 1):
		for y in range(SURFACE_ROWS + 1, GRID_HEIGHT - 1):
			if not solid[x][y] and solid[x][y + 1]:
				floor_cells.append(Vector2i(x, y))
	return floor_cells

## Places fuel pickups on cave floors, the PRD's "found fuel" reward for
## exploring caves instead of digging straight down. Takes the front slice
## of the (already shuffled) floor_cells list; ore takes the next slice,
## so the two pickup types never land on the same cell.
func _scatter_fuel_deposits(floor_cells: Array) -> void:
	var count: int = min(FUEL_DEPOSIT_COUNT, floor_cells.size())
	for i in range(count):
		var cell: Vector2i = floor_cells[i]
		var pickup := FuelPickupScene.instantiate()
		pickup.position = map_to_local(cell)
		_reserved_floors[cell + Vector2i.DOWN] = true
		add_child(pickup)

## Ore/relic currency, banked on extraction (milestone 8). Value scales
## with depth band so pushing deeper is worth more, not just riskier.
func _scatter_ore_deposits(floor_cells: Array) -> void:
	var start: int = min(FUEL_DEPOSIT_COUNT, floor_cells.size())
	var end: int = min(start + ORE_DEPOSIT_COUNT, floor_cells.size())
	for i in range(start, end):
		var cell: Vector2i = floor_cells[i]
		var pickup := OrePickupScene.instantiate()
		pickup.value = ORE_VALUE_BY_LAYER[_layer_index_for_row(cell.y)]
		pickup.position = map_to_local(cell)
		_reserved_floors[cell + Vector2i.DOWN] = true
		add_child(pickup)

func _pick_lost_miner_cell() -> void:
	lost_miner_cell = _take_spare_floor_cell(func(cell): return cell.y >= LOST_MINER_MIN_ROW and cell.y <= LOST_MINER_MAX_ROW)

## A random unclaimed cave-floor cell in a depth band, for placing a
## stranded miner in the layer they drifted to. (-1, -1) if none.
func take_floor_cell_in_layer(layer_index: int) -> Vector2i:
	return _take_spare_floor_cell(func(cell): return _layer_index_for_row(cell.y) == layer_index)

## Up to count unclaimed cave-floor cells between min and max tiles from
## center, spread evenly by distance (far to near) - where a stranded
## miner's signs go, so they get denser as you close in. Claims them, so
## their floors never crumble.
func take_trail_cells(center: Vector2i, count: int, min_tiles: float, max_tiles: float) -> Array[Vector2i]:
	var candidates: Array[Vector2i] = []
	for cell in _spare_floor_cells:
		var d := Vector2(cell - center).length()
		if d >= min_tiles and d <= max_tiles:
			candidates.append(cell)
	# Aim each sign at an evenly spaced distance, max down to min, taking
	# the closest-matching cell. (Picking evenly through a distance-sorted
	# list skews far: there is more floor area at larger radii.)
	var picked: Array[Vector2i] = []
	for i in range(count):
		if candidates.is_empty():
			break
		var target: float = lerp(max_tiles, min_tiles, i / float(max(1, count - 1)))
		var best: Vector2i = candidates[0]
		for cell in candidates:
			if absf(Vector2(cell - center).length() - target) < absf(Vector2(best - center).length() - target):
				best = cell
		candidates.erase(best)
		_spare_floor_cells.erase(best)
		_reserved_floors[best + Vector2i.DOWN] = true
		picked.append(best)
	return picked

func _take_spare_floor_cell(accept: Callable) -> Vector2i:
	for i in range(_spare_floor_cells.size()):
		var cell: Vector2i = _spare_floor_cells[i]
		if accept.call(cell):
			_spare_floor_cells.remove_at(i)
			_reserved_floors[cell + Vector2i.DOWN] = true
			return cell
	return Vector2i(-1, -1)

func layer_index_at_world(world_pos: Vector2) -> int:
	return _layer_index_for_row(clamp(world_to_cell(world_pos).y, SURFACE_ROWS, GRID_HEIGHT - 1))

func is_solid(cell: Vector2i) -> bool:
	return get_cell_source_id(0, cell) != -1

func is_indestructible(cell: Vector2i) -> bool:
	return get_cell_atlas_coords(0, cell) == BEDROCK_ATLAS_COORDS

func dig_at_world(world_pos: Vector2) -> bool:
	return dig_cells([world_to_cell(world_pos)]) > 0

## Digs every solid, destructible cell in the list, emitting noise scaled
## to how much was actually cleared. Used for multi-tile digs (a tall
## notch, a step) so a bigger dig costs more noise than a single tile.
## Bedrock at the map's edges is skipped, so a run can never dig its way
## out of the generated area. Enemies pass emit_noise = false: noise is
## the player's cost, and a Burrower's tunnelling feeding the meter would
## chain-spawn more Burrowers.
func dig_cells(cells: Array, emit_noise: bool = true) -> int:
	var dug_count := 0
	for cell in cells:
		if is_solid(cell) and not is_indestructible(cell):
			if emit_noise and is_gas(cell): # player digs only; Burrowers tunnel through quietly
				gas_released.emit(cell_to_world(cell))
			set_cell(0, cell, -1)
			_wall_cells.erase(cell)
			dug_count += 1
			if emit_noise: # player digs; enemy tunnels don't collapse
				_dug_cells.append(cell)
	if dug_count > 0 and emit_noise:
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

## One decay tick's worth of collapse + crumble when due. Returns the
## noise made, for Main to feed the meter.
func tick_decay(delta: float, player_pos: Vector2) -> float:
	_run_time += delta
	_decay_timer += delta
	var interval := decay_interval(player_pos)
	if _decay_timer < interval:
		return 0.0
	_decay_timer = 0.0
	var noise := 0.0
	if _collapse_tunnel():
		noise += DECAY_NOISE
	if _crumble_floor(player_pos):
		noise += DECAY_NOISE
	return noise

## Seconds between decay ticks: shrinks over the run, and halves while the
## player is in the unstable deep layer.
func decay_interval(player_pos: Vector2) -> float:
	var interval: float = lerp(DECAY_INTERVAL_START, DECAY_INTERVAL_END, min(1.0, _run_time / DECAY_RAMP_TIME))
	if layer_index_at_world(player_pos) == UNSTABLE_LAYER:
		interval *= UNSTABLE_DECAY_MULTIPLIER
	return interval

func _place_gas_pockets(rng: RandomNumberGenerator) -> void:
	var placed := 0
	var tries := 0
	while placed < GAS_POCKET_COUNT and tries < GAS_POCKET_COUNT * 20:
		tries += 1
		var cell := Vector2i(rng.randi_range(1, GRID_WIDTH - 2), rng.randi_range(SURFACE_ROWS + 1, GRID_HEIGHT - 2))
		if _layer_index_for_row(cell.y) == GAS_LAYER and get_cell_atlas_coords(0, cell) == LAYER_ATLAS_COORDS[GAS_LAYER]:
			set_cell(0, cell, source_id, GAS_ATLAS_COORDS)
			placed += 1

func is_gas(cell: Vector2i) -> bool:
	return get_cell_atlas_coords(0, cell) == GAS_ATLAS_COORDS

func _collapse_tunnel() -> bool:
	var candidates := _dug_cells.filter(func(c): return not is_solid(c) and not is_lit(cell_to_world(c)))
	if candidates.is_empty():
		return false
	var cell: Vector2i = candidates.pick_random()
	_dug_cells.erase(cell)
	set_cell(0, cell, source_id, LAYER_ATLAS_COORDS[_layer_index_for_row(cell.y)])
	return true

func _crumble_floor(player_pos: Vector2) -> bool:
	var center := world_to_cell(player_pos)
	for i in range(CRUMBLE_SAMPLE_TRIES):
		var cell := center + Vector2i(randi_range(-CRUMBLE_RADIUS_TILES, CRUMBLE_RADIUS_TILES), randi_range(-CRUMBLE_RADIUS_TILES, CRUMBLE_RADIUS_TILES))
		if cell.y <= SURFACE_ROWS or not is_solid(cell) or is_indestructible(cell) or is_wall(cell):
			continue
		if is_solid(cell + Vector2i.UP) or _reserved_floors.has(cell) or is_lit(cell_to_world(cell)):
			continue
		set_cell(0, cell, -1)
		return true
	return false

## Inside any MineLight's current radius (same test ropes use).
func is_lit(world_pos: Vector2) -> bool:
	return MineLight.is_lit(get_tree(), world_pos)

func is_wall(cell: Vector2i) -> bool:
	return get_cell_atlas_coords(0, cell) == WALL_ATLAS_COORDS

func wall_count() -> int:
	return _wall_cells.size()

## Solid, non-bedrock, not-yet-walled cells within radius of center,
## nearest first - what fortifying would reinforce, in order.
func unreinforced_cells_around(center: Vector2i, radius: int) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for dx in range(-radius, radius + 1):
		for dy in range(-radius, radius + 1):
			var cell := center + Vector2i(dx, dy)
			if Vector2(dx, dy).length() <= radius and is_solid(cell) and not is_indestructible(cell) and not is_wall(cell):
				cells.append(cell)
	cells.sort_custom(func(a, b): return (a - center).length_squared() < (b - center).length_squared())
	return cells

func reinforce(cell: Vector2i) -> void:
	set_cell(0, cell, source_id, WALL_ATLAS_COORDS)
	_wall_cells.append(cell)

## Wears one random wall back to plain rock every interval; the interval
## shrinks as the base light dims (PRD: structures decay faster in the
## dark, sharing the light's clock).
func decay_walls(delta: float, base_light_fraction: float) -> void:
	if _wall_cells.is_empty():
		_wall_decay_timer = 0.0
		return
	_wall_decay_timer += delta
	var interval: float = lerp(WALL_DECAY_INTERVAL_DARK, WALL_DECAY_INTERVAL_LIT, base_light_fraction)
	if _wall_decay_timer < interval:
		return
	_wall_decay_timer = 0.0
	var cell: Vector2i = _wall_cells.pick_random()
	_wall_cells.erase(cell)
	set_cell(0, cell, source_id, LAYER_ATLAS_COORDS[_layer_index_for_row(cell.y)])

func world_to_cell(world_pos: Vector2) -> Vector2i:
	return local_to_map(to_local(world_pos))

func cell_to_world(cell: Vector2i) -> Vector2:
	return to_global(map_to_local(cell))

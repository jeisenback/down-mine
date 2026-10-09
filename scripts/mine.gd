extends TileMap
class_name MineGrid

signal tile_dug(noise_amount: float)
## The player dug out a gas rock (milestone 29); Main releases a cloud.
signal gas_released(world_pos: Vector2)

const TILE_SIZE := 16
const GRID_WIDTH := 160
const GRID_HEIGHT := 450
const SURFACE_ROWS := 4
const DIG_NOISE := 6.0

# 16x16 fill regions in the Deep Night tileset (8x8 pack, so each layer
# tile is a 2x2 block of its art). The sheet's flat background colour also
# fills the gaps in these textures; those pixels get the layer colour
# instead, so solid rock still reads apart from empty cave.
const TILESET_TEXTURE := preload("res://assets/deep_night/tiles.png")
const SPECKLE_GREEN := Rect2i(0, 64, 16, 16)
const SPECKLE_BLUE := Rect2i(104, 64, 16, 16)
const STONE_BLOCK := Rect2i(8, 120, 16, 16)

# Depth bands, top to bottom, per the PRD's "layers have their own
# hazards and look" pillar. One table drives everything keyed by layer:
# the tile look, cave density (denser near the surface, bigger caverns
# deeper down), ore value (deeper = more), what the camp there holds,
# and the hazards, all of which already exist elsewhere in the game:
#   quiet   - noise never fills the meter and no Stalker enters (the
#             lonely start: nothing hunts in the first two layers)
#   gas     - gas pockets in the rock (see _place_gas_pockets)
#   decay   - decay interval multiplier; below 1 the layer is unstable
#   stalker - the first descent into the layer wakes a Stalker
# Equal depth bands; the layer index is the key in saves too (stranded
# miners' layer, where a miner was found), so order matters.
const LAYERS := [
	{"name": "Topsoil", "quiet": true, "gas": false, "decay": 1.0, "stalker": false,
		"fill": 0.62, "ore": 10, "camp_ore": 15, "color": Color(0.42, 0.32, 0.22), "region": SPECKLE_GREEN},
	{"name": "Clay", "quiet": true, "gas": false, "decay": 1.0, "stalker": false,
		"fill": 0.60, "ore": 15, "camp_ore": 20, "color": Color(0.5, 0.3, 0.22), "region": SPECKLE_GREEN},
	{"name": "Stone", "quiet": false, "gas": true, "decay": 1.0, "stalker": true,
		"fill": 0.56, "ore": 25, "camp_ore": 30, "color": Color(0.45, 0.45, 0.48), "region": SPECKLE_BLUE},
	{"name": "Slate", "quiet": false, "gas": false, "decay": 0.5, "stalker": false,
		"fill": 0.55, "ore": 35, "camp_ore": 40, "color": Color(0.3, 0.33, 0.4), "region": SPECKLE_BLUE},
	{"name": "Deep rock", "quiet": false, "gas": true, "decay": 0.5, "stalker": true,
		"fill": 0.53, "ore": 50, "camp_ore": 60, "color": Color(0.22, 0.16, 0.2), "region": STONE_BLOCK},
	{"name": "The Hollow", "quiet": false, "gas": false, "decay": 0.35, "stalker": false,
		"fill": 0.50, "ore": 75, "camp_ore": 80, "color": Color(0.12, 0.2, 0.22), "region": STONE_BLOCK},
]
# Two layers can share a texture region; the tile is tinted toward the
# layer colour by this much so they still read apart.
const LAYER_TINT_STRENGTH := 0.35

# Tile atlas layout: one tile per layer, then one gas variant per layer,
# then bedrock, reinforced wall and the vault shell.
const LAYER_COUNT := 6 # LAYERS.size(); _ready checks they agree
const GAS_ATLAS_OFFSET := LAYER_COUNT
const BEDROCK_ATLAS_COORDS := Vector2i(2 * LAYER_COUNT, 0)
const WALL_ATLAS_COORDS := Vector2i(2 * LAYER_COUNT + 1, 0)
const VAULT_ATLAS_COORDS := Vector2i(2 * LAYER_COUNT + 2, 0)

# Bedrock: indestructible, forms the map's outer walls/floor so digging
# can never open a path out of the generated area.
const BEDROCK_COLOR := Color(0.05, 0.05, 0.06)
# The relic vault's shell (milestone 35): indestructible like bedrock, but
# deep stone tinted brass so it reads as a built chamber.
const VAULT_TINT := Color(0.75, 0.6, 0.3)
const VAULT_TINT_STRENGTH := 0.4

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
const COLLAPSE_HEARING_TILES := 16.0

# Reinforced rock around the run base (milestone 18): the tileset's iron
# grate (8x16, drawn twice across) over dark earth. Burrowers must chew
# through it; the player digs it like normal rock. Walls wear back to
# plain rock over time, faster when the base's light is low.
const WALL_COLOR := Color(0.2, 0.15, 0.1)

# Layer identity (milestone 29, PRD: layers have "their own hazards").
# Gas layers hold gas pockets: rock tinted green, readable before you dig
# it, that releases a gas cloud when the player digs it out. Unstable
# layers (decay < 1) tick decay faster while the player is down there.
const GAS_TINT := Color(0.45, 0.85, 0.25)
const GAS_TINT_STRENGTH := 0.45
const GAS_POCKET_COUNT := 60 # per gas layer
const WALL_TEXTURE_REGION := Rect2i(80, 120, 8, 16)
const WALL_DECAY_INTERVAL_LIT := 40.0  # seconds per wall lost, base light full
const WALL_DECAY_INTERVAL_DARK := 8.0  # ...and with the base light out

# Cellular-automata cave carving: start from a random fill (each layer's
# "fill") below the solid crust, then smooth a few times so pockets read
# as caves rather than noise. Standard 4/5-neighbor rule.
const CA_ITERATIONS := 3

# Pickup counts are per mine; the mine is 160x450, so these keep the
# density of the old 80x300 one.
const FUEL_DEPOSIT_COUNT := 240
const FuelPickupScene := preload("res://scenes/FuelPickup.tscn")

const ORE_DEPOSIT_COUNT := 180
const OrePickupScene := preload("res://scenes/OrePickup.tscn")

# One lost miner per run, on a cave floor straddling the bottom of the
# quiet zone - deep enough to be a detour with some risk, shallow enough
# to escort back (milestone 13).
const LOST_MINER_ROWS_ABOVE_QUIET_FLOOR := 30
const LOST_MINER_ROWS_BELOW_QUIET_FLOOR := 40

# Event rooms (milestone 33): open chambers carved each run, each holding
# one mine event that Main places (see Main._spawn_events). One entry per
# room; the layer is picked from the listed ones. A camp in every layer.
const EVENT_ROOMS := [
	# First, so it always finds room in the bottom band.
	{"kind": "heart", "layers": [5], "bottom": true},
	{"kind": "camp", "layers": [0]},
	{"kind": "camp", "layers": [1]},
	{"kind": "camp", "layers": [2]},
	{"kind": "camp", "layers": [3]},
	{"kind": "camp", "layers": [4]},
	{"kind": "camp", "layers": [5]},
	{"kind": "lift", "layers": [2, 3]},
	{"kind": "outpost", "layers": [2, 3, 4]},
	{"kind": "vault", "layers": [4, 5]},
	{"kind": "gallery", "layers": [3, 4]},
	{"kind": "nest", "layers": [4]},
]
const ROOM_SIZE := Vector2i(9, 4)
const ROOM_MIN_SPACING_TILES := 32.0
const ROOM_PLACE_TRIES := 50

var source_id: int = 0
## This mine's seed (milestone 43): the same seed builds the same mine.
var mine_seed: int = 0
## The seed the next mine uses; 0 picks a random one. Main sets it from
## the launch options for the first run.
static var next_seed: int = 0
static var _launch_seed_read: bool = false
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
## This run's event rooms: {"kind", "cell"}, cell = floor-standing
## center of the room.
var event_rooms: Array = []
## Open cells and floors of the event rooms; no pickups, gas or crumbling.
var _room_cells: Dictionary = {}
## Bedrock shell of the relic vault (milestone 35).
var _vault_cells: Dictionary = {}
var _decay_timer: float = 0.0
## Scales every decay interval: below 1 the mine falls apart faster
## (claimed Hearts, and a Heart being carried - milestone 40).
var decay_multiplier: float = 1.0
var _run_time: float = 0.0

func _ready() -> void:
	assert(LAYERS.size() == LAYER_COUNT, "LAYER_COUNT must match the LAYERS table")
	_build_tileset()
	_generate_layout()

func _build_tileset() -> void:
	var atlas_width := VAULT_ATLAS_COORDS.x + 1
	var image := Image.create(TILE_SIZE * atlas_width, TILE_SIZE, false, Image.FORMAT_RGBA8)
	image.fill_rect(Rect2i(BEDROCK_ATLAS_COORDS.x * TILE_SIZE, 0, TILE_SIZE, TILE_SIZE), BEDROCK_COLOR)
	image.fill_rect(Rect2i(WALL_ATLAS_COORDS.x * TILE_SIZE, 0, TILE_SIZE, TILE_SIZE), WALL_COLOR)
	var source_image := TILESET_TEXTURE.get_image()
	source_image.decompress()
	# Each layer's tile: its texture region tinted toward the layer colour,
	# background pixels replaced by it; the gas variant is that tinted green.
	for i in range(LAYERS.size()):
		var layer: Dictionary = LAYERS[i]
		var region: Rect2i = layer.region
		for x in range(TILE_SIZE):
			for y in range(TILE_SIZE):
				var pixel := source_image.get_pixel(region.position.x + x, region.position.y + y)
				if pixel.is_equal_approx(PixelArt.SHEET_BG_COLOR):
					pixel = layer.color
				else:
					pixel = pixel.lerp(layer.color, LAYER_TINT_STRENGTH)
				image.set_pixel(layer_atlas(i).x * TILE_SIZE + x, y, pixel)
				image.set_pixel(gas_atlas(i).x * TILE_SIZE + x, y, pixel.lerp(GAS_TINT, GAS_TINT_STRENGTH))
	for x in range(TILE_SIZE):
		for y in range(TILE_SIZE):
			var grate_x := WALL_TEXTURE_REGION.position.x + x % WALL_TEXTURE_REGION.size.x
			var pixel := source_image.get_pixel(grate_x, WALL_TEXTURE_REGION.position.y + y)
			if not pixel.is_equal_approx(PixelArt.SHEET_BG_COLOR):
				image.set_pixel(WALL_ATLAS_COORDS.x * TILE_SIZE + x, y, pixel)
			# The vault shell: the deepest layer's tile, tinted brass.
			var deep := image.get_pixel(layer_atlas(LAYERS.size() - 1).x * TILE_SIZE + x, y)
			image.set_pixel(VAULT_ATLAS_COORDS.x * TILE_SIZE + x, y, deep.lerp(VAULT_TINT, VAULT_TINT_STRENGTH))
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
	if not _launch_seed_read: # a launch seed applies to the first mine only
		_launch_seed_read = true
		var launch_seed := LaunchOptions.value("seed")
		if launch_seed.is_valid_int():
			next_seed = int(launch_seed)
	mine_seed = next_seed if next_seed != 0 else randi_range(1, 999999)
	next_seed = 0
	rng.seed = mine_seed
	seed(mine_seed) # shuffles and picks elsewhere in generation use the global RNG

	var solid := _make_grid(false)
	for x in range(GRID_WIDTH):
		for y in range(GRID_HEIGHT):
			if y < SURFACE_ROWS:
				solid[x][y] = false
			elif y == SURFACE_ROWS:
				solid[x][y] = true # a crust the player always has to dig through
			else:
				solid[x][y] = rng.randf() < LAYERS[_layer_index_for_row(y)].fill
	_reinforce_boundaries(solid)

	for i in range(CA_ITERATIONS):
		solid = _smooth(solid)
		_reinforce_boundaries(solid)
		for x in range(GRID_WIDTH):
			solid[x][SURFACE_ROWS] = true
	_carve_event_rooms(solid, rng)

	for x in range(GRID_WIDTH):
		for y in range(GRID_HEIGHT):
			if not solid[x][y]:
				continue
			if _is_boundary(x, y):
				set_cell(0, Vector2i(x, y), source_id, BEDROCK_ATLAS_COORDS)
			elif _vault_cells.has(Vector2i(x, y)):
				set_cell(0, Vector2i(x, y), source_id, VAULT_ATLAS_COORDS)
			else:
				set_cell(0, Vector2i(x, y), source_id, layer_atlas(_layer_index_for_row(y)))
	_place_gas_pockets(rng)

	var floor_cells := _find_floor_cells(solid).filter(func(c): return not _room_cells.has(c))
	floor_cells.shuffle()
	_scatter_fuel_deposits(floor_cells)
	_scatter_ore_deposits(floor_cells)
	_spare_floor_cells = floor_cells.slice(min(FUEL_DEPOSIT_COUNT + ORE_DEPOSIT_COUNT, floor_cells.size()))
	_pick_lost_miner_cell()

## Clears a ROOM_SIZE chamber per EVENT_ROOMS entry, on a solid floor,
## spaced apart. A room that finds no spot is skipped.
func _carve_event_rooms(solid: Array, rng: RandomNumberGenerator) -> void:
	for room in EVENT_ROOMS:
		var layer: int = room.layers[rng.randi_range(0, room.layers.size() - 1)]
		var rows := _layer_rows(layer)
		if room.get("bottom", false):
			rows.x = rows.y - ROOM_SIZE.y - 12
		for i in range(ROOM_PLACE_TRIES):
			var top_left := Vector2i(rng.randi_range(2, GRID_WIDTH - 2 - ROOM_SIZE.x),
				rng.randi_range(max(rows.x, SURFACE_ROWS + 2), rows.y - ROOM_SIZE.y - 1))
			var center := top_left + Vector2i(ROOM_SIZE.x / 2, ROOM_SIZE.y - 1)
			if event_rooms.any(func(r): return Vector2(r.cell - center).length() < ROOM_MIN_SPACING_TILES):
				continue
			for x in range(top_left.x, top_left.x + ROOM_SIZE.x):
				for y in range(top_left.y, top_left.y + ROOM_SIZE.y + 1):
					solid[x][y] = y == top_left.y + ROOM_SIZE.y # open room, solid floor row
					_room_cells[Vector2i(x, y)] = true
					if solid[x][y]:
						_reserved_floors[Vector2i(x, y)] = true
			var entry := {"kind": room.kind, "cell": center, "rect": Rect2i(top_left, ROOM_SIZE)}
			if room.kind == "vault":
				entry["door"] = _seal_vault(solid, top_left)
			event_rooms.append(entry)
			break

## Rings the room at top_left in bedrock, leaving a 2-tile doorway on its
## left at floor level (Main puts the vault door there). Returns the
## doorway's lower cell.
func _seal_vault(solid: Array, top_left: Vector2i) -> Vector2i:
	var left := top_left.x - 1
	var right := top_left.x + ROOM_SIZE.x
	var top := top_left.y - 1
	var bottom := top_left.y + ROOM_SIZE.y
	var door := Vector2i(left, bottom - 1)
	for x in range(left, right + 1):
		for y in range(top, bottom + 1):
			if x != left and x != right and y != top and y != bottom:
				continue
			var cell := Vector2i(x, y)
			_room_cells[cell] = true
			if cell == door or cell == door + Vector2i.UP:
				solid[x][y] = false
			else:
				solid[x][y] = true
				_vault_cells[cell] = true
	return door

## First and last row (inclusive) of a depth layer.
func _layer_rows(layer: int) -> Vector2i:
	var first := -1
	var last := -1
	for y in range(SURFACE_ROWS, GRID_HEIGHT - 1):
		if _layer_index_for_row(y) == layer:
			if first < 0:
				first = y
			last = y
	return Vector2i(first, last)

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

## Equal depth bands below the surface rows.
func _layer_index_for_row(y: int) -> int:
	var relative := float(y - SURFACE_ROWS) / float(GRID_HEIGHT - SURFACE_ROWS)
	return clampi(int(relative * LAYERS.size()), 0, LAYERS.size() - 1)

## Last row of the deepest quiet layer: the floor of the lonely zone.
func quiet_floor_row() -> int:
	var last := SURFACE_ROWS
	for i in range(LAYERS.size()):
		if LAYERS[i].quiet:
			last = _layer_rows(i).y
	return last

## Inside a quiet layer (or above the crust): nothing hears, nothing hunts.
func is_quiet_at(world_pos: Vector2) -> bool:
	return LAYERS[layer_index_at_world(world_pos)].quiet

## The HUD's one-line summary of a layer's hazards, from its flags.
func hazard_text(layer: int, with_stalker: bool = true) -> String:
	var entry: Dictionary = LAYERS[layer]
	var parts: Array[String] = []
	if entry.quiet:
		parts.append("quiet")
	if entry.gas:
		parts.append("gas pockets")
	if entry.decay < 1.0:
		parts.append("unstable")
	if entry.stalker and with_stalker:
		parts.append("a Stalker wakes")
	return ", ".join(parts)

func layer_atlas(layer: int) -> Vector2i:
	return Vector2i(layer, 0)

func gas_atlas(layer: int) -> Vector2i:
	return Vector2i(GAS_ATLAS_OFFSET + layer, 0)

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
		pickup.value = ore_value_at(cell_to_world(cell))
		pickup.position = map_to_local(cell)
		_reserved_floors[cell + Vector2i.DOWN] = true
		add_child(pickup)

func _pick_lost_miner_cell() -> void:
	var first := quiet_floor_row() - LOST_MINER_ROWS_ABOVE_QUIET_FLOOR
	var last := quiet_floor_row() + LOST_MINER_ROWS_BELOW_QUIET_FLOOR
	lost_miner_cell = _take_spare_floor_cell(func(cell): return cell.y >= first and cell.y <= last)

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

## Ore value per pickup at a spot: deeper layers pay more.
func ore_value_at(world_pos: Vector2) -> int:
	return LAYERS[layer_index_at_world(world_pos)].ore

## Refills an open cell with its layer's rock (the gallery collapse).
func fill_cell(cell: Vector2i) -> void:
	set_cell(0, cell, source_id, layer_atlas(_layer_index_for_row(cell.y)))

func is_solid(cell: Vector2i) -> bool:
	return get_cell_source_id(0, cell) != -1

func is_indestructible(cell: Vector2i) -> bool:
	return get_cell_atlas_coords(0, cell) in [BEDROCK_ATLAS_COORDS, VAULT_ATLAS_COORDS]

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
		Sfx.play("dig")
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
	for cell in [_collapse_tunnel(), _crumble_floor(player_pos)]:
		if cell.x >= 0:
			noise += DECAY_NOISE
			_play_collapse(cell, player_pos)
	return noise

## Rumble for a collapse or crumble, fading with distance; silent past
## COLLAPSE_HEARING_TILES so the far side of the mine doesn't chatter.
func _play_collapse(cell: Vector2i, player_pos: Vector2) -> void:
	var tiles := cell_to_world(cell).distance_to(player_pos) / TILE_SIZE
	if tiles <= COLLAPSE_HEARING_TILES:
		Sfx.play("collapse", -3.0 - tiles)

## Seconds between decay ticks: shrinks over the run, and shrinks again
## by the layer's decay multiplier while the player is in an unstable one.
func decay_interval(player_pos: Vector2) -> float:
	var interval: float = lerp(DECAY_INTERVAL_START, DECAY_INTERVAL_END, min(1.0, _run_time / DECAY_RAMP_TIME))
	interval *= LAYERS[layer_index_at_world(player_pos)].decay
	return interval * decay_multiplier

## GAS_POCKET_COUNT pockets in each gas layer, in plain rock outside rooms.
func _place_gas_pockets(rng: RandomNumberGenerator) -> void:
	for layer in range(LAYERS.size()):
		if not LAYERS[layer].gas:
			continue
		var rows := _layer_rows(layer)
		var placed := 0
		var tries := 0
		while placed < GAS_POCKET_COUNT and tries < GAS_POCKET_COUNT * 20:
			tries += 1
			var cell := Vector2i(rng.randi_range(1, GRID_WIDTH - 2), rng.randi_range(rows.x, rows.y))
			if _room_cells.has(cell) or get_cell_atlas_coords(0, cell) != layer_atlas(layer):
				continue
			set_cell(0, cell, source_id, gas_atlas(layer))
			placed += 1

func is_gas(cell: Vector2i) -> bool:
	var atlas := get_cell_atlas_coords(0, cell)
	return atlas.y == 0 and atlas.x >= GAS_ATLAS_OFFSET and atlas.x < GAS_ATLAS_OFFSET + LAYERS.size()

## Refills one dark dug cell; returns it, or (-1, -1) if none.
func _collapse_tunnel() -> Vector2i:
	var candidates := _dug_cells.filter(func(c): return not is_solid(c) and not is_lit(cell_to_world(c)) \
		and not Support.protects(get_tree(), cell_to_world(c)))
	if candidates.is_empty():
		return Vector2i(-1, -1)
	var cell: Vector2i = candidates.pick_random()
	_dug_cells.erase(cell)
	fill_cell(cell)
	return cell

## Drops one dark cave floor near the player; returns it, or (-1, -1).
func _crumble_floor(player_pos: Vector2) -> Vector2i:
	var center := world_to_cell(player_pos)
	for i in range(CRUMBLE_SAMPLE_TRIES):
		var cell := center + Vector2i(randi_range(-CRUMBLE_RADIUS_TILES, CRUMBLE_RADIUS_TILES), randi_range(-CRUMBLE_RADIUS_TILES, CRUMBLE_RADIUS_TILES))
		if cell.y <= SURFACE_ROWS or not is_solid(cell) or is_indestructible(cell) or is_wall(cell):
			continue
		if Support.protects(get_tree(), cell_to_world(cell)):
			continue
		if is_solid(cell + Vector2i.UP) or _reserved_floors.has(cell) or is_lit(cell_to_world(cell)):
			continue
		set_cell(0, cell, -1)
		return cell
	return Vector2i(-1, -1)

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
	fill_cell(cell)

func world_to_cell(world_pos: Vector2) -> Vector2i:
	return local_to_map(to_local(world_pos))

func cell_to_world(cell: Vector2i) -> Vector2:
	return to_global(map_to_local(cell))

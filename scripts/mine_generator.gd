extends RefCounted
class_name MineGenerator

## Turns a seed into a MineLayout (issue #74). No nodes, no tile map. One
## side effect: it seeds the GLOBAL random generator (`seed(mine_seed)`), which
## the floor-cell shuffle here and the fuel pickups MineGrid builds afterwards
## draw from, so what Main picks later (names, crumbling floors) depends on it.
## The same seed must always build the same mine, so the random sources and
## their order are exactly the old MineGrid's: one generator seeded with the
## mine seed (fill, event rooms, gas), `seed + 51` (old mine), `seed + 52`
## (torches), and the global generator for the shuffle. The golden fingerprint
## test hashes where the global generator ends up, so an extra draw fails it.

var _layout := MineLayout.new()
var _solid: Array = []
var _rng := RandomNumberGenerator.new()

static func generate(mine_seed: int) -> MineLayout:
	return MineGenerator.new()._run(mine_seed)

# --- helpers shared with MineGrid's queries ----------------------------------------

## Equal depth bands below the surface rows.
static func layer_index_for_row(y: int) -> int:
	var relative := float(y - MineGrid.SURFACE_ROWS) / float(MineGrid.GRID_HEIGHT - MineGrid.SURFACE_ROWS)
	return clampi(int(relative * MineGrid.LAYERS.size()), 0, MineGrid.LAYERS.size() - 1)

## First and last row (inclusive) of a depth layer.
static func layer_rows(layer: int) -> Vector2i:
	var first := -1
	var last := -1
	for y in range(MineGrid.SURFACE_ROWS, MineGrid.GRID_HEIGHT - 1):
		if layer_index_for_row(y) == layer:
			if first < 0:
				first = y
			last = y
	return Vector2i(first, last)

static func shaft_column() -> int:
	return MineGrid.GRID_WIDTH / 2

## First and last open row of the shaft, above its collapse.
static func shaft_open_rows(shaft_end_row: int) -> Vector2i:
	return Vector2i(MineGrid.SURFACE_ROWS + 1, shaft_end_row - MineGrid.SHAFT_COLLAPSE_ROWS)

static func shaft_rect(shaft_end_row: int) -> Rect2i:
	return Rect2i(shaft_column() - MineGrid.SHAFT_WIDTH / 2, MineGrid.SURFACE_ROWS + 1,
			MineGrid.SHAFT_WIDTH, shaft_end_row - MineGrid.SURFACE_ROWS)

## The shaft's box, then each drift's box (its two rows and the floor).
static func old_mine_rects(drifts: Array[Drift], shaft_end_row: int) -> Array[Rect2i]:
	var rects: Array[Rect2i] = [shaft_rect(shaft_end_row)]
	for d in drifts:
		var left: int = mini(d.x0, d.x1)
		rects.append(Rect2i(left, d.row - 1, absi(d.x1 - d.x0) + 1, 3))
	return rects

## Last row of the deepest quiet layer: the floor of the lonely zone.
static func quiet_floor_row() -> int:
	var last := MineGrid.SURFACE_ROWS
	for i in range(MineGrid.LAYERS.size()):
		if MineGrid.LAYERS[i].quiet:
			last = layer_rows(i).y
	return last

static func is_boundary(x: int, y: int) -> bool:
	return x == 0 or x == MineGrid.GRID_WIDTH - 1 or y == MineGrid.GRID_HEIGHT - 1

# --- generation -------------------------------------------------------------------

func _run(mine_seed: int) -> MineLayout:
	_layout.mine_seed = mine_seed
	_rng.seed = mine_seed
	seed(mine_seed) # the floor-cell shuffle below, then the fuel pickups, draw from the global RNG

	_solid = _make_grid(false)
	for x in range(MineGrid.GRID_WIDTH):
		for y in range(MineGrid.GRID_HEIGHT):
			if y < MineGrid.SURFACE_ROWS:
				_solid[x][y] = false
			elif y == MineGrid.SURFACE_ROWS:
				_solid[x][y] = true # a crust the player always has to dig through
			else:
				_solid[x][y] = _rng.randf() < MineGrid.LAYERS[layer_index_for_row(y)].fill
	_reinforce_boundaries(_solid)

	var flat := _flatten(_solid)
	for i in range(MineGrid.CA_ITERATIONS):
		flat = smooth(flat)
		_reinforce_flat(flat)
		for x in range(MineGrid.GRID_WIDTH):
			flat[x * MineGrid.GRID_HEIGHT + MineGrid.SURFACE_ROWS] = 1
	_solid = _unflatten(flat)
	_carve_old_mine()
	_carve_event_rooms()

	var shaft := shaft_rect(_layout.shaft_end_row)
	for x in range(MineGrid.GRID_WIDTH):
		for y in range(MineGrid.GRID_HEIGHT):
			if not _solid[x][y]:
				continue
			var cell := Vector2i(x, y)
			var kind := MineLayout.Kind.ROCK
			if is_boundary(x, y):
				kind = MineLayout.Kind.BEDROCK
			elif _layout.vault_cells.has(cell):
				kind = MineLayout.Kind.VAULT
			elif _layout.plank_cells.has(cell):
				kind = MineLayout.Kind.PLANK
			elif shaft.has_point(cell) or _layout.debris_cells.has(cell):
				kind = MineLayout.Kind.DEBRIS
			_layout.kinds[x * MineGrid.GRID_HEIGHT + y] = kind
	_place_gas_pockets()

	var floor_cells := _find_floor_cells().filter(func(c): return not _layout.room_cells.has(c))
	floor_cells.shuffle()
	_scatter_pickups(floor_cells)
	_layout.spare_floor_cells = floor_cells.slice(min(MineGrid.FUEL_DEPOSIT_COUNT + MineGrid.ORE_DEPOSIT_COUNT, floor_cells.size()))
	_pick_lost_miner_cell()
	_place_torches()
	return _layout

func _make_grid(default_value: bool) -> Array:
	var grid: Array = []
	grid.resize(MineGrid.GRID_WIDTH)
	for x in range(MineGrid.GRID_WIDTH):
		var column: Array = []
		column.resize(MineGrid.GRID_HEIGHT)
		column.fill(default_value)
		grid[x] = column
	return grid

func _reinforce_boundaries(grid: Array) -> void:
	for x in range(MineGrid.GRID_WIDTH):
		grid[x][MineGrid.GRID_HEIGHT - 1] = true
	# Full height, including surface rows, so the entrance shaft can't be
	# walked off the side of the map before any digging happens.
	for y in range(0, MineGrid.GRID_HEIGHT):
		grid[0][y] = true
		grid[MineGrid.GRID_WIDTH - 1][y] = true

## One cellular-automata pass over a flat grid (index x * GRID_HEIGHT + y, 1 = solid): a
## solid cell stays solid with 4 or more solid neighbours of its 8, an empty one becomes
## solid with 5 or more; outside the map counts as solid; rows above the surface stay empty.
## Each cell's column triple is summed once, then a neighbour count is three of those.
static func smooth(grid: PackedByteArray) -> PackedByteArray:
	var w := MineGrid.GRID_WIDTH
	var h := MineGrid.GRID_HEIGHT
	var triple := PackedByteArray()
	triple.resize(w * h)
	for x in range(w):
		var base := x * h
		for y in range(h):
			var above := grid[base + y - 1] if y > 0 else 1
			var below := grid[base + y + 1] if y < h - 1 else 1
			triple[base + y] = above + grid[base + y] + below
	var out := PackedByteArray()
	out.resize(w * h)
	for x in range(w):
		var base := x * h
		for y in range(MineGrid.SURFACE_ROWS, h):
			var left := triple[base - h + y] if x > 0 else 3
			var right := triple[base + h + y] if x < w - 1 else 3
			var cell := grid[base + y]
			var walls := left + triple[base + y] + right - cell
			out[base + y] = 1 if walls >= (4 if cell == 1 else 5) else 0
	return out

func _flatten(grid: Array) -> PackedByteArray:
	var flat := PackedByteArray()
	flat.resize(MineGrid.GRID_WIDTH * MineGrid.GRID_HEIGHT)
	for x in range(MineGrid.GRID_WIDTH):
		for y in range(MineGrid.GRID_HEIGHT):
			flat[x * MineGrid.GRID_HEIGHT + y] = 1 if grid[x][y] else 0
	return flat

func _unflatten(flat: PackedByteArray) -> Array:
	var grid := _make_grid(false)
	for x in range(MineGrid.GRID_WIDTH):
		for y in range(MineGrid.GRID_HEIGHT):
			grid[x][y] = flat[x * MineGrid.GRID_HEIGHT + y] == 1
	return grid

## _reinforce_boundaries on a flat grid.
func _reinforce_flat(flat: PackedByteArray) -> void:
	var w := MineGrid.GRID_WIDTH
	var h := MineGrid.GRID_HEIGHT
	for x in range(w):
		flat[x * h + h - 1] = 1
	for y in range(h):
		flat[y] = 1
		flat[(w - 1) * h + y] = 1

## Opens the shaft from just below the crust, fills its last
## SHAFT_COLLAPSE_ROWS rows with rock, and keeps both clear of pickups, gas
## and crumbling.
func _carve_old_mine() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = _layout.mine_seed + 51
	var stone := layer_rows(2)
	_layout.shaft_end_row = rng.randi_range(stone.x, stone.x + (stone.y - stone.x) / 2)
	var open := shaft_open_rows(_layout.shaft_end_row)
	var left := shaft_column() - MineGrid.SHAFT_WIDTH / 2
	for x in range(left, left + MineGrid.SHAFT_WIDTH):
		for y in range(open.x, _layout.shaft_end_row + 1):
			var cell := Vector2i(x, y)
			_solid[x][y] = y > open.y
			_layout.room_cells[cell] = true
			if y > open.y:
				_layout.reserved_floors[cell] = true
	# Timber up both sides of the open shaft.
	for y in range(open.x, open.y + 1):
		_layout.decor[Vector2i(left, y)] = MineLayout.Decor.FRAME
		_layout.decor[Vector2i(left + MineGrid.SHAFT_WIDTH - 1, y)] = MineLayout.Decor.FRAME
	# The old ladder, in pieces, some missing.
	_layout.old_ladder_rows.clear()
	for row in range(open.x, open.y + 1, MineGrid.OLD_LADDER_PIECE_ROWS):
		if rng.randf() >= MineGrid.OLD_LADDER_MISSING_CHANCE:
			_layout.old_ladder_rows.append(row)
	_carve_drifts(rng)
	_place_lift(rng)

## One gallery per worked layer (Topsoil, Clay, Stone) off the shaft: a
## two-tile tunnel on a random side at a random row, posted every
## DRIFT_POST_SPACING tiles, floored with planks where it crosses a cave.
## A layer the shaft's open part does not reach gets none.
func _carve_drifts(rng: RandomNumberGenerator) -> void:
	_layout.drifts.clear()
	var open := shaft_open_rows(_layout.shaft_end_row)
	for layer in range(3):
		var rows := layer_rows(layer)
		var lo: int = maxi(rows.x, open.x + 3)
		var hi: int = mini(rows.y - 3, open.y - 3)
		if lo > hi:
			continue
		var row := rng.randi_range(lo, hi)
		var side := rng.randi_range(0, 1) * 2 - 1
		var length := rng.randi_range(MineGrid.DRIFT_MIN_LENGTH, MineGrid.DRIFT_MAX_LENGTH)
		var x0 := shaft_column() + side * (MineGrid.SHAFT_WIDTH / 2 + 1)
		var drift := Drift.new(layer, side, row, x0, x0 + side * (length - 1), "miner" if layer == 2 else "camp")
		_layout.drifts.append(drift)
		# Step from the shaft's edge onto the drift's floor.
		var landing := Vector2i(shaft_column() + side, row + 1)
		_layout.plank_cells[landing] = true
		_solid[landing.x][landing.y] = true
		_layout.room_cells[landing] = true
		_layout.reserved_floors[landing] = true
		for i in range(length):
			var x := x0 + side * i
			for y in [row - 1, row]:
				_solid[x][y] = false
				_layout.room_cells[Vector2i(x, y)] = true
			var floor_cell := Vector2i(x, row + 1)
			if not _solid[x][row + 1]:
				_solid[x][row + 1] = true
				_layout.plank_cells[floor_cell] = true
			_layout.room_cells[floor_cell] = true
			_layout.reserved_floors[floor_cell] = true
			if i > 0 and i % MineGrid.DRIFT_POST_SPACING == 0:
				_layout.decor[Vector2i(x, row)] = MineLayout.Decor.POST
				_layout.decor[Vector2i(x, row - 1)] = MineLayout.Decor.POST
		if layer >= 1:
			_collapse_drift(drift, length, rng)
		if drift.end_kind == "camp":
			var end_cell := Vector2i(drift.x1, row)
			var camp := EventRoom.new("camp", end_cell, Rect2i(end_cell - Vector2i(0, 1), Vector2i(1, 2)))
			camp.at_drift_end = true
			_layout.event_rooms.append(camp)

## The old cage: the lift stands in the shaft's edge column near the bottom
## of Clay, on a plank floor, so the ladder column stays open (the shaft's cells are
## already kept clear of pickups and gas). It keeps clear
## of the Clay gallery's mouth. (Clay is quiet: repairing it is silent.)
func _place_lift(rng: RandomNumberGenerator) -> void:
	var side := rng.randi_range(0, 1) * 2 - 1
	var row := mini(layer_rows(1).y - MineGrid.LIFT_ROWS_FROM_CLAY_BOTTOM, shaft_open_rows(_layout.shaft_end_row).y - 2)
	for d in _layout.drifts:
		if d.layer == 1 and absi(d.row - row) <= 3:
			row = d.row - 4
	var cell := Vector2i(shaft_column() + side, row)
	var floor_cell := cell + Vector2i.DOWN
	_solid[floor_cell.x][floor_cell.y] = true
	_layout.plank_cells[floor_cell] = true
	_layout.reserved_floors[floor_cell] = true
	var lift := EventRoom.new("lift", cell, Rect2i(cell - Vector2i(0, 1), Vector2i(1, 2)))
	lift.in_shaft = true
	_layout.event_rooms.append(lift)

## Fills a DRIFT_COLLAPSE_MIN..MAX long stretch of both rows with rock,
## leaving DRIFT_END_CLEAR open tiles at each end so neither the shaft mouth
## nor the camp / miner at the far end is swallowed.
func _collapse_drift(drift: Drift, length: int, rng: RandomNumberGenerator) -> void:
	var size := rng.randi_range(MineGrid.DRIFT_COLLAPSE_MIN, MineGrid.DRIFT_COLLAPSE_MAX)
	var start := rng.randi_range(MineGrid.DRIFT_END_CLEAR, length - MineGrid.DRIFT_END_CLEAR - size)
	var first_x: int = drift.x0 + drift.side * start
	var last_x: int = drift.x0 + drift.side * (start + size - 1)
	for x in range(mini(first_x, last_x), maxi(first_x, last_x) + 1):
		for y in [drift.row - 1, drift.row]:
			_solid[x][y] = true
			_layout.debris_cells[Vector2i(x, y)] = true
			_layout.reserved_floors[Vector2i(x, y)] = true
	drift.collapse = Rect2i(mini(first_x, last_x), drift.row - 1, size, 2)

## Clears a ROOM_SIZE chamber per EVENT_ROOMS entry, on a solid floor,
## spaced apart. A room that finds no spot is skipped.
func _carve_event_rooms() -> void:
	var rng := _rng
	for room in MineGrid.EVENT_ROOMS:
		var layer: int = room.layers[rng.randi_range(0, room.layers.size() - 1)]
		var rows := layer_rows(layer)
		if room.get("bottom", false):
			rows.x = rows.y - MineGrid.ROOM_SIZE.y - 12
		for i in range(MineGrid.ROOM_PLACE_TRIES):
			var top_left := Vector2i(rng.randi_range(2, MineGrid.GRID_WIDTH - 2 - MineGrid.ROOM_SIZE.x),
				rng.randi_range(max(rows.x, MineGrid.SURFACE_ROWS + 2), rows.y - MineGrid.ROOM_SIZE.y - 1))
			var center := top_left + Vector2i(MineGrid.ROOM_SIZE.x / 2, MineGrid.ROOM_SIZE.y - 1)
			var room_box := Rect2i(top_left, MineGrid.ROOM_SIZE).grow(1)
			if old_mine_rects(_layout.drifts, _layout.shaft_end_row).any(func(r): return room_box.intersects(r)):
				continue # rooms keep out of the old mine
			if _layout.event_rooms.any(func(r): return Vector2(r.cell - center).length() < MineGrid.ROOM_MIN_SPACING_TILES):
				continue
			for x in range(top_left.x, top_left.x + MineGrid.ROOM_SIZE.x):
				for y in range(top_left.y, top_left.y + MineGrid.ROOM_SIZE.y + 1):
					_solid[x][y] = y == top_left.y + MineGrid.ROOM_SIZE.y # open room, solid floor row
					_layout.room_cells[Vector2i(x, y)] = true
					if _solid[x][y]:
						_layout.reserved_floors[Vector2i(x, y)] = true
			var entry := EventRoom.new(room.kind, center, Rect2i(top_left, MineGrid.ROOM_SIZE))
			if room.kind == "vault":
				entry.door = _seal_vault(top_left)
			_layout.event_rooms.append(entry)
			break

## Rings the room at top_left in bedrock, leaving a 2-tile doorway on its
## left at floor level (Main puts the vault door there). Returns the
## doorway's lower cell.
func _seal_vault(top_left: Vector2i) -> Vector2i:
	var left := top_left.x - 1
	var right := top_left.x + MineGrid.ROOM_SIZE.x
	var top := top_left.y - 1
	var bottom := top_left.y + MineGrid.ROOM_SIZE.y
	var door := Vector2i(left, bottom - 1)
	for x in range(left, right + 1):
		for y in range(top, bottom + 1):
			if x != left and x != right and y != top and y != bottom:
				continue
			var cell := Vector2i(x, y)
			_layout.room_cells[cell] = true
			if cell == door or cell == door + Vector2i.UP:
				_solid[x][y] = false
			else:
				_solid[x][y] = true
				_layout.vault_cells[cell] = true
	return door

func _place_gas_pockets() -> void:
	for layer in range(MineGrid.LAYERS.size()):
		if not MineGrid.LAYERS[layer].gas:
			continue
		var rows := layer_rows(layer)
		var placed := 0
		var tries := 0
		while placed < MineGrid.GAS_POCKET_COUNT and tries < MineGrid.GAS_POCKET_COUNT * 20:
			tries += 1
			var cell := Vector2i(_rng.randi_range(1, MineGrid.GRID_WIDTH - 2), _rng.randi_range(rows.x, rows.y))
			if _layout.room_cells.has(cell) or _layout.kind_at(cell) != MineLayout.Kind.ROCK:
				continue
			_layout.kinds[cell.x * MineGrid.GRID_HEIGHT + cell.y] = MineLayout.Kind.GAS
			placed += 1

## Open cells with solid rock directly beneath them - valid places to stand
## a pickup on a cave floor.
func _find_floor_cells() -> Array:
	var floor_cells: Array = []
	for x in range(1, MineGrid.GRID_WIDTH - 1):
		for y in range(MineGrid.SURFACE_ROWS + 1, MineGrid.GRID_HEIGHT - 1):
			if not _solid[x][y] and _solid[x][y + 1]:
				floor_cells.append(Vector2i(x, y))
	return floor_cells

## Fuel pickups take the front slice of the (already shuffled) floor cells,
## ore the next, so the two never land on the same cell. Ore is worth more the
## deeper it lies.
func _scatter_pickups(floor_cells: Array) -> void:
	var fuel_count: int = min(MineGrid.FUEL_DEPOSIT_COUNT, floor_cells.size())
	for i in range(fuel_count):
		var cell: Vector2i = floor_cells[i]
		_layout.reserved_floors[cell + Vector2i.DOWN] = true
		_layout.fuel_cells.append(cell)
	var start: int = min(MineGrid.FUEL_DEPOSIT_COUNT, floor_cells.size())
	var end: int = min(start + MineGrid.ORE_DEPOSIT_COUNT, floor_cells.size())
	for i in range(start, end):
		var cell: Vector2i = floor_cells[i]
		_layout.reserved_floors[cell + Vector2i.DOWN] = true
		_layout.ore_cells.append({"cell": cell, "value": MineGrid.LAYERS[layer_index_for_row(cell.y)].ore})

func _pick_lost_miner_cell() -> void:
	for d in _layout.drifts:
		if d.end_kind == "miner": # the Stone gallery's far end
			_layout.lost_miner_cell = Vector2i(d.x1, d.row)
			return
	var first := quiet_floor_row() - MineGrid.LOST_MINER_ROWS_ABOVE_QUIET_FLOOR
	var last := quiet_floor_row() + MineGrid.LOST_MINER_ROWS_BELOW_QUIET_FLOOR
	_layout.lost_miner_cell = Vector2i(-1, -1)
	for i in range(_layout.spare_floor_cells.size()):
		var cell: Vector2i = _layout.spare_floor_cells[i]
		if cell.y >= first and cell.y <= last:
			_layout.spare_floor_cells.remove_at(i)
			_layout.reserved_floors[cell + Vector2i.DOWN] = true
			_layout.lost_miner_cell = cell
			return

## Lights Topsoil and Clay (see the TORCH_ constants). Cave torches take free
## cells out of the spare pool, so spawns cannot stand on one, and keep their
## floors from crumbling like a pickup's.
func _place_torches() -> void:
	_layout.torches.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = _layout.mine_seed + 52
	var clay_bottom := layer_rows(1).y
	var open := shaft_open_rows(_layout.shaft_end_row)
	var lift_cells: Array = _layout.event_rooms.filter(func(r): return r.kind == "lift").map(func(r): return r.cell)
	var side := -1
	for y in range(open.x + MineGrid.TORCH_SHAFT_FIRST_ROW_OFFSET, mini(open.y, clay_bottom) + 1, MineGrid.TORCH_SHAFT_SPACING):
		var cell := Vector2i(shaft_column() + side, y)
		if _layout.is_solid(cell) or lift_cells.has(cell):
			continue
		_layout.torches.append(TorchSite.new(cell, "shaft"))
		side = -side
	var candidates: Array = _layout.spare_floor_cells.filter(func(c): return c.y <= clay_bottom)
	var placed: Array[Vector2i] = []
	for i in range(MineGrid.TORCH_CAVE_TRIES):
		if placed.size() >= MineGrid.TORCH_CAVE_COUNT or candidates.is_empty():
			break
		var cell: Vector2i = candidates[rng.randi_range(0, candidates.size() - 1)]
		if placed.any(func(p): return Vector2(p).distance_to(Vector2(cell)) < MineGrid.TORCH_CAVE_SPACING_TILES):
			continue
		placed.append(cell)
		_layout.spare_floor_cells.erase(cell)
		_layout.reserved_floors[cell + Vector2i.DOWN] = true
		_layout.torches.append(TorchSite.new(cell, "cave"))

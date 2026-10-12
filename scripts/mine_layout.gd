extends RefCounted
class_name MineLayout

## What MineGenerator decides about one seed, as plain data (issue #74): no
## nodes, no tile map. MineGrid applies it (set_cell, pickups, torches) and
## copies it into the fields the rest of the game reads.

enum Kind { EMPTY, ROCK, BEDROCK, VAULT, PLANK, DEBRIS, GAS }
enum Decor { FRAME, POST }

var mine_seed: int = 0
## One Kind per cell, indexed x * GRID_HEIGHT + y.
var kinds := PackedByteArray()
## Decor-layer cells (shaft timber, drift posts): cell -> Decor.
var decor: Dictionary = {}
var drifts: Array[Drift] = []
var event_rooms: Array[EventRoom] = []
var torches: Array[TorchSite] = []
## Sets of cells (cell -> true), as MineGrid keeps them.
var room_cells: Dictionary = {}
var reserved_floors: Dictionary = {}
var plank_cells: Dictionary = {}
var debris_cells: Dictionary = {}
var vault_cells: Dictionary = {}
var fuel_cells: Array = []
## [{"cell": Vector2i, "value": int}, ...]
var ore_cells: Array = []
var spare_floor_cells: Array = []
var lost_miner_cell := Vector2i(-1, -1)
var shaft_end_row: int = -1
var old_ladder_rows: Array = []

func _init() -> void:
	kinds.resize(MineGrid.GRID_WIDTH * MineGrid.GRID_HEIGHT)
	kinds.fill(Kind.EMPTY)

func kind_at(cell: Vector2i) -> int:
	if cell.x < 0 or cell.x >= MineGrid.GRID_WIDTH or cell.y < 0 or cell.y >= MineGrid.GRID_HEIGHT:
		return Kind.EMPTY
	return kinds[cell.x * MineGrid.GRID_HEIGHT + cell.y]

func is_solid(cell: Vector2i) -> bool:
	return kind_at(cell) != Kind.EMPTY

func shaft_column() -> int:
	return MineGenerator.shaft_column()

func shaft_open_rows() -> Vector2i:
	return MineGenerator.shaft_open_rows(shaft_end_row)

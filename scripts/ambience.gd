extends Node
class_name Ambience

## Sparse ambient sound for slow exploration (M87): an occasional water drip below the crust and,
## in the old workings, an occasional timber creak. Quiet, with long silences between. It keeps its
## own random generator, so it never touches the mine's seeded numbers.

const DRIP_MIN := 6.0
const DRIP_MAX := 14.0
const CREAK_MIN := 15.0
const CREAK_MAX := 30.0
const DRIP_DB := -18.0
const CREAK_DB := -14.0
## How far either sound's volume may drift, in dB, so no two sound alike.
const VOLUME_DRIFT_DB := 3.0
## The workings are checked this often, not every frame.
const CHECK_SECONDS := 0.5

var mine: MineGrid
var player: Player
var rng := RandomNumberGenerator.new()

var _drip_left: float
var _creak_left: float
var _below_crust := false
var _in_workings := false
var _check_left := 0.0

func _init() -> void:
	rng.randomize()
	schedule()

## Draws the time to each sound's first occurrence.
func schedule() -> void:
	_drip_left = rng.randf_range(DRIP_MIN, DRIP_MAX)
	_creak_left = rng.randf_range(CREAK_MIN, CREAK_MAX)

func _process(delta: float) -> void:
	if mine == null or player == null:
		return
	_check_left -= delta
	if _check_left <= 0.0:
		_check_left = CHECK_SECONDS
		var cell := mine.world_to_cell(player.global_position)
		_below_crust = cell.y > MineGrid.SURFACE_ROWS
		_in_workings = _below_crust and in_workings(mine, cell)
	var sound := advance(delta, _below_crust, _in_workings)
	if sound != "":
		Sfx.play(sound, volume_db(sound) + rng.randf_range(-VOLUME_DRIFT_DB, VOLUME_DRIFT_DB))

## Counts down `delta` seconds and returns the sound due ("drip", "creak" or ""). Drips count down
## only below the crust and creaks only in the workings, so nothing is saved up while away.
func advance(delta: float, below_crust: bool, in_the_workings: bool) -> String:
	var due := ""
	if below_crust:
		_drip_left -= delta
		if _drip_left <= 0.0:
			_drip_left = rng.randf_range(DRIP_MIN, DRIP_MAX)
			due = "drip"
	if in_the_workings:
		_creak_left -= delta
		if _creak_left <= 0.0:
			_creak_left = rng.randf_range(CREAK_MIN, CREAK_MAX)
			if due == "":
				due = "creak"
	return due

static func volume_db(sound: String) -> float:
	return DRIP_DB if sound == "drip" else CREAK_DB

## Whether `cell` is in the old workings: on a spine (its two open rows) or within a tile of a
## connector's passage.
static func in_workings(grid: MineGrid, cell: Vector2i) -> bool:
	for d in grid.drifts:
		if cell.x >= mini(d.x0, d.x1) and cell.x <= maxi(d.x0, d.x1) and cell.y >= d.row - 1 and cell.y <= d.row:
			return true
	for c in grid.connectors:
		for passage_cell in c.cells:
			if absi(passage_cell.x - cell.x) <= 1 and absi(passage_cell.y - cell.y) <= 1:
				return true
	return false

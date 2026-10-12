extends RefCounted
class_name RunContext

## What a mine event may reach in the run: the one written-down interface
## between event nodes (camp, lift, heart, outpost, ...) and Main. Main
## builds it once; an event that needs more adds it here, so the list of
## what events depend on stays in this file.
var player: Player
var hud: HUD
var noise_meter: NoiseMeter
var mine: MineGrid

var _take_heart: Callable
var _ride_to_surface: Callable
var _read_journal_page: Callable
var _add_lamps: Callable
var _nest_destroyed: Callable

## Main wires the actions it owns; refs are set directly on the fields.
func bind(take_heart: Callable, ride_to_surface: Callable, read_journal_page: Callable,
		add_lamps: Callable, nest_destroyed: Callable) -> void:
	_take_heart = take_heart
	_ride_to_surface = ride_to_surface
	_read_journal_page = read_journal_page
	_add_lamps = add_lamps
	_nest_destroyed = nest_destroyed

func take_heart() -> void:
	_take_heart.call()

func ride_to_surface(world_x: float) -> void:
	_ride_to_surface.call(world_x)

func read_journal_page() -> String:
	return _read_journal_page.call()

func add_lamps(count: int) -> void:
	_add_lamps.call(count)

func nest_destroyed() -> void:
	_nest_destroyed.call()

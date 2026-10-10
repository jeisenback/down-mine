extends Node2D
class_name Camp

## An abandoned miners' camp (milestone 33, a mine event). Searching it
## (E) once gives light, ore and the next page of the old crew's journal,
## and lights the camp lantern - a placed light like a Lamp, so it burns
## out and draws Snuffers. Once out, it can be relit from the player's
## own lantern.
const SEARCH_FUEL := 25.0
const RELIGHT_FUEL := 15.0
const LampScene := preload("res://scenes/Lamp.tscn")

var layer: int = 0
var searched: bool = false
var _lamp: Lamp = null

func _ready() -> void:
	add_to_group("mine_events")

func prompt(main: Node) -> String:
	if not searched:
		return "E: search the camp"
	if not _lantern_lit():
		if main.player.light.fuel <= RELIGHT_FUEL:
			return "Relighting needs more light"
		return "E: relight the camp lantern"
	return ""

func use(main: Node) -> void:
	if not searched:
		searched = true
		main.player.light.add_fuel(SEARCH_FUEL)
		main.player.currency += MineGrid.LAYERS[layer].camp_ore # deeper camps hold more
		main.hud.show_message(main.read_journal_page())
		Sfx.play("ore")
		_light_lantern()
	elif not _lantern_lit() and main.player.light.fuel > RELIGHT_FUEL:
		main.player.light.fuel -= RELIGHT_FUEL
		Sfx.play("fuel")
		_light_lantern()

func _lantern_lit() -> bool:
	return is_instance_valid(_lamp) and not _lamp.is_queued_for_deletion()

func _light_lantern() -> void:
	_lamp = LampScene.instantiate()
	_lamp.position = Vector2(10, 1)
	add_child(_lamp)

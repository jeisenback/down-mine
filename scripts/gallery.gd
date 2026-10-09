extends Node2D
class_name Gallery

## A collapsing gallery (milestone 36, a mine event): a room lined with
## rich ore under a failing ceiling. Stepping in starts a countdown; when
## it ends the room fills with rock - light doesn't stop it, supports do.
## Anyone still inside is buried: hurt, and left to dig out. Buried ore
## is lost.
const ORE_COUNT := 4
const ORE_MULTIPLIER := 2
const COLLAPSE_SECONDS := 12.0
const COLLAPSE_NOISE := 30.0
const BURY_DAMAGE := 1
const OrePickupScene := preload("res://scenes/OrePickup.tscn")

var main: Node
var rect: Rect2i
var collapsed: bool = false
var _time_left: float = -1.0 # below 0 until the player steps in
var _ore: Array[OrePickup] = []

func _ready() -> void:
	var mine: MineGrid = main.mine
	var floor_row := rect.end.y - 1
	var value: int = mine.ore_value_at(global_position) * ORE_MULTIPLIER
	for i in range(ORE_COUNT):
		var pickup: OrePickup = OrePickupScene.instantiate()
		pickup.value = value
		pickup.global_position = mine.cell_to_world(Vector2i(rect.position.x + 1 + i * 2, floor_row))
		mine.add_child.call_deferred(pickup)
		_ore.append(pickup)

func _process(delta: float) -> void:
	if collapsed:
		return
	if _time_left < 0.0:
		if rect.has_point(main.mine.world_to_cell(main.player.global_position)):
			_time_left = COLLAPSE_SECONDS
			Sfx.play("collapse", -12.0)
		return
	_time_left -= delta
	main.hud.show_message("The gallery ceiling is failing: %ds" % ceili(_time_left))
	if _time_left <= 0.0:
		collapse()

func collapse() -> void:
	collapsed = true
	var mine: MineGrid = main.mine
	var player_cell := mine.world_to_cell(main.player.global_position)
	var filled: Dictionary = {}
	for x in range(rect.position.x, rect.end.x):
		for y in range(rect.position.y, rect.end.y):
			var cell := Vector2i(x, y)
			if cell == player_cell or cell == player_cell + Vector2i.UP:
				continue # buried, not crushed inside the rock
			if mine.is_solid(cell) or Support.protects(get_tree(), mine.cell_to_world(cell)):
				continue
			mine.fill_cell(cell)
			filled[cell] = true
	for pickup in _ore:
		if is_instance_valid(pickup) and filled.has(mine.world_to_cell(pickup.global_position)):
			pickup.queue_free()
	if rect.has_point(player_cell):
		main.player.take_hit(BURY_DAMAGE, "burial")
		main.hud.show_message("Buried! Dig out.")
	main.noise_meter.add_noise(COLLAPSE_NOISE)
	Sfx.play("collapse")

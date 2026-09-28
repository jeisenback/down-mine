extends Node2D
class_name Lamp

## A placed light (milestone 20) - the PRD's "placed lights": set down
## to light the route home, burns out on its own, and is what Snuffers
## hunt. Being in the mine_lights group (via MineLight) also slows rope
## decay nearby.

@onready var light: MineLight = $MineLight

func _ready() -> void:
	add_to_group("lamps")
	light.add_to_group("snuffable")
	light.fuel_depleted.connect(queue_free) # an empty MineLight still glows at radius_min

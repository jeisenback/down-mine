extends Node2D
class_name StrandedSign

## Milestone 25, the PRD's in-mine signs leading to a stranded miner: a
## scrap of their shirt with a faint glow in its colour. Veterans leave
## clearer ones (a brighter, wider glow; Main also places more of them).

const VETERAN_RADIUS := 34.0
const VETERAN_ENERGY := 0.9

var color: Color = Color(1, 1, 1)
var veteran: bool = false

@onready var light: MineLight = $MineLight

func _ready() -> void:
	$Scrap.color = color
	$MineLight/PointLight2D.color = color.lightened(0.3)
	if veteran:
		light.radius_max = VETERAN_RADIUS
		light.radius_min = VETERAN_RADIUS
		light.energy_max = VETERAN_ENERGY
		light.energy_min = VETERAN_ENERGY

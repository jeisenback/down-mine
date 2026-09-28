extends Node2D
class_name RunBase

## Marker + light source (milestone 5), and the Burrower's target
## (milestone 11): when its health runs out the base falls and the run
## fails. Repair is a later milestone.
signal fell
signal health_changed(health: int, max_health: int)

const MAX_HEALTH := 3

@onready var light: MineLight = $MineLight

var health: int = MAX_HEALTH

func take_hit(amount: int) -> void:
	if health <= 0:
		return
	health = max(0, health - amount)
	health_changed.emit(health, MAX_HEALTH)
	if health == 0:
		fell.emit()

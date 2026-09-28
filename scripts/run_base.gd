extends Node2D
class_name RunBase

## Marker + light source (milestone 5), and the Burrower's target
## (milestone 11): when its health runs out the base falls and the run
## fails. Repairable (milestone 17): see tick_repair().
signal fell
signal health_changed(health: int, max_health: int)

const MAX_HEALTH := 3
# Repair: 1 health per REPAIR_TIME seconds of holding the repair key at
# the base, paid from the run's ore when each point completes, and loud
# (PRD: building and repairing raise noise). Repair crew scale cost/speed.
const REPAIR_TIME := 3.0
const REPAIR_ORE_COST := 10
const REPAIR_NOISE := 20.0
# Fortifying (B at the base) reinforces rock within this many tiles, per
# tile paid from run ore (repair crew discount it too) and noisy. Each
# press does one batch of the nearest tiles: a base planted in solid rock
# has ~50 in range, and doing them all at once filled the noise meter.
const FORTIFY_RADIUS_TILES := 5
const FORTIFY_BATCH_TILES := 12
const WALL_ORE_COST := 2
const WALL_NOISE := 2.0

@onready var light: MineLight = $MineLight

var health: int = MAX_HEALTH
var repair_cost_multiplier: float = 1.0
var repair_speed_multiplier: float = 1.0
## 0..1 toward the next point of health.
var repair_progress: float = 0.0

func needs_repair() -> bool:
	return health > 0 and health < MAX_HEALTH

func repair_cost() -> int:
	return roundi(REPAIR_ORE_COST * repair_cost_multiplier)

func wall_cost() -> int:
	return max(1, roundi(WALL_ORE_COST * repair_cost_multiplier))

## Advances repair while the player holds the key here. Returns true when
## a point of health completes - the caller pays repair_cost() and makes
## the noise. Won't advance if the player can't afford the point.
func tick_repair(delta: float, available_ore: int) -> bool:
	if not needs_repair() or available_ore < repair_cost():
		return false
	repair_progress += delta * repair_speed_multiplier / REPAIR_TIME
	if repair_progress < 1.0:
		return false
	repair_progress = 0.0
	health += 1
	health_changed.emit(health, MAX_HEALTH)
	return true

func take_hit(amount: int) -> void:
	if health <= 0:
		return
	health = max(0, health - amount)
	health_changed.emit(health, MAX_HEALTH)
	if health == 0:
		fell.emit()

extends Node2D
class_name RunBase

## Marker + light source (milestone 5), and the Burrower's target
## (milestone 11): when its health runs out the base falls and the run
## fails. Repairable (milestone 17): see tick_repair().
signal fell
signal health_changed(health: int, max_health: int)

## The Camp's max health; later tiers raise it (see max_health()).
const MAX_HEALTH := 3
# Tiers (milestone 56): the base grows Camp, Outpost, Fort, bought with ore at
# the base (Main.grow_base). Each raises max health, the base light's fuel
# capacity and how long a reinforced wall holds a Burrower; the Outpost brings
# the beacon and the Fort the bell.
const TIER_NAMES := ["Camp", "Outpost", "Fort"]
const TIER_COSTS := [0, 70, 120] # to reach this tier
const TIER_MAX_HEALTH := [3, 4, 5]
const TIER_LIGHT_FUEL := [200.0, 260.0, 340.0]
const TIER_WALL_CHEW_SECONDS := [2.5, 3.5, 5.0]
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
# Base buildings (milestone 32), now part of the tiers (milestone 56): the
# Outpost brings the beacon (the base light reaches further, a bigger refuge,
# but burns faster), the Fort the alarm bell (warns when noise nears the
# Burrower threshold, and tells you each wave's size).
const BEACON_RADIUS_MULTIPLIER := 1.5
const BEACON_BURN_MULTIPLIER := 1.5
const BUILD_NOISE := 10.0

@onready var light: MineLight = $MineLight

var health: int = MAX_HEALTH
var tier: int = 0
var has_beacon: bool = false
var has_bell: bool = false
var repair_cost_multiplier: float = 1.0
var repair_speed_multiplier: float = 1.0
## 0..1 toward the next point of health.
var repair_progress: float = 0.0

func _ready() -> void:
	light.add_to_group("snuffable") # Snuffers hunt the base light too

func build_beacon() -> void:
	has_beacon = true
	light.radius_max *= BEACON_RADIUS_MULTIPLIER
	light.radius_min *= BEACON_RADIUS_MULTIPLIER
	light.burn_rate *= BEACON_BURN_MULTIPLIER
	$Beacon.visible = true

func build_bell() -> void:
	has_bell = true
	$Bell.visible = true

## The drawn bell swings harder while it warns of noise (milestone 53).
func ring_bell(ringing: bool) -> void:
	$Bell.art.pose = 1.0 if ringing else 0.0

func max_health() -> int:
	return TIER_MAX_HEALTH[tier]

func tier_name() -> String:
	return TIER_NAMES[tier]

## Ore for the next tier, or -1 at the Fort.
func next_tier_cost() -> int:
	return TIER_COSTS[tier + 1] if tier + 1 < TIER_COSTS.size() else -1

## How long a reinforced wall holds a Burrower at this tier.
func wall_chew_time() -> float:
	return TIER_WALL_CHEW_SECONDS[tier]

## Raises the base one tier (the caller has taken the ore): full health at the
## new max, a full light at the new capacity, and the beacon at the Outpost or
## the bell at the Fort. False at the Fort or when the base has fallen.
func grow() -> bool:
	if health <= 0 or next_tier_cost() < 0:
		return false
	tier += 1
	health = max_health()
	health_changed.emit(health, max_health())
	light.max_fuel = TIER_LIGHT_FUEL[tier]
	light.fuel = light.max_fuel
	if tier == 1:
		build_beacon()
	elif tier == 2:
		build_bell()
	_show_tier_props()
	return true

## Shows the props for this tier: the Outpost's palisade, which the Fort's
## rampart replaces. (The beacon and bell show themselves when built.)
func _show_tier_props() -> void:
	$Palisade.visible = tier == 1
	$Rampart.visible = tier == 2

func needs_repair() -> bool:
	return health > 0 and health < max_health()

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
	health_changed.emit(health, max_health())
	return true

## Adds health up to the tier's max (a crew Mender). A fallen base stays down.
func heal(amount: int) -> void:
	if health <= 0:
		return
	health = min(max_health(), health + amount)
	health_changed.emit(health, max_health())

func take_hit(amount: int) -> void:
	if health <= 0:
		return
	health = max(0, health - amount)
	Sfx.play("alarm")
	health_changed.emit(health, max_health())
	if health == 0:
		fell.emit()

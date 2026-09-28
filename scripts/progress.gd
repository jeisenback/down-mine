extends RefCounted
class_name Progress

## Everything that survives between runs: the ore bank and hub upgrade
## levels. Per the PRD, hub progress is never lost - only extraction adds
## ore, and nothing here is taken away by a failed run.

const SAVE_PATH := "user://save.cfg"

# Hub upgrades. cost_per_level scales linearly: level n costs n * cost.
const UPGRADES := {
	"lantern": {"name": "Lantern tank", "effect": "+15s light", "cost_per_level": 30, "max_level": 3},
	"hard_hat": {"name": "Hard hat", "effect": "+1 health", "cost_per_level": 50, "max_level": 2},
}
const UPGRADE_ORDER := ["lantern", "hard_hat"] # hub key 1, key 2

const LANTERN_FUEL_PER_LEVEL := 15.0
const HARD_HAT_HEALTH_PER_LEVEL := 1

var banked_ore: int = 0
var levels: Dictionary = {}

static func load_saved() -> Progress:
	var progress := Progress.new()
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) == OK:
		progress.banked_ore = int(config.get_value("bank", "ore", 0))
		for id in UPGRADES:
			progress.levels[id] = int(config.get_value("upgrades", id, 0))
	return progress

func save() -> void:
	var config := ConfigFile.new()
	config.set_value("bank", "ore", banked_ore)
	for id in UPGRADES:
		config.set_value("upgrades", id, level(id))
	config.save(SAVE_PATH)

func level(id: String) -> int:
	return levels.get(id, 0)

## Cost of the next level, or -1 if already maxed.
func next_cost(id: String) -> int:
	var upgrade: Dictionary = UPGRADES[id]
	if level(id) >= upgrade.max_level:
		return -1
	return (level(id) + 1) * upgrade.cost_per_level

func try_buy(id: String) -> bool:
	var cost := next_cost(id)
	if cost < 0 or banked_ore < cost:
		return false
	banked_ore -= cost
	levels[id] = level(id) + 1
	save()
	return true

func apply_to(player: Player) -> void:
	player.light.max_fuel += level("lantern") * LANTERN_FUEL_PER_LEVEL
	player.light.fuel = player.light.max_fuel
	player.health += level("hard_hat") * HARD_HAT_HEALTH_PER_LEVEL

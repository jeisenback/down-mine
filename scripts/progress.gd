extends RefCounted
class_name Progress

## Everything that survives between runs: the ore bank, hub upgrade
## levels, the NPC roster, and stranded NPCs. Per the PRD, hub progress is never lost -
## only extraction adds ore, and nothing here is taken away by a failed run.

const SAVE_PATH := "user://save.cfg"

# Hub upgrades. cost_per_level scales linearly: level n costs n * cost.
const UPGRADES := {
	"lantern": {"name": "Lantern tank", "effect": "+15s light", "cost_per_level": 30, "max_level": 3},
	"hard_hat": {"name": "Hard hat", "effect": "+1 health", "cost_per_level": 50, "max_level": 2},
}
const UPGRADE_ORDER := ["lantern", "hard_hat"] # hub key 1, key 2

const LANTERN_FUEL_PER_LEVEL := 15.0
const HARD_HAT_HEALTH_PER_LEVEL := 1

# NPC types (PRD: light, repair, noise, traversal). Only light exists so
# far. A crew member's type improves its system while on the crew.
const NPC_TYPES := {
	"light": {"label": "Light", "effect": "lantern burns 20% slower, reaches 15% further"},
}
const LIGHT_CREW_BURN_MULTIPLIER := 0.8
const LIGHT_CREW_RADIUS_MULTIPLIER := 1.15
# PRD default: 1 starting slot, 4 max via hub upgrades (later). Until
# there is a crew picker, the crew is simply the first N rescued.
const CREW_SLOTS := 1

# Stranded NPCs drift one layer deeper for every run that ends without
# rescuing them; drifting past the last layer kills them (PRD: death only
# through neglect). Matches MineGrid's depth bands.
const LAYER_NAMES := ["Topsoil", "Stone", "Deep rock"]

var banked_ore: int = 0
var levels: Dictionary = {}
## Rescued NPCs, oldest first: [{"name": String, "type": String}, ...]
var roster: Array = []
## Stranded NPCs: [{"name": String, "type": String, "layer": int}, ...]
var stranded: Array = []

static func load_saved() -> Progress:
	var progress := Progress.new()
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) == OK:
		progress.banked_ore = int(config.get_value("bank", "ore", 0))
		for id in UPGRADES:
			progress.levels[id] = int(config.get_value("upgrades", id, 0))
		progress.roster = config.get_value("npcs", "roster", [])
		progress.stranded = config.get_value("npcs", "stranded", [])
	return progress

func save() -> void:
	var config := ConfigFile.new()
	config.set_value("bank", "ore", banked_ore)
	for id in UPGRADES:
		config.set_value("upgrades", id, level(id))
	config.set_value("npcs", "roster", roster)
	config.set_value("npcs", "stranded", stranded)
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

func crew() -> Array:
	return roster.slice(0, CREW_SLOTS)

## Settles NPC state at the end of a run and saves. rescued: miners
## extracted with the player. newly_stranded: miners being escorted when
## the run failed, with the layer they were lost in. Every other stranded
## miner drifts a layer deeper. Returns summary lines for the hub.
func end_run(rescued: Array, newly_stranded: Array) -> Array:
	var notes: Array = []
	var settled := {}
	for npc in rescued:
		roster.append({"name": npc.name, "type": npc.type})
		settled[npc.name] = true
		notes.append("Rescued %s - joins the roster" % npc.name)
	for npc in newly_stranded:
		settled[npc.name] = true
		notes.append("%s is stranded in the %s" % [npc.name, LAYER_NAMES[npc.layer]])
	var still_stranded: Array = []
	for npc in stranded:
		if settled.has(npc.name):
			continue
		npc.layer += 1
		if npc.layer >= LAYER_NAMES.size():
			notes.append("%s drifted too deep and was lost for good" % npc.name)
		else:
			still_stranded.append(npc)
	stranded = still_stranded + newly_stranded
	save()
	return notes

func apply_to(player: Player) -> void:
	player.light.max_fuel += level("lantern") * LANTERN_FUEL_PER_LEVEL
	player.light.fuel = player.light.max_fuel
	player.health += level("hard_hat") * HARD_HAT_HEALTH_PER_LEVEL
	for member in crew():
		if member.type == "light":
			player.light.burn_rate *= LIGHT_CREW_BURN_MULTIPLIER
			player.light.radius_max *= LIGHT_CREW_RADIUS_MULTIPLIER

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
	"crew_bunk": {"name": "Crew bunk", "effect": "+1 crew slot", "cost_per_level": 80, "max_level": 3},
}
const UPGRADE_ORDER := ["lantern", "hard_hat", "crew_bunk"] # hub keys 1-3

const LANTERN_FUEL_PER_LEVEL := 15.0
const HARD_HAT_HEALTH_PER_LEVEL := 1

# NPC types (PRD: light, repair, noise, traversal). A crew member's type
# improves its system while on the crew; two of a type stack. Repair
# waits for base repair to exist.
const NPC_TYPES := {
	"light": {"label": "Light", "effect": "lantern burns 20% slower, reaches 15% further"},
	"noise": {"label": "Noise", "effect": "everything you do is 25% quieter"},
	"traversal": {"label": "Traversal", "effect": "grapple reaches 50% further"},
}
const LIGHT_CREW_BURN_MULTIPLIER := 0.8
const LIGHT_CREW_RADIUS_MULTIPLIER := 1.15
const NOISE_CREW_MULTIPLIER := 0.75
const TRAVERSAL_CREW_GRAPPLE_MULTIPLIER := 1.5
# PRD: types missing from the roster spawn more often.
const MISSING_TYPE_WEIGHT := 3
# PRD default: 1 starting slot, 4 max via the crew bunk upgrade.
const BASE_CREW_SLOTS := 1

# Stranded NPCs drift one layer deeper for every run that ends without
# rescuing them; drifting past the last layer kills them (PRD: death only
# through neglect). Matches MineGrid's depth bands.
const LAYER_NAMES := ["Topsoil", "Stone", "Deep rock"]

var banked_ore: int = 0
var levels: Dictionary = {}
## Rescued NPCs, oldest first: [{"name": String, "type": String}, ...]
var roster: Array = []
## Names of roster members picked for the crew at the hub.
var crew_names: Array = []
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
		# Saves from before the crew picker: keep their implicit crew.
		var default_crew := progress.roster.slice(0, BASE_CREW_SLOTS).map(func(m): return m.name)
		progress.crew_names = config.get_value("npcs", "crew", default_crew)
	return progress

func save() -> void:
	var config := ConfigFile.new()
	config.set_value("bank", "ore", banked_ore)
	for id in UPGRADES:
		config.set_value("upgrades", id, level(id))
	config.set_value("npcs", "roster", roster)
	config.set_value("npcs", "stranded", stranded)
	config.set_value("npcs", "crew", crew_names)
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

func crew_slots() -> int:
	return BASE_CREW_SLOTS + level("crew_bunk")

func crew() -> Array:
	return roster.filter(func(m): return m.name in crew_names)

## Hub crew picker: takes a roster member off the crew, or puts them on -
## bumping the longest-serving pick if every slot is full.
func toggle_crew(npc_name: String) -> void:
	if npc_name in crew_names:
		crew_names.erase(npc_name)
	else:
		if crew_names.size() >= crew_slots():
			crew_names.pop_front()
		crew_names.append(npc_name)
	save()

## Type for a newly found miner, weighted toward types the roster lacks.
func pick_new_npc_type() -> String:
	var owned := roster.map(func(m): return m.type)
	var pool: Array = []
	for type in NPC_TYPES:
		for i in range(1 if type in owned else MISSING_TYPE_WEIGHT):
			pool.append(type)
	return pool.pick_random()

## Settles NPC state at the end of a run and saves. rescued: miners
## extracted with the player. newly_stranded: miners being escorted when
## the run failed, with the layer they were lost in. Every other stranded
## miner drifts a layer deeper. Returns summary lines for the hub.
func end_run(rescued: Array, newly_stranded: Array) -> Array:
	var notes: Array = []
	var settled := {}
	for npc in rescued:
		roster.append({"name": npc.name, "type": npc.type})
		if crew_names.size() < crew_slots():
			crew_names.append(npc.name) # fill a free slot by default
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

func apply_to(player: Player, noise_meter: NoiseMeter) -> void:
	player.light.max_fuel += level("lantern") * LANTERN_FUEL_PER_LEVEL
	player.light.fuel = player.light.max_fuel
	player.health += level("hard_hat") * HARD_HAT_HEALTH_PER_LEVEL
	for member in crew():
		if member.type == "light":
			player.light.burn_rate *= LIGHT_CREW_BURN_MULTIPLIER
			player.light.radius_max *= LIGHT_CREW_RADIUS_MULTIPLIER
		elif member.type == "noise":
			noise_meter.noise_multiplier *= NOISE_CREW_MULTIPLIER
		elif member.type == "traversal":
			player.grapple_range *= TRAVERSAL_CREW_GRAPPLE_MULTIPLIER

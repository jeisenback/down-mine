extends RefCounted
class_name Progress

## Everything that survives between runs: the ore bank, hub upgrade
## levels, the NPC roster, and stranded NPCs. Per the PRD, hub progress
## is never lost - only extraction adds ore, and nothing here is taken
## away by a failed run.

const SAVE_PATH := "user://save.cfg"

# The old crew's journal (milestone 33): one page per camp searched, in
# order across runs.
const JOURNAL := [
	"Day 3. The seam runs deeper than the survey said. Hollis wants to push on.",
	"Day 9. Lamps die faster down here. Something drinks the light.",
	"Day 12. Heard digging below us at night. None of us were digging.",
	"Day 15. Hollis got an old lift working. It groans, but it climbs.",
	"Day 20. Marta went for fuel and did not come back. We tore up her shirt for markers.",
	"Day 23. The stone breathes green in the cracks. Do not swing a pick near it.",
	"Day 31. Found another camp, older than ours. Same pages. Same handwriting.",
	"Last page. If you are reading this, keep your light high and your voice low.",
]

# Hub upgrades. cost_per_level scales linearly: level n costs n * cost.
const UPGRADES := {
	"lantern": {"name": "Lantern tank", "effect": "+15s light", "cost_per_level": 30, "max_level": 3},
	"hard_hat": {"name": "Hard hat", "effect": "+1 health", "cost_per_level": 50, "max_level": 2},
	"crew_bunk": {"name": "Crew bunk", "effect": "+1 crew slot", "cost_per_level": 80, "max_level": 3},
	# Tool unlocks (milestone 28, PRD: "new tools unlock at the hub; NPCs
	# improve them"). The grapple and ropes stay free as the baseline.
	"lamps": {"name": "Lamps", "effect": "unlock, 3 per run", "cost_per_level": 40, "max_level": 1},
	"ladders": {"name": "Ladders", "effect": "unlock, 4 per run", "cost_per_level": 60, "max_level": 1},
	"anchors": {"name": "Anchors", "effect": "unlock, 2 per run", "cost_per_level": 100, "max_level": 1},
}
const UPGRADE_ORDER := ["lantern", "hard_hat", "crew_bunk", "lamps", "ladders", "anchors"] # hub keys 1-6

const LANTERN_FUEL_PER_LEVEL := 15.0
const HARD_HAT_HEALTH_PER_LEVEL := 1

# NPC types (PRD: light, repair, noise, traversal). A crew member's type
# improves its system while on the crew; two of a type stack. Bonuses
# are fractions at rank strength 1.0; veterans scale them (see RANKS).
# title: veteran epithet.
const NPC_TYPES := {
	"light": {"label": "Light", "title": "Lamplighter"},
	"noise": {"label": "Noise", "title": "Whisper"},
	"traversal": {"label": "Traversal", "title": "Climber"},
	"repair": {"label": "Repair", "title": "Mender"},
}
const LIGHT_BURN_REDUCTION := 0.2
const LIGHT_RADIUS_BONUS := 0.15
const NOISE_REDUCTION := 0.25
const TRAVERSAL_GRAPPLE_BONUS := 0.5
const TRAVERSAL_TOOL_LIFE_BONUS := 0.5   # ropes and ladders last longer
const TRAVERSAL_LADDER_SPEED_BONUS := 0.25
const REPAIR_COST_REDUCTION := 0.25
const REPAIR_SPEED_BONUS := 0.25

# Veterans (PRD): crew gain a run of experience each time a run they were
# on ends in extraction. Rank scales their bonus; Veterans earn a title.
const RANKS := [
	{"name": "Rookie", "runs": 0, "strength": 1.0},
	{"name": "Seasoned", "runs": 2, "strength": 1.5},
	{"name": "Veteran", "runs": 5, "strength": 2.0},
]
# Veteran quirks (PRD: veterans pick up "quirks"): one per Veteran,
# assigned on promotion, a small effect while they are on the crew. Most
# help; one is a mild downside, for character.
const QUIRKS := {
	"night_eyes": {"name": "Night eyes", "effect": "lantern never dims as small"},
	"deep_lungs": {"name": "Deep lungs", "effect": "+10s lantern fuel"},
	"sure_footed": {"name": "Sure-footed", "effect": "safe falls 1 tile higher"},
	"pack_rat": {"name": "Pack rat", "effect": "+1 lamp per run"},
	"tinkerer": {"name": "Tinkerer", "effect": "repairs 10% faster"},
	"hums": {"name": "Hums while working", "effect": "everything 10% louder"},
}
const NIGHT_EYES_MIN_RADIUS_BONUS := 12.0
const DEEP_LUNGS_FUEL := 10.0
const SURE_FOOTED_TILES := 1.0
const TINKERER_REPAIR_SPEED := 1.1
const HUMS_NOISE := 1.1
# PRD: types missing from the roster spawn more often.
const MISSING_TYPE_WEIGHT := 3
# PRD default: 1 starting slot, 4 max via the crew bunk upgrade.
const BASE_CREW_SLOTS := 1

# Stranded NPCs drift one layer deeper for every run that ends without
# rescuing them; drifting past the last of MineGrid's layers kills them
# (PRD: death only through neglect).
static func layer_name(layer: int) -> String:
	return MineGrid.LAYERS[layer].name

## Where save() writes. Tests point this elsewhere so they never touch
## the player's real save.
var save_path: String = SAVE_PATH
var banked_ore: int = 0
var levels: Dictionary = {}
## Rescued NPCs, oldest first: [{"name": String, "type": String}, ...]
var roster: Array = []
## Names of roster members picked for the crew at the hub.
var crew_names: Array = []
## Stranded NPCs: [{"name": String, "type": String, "layer": int}, ...],
## plus "runs"/"found_in" for former crew, restored on rescue.
var stranded: Array = []
var journal_read: int = 0
## Hearts of the mine brought home (milestone 40); each makes later mines
## decay faster.
var hearts_claimed: int = 0
## Recent runs, newest first (milestone 45), for tuning: result, seconds,
## depth, ore, Burrowers, hits by source, seed.
var run_log: Array = []
const RUN_LOG_SIZE := 10

## When set, load_saved() uses this path instead - the Main smoke test
## points it at the test save so it never reads the player's real one.
static var path_override: String = ""

static func load_saved(path: String = SAVE_PATH) -> Progress:
	if path_override != "":
		path = path_override
	var progress := Progress.new()
	progress.save_path = path
	var config := ConfigFile.new()
	if config.load(path) == OK:
		progress.banked_ore = int(config.get_value("bank", "ore", 0))
		for id in UPGRADES:
			progress.levels[id] = int(config.get_value("upgrades", id, 0))
		progress.roster = config.get_value("npcs", "roster", [])
		progress.stranded = config.get_value("npcs", "stranded", [])
		progress.journal_read = int(config.get_value("lore", "journal_read", 0))
		progress.hearts_claimed = int(config.get_value("lore", "hearts_claimed", 0))
		progress.run_log = config.get_value("stats", "run_log", [])
		# Saves from before the crew picker: keep their implicit crew.
		var default_crew := progress.roster.slice(0, BASE_CREW_SLOTS).map(func(m): return m.name)
		progress.crew_names = config.get_value("npcs", "crew", default_crew)
		progress._assign_missing_quirks() # Veterans from before quirks existed
	return progress

## Gives every Veteran without a quirk a random one, preferring quirks no
## one on the roster has yet so Veterans stay distinct. Returns who got one.
func _assign_missing_quirks() -> Array:
	var assigned: Array = []
	for member in roster:
		if rank_of(member).name == "Veteran" and not member.has("quirk"):
			var held := roster.map(func(m): return m.get("quirk", ""))
			var fresh := QUIRKS.keys().filter(func(q): return not q in held)
			member["quirk"] = (fresh if not fresh.is_empty() else QUIRKS.keys()).pick_random()
			assigned.append(member)
	return assigned

func quirk_text(member: Dictionary) -> String:
	if not member.has("quirk"):
		return ""
	var quirk: Dictionary = QUIRKS[member.quirk]
	return "%s (%s)" % [quirk.name, quirk.effect]

## Extra lamps per run from crew quirks.
func extra_lamps() -> int:
	return crew().filter(func(m): return m.get("quirk", "") == "pack_rat").size()

func save() -> void:
	var config := ConfigFile.new()
	config.set_value("bank", "ore", banked_ore)
	for id in UPGRADES:
		config.set_value("upgrades", id, level(id))
	config.set_value("npcs", "roster", roster)
	config.set_value("npcs", "stranded", stranded)
	config.set_value("npcs", "crew", crew_names)
	config.set_value("lore", "journal_read", journal_read)
	config.set_value("lore", "hearts_claimed", hearts_claimed)
	config.set_value("stats", "run_log", run_log)
	config.save(save_path)

func record_run(entry: Dictionary) -> void:
	run_log.push_front(entry)
	run_log = run_log.slice(0, RUN_LOG_SIZE)
	save()

## One line per run for the hub, e.g. "Died (Stalker) 3:12, depth 84,
## 40 ore, 2 Burrowers, hits: Stalker 2, fall 1 [seed 1234]".
static func run_log_line(entry: Dictionary) -> String:
	var seconds := int(entry.get("seconds", 0))
	var hits: Dictionary = entry.get("hits", {})
	var hit_text := ", ".join(hits.keys().map(func(k): return "%s %d" % [k, hits[k]]))
	return "%s %d:%02d, depth %d, %d ore, %d Burrower%s%s [seed %d]" % [
		entry.get("result", "?"), seconds / 60, seconds % 60, entry.get("depth", 0), entry.get("ore", 0),
		entry.get("burrowers", 0), "" if entry.get("burrowers", 0) == 1 else "s",
		(", hits: " + hit_text) if hit_text != "" else "", entry.get("seed", 0)]

## The next unread journal page, marked read and saved right away (the
## page is found whether or not the run ends well).
func read_journal_page() -> String:
	if journal_read >= JOURNAL.size():
		return "The rest of the journal is water-stained and unreadable."
	journal_read += 1
	save()
	return "Journal %d/%d: %s" % [journal_read, JOURNAL.size(), JOURNAL[journal_read - 1]]

func level(id: String) -> int:
	return levels.get(id, 0)

func has_unlock(id: String) -> bool:
	return level(id) >= 1

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

func rank_of(member: Dictionary) -> Dictionary:
	var rank: Dictionary = RANKS[0]
	for r in RANKS:
		if member.get("runs", 0) >= r.runs:
			rank = r
	return rank

func display_name(member: Dictionary) -> String:
	if rank_of(member).name == "Veteran":
		return "%s the %s" % [member.name, NPC_TYPES[member.type].title]
	return member.name

func effect_text(member: Dictionary) -> String:
	var strength: float = rank_of(member).strength
	match member.type:
		"light":
			return "lantern burn -%d%%, reach +%d%%" % [
				roundi(LIGHT_BURN_REDUCTION * strength * 100), roundi(LIGHT_RADIUS_BONUS * strength * 100)]
		"noise":
			return "noise -%d%%" % roundi(NOISE_REDUCTION * strength * 100)
		"traversal":
			return "grapple +%d%%, rope life +%d%%, ladders +%d%%" % [
				roundi(TRAVERSAL_GRAPPLE_BONUS * strength * 100), roundi(TRAVERSAL_TOOL_LIFE_BONUS * strength * 100),
				roundi(TRAVERSAL_LADDER_SPEED_BONUS * strength * 100)]
		"repair":
			return "repair cost -%d%%, speed +%d%%" % [
				roundi(REPAIR_COST_REDUCTION * strength * 100), roundi(REPAIR_SPEED_BONUS * strength * 100)]
	return ""

## Type for a newly found miner, weighted toward types the roster lacks.
func pick_new_npc_type() -> String:
	var owned := roster.map(func(m): return m.type)
	var pool: Array = []
	for type in NPC_TYPES:
		for i in range(1 if type in owned else MISSING_TYPE_WEIGHT):
			pool.append(type)
	return pool.pick_random()

## Settles NPC state at the end of a run and saves. rescued: miners
## extracted with the player (with the layer they were found in).
## newly_stranded: miners being escorted, or crew left at the base, when
## the run failed, with the layer they were lost in; crew leave the
## roster (and their bonus) until rescued. On extraction the crew gains a
## run of experience. Every other stranded miner drifts a layer deeper.
## Returns summary lines for the hub.
func end_run(rescued: Array, newly_stranded: Array, extracted: bool) -> Array:
	var notes: Array = []
	if extracted:
		for member in crew(): # before rescues, so newcomers don't gain a run
			var old_rank: String = rank_of(member).name
			member.runs = member.get("runs", 0) + 1
			if rank_of(member).name != old_rank:
				notes.append("%s is now %s" % [display_name(member), rank_of(member).name])
		for member in _assign_missing_quirks():
			notes.append("%s picked up a quirk: %s" % [display_name(member), quirk_text(member)])
	var settled := {}
	for npc in rescued:
		# A rescued former crew member keeps their experience and history.
		var history: Dictionary = _stranded_entry(npc.name)
		roster.append({"name": npc.name, "type": npc.type,
			"runs": history.get("runs", 0), "found_in": history.get("found_in", npc.found_in)})
		if history.has("quirk"):
			roster[-1]["quirk"] = history.quirk
		if crew_names.size() < crew_slots():
			crew_names.append(npc.name) # fill a free slot by default
		settled[npc.name] = true
		notes.append("Rescued %s - joins the roster" % display_name(roster[-1]))
	for npc in newly_stranded:
		var member: Dictionary = _roster_entry(npc.name)
		if not member.is_empty():
			roster.erase(member)
			crew_names.erase(npc.name)
			npc["runs"] = member.get("runs", 0) # string keys, like the rest of the save
			npc["found_in"] = member.get("found_in", 0)
			if member.has("quirk"):
				npc["quirk"] = member.quirk
		settled[npc.name] = true
		notes.append("%s is stranded in the %s" % [npc.name, layer_name(npc.layer)])
	var still_stranded: Array = []
	for npc in stranded:
		if settled.has(npc.name):
			continue
		npc.layer += 1
		if npc.layer >= MineGrid.LAYERS.size():
			notes.append("%s drifted too deep and was lost for good" % npc.name)
		else:
			still_stranded.append(npc)
	stranded = still_stranded + newly_stranded
	save()
	return notes

func _roster_entry(npc_name: String) -> Dictionary:
	for member in roster:
		if member.name == npc_name:
			return member
	return {}

func _stranded_entry(npc_name: String) -> Dictionary:
	for npc in stranded:
		if npc.name == npc_name:
			return npc
	return {}

func apply_to(player: Player, noise_meter: NoiseMeter, run_base: RunBase) -> void:
	player.light.max_fuel += level("lantern") * LANTERN_FUEL_PER_LEVEL
	player.light.fuel = player.light.max_fuel
	player.health += level("hard_hat") * HARD_HAT_HEALTH_PER_LEVEL
	if not has_unlock("ladders"):
		player.ladders_left = 0
	if not has_unlock("anchors"):
		player.anchors_left = 0
	for member in crew():
		var strength: float = rank_of(member).strength
		if member.type == "light":
			player.light.burn_rate *= 1.0 - LIGHT_BURN_REDUCTION * strength
			player.light.radius_max *= 1.0 + LIGHT_RADIUS_BONUS * strength
		elif member.type == "noise":
			noise_meter.noise_multiplier *= 1.0 - NOISE_REDUCTION * strength
		elif member.type == "traversal":
			player.grapple_range *= 1.0 + TRAVERSAL_GRAPPLE_BONUS * strength
			player.tool_life_multiplier *= 1.0 + TRAVERSAL_TOOL_LIFE_BONUS * strength
			player.ladder_speed_multiplier *= 1.0 + TRAVERSAL_LADDER_SPEED_BONUS * strength
		elif member.type == "repair":
			run_base.repair_cost_multiplier *= 1.0 - REPAIR_COST_REDUCTION * strength
			run_base.repair_speed_multiplier *= 1.0 + REPAIR_SPEED_BONUS * strength
		match member.get("quirk", ""):
			"night_eyes":
				player.light.radius_min += NIGHT_EYES_MIN_RADIUS_BONUS
			"deep_lungs":
				player.light.max_fuel += DEEP_LUNGS_FUEL
				player.light.fuel = player.light.max_fuel
			"sure_footed":
				player.safe_fall_tiles += SURE_FOOTED_TILES
			"tinkerer":
				run_base.repair_speed_multiplier *= TINKERER_REPAIR_SPEED
			"hums":
				noise_meter.noise_multiplier *= HUMS_NOISE
			# pack_rat: extra_lamps(), read by Main

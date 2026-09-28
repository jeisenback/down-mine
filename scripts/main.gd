extends Node2D
class_name Main

# How close to the run base counts as "there" (repair, fortify, refuel).
const BASE_RADIUS := 32.0
# Standing at the base refills the lantern from the base's own light -
# the PRD's shared light/structure clock: refuelling dims the base,
# which makes its walls wear faster.
const BASE_REFUEL_RATE := 6.0 # fuel/s moved from base light to lantern
# Planting the base (milestone 19): once per run, anywhere below the
# crust. The flag stands this far above the floor the player is on.
const BASE_PLANT_NOISE := 15.0
const BASE_FLAG_HEIGHT_ABOVE_PLAYER := 15.0
const CREW_SPACING := 12.0 # px between crew standing at the base

# Burrowers surface this far below the player - the noise came from
# there - and tunnel to the base, so the player can race or chase them.
const BURROWER_SPAWN_OFFSET_TILES := 10
const BurrowerScene := preload("res://scenes/Burrower.tscn")

# Placed lights (milestone 20): a few per run, noisy to place.
const LampScene := preload("res://scenes/Lamp.tscn")
const LAMPS_PER_RUN := 3
const LAMP_PLACE_NOISE := 10.0
# Snuffers: while any lamp is burning, one appears every interval (never
# more than one at a time), this far from the light it will hunt first.
const SnufferScene := preload("res://scenes/Snuffer.tscn")
const SNUFFER_SPAWN_INTERVAL := 45.0
const SNUFFER_SPAWN_DISTANCE_TILES := 10

const LostMinerScene := preload("res://scenes/LostMiner.tscn")
# Signs leading to each stranded miner (milestone 25); Veterans leave more.
const StrandedSignScene := preload("res://scenes/StrandedSign.tscn")
const SIGN_COUNT := 5
const VETERAN_SIGN_COUNT := 8
const SIGN_MIN_TILES := 2.0
const SIGN_MAX_TILES := 18.0
# Each miner has their own shirt colour (and matching glow), so the same
# miner always looks the same and two miners never read as one. All
# distinct from the player's red shirt.
const MINER_COLORS := {
	"Ada": Color(0.25, 0.45, 0.95),  # blue
	"Bram": Color(0.2, 0.7, 0.3),    # green
	"Cole": Color(0.6, 0.3, 0.85),   # violet
	"Dita": Color(0.95, 0.8, 0.2),   # yellow
	"Ezra": Color(0.2, 0.75, 0.8),   # cyan
	"Fenn": Color(0.95, 0.4, 0.7),   # pink
	"Greta": Color(0.92, 0.92, 0.92), # white
	"Hale": Color(0.5, 0.32, 0.18),  # brown
	"Iris": Color(0.65, 0.9, 0.2),   # lime
	"Jory": Color(0.15, 0.2, 0.5),   # navy
}

@onready var mine: MineGrid = $Mine
@onready var run_base: RunBase = $RunBase
@onready var player: Player = $Player
@onready var stalker: Stalker = $Stalker
@onready var noise_meter: NoiseMeter = $NoiseMeter
@onready var hud: HUD = $HUD

var run_ended: bool = false
var max_depth_reached: int = 0
var _extract_key_was_pressed: bool = false
var _fortify_key_was_pressed: bool = false
var _plant_key_was_pressed: bool = false
var base_planted: bool = false
var lamps_left: int = LAMPS_PER_RUN
var _lamp_key_was_pressed: bool = false
var _snuffer_timer: float = 0.0
var progress: Progress
var lost_miners: Array[LostMiner] = []
var crew_at_base: Array[LostMiner] = []

func _ready() -> void:
	player.mine = mine
	stalker.player = player
	stalker.run_base = run_base
	mine.tile_dug.connect(_on_tile_dug)
	player.made_noise.connect(_on_tile_dug) # same amount->noise_meter path, source doesn't matter
	noise_meter.noise_changed.connect(hud.update_noise)
	noise_meter.threshold_reached.connect(_on_noise_threshold)
	player.died.connect(_on_player_died)
	run_base.fell.connect(_on_base_fell)
	hud.new_run_requested.connect(_start_new_run)
	hud.upgrade_requested.connect(_on_upgrade_requested)
	hud.crew_toggle_requested.connect(_on_crew_toggle_requested)
	progress = Progress.load_saved()
	progress.apply_to(player, noise_meter, run_base)
	lamps_left += progress.extra_lamps()
	hud.update_banked(progress.banked_ore)
	_configure_camera_limits()
	_spawn_lost_miners()
	_spawn_crew()

## The crew wait at the run base (PRD: they can be caught in a base
## attack or left behind when a run fails - see _fail_run).
func _spawn_crew() -> void:
	for member in progress.crew():
		var miner: LostMiner = LostMinerScene.instantiate()
		miner.player = player
		miner.miner_name = member.name
		miner.npc_type = member.type
		miner.stationary = true
		miner.shirt_color = MINER_COLORS.get(member.name, Color(1, 1, 1))
		add_child(miner)
		crew_at_base.append(miner)
	_place_crew_at_base()

## Side by side on the base's floor, flanking the flag.
func _place_crew_at_base() -> void:
	for i in range(crew_at_base.size()):
		var side := -1 if i % 2 == 0 else 1
		var offset_x := side * CREW_SPACING * (1 + floori(i / 2.0))
		crew_at_base[i].global_position = run_base.global_position + Vector2(offset_x, BASE_FLAG_HEIGHT_ABOVE_PLAYER)

## This run's new find (named from miners not on the roster or stranded),
## plus every stranded miner, placed in the layer they have drifted to.
func _spawn_lost_miners() -> void:
	var taken := (progress.roster + progress.stranded).map(func(m): return m.name)
	var names := MINER_COLORS.keys().filter(func(n): return not n in taken)
	if mine.lost_miner_cell.x >= 0 and not names.is_empty():
		_spawn_miner(names.pick_random(), progress.pick_new_npc_type(), mine.lost_miner_cell, false)
	for npc in progress.stranded:
		var cell := mine.take_floor_cell_in_layer(npc.layer)
		if cell.x >= 0:
			_spawn_miner(npc.name, npc.type, cell, true)
			_place_signs(npc, cell)

## The PRD's in-mine signs: scraps of the stranded miner's shirt on cave
## floors around them, spread from far to near so they get denser as the
## player closes in. The hub says which layer; the signs say where.
func _place_signs(npc: Dictionary, miner_cell: Vector2i) -> void:
	var veteran: bool = progress.rank_of(npc).name == "Veteran"
	var count := VETERAN_SIGN_COUNT if veteran else SIGN_COUNT
	for cell in mine.take_trail_cells(miner_cell, count, SIGN_MIN_TILES, SIGN_MAX_TILES):
		var marker: StrandedSign = StrandedSignScene.instantiate()
		marker.color = MINER_COLORS.get(npc.name, Color(1, 1, 1))
		marker.veteran = veteran
		marker.global_position = mine.cell_to_world(cell)
		mine.add_child(marker)

func _spawn_miner(miner_name: String, npc_type: String, cell: Vector2i, was_stranded: bool) -> void:
	var miner: LostMiner = LostMinerScene.instantiate()
	miner.player = player
	miner.miner_name = miner_name
	miner.npc_type = npc_type
	miner.was_stranded = was_stranded
	miner.shirt_color = MINER_COLORS.get(miner_name, Color(1, 1, 1))
	miner.global_position = mine.cell_to_world(cell)
	miner.found_in = mine.layer_index_at_world(miner.global_position)
	miner.picked_up.connect(_on_miner_picked_up.bind(miner))
	add_child(miner)
	lost_miners.append(miner)

func _on_miner_picked_up(miner: LostMiner) -> void:
	var escorts := _escorts()
	miner.follow_delay = LostMiner.FOLLOW_DELAY_POINTS * escorts.size()
	hud.update_escort(", ".join(escorts.map(func(m): return "%s (%s)" % [m.miner_name, Progress.NPC_TYPES[m.npc_type].label])))

func _escorts() -> Array:
	return lost_miners.filter(func(m): return m.following)

func _configure_camera_limits() -> void:
	var camera := player.get_node("Camera2D") as Camera2D
	camera.limit_right = mine.GRID_WIDTH * mine.TILE_SIZE
	camera.limit_bottom = mine.GRID_HEIGHT * mine.TILE_SIZE

func _process(delta: float) -> void:
	if run_ended:
		return
	hud.update_fuel(player.light.fuel_fraction())
	hud.update_health(player.health)
	hud.update_compass(run_base.global_position - player.global_position)
	hud.update_currency(player.currency)
	_check_repair(delta)
	_check_fortify()
	_check_refuel(delta)
	_check_plant()
	_check_lamp()
	_check_snuffer_spawn(delta)
	hud.update_tools(lamps_left, player.ladders_left, player.anchors_left, get_tree().get_nodes_in_group("snuffers").size() > 0)
	mine.decay_walls(delta, run_base.light.fuel_fraction())
	var decay_noise := mine.tick_decay(delta, player.global_position)
	if decay_noise > 0.0:
		noise_meter.add_noise(decay_noise)
	hud.update_base(run_base, get_tree().get_nodes_in_group("burrowers").size() > 0, mine.wall_count())
	hud.update_prompts(_action_prompts())
	max_depth_reached = max(max_depth_reached, _current_depth())
	_check_extraction()

## Depth in tiles below the surface crust, for the run summary. Never
## negative even if the player is still above the crust at run start.
func _current_depth() -> int:
	var cell := mine.world_to_cell(player.global_position)
	return max(0, cell.y - mine.SURFACE_ROWS)

func _action_prompts() -> Array:
	var prompts: Array = []
	if _near_base():
		if run_base.needs_repair():
			if player.currency < run_base.repair_cost():
				prompts.append("Repair needs %d ore" % run_base.repair_cost())
			elif run_base.repair_progress > 0.0:
				prompts.append("Repairing %d%%" % int(run_base.repair_progress * 100))
			else:
				prompts.append("F (hold): repair, %d ore" % run_base.repair_cost())
		prompts.append("B: fortify, %d ore/tile" % run_base.wall_cost())
	if _can_plant():
		prompts.append("P: plant base here")
	if _at_surface():
		prompts.append("E: extract")
	return prompts

func _near_base() -> bool:
	return player.global_position.distance_to(run_base.global_position) < BASE_RADIUS

## Above the crust = out of the mine. Extraction happens here, not at the
## base, so a base planted deep is a forward camp, not a way out: the
## climb home stays the hard part (PRD traversal pillar).
func _at_surface() -> bool:
	return player.global_position.y < mine.SURFACE_ROWS * mine.TILE_SIZE

func _can_plant() -> bool:
	return not base_planted and player.is_on_floor() and not _at_surface()

## P moves the run base - flag, light, repair, walls, Burrower target -
## to where the player stands. Walls left behind wear away as usual.
func _check_plant() -> void:
	var pressed := Input.is_physical_key_pressed(KEY_P)
	if pressed and not _plant_key_was_pressed and _can_plant():
		base_planted = true
		run_base.global_position = player.global_position - Vector2(0, BASE_FLAG_HEIGHT_ABOVE_PLAYER)
		run_base.repair_progress = 0.0
		_place_crew_at_base()
		noise_meter.add_noise(BASE_PLANT_NOISE)
	_plant_key_was_pressed = pressed

## L sets a lamp down where the player stands.
func _check_lamp() -> void:
	var pressed := Input.is_physical_key_pressed(KEY_L)
	if pressed and not _lamp_key_was_pressed and lamps_left > 0 and player.is_on_floor():
		lamps_left -= 1
		var lamp: Lamp = LampScene.instantiate()
		lamp.global_position = player.global_position
		mine.add_child(lamp)
		noise_meter.add_noise(LAMP_PLACE_NOISE)
	_lamp_key_was_pressed = pressed

func _check_snuffer_spawn(delta: float) -> void:
	if get_tree().get_nodes_in_group("lamps").is_empty() or not get_tree().get_nodes_in_group("snuffers").is_empty():
		_snuffer_timer = 0.0
		return
	_snuffer_timer += delta
	if _snuffer_timer < SNUFFER_SPAWN_INTERVAL:
		return
	_snuffer_timer = 0.0
	var snuffer: Snuffer = SnufferScene.instantiate()
	snuffer.player = player
	snuffer.global_position = _snuffer_spawn_position()
	add_child(snuffer)

## Near the light furthest from the player, in a random direction,
## clamped inside the mine below the crust.
func _snuffer_spawn_position() -> Vector2:
	var far_light: Node2D = null
	for light in get_tree().get_nodes_in_group("snuffable"):
		if far_light == null or light.global_position.distance_to(player.global_position) > far_light.global_position.distance_to(player.global_position):
			far_light = light
	var offset := Vector2.RIGHT.rotated(randf() * TAU) * SNUFFER_SPAWN_DISTANCE_TILES * mine.TILE_SIZE
	var cell := mine.world_to_cell(far_light.global_position + offset)
	cell.x = clamp(cell.x, 1, mine.GRID_WIDTH - 2)
	cell.y = clamp(cell.y, mine.SURFACE_ROWS, mine.GRID_HEIGHT - 2)
	return mine.cell_to_world(cell)

func _check_refuel(delta: float) -> void:
	if not _near_base():
		return
	var room := player.light.max_fuel - player.light.fuel
	var amount: float = min(BASE_REFUEL_RATE * delta, room, run_base.light.fuel)
	if amount > 0.0:
		player.light.add_fuel(amount)
		run_base.light.fuel -= amount

## Holding F at the base repairs it, paid from this run's ore.
func _check_repair(delta: float) -> void:
	if not (Input.is_physical_key_pressed(KEY_F) and _near_base()):
		return
	if run_base.tick_repair(delta, player.currency):
		player.currency -= run_base.repair_cost()
		noise_meter.add_noise(run_base.REPAIR_NOISE)

## Pressing B at the base reinforces the rock around it, nearest tiles
## first: one batch per press, as many as this run's ore covers.
func _check_fortify() -> void:
	var pressed := Input.is_physical_key_pressed(KEY_B)
	if pressed and not _fortify_key_was_pressed and _near_base():
		var base_cell := mine.world_to_cell(run_base.global_position)
		var cells := mine.unreinforced_cells_around(base_cell, run_base.FORTIFY_RADIUS_TILES)
		var count: int = min(cells.size(), run_base.FORTIFY_BATCH_TILES, player.currency / run_base.wall_cost())
		for i in range(count):
			mine.reinforce(cells[i])
		if count > 0:
			player.currency -= count * run_base.wall_cost()
			noise_meter.add_noise(count * run_base.WALL_NOISE)
	_fortify_key_was_pressed = pressed

func _check_extraction() -> void:
	var extract_pressed := Input.is_physical_key_pressed(KEY_E)
	if extract_pressed and not _extract_key_was_pressed and _at_surface():
		_extract()
	_extract_key_was_pressed = extract_pressed

func _extract() -> void:
	run_ended = true
	progress.banked_ore += player.currency
	progress.save()
	hud.update_banked(progress.banked_ore)
	var rescued := _escorts().map(func(m): return {"name": m.miner_name, "type": m.npc_type, "found_in": m.found_in})
	var notes := progress.end_run(rescued, [], true)
	hud.show_run_summary("Extracted!", true, player.currency, max_depth_reached, progress, notes)
	get_tree().paused = true

func _on_tile_dug(noise_amount: float) -> void:
	noise_meter.add_noise(noise_amount)

func _on_noise_threshold() -> void:
	var burrower: Burrower = BurrowerScene.instantiate()
	burrower.mine = mine
	burrower.player = player
	burrower.target = run_base
	burrower.global_position = _burrower_spawn_position()
	add_child(burrower)

## Below the player, clamped inside the bedrock walls and floor.
func _burrower_spawn_position() -> Vector2:
	var cell := mine.world_to_cell(player.global_position) + Vector2i(0, BURROWER_SPAWN_OFFSET_TILES)
	cell.x = clamp(cell.x, 1, mine.GRID_WIDTH - 2)
	cell.y = clamp(cell.y, mine.SURFACE_ROWS, mine.GRID_HEIGHT - 2)
	return mine.cell_to_world(cell)

func _on_base_fell() -> void:
	_fail_run("Base Fell")

func _on_player_died() -> void:
	_fail_run("Run Failed")

func _fail_run(title: String) -> void:
	if run_ended:
		return
	run_ended = true
	hud.update_health(player.health)
	# PRD: miners lost during an escort are stranded where they were lost,
	# and crew left at the base are stranded in the base's layer.
	var newly_stranded := (_escorts() + crew_at_base).map(func(m): return {
		"name": m.miner_name, "type": m.npc_type, "layer": mine.layer_index_at_world(m.global_position)})
	var notes := progress.end_run([], newly_stranded, false)
	hud.show_run_summary(title, false, player.currency, max_depth_reached, progress, notes)
	get_tree().paused = true

## Reloading the scene is the whole reset: the mine regenerates in
## Mine._ready() and every per-run value (light, noise, run ore) starts
## fresh. Only Progress (bank, upgrades, roster, stranded) survives, via
## the save file.
func _start_new_run() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()

## Hub purchase from the run summary. Upgrades take effect next run,
## when Progress.apply_to() runs on the fresh player.
func _on_upgrade_requested(id: String) -> void:
	if progress.try_buy(id):
		hud.update_banked(progress.banked_ore)
		hud.refresh_hub(progress)

## Hub crew picker, by roster index. Takes effect next run.
func _on_crew_toggle_requested(roster_index: int) -> void:
	if roster_index < progress.roster.size():
		progress.toggle_crew(progress.roster[roster_index].name)
		hud.refresh_hub(progress)

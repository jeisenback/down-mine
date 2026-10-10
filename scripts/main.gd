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

# Layer identity (milestone 29): the HUD names each layer's hazards from
# MineGrid.LAYERS; gas rock releases clouds; the first descent into a
# layer flagged "stalker" wakes one, this far off in the dark. No Stalker
# ever rises into the quiet layers on top, so climbing back up is a real
# escape. The nest (milestone 37) sits in NEST_LAYER: burning it removes
# that layer's Stalker, or stops it waking.
const GasCloudScene := preload("res://scenes/GasCloud.tscn")
const StalkerScene := preload("res://scenes/Stalker.tscn")
const STALKER_SPAWN_TILES := 12
const NEST_LAYER := 4

# Buildings (milestone 32): support beams anywhere; beacon and bell at base.
const SupportScene := preload("res://scenes/Support.tscn")
const LadderScene := preload("res://scenes/Ladder.tscn")
const OLD_LADDER_CLEARANCE := 2
const SUPPORT_ORE_COST := 15
const BELL_WARNING_FRACTION := 0.75

# Mine events (milestone 33): scenes by EVENT_ROOMS kind, used with E.
const EVENT_SCENES := {
	"camp": preload("res://scenes/Camp.tscn"),
	"lift": preload("res://scenes/Lift.tscn"),
	"outpost": preload("res://scenes/Outpost.tscn"),
	"vault": preload("res://scenes/Relic.tscn"),
	"gallery": preload("res://scenes/Gallery.tscn"),
	"nest": preload("res://scenes/Nest.tscn"),
	"heart": preload("res://scenes/Heart.tscn"),
}
const EVENT_RANGE := 24.0
const VaultDoorScene := preload("res://scenes/VaultDoor.tscn")

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
## Layers whose Stalker has woken (first descent), by layer index.
var _stalkers_woken: Dictionary = {}
## The NEST_LAYER Stalker, which burning the nest removes.
var deep_stalker: Stalker = null
## A burned nest (milestone 37) keeps the deep's second Stalker away.
var nest_destroyed: bool = false
# The Heart of the mine (milestone 40): the run's goal.
const HEART_ORE := 300
const HEART_NOISE := 50.0
const HEART_CARRY_DECAY := 0.5 # the mine decays twice as fast behind you
const CLAIMED_DECAY_STEP := 0.85 # each claimed Heart: later mines decay 15% faster
var carrying_heart: bool = false
# Run log (milestone 45).
var run_seconds: float = 0.0
var burrowers_spawned: int = 0 # from noise
var waves_spawned: int = 0 # from the mine's clock
var mine_clock := MineClock.new()
# Debug keys (milestone 43), only with the debug launch option.
const DEBUG_KEYS := [KEY_I, KEY_O, KEY_U, KEY_N, KEY_K, KEY_M]
const DEBUG_ORE := 100
var debug_enabled: bool = false
var _debug_keys_down: Dictionary = {}
var _debug_event_index: int = 0
var _build_keys_down: Dictionary = {}
var _bell_ringing: bool = false
var progress: Progress
var lost_miners: Array[LostMiner] = []
var crew_at_base: Array[LostMiner] = []

func _ready() -> void:
	player.mine = mine
	noise_meter.quiet_at = func(pos: Vector2): return mine.is_quiet_at(pos)
	noise_meter.base_position = func(): return run_base.global_position
	mine.tile_dug.connect(_on_tile_dug)
	mine.gas_released.connect(_on_gas_released)
	player.made_noise.connect(func(amount): _on_tile_dug(amount, player.global_position))
	noise_meter.noise_changed.connect(hud.update_noise)
	noise_meter.threshold_reached.connect(_on_noise_threshold)
	noise_meter.noise_made.connect(_on_noise_made)
	player.died.connect(_on_player_died)
	run_base.fell.connect(_on_base_fell)
	hud.new_run_requested.connect(_start_new_run)
	hud.upgrade_requested.connect(_on_upgrade_requested)
	hud.crew_toggle_requested.connect(_on_crew_toggle_requested)
	progress = Progress.load_saved()
	progress.apply_to(player, noise_meter, run_base)
	mine.decay_multiplier = pow(CLAIMED_DECAY_STEP, progress.hearts_claimed)
	# Lamps need the hub unlock; a Pack rat brings their own either way.
	lamps_left = (LAMPS_PER_RUN if progress.has_unlock("lamps") else 0) + progress.extra_lamps()
	hud.update_banked(progress.banked_ore)
	_configure_camera_limits()
	_spawn_lost_miners()
	_spawn_crew()
	_spawn_events()
	_spawn_old_ladder()
	debug_enabled = LaunchOptions.debug_enabled()
	hud.show_seed(mine.mine_seed, debug_enabled)
	Sfx.warm_up()

## The old mine's ladder (milestone 51): each surviving 8-row piece is a run
## of 4-tile Ladder scenes up the shaft's centre column. They never rot.
## Only whole scenes are placed, and none comes within OLD_LADDER_CLEARANCE
## rows of the collapse: a player standing on the debris must not be on a
## ladder, or holding S would climb instead of digging.
func _spawn_old_ladder() -> void:
	var last_row: int = mine.shaft_open_rows().y - OLD_LADDER_CLEARANCE
	for row in mine.old_ladder_rows:
		for j in range(ceili(MineGrid.OLD_LADDER_PIECE_ROWS / 4.0)):
			var bottom_row: int = row + 4 * j + 3
			if bottom_row > last_row:
				continue
			var ladder: Rope = LadderScene.instantiate()
			ladder.life_seconds = INF
			ladder.climb_speed = Player.LADDER_CLIMB_SPEED
			mine.add_child(ladder)
			ladder.global_position = mine.cell_to_world(Vector2i(mine.shaft_column(), bottom_row)) + Vector2(0.0, mine.TILE_SIZE / 2.0)

func _spawn_events() -> void:
	for room in mine.event_rooms:
		var event: Node2D = EVENT_SCENES[room.kind].instantiate()
		if event is Camp:
			event.layer = mine.layer_index_at_world(mine.cell_to_world(room.cell))
		if event is Outpost:
			event.main = self
		if event is Nest:
			event.main = self
		if event is Gallery:
			event.main = self
			event.rect = room.rect
		event.global_position = mine.cell_to_world(room.cell)
		mine.add_child(event)
		if event is Outpost:
			_spawn_survivor(event.global_position + Outpost.SURVIVOR_OFFSET)
		if room.kind == "vault":
			var door: VaultDoor = VaultDoorScene.instantiate()
			door.global_position = mine.cell_to_world(room.door) + Vector2(0, -mine.TILE_SIZE / 2.0)
			mine.add_child(door)

## The outpost's recruitable survivor, named like a new find.
func _spawn_survivor(pos: Vector2) -> void:
	var names := _free_miner_names()
	if names.is_empty():
		return
	_spawn_miner(names.pick_random(), progress.pick_new_npc_type(), mine.world_to_cell(pos), false, Outpost.RECRUIT_ORE)

## Miner names not on the roster, stranded, or already in this mine.
func _free_miner_names() -> Array:
	var taken := (progress.roster + progress.stranded).map(func(m): return m.name) + lost_miners.map(func(m): return m.miner_name)
	return MINER_COLORS.keys().filter(func(n): return not n in taken)

## The closest mine event within reach, or null.
func _nearest_event() -> Node2D:
	var nearest: Node2D = null
	for event in get_tree().get_nodes_in_group("mine_events"):
		var d := player.global_position.distance_to(event.global_position)
		if d < EVENT_RANGE and (nearest == null or d < player.global_position.distance_to(nearest.global_position)):
			nearest = event
	return nearest

## The lift's ride: player and escorts to the surface above world_x.
func ride_to_surface(world_x: float) -> void:
	var cell := Vector2i(mine.world_to_cell(Vector2(world_x, 0)).x, mine.SURFACE_ROWS - 1)
	var target := mine.cell_to_world(cell)
	player.global_position = target
	player.velocity = Vector2.ZERO
	for miner in _escorts():
		miner.teleport_to(target)

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
	var names := _free_miner_names()
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

func _spawn_miner(miner_name: String, npc_type: String, cell: Vector2i, was_stranded: bool, recruit_cost: int = 0) -> void:
	var miner: LostMiner = LostMinerScene.instantiate()
	miner.player = player
	miner.miner_name = miner_name
	miner.npc_type = npc_type
	miner.was_stranded = was_stranded
	miner.recruit_cost = recruit_cost
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
	run_seconds += delta
	match mine_clock.tick(delta, run_seconds, carrying_heart):
		"warn":
			if run_base.has_bell:
				Sfx.play("alarm", -4.0)
		"wave":
			_spawn_wave()
	hud.update_fuel(player.light.fuel_fraction())
	hud.update_health(player.health)
	_check_layer()
	hud.update_compass(run_base.global_position - player.global_position)
	hud.update_currency(player.currency)
	_check_repair(delta)
	_check_fortify()
	_check_refuel(delta)
	_check_plant()
	_check_lamp()
	_check_builds()
	_check_bell()
	if debug_enabled:
		_check_debug_keys()
	_check_snuffer_spawn(delta)
	hud.update_tools({
		"Lamps": lamps_left if progress.has_unlock("lamps") or lamps_left > 0 else -1,
		"Ladders": player.ladders_left if progress.has_unlock("ladders") or player.ladders_left > 0 else -1,
		"Anchors": player.anchors_left if progress.has_unlock("anchors") or player.anchors_left > 0 else -1,
	}, get_tree().get_nodes_in_group("snuffers").size() > 0)
	mine.decay_walls(delta, run_base.light.fuel_fraction())
	for lost_at in mine.tick_decay(delta, player.global_position):
		noise_meter.add_noise(MineGrid.DECAY_NOISE, lost_at)
	hud.update_base(run_base, get_tree().get_nodes_in_group("burrowers").size() > 0, mine.wall_count())
	hud.update_prompts(_action_prompts())
	max_depth_reached = max(max_depth_reached, _current_depth())
	_check_extraction()

## HUD layer line, and the layer's Stalker on the first descent into it.
func _check_layer() -> void:
	var layer := mine.layer_index_at_world(player.global_position)
	var nest_calmed := layer == NEST_LAYER and nest_destroyed
	var hazard: String = mine.hazard_text(layer, not nest_calmed)
	var line: String = Progress.layer_name(layer) + (": " + hazard if hazard != "" else "")
	hud.update_layer(line + ("  - CARRYING THE HEART" if carrying_heart else "") + "  (depth %d)" % _current_depth())
	if mine.LAYERS[layer].stalker and not _stalkers_woken.has(layer) and not nest_calmed:
		_stalkers_woken[layer] = true
		_wake_stalker(layer)

## One Stalker, off to one side in the dark, held out of the quiet layers.
func _wake_stalker(layer: int) -> void:
	var hunter: Stalker = StalkerScene.instantiate()
	hunter.player = player
	hunter.run_base = run_base
	# Below the quiet floor by a tile and a strike's reach, so a player
	# standing on the boundary row is out of range.
	hunter.min_y = mine.cell_to_world(Vector2i(0, mine.quiet_floor_row())).y + mine.TILE_SIZE + Stalker.ATTACK_RANGE
	var side := -1 if randf() < 0.5 else 1
	hunter.global_position = player.global_position + Vector2(side * STALKER_SPAWN_TILES * mine.TILE_SIZE, 0)
	add_child(hunter)
	if layer == NEST_LAYER:
		deep_stalker = hunter

## Taking the Heart: loud, and the mine collapses faster until the run ends.
func take_heart() -> void:
	carrying_heart = true
	noise_meter.add_noise(HEART_NOISE, player.global_position)
	mine.decay_multiplier *= HEART_CARRY_DECAY
	Sfx.play("collapse")
	hud.show_message("The mine shudders awake. Get the Heart to the surface!")

func _check_debug_keys() -> void:
	for key in DEBUG_KEYS:
		var pressed := Input.is_physical_key_pressed(key)
		if pressed and not _debug_keys_down.get(key, false):
			match key:
				KEY_I: debug_toggle_god()
				KEY_O: player.currency += DEBUG_ORE
				KEY_U: player.light.fuel = player.light.max_fuel
				KEY_N: debug_next_event()
				KEY_K: debug_next_layer()
				KEY_M: debug_toggle_reveal()
		_debug_keys_down[key] = pressed

func debug_toggle_god() -> void:
	player.invincible = not player.invincible
	hud.show_message("God mode " + ("on" if player.invincible else "off"))

## Teleports to the next event room, in the order the mine placed them.
func debug_next_event() -> void:
	if mine.event_rooms.is_empty():
		return
	var room: Dictionary = mine.event_rooms[_debug_event_index % mine.event_rooms.size()]
	_debug_event_index += 1
	player.global_position = mine.cell_to_world(room.cell + Vector2i(-2, 0))
	player.velocity = Vector2.ZERO
	hud.show_message("Teleported to the %s" % room.kind)

## Teleports into a cave in the next layer down; from the last layer, back
## to the base.
func debug_next_layer() -> void:
	var next := mine.layer_index_at_world(player.global_position) + 1
	if next >= mine.LAYERS.size():
		player.global_position = run_base.global_position
		return
	var cell := mine.take_floor_cell_in_layer(next)
	if cell.x >= 0:
		player.global_position = mine.cell_to_world(cell)
		player.velocity = Vector2.ZERO

func debug_toggle_reveal() -> void:
	var dark := $CanvasModulate as CanvasModulate
	dark.visible = not dark.visible

func on_nest_destroyed() -> void:
	nest_destroyed = true
	if is_instance_valid(deep_stalker):
		deep_stalker.queue_free()
	hud.show_message("The nest is ash. The deep goes quiet.")

func _on_gas_released(world_pos: Vector2) -> void:
	var cloud: GasCloud = GasCloudScene.instantiate()
	cloud.player = player
	cloud.global_position = world_pos
	add_child(cloud)
	noise_meter.add_noise(GasCloud.RELEASE_NOISE, world_pos)

## Depth in tiles below the surface crust, for the run summary. Never
## negative even if the player is still above the crust at run start.
func _current_depth() -> int:
	var cell := mine.world_to_cell(player.global_position)
	return max(0, cell.y - mine.SURFACE_ROWS)

func _action_prompts() -> Array:
	var prompts: Array = []
	if player.in_the_dark():
		prompts.append("Too dark to dig")
	if _near_base():
		if run_base.needs_repair():
			if player.currency < run_base.repair_cost():
				prompts.append("Repair needs %d ore" % run_base.repair_cost())
			elif run_base.repair_progress > 0.0:
				prompts.append("Repairing %d%%" % int(run_base.repair_progress * 100))
			else:
				prompts.append("F (hold): repair, %d ore" % run_base.repair_cost())
		prompts.append("B: fortify, %d ore/tile" % run_base.wall_cost())
		if not run_base.has_beacon:
			prompts.append("2: beacon, %d ore" % run_base.BEACON_ORE_COST)
		if not run_base.has_bell:
			prompts.append("3: bell, %d ore" % run_base.BELL_ORE_COST)
	if not _at_surface() and player.currency >= SUPPORT_ORE_COST:
		prompts.append("1: support, %d ore" % SUPPORT_ORE_COST)
	if _can_plant():
		prompts.append("P: plant base here")
	if _at_surface():
		prompts.append("E: extract")
	else:
		var event := _nearest_event()
		if event and event.prompt(self) != "":
			prompts.append(event.prompt(self))
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
		noise_meter.add_noise(BASE_PLANT_NOISE, player.global_position)
	_plant_key_was_pressed = pressed

## Number keys build (milestone 32), paid from this run's ore: 1 a
## support beam where you stand, 2 a beacon and 3 an alarm bell at the
## base (one each per run). The hub reads these keys only while paused.
func _check_builds() -> void:
	for key in [KEY_1, KEY_2, KEY_3]:
		var pressed := Input.is_physical_key_pressed(key)
		if pressed and not _build_keys_down.get(key, false):
			match key:
				KEY_1: build_support()
				KEY_2: build_beacon()
				KEY_3: build_bell()
		_build_keys_down[key] = pressed

func build_support() -> bool:
	if _at_surface() or not player.is_on_floor() or player.currency < SUPPORT_ORE_COST:
		return false
	var support: Support = SupportScene.instantiate()
	mine.add_child(support)
	support.global_position = player.global_position
	_pay_for_build(SUPPORT_ORE_COST)
	return true

func build_beacon() -> bool:
	if not _near_base() or run_base.has_beacon or player.currency < run_base.BEACON_ORE_COST:
		return false
	run_base.build_beacon()
	_pay_for_build(run_base.BEACON_ORE_COST)
	return true

func build_bell() -> bool:
	if not _near_base() or run_base.has_bell or player.currency < run_base.BELL_ORE_COST:
		return false
	run_base.build_bell()
	_pay_for_build(run_base.BELL_ORE_COST)
	return true

func _pay_for_build(cost: int) -> void:
	player.currency -= cost
	noise_meter.add_noise(run_base.BUILD_NOISE, player.global_position)
	Sfx.play("place")

## With a bell at the base, noise past BELL_WARNING_FRACTION of the
## Burrower threshold rings once and turns the HUD noise line red.
func _check_bell() -> void:
	var loud := run_base.has_bell and noise_meter.noise >= noise_meter.threshold * BELL_WARNING_FRACTION
	if loud and not _bell_ringing:
		Sfx.play("alarm", -4.0)
	_bell_ringing = loud
	hud.set_noise_warning(loud)

## L sets a lamp down where the player stands.
func _check_lamp() -> void:
	var pressed := Input.is_physical_key_pressed(KEY_L)
	if pressed and not _lamp_key_was_pressed and lamps_left > 0 and player.is_on_floor():
		lamps_left -= 1
		Sfx.play("place")
		var lamp: Lamp = LampScene.instantiate()
		lamp.global_position = player.global_position
		mine.add_child(lamp)
		noise_meter.add_noise(LAMP_PLACE_NOISE, lamp.global_position)
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
		noise_meter.add_noise(run_base.REPAIR_NOISE, run_base.global_position)

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
			noise_meter.add_noise(count * run_base.WALL_NOISE, run_base.global_position)
	_fortify_key_was_pressed = pressed

func _check_extraction() -> void:
	var extract_pressed := Input.is_physical_key_pressed(KEY_E)
	if extract_pressed and not _extract_key_was_pressed:
		if _at_surface():
			_extract()
		elif _nearest_event():
			_nearest_event().use(self)
	_extract_key_was_pressed = extract_pressed

func _extract() -> void:
	run_ended = true
	var title := "Extracted!"
	if carrying_heart:
		player.currency += HEART_ORE
		progress.hearts_claimed += 1
		title = "The Heart is yours!"
	progress.banked_ore += player.currency
	_record_run("Heart claimed" if carrying_heart else "Extracted")
	hud.update_banked(progress.banked_ore)
	var rescued := _escorts().map(func(m): return {"name": m.miner_name, "type": m.npc_type, "found_in": m.found_in})
	var notes := progress.end_run(rescued, [], true) + ["Seed: %d" % mine.mine_seed]
	hud.show_run_summary(title, true, player.currency, max_depth_reached, progress, notes)
	get_tree().paused = true

func _record_run(result: String) -> void:
	progress.record_run({
		"result": result, "seconds": int(run_seconds), "depth": max_depth_reached,
		"ore": player.currency, "burrowers": burrowers_spawned, "waves": waves_spawned,
		"hits": player.hits_by.duplicate(), "seed": mine.mine_seed,
	})

## The next journal page; the last one also marks where the old shaft's
## collapse ends (milestone 51), so the way home from below can be found.
func read_journal_page() -> String:
	var text := progress.read_journal_page()
	if progress.journal_read == Progress.JOURNAL.size() and text.begins_with("Journal "):
		text += "\nIn the margin: the old shaft ends in a collapse at depth %d. Dig a stair up beside it." % (mine.shaft_end_row - MineGrid.SURFACE_ROWS)
	return text

func _on_tile_dug(noise_amount: float, world_pos: Vector2) -> void:
	noise_meter.add_noise(noise_amount, world_pos)

## Stalkers within hearing of a loud act close in (milestone 50).
func _on_noise_made(position: Vector2, amount: float) -> void:
	if amount < Stalker.LOUD_NOISE:
		return
	for stalker in get_tree().get_nodes_in_group("stalkers"):
		if stalker.global_position.distance_to(position) / mine.TILE_SIZE <= Stalker.HEARING_TILES:
			stalker.alert()

func _on_noise_threshold() -> void:
	Sfx.play("alarm", -6.0) # something heard you
	burrowers_spawned += 1
	_spawn_burrower(mine.world_to_cell(player.global_position))

## The mine's clock sends one at the base, whatever the player did.
func _spawn_wave() -> void:
	waves_spawned += 1
	_spawn_burrower(mine.world_to_cell(run_base.global_position))

## Surfaces a Burrower BURROWER_SPAWN_OFFSET_TILES below `origin`, bound for
## the base.
func _spawn_burrower(origin: Vector2i) -> void:
	var burrower: Burrower = BurrowerScene.instantiate()
	burrower.mine = mine
	burrower.player = player
	burrower.target = run_base
	burrower.global_position = _burrower_spawn_position(origin)
	add_child(burrower)

## Below `origin`, clamped inside the bedrock walls and floor and never
## above the quiet floor (nothing in the mine's creatures lives there).
func _burrower_spawn_position(origin: Vector2i) -> Vector2:
	var cell := origin + Vector2i(0, BURROWER_SPAWN_OFFSET_TILES)
	cell.x = clamp(cell.x, 1, mine.GRID_WIDTH - 2)
	cell.y = clamp(cell.y, maxi(mine.SURFACE_ROWS, mine.quiet_floor_row() + 1), mine.GRID_HEIGHT - 2)
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
	var result := "Base fell" if title == "Base Fell" else "Died (%s)" % (player.last_hit_by if player.last_hit_by != "" else "unknown")
	_record_run(result)
	# PRD: miners lost during an escort are stranded where they were lost,
	# and crew left at the base are stranded in the base's layer.
	var newly_stranded := (_escorts() + crew_at_base).map(func(m): return {
		"name": m.miner_name, "type": m.npc_type, "layer": mine.layer_index_at_world(m.global_position)})
	var notes := progress.end_run([], newly_stranded, false) + ["Seed: %d" % mine.mine_seed]
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

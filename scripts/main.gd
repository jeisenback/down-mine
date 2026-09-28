extends Node2D
class_name Main

# How close to the run base counts as "there" for extracting.
const EXTRACTION_RADIUS := 32.0

# Burrowers surface this far below the player - the noise came from
# there - and tunnel to the base, so the player can race or chase them.
const BURROWER_SPAWN_OFFSET_TILES := 10
const BurrowerScene := preload("res://scenes/Burrower.tscn")

const LostMinerScene := preload("res://scenes/LostMiner.tscn")
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
var progress: Progress
var lost_miners: Array[LostMiner] = []

func _ready() -> void:
	player.mine = mine
	stalker.player = player
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
	progress.apply_to(player, noise_meter)
	hud.update_banked(progress.banked_ore)
	_configure_camera_limits()
	_spawn_lost_miners()

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

func _spawn_miner(miner_name: String, npc_type: String, cell: Vector2i, was_stranded: bool) -> void:
	var miner: LostMiner = LostMinerScene.instantiate()
	miner.player = player
	miner.miner_name = miner_name
	miner.npc_type = npc_type
	miner.was_stranded = was_stranded
	miner.shirt_color = MINER_COLORS.get(miner_name, Color(1, 1, 1))
	miner.global_position = mine.cell_to_world(cell)
	miner.picked_up.connect(_on_miner_picked_up.bind(miner))
	add_child(miner)
	lost_miners.append(miner)

func _on_miner_picked_up(miner: LostMiner) -> void:
	var escorts := _escorts()
	miner.follow_delay = LostMiner.FOLLOW_DELAY_POINTS * escorts.size()
	hud.update_escort(", ".join(escorts.map(func(m): return "%s (%s)" % [m.miner_name, Progress.NPC_TYPES[m.npc_type].label])))

func _escorts() -> Array:
	return lost_miners.filter(func(m): return m.following)

## The PRD's in-mine "signs" for stranded miners, simplified: while the
## player is in a stranded miner's layer, an arrow in their shirt colour
## points to the nearest one. The hub already told them which layer.
func _update_stranded_compass() -> void:
	var player_layer := mine.layer_index_at_world(player.global_position)
	var nearest: LostMiner = null
	for miner in lost_miners:
		if miner.was_stranded and not miner.following and mine.layer_index_at_world(miner.global_position) == player_layer:
			if nearest == null or player.global_position.distance_to(miner.global_position) < player.global_position.distance_to(nearest.global_position):
				nearest = miner
	if nearest == null:
		hud.hide_stranded_compass()
	else:
		hud.update_stranded_compass(nearest.global_position - player.global_position, nearest.shirt_color)

func _configure_camera_limits() -> void:
	var camera := player.get_node("Camera2D") as Camera2D
	camera.limit_right = mine.GRID_WIDTH * mine.TILE_SIZE
	camera.limit_bottom = mine.GRID_HEIGHT * mine.TILE_SIZE

func _process(_delta: float) -> void:
	if run_ended:
		return
	hud.update_fuel(player.light.fuel_fraction())
	hud.update_health(player.health)
	hud.update_compass(run_base.global_position - player.global_position)
	_update_stranded_compass()
	hud.update_currency(player.currency)
	hud.update_base(run_base.health, run_base.MAX_HEALTH, get_tree().get_nodes_in_group("burrowers").size() > 0)
	max_depth_reached = max(max_depth_reached, _current_depth())
	_check_extraction()

## Depth in tiles below the surface crust, for the run summary. Never
## negative even if the player is still above the crust at run start.
func _current_depth() -> int:
	var cell := mine.world_to_cell(player.global_position)
	return max(0, cell.y - mine.SURFACE_ROWS)

func _check_extraction() -> void:
	var extract_pressed := Input.is_physical_key_pressed(KEY_E)
	var near_base := player.global_position.distance_to(run_base.global_position) < EXTRACTION_RADIUS
	if extract_pressed and not _extract_key_was_pressed and near_base:
		_extract()
	_extract_key_was_pressed = extract_pressed

func _extract() -> void:
	run_ended = true
	progress.banked_ore += player.currency
	progress.save()
	hud.update_banked(progress.banked_ore)
	var rescued := _escorts().map(func(m): return {"name": m.miner_name, "type": m.npc_type})
	var notes := progress.end_run(rescued, [])
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
	# PRD: miners lost during an escort are stranded where they were lost.
	var newly_stranded := _escorts().map(func(m): return {
		"name": m.miner_name, "type": m.npc_type, "layer": mine.layer_index_at_world(m.global_position)})
	var notes := progress.end_run([], newly_stranded)
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

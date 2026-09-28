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
var lost_miner: LostMiner

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
	progress = Progress.load_saved()
	progress.apply_to(player)
	hud.update_banked(progress.banked_ore)
	_configure_camera_limits()
	_spawn_lost_miner()

## One lost miner per run, named from those not already on the roster.
func _spawn_lost_miner() -> void:
	if mine.lost_miner_cell.x < 0:
		return
	var taken := progress.roster.map(func(m): return m.name)
	var names := MINER_COLORS.keys().filter(func(n): return not n in taken)
	if names.is_empty():
		names = MINER_COLORS.keys()
	lost_miner = LostMinerScene.instantiate()
	lost_miner.player = player
	lost_miner.miner_name = names.pick_random()
	lost_miner.shirt_color = MINER_COLORS[lost_miner.miner_name]
	lost_miner.global_position = mine.cell_to_world(mine.lost_miner_cell)
	lost_miner.picked_up.connect(func(): hud.update_escort(lost_miner.miner_name))
	add_child(lost_miner)

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
	var notes: Array = []
	if _escorting():
		progress.rescue(lost_miner.miner_name, lost_miner.npc_type)
		notes.append("Rescued %s - joins the roster" % lost_miner.miner_name)
	hud.show_run_summary("Extracted!", true, player.currency, max_depth_reached, progress, notes)
	get_tree().paused = true

func _escorting() -> bool:
	return lost_miner != null and lost_miner.following

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
	var notes: Array = []
	if _escorting():
		notes.append("%s was lost in the dark" % lost_miner.miner_name)
	hud.show_run_summary(title, false, player.currency, max_depth_reached, progress, notes)
	get_tree().paused = true

## Reloading the scene is the whole reset: the mine regenerates in
## Mine._ready() and every per-run value (light, noise, run ore) starts
## fresh. Only Progress (bank + upgrades) survives, via the save file.
func _start_new_run() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()

## Hub purchase from the run summary. Upgrades take effect next run,
## when Progress.apply_to() runs on the fresh player.
func _on_upgrade_requested(id: String) -> void:
	if progress.try_buy(id):
		hud.update_banked(progress.banked_ore)
		hud.refresh_hub(progress)

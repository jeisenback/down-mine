extends Node2D
class_name Main

# How close to the run base counts as "there" for extracting.
const EXTRACTION_RADIUS := 32.0

# Lifetime ore total, carried between runs. Only extraction adds to it;
# a failed run's ore is lost. The hub will spend from this later.
const SAVE_PATH := "user://save.cfg"

@onready var mine: MineGrid = $Mine
@onready var run_base: RunBase = $RunBase
@onready var player: Player = $Player
@onready var stalker: Stalker = $Stalker
@onready var noise_meter: NoiseMeter = $NoiseMeter
@onready var hud: HUD = $HUD

var run_ended: bool = false
var max_depth_reached: int = 0
var _extract_key_was_pressed: bool = false
var banked_ore: int = 0

func _ready() -> void:
	player.mine = mine
	stalker.player = player
	mine.tile_dug.connect(_on_tile_dug)
	player.made_noise.connect(_on_tile_dug) # same amount->noise_meter path, source doesn't matter
	noise_meter.noise_changed.connect(hud.update_noise)
	noise_meter.threshold_reached.connect(_on_noise_threshold)
	player.died.connect(_on_player_died)
	hud.new_run_requested.connect(_start_new_run)
	banked_ore = _load_banked_ore()
	hud.update_banked(banked_ore)
	_configure_camera_limits()

func _configure_camera_limits() -> void:
	var camera := player.get_node("Camera2D") as Camera2D
	camera.limit_right = mine.GRID_WIDTH * mine.TILE_SIZE
	camera.limit_bottom = mine.GRID_HEIGHT * mine.TILE_SIZE

func _process(_delta: float) -> void:
	if run_ended:
		return
	hud.update_fuel(player.light.fuel_fraction())
	hud.update_compass(run_base.global_position - player.global_position)
	hud.update_currency(player.currency)
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
	banked_ore += player.currency
	_save_banked_ore(banked_ore)
	hud.update_banked(banked_ore)
	hud.show_run_summary(true, player.currency, max_depth_reached, banked_ore)
	get_tree().paused = true

func _on_tile_dug(noise_amount: float) -> void:
	noise_meter.add_noise(noise_amount)

func _on_noise_threshold() -> void:
	print("Noise threshold reached — base attack would trigger here.")

func _on_player_died() -> void:
	run_ended = true
	hud.show_run_summary(false, player.currency, max_depth_reached, banked_ore)
	get_tree().paused = true

## Reloading the scene is the whole reset: the mine regenerates in
## Mine._ready() and every per-run value (light, noise, run ore) starts
## fresh. Only banked_ore survives, via the save file.
func _start_new_run() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()

func _load_banked_ore() -> int:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return 0
	return int(config.get_value("bank", "ore", 0))

func _save_banked_ore(amount: int) -> void:
	var config := ConfigFile.new()
	config.load(SAVE_PATH) # keep any other sections once there are some
	config.set_value("bank", "ore", amount)
	config.save(SAVE_PATH)

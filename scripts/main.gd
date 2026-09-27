extends Node2D
class_name Main

@onready var mine: MineGrid = $Mine
@onready var player: Player = $Player
@onready var stalker: Stalker = $Stalker
@onready var noise_meter: NoiseMeter = $NoiseMeter
@onready var hud: HUD = $HUD

func _ready() -> void:
	player.mine = mine
	stalker.player = player
	mine.tile_dug.connect(_on_tile_dug)
	noise_meter.noise_changed.connect(hud.update_noise)
	noise_meter.threshold_reached.connect(_on_noise_threshold)
	player.died.connect(_on_player_died)

func _process(_delta: float) -> void:
	hud.update_fuel(player.light.fuel_fraction())

func _on_tile_dug(noise_amount: float) -> void:
	noise_meter.add_noise(noise_amount)

func _on_noise_threshold() -> void:
	print("Noise threshold reached — base attack would trigger here.")

func _on_player_died() -> void:
	print("Player died — run over (milestone 1 stub).")
	get_tree().paused = true

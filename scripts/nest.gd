extends Node2D
class_name Nest

## A Stalker nest (milestone 37, a mine event) in the deep. Flaring the
## lantern close by for BURN_SECONDS burns it - loud - and with it goes
## the deep rock's second Stalker for the rest of the run.
const BURN_RANGE := 40.0
const BURN_SECONDS := 2.0
const BURN_NOISE := 20.0

var main: Node
var burn: float = 0.0
var destroyed: bool = false

func _ready() -> void:
	add_to_group("mine_events")

func _process(delta: float) -> void:
	if destroyed:
		return
	var player: Player = main.player
	if player.light.is_flaring and player.global_position.distance_to(global_position) < BURN_RANGE:
		burn += delta
		if burn >= BURN_SECONDS:
			_destroy()

func prompt(_main: Node) -> String:
	if burn > 0.0:
		return "Burning the nest %d%%" % int(burn / BURN_SECONDS * 100)
	return "Shift (flare): burn the Stalker nest"

func use(_main: Node) -> void:
	pass # flaring does it, not E

func _destroy() -> void:
	destroyed = true
	remove_from_group("mine_events")
	$Art.art.pose = 1.0 # eggs become a scorched patch
	main.noise_meter.add_noise(BURN_NOISE, global_position)
	Sfx.play("hiss")
	main.on_nest_destroyed()

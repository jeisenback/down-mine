extends Node

## A stand-in for Main in art wiring tests: the few members events touch.
var player: Player
var noise_meter: NoiseMeter
var rode_from: float = -1.0

func ride_to_surface(x: float) -> void:
	rode_from = x

func on_nest_destroyed() -> void:
	pass

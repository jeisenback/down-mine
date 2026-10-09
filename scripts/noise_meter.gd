extends Node
class_name NoiseMeter

signal threshold_reached
signal noise_changed(value: float, fraction: float)

@export var max_noise: float = 100.0
@export var decay_rate: float = 8.0
@export var threshold: float = 100.0
## Scales all incoming noise; a noise-type crew member lowers it.
var noise_multiplier: float = 1.0
## Returns true while nothing can hear: noise still shows on the meter's
## path but adds nothing (the quiet layers at the top of the mine). Main
## sets it; pull-based so a teleport is honoured on the very next call.
var quiet_check: Callable = func(): return false

var noise: float = 0.0

func _process(delta: float) -> void:
	if noise > 0.0:
		noise = max(0.0, noise - decay_rate * delta)
		noise_changed.emit(noise, noise / max_noise)

func add_noise(amount: float) -> void:
	if quiet_check.call():
		amount = 0.0
	noise = min(max_noise, noise + amount * noise_multiplier)
	noise_changed.emit(noise, noise / max_noise)
	# Filling the meter summons something, and the meter empties: more noise
	# summons more. (It used to stay pinned at the cap while the player kept
	# digging, so nonstop noise brought only one Burrower.)
	if noise >= threshold:
		noise = 0.0
		noise_changed.emit(noise, 0.0)
		threshold_reached.emit()

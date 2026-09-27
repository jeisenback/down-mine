extends Node
class_name NoiseMeter

signal threshold_reached
signal noise_changed(value: float, fraction: float)

@export var max_noise: float = 100.0
@export var decay_rate: float = 8.0
@export var threshold: float = 100.0

var noise: float = 0.0
var _triggered: bool = false

func _process(delta: float) -> void:
	if noise > 0.0:
		noise = max(0.0, noise - decay_rate * delta)
		noise_changed.emit(noise, noise / max_noise)

func add_noise(amount: float) -> void:
	noise = min(max_noise, noise + amount)
	noise_changed.emit(noise, noise / max_noise)
	if noise >= threshold and not _triggered:
		_triggered = true
		threshold_reached.emit()
	elif noise < threshold:
		_triggered = false

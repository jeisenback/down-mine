extends CanvasLayer
class_name HUD

@onready var fuel_label: Label = $Margin/VBox/FuelLabel
@onready var noise_label: Label = $Margin/VBox/NoiseLabel
@onready var noise_bar: ProgressBar = $Margin/VBox/NoiseBar

func update_fuel(fraction: float) -> void:
	fuel_label.text = "Light: %d%%" % int(fraction * 100)

func update_noise(value: float, fraction: float) -> void:
	noise_label.text = "Noise: %d" % int(value)
	noise_bar.value = fraction * 100.0

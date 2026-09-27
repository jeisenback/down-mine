extends CanvasLayer
class_name HUD

const COMPASS_MARGIN := 40.0

@onready var fuel_label: Label = $Margin/VBox/FuelLabel
@onready var noise_label: Label = $Margin/VBox/NoiseLabel
@onready var noise_bar: ProgressBar = $Margin/VBox/NoiseBar
@onready var compass: Node2D = $Compass

func update_fuel(fraction: float) -> void:
	fuel_label.text = "Light: %d%%" % int(fraction * 100)

func update_noise(value: float, fraction: float) -> void:
	noise_label.text = "Noise: %d" % int(value)
	noise_bar.value = fraction * 100.0

## Points an arrow toward the run base from anywhere in the mine, clamped
## to a circle near the screen edge (an off-screen-indicator, not tied to
## the player's actual on-screen position, since this is a CanvasLayer in
## screen space). to_target is world-space (target - player), so the
## screen-space direction matches it directly since the camera doesn't
## rotate.
func update_compass(to_target: Vector2) -> void:
	if to_target.length_squared() < 1.0:
		compass.visible = false
		return
	compass.visible = true
	var direction := to_target.normalized()
	var viewport_size := get_viewport().get_visible_rect().size
	var center := viewport_size / 2.0
	var radius: float = max(0.0, min(center.x, center.y) - COMPASS_MARGIN)
	compass.position = center + direction * radius
	compass.rotation = direction.angle()

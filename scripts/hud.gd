extends CanvasLayer
class_name HUD

## Emitted when the player asks for another run from the run summary.
## The HUD runs while the tree is paused (see _ready) so it can hear this.
signal new_run_requested

const COMPASS_MARGIN := 40.0
# Below this distance, hide the arrow instead of pointing it - arctan2 of
# a near-zero direction vector is extremely sensitive to small position
# jitter, so without a real "arrived" radius the arrow spins erratically
# as soon as the player gets close, not just when exactly on top of it.
const ARRIVAL_RADIUS := 32.0

@onready var fuel_label: Label = $Margin/VBox/FuelLabel
@onready var noise_label: Label = $Margin/VBox/NoiseLabel
@onready var noise_bar: ProgressBar = $Margin/VBox/NoiseBar
@onready var ore_label: Label = $Margin/VBox/OreLabel
@onready var banked_label: Label = $Margin/VBox/BankedLabel
@onready var compass: Node2D = $Compass
@onready var run_summary: ColorRect = $RunSummary
@onready var run_summary_label: Label = $RunSummary/SummaryLabel

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func _unhandled_input(event: InputEvent) -> void:
	if not run_summary.visible:
		return
	var key := event as InputEventKey
	if key and key.pressed and not key.echo and key.physical_keycode in [KEY_ENTER, KEY_KP_ENTER]:
		new_run_requested.emit()

func update_fuel(fraction: float) -> void:
	fuel_label.text = "Light: %d%%" % int(fraction * 100)

func update_noise(value: float, fraction: float) -> void:
	noise_label.text = "Noise: %d" % int(value)
	noise_bar.value = fraction * 100.0

func update_currency(amount: int) -> void:
	ore_label.text = "Ore: %d" % amount

func update_banked(amount: int) -> void:
	banked_label.text = "Banked: %d" % amount

## Points an arrow toward the run base from anywhere in the mine, clamped
## to a circle near the screen edge (an off-screen-indicator, not tied to
## the player's actual on-screen position, since this is a CanvasLayer in
## screen space). to_target is world-space (target - player), so the
## screen-space direction matches it directly since the camera doesn't
## rotate.
func update_compass(to_target: Vector2) -> void:
	if to_target.length_squared() < ARRIVAL_RADIUS * ARRIVAL_RADIUS:
		compass.visible = false
		return
	compass.visible = true
	var direction := to_target.normalized()
	var viewport_size := get_viewport().get_visible_rect().size
	var center := viewport_size / 2.0
	var radius: float = max(0.0, min(center.x, center.y) - COMPASS_MARGIN)
	compass.position = center + direction * radius
	compass.rotation = direction.angle()

## Right now a run only ever ends by dying or reaching this. Without a
## visible outcome it just looked like the game froze - this makes an
## ending actually read as an ending.
func show_run_summary(success: bool, currency: int, depth: int, banked_total: int) -> void:
	var title := "Extracted!" if success else "Run Failed"
	var currency_line := "Ore banked: %d" % currency if success else "Ore lost: %d" % currency
	run_summary_label.text = "%s\n%s\nDepth reached: %d tiles\nTotal banked: %d\n\nPress Enter for a new run" % [
		title, currency_line, depth, banked_total]
	run_summary.visible = true

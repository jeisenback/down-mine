extends Node
class_name NoiseMeter

signal threshold_reached
signal noise_changed(value: float, fraction: float)
## A sound the Stalker may hear: where it was made and how loud (milestone
## 50). Not emitted for sounds in a quiet layer.
signal noise_made(position: Vector2, amount: float)

## The base fills the Burrower meter by distance: full at the base, nothing
## at this many tiles.
const BASE_HEARING_TILES := 80.0

@export var max_noise: float = 100.0
@export var decay_rate: float = 8.0
@export var threshold: float = 100.0
## Scales all incoming noise; a noise-type crew member lowers it.
var noise_multiplier: float = 1.0
## Whether nothing can hear at a world position: a sound made there adds
## nothing and alerts nothing (the quiet layers at the top of the mine).
## Main sets it; pull-based so a teleport is honoured on the very next call.
var quiet_at: Callable = func(_pos: Vector2): return false
## Where the base listens, in world space. Main sets it; pull-based so
## replanting the base (P) moves the listener at once.
var base_position: Callable = func(): return Vector2.ZERO

var noise: float = 0.0

func _process(delta: float) -> void:
	if noise > 0.0:
		noise = max(0.0, noise - decay_rate * delta)
		noise_changed.emit(noise, noise / max_noise)

## 1.0 at the base falling linearly to 0.0 at BASE_HEARING_TILES.
static func hearing(tiles: float) -> float:
	return clampf(1.0 - tiles / BASE_HEARING_TILES, 0.0, 1.0)

## A sound of `amount` made at world `position`. The base hears it by
## distance; the Stalker is told where it was made.
func add_noise(amount: float, position: Vector2) -> void:
	if quiet_at.call(position):
		return
	if amount > 0.0:
		noise_made.emit(position, amount)
	var tiles: float = position.distance_to(base_position.call()) / MineGrid.TILE_SIZE
	noise = min(max_noise, noise + amount * hearing(tiles) * noise_multiplier)
	noise_changed.emit(noise, noise / max_noise)
	# Filling the meter summons something, and the meter empties: more noise
	# summons more. (It used to stay pinned at the cap while the player kept
	# digging, so nonstop noise brought only one Burrower.)
	if noise >= threshold:
		noise = 0.0
		noise_changed.emit(noise, 0.0)
		threshold_reached.emit()

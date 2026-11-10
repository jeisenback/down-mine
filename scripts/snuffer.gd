extends Node2D
class_name Snuffer

## The PRD's light-eating enemy: drifts through rock toward the placed
## light (lamps, the run base) furthest from the player - light spread
## too thin - and drains it dry. The player's light drives it off; only a
## flare hurts it, same rule as the Burrower.

const SPEED := 34.0
const FLEE_SPEED := 50.0
const DRAIN_RANGE := 12.0
const DRAIN_RATE := 30.0 # fuel/s: a lamp (90) lasts ~3s, the base (200) ~7s
const MAX_HEALTH := 1.0  # seconds of flare exposure
const RETARGET_INTERVAL := 1.0

var player: Player
var health: float = MAX_HEALTH
var _target: MineLight
var _retarget_timer: float = 0.0

@onready var art: ArtSprite = $Art

func _ready() -> void:
	add_to_group(Groups.SNUFFERS)

func _physics_process(delta: float) -> void:
	var from_player := global_position - player.global_position
	if from_player.length() < player.light.current_radius():
		if player.light.is_flaring:
			health -= delta
			if health <= 0.0:
				queue_free()
				return
		global_position += from_player.normalized() * FLEE_SPEED * delta
		_show_drain(false, Vector2.ZERO)
		return

	_retarget_timer -= delta
	if _retarget_timer <= 0.0 or not is_instance_valid(_target):
		_retarget_timer = RETARGET_INTERVAL
		_target = _pick_target()
	if _target == null:
		_show_drain(false, Vector2.ZERO)
		return
	var to_target := _target.global_position - global_position
	art.flip_h = to_target.x < 0.0
	if to_target.length() > DRAIN_RANGE:
		global_position += to_target.normalized() * SPEED * delta
		_show_drain(false, Vector2.ZERO)
	else:
		_target.fuel = max(0.0, _target.fuel - DRAIN_RATE * delta)
		_show_drain(true, to_target)

## The drawn core lights and a tether reaches for the light while it drains (the art is mirrored when
## the Snuffer faces left, so the tether's x is always drawn forward).
func _show_drain(draining: bool, to_target: Vector2) -> void:
	art.art.pose = 1.0 if draining else 0.0
	art.art.aim = Vector2(absf(to_target.x), to_target.y) if draining else Vector2.ZERO

func _pick_target() -> MineLight:
	var best: MineLight = null
	var best_distance := -1.0
	for light in get_tree().get_nodes_in_group(Groups.SNUFFABLE):
		if light.fuel <= 0.0:
			continue
		var d: float = light.global_position.distance_to(player.global_position)
		if d > best_distance:
			best = light
			best_distance = d
	return best

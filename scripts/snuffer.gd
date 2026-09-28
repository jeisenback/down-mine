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
const ANIM_FPS := 5.0
const FRAME_COUNT := 4

var player: Player
var health: float = MAX_HEALTH
var _target: MineLight
var _retarget_timer: float = 0.0
var _anim_time: float = 0.0

@onready var sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	add_to_group("snuffers")
	sprite.texture = PixelArt.keyed(sprite.texture)

func _physics_process(delta: float) -> void:
	_anim_time += delta
	sprite.frame = int(_anim_time * ANIM_FPS) % FRAME_COUNT

	var from_player := global_position - player.global_position
	if from_player.length() < player.light.current_radius():
		if player.light.is_flaring:
			health -= delta
			if health <= 0.0:
				queue_free()
				return
		global_position += from_player.normalized() * FLEE_SPEED * delta
		return

	_retarget_timer -= delta
	if _retarget_timer <= 0.0 or not is_instance_valid(_target):
		_retarget_timer = RETARGET_INTERVAL
		_target = _pick_target()
	if _target == null:
		return
	var to_target := _target.global_position - global_position
	sprite.flip_h = to_target.x < 0.0
	if to_target.length() > DRAIN_RANGE:
		global_position += to_target.normalized() * SPEED * delta
	else:
		_target.fuel = max(0.0, _target.fuel - DRAIN_RATE * delta)

func _pick_target() -> MineLight:
	var best: MineLight = null
	var best_distance := -1.0
	for light in get_tree().get_nodes_in_group("snuffable"):
		if light.fuel <= 0.0:
			continue
		var d: float = light.global_position.distance_to(player.global_position)
		if d > best_distance:
			best = light
			best_distance = d
	return best

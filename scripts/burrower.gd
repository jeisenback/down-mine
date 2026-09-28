extends Node2D
class_name Burrower

## The PRD's base-threatening enemy: spawned when the noise meter crosses
## its threshold, tunnels straight through rock to the run base and chews
## on it. Light is the only defence - the player's light slows it, and
## only a flare (which burns fuel 4x) actually hurts it, so stopping an
## attack always costs part of the run.

const SPEED := 28.0
const LIT_SPEED_MULTIPLIER := 0.4
const MAX_HEALTH := 1.5 # seconds of flare exposure
const ATTACK_RANGE := 14.0
const ATTACK_COOLDOWN := 2.0
const ANIM_FPS := 6.0
const FRAME_COUNT := 3

var mine: MineGrid
var player: Player
var target: RunBase
var health: float = MAX_HEALTH
var _attack_timer: float = 0.0
var _anim_time: float = 0.0

@onready var sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	add_to_group("burrowers")
	sprite.texture = PixelArt.keyed(sprite.texture)

func _physics_process(delta: float) -> void:
	_attack_timer = max(0.0, _attack_timer - delta)
	_anim_time += delta
	sprite.frame = int(_anim_time * ANIM_FPS) % FRAME_COUNT

	var in_player_light := global_position.distance_to(player.global_position) < player.light.current_radius()
	if in_player_light and player.light.is_flaring:
		health -= delta
		if health <= 0.0:
			queue_free()
			return

	var to_target := target.global_position - global_position
	sprite.flip_h = to_target.x < 0.0
	if to_target.length() <= ATTACK_RANGE:
		if _attack_timer <= 0.0:
			_attack_timer = ATTACK_COOLDOWN
			target.take_hit(1)
		return

	var speed := SPEED * (LIT_SPEED_MULTIPLIER if in_player_light else 1.0)
	global_position += to_target.normalized() * speed * delta
	mine.dig_cells([mine.world_to_cell(global_position)], false)

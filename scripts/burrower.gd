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
# The drawn mandibles stay wide for this long after a strike (milestone 53).
const STRIKE_POSE_SECONDS := 0.4
# A reinforced tile holds it for the base's wall_chew_time() (tier-dependent);
# plain rock is instant.
# Rhythm of threat (milestone 55): the base light fights back. Inside its
# radius a Burrower is slowed like it is in the player's light, and loses this
# much health a second times the light's fuel fraction (tripled while the player
# flares inside the light). A full light kills one in 10 s.
const BASE_LIGHT_DAMAGE_RATE := 0.15
const PRESENCE_FLARE_MULTIPLIER := 3.0

var mine: MineGrid
var player: Player
var target: RunBase
var health: float = MAX_HEALTH
var _attack_timer: float = 0.0
var _strike_timer: float = 0.0
var _chew_timer: float = 0.0

@onready var art: ArtSprite = $Art

## Health lost per second inside the base light at this fuel fraction.
static func base_light_damage_per_second(fuel_fraction: float, presence_flaring: bool) -> float:
	return BASE_LIGHT_DAMAGE_RATE * fuel_fraction * (PRESENCE_FLARE_MULTIPLIER if presence_flaring else 1.0)

func _ready() -> void:
	add_to_group("burrowers")

func _physics_process(delta: float) -> void:
	_attack_timer = max(0.0, _attack_timer - delta)
	_strike_timer = maxf(0.0, _strike_timer - delta)
	if _strike_timer <= 0.0:
		art.art.pose = 0.0

	var in_player_light := global_position.distance_to(player.global_position) < player.light.current_radius()
	if in_player_light and player.light.is_flaring:
		health -= delta
		if health <= 0.0:
			queue_free()
			return

	var base_radius: float = target.light.current_radius()
	var in_base_light := global_position.distance_to(target.global_position) < base_radius
	if in_base_light:
		var presence := player.light.is_flaring and player.global_position.distance_to(target.global_position) < base_radius
		health -= base_light_damage_per_second(target.light.fuel_fraction(), presence) * delta
		if health <= 0.0:
			queue_free()
			return

	var to_target := target.global_position - global_position
	art.flip_h = to_target.x < 0.0
	if to_target.length() <= ATTACK_RANGE:
		if _attack_timer <= 0.0:
			_attack_timer = ATTACK_COOLDOWN
			_strike_timer = STRIKE_POSE_SECONDS
			art.art.pose = 1.0
			target.take_hit(1)
		return

	var speed := SPEED * (LIT_SPEED_MULTIPLIER if in_player_light or in_base_light else 1.0)
	var next_position := global_position + to_target.normalized() * speed * delta
	var next_cell := mine.world_to_cell(next_position)
	if mine.is_wall(next_cell):
		_chew_timer += delta
		if _chew_timer >= target.wall_chew_time():
			_chew_timer = 0.0
			mine.dig_cells([next_cell], false)
		return
	global_position = next_position
	mine.dig_cells([next_cell], false)

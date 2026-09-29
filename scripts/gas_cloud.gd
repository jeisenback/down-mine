extends Node2D
class_name GasCloud

## Released by digging out a gas rock in the Stone layer (milestone 29).
## Lingers a few seconds; standing in it costs health on a steady tick.
## Fades out as it thins.

const RADIUS := 32.0 # 2 tiles
const LIFE_SECONDS := 8.0
const DAMAGE_INTERVAL := 1.5
const RELEASE_NOISE := 5.0 # the hiss

var player: Player
var _age: float = 0.0
var _damage_timer: float = 0.0

@onready var haze: Sprite2D = $Haze

func _ready() -> void:
	add_to_group("gas_clouds")
	Sfx.play("hiss")

func _process(delta: float) -> void:
	_age += delta
	if _age >= LIFE_SECONDS:
		queue_free()
		return
	haze.modulate.a = 1.0 - _age / LIFE_SECONDS
	if contains(player.global_position):
		_damage_timer += delta
		if _damage_timer >= DAMAGE_INTERVAL:
			_damage_timer = 0.0
			player.take_hit(1, "gas")
	else:
		_damage_timer = 0.0

func contains(world_pos: Vector2) -> bool:
	return global_position.distance_to(world_pos) < RADIUS

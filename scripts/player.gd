extends CharacterBody2D
class_name Player

signal died

const SPEED := 120.0
const GRAVITY := 700.0
const DIG_COOLDOWN := 0.25
const MAX_HEALTH := 3

@onready var light: MineLight = $MineLight
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

var mine: MineGrid
var dig_timer: float = 0.0
var facing: int = 1
var health: int = MAX_HEALTH

func _physics_process(delta: float) -> void:
	dig_timer = max(0.0, dig_timer - delta)

	var input_dir := 0.0
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
		input_dir -= 1.0
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
		input_dir += 1.0
	if input_dir != 0.0:
		facing = int(sign(input_dir))
	velocity.x = input_dir * SPEED

	if not is_on_floor():
		velocity.y += GRAVITY * delta
	else:
		velocity.y = 0.0

	var digging_down := Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN)
	var digging_forward := Input.is_physical_key_pressed(KEY_SPACE)
	if digging_down:
		_try_dig(Vector2.DOWN)
	elif digging_forward:
		_try_dig(Vector2(facing, 0))

	light.set_flaring(Input.is_physical_key_pressed(KEY_SHIFT))

	move_and_slide()

func _try_dig(direction: Vector2) -> void:
	if dig_timer > 0.0 or mine == null:
		return
	# Reach just past the collision box's edge into the adjacent tile,
	# not an extra tile beyond it.
	var half_extents: Vector2 = (collision_shape.shape as RectangleShape2D).size / 2.0
	var half_tile: float = mine.TILE_SIZE / 2.0
	var target := global_position + Vector2(
		direction.x * (half_extents.x + half_tile),
		direction.y * (half_extents.y + half_tile)
	)
	if mine.dig_at_world(target):
		dig_timer = DIG_COOLDOWN

func take_hit(amount: int) -> void:
	health -= amount
	if health <= 0:
		died.emit()

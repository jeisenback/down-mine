extends CharacterBody2D
class_name Player

signal died

const SPEED := 120.0
const ACCELERATION := 900.0  # reaches full speed in ~0.13s
const DECELERATION := 1200.0 # stops in ~0.1s, snappier than starting
const GRAVITY := 700.0
const JUMP_VELOCITY := -200.0
# Tuned to roughly match the natural fall time through one dug tile
# (~0.1s at this gravity). Digging straight down while falling used to
# stutter: dig, fall one tile (~0.1s), then stand frozen for the
# remaining ~0.15s of a 0.25s cooldown before digging again — a dead
# pause after every single tile that read as broken. At this cooldown
# the wait is gated by the fall itself, not idle time.
const DIG_COOLDOWN := 0.11
const MAX_HEALTH := 3

# Jump forgiveness: a press just before landing still fires on touchdown
# (buffer), and a press just after walking off a ledge still fires as if
# still grounded (coyote time). Without these, jumping near any edge —
# and this game is full of them — reads as unresponsive.
const COYOTE_TIME := 0.1
const JUMP_BUFFER_TIME := 0.12

@onready var light: MineLight = $MineLight
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

var mine: MineGrid
var dig_timer: float = 0.0
var facing: int = 1
var health: int = MAX_HEALTH
## Currency found this run, only banked on extraction (milestone 8) - lost
## if the run ends in death instead.
var currency: int = 0
var _jump_was_pressed: bool = false
var _coyote_timer: float = 0.0
var _jump_buffer_timer: float = 0.0

func _physics_process(delta: float) -> void:
	dig_timer = max(0.0, dig_timer - delta)
	_coyote_timer = max(0.0, _coyote_timer - delta)
	_jump_buffer_timer = max(0.0, _jump_buffer_timer - delta)

	var input_dir := 0.0
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
		input_dir -= 1.0
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
		input_dir += 1.0
	if input_dir != 0.0:
		facing = int(sign(input_dir))
	_apply_horizontal_movement(input_dir, delta)

	if is_on_floor():
		velocity.y = 0.0
		_coyote_timer = COYOTE_TIME
	else:
		velocity.y += GRAVITY * delta

	var jump_pressed := Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP)
	if jump_pressed and not _jump_was_pressed:
		_jump_buffer_timer = JUMP_BUFFER_TIME
	_jump_was_pressed = jump_pressed

	if _jump_buffer_timer > 0.0 and _coyote_timer > 0.0:
		velocity.y = JUMP_VELOCITY
		_jump_buffer_timer = 0.0
		_coyote_timer = 0.0

	var digging_down := Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN)
	var digging_forward := Input.is_physical_key_pressed(KEY_SPACE)
	if digging_down and input_dir != 0.0:
		_dig_staircase()
	elif digging_down:
		_dig_straight_down()
	elif digging_forward and jump_pressed:
		_dig_straight_up()
	elif digging_forward:
		_dig_forward()

	light.set_flaring(Input.is_physical_key_pressed(KEY_SHIFT))

	move_and_slide()

## Ramps velocity.x toward the input's target speed instead of snapping to
## it, so starting and stopping have weight. Takes input_dir directly
## (rather than reading Input itself) so it's callable from a headless
## test without needing to simulate a real key press.
func _apply_horizontal_movement(input_dir: float, delta: float) -> void:
	var target_speed := input_dir * SPEED
	var accel := ACCELERATION if input_dir != 0.0 else DECELERATION
	velocity.x = move_toward(velocity.x, target_speed, accel * delta)

func _dig_straight_down() -> void:
	if dig_timer > 0.0 or mine == null:
		return
	var half_extents: Vector2 = (collision_shape.shape as RectangleShape2D).size / 2.0
	var half_tile: float = mine.TILE_SIZE / 2.0
	var target := global_position + Vector2(0.0, half_extents.y + half_tile)
	if mine.dig_at_world(target):
		dig_timer = DIG_COOLDOWN

## Digs the tile directly above the player's head - the return trip's
## answer to _dig_straight_down(). Unlike digging down, gravity doesn't
## carry the player up through the cleared gap: it has to be paired with
## jumping into the new space, then dug again near the top of the arc.
## Triggered by holding Space (dig) + Up/W (the jump key) together, so it
## doesn't collide with either action alone.
func _dig_straight_up() -> void:
	if dig_timer > 0.0 or mine == null:
		return
	var half_extents: Vector2 = (collision_shape.shape as RectangleShape2D).size / 2.0
	var half_tile: float = mine.TILE_SIZE / 2.0
	var target := global_position + Vector2(0.0, -(half_extents.y + half_tile))
	if mine.dig_at_world(target):
		dig_timer = DIG_COOLDOWN

## Clears a notch the player's full height, one tile forward, so a
## sideways tunnel is actually tall enough to walk through.
func _dig_forward() -> void:
	if dig_timer > 0.0 or mine == null:
		return
	var half_extents: Vector2 = (collision_shape.shape as RectangleShape2D).size / 2.0
	var half_tile: float = mine.TILE_SIZE / 2.0
	var target_x := global_position.x + facing * (half_extents.x + half_tile)
	var cells := mine.cells_in_column(
		target_x,
		global_position.y - half_extents.y + 2.0,
		global_position.y + half_extents.y - 2.0
	)
	if mine.dig_cells(cells) > 0:
		dig_timer = DIG_COOLDOWN

## Clears one descending step: the forward notch (full player height)
## plus the tile below it, so holding down + a movement key while
## walking carves a staircase in one action instead of alternating
## forward/down digs tile by tile.
func _dig_staircase() -> void:
	if dig_timer > 0.0 or mine == null:
		return
	var half_extents: Vector2 = (collision_shape.shape as RectangleShape2D).size / 2.0
	var half_tile: float = mine.TILE_SIZE / 2.0
	var target_x := global_position.x + facing * (half_extents.x + half_tile)
	var cells := mine.cells_in_column(
		target_x,
		global_position.y - half_extents.y + 2.0,
		global_position.y + half_extents.y + mine.TILE_SIZE - 2.0
	)
	if mine.dig_cells(cells) > 0:
		dig_timer = DIG_COOLDOWN

func take_hit(amount: int) -> void:
	health -= amount
	if health <= 0:
		died.emit()

func add_currency(amount: int) -> void:
	currency += amount

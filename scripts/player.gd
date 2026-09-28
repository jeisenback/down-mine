extends CharacterBody2D
class_name Player

signal died
## Emitted for actions that make noise but aren't tile digging (rope
## placement, later: other placed tools) - Main connects this to the
## noise meter the same way it connects MineGrid.tile_dug.
signal made_noise(amount: float)

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

# Grapple: the PRD's "reusable tool, the reliable baseline" for getting
# back up. Fires straight up, pulls to just below the first solid
# ceiling within range. A miss (nothing in range) still costs half the
# cooldown so spamming it isn't free.
const GRAPPLE_RANGE := 96.0 # 6 tiles
const GRAPPLE_PULL_SPEED := 500.0
const GRAPPLE_COOLDOWN := 0.6

# Ropes: the PRD's consumable traversal tool. Placed at the current cell,
# climbable while touching it, decays over time (faster in darkness,
# handled by Rope itself). Placement has a short cooldown and costs noise,
# per "placed tools... make noise when placed".
const ROPE_LENGTH_TILES := 6
const ROPE_PLACE_COOLDOWN := 1.5
const ROPE_PLACE_NOISE := 15.0
const CLIMB_SPEED := 80.0
const RopeScene := preload("res://scenes/Rope.tscn")

# Deep Night player sheet: 16x16 frames, 10 per row, art faces right.
# Odd rows are an alternate shading of the row above and go unused.
const SHEET_COLUMNS := 10
const RUN_ROW := 0        # 8 frames; frame 0 doubles as idle
const PUSH_ROW := 2       # 3 frames, arms out - used when digging in place
const PUSH_RUN_ROW := 4   # 8 frames - running while digging forward
const JUMP_ROW := 6       # 5 frames; 2 = rising, 3 = falling
const RUN_FRAME_COUNT := 8
const RUN_ANIM_FPS := 12.0

@onready var light: MineLight = $MineLight
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var rope_detector: Area2D = $RopeDetector
@onready var body_sprite: Sprite2D = $Body

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
var _grapple_was_pressed: bool = false
var _grapple_timer: float = 0.0
var _grappling: bool = false
var _grapple_target_y: float = 0.0
var _rope_place_was_pressed: bool = false
var _rope_place_timer: float = 0.0
var _ropes_touching: Array = []
var _anim_time: float = 0.0

func _ready() -> void:
	body_sprite.texture = PixelArt.keyed(body_sprite.texture)
	rope_detector.area_entered.connect(_on_rope_area_entered)
	rope_detector.area_exited.connect(_on_rope_area_exited)

func _on_rope_area_entered(area: Area2D) -> void:
	if area is Rope:
		_ropes_touching.append(area)

func _on_rope_area_exited(area: Area2D) -> void:
	_ropes_touching.erase(area)

func is_on_rope() -> bool:
	_ropes_touching = _ropes_touching.filter(func(r): return is_instance_valid(r))
	return _ropes_touching.size() > 0

func _physics_process(delta: float) -> void:
	dig_timer = max(0.0, dig_timer - delta)
	_coyote_timer = max(0.0, _coyote_timer - delta)
	_jump_buffer_timer = max(0.0, _jump_buffer_timer - delta)
	_grapple_timer = max(0.0, _grapple_timer - delta)
	_rope_place_timer = max(0.0, _rope_place_timer - delta)

	var input_dir := 0.0
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
		input_dir -= 1.0
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
		input_dir += 1.0
	if input_dir != 0.0:
		facing = int(sign(input_dir))
	_apply_horizontal_movement(input_dir, delta)
	_update_animation(input_dir, delta)

	var place_rope_pressed := Input.is_physical_key_pressed(KEY_R)
	if place_rope_pressed and not _rope_place_was_pressed and _rope_place_timer <= 0.0:
		_place_rope()
	_rope_place_was_pressed = place_rope_pressed

	var grapple_pressed := Input.is_physical_key_pressed(KEY_Q)
	if grapple_pressed and not _grapple_was_pressed and not _grappling and _grapple_timer <= 0.0:
		_try_fire_grapple()
	_grapple_was_pressed = grapple_pressed

	if _grappling:
		velocity.y = -GRAPPLE_PULL_SPEED
		if global_position.y <= _grapple_target_y:
			_grappling = false
			velocity.y = 0.0
		move_and_slide()
		return

	var up_held := Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP)
	var down_held := Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN)

	if is_on_rope():
		velocity.y = 0.0
		if up_held:
			velocity.y = -CLIMB_SPEED
		elif down_held:
			velocity.y = CLIMB_SPEED
		move_and_slide()
		return

	if is_on_floor():
		velocity.y = 0.0
		_coyote_timer = COYOTE_TIME
	else:
		velocity.y += GRAVITY * delta

	if up_held and not _jump_was_pressed:
		_jump_buffer_timer = JUMP_BUFFER_TIME
	_jump_was_pressed = up_held

	if _jump_buffer_timer > 0.0 and _coyote_timer > 0.0:
		velocity.y = JUMP_VELOCITY
		_jump_buffer_timer = 0.0
		_coyote_timer = 0.0

	var digging_forward := Input.is_physical_key_pressed(KEY_SPACE)
	if down_held and input_dir != 0.0:
		_dig_staircase()
	elif down_held:
		_dig_straight_down()
	elif digging_forward and up_held:
		_dig_straight_up()
	elif digging_forward:
		_dig_forward()

	light.set_flaring(Input.is_physical_key_pressed(KEY_SHIFT))

	move_and_slide()

## Picks the sprite frame from movement state. Runs before this frame's
## move_and_slide(), so it reads last frame's floor contact - a one-frame
## lag nobody will see at this size.
func _update_animation(input_dir: float, delta: float) -> void:
	body_sprite.flip_h = facing < 0
	var row := RUN_ROW
	var column := 0
	if not is_on_floor() and not is_on_rope():
		row = JUMP_ROW
		column = 2 if velocity.y < 0.0 else 3
	elif Input.is_physical_key_pressed(KEY_SPACE):
		if input_dir != 0.0:
			row = PUSH_RUN_ROW
			column = _run_cycle_frame(delta)
		else:
			row = PUSH_ROW
			column = 2
	elif input_dir != 0.0:
		column = _run_cycle_frame(delta)
	else:
		_anim_time = 0.0
	body_sprite.frame = row * SHEET_COLUMNS + column

func _run_cycle_frame(delta: float) -> int:
	_anim_time += delta
	return int(_anim_time * RUN_ANIM_FPS) % RUN_FRAME_COUNT

## Scans straight up from the player's cell for the first solid cell
## within GRAPPLE_RANGE. On a hit, starts pulling toward a point just
## below it. On a miss, still costs half the cooldown so spamming it
## isn't free.
func _try_fire_grapple() -> void:
	if mine == null:
		return
	var start_cell := mine.world_to_cell(global_position)
	var max_cells := int(GRAPPLE_RANGE / mine.TILE_SIZE)
	for i in range(1, max_cells + 1):
		var cell := Vector2i(start_cell.x, start_cell.y - i)
		if mine.is_solid(cell):
			var target_cell := Vector2i(start_cell.x, cell.y + 1)
			_grapple_target_y = mine.cell_to_world(target_cell).y
			_grappling = true
			_grapple_timer = GRAPPLE_COOLDOWN
			return
	_grapple_timer = GRAPPLE_COOLDOWN * 0.5

## Places a Rope anchored at the top of the player's current cell,
## extending downward. Cell-aligned rather than pixel-exact so climbing
## it later feels grid-consistent.
func _place_rope() -> void:
	if mine == null:
		return
	var cell := mine.world_to_cell(global_position)
	var rope: Rope = RopeScene.instantiate()
	mine.add_child(rope)
	rope.global_position = mine.cell_to_world(cell) - Vector2(0.0, mine.TILE_SIZE / 2.0)
	_rope_place_timer = ROPE_PLACE_COOLDOWN
	made_noise.emit(ROPE_PLACE_NOISE)

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

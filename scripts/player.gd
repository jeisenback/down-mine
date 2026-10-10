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
# Digging straight down is a steady descent: the fall is held to just
# under one tile per cooldown while there is rock to dig below, so the
# next dig always lands before the feet do. Left to gravity the fall
# outran the dig rate after a tile or two, landed on the undug cell,
# zeroed the speed, waited out the cooldown and started again from rest:
# a visible hitch every couple of tiles. The hold lifts as soon as the
# two cells below are open, so a drop into a cave is a real fall.
const DIG_COOLDOWN := 0.11
const DIG_DESCENT_SPEED := MineGrid.TILE_SIZE / DIG_COOLDOWN * 0.9 # ~131 px/s, 8 tiles/s
const DIG_CENTRE_STEP := 2.0 # px per frame toward the dug column's centre
const MAX_HEALTH := 3
# Milestone 49: with the lantern at zero and no other light on you, health
# drains and you can't dig. Any other light suspends it.
const DARK_DRAIN_SECONDS := 12.0

# Jump forgiveness: a press just before landing still fires on touchdown
# (buffer), and a press just after walking off a ledge still fires as if
# still grounded (coyote time). Without these, jumping near any edge —
# and this game is full of them — reads as unresponsive.
const COYOTE_TIME := 0.1
const JUMP_BUFFER_TIME := 0.12
# Milestone 38: letting go of jump while rising cuts the jump short (a
# short hop), and walking into a 1-tile bump steps up onto it.
const JUMP_CUT := 0.4
const STEP_HEIGHT := 17.0 # one tile, plus a pixel to clear the edge
const STEP_PROBE := 2.0
# Milestone 42: pushing into a wall in mid-air pulls you up over its lip
# if the top is within this many px of your feet. Jump peak (~30 px) plus
# this reaches a 2-tile ledge (32 px) but not a 3-tile one (48 px).
const MANTLE_REACH := 14

# Grapple: the PRD's "reusable tool, the reliable baseline" for getting
# back up. Fires straight up, pulls to just below the first solid
# ceiling within range. A miss (nothing in range) still costs half the
# cooldown so spamming it isn't free.
const GRAPPLE_RANGE := 96.0 # 6 tiles, before crew bonuses
const GRAPPLE_PULL_SPEED := 500.0
const GRAPPLE_COOLDOWN := 0.6

# Ropes: the PRD's consumable traversal tool. Placed at the current cell,
# climbable while touching it, decays over time (faster in darkness,
# handled by Rope itself). Placement has a short cooldown and costs noise,
# per "placed tools... make noise when placed".
const ROPE_LENGTH_TILES := 6
const ROPE_PLACE_COOLDOWN := 1.5
const ROPE_PLACE_NOISE := 15.0
const ROPE_LIFE_SECONDS := 45.0
const CLIMB_SPEED := 80.0
const RopeScene := preload("res://scenes/Rope.tscn")

# Ladders (milestone 27): the rope's complement - a rope hangs down from a
# ledge, a ladder stands up from your feet (for climbing out of a hole you
# dropped into). Limited per run, faster to climb, longer-lived.
const LADDERS_PER_RUN := 4
const LADDER_LIFE_SECONDS := 120.0
const LADDER_CLIMB_SPEED := 140.0
const LADDER_PLACE_NOISE := 15.0
const LadderScene := preload("res://scenes/Ladder.tscn")

# Anchors (milestone 27): placed grapple points. The grapple pulls straight
# to the nearest anchor in range and line of sight before trying a ceiling.
const ANCHORS_PER_RUN := 2
const ANCHOR_RANGE := 160.0 # 10 tiles
const ANCHOR_PLACE_NOISE := 20.0 # hammering a bolt in
const ANCHOR_ARRIVE_DISTANCE := 6.0
const ANCHOR_PULL_TIMEOUT := 1.2 # safety stop for a pull that never arrives
const AnchorScene := preload("res://scenes/Anchor.tscn")

# Fall damage, judged by landing speed rather than height fallen, so
# digging straight down (a near-continuous fall that clears the floor
# ahead of you) stays safe while breaking into a cave and dropping
# through it hurts. Thresholds are in tiles of equivalent free fall.
# Plain dig-down lands at ~2.7 tiles' worth; a jump is under 2; digging
# into an upper-layer cave drops ~5-6. Deeper layers have bigger caverns,
# so the same habit gets more dangerous with depth.
const SAFE_FALL_TILES := 7.0
const FALL_TILES_PER_EXTRA_DAMAGE := 3.0
# Quality pass: a long fall through a cave ceiling (easy to dig into) did
# up to 4 damage - dead from full health, unseen below the light. Capped.
const MAX_FALL_DAMAGE := 2
const FALL_NOISE_PER_DAMAGE := 12.0

@onready var light: MineLight = $MineLight
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var rope_detector: Area2D = $RopeDetector
@onready var art: ArtSprite = $Art

var mine: MineGrid
var dig_timer: float = 0.0
var facing: int = 1
var health: int = MAX_HEALTH
## Currency found this run, only banked on extraction (milestone 8) - lost
## if the run ends in death instead.
var currency: int = 0
var _jump_was_pressed: bool = false
var _jump_rising: bool = false # jumped and still holding up
var invincible: bool = false # debug god mode (milestone 43)
var hits_by: Dictionary = {} # damage taken this run, by source
var last_hit_by: String = ""
var _dark_timer: float = 0.0 # seconds in the dark since the last drain hit
var _coyote_timer: float = 0.0
var _jump_buffer_timer: float = 0.0
var _grapple_was_pressed: bool = false
var _grapple_timer: float = 0.0
var _grappling: bool = false
var _grapple_target_y: float = 0.0
var _rope_place_was_pressed: bool = false
var _rope_place_timer: float = 0.0
var _ropes_touching: Array = []
## GRAPPLE_RANGE after crew bonuses (Progress.apply_to).
var grapple_range: float = GRAPPLE_RANGE
## SAFE_FALL_TILES after crew quirks (Progress.apply_to).
var safe_fall_tiles: float = SAFE_FALL_TILES
## Traversal crew bonuses (Progress.apply_to): rope/ladder life, ladder climb.
var tool_life_multiplier: float = 1.0
var ladder_speed_multiplier: float = 1.0
var ladders_left: int = LADDERS_PER_RUN
var anchors_left: int = ANCHORS_PER_RUN
var _ladder_was_pressed: bool = false
var _anchor_was_pressed: bool = false
var _grapple_anchor: Node2D = null
var _grapple_pull_time: float = 0.0
## Corner of an up-then-over pull to an anchor (movement pass), or INF.
var _grapple_waypoint: Vector2 = Vector2.INF
var _was_on_floor: bool = true

func _ready() -> void:
	add_to_group("player")
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

## Lantern out and no other light reaching the player. The player's own
## dead lantern keeps a 30 px radius, so it is excluded from the lit test.
func in_the_dark() -> bool:
	return light.is_out() and not MineLight.is_lit(get_tree(), global_position, light)

func can_dig() -> bool:
	return mine != null and not in_the_dark()

func _tick_dark_drain(delta: float) -> void:
	if not in_the_dark():
		_dark_timer = 0.0
		return
	_dark_timer += delta
	if _dark_timer >= DARK_DRAIN_SECONDS:
		_dark_timer -= DARK_DRAIN_SECONDS
		take_hit(1, "dark")

func _physics_process(delta: float) -> void:
	_tick_dark_drain(delta)
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
		_place_rope(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN))
	_rope_place_was_pressed = place_rope_pressed

	var ladder_pressed := Input.is_physical_key_pressed(KEY_T)
	if ladder_pressed and not _ladder_was_pressed and ladders_left > 0 and _rope_place_timer <= 0.0:
		_place_ladder()
	_ladder_was_pressed = ladder_pressed

	var anchor_pressed := Input.is_physical_key_pressed(KEY_G)
	if anchor_pressed and not _anchor_was_pressed and anchors_left > 0 and is_on_floor():
		_place_anchor()
	_anchor_was_pressed = anchor_pressed

	var grapple_pressed := Input.is_physical_key_pressed(KEY_Q)
	if grapple_pressed and not _grapple_was_pressed and not _grappling and _grapple_timer <= 0.0:
		_try_fire_grapple()
	_grapple_was_pressed = grapple_pressed

	if _grappling and _grapple_anchor != null:
		_pull_toward_anchor(delta)
		_was_on_floor = false
		return
	if _grappling:
		velocity.y = -GRAPPLE_PULL_SPEED
		if global_position.y <= _grapple_target_y:
			_grappling = false
			velocity.y = 0.0
		_move()
		return

	var up_held := Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP)
	var down_held := Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN)

	if is_on_rope():
		var climb := _climb_speed()
		velocity.y = 0.0
		if up_held:
			velocity.y = -climb
		elif down_held:
			velocity.y = climb
		_move()
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
		_jump_rising = true
	_apply_jump_cut(up_held)

	# Steps and mantles come before digging, Space held or not: a 1-tile
	# bump in the way is walked over, not dug (see _dig_forward). Not while
	# digging down - stairs and stepping up contradict.
	var stepped := false
	if input_dir != 0.0 and not down_held:
		stepped = _try_step_up(input_dir) if is_on_floor() else _try_mantle(input_dir)

	var digging_forward := Input.is_physical_key_pressed(KEY_SPACE)
	if down_held and input_dir != 0.0:
		_dig_staircase()
	elif down_held:
		_dig_straight_down()
	elif digging_forward and up_held:
		_dig_straight_up()
	elif digging_forward and not stepped:
		_dig_forward(input_dir != 0.0)

	light.set_flaring(Input.is_physical_key_pressed(KEY_SHIFT))
	_move()

## Releasing up while still rising cuts the jump, once per jump.
func _apply_jump_cut(up_held: bool) -> void:
	if not _jump_rising:
		return
	if velocity.y >= 0.0:
		_jump_rising = false
	elif not up_held:
		velocity.y *= JUMP_CUT
		_jump_rising = false

## In the air, pushing into a wall whose top is within MANTLE_REACH of
## the feet: pull up over the lip. Returns whether it did.
func _try_mantle(dir: float) -> bool:
	var ahead := Vector2(dir * STEP_PROBE, 0.0)
	if not test_move(global_transform, ahead):
		return false # nothing to grab
	for lift in range(2, MANTLE_REACH + 1, 2):
		var up := Vector2(0.0, -lift)
		if test_move(global_transform, up):
			return false # ceiling in the way
		if not test_move(global_transform.translated(up), ahead):
			global_position += up + ahead
			velocity.y = 0.0
			return true
	return false

## Walking on the floor into a bump exactly one tile tall climbs onto it.
## Taller walls, and bumps without headroom above, still block. Returns
## whether it stepped.
func _try_step_up(dir: float) -> bool:
	if not is_on_floor():
		return false
	var ahead := Vector2(dir * STEP_PROBE, 0.0)
	if not test_move(global_transform, ahead):
		return false # nothing in the way
	var up := Vector2(0.0, -STEP_HEIGHT)
	if test_move(global_transform, up) or test_move(global_transform.translated(up), ahead):
		return false
	global_position += up + ahead
	return true

## What the drawn miner is doing, from movement: "idle", "run", "dig"
## (the dig key is held, in place or moving), "jump" (rising) or "fall".
static func animation_state(on_ground: bool, digging: bool, input_dir: float, vy: float) -> String:
	if not on_ground:
		return "jump" if vy < 0.0 else "fall"
	if digging:
		return "dig"
	return "run" if input_dir != 0.0 else "idle"

## Points the drawn miner at this frame's movement state. Runs before this
## frame's move_and_slide(), so it reads last frame's floor contact - a
## one-frame lag nobody will see at this size.
func _update_animation(input_dir: float, _delta: float) -> void:
	art.flip_h = facing < 0
	var on_ground := is_on_floor() or is_on_rope()
	art.art.state = Player.animation_state(on_ground, Input.is_physical_key_pressed(KEY_SPACE), input_dir, velocity.y)

## move_and_slide() plus landing detection. The velocity going in is the
## impact speed, since the collision zeroes it.
func _move() -> void:
	var fall_speed := velocity.y
	move_and_slide()
	if is_on_floor() and not _was_on_floor:
		_on_landed(fall_speed)
	_was_on_floor = is_on_floor()

func _on_landed(fall_speed: float) -> void:
	var damage := fall_damage_for_speed(fall_speed, safe_fall_tiles)
	if damage > 0:
		made_noise.emit(FALL_NOISE_PER_DAMAGE * damage)
		take_hit(damage, "fall")

## Converts landing speed to tiles of free fall (v^2 / 2g), then to damage.
static func fall_damage_for_speed(fall_speed: float, safe_tiles: float = SAFE_FALL_TILES) -> int:
	if fall_speed <= 0.0:
		return 0
	var fall_tiles := fall_speed * fall_speed / (2.0 * GRAVITY) / MineGrid.TILE_SIZE
	if fall_tiles < safe_tiles:
		return 0
	return mini(MAX_FALL_DAMAGE, 1 + int((fall_tiles - safe_tiles) / FALL_TILES_PER_EXTRA_DAMAGE))

## Scans straight up from the player's cell for the first solid cell
## within grapple_range. On a hit, starts pulling toward a point just
## below it. On a miss, still costs half the cooldown so spamming it
## isn't free.
func _try_fire_grapple() -> void:
	if mine == null:
		return
	var anchor := _anchor_in_reach()
	if anchor != null:
		_grapple_anchor = anchor
		_grapple_pull_time = 0.0
		_grappling = true
		_grapple_timer = GRAPPLE_COOLDOWN
		return
	var start_cell := mine.world_to_cell(global_position)
	var max_cells := int(grapple_range / mine.TILE_SIZE)
	for i in range(1, max_cells + 1):
		var cell := Vector2i(start_cell.x, start_cell.y - i)
		if mine.is_solid(cell):
			var target_cell := Vector2i(start_cell.x, cell.y + 1)
			_grapple_target_y = mine.cell_to_world(target_cell).y
			_grappling = true
			_grapple_timer = GRAPPLE_COOLDOWN
			return
	_grapple_timer = GRAPPLE_COOLDOWN * 0.5

## Places a Rope, hanging ROPE_LENGTH_TILES down from its top, cell-aligned.
## Movement pass: it used to hang from the player's own cell into the rock
## below, so it couldn't get anyone up a shaft or down a drop. Now R throws
## it up (its top at the ceiling, or 5 tiles up) to climb; S+R drops it
## over the edge in front, into a drop, to climb down and back.
func _place_rope(drop: bool = false) -> void:
	if mine == null:
		return
	var cell := mine.world_to_cell(global_position)
	var top := cell
	var ahead := cell + Vector2i(facing, 0)
	if drop:
		if not mine.is_solid(ahead) and not mine.is_solid(ahead + Vector2i.DOWN):
			top = ahead # over the edge into the drop
	else:
		for i in range(1, ROPE_LENGTH_TILES):
			if mine.is_solid(top + Vector2i.UP):
				break
			top += Vector2i.UP
	var rope: Rope = RopeScene.instantiate()
	mine.add_child(rope)
	rope.global_position = mine.cell_to_world(top) - Vector2(0.0, mine.TILE_SIZE / 2.0)
	rope.life_seconds = ROPE_LIFE_SECONDS * tool_life_multiplier
	rope.climb_speed = CLIMB_SPEED
	_rope_place_timer = ROPE_PLACE_COOLDOWN
	made_noise.emit(ROPE_PLACE_NOISE)
	Sfx.play("place")

## Places a Ladder standing up from the bottom of the player's cell.
func _place_ladder() -> void:
	if mine == null or ladders_left <= 0:
		return
	var cell := mine.world_to_cell(global_position)
	var ladder: Rope = LadderScene.instantiate()
	ladder.life_seconds = LADDER_LIFE_SECONDS * tool_life_multiplier
	ladder.climb_speed = LADDER_CLIMB_SPEED * ladder_speed_multiplier
	mine.add_child(ladder)
	ladder.global_position = mine.cell_to_world(cell) + Vector2(0.0, mine.TILE_SIZE / 2.0)
	ladders_left -= 1
	_rope_place_timer = ROPE_PLACE_COOLDOWN
	made_noise.emit(LADDER_PLACE_NOISE)
	Sfx.play("place")

func _place_anchor() -> void:
	if mine == null or anchors_left <= 0:
		return
	var anchor: Anchor = AnchorScene.instantiate()
	mine.add_child(anchor)
	anchor.global_position = global_position
	anchors_left -= 1
	made_noise.emit(ANCHOR_PLACE_NOISE)
	Sfx.play("place")

## Fastest climb among the ropes/ladders being touched.
func _climb_speed() -> float:
	var speed := 0.0
	for r in _ropes_touching:
		if is_instance_valid(r):
			speed = max(speed, r.climb_speed)
	return speed

## Nearest anchor within ANCHOR_RANGE with a clear pull to it: a straight
## line, or straight up then across (out of a narrow pit, where the direct
## line clips the pit wall). Sets _grapple_waypoint for the up-then-across
## case.
func _anchor_in_reach() -> Node2D:
	var best: Node2D = null
	var best_waypoint := Vector2.INF
	for anchor in get_tree().get_nodes_in_group("anchors"):
		var d := global_position.distance_to(anchor.global_position)
		if d > ANCHOR_RANGE or d < ANCHOR_ARRIVE_DISTANCE:
			continue
		var waypoint := Vector2.INF
		if not _clear_line_to(anchor.global_position):
			var corner := Vector2(global_position.x, anchor.global_position.y)
			if not (_clear_segment(global_position, corner) and _clear_segment(corner, anchor.global_position)):
				continue
			waypoint = corner
		if best == null or d < global_position.distance_to(best.global_position):
			best = anchor
			best_waypoint = waypoint
	_grapple_waypoint = best_waypoint
	return best

## No rock anywhere along the segment (4 px steps, both ends included).
func _clear_segment(from: Vector2, to: Vector2) -> bool:
	var steps := maxi(1, int(from.distance_to(to) / 4.0))
	for i in range(steps + 1):
		if mine.is_solid(mine.world_to_cell(from.lerp(to, i / float(steps)))):
			return false
	return true

## Rock between the player and the target, ignoring the target's floor
## lip: an anchor stands on a floor, so any line to it from below crosses
## the tile under it or its edge - the line goes over the edge, as a real
## one would. Any other rock blocks.
func _clear_line_to(target: Vector2) -> bool:
	var target_cell := mine.world_to_cell(target)
	var steps := int(global_position.distance_to(target) / 4.0)
	for i in range(1, steps):
		var cell := mine.world_to_cell(global_position.lerp(target, i / float(steps)))
		var is_lip := cell.y == target_cell.y + 1 and absi(cell.x - target_cell.x) <= 1
		if mine.is_solid(cell) and not is_lip:
			return false
	return true

## Reels the player along the straight line to the anchor. Moves directly
## rather than through move_and_slide, which would snag on the lip the
## line passes over; the line of sight check already ruled out real rock.
func _pull_toward_anchor(delta: float) -> void:
	_grapple_pull_time += delta
	velocity = Vector2.ZERO
	var to_anchor := Vector2.ZERO
	if is_instance_valid(_grapple_anchor):
		to_anchor = _grapple_anchor.global_position - global_position
	if _grapple_waypoint != Vector2.INF:
		var to_corner := _grapple_waypoint - global_position
		if to_corner.length() < ANCHOR_ARRIVE_DISTANCE:
			_grapple_waypoint = Vector2.INF
		else:
			global_position += to_corner.normalized() * min(GRAPPLE_PULL_SPEED * delta, to_corner.length())
			return
	if to_anchor.length() < ANCHOR_ARRIVE_DISTANCE or _grapple_pull_time > ANCHOR_PULL_TIMEOUT:
		if to_anchor.length() < ANCHOR_ARRIVE_DISTANCE:
			global_position = _grapple_anchor.global_position
		_grappling = false
		_grapple_anchor = null
		return
	global_position += to_anchor.normalized() * min(GRAPPLE_PULL_SPEED * delta, to_anchor.length())

## Ramps velocity.x toward the input's target speed instead of snapping to
## it, so starting and stopping have weight. Takes input_dir directly
## (rather than reading Input itself) so it's callable from a headless
## test without needing to simulate a real key press.
func _apply_horizontal_movement(input_dir: float, delta: float) -> void:
	var target_speed := input_dir * SPEED
	var accel := ACCELERATION if input_dir != 0.0 else DECELERATION
	velocity.x = move_toward(velocity.x, target_speed, accel * delta)

func _dig_straight_down() -> void:
	if not can_dig():
		return
	var half_extents: Vector2 = (collision_shape.shape as RectangleShape2D).size / 2.0
	var half_tile: float = mine.TILE_SIZE / 2.0
	var target := global_position + Vector2(0.0, half_extents.y + half_tile)
	# The body is narrower than a tile but still rests on the next tile
	# unless centred over the hole, so slide over it while digging.
	var column_x := mine.cell_to_world(mine.world_to_cell(target)).x
	var step := Vector2(move_toward(global_position.x, column_x, DIG_CENTRE_STEP) - global_position.x, 0.0)
	if step.x != 0.0 and not test_move(global_transform, step):
		global_position += step
	# Steady descent while there is rock to dig within two cells below
	# (two, so the hold doesn't lapse the instant the next cell is dug).
	var below := mine.world_to_cell(target)
	if _diggable(below) or _diggable(below + Vector2i.DOWN):
		velocity.y = minf(velocity.y, DIG_DESCENT_SPEED)
	if dig_timer > 0.0:
		return
	if mine.dig_at_world(target):
		dig_timer = DIG_COOLDOWN

func _diggable(cell: Vector2i) -> bool:
	return mine.is_solid(cell) and not mine.is_indestructible(cell)

## Digs the tile directly above the player's head - the return trip's
## answer to _dig_straight_down(). Unlike digging down, gravity doesn't
## carry the player up through the cleared gap: it has to be paired with
## jumping into the new space, then dug again near the top of the arc.
## Triggered by holding Space (dig) + Up/W (the jump key) together, so it
## doesn't collide with either action alone.
func _dig_straight_up() -> void:
	if dig_timer > 0.0 or not can_dig():
		return
	var half_extents: Vector2 = (collision_shape.shape as RectangleShape2D).size / 2.0
	var half_tile: float = mine.TILE_SIZE / 2.0
	var target := global_position + Vector2(0.0, -(half_extents.y + half_tile))
	if mine.dig_at_world(target):
		dig_timer = DIG_COOLDOWN

## Clears a notch the player's full height, one tile forward, so a
## sideways tunnel is actually tall enough to walk through. While walking
## on the floor, a 1-tile bump with headroom is left alone: the dig would
## fire before contact and flatten it, when stepping over it is faster
## and quieter (movement quality pass). Standing still still digs it.
func _dig_forward(walking: bool = false) -> void:
	if dig_timer > 0.0 or not can_dig():
		return
	var half_extents: Vector2 = (collision_shape.shape as RectangleShape2D).size / 2.0
	var half_tile: float = mine.TILE_SIZE / 2.0
	var target_x := global_position.x + facing * (half_extents.x + half_tile)
	var cells := mine.cells_in_column(
		target_x,
		global_position.y - half_extents.y + 2.0,
		global_position.y + half_extents.y - 2.0
	)
	if walking and is_on_floor() and _is_steppable_bump(cells):
		return
	if mine.dig_cells(cells) > 0:
		dig_timer = DIG_COOLDOWN

## One solid cell at the player's own row, open above it and above the
## player: what _try_step_up climbs.
func _is_steppable_bump(cells: Array) -> bool:
	if cells.size() != 1:
		return false
	var bump: Vector2i = cells[0]
	var own_cell := mine.world_to_cell(global_position)
	return mine.is_solid(bump) and not mine.is_solid(bump + Vector2i.UP) and not mine.is_solid(own_cell + Vector2i.UP)

## Clears one descending step: the cell ahead at the player's row plus the
## one below it, so holding down + a movement key while walking carves a
## staircase in one action instead of alternating forward/down digs tile
## by tile. Only from a standing floor: the next step is dug after the
## drop onto this one, so every step is exactly one row lower (digging
## from the pixel span mid-drop used to straddle three rows).
func _dig_staircase() -> void:
	if dig_timer > 0.0 or not can_dig() or not is_on_floor():
		return
	var own_cell := mine.world_to_cell(global_position)
	if not mine.is_solid(own_cell + Vector2i.DOWN):
		return # standing on the lip of the last step, not on this one yet
	var ahead := own_cell + Vector2i(facing, 0)
	if mine.dig_cells([ahead, ahead + Vector2i.DOWN]) > 0:
		dig_timer = DIG_COOLDOWN

## source names what hurt the player, for the run log (milestone 45).
func take_hit(amount: int, source: String = "other") -> void:
	if invincible:
		return
	hits_by[source] = hits_by.get(source, 0) + amount
	last_hit_by = source
	Sfx.play("hit")
	health -= amount
	if health <= 0:
		died.emit()

func add_currency(amount: int) -> void:
	currency += amount

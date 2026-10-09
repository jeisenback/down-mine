extends CharacterBody2D
class_name Stalker

enum State { LURK, APPROACH, FLEE }

const SPEED := 60.0
const SAFE_LIGHT_MARGIN := 10.0
const ATTACK_RANGE := 14.0
const ATTACK_COOLDOWN := 1.2
# PRD: "strikes when [the light] flickers or shrinks". The lantern only
# holds a Stalker off while above this fuel fraction (or flaring); below
# it, the Stalker closes in. Before this, it fled at radius - margin, and
# since the lantern never shrinks below 30px that was always outside
# ATTACK_RANGE - a standing player could never be hit, only one moving
# into it.
const STRIKE_FUEL_FRACTION := 0.25
# Quality pass: out of range it used to stop dead, and rock blocked it, so
# outpacing it once made the dark safe for good. Now it drifts through
# rock (collision_mask 0, like the Snuffer) and hunts at this speed.
const HUNT_SPEED := 24.0
# After a strike it backs off for a moment: time to flare or run for light
# (it used to land three hits in 2.4 s, dead before the player could react).
const RETREAT_SECONDS := 3.0
const RETREAT_SECONDS_DARK := 1.5 # milestone 49: at zero light it returns sooner

var player: Player
## The base light is a refuge: inside it the Stalker only retreats, so it
## never attacks there - it waits at the edge instead.
var run_base: RunBase
## Never rises above this world y: the quiet layers at the top of the mine
## are off limits (Main sets it), so climbing back up is a real escape.
var min_y: float = -INF
var state: State = State.LURK
var attack_timer: float = 0.0
var retreat_timer: float = 0.0
var _anim_time: float = 0.0

# Tileset slime (milestone 30): three squash-and-stretch frames.
const ANIM_FPS := 5.0
const FRAME_COUNT := 3

@onready var body: Sprite2D = $Body

func _ready() -> void:
	add_to_group("stalkers")
	body.texture = PixelArt.keyed(body.texture)

func _process(delta: float) -> void:
	_anim_time += delta
	body.frame = int(_anim_time * ANIM_FPS) % FRAME_COUNT
	if absf(velocity.x) > 1.0:
		body.flip_h = velocity.x < 0.0

func _physics_process(delta: float) -> void:
	attack_timer = max(0.0, attack_timer - delta)
	retreat_timer = max(0.0, retreat_timer - delta)
	if player == null:
		return

	var from_base := global_position - run_base.global_position
	if from_base.length() < run_base.light.current_radius() - SAFE_LIGHT_MARGIN:
		velocity = from_base.normalized() * SPEED
		move_and_slide()
		global_position.y = maxf(global_position.y, min_y)
		return

	var to_player := player.global_position - global_position
	var distance := to_player.length()
	var light_radius: float = player.light.current_radius()
	var light_holds: bool = player.light.is_flaring or player.light.fuel_fraction() > STRIKE_FUEL_FRACTION
	var in_light := light_holds and distance < light_radius - SAFE_LIGHT_MARGIN

	if in_light or retreat_timer > 0.0:
		state = State.FLEE
	elif distance < light_radius + 80.0:
		state = State.APPROACH
	else:
		state = State.LURK

	match state:
		State.FLEE:
			velocity = -to_player.normalized() * SPEED
		State.APPROACH:
			velocity = to_player.normalized() * SPEED
			if distance < ATTACK_RANGE and attack_timer <= 0.0:
				_attack()
		State.LURK:
			velocity = to_player.normalized() * HUNT_SPEED # the dark closes in

	move_and_slide()
	global_position.y = maxf(global_position.y, min_y)

func _attack() -> void:
	attack_timer = ATTACK_COOLDOWN
	retreat_timer = RETREAT_SECONDS_DARK if player.light.is_out() else RETREAT_SECONDS
	if player.has_method("take_hit"):
		player.take_hit(1, "Stalker")

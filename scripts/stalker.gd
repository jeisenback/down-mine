extends CharacterBody2D
class_name Stalker

enum State { LURK, APPROACH, FLEE }

const SPEED := 60.0
const SAFE_LIGHT_MARGIN := 10.0
const ATTACK_RANGE := 14.0
const ATTACK_COOLDOWN := 1.2

var player: Player
var state: State = State.LURK
var attack_timer: float = 0.0

func _physics_process(delta: float) -> void:
	attack_timer = max(0.0, attack_timer - delta)
	if player == null:
		return

	var to_player := player.global_position - global_position
	var distance := to_player.length()
	var light_radius: float = player.light.current_radius()
	var in_light := distance < light_radius - SAFE_LIGHT_MARGIN

	if in_light:
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
			velocity = velocity.move_toward(Vector2.ZERO, SPEED * delta)

	move_and_slide()

func _attack() -> void:
	attack_timer = ATTACK_COOLDOWN
	if player.has_method("take_hit"):
		player.take_hit(1)

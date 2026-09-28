extends Area2D
class_name Rope

## A climbable placed tool: ropes (hang down from where they're placed)
## and ladders (stand up from the player's feet) share this script, set
## apart by their scene shape and the life/climb speed the player gives
## them. Lifetime is measured sitting in light; in the dark it decays
## twice as fast, sharing the PRD's "structures decay faster in darkness"
## clock with MineLight.
const DARK_DECAY_MULTIPLIER := 2.0

var life_seconds: float = 45.0
var climb_speed: float = 80.0
var lifetime: float = 1.0 # 1.0 = fresh, 0.0 = gone

func _process(delta: float) -> void:
	var rate := (1.0 / life_seconds) * (1.0 if MineLight.is_lit(get_tree(), global_position) else DARK_DECAY_MULTIPLIER)
	lifetime -= rate * delta
	if lifetime <= 0.0:
		queue_free()

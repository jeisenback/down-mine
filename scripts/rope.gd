extends Area2D
class_name Rope

## Full lifetime is ~45s sitting in light; decays twice as fast in the
## dark, sharing the PRD's "structures decay faster in darkness" clock
## with MineLight.
const DECAY_RATE := 1.0 / 45.0
const DARK_DECAY_MULTIPLIER := 2.0

var lifetime: float = 1.0 # 1.0 = fresh, 0.0 = gone

func _process(delta: float) -> void:
	var rate := DECAY_RATE * (DARK_DECAY_MULTIPLIER if not _is_in_light() else 1.0)
	lifetime -= rate * delta
	if lifetime <= 0.0:
		queue_free()

func _is_in_light() -> bool:
	for light in get_tree().get_nodes_in_group("mine_lights"):
		if global_position.distance_to(light.global_position) < light.current_radius():
			return true
	return false

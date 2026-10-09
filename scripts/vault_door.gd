extends StaticBody2D
class_name VaultDoor

## The relic vault's door (milestone 35, a mine event): the only way into
## a bedrock chamber. Breaking it takes one press but is very loud.
const BREAK_NOISE := 60.0

func _ready() -> void:
	add_to_group("mine_events")

func prompt(_main: Node) -> String:
	return "E: break into the vault (very loud)"

func use(main: Node) -> void:
	main.noise_meter.add_noise(BREAK_NOISE, global_position)
	Sfx.play("collapse")
	queue_free()

extends Node2D
class_name Heart

## The Heart of the mine (milestone 40): the run's goal, in a chamber on
## the bedrock floor. Taking it wakes the mine (see Main.take_heart);
## getting it to the surface wins the run.

func _ready() -> void:
	add_to_group("mine_events")

func prompt(_main: Node) -> String:
	return "E: take the Heart of the mine (it wakes)"

func use(main: Node) -> void:
	main.take_heart()
	queue_free()

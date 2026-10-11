extends Node2D
class_name Torch

## A wall torch set in the early mine (milestone 60): a light that never burns
## down. It is a MineLight like the lantern and lamps, so lit ground does not
## crumble and ropes decay slower beside it, but it is neither a Lamp nor
## snuffable: Snuffers neither spawn for it nor hunt it.

func _ready() -> void:
	add_to_group("torches")

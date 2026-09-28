extends Area2D
class_name OrePickup

## Set by MineGrid at spawn time, scaled by depth band.
@export var value: int = 10

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	$Body.texture = PixelArt.keyed($Body.texture) # tileset gold nugget (milestone 30)

func _on_body_entered(body: Node) -> void:
	if body is Player:
		(body as Player).add_currency(value)
		Sfx.play("ore")
		queue_free()

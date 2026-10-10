extends Area2D
class_name FuelPickup

@export var fuel_amount: float = 25.0

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
	if body is Player:
		(body as Player).light.add_fuel(fuel_amount)
		Sfx.play("fuel")
		queue_free()

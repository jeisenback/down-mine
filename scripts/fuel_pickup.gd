extends Area2D
class_name FuelPickup

@export var fuel_amount: float = 25.0

# Mines build pickups during seeded generation, and each used to draw one global
# random number (a twinkle phase). The draw stays so every seed keeps building
# the same mine it did before the art was redrawn (milestone 53).
var _seed_stream_draw: float = randf()

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
	if body is Player:
		(body as Player).light.add_fuel(fuel_amount)
		Sfx.play("fuel")
		queue_free()

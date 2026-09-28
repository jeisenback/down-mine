extends Area2D
class_name FuelPickup

@export var fuel_amount: float = 25.0

# Tileset star (milestone 30), twinkling between a large and small cross.
const TWINKLE_FPS := 2.5

var _time: float = randf() # desync neighbouring pickups

@onready var body: Sprite2D = $Body

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body.texture = PixelArt.keyed(body.texture)

func _process(delta: float) -> void:
	_time += delta
	body.frame = 0 if int(_time * TWINKLE_FPS) % 2 == 0 else 2

func _on_body_entered(body: Node) -> void:
	if body is Player:
		(body as Player).light.add_fuel(fuel_amount)
		queue_free()

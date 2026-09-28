extends Node2D
class_name MineLight

signal fuel_depleted

@export var max_fuel: float = 60.0
@export var burn_rate: float = 1.0
@export var flare_burn_multiplier: float = 4.0
@export var radius_max: float = 140.0
@export var radius_min: float = 30.0
@export var energy_max: float = 1.4
@export var energy_min: float = 0.3

var fuel: float
var is_flaring: bool = false

@onready var point_light: PointLight2D = $PointLight2D
@onready var detection_area: Area2D = $DetectionArea
@onready var detection_shape: CollisionShape2D = $DetectionArea/CollisionShape2D

func _ready() -> void:
	add_to_group("mine_lights") # so Rope can check "am I lit" without a direct reference
	fuel = max_fuel
	point_light.texture = _make_glow_texture()
	detection_shape.shape = CircleShape2D.new()
	_update_visuals()

func _process(delta: float) -> void:
	var rate := burn_rate * (flare_burn_multiplier if is_flaring else 1.0)
	fuel = max(0.0, fuel - rate * delta)
	_update_visuals()
	if fuel <= 0.0:
		fuel_depleted.emit()

func add_fuel(amount: float) -> void:
	fuel = min(max_fuel, fuel + amount)

func set_flaring(flaring: bool) -> void:
	is_flaring = flaring

func fuel_fraction() -> float:
	return fuel / max_fuel if max_fuel > 0.0 else 0.0

func current_radius() -> float:
	var frac := fuel_fraction()
	var base_radius: float = lerp(radius_min, radius_max, frac)
	return base_radius * (1.3 if is_flaring else 1.0)

func _update_visuals() -> void:
	var frac := fuel_fraction()
	var radius := current_radius()
	var scale_factor: float = radius / 128.0
	point_light.scale = Vector2(scale_factor, scale_factor)
	point_light.energy = lerp(energy_min, energy_max, frac) * (1.5 if is_flaring else 1.0)
	(detection_shape.shape as CircleShape2D).radius = radius

func _make_glow_texture() -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1, 0.92, 0.7, 1.0))
	gradient.set_color(1, Color(1, 0.92, 0.7, 0.0))
	var tex := GradientTexture2D.new()
	tex.gradient = gradient
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 256
	tex.height = 256
	return tex

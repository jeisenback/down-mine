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

## Below this fraction of fuel the light warms toward WARM_COLOR and gutters (M91): the colour slides
## and the brightness wavers more the closer to empty. Purely how it looks: the reach never changes.
const LOW_FUEL := 0.3
const WARM_COLOR := Color(1.0, 0.55, 0.25)
## The most the brightness departs from its set value when the fuel is gone, as a fraction.
const GUTTER := 0.35

var fuel: float
var is_flaring: bool = false
var _base_color: Color
var _warmed := false
var _clock := 0.0
var _phase := 0.0

@onready var point_light: PointLight2D = $PointLight2D
@onready var detection_area: Area2D = $DetectionArea
@onready var detection_shape: CollisionShape2D = $DetectionArea/CollisionShape2D

func _ready() -> void:
	add_to_group(Groups.MINE_LIGHTS) # so Rope can check "am I lit" without a direct reference
	fuel = max_fuel
	_phase = float(get_instance_id() % 628) / 100.0 # each light wavers on its own
	point_light.texture = _make_glow_texture()
	detection_shape.shape = CircleShape2D.new()
	_update_visuals()

func _process(delta: float) -> void:
	_clock += delta
	var rate := burn_rate * (flare_burn_multiplier if is_flaring else 1.0)
	fuel = max(0.0, fuel - rate * delta)
	_update_visuals()
	if fuel <= 0.0:
		fuel_depleted.emit()

## Whether any MineLight's current radius reaches world_pos - the one
## "is this spot lit?" test that decay, ropes and anchors share.
## A light equal to `except` is skipped (a lantern doesn't light its own bearer's dark).
static func is_lit(tree: SceneTree, world_pos: Vector2, except: Node = null) -> bool:
	for light in tree.get_nodes_in_group(Groups.MINE_LIGHTS):
		if light == except:
			continue
		if world_pos.distance_to(light.global_position) < light.current_radius():
			return true
	return false

func is_out() -> bool:
	return fuel <= 0.0

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
	point_light.energy = lerp(energy_min, energy_max, frac) * (1.5 if is_flaring else 1.0) * gutter(_clock, frac, _phase)
	_tint(frac)
	(detection_shape.shape as CircleShape2D).radius = radius

## Warms the light's colour while the fuel is low, from whatever colour it had when it was healthy (a
## light may be given its own colour after it starts), and puts that colour back when it is refuelled.
func _tint(frac: float) -> void:
	if low_fuel_t(frac) > 0.0:
		if not _warmed:
			_base_color = point_light.color
			_warmed = true
		point_light.color = low_fuel_color(_base_color, frac)
	elif _warmed:
		point_light.color = _base_color
		_warmed = false

## How far into the low-fuel range the light is: 0 at LOW_FUEL and above, 1 when empty.
static func low_fuel_t(fuel_fraction_now: float) -> float:
	return clampf(1.0 - fuel_fraction_now / LOW_FUEL, 0.0, 1.0)

## `base` slid toward WARM_COLOR as the fuel runs out (alpha kept).
static func low_fuel_color(base: Color, fuel_fraction_now: float) -> Color:
	var warmed := base.lerp(WARM_COLOR, low_fuel_t(fuel_fraction_now))
	warmed.a = base.a
	return warmed

## A brightness multiplier at `time` for a light with `phase`: 1 above LOW_FUEL, then three unaligned
## sines whose reach grows to GUTTER as the fuel runs out. Always within 1 +/- GUTTER * low_fuel_t.
static func gutter(time: float, fuel_fraction_now: float, phase: float) -> float:
	var amplitude := GUTTER * low_fuel_t(fuel_fraction_now)
	if amplitude <= 0.0:
		return 1.0
	var wobble := sin(time * 9.3 + phase) * 0.5 + sin(time * 17.1 + phase * 1.7) * 0.3 + sin(time * 5.1 + phase * 0.6) * 0.2
	return 1.0 + amplitude * wobble

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

extends CPUParticles2D
class_name DustMotes

## A few motes of dust hanging in the air around the player (M89). They are ordinary lit canvas
## items, so they show only where a light reaches: a drift of specks through the lantern's beam,
## and nothing in the dark. They stay where they are as the player moves (world-space), so walking
## through them makes them stream past. Cosmetic: no physics, no effect on any light's reach.

const MOTES := 28
const LIFETIME := 8.0
const RADIUS := 130.0

func _init() -> void:
	amount = MOTES
	lifetime = LIFETIME
	preprocess = LIFETIME # already in the air when the run starts
	local_coords = false
	emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	emission_sphere_radius = RADIUS
	direction = Vector2(0.0, -1.0)
	spread = 180.0
	gravity = Vector2.ZERO
	initial_velocity_min = 1.0
	initial_velocity_max = 5.0
	scale_amount_min = 1.0
	scale_amount_max = 2.0
	color = Color(1.0, 0.95, 0.8, 0.6)
	var fade := Gradient.new() # in and out, so no mote pops
	fade.offsets = PackedFloat32Array([0.0, 0.25, 0.75, 1.0])
	fade.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	color_ramp = fade
	emitting = true

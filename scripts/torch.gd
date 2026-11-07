extends Node2D
class_name Torch

## A wall torch set in the early mine (milestone 60): a light that never burns
## down. It is a MineLight like the lantern and lamps, so lit ground does not
## crumble and ropes decay slower beside it, but it is neither a Lamp nor
## snuffable: Snuffers neither spawn for it nor hunt it.
##
## The flame flickers (M87): its brightness wobbles by up to FLICKER either way. Only the look of
## the light moves; its reach (the radius the mine's "is this lit" test uses) never changes.

## The most the light's energy departs from its set value, as a fraction.
const FLICKER := 0.12

@onready var _light: MineLight = $MineLight
var _base_energy: float
var _clock: float
var _phase: float

func _ready() -> void:
	add_to_group(Groups.TORCHES)
	_base_energy = _light.energy_max
	_phase = fposmod(position.x * 0.37 + position.y * 0.11, TAU) # neighbours do not pulse together
	_clock = _phase

func _process(delta: float) -> void:
	_clock += delta
	var energy := _base_energy * flicker(_clock, _phase)
	_light.energy_min = energy
	_light.energy_max = energy

## The brightness multiplier at `time` for a torch with `phase`: three slow sines that do not line
## up, so it wavers instead of pulsing. Always within 1 +/- FLICKER.
static func flicker(time: float, phase: float) -> float:
	var wobble := sin(time * 7.1 + phase) * 0.5 + sin(time * 12.9 + phase * 2.3) * 0.3 + sin(time * 3.3 + phase * 0.7) * 0.2
	return 1.0 + FLICKER * wobble

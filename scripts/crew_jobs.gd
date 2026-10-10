extends RefCounted
class_name CrewJobs

## What the crew do at the run base on their own (milestone 54): the four
## miner types as jobs. The Mender mends the base, the Lamplighter refines ore
## into base fuel, the Climber makes ladders, anchors and lamps, and the
## Whisper hushes the base. Jobs spend the ore the player carries and make
## noise at the base. Rates are Rookie rates; the interval divides by rank
## strength. No scene tree: Main binds it to the run's objects and ticks it.

const MENDER_INTERVAL := 12.0
const MENDER_ORE := 5
const LAMPLIGHTER_INTERVAL := 15.0
const LAMPLIGHTER_ORE := 4
const LAMPLIGHTER_FUEL := 20.0
const LAMPLIGHTER_FULL_FRACTION := 0.9
const CLIMBER_INTERVAL := 60.0
const CLIMBER_ORDER := ["ladders", "anchors", "lamps"]
const CLIMBER_COSTS := {"ladders": 6, "anchors": 10, "lamps": 8}
## The Climber makes at most this many of each item per run, however many are used.
const CLIMBER_MAX_MADE := 2
## 1 noise per second per working miner: the meter drains 8 a second, so anything
## much smaller or rarer would be gone before it could be seen.
const JOB_NOISE := 1.0
const JOB_NOISE_INTERVAL := 1.0
const WHISPER_REDUCTION := 0.25
const WHISPER_MAX_REDUCTION := 0.6

## Crew name -> whether their job could work on the last tick.
var working: Dictionary = {}

var _base: RunBase
var _player: Player
var _noise: NoiseMeter
var _unlocked: Dictionary = {}
var _give_lamp: Callable
var _made: Dictionary = {}
var _state: Dictionary = {}

## Binds the run's objects. `unlocked` is {"ladders", "anchors", "lamps"} -> bool.
func bind(base: RunBase, player: Player, noise_meter: NoiseMeter, unlocked: Dictionary, give_lamp: Callable) -> void:
	_base = base
	_player = player
	_noise = noise_meter
	_unlocked = unlocked
	_give_lamp = give_lamp
	_made.clear()
	_state.clear()
	working.clear()

## The multiplier on noise the base hears from the Whispers on the crew
## (their rank strengths): stacking, never below 1 - WHISPER_MAX_REDUCTION.
static func whisper_factor(strengths: Array) -> float:
	var factor := 1.0
	for strength in strengths:
		factor *= 1.0 - WHISPER_REDUCTION * strength
	return maxf(factor, 1.0 - WHISPER_MAX_REDUCTION)

## Advances every crew member's job by `delta`. `crew` is an Array of
## {"name", "type", "strength"}. A job only gains progress, and only makes
## noise, on ticks where it can work. Each member acts at most once per tick.
func tick(delta: float, crew: Array) -> void:
	working.clear()
	var standing: bool = _base != null and _base.health > 0
	for member in crew:
		var name: String = member.name
		if not standing:
			working[name] = false
			continue
		if member.type == "noise":
			working[name] = true  # hushing the base needs no ore and makes no sound
			continue
		if not _state.has(name):
			_state[name] = {"work": 0.0, "noise": 0.0, "next": 0}
		var state: Dictionary = _state[name]
		var can := _can_work(member.type, state)
		working[name] = can
		if not can:
			continue
		state.work += delta
		state.noise += delta
		if state.noise >= JOB_NOISE_INTERVAL:
			state.noise -= JOB_NOISE_INTERVAL
			_noise.add_noise(JOB_NOISE, _base.global_position)
		if state.work >= _interval(member.type) / member.strength:
			state.work = 0.0
			_act(member.type, state)

func _interval(type: String) -> float:
	match type:
		"repair": return MENDER_INTERVAL
		"light": return LAMPLIGHTER_INTERVAL
	return CLIMBER_INTERVAL

func _can_work(type: String, state: Dictionary) -> bool:
	match type:
		"repair":
			return _base.needs_repair() and _player.currency >= MENDER_ORE
		"light":
			return _base.light.fuel_fraction() < LAMPLIGHTER_FULL_FRACTION and _player.currency >= LAMPLIGHTER_ORE
		"traversal":
			var index := _next_item(state)
			return index >= 0 and _player.currency >= CLIMBER_COSTS[CLIMBER_ORDER[index]]
	return false

func _act(type: String, state: Dictionary) -> void:
	match type:
		"repair":
			_player.currency -= MENDER_ORE
			_base.heal(1)
		"light":
			_player.currency -= LAMPLIGHTER_ORE
			_base.light.add_fuel(LAMPLIGHTER_FUEL)
		"traversal":
			var index := _next_item(state)
			var item: String = CLIMBER_ORDER[index]
			_player.currency -= CLIMBER_COSTS[item]
			_made[item] = _made.get(item, 0) + 1
			match item:
				"ladders": _player.ladders_left += 1
				"anchors": _player.anchors_left += 1
				"lamps": _give_lamp.call()
			state.next = (index + 1) % CLIMBER_ORDER.size()

## Index into CLIMBER_ORDER of the next item to make, starting from this
## member's turn: unlocked and not yet made CLIMBER_MAX_MADE times. -1 when there is none.
func _next_item(state: Dictionary) -> int:
	for step in range(CLIMBER_ORDER.size()):
		var index: int = (state.next + step) % CLIMBER_ORDER.size()
		var item: String = CLIMBER_ORDER[index]
		if _unlocked.get(item, false) and _made.get(item, 0) < CLIMBER_MAX_MADE:
			return index
	return -1

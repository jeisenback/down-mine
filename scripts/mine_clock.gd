extends RefCounted
class_name MineClock

## The mine's own clock (milestone 50): from MINE_WAKE_SECONDS into a run
## it sends a Burrower at the base every wave_interval(), whatever the
## player does. Pure state, no nodes: Main ticks it and does the spawning.
const MINE_WAKE_SECONDS := 240.0
const WAVE_INTERVAL_START := 90.0
const WAVE_INTERVAL_END := 45.0
const WAVE_WARNING_SECONDS := 10.0
const HEART_INTERVAL_MULTIPLIER := 0.5 # carrying the Heart halves it
## Rhythm of threat (milestone 55): waves come in cycles of five, the fifth a
## peak. The first cycle brings these Burrowers; each later cycle adds one to
## every count. After a peak the next wave is a calm, this many intervals away.
const WAVE_CYCLE_SIZES := [1, 1, 2, 2, 4]
const CALM_MULTIPLIER := 2.0

## Waves that have surfaced so far (the one being handled counts).
var wave_number: int = 0
var _countdown: float = -1.0 # seconds to the next wave; -1 = not started
var _warned: bool = false
var _calm: bool = false # the last wave was a peak; the next one is a calm away

## Burrowers in wave n (counting from 1).
static func wave_size(n: int) -> int:
	var index := maxi(n, 1) - 1
	return WAVE_CYCLE_SIZES[index % WAVE_CYCLE_SIZES.size()] + index / WAVE_CYCLE_SIZES.size()

## Every fifth wave.
static func is_peak(n: int) -> bool:
	return n > 0 and n % WAVE_CYCLE_SIZES.size() == 0

## After a peak, until the next wave surfaces.
func in_calm() -> bool:
	return _calm

## Seconds to the next wave, or -1 before the mine wakes.
func seconds_to_next() -> float:
	return _countdown

func next_wave_number() -> int:
	return wave_number + 1

## Seconds between waves: 90 at the wake time, shrinking to 45 by the end
## of the mine's decay ramp, halved while carrying the Heart.
static func wave_interval(run_seconds: float, carrying_heart: bool) -> float:
	var ramp := clampf((run_seconds - MINE_WAKE_SECONDS) / (MineGrid.DECAY_RAMP_TIME - MINE_WAKE_SECONDS), 0.0, 1.0)
	var interval: float = lerp(WAVE_INTERVAL_START, WAVE_INTERVAL_END, ramp)
	return interval * (HEART_INTERVAL_MULTIPLIER if carrying_heart else 1.0)

## "" most ticks; "warn" once when WAVE_WARNING_SECONDS remain; "wave" when
## one surfaces. The countdown never exceeds the current interval, so
## taking the Heart shortens a wave already pending.
func tick(delta: float, run_seconds: float, carrying_heart: bool) -> String:
	if run_seconds < MINE_WAKE_SECONDS:
		return ""
	var interval := wave_interval(run_seconds, carrying_heart)
	var limit := interval * (CALM_MULTIPLIER if _calm else 1.0)
	if _countdown < 0.0:
		_countdown = limit
	_countdown = minf(_countdown, limit) - delta
	if _countdown <= 0.0:
		wave_number += 1
		_calm = is_peak(wave_number)
		_countdown = interval * (CALM_MULTIPLIER if _calm else 1.0)
		_warned = false
		return "wave"
	if not _warned and _countdown <= WAVE_WARNING_SECONDS:
		_warned = true
		return "warn"
	return ""

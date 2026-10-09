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

var _countdown: float = -1.0 # seconds to the next wave; -1 = not started
var _warned: bool = false

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
	if _countdown < 0.0:
		_countdown = interval
	_countdown = minf(_countdown, interval) - delta
	if _countdown <= 0.0:
		_countdown = interval
		_warned = false
		return "wave"
	if not _warned and _countdown <= WAVE_WARNING_SECONDS:
		_warned = true
		return "warn"
	return ""

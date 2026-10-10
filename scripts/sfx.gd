extends RefCounted
class_name Sfx

## Sound effects (milestone 31). The Deep Night pack has no audio, so each
## effect is synthesized once, at first use, into a short 16-bit mono
## AudioStreamWAV - no audio files to license or credit. Played through a
## small pool of AudioStreamPlayers kept on the scene root (it survives
## scene reloads between runs, and is rebuilt if something frees it).
##
##   Sfx.play("dig")                 # full volume
##   Sfx.play("collapse", -12.0)     # quieter, e.g. far away

const SAMPLE_RATE := 22050
const POOL_SIZE := 8
const SOUNDS := ["dig", "hit", "ore", "fuel", "place", "collapse", "hiss", "alarm", "rumble"]

# The pool node also holds the synthesized streams (as metadata), so they
# are freed with the scene tree at exit - a static cache would still be
# alive at Godot's exit leak check and get reported as leaked.
static var _pool: Node = null

## Synthesizes every effect (~40ms) and builds the pool. Main calls this
## while a run loads, so the first dig doesn't stutter.
static func warm_up() -> void:
	for name in SOUNDS:
		stream(name)

static func play(sound: String, volume_db: float = 0.0) -> void:
	warm_up() # no-op once warm
	if not is_instance_valid(_pool) or not _pool.is_inside_tree():
		return
	var player: AudioStreamPlayer = null
	for p in _pool.get_children():
		if not p.playing:
			player = p
			break
	if player == null: # all busy: steal the first one
		player = _pool.get_child(0)
	player.stream = stream(sound)
	player.volume_db = volume_db
	player.play()

static func stream(sound: String) -> AudioStreamWAV:
	if not is_instance_valid(_pool):
		_build_pool()
	if not is_instance_valid(_pool): # no scene tree to cache on
		return _make(sound)
	var streams: Dictionary = _pool.get_meta("streams")
	if not streams.has(sound):
		streams[sound] = _make(sound)
	return streams[sound]

static func _build_pool() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	_pool = Node.new()
	_pool.name = "SfxPool"
	_pool.set_meta("streams", {})
	_pool.process_mode = Node.PROCESS_MODE_ALWAYS # hub sounds while paused
	for i in range(POOL_SIZE):
		_pool.add_child(AudioStreamPlayer.new())
	tree.root.add_child(_pool)

## Stops every sound. Quitting while a sound is still playing makes
## Godot report its playback as "leaked" at exit (harmless - the process
## is ending - but noisy), so the test runner calls this before quitting.
static func stop_all() -> void:
	if is_instance_valid(_pool):
		for p in _pool.get_children():
			p.stop()

## Builds one effect from a few primitives: tone (with pitch sweep),
## filtered noise, and an exponential decay envelope.
static func _make(sound: String) -> AudioStreamWAV:
	match sound:
		"dig":      return _render(0.12, func(t, n): return _lowpass_noise(n, 0.35) * _decay(t, 0.03))
		"hit":      return _render(0.25, func(t, n): return (_tone(t, 110.0, 50.0, 0.25) * 0.8 + n * 0.2) * _decay(t, 0.07))
		"ore":      return _render(0.35, func(t, n): return (_tone(t, 880.0) + _tone(t, 1320.0) * 0.5) * 0.5 * _decay(t, 0.09))
		"fuel":     return _render(0.22, func(t, n): return _tone(t, 500.0, 950.0, 0.22) * 0.6 * _decay(t, 0.12))
		"place":    return _render(0.10, func(t, n): return (_tone(t, 180.0) * 0.6 + n * 0.3) * _decay(t, 0.025))
		"collapse": return _render(0.6, func(t, n): return _lowpass_noise(n, 0.08) * 1.6 * _decay(t, 0.2))
		"hiss":     return _render(1.0, func(t, n): return (n - _lowpass_noise(n, 0.3)) * 0.5 * minf(1.0, t * 20.0) * _decay(t, 0.45))
		"rumble":   return _render(0.7, func(t, n): return _lowpass_noise(n, 0.07) * 2.4 * minf(1.0, t * 12.0) * _decay(t, 0.28))
		"alarm":    return _render(0.5, func(t, n): return signf(sin(TAU * 440.0 * t)) * 0.3 * (1.0 if fmod(t, 0.25) < 0.15 else 0.0))
	return _render(0.05, func(t, n): return 0.0)

static var _lp_state: float = 0.0

static func _lowpass_noise(n: float, amount: float) -> float:
	_lp_state += (n - _lp_state) * amount
	return _lp_state

static func _tone(t: float, from_hz: float, to_hz: float = -1.0, sweep_seconds: float = 1.0) -> float:
	if to_hz < 0.0:
		return sin(TAU * from_hz * t)
	# Integrated linear sweep, so the pitch glides without clicks.
	var k := (to_hz - from_hz) / sweep_seconds
	return sin(TAU * (from_hz * t + 0.5 * k * t * t))

static func _decay(t: float, time_constant: float) -> float:
	return exp(-t / time_constant)

static func _render(seconds: float, sample: Callable) -> AudioStreamWAV:
	_lp_state = 0.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 1 # the same sound every time
	var count := int(seconds * SAMPLE_RATE)
	var data := PackedByteArray()
	data.resize(count * 2)
	for i in range(count):
		var value: float = sample.call(i / float(SAMPLE_RATE), rng.randf_range(-1.0, 1.0))
		data.encode_s16(i * 2, int(clampf(value, -1.0, 1.0) * 32000.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = SAMPLE_RATE
	wav.stereo = false
	wav.data = data
	return wav

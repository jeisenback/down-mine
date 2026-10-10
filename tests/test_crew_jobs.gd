extends TestCase

## Crew jobs (workers and jobs, milestone 54): rates by rank, ore and noise
## costs, unlocks and caps, and everything that must stop them.

const PlayerScene := preload("res://scenes/Player.tscn")
const RunBaseScene := preload("res://scenes/RunBase.tscn")

var base: RunBase
var player: Player
var meter: NoiseMeter
var jobs: CrewJobs
var lamps: Array = [3]

func _rig(unlocked: Dictionary = {"ladders": true, "anchors": true, "lamps": true}) -> void:
	base = add(RunBaseScene.instantiate())
	base.global_position = Vector2.ZERO
	player = add(PlayerScene.instantiate())
	player.set_physics_process(false)
	player.light.burn_rate = 0.0
	meter = add(NoiseMeter.new())
	meter.decay_rate = 0.0
	meter.base_position = func(): return base.global_position
	var stock := [3] # captured by the callables instead of self, so the test case holds no cycle
	lamps = stock
	jobs = CrewJobs.new()
	jobs.bind(base, player, meter, unlocked, func(): return stock[0], func(): stock[0] += 1)

func _member(type: String, strength: float = 1.0, name: String = "") -> Dictionary:
	return {"name": name if name != "" else type, "type": type, "strength": strength}

func test_mender_heals_one_health_per_twelve_seconds_and_charges_ore() -> void:
	_rig()
	base.health = 1
	player.currency = 20
	jobs.tick(11.9, [_member("repair")])
	assert_eq(base.health, 1, "not yet")
	assert_eq(player.currency, 20, "no ore spent yet")
	jobs.tick(0.2, [_member("repair")])
	assert_eq(base.health, 2, "healed")
	assert_eq(player.currency, 15, "5 ore")

func test_rank_scales_every_job() -> void:
	_rig()
	base.health = 1
	player.currency = 50
	jobs.tick(5.9, [_member("repair", 2.0)])
	assert_eq(base.health, 1, "a veteran Mender is not there yet at 5.9 s")
	jobs.tick(0.2, [_member("repair", 2.0)])
	assert_eq(base.health, 2, "but heals after 6 s")
	base.light.fuel = base.light.max_fuel * 0.5
	var before: float = base.light.fuel
	jobs.tick(9.9, [_member("light", 1.5)])
	assert_eq(base.light.fuel, before, "seasoned Lamplighter not yet at 9.9 s")
	jobs.tick(0.2, [_member("light", 1.5)])
	assert_eq(base.light.fuel, before + CrewJobs.LAMPLIGHTER_FUEL, "refines after 10 s")

func test_lamplighter_refines_ore_into_base_fuel_only_below_ninety_percent() -> void:
	_rig()
	player.currency = 10
	base.light.fuel = base.light.max_fuel * 0.5
	var before: float = base.light.fuel
	jobs.tick(15.1, [_member("light")])
	assert_eq(base.light.fuel, before + 20.0, "+20 fuel")
	assert_eq(player.currency, 6, "4 ore")
	base.light.fuel = base.light.max_fuel * 0.95
	jobs.tick(30.0, [_member("light")])
	assert_eq(base.light.fuel, base.light.max_fuel * 0.95, "nothing added near full")
	assert_eq(player.currency, 6, "no ore wasted near full")

func test_climber_rotates_ladder_anchor_lamp_and_charges_each() -> void:
	_rig()
	player.currency = 100
	var ladders: int = player.ladders_left
	var anchors: int = player.anchors_left
	jobs.tick(60.1, [_member("traversal")])
	assert_eq(player.ladders_left, ladders + 1, "ladder first")
	assert_eq(player.currency, 94, "6 ore")
	jobs.tick(60.1, [_member("traversal")])
	assert_eq(player.anchors_left, anchors + 1, "then an anchor")
	assert_eq(player.currency, 84, "10 ore")
	jobs.tick(60.1, [_member("traversal")])
	assert_eq(lamps[0], 4, "then a lamp")
	assert_eq(player.currency, 76, "8 ore")

func test_climber_respects_unlocks_and_caps() -> void:
	_rig({"ladders": true, "anchors": false, "lamps": true})
	player.currency = 100
	var anchors: int = player.anchors_left
	jobs.tick(60.1, [_member("traversal")])
	jobs.tick(60.1, [_member("traversal")])
	assert_eq(player.anchors_left, anchors, "locked anchors are never made")
	assert_eq(lamps[0], 4, "the second item skipped to a lamp")
	_rig()
	player.currency = 100
	player.ladders_left += CrewJobs.CLIMBER_CAP_OVER_START
	var ladders: int = player.ladders_left
	jobs.tick(60.1, [_member("traversal")])
	assert_eq(player.ladders_left, ladders, "capped ladders are skipped")
	assert_eq(player.anchors_left, Player.ANCHORS_PER_RUN + 1, "so an anchor came first")
	_rig({"ladders": false, "anchors": false, "lamps": false})
	player.currency = 100
	jobs.tick(300.0, [_member("traversal")])
	assert_eq(player.currency, 100, "nothing to make: no ore spent")
	assert_true(not jobs.working["traversal"], "and not working")

func test_whisper_factor_stacks_and_caps() -> void:
	assert_eq(CrewJobs.whisper_factor([1.0]), 0.75, "rookie")
	assert_eq(CrewJobs.whisper_factor([2.0]), 0.5, "veteran")
	assert_eq(CrewJobs.whisper_factor([1.0, 1.0]), 0.5625, "two rookies multiply")
	assert_eq(CrewJobs.whisper_factor([2.0, 2.0, 2.0]), 1.0 - CrewJobs.WHISPER_MAX_REDUCTION, "capped")
	assert_eq(CrewJobs.whisper_factor([]), 1.0, "none")

func test_working_miners_make_one_noise_per_ten_seconds_except_the_whisper() -> void:
	_rig()
	base.health = 1
	player.currency = 100
	jobs.tick(10.0, [_member("repair"), _member("noise")])
	assert_eq(meter.noise, 1.0, "one noise, from the Mender only")
	assert_true(jobs.working["repair"] and jobs.working["noise"], "both working")

func test_a_job_that_cannot_work_makes_no_noise_and_gains_no_progress() -> void:
	_rig()
	player.currency = 100
	jobs.tick(30.0, [_member("repair")])
	assert_eq(meter.noise, 0.0, "no noise at full health")
	assert_true(not jobs.working["repair"], "not working")
	base.health = 1
	jobs.tick(11.9, [_member("repair")])
	assert_eq(base.health, 1, "the idle time did not bank progress")
	jobs.tick(0.2, [_member("repair")])
	assert_eq(base.health, 2, "the full twelve seconds still apply")

func test_ore_never_goes_negative_and_jobs_wait_for_it() -> void:
	_rig()
	base.health = 1
	base.light.fuel = base.light.max_fuel * 0.5
	var fuel: float = base.light.fuel
	player.currency = 5
	jobs.tick(15.0, [_member("repair"), _member("light")])
	assert_eq(player.currency, 0, "the Mender took the last ore")
	assert_eq(base.health, 2, "and healed")
	assert_eq(base.light.fuel, fuel, "the Lamplighter had none left")
	assert_true(not jobs.working["light"], "and is not working")

func test_nothing_works_after_the_base_falls() -> void:
	_rig()
	base.health = 0
	player.currency = 100
	jobs.tick(200.0, [_member("repair"), _member("light"), _member("noise"), _member("traversal")])
	assert_eq(player.currency, 100, "no spend")
	assert_eq(meter.noise, 0.0, "no noise")
	for name in ["repair", "light", "noise", "traversal"]:
		assert_true(not jobs.working[name], "%s idle" % name)

func test_heal_stops_at_full_health_and_at_zero() -> void:
	_rig()
	base.health = 1
	base.heal(5)
	assert_eq(base.health, RunBase.MAX_HEALTH, "capped")
	base.health = 0
	base.heal(1)
	assert_eq(base.health, 0, "a fallen base stays down")

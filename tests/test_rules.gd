extends TestCase

## Pure rules: fall damage, hub purchases, NPC rescue/stranding/drift,
## crew experience and ranks.

func _speed_for_fall(tiles: float) -> float:
	return sqrt(2.0 * Player.GRAVITY * tiles * MineGrid.TILE_SIZE)

func _progress() -> Progress:
	var p := Progress.new()
	p.save_path = TEST_SAVE_PATH
	return p

func test_fall_damage_thresholds() -> void:
	for case in [[2.0, 0], [6.9, 0], [7.1, 1], [9.9, 1], [10.1, 2], [13.1, 2], [30.0, Player.MAX_FALL_DAMAGE]]:
		assert_eq(Player.fall_damage_for_speed(_speed_for_fall(case[0])), case[1], "fall of %s tiles" % case[0])

func test_hub_purchase_costs_scale_and_cap() -> void:
	var p := _progress()
	p.banked_ore = 100
	assert_true(p.try_buy("lantern"), "level 1 affordable")
	assert_eq(p.banked_ore, 70, "level 1 costs 30")
	assert_true(p.try_buy("lantern"), "level 2 affordable")
	assert_eq(p.banked_ore, 10, "level 2 costs 60")
	assert_true(not p.try_buy("lantern"), "level 3 (90) unaffordable")
	assert_eq(p.level("lantern"), 2, "lantern level")

func test_tool_unlocks_are_one_time_purchases() -> void:
	var p := _progress()
	p.banked_ore = 200
	assert_true(not p.has_unlock("anchors"), "locked at first")
	assert_true(p.try_buy("anchors"), "affordable")
	assert_eq(p.banked_ore, 100, "anchors cost 100")
	assert_true(p.has_unlock("anchors"), "unlocked")
	assert_true(not p.try_buy("anchors"), "can't buy twice")
	assert_eq(p.banked_ore, 100, "no second charge")

func test_rescue_joins_roster_and_fills_free_crew_slot() -> void:
	var p := _progress()
	p.end_run([{"name": "Ada", "type": "light", "found_in": 1}], [], true)
	assert_eq(p.roster.size(), 1, "roster size")
	assert_eq(p.crew_names, ["Ada"], "crew")

func test_failed_escort_is_stranded_in_its_layer() -> void:
	var p := _progress()
	p.end_run([], [{"name": "Bram", "type": "noise", "layer": 1}], false)
	assert_eq(p.stranded.size(), 1, "stranded count")
	assert_eq(p.stranded[0].layer, 1, "stranded layer")
	assert_true(p.roster.is_empty(), "not on roster")

func test_stranded_miners_drift_then_die() -> void:
	var p := _progress()
	var last_layer := MineGrid.LAYERS.size() - 1
	p.stranded = [{"name": "Cole", "type": "light", "layer": last_layer - 1}]
	p.end_run([], [], true)
	assert_eq(p.stranded[0].layer, last_layer, "drifted one layer")
	var notes := p.end_run([], [], true)
	assert_true(p.stranded.is_empty(), "gone after drifting past the last layer")
	assert_true(notes.any(func(n): return "lost for good" in n), "death announced")

func test_crew_gain_experience_only_on_extraction() -> void:
	var p := _progress()
	p.roster = [{"name": "Dita", "type": "light", "runs": 1}]
	p.crew_names = ["Dita"]
	p.end_run([], [], false)
	assert_eq(p.roster[0].runs, 1, "failed run gives nothing")
	var notes := p.end_run([], [], true)
	assert_eq(p.roster[0].runs, 2, "extraction gives a run")
	assert_eq(p.rank_of(p.roster[0]).name, "Seasoned", "rank at 2 runs")
	assert_true(notes.any(func(n): return "Seasoned" in n), "rank-up announced")

func test_stranded_crew_leave_roster_and_keep_history() -> void:
	var p := _progress()
	p.roster = [{"name": "Fenn", "type": "repair", "runs": 6, "found_in": 2}]
	p.crew_names = ["Fenn"]
	p.end_run([], [{"name": "Fenn", "type": "repair", "layer": 1}], false)
	assert_true(p.roster.is_empty(), "stranded crew leave the roster")
	assert_true(p.crew().is_empty(), "and the crew (no bonus)")
	assert_eq(p.stranded[0].runs, 6, "experience travels with them")
	var notes := p.end_run([{"name": "Fenn", "type": "repair", "found_in": 1}], [], true)
	assert_eq(p.roster[0].runs, 6, "rescue restores experience")
	assert_eq(p.roster[0].found_in, 2, "and history")
	assert_eq(p.crew_names, ["Fenn"], "back on the crew")
	assert_true(notes.any(func(n): return "Fenn the Mender" in n), "rescued as a Veteran")

func test_promotion_to_veteran_grants_a_quirk() -> void:
	var p := _progress()
	p.roster = [{"name": "Greta", "type": "noise", "runs": 4}]
	p.crew_names = ["Greta"]
	var notes := p.end_run([], [], true)
	assert_true(p.roster[0].has("quirk"), "new Veteran has a quirk")
	assert_true(p.roster[0].quirk in Progress.QUIRKS, "quirk is a known one")
	assert_true(notes.any(func(n): return "quirk" in n), "quirk announced")
	var vets: Array = []
	for i in range(Progress.QUIRKS.size()):
		vets.append({"name": "V%d" % i, "type": "light", "runs": 5})
	p.roster = vets
	p._assign_missing_quirks()
	var quirks := vets.map(func(v): return v.quirk)
	for q in Progress.QUIRKS:
		assert_true(q in quirks, "no repeats until every quirk is taken (%s missing)" % q)
	var seasoned := {"name": "Hale", "type": "light", "runs": 2}
	p.roster.append(seasoned)
	p._assign_missing_quirks()
	assert_true(not seasoned.has("quirk"), "only Veterans get quirks")

func test_quirk_survives_stranding_and_rescue() -> void:
	var p := _progress()
	p.roster = [{"name": "Iris", "type": "light", "runs": 7, "quirk": "pack_rat"}]
	p.crew_names = ["Iris"]
	assert_eq(p.extra_lamps(), 1, "pack rat on the crew adds a lamp")
	p.end_run([], [{"name": "Iris", "type": "light", "layer": 0}], false)
	assert_eq(p.extra_lamps(), 0, "no lamp while stranded")
	p.end_run([{"name": "Iris", "type": "light", "found_in": 0}], [], true)
	assert_eq(p.roster[0].get("quirk", ""), "pack_rat", "quirk kept through rescue")

func test_sure_footed_raises_safe_fall() -> void:
	var seven := _speed_for_fall(7.5)
	assert_eq(Player.fall_damage_for_speed(seven), 1, "7.5 tiles hurts by default")
	assert_eq(Player.fall_damage_for_speed(seven, Player.SAFE_FALL_TILES + Progress.SURE_FOOTED_TILES), 0, "sure-footed takes it")

func test_veteran_bonus_and_title() -> void:
	var p := _progress()
	var vet := {"name": "Ezra", "type": "noise", "runs": 5}
	assert_eq(p.rank_of(vet).strength, 2.0, "veteran strength")
	assert_eq(p.display_name(vet), "Ezra the Whisper", "veteran title")
	assert_eq(p.effect_text(vet), "noise -50%", "doubled bonus")

func test_hearing_falls_linearly_to_zero_at_80_tiles() -> void:
	assert_eq(NoiseMeter.hearing(0.0), 1.0, "full at the base")
	assert_eq(NoiseMeter.hearing(40.0), 0.5, "half at 40 tiles")
	assert_eq(NoiseMeter.hearing(80.0), 0.0, "nothing at 80")
	assert_eq(NoiseMeter.hearing(500.0), 0.0, "never negative")

func test_noise_is_scaled_by_distance_from_the_base() -> void:
	var meter: NoiseMeter = add(NoiseMeter.new())
	meter.decay_rate = 0.0
	meter.base_position = func(): return Vector2.ZERO
	meter.add_noise(40.0, Vector2.ZERO)
	assert_eq(meter.noise, 40.0, "at the base: full")
	meter.noise = 0.0
	meter.add_noise(40.0, Vector2(40 * MineGrid.TILE_SIZE, 0))
	assert_eq(meter.noise, 20.0, "40 tiles away: half")
	meter.noise = 0.0
	meter.noise_multiplier = 0.5
	meter.add_noise(40.0, Vector2.ZERO)
	assert_eq(meter.noise, 20.0, "crew multiplier still applies after hearing")

func test_quiet_layers_are_judged_at_the_sound() -> void:
	var meter: NoiseMeter = add(NoiseMeter.new())
	meter.decay_rate = 0.0
	meter.quiet_at = func(pos: Vector2): return pos.y < 100.0
	var heard: Array = []
	meter.noise_made.connect(func(pos, amount): heard.append(pos))
	meter.add_noise(30.0, Vector2(0, 50))
	assert_eq(meter.noise, 0.0, "sound in a quiet layer adds nothing")
	assert_eq(heard.size(), 0, "and alerts nothing")
	meter.add_noise(30.0, Vector2(0, 500))
	assert_eq(heard.size(), 1, "sound below the quiet floor is announced")

func test_wave_interval_shrinks_with_the_decay_ramp_and_halves_with_the_heart() -> void:
	assert_eq(MineClock.wave_interval(240.0, false), 90.0, "starts at 90 s")
	assert_eq(MineClock.wave_interval(360.0, false), 67.5, "halfway down the ramp")
	assert_eq(MineClock.wave_interval(480.0, false), 45.0, "45 s at the end of the ramp")
	assert_eq(MineClock.wave_interval(2000.0, false), 45.0, "clamped after")
	assert_eq(MineClock.wave_interval(240.0, true), 45.0, "Heart halves it")

func test_clock_is_silent_until_240_then_warns_then_waves() -> void:
	var clock := MineClock.new()
	var t := 0.0
	var events: Array = []
	while t < 239.0:
		t += 1.0
		assert_eq(clock.tick(1.0, t, false), "", "silent before the mine wakes (t=%d)" % t)
	while t < 340.0 and events.size() < 2:
		t += 1.0
		var event := clock.tick(1.0, t, false)
		if event != "":
			events.append([event, t])
	assert_eq(events[0][0], "warn", "warning first")
	assert_eq(events[1][0], "wave", "then the wave")
	assert_true(absf((events[1][1] - events[0][1]) - MineClock.WAVE_WARNING_SECONDS) <= 1.0, "warning comes 10 s ahead")
	assert_true(events[1][1] >= 240.0 + 89.0 and events[1][1] <= 240.0 + 92.0, "first wave about 90 s after waking")

func test_taking_the_heart_shortens_a_pending_wave() -> void:
	var clock := MineClock.new()
	clock.tick(1.0, 240.0, false) # starts a 90 s countdown
	var event := ""
	var t := 240.0
	while event != "wave" and t < 300.0:
		t += 1.0
		event = clock.tick(1.0, t, true)
	assert_eq(event, "wave", "wave arrives within the halved interval")
	assert_true(t < 240.0 + 46.0, "about 45 s, not 90 (t=%d)" % t)

func test_run_log_counts_waves_and_old_entries_still_print() -> void:
	var line := Progress.run_log_line({"result": "Base fell", "seconds": 300, "depth": 50, "ore": 3, "burrowers": 1, "waves": 2, "seed": 7})
	assert_true(line.contains("2 waves"), "waves are shown")
	var old := Progress.run_log_line({"result": "Extracted", "seconds": 60, "depth": 5, "ore": 0, "burrowers": 0, "seed": 7})
	assert_true(not old.contains("wave"), "old entries unchanged")

func test_job_crew_lists_name_type_and_rank_strength() -> void:
	var p := _progress()
	p.roster = [{"name": "Ana", "type": "repair", "runs": 0}, {"name": "Ben", "type": "light", "runs": 5}, {"name": "Cy", "type": "noise", "runs": 0}]
	p.crew_names = ["Ana", "Ben"]
	assert_eq(p.job_crew(), [
		{"name": "Ana", "type": "repair", "strength": 1.0},
		{"name": "Ben", "type": "light", "strength": 2.0},
	], "only the crew, each with their rank's strength")

func test_effect_text_describes_the_job() -> void:
	var p := _progress()
	assert_eq(p.effect_text({"name": "A", "type": "repair", "runs": 0}), "repairs the base 1 health per 12 s, 5 ore", "Mender")
	assert_eq(p.effect_text({"name": "A", "type": "repair", "runs": 5}), "repairs the base 1 health per 6 s, 5 ore", "Veteran Mender")
	assert_eq(p.effect_text({"name": "A", "type": "light", "runs": 0}), "refines 4 ore into 20 base fuel every 15 s", "Lamplighter")
	assert_eq(p.effect_text({"name": "A", "type": "traversal", "runs": 0}), "makes a ladder, anchor or lamp every 60 s", "Climber")
	assert_eq(p.effect_text({"name": "A", "type": "noise", "runs": 0}), "noise -25%", "Whisper")

# --- the wave cycle (rhythm of threat, milestone 55) --------------------------------

## Ticks a fresh clock a second at a time from the wake, returning the run
## time of each wave until `count` have come.
func _wave_times(clock: MineClock, count: int, carrying_heart: bool = false) -> Array:
	var times: Array = []
	var t := MineClock.MINE_WAKE_SECONDS - 1.0
	while times.size() < count and t < 3000.0:
		t += 1.0
		if clock.tick(1.0, t, carrying_heart) == "wave":
			times.append(t)
	return times

func test_wave_sizes_cycle_and_grow() -> void:
	var sizes: Array = []
	for n in range(1, 11):
		sizes.append(MineClock.wave_size(n))
	assert_eq(sizes, [1, 1, 2, 2, 4, 2, 2, 3, 3, 5], "two cycles")
	assert_eq(MineClock.wave_size(11), 3, "the third cycle starts at 3")

func test_every_fifth_wave_is_a_peak() -> void:
	for n in [5, 10, 15]:
		assert_true(MineClock.is_peak(n), "wave %d is a peak" % n)
	for n in [1, 4, 6, 9]:
		assert_true(not MineClock.is_peak(n), "wave %d is not" % n)

func test_a_calm_follows_each_peak() -> void:
	var clock := MineClock.new()
	var times := _wave_times(clock, 5)
	assert_eq(clock.wave_number, 5, "five waves so far")
	assert_true(clock.in_calm(), "calm after the peak")
	var interval := MineClock.wave_interval(times[4], false)
	assert_true(absf(clock.seconds_to_next() - MineClock.CALM_MULTIPLIER * interval) <= 1.5, "the countdown is a calm, not one interval (%f)" % clock.seconds_to_next())
	var t: float = times[4]
	var next := 0.0
	while next == 0.0 and t < 3000.0:
		t += 1.0
		if clock.tick(1.0, t, false) == "wave":
			next = t
	assert_true(absf((next - times[4]) - 2.0 * interval) <= 1.5, "the sixth wave comes two intervals later (%f)" % (next - times[4]))
	assert_true(not clock.in_calm(), "the calm is over")
	var after := 0.0
	while after == 0.0 and t < 3000.0:
		t += 1.0
		if clock.tick(1.0, t, false) == "wave":
			after = t
	assert_true(absf((after - next) - MineClock.wave_interval(next, false)) <= 1.5, "back to one interval between ordinary waves")

func test_seconds_to_next_before_and_after_the_wake() -> void:
	var clock := MineClock.new()
	assert_eq(clock.seconds_to_next(), -1.0, "not started")
	clock.tick(1.0, 100.0, false)
	assert_eq(clock.seconds_to_next(), -1.0, "still asleep at 100 s")
	clock.tick(1.0, 240.0, false)
	assert_true(absf(clock.seconds_to_next() - 89.0) <= 1.0, "about 90 right after the wake")
	var before := clock.seconds_to_next()
	clock.tick(2.0, 242.0, false)
	assert_eq(clock.seconds_to_next(), before - 2.0, "counts down with the delta")
	assert_eq(clock.next_wave_number(), 1, "the first wave is next")

func test_the_heart_halves_a_calm_and_keeps_the_cycle_position() -> void:
	var clock := MineClock.new()
	var times := _wave_times(clock, 5)
	var t: float = times[4]
	var event := ""
	var waited := 0.0
	while event != "wave" and waited < 200.0:
		t += 1.0
		waited += 1.0
		event = clock.tick(1.0, t, true)
	assert_eq(event, "wave", "a wave comes")
	assert_true(waited <= MineClock.CALM_MULTIPLIER * MineClock.wave_interval(t, true) + 1.5, "within the halved calm (%f)" % waited)
	assert_eq(clock.wave_number, 6, "the sixth wave, not a restart")
	assert_eq(MineClock.wave_size(clock.wave_number), 2, "of size two")

func test_wave_number_counts_each_wave() -> void:
	var clock := MineClock.new()
	assert_eq(clock.wave_number, 0, "none yet")
	_wave_times(clock, 3)
	assert_eq(clock.wave_number, 3, "three waves")

func test_wave_line_wording() -> void:
	assert_eq(MineClock.hud_text(-1.0, 1, false, false, 100.0), "Mine wakes in 140 s", "before the wake")
	assert_eq(MineClock.hud_text(41.2, 3, false, false, 300.0), "Wave in 42 s", "rounded up, no size without the bell")
	assert_eq(MineClock.hud_text(41.2, 5, false, false, 300.0), "Wave in 42 s: PEAK", "a peak is always marked")
	assert_eq(MineClock.hud_text(30.0, 3, false, true, 300.0), "Wave in 30 s: 2 Burrowers", "the bell adds the size")
	assert_eq(MineClock.hud_text(30.0, 1, false, true, 300.0), "Wave in 30 s: 1 Burrower", "singular")
	assert_eq(MineClock.hud_text(30.0, 5, false, true, 300.0), "Wave in 30 s: 4 Burrowers, PEAK", "peak with the bell")
	assert_eq(MineClock.hud_text(80.0, 6, true, false, 560.0), "Calm: next wave in 80 s", "during a calm")
	assert_eq(MineClock.hud_text(80.0, 6, true, true, 560.0), "Calm: next wave in 80 s: 2 Burrowers", "calm with the bell")

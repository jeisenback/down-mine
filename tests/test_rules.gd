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

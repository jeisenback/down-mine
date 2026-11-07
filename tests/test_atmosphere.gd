extends TestCase

## Slow, atmospheric exploration (M87): flickering torches and sparse ambient sound. Both are
## cosmetic: a torch's reach is untouched, and the ambience has its own random numbers.

const TorchScene := preload("res://scenes/Torch.tscn")

# --- torch flicker ------------------------------------------------------------------------

func test_the_flicker_stays_within_its_band_and_moves() -> void:
	var lowest := 10.0
	var highest := -10.0
	for i in range(1200):
		var f := Torch.flicker(i * 0.05, 1.3)
		lowest = minf(lowest, f)
		highest = maxf(highest, f)
	assert_true(lowest >= 1.0 - Torch.FLICKER - 0.0001 and highest <= 1.0 + Torch.FLICKER + 0.0001, "within the band (%.3f to %.3f)" % [lowest, highest])
	assert_true(highest - lowest > Torch.FLICKER, "it really moves (range %.3f)" % (highest - lowest))

func test_neighbouring_torches_do_not_pulse_together() -> void:
	assert_true(not is_equal_approx(Torch.flicker(2.0, 0.0), Torch.flicker(2.0, 2.0)), "different phases differ")

func test_a_torch_flickers_its_light_but_not_its_reach() -> void:
	var torch: Torch = TorchScene.instantiate()
	torch.position = Vector2(100, 100)
	add(torch)
	var light: MineLight = torch.get_node("MineLight")
	var energies := {}
	for i in range(90):
		await tree.process_frame
		energies[snappedf(light.point_light.energy, 0.001)] = true
		assert_eq(light.current_radius(), 90.0, "the reach never changes")
	assert_true(energies.size() > 5, "the light's energy varies (%d values)" % energies.size())
	assert_true(MineLight.is_lit(tree, torch.global_position + Vector2(85, 0)), "lit just inside its reach")
	assert_true(not MineLight.is_lit(tree, torch.global_position + Vector2(95, 0)), "dark just outside it")

# --- ambient sound ------------------------------------------------------------------------

func _ambience(rng_seed: int = 5) -> Ambience:
	var ambience := Ambience.new()
	ambience.rng.seed = rng_seed
	ambience.schedule()
	return ambience

## Runs `seconds` in half-second steps; returns [time, sound] for every sound that fired.
func _run(ambience: Ambience, seconds: float, below_crust: bool, in_workings: bool) -> Array:
	var heard: Array = []
	var t := 0.0
	while t < seconds:
		t += 0.5
		var sound := ambience.advance(0.5, below_crust, in_workings)
		if sound != "":
			heard.append([t, sound])
	return heard

func test_nothing_plays_on_the_surface() -> void:
	assert_eq(_run(_ambience(), 300.0, false, false), [], "silent above the crust")

func test_drips_come_every_six_to_fourteen_seconds_below_the_crust() -> void:
	var drips := _run(_ambience(), 600.0, true, false).filter(func(h): return h[1] == "drip")
	assert_true(drips.size() >= 600.0 / Ambience.DRIP_MAX - 1 and drips.size() <= 600.0 / Ambience.DRIP_MIN + 1, "about one every 6 to 14 s (%d in 600 s)" % drips.size())
	for i in range(1, drips.size()):
		var gap: float = drips[i][0] - drips[i - 1][0]
		assert_true(gap >= Ambience.DRIP_MIN - 0.5 and gap <= Ambience.DRIP_MAX + 0.5, "gap %.1f s within the band" % gap)

func test_creaks_come_only_in_the_old_workings() -> void:
	var outside := _run(_ambience(), 400.0, true, false).filter(func(h): return h[1] == "creak")
	assert_eq(outside.size(), 0, "no creaks in plain rock")
	var inside := _run(_ambience(), 600.0, true, true).filter(func(h): return h[1] == "creak")
	assert_true(inside.size() >= 600.0 / Ambience.CREAK_MAX - 1 and inside.size() <= 600.0 / Ambience.CREAK_MIN + 1, "about one every 15 to 30 s (%d in 600 s)" % inside.size())
	for i in range(1, inside.size()):
		var gap: float = inside[i][0] - inside[i - 1][0]
		assert_true(gap >= Ambience.CREAK_MIN - 0.5 and gap <= Ambience.CREAK_MAX + 0.5, "creak gap %.1f s within the band" % gap)

func test_the_ambience_is_quiet() -> void:
	assert_true(Ambience.volume_db("drip") <= -12.0, "drips are quiet")
	assert_true(Ambience.volume_db("creak") <= -10.0, "creaks are quiet")

func test_the_ambience_takes_no_numbers_from_the_global_generator() -> void:
	seed(321)
	var expected := randi()
	seed(321)
	var ambience := Ambience.new()
	ambience.schedule()
	_run(ambience, 120.0, true, true)
	assert_eq(randi(), expected, "the global generator is untouched")

func test_the_old_workings_are_the_spines_and_the_connectors() -> void:
	var mine := shared_mine(1001)
	var spine: Drift = mine.drifts.filter(func(d): return d.layer == 4)[0]
	assert_true(Ambience.in_workings(mine, Vector2i(spine.x0 + spine.side * 3, spine.row)), "on a spine")
	var c: Connector = mine.connectors[0]
	assert_true(Ambience.in_workings(mine, c.cells[c.cells.size() / 2]), "in a connector")
	assert_true(not Ambience.in_workings(mine, Vector2i(5, 60)), "not in plain rock")

func test_a_run_has_the_ambience() -> void:
	Progress.path_override = TEST_SAVE_PATH
	var fresh := Progress.new()
	fresh.save_path = TEST_SAVE_PATH
	fresh.save()
	var main: Main = add(load("res://scenes/Main.tscn").instantiate())
	await physics_frames(3)
	assert_true(main.ambience is Ambience, "Main has an ambience")
	assert_eq(main.ambience.mine, main.mine, "it knows the mine")
	assert_eq(main.ambience.player, main.player, "and the player")
	Progress.path_override = ""

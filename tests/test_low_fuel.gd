extends TestCase

## A light that is running out of fuel warms toward orange and gutters (M91). Cosmetic: its reach is
## the same radius the mine's "is this lit" test has always used.

const LampScene := preload("res://scenes/Lamp.tscn")
const BASE := Color(1.0, 0.92, 0.7, 1.0)

func test_a_light_above_the_low_fuel_mark_is_unchanged() -> void:
	for frac in [1.0, 0.6, MineLight.LOW_FUEL]:
		assert_eq(MineLight.low_fuel_color(BASE, frac), BASE, "the colour at %.2f fuel" % frac)
		for t in [0.0, 1.3, 7.7]:
			assert_eq(MineLight.gutter(t, frac, 0.4), 1.0, "no wobble at %.2f fuel" % frac)

func test_the_light_warms_as_fuel_falls() -> void:
	var previous := BASE.g
	for frac in [0.25, 0.2, 0.1, 0.0]:
		var colour := MineLight.low_fuel_color(BASE, frac)
		assert_true(colour.g < previous, "greener light gives way to orange at %.2f fuel (g %.3f)" % [frac, colour.g])
		assert_eq(colour.a, BASE.a, "alpha is kept")
		previous = colour.g
	var out := MineLight.low_fuel_color(BASE, 0.0)
	assert_true(absf(out.r - MineLight.WARM_COLOR.r) < 0.001 and absf(out.g - MineLight.WARM_COLOR.g) < 0.001 and absf(out.b - MineLight.WARM_COLOR.b) < 0.001, "fully warm when the fuel is gone (%s)" % str(out))

func test_the_wobble_grows_as_fuel_falls_and_stays_in_its_band() -> void:
	var spread := {}
	for frac in [0.25, 0.1, 0.0]:
		var lowest := 10.0
		var highest := -10.0
		for i in range(1500):
			var f := MineLight.gutter(i * 0.04, frac, 1.1)
			lowest = minf(lowest, f)
			highest = maxf(highest, f)
		var band := MineLight.GUTTER * MineLight.low_fuel_t(frac)
		assert_true(lowest >= 1.0 - band - 0.0001 and highest <= 1.0 + band + 0.0001, "within 1 +/- %.3f at %.2f fuel (%.3f to %.3f)" % [band, frac, lowest, highest])
		spread[frac] = highest - lowest
	assert_true(spread[0.1] > spread[0.25] and spread[0.0] > spread[0.1], "wavers more as the fuel runs out (%s)" % str(spread))
	assert_true(spread[0.0] > MineLight.GUTTER, "a real flicker when empty (%.3f)" % spread[0.0])

func test_a_low_light_is_redder_and_flickers_but_keeps_its_reach() -> void:
	var lamp: Node2D = add(LampScene.instantiate())
	await tree.process_frame
	var light: MineLight = lamp.get_node("MineLight")
	light.burn_rate = 0.0
	light.fuel = light.max_fuel
	await tree.process_frame
	var full_colour := light.point_light.color
	light.fuel = light.max_fuel * 0.08
	var energies := {}
	for i in range(60):
		await tree.process_frame
		energies[snappedf(light.point_light.energy, 0.001)] = true
		assert_eq(light.current_radius(), lerpf(light.radius_min, light.radius_max, 0.08), "the reach is only the fuel's, never the flicker's")
	assert_true(light.point_light.color.g < full_colour.g - 0.05, "redder than at full fuel (%s vs %s)" % [str(light.point_light.color), str(full_colour)])
	assert_true(energies.size() > 8, "the brightness wavers (%d values)" % energies.size())
	assert_true(MineLight.is_lit(tree, light.global_position + Vector2(light.current_radius() - 2.0, 0)), "lit just inside its reach")
	assert_true(not MineLight.is_lit(tree, light.global_position + Vector2(light.current_radius() + 2.0, 0)), "dark just outside it")

func test_a_light_that_never_burns_down_is_left_alone() -> void:
	var torch: Torch = add(load("res://scenes/Torch.tscn").instantiate())
	var light: MineLight = torch.get_node("MineLight")
	var colour := light.point_light.color
	for i in range(30):
		await tree.process_frame
	assert_eq(light.point_light.color, colour, "a torch keeps its colour")

func test_a_light_with_its_own_colour_keeps_it_until_low_then_gets_it_back() -> void:
	var lamp: Node2D = add(LampScene.instantiate())
	await tree.process_frame
	var light: MineLight = lamp.get_node("MineLight")
	light.burn_rate = 0.0
	var own := Color(0.3, 0.8, 0.4, 1.0) # set after the light started, as a lost miner sets its shirt colour
	light.point_light.color = own
	light.fuel = light.max_fuel
	for i in range(5):
		await tree.process_frame
	assert_eq(light.point_light.color, own, "a healthy light keeps the colour it was given")
	light.fuel = light.max_fuel * 0.05
	await tree.process_frame
	assert_true(light.point_light.color.r > own.r + 0.2, "a low light warms from its own colour (%s)" % str(light.point_light.color))
	light.fuel = light.max_fuel
	await tree.process_frame
	assert_eq(light.point_light.color, own, "refuelled, it gets its own colour back")

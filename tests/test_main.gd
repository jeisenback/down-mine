extends TestCase

## Smoke test for the whole game scene. The other tests build only the
## nodes they need, so a script error in Main (or anything only Main
## loads) would slip past them; this loads Main, runs it briefly, and
## checks it came up. Points Progress at the test save so it never reads
## the player's real save.

func test_main_scene_loads_and_runs() -> void:
	Progress.path_override = TEST_SAVE_PATH
	var main_script: GDScript = load("res://scripts/main.gd")
	assert_true(main_script != null and main_script.can_instantiate(), "main.gd compiles")
	var packed: PackedScene = load("res://scenes/Main.tscn")
	var main: Node = packed.instantiate()
	add(main)
	await physics_frames(30)
	assert_true(main.progress != null, "Main finished _ready")
	assert_true(main.player != null and main.player.health > 0, "player alive after a moment")
	assert_true(main.hud.layer_label.text != "", "HUD updating")
	Progress.path_override = ""

func test_buildings_cost_ore_and_bell_warns() -> void:
	Progress.path_override = TEST_SAVE_PATH
	var main: Node = add(load("res://scenes/Main.tscn").instantiate())
	await physics_frames(10)
	main.stalker.process_mode = Node.PROCESS_MODE_DISABLED
	main.player.global_position = main.run_base.global_position + Vector2(0, 15)
	await physics_frames(10)
	main.player.currency = 100
	assert_true(not main.build_support(), "no supports at the surface")
	assert_true(main.build_beacon(), "beacon built at the base")
	assert_true(not main.build_beacon(), "one beacon per run")
	assert_true(main.build_bell(), "bell built")
	assert_eq(main.player.currency, 100 - RunBase.BEACON_ORE_COST - RunBase.BELL_ORE_COST, "paid from run ore")
	main.noise_meter.decay_rate = 0.0
	main.noise_meter.noise = main.noise_meter.threshold * 0.8
	await physics_frames(2)
	assert_true(main.hud.noise_label.text.contains("LOUD"), "bell warns near the threshold")
	main.noise_meter.noise = 0.0
	main.noise_meter.add_noise(0.0)
	await physics_frames(2)
	assert_true(not main.hud.noise_label.text.contains("LOUD"), "warning clears when quiet")
	Progress.path_override = ""

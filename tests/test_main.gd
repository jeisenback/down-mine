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

func test_camp_search_and_lift_ride() -> void:
	Progress.path_override = TEST_SAVE_PATH
	var main: Node = add(load("res://scenes/Main.tscn").instantiate())
	await physics_frames(5)
	main.stalker.process_mode = Node.PROCESS_MODE_DISABLED
	var events := main.get_tree().get_nodes_in_group("mine_events")
	var camp: Camp = events.filter(func(e): return e is Camp)[0]
	var lift: Lift = events.filter(func(e): return e is Lift)[0]

	main.player.light.fuel = 10.0
	var pages: int = main.progress.journal_read
	camp.use(main)
	assert_eq(main.player.currency, Camp.ORE_BY_LAYER[camp.layer], "camp gives ore")
	assert_true(main.player.light.fuel > 10.0, "camp gives light")
	assert_eq(main.progress.journal_read, min(pages + 1, Progress.JOURNAL.size()), "a journal page read")
	assert_eq(camp.prompt(main), "", "lantern lit, nothing to do")
	camp.use(main)
	assert_eq(main.player.currency, Camp.ORE_BY_LAYER[camp.layer], "searched only once")

	main.player.currency = Lift.REPAIR_ORE
	lift.use(main)
	assert_eq(main.player.currency, 0, "repair paid")
	assert_true(main.noise_meter.noise > 0.0, "repair is loud")
	main.player.global_position = lift.global_position
	lift.use(main)
	assert_true(main._at_surface(), "ride ends at the surface")
	lift.use(main)
	assert_eq(lift.state, Lift.State.USED, "one ride only")
	Progress.path_override = ""

func test_outpost_trades_recruits_and_is_noisy() -> void:
	Progress.path_override = TEST_SAVE_PATH
	var main: Node = add(load("res://scenes/Main.tscn").instantiate())
	await physics_frames(5)
	main.stalker.process_mode = Node.PROCESS_MODE_DISABLED
	var events := main.get_tree().get_nodes_in_group("mine_events")
	var outpost: Outpost = events.filter(func(e): return e is Outpost)[0]
	var survivor: LostMiner = events.filter(func(e): return e is LostMiner)[0]

	main.player.currency = Outpost.PACK_ORE * 3 + Outpost.RECRUIT_ORE
	var ladders: int = main.player.ladders_left
	for i in range(3):
		outpost.use(main)
	assert_eq(outpost.stock, 0, "stock runs out")
	assert_eq(main.player.ladders_left, ladders + Outpost.STOCK * Outpost.PACK.ladders, "packs add ladders")
	assert_eq(main.player.currency, Outpost.PACK_ORE + Outpost.RECRUIT_ORE, "paid per pack, not past stock")

	main.player.currency = Outpost.RECRUIT_ORE
	survivor.use(main)
	assert_eq(main.player.currency, 0, "recruit paid")
	assert_true(survivor.following and survivor in main._escorts(), "survivor joins as an escort")
	assert_true(not survivor.is_in_group("mine_events"), "no longer an event")

	main.noise_meter.decay_rate = 0.0
	main.noise_meter.noise = 0.0
	main.player.global_position = outpost.global_position
	await physics_frames(30)
	assert_true(main.noise_meter.noise > 0.0, "staying at the outpost is noisy")
	Progress.path_override = ""

func test_vault_door_is_loud_and_relic_pays() -> void:
	Progress.path_override = TEST_SAVE_PATH
	var main: Node = add(load("res://scenes/Main.tscn").instantiate())
	await physics_frames(5)
	main.stalker.process_mode = Node.PROCESS_MODE_DISABLED
	var events := main.get_tree().get_nodes_in_group("mine_events")
	var door: VaultDoor = events.filter(func(e): return e is VaultDoor)[0]
	var relic: Relic = events.filter(func(e): return e is Relic)[0]
	main.noise_meter.decay_rate = 0.0
	main.noise_meter.noise = 0.0
	door.use(main)
	assert_eq(main.noise_meter.noise, VaultDoor.BREAK_NOISE, "breaking in is loud")
	await physics_frames(1)
	assert_true(not is_instance_valid(door), "door gone")
	main.player.currency = 0
	relic.use(main)
	assert_eq(main.player.currency, Relic.VALUE, "relic adds run ore")
	Progress.path_override = ""

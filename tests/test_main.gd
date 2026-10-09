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

func test_quiet_layers_hear_nothing_and_wake_no_stalker() -> void:
	Progress.path_override = TEST_SAVE_PATH
	var main: Node = add(load("res://scenes/Main.tscn").instantiate())
	await physics_frames(5)
	main.noise_meter.decay_rate = 0.0
	assert_true(main.mine.is_quiet_at(main.player.global_position), "the surface is in the quiet zone")
	main.noise_meter.add_noise(50.0)
	assert_eq(main.noise_meter.noise, 0.0, "noise in the quiet zone adds nothing")
	assert_true(main.get_tree().get_nodes_in_group("stalkers").is_empty(), "no Stalker above the quiet floor")
	main.player.global_position = main.mine.cell_to_world(Vector2i(40, main.mine.quiet_floor_row() + 10))
	assert_true(not main.mine.is_quiet_at(main.player.global_position), "below the quiet floor")
	main.noise_meter.add_noise(50.0)
	assert_eq(main.noise_meter.noise, 50.0, "noise counts below it")
	await tree.create_timer(0.2).timeout # physics frames alone may not run _process
	var stalkers := main.get_tree().get_nodes_in_group("stalkers")
	assert_eq(stalkers.size(), 1, "the first descent below the quiet zone wakes one Stalker")
	assert_true(stalkers[0].min_y > main.mine.cell_to_world(Vector2i(0, main.mine.quiet_floor_row())).y, "held out of the quiet layers")
	Progress.path_override = ""

func test_buildings_cost_ore_and_bell_warns() -> void:
	Progress.path_override = TEST_SAVE_PATH
	var main: Node = add(load("res://scenes/Main.tscn").instantiate())
	await physics_frames(10)
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
	var events := main.get_tree().get_nodes_in_group("mine_events")
	var camp: Camp = events.filter(func(e): return e is Camp)[0]
	var lift: Lift = events.filter(func(e): return e is Lift)[0]

	main.player.light.fuel = 10.0
	var pages: int = main.progress.journal_read
	camp.use(main)
	assert_eq(main.player.currency, MineGrid.LAYERS[camp.layer].camp_ore, "camp gives ore")
	assert_true(main.player.light.fuel > 10.0, "camp gives light")
	assert_eq(main.progress.journal_read, min(pages + 1, Progress.JOURNAL.size()), "a journal page read")
	assert_eq(camp.prompt(main), "", "lantern lit, nothing to do")
	camp.use(main)
	assert_eq(main.player.currency, MineGrid.LAYERS[camp.layer].camp_ore, "searched only once")

	main.player.currency = Lift.REPAIR_ORE
	main.player.global_position = lift.global_position # below the quiet layers, so noise counts
	lift.use(main)
	assert_eq(main.player.currency, 0, "repair paid")
	assert_true(main.noise_meter.noise > 0.0, "repair is loud")
	lift.use(main)
	assert_true(main._at_surface(), "ride ends at the surface")
	lift.use(main)
	assert_eq(lift.state, Lift.State.USED, "one ride only")
	Progress.path_override = ""

func test_outpost_trades_recruits_and_is_noisy() -> void:
	Progress.path_override = TEST_SAVE_PATH
	var main: Node = add(load("res://scenes/Main.tscn").instantiate())
	await physics_frames(5)
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
	var events := main.get_tree().get_nodes_in_group("mine_events")
	var door: VaultDoor = events.filter(func(e): return e is VaultDoor)[0]
	var relic: Relic = events.filter(func(e): return e is Relic)[0]
	main.noise_meter.decay_rate = 0.0
	main.noise_meter.noise = 0.0
	main.player.global_position = door.global_position # below the quiet layers, so noise counts
	door.use(main)
	assert_eq(main.noise_meter.noise, VaultDoor.BREAK_NOISE, "breaking in is loud")
	await physics_frames(1)
	assert_true(not is_instance_valid(door), "door gone")
	main.player.currency = 0
	relic.use(main)
	assert_eq(main.player.currency, Relic.VALUE, "relic adds run ore")
	Progress.path_override = ""

func test_gallery_collapses_after_entry_and_buries() -> void:
	Progress.path_override = TEST_SAVE_PATH
	var main: Node = add(load("res://scenes/Main.tscn").instantiate())
	await physics_frames(5)
	var gallery: Gallery = main.mine.get_children().filter(func(n): return n is Gallery)[0]
	var ore: Array = main.mine.get_children().filter(func(n): return n is OrePickup and gallery.rect.has_point(main.mine.world_to_cell(n.global_position)))
	assert_eq(ore.size(), Gallery.ORE_COUNT, "rich ore in the gallery")
	await physics_frames(10)
	assert_true(gallery._time_left < 0.0, "no countdown before entry")

	main.player.set_physics_process(false) # stand still, no pickups
	main.player.health = 5
	main.player.global_position = main.mine.cell_to_world(gallery.rect.position + Vector2i(1, 0))
	await physics_frames(3)
	assert_true(gallery._time_left > 0.0, "countdown starts on entry")
	main.noise_meter.decay_rate = 0.0
	main.noise_meter.noise = 0.0
	gallery.collapse()
	assert_true(main.mine.is_solid(Vector2i(gallery.rect.end.x - 1, gallery.rect.position.y)), "room filled")
	assert_true(not main.mine.is_solid(main.mine.world_to_cell(main.player.global_position)), "player's cell left open")
	assert_eq(main.player.health, 5 - Gallery.BURY_DAMAGE, "buried player hurt")
	assert_eq(main.noise_meter.noise, Gallery.COLLAPSE_NOISE, "collapse is loud")
	await physics_frames(1)
	assert_true(ore.all(func(p): return not is_instance_valid(p)), "buried ore lost")
	Progress.path_override = ""

func test_flaring_burns_the_nest_and_calms_the_deep() -> void:
	Progress.path_override = TEST_SAVE_PATH
	var main: Node = add(load("res://scenes/Main.tscn").instantiate())
	await physics_frames(5)
	var nest: Nest = main.get_tree().get_nodes_in_group("mine_events").filter(func(e): return e is Nest)[0]
	main.player.set_physics_process(false) # no input: flaring set by hand
	main.player.global_position = nest.global_position
	await tree.create_timer(0.2).timeout # physics frames alone may not run _process
	assert_true(is_instance_valid(main.deep_stalker), "deep Stalker woke on arrival")
	assert_eq(nest.burn, 0.0, "no burn without a flare")
	main.noise_meter.decay_rate = 0.0
	main.noise_meter.noise = 0.0
	main.player.light.is_flaring = true
	main.player.light.fuel = main.player.light.max_fuel
	await tree.create_timer(Nest.BURN_SECONDS + 0.3).timeout
	assert_true(nest.destroyed and main.nest_destroyed, "flaring burned the nest")
	assert_true(main.noise_meter.noise >= Nest.BURN_NOISE, "burning is loud") # decay may add a little
	await tree.create_timer(0.1).timeout
	assert_true(not is_instance_valid(main.deep_stalker), "deep Stalker gone")
	assert_eq(main.hud.layer_label.text, "Deep rock: gas pockets, unstable", "hazard line drops the Stalker")
	Progress.path_override = ""

func test_heart_wakes_the_mine_and_wins_the_run() -> void:
	Progress.path_override = TEST_SAVE_PATH
	var main: Node = add(load("res://scenes/Main.tscn").instantiate())
	await physics_frames(5)
	var heart: Heart = main.get_tree().get_nodes_in_group("mine_events").filter(func(e): return e is Heart)[0]
	var claimed: int = main.progress.hearts_claimed
	var decay: float = main.mine.decay_multiplier
	assert_eq(decay, pow(main.CLAIMED_DECAY_STEP, claimed), "claimed Hearts speed up decay")
	main.noise_meter.decay_rate = 0.0
	main.noise_meter.noise = 0.0
	main.player.global_position = heart.global_position # below the quiet layers, so noise counts
	heart.use(main)
	assert_true(main.carrying_heart, "carrying")
	assert_eq(main.noise_meter.noise, main.HEART_NOISE, "taking it is loud")
	assert_eq(main.mine.decay_multiplier, decay * main.HEART_CARRY_DECAY, "mine decays faster")
	main.player.currency = 10
	var banked: int = main.progress.banked_ore
	main._extract()
	tree.paused = false
	assert_eq(main.progress.hearts_claimed, claimed + 1, "Heart claimed")
	assert_eq(main.progress.banked_ore, banked + 10 + main.HEART_ORE, "Heart banks its ore")
	assert_true(main.hud.run_summary_label.text.contains("The Heart is yours!"), "win title")
	Progress.path_override = ""

func test_title_then_controls_overlay() -> void:
	HUD.title_seen = false
	var hud: HUD = add(load("res://scenes/HUD.tscn").instantiate())
	assert_true(hud.overlay.visible and tree.paused, "title shows, paused")
	hud._overlay_key(KEY_ENTER)
	assert_true(not hud.overlay.visible and not tree.paused, "Enter starts")
	assert_true(HUD.title_seen, "title only once")
	hud._overlay_key(KEY_ESCAPE)
	assert_true(hud.overlay.visible and tree.paused, "Esc shows controls, paused")
	assert_true(hud._overlay_label.text.begins_with("CONTROLS"), "controls text")
	assert_true(hud._overlay_key(KEY_D), "other keys swallowed while open")
	hud._overlay_key(KEY_ESCAPE)
	assert_true(not hud.overlay.visible and not tree.paused, "Esc closes")
	hud.run_summary.visible = true
	hud._overlay_key(KEY_ESCAPE)
	hud._overlay_key(KEY_ESCAPE)
	assert_true(tree.paused, "stays paused behind the run summary")
	tree.paused = false
	HUD.title_seen = true

func test_debug_actions_and_seed_display() -> void:
	Progress.path_override = TEST_SAVE_PATH
	var main: Node = add(load("res://scenes/Main.tscn").instantiate())
	await physics_frames(5)
	assert_true(main.hud.seed_label.text.begins_with("Seed %d" % main.mine.mine_seed), "seed shown")
	assert_true(not main.debug_enabled, "debug off without the launch option")
	main.debug_toggle_god()
	var health: int = main.player.health
	main.player.take_hit(2)
	assert_eq(main.player.health, health, "god mode takes no damage")
	main.debug_toggle_god()
	main.debug_next_event()
	var room: Dictionary = main.mine.event_rooms[0]
	assert_true(main.player.global_position.distance_to(main.mine.cell_to_world(room.cell)) < 40.0, "teleported to the first event")
	main.player.global_position = main.run_base.global_position + Vector2(0, 40)
	main.debug_next_layer()
	assert_eq(main.mine.layer_index_at_world(main.player.global_position), 1, "dropped into the next layer")
	var dark: CanvasModulate = main.get_node("CanvasModulate")
	main.debug_toggle_reveal()
	assert_true(not dark.visible, "map revealed")
	Progress.path_override = ""

func test_run_log_records_runs_and_causes() -> void:
	Progress.path_override = TEST_SAVE_PATH
	var main: Node = add(load("res://scenes/Main.tscn").instantiate())
	await physics_frames(5)
	main.progress.run_log = []
	main.player.health = 3
	main.player.take_hit(1, "fall")
	main.player.take_hit(1, "Stalker")
	main.player.take_hit(1, "Stalker")
	await physics_frames(2)
	tree.paused = false
	var entry: Dictionary = main.progress.run_log[0]
	assert_eq(entry.result, "Died (Stalker)", "cause of death is the last hit")
	assert_eq(entry.hits, {"fall": 1, "Stalker": 2}, "hits by source")
	assert_eq(entry.seed, main.mine.mine_seed, "seed logged")
	var line := Progress.run_log_line(entry)
	assert_true(line.begins_with("Died (Stalker) ") and line.contains("hits: fall 1, Stalker 2"), "log line: " + line)
	var hud: HUD = main.hud
	assert_true(hud.run_summary_label.text.contains("L: recent runs"), "hub offers the run log")
	var press_l := InputEventKey.new()
	press_l.physical_keycode = KEY_L
	press_l.pressed = true
	hud._unhandled_input(press_l)
	assert_true(hud.run_summary_label.text.begins_with("RECENT RUNS") and hud.run_summary_label.text.contains("Died (Stalker)"), "L shows the run log")
	hud._unhandled_input(press_l)
	assert_true(hud.run_summary_label.text.contains("Banked ore"), "L again: back to the hub")
	var saved := Progress.load_saved()
	assert_eq(saved.run_log.size(), 1, "run log saved")
	for i in range(12):
		saved.record_run({"result": "Extracted"})
	assert_eq(saved.run_log.size(), Progress.RUN_LOG_SIZE, "keeps the last 10")
	Progress.path_override = ""

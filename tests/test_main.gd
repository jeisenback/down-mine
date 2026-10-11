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
	main.noise_meter.add_noise(50.0, main.player.global_position)
	assert_eq(main.noise_meter.noise, 0.0, "noise in the quiet zone adds nothing")
	assert_true(main.get_tree().get_nodes_in_group("stalkers").is_empty(), "no Stalker above the quiet floor")
	main.player.global_position = main.mine.cell_to_world(Vector2i(40, main.mine.quiet_floor_row() + 10))
	# The base hears by distance; put it beside the sound so only the amount is under test.
	main.run_base.global_position = main.player.global_position
	assert_true(not main.mine.is_quiet_at(main.player.global_position), "below the quiet floor")
	main.noise_meter.add_noise(50.0, main.player.global_position)
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
	main.player.currency = 200
	assert_true(main.grow_base(), "the Outpost, with the beacon")
	assert_true(main.grow_base(), "the Fort, with the bell")
	assert_eq(main.player.currency, 200 - RunBase.TIER_COSTS[1] - RunBase.TIER_COSTS[2], "paid from run ore")
	main.noise_meter.decay_rate = 0.0
	main.noise_meter.noise = main.noise_meter.threshold * 0.8
	await physics_frames(2)
	assert_true(main.hud.noise_label.text.contains("LOUD"), "bell warns near the threshold")
	main.noise_meter.noise = 0.0
	main.noise_meter.add_noise(0.0, main.player.global_position)
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
	main.player.global_position = lift.global_position
	main.noise_meter.decay_rate = 0.0
	main.noise_meter.noise = 0.0
	lift.use(main)
	assert_eq(main.player.currency, 0, "repair paid")
	assert_eq(main.noise_meter.noise, 0.0, "Clay is quiet: nothing hears the repair")
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
	# The base hears by distance; put it beside the sound so only the amount is under test.
	main.run_base.global_position = outpost.global_position
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
	# The base hears by distance; put it beside the sound so only the amount is under test.
	main.run_base.global_position = door.global_position
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
	# The base hears by distance; put it beside the sound so only the amount is under test.
	main.run_base.global_position = gallery.global_position
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
	# The base hears by distance; put it beside the sound so only the amount is under test.
	main.run_base.global_position = nest.global_position
	main.player.light.is_flaring = true
	main.player.light.fuel = main.player.light.max_fuel
	await tree.create_timer(Nest.BURN_SECONDS + 0.3).timeout
	assert_true(nest.destroyed and main.nest_destroyed, "flaring burned the nest")
	assert_true(main.noise_meter.noise >= Nest.BURN_NOISE, "burning is loud") # decay may add a little
	await tree.create_timer(0.1).timeout
	assert_true(not is_instance_valid(main.deep_stalker), "deep Stalker gone")
	assert_true(main.hud.layer_label.text.begins_with("Deep rock: gas pockets, unstable"), "hazard line drops the Stalker")
	assert_true(not main.hud.layer_label.text.contains("Stalker"), "and says nothing of one")
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
	# The base hears by distance; put it beside the sound so only the amount is under test.
	main.run_base.global_position = heart.global_position
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
	assert_true(hud.run_summary_label.text.contains("Depth reached"), "the summary shows the result")
	assert_true(hud.run_summary_label.text.contains("Enter: go to the hub"), "Enter leads to the hub")
	var saved := Progress.load_saved()
	assert_eq(saved.run_log.size(), 1, "run log saved")
	for i in range(12):
		saved.record_run({"result": "Extracted"})
	assert_eq(saved.run_log.size(), Progress.RUN_LOG_SIZE, "keeps the last 10")
	Progress.path_override = ""

func test_hud_says_too_dark_to_dig() -> void:
	Progress.path_override = TEST_SAVE_PATH
	# Seed 48's terrain puts a fuel pickup (25 fuel) where the player lands: on a
	# random seed this test failed about 1 run in 80 (CI, M51c).
	MineGrid.next_seed = 48
	var main: Node = add(load("res://scenes/Main.tscn").instantiate())
	await physics_frames(5)
	for child in main.mine.get_children():
		if child is FuelPickup:
			child.queue_free() # nothing to refill the lantern, wherever the terrain puts one
	await physics_frames(2)
	main.player.global_position = main.mine.cell_to_world(Vector2i(40, main.mine.quiet_floor_row() + 10))
	main.player.light.burn_rate = 0.0
	main.player.light.fuel = 0.0
	await tree.create_timer(0.2).timeout
	assert_true(main.hud.prompt_label.text.contains("Too dark to dig"), "prompt shown in the dark")
	Progress.path_override = ""

func test_the_base_hears_by_distance_below_the_quiet_floor() -> void:
	Progress.path_override = TEST_SAVE_PATH
	var main: Node = add(load("res://scenes/Main.tscn").instantiate())
	await physics_frames(5)
	main.noise_meter.decay_rate = 0.0
	# The quiet layers reach about 150 rows down: plant the base below them so
	# only distance decides what it hears.
	var base_pos: Vector2 = main.mine.cell_to_world(Vector2i(80, main.mine.quiet_floor_row() + 10))
	main.run_base.global_position = base_pos
	main.noise_meter.add_noise(40.0, base_pos + Vector2(0, 20 * MineGrid.TILE_SIZE))
	assert_eq(main.noise_meter.noise, 30.0, "20 tiles from the base: three quarters")
	main.noise_meter.noise = 0.0
	main.noise_meter.add_noise(50.0, base_pos + Vector2(0, 90 * MineGrid.TILE_SIZE))
	assert_eq(main.noise_meter.noise, 0.0, "90 tiles from the base: inaudible")
	Progress.path_override = ""

func test_a_surface_base_hears_nothing_made_in_a_quiet_layer_and_replanting_moves_the_listener() -> void:
	Progress.path_override = TEST_SAVE_PATH
	var main: Node = add(load("res://scenes/Main.tscn").instantiate())
	await physics_frames(5)
	main.noise_meter.decay_rate = 0.0
	var deep: Vector2 = main.mine.cell_to_world(Vector2i(80, main.mine.quiet_floor_row() + 40))
	main.noise_meter.add_noise(50.0, deep)
	assert_eq(main.noise_meter.noise, 0.0, "surface base: the deep is out of earshot")
	main.run_base.global_position = deep
	main.noise_meter.add_noise(50.0, deep)
	assert_eq(main.noise_meter.noise, 50.0, "replanted beside it: heard in full")
	Progress.path_override = ""

func test_digging_reports_where_it_happened() -> void:
	var mine: MineGrid = add(load("res://scenes/Mine.tscn").instantiate())
	var reports: Array = []
	mine.tile_dug.connect(func(amount, pos): reports.append(pos))
	var cell := Vector2i(40, 60)
	mine.fill_cell(cell)
	mine.dig_cells([cell])
	assert_eq(reports.size(), 1, "one dig, one report")
	assert_eq(reports[0], mine.cell_to_world(cell), "reported at the dug cell")

func test_noise_alerts_only_stalkers_within_30_tiles() -> void:
	Progress.path_override = TEST_SAVE_PATH
	var main: Node = add(load("res://scenes/Main.tscn").instantiate())
	await physics_frames(5)
	main.player.global_position = main.mine.cell_to_world(Vector2i(40, main.mine.quiet_floor_row() + 10))
	await tree.create_timer(0.2).timeout # wakes the first Stalker
	var stalker: Stalker = main.get_tree().get_nodes_in_group("stalkers")[0]
	stalker.global_position = main.player.global_position + Vector2(20 * MineGrid.TILE_SIZE, 0)
	main.noise_meter.add_noise(Stalker.LOUD_NOISE, main.player.global_position)
	assert_eq(stalker.alert_timer, Stalker.ALERT_SECONDS, "20 tiles away hears it")
	stalker.alert_timer = 0.0
	stalker.global_position = main.player.global_position + Vector2(40 * MineGrid.TILE_SIZE, 0)
	main.noise_meter.add_noise(Stalker.LOUD_NOISE, main.player.global_position)
	assert_eq(stalker.alert_timer, 0.0, "40 tiles away does not")
	Progress.path_override = ""

func test_a_wave_spawns_below_the_quiet_floor_and_is_counted_apart() -> void:
	Progress.path_override = TEST_SAVE_PATH
	var main: Node = add(load("res://scenes/Main.tscn").instantiate())
	await physics_frames(5)
	var before: int = main.get_tree().get_nodes_in_group("burrowers").size()
	main._spawn_wave()
	var burrowers := main.get_tree().get_nodes_in_group("burrowers")
	assert_eq(burrowers.size(), before + 1, "one Burrower")
	assert_eq(main.waves_spawned, 1, "counted as a wave")
	assert_eq(main.burrowers_spawned, 0, "not as a noise Burrower")
	var floor_y: float = main.mine.cell_to_world(Vector2i(0, main.mine.quiet_floor_row())).y
	assert_true(burrowers[burrowers.size() - 1].global_position.y > floor_y, "never inside the quiet layers, even for a surface base")
	Progress.path_override = ""

func test_no_waves_after_the_run_ends() -> void:
	Progress.path_override = TEST_SAVE_PATH
	var main: Node = add(load("res://scenes/Main.tscn").instantiate())
	await physics_frames(5)
	main.run_seconds = 1000.0
	main.mine_clock._countdown = 0.01 # one frame from a wave
	main.run_ended = true
	var before: int = main.get_tree().get_nodes_in_group("burrowers").size()
	await physics_frames(30)
	assert_eq(main.get_tree().get_nodes_in_group("burrowers").size(), before, "a finished run sends nothing")
	Progress.path_override = ""

func test_quiet_noise_does_not_alert_a_stalker() -> void:
	Progress.path_override = TEST_SAVE_PATH
	var main: Node = add(load("res://scenes/Main.tscn").instantiate())
	await physics_frames(5)
	main.player.global_position = main.mine.cell_to_world(Vector2i(40, main.mine.quiet_floor_row() + 10))
	await tree.create_timer(0.2).timeout # wakes the first Stalker
	var stalker: Stalker = main.get_tree().get_nodes_in_group("stalkers")[0]
	stalker.global_position = main.player.global_position + Vector2(5 * MineGrid.TILE_SIZE, 0)
	stalker.retreat_timer = 2.0
	main.noise_meter.add_noise(MineGrid.DIG_NOISE, main.player.global_position)
	main.noise_meter.add_noise(MineGrid.DECAY_NOISE, main.player.global_position)
	assert_eq(stalker.alert_timer, 0.0, "a dug tile or a crumble is too quiet to alert it")
	assert_eq(stalker.retreat_timer, 2.0, "so a striking Stalker keeps its retreat")
	main.noise_meter.add_noise(Stalker.LOUD_NOISE, main.player.global_position)
	assert_eq(stalker.alert_timer, Stalker.ALERT_SECONDS, "a loud act does")
	Progress.path_override = ""

func test_old_ladders_are_placed_and_never_decay() -> void:
	Progress.path_override = TEST_SAVE_PATH
	var main: Node = add(load("res://scenes/Main.tscn").instantiate())
	await physics_frames(5)
	var ladders: Array = main.mine.get_children().filter(func(n): return n is Rope and n.life_seconds == INF)
	assert_true(ladders.size() >= main.mine.old_ladder_rows.size(), "at least one ladder per surviving piece")
	var col_x: float = main.mine.cell_to_world(Vector2i(main.mine.shaft_column(), 0)).x
	for l in ladders:
		assert_eq(l.global_position.x, col_x, "on the shaft's centre column")
		assert_true(l.global_position.y <= main.mine.cell_to_world(Vector2i(0, main.mine.shaft_open_rows().y)).y + MineGrid.TILE_SIZE, "none hangs below the open shaft")
	await physics_frames(120)
	for l in ladders:
		assert_eq(l.lifetime, 1.0, "old ladders do not rot, in light or dark")
	Progress.path_override = ""

func test_the_old_ladder_stops_short_of_the_collapse() -> void:
	Progress.path_override = TEST_SAVE_PATH
	MineGrid.next_seed = 2002 # a seed whose last 8-row piece survives
	var main: Node = add(load("res://scenes/Main.tscn").instantiate())
	await physics_frames(5)
	var open: Vector2i = main.mine.shaft_open_rows()
	var last_piece: int = open.x + MineGrid.OLD_LADDER_PIECE_ROWS * ((open.y - open.x) / MineGrid.OLD_LADDER_PIECE_ROWS)
	assert_true(main.mine.old_ladder_rows.has(last_piece), "seed 2002 keeps the piece nearest the collapse (row %d)" % last_piece)
	main.player.set_physics_process(false)
	main.player.global_position = main.mine.cell_to_world(Vector2i(main.mine.shaft_column(), open.y))
	await physics_frames(5)
	assert_true(not main.player.is_on_rope(), "standing on the debris you are not on a ladder, so you can dig down")
	for ladder in main.mine.get_children().filter(func(n): return n is Rope):
		var bottom_row: int = main.mine.world_to_cell(ladder.global_position - Vector2(0.0, 1.0)).y
		var covered := false
		for row in main.mine.old_ladder_rows:
			covered = covered or (bottom_row - 3 >= row and bottom_row <= row + MineGrid.OLD_LADDER_PIECE_ROWS - 1)
		assert_true(covered, "every ladder sits inside a surviving piece (bottom row %d)" % bottom_row)
	Progress.path_override = ""

func test_main_places_a_camp_and_the_miner_inside_the_drifts() -> void:
	Progress.path_override = TEST_SAVE_PATH
	var main: Node = add(load("res://scenes/Main.tscn").instantiate())
	await physics_frames(5)
	var stone: Array = main.mine.drifts.filter(func(d): return d.layer == 2)
	assert_true(not stone.is_empty(), "seed 1001 has a Stone drift")
	var miner_cell: Vector2i = main.mine.world_to_cell(main.lost_miners[0].global_position)
	assert_true(absi(miner_cell.x - stone[0].x1) <= 1 and absi(miner_cell.y - stone[0].row) <= 1, "the lost miner is at the Stone drift's far end")
	var camps := main.get_tree().get_nodes_in_group("mine_events").filter(func(e): return e is Camp)
	var topsoil: Array = main.mine.drifts.filter(func(d): return d.layer == 0)
	assert_true(camps.any(func(c): return main.mine.world_to_cell(c.global_position) == Vector2i(topsoil[0].x1, topsoil[0].row)), "the Topsoil camp stands at its drift's end")
	Progress.path_override = ""

func test_the_last_journal_page_marks_the_shafts_end() -> void:
	Progress.path_override = TEST_SAVE_PATH
	var main: Node = add(load("res://scenes/Main.tscn").instantiate())
	await physics_frames(5)
	var depth: int = main.mine.shaft_end_row - MineGrid.SURFACE_ROWS
	main.progress.journal_read = Progress.JOURNAL.size() - 2
	var earlier: String = main.read_journal_page()
	assert_true(not earlier.contains("depth"), "an ordinary page carries no pointer")
	var last: String = main.read_journal_page()
	assert_true(last.contains("Last page"), "that read the last page")
	assert_true(last.contains("\nIn the margin"), "the note sits on its own line, so the HUD does not clip it")
	assert_true(last.contains("depth %d" % depth), "and it names the collapse's depth (%d)" % depth)
	var again: String = main.read_journal_page()
	assert_true(again.contains("Last page") and again.contains("depth %d" % depth), "a finished journal keeps its last page, with the depth, readable at every later camp")
	main.progress.journal_read = 0
	assert_true(not main.read_journal_page().contains("depth"), "page one carries no pointer")
	Progress.path_override = ""

func test_the_hud_shows_the_live_depth_the_journal_refers_to() -> void:
	Progress.path_override = TEST_SAVE_PATH
	var main: Node = add(load("res://scenes/Main.tscn").instantiate())
	await physics_frames(5)
	main.player.set_physics_process(false)
	main.player.global_position = main.mine.cell_to_world(Vector2i(40, main.mine.quiet_floor_row() + 10))
	await tree.create_timer(0.2).timeout
	assert_true(main.hud.layer_label.text.contains("depth %d" % main._current_depth()), "the layer line reads the depth (%s)" % main.hud.layer_label.text)
	Progress.path_override = ""

func test_the_lift_prompt_does_not_call_a_quiet_repair_loud() -> void:
	Progress.path_override = TEST_SAVE_PATH
	var main: Node = add(load("res://scenes/Main.tscn").instantiate())
	await physics_frames(5)
	var lift: Lift = main.get_tree().get_nodes_in_group("mine_events").filter(func(e): return e is Lift)[0]
	main.player.currency = Lift.REPAIR_ORE
	assert_true(not lift.prompt(main).contains("loud"), "the prompt (%s) does not say loud" % lift.prompt(main))
	Progress.path_override = ""

func test_debug_event_teleport_lands_on_open_ground() -> void:
	Progress.path_override = TEST_SAVE_PATH
	MineGrid.next_seed = 1001 # its first event is a camp at the far end of a gallery that runs left
	var main: Node = add(load("res://scenes/Main.tscn").instantiate())
	await physics_frames(5)
	for i in range(main.mine.event_rooms.size()):
		main.debug_next_event()
		var cell: Vector2i = main.mine.world_to_cell(main.player.global_position)
		assert_true(not main.mine.is_solid(cell), "event %d (%s): teleported into rock at %s" % [i, main.mine.event_rooms[i].kind, cell])
	Progress.path_override = ""

# --- crew jobs (workers and jobs, milestone 54) ---------------------------------------

## A saved roster and crew, then a Main that loads it. Each member is [name, type].
func _main_with_crew(members: Array, levels: Dictionary = {}) -> Node:
	var p := Progress.new()
	p.save_path = TEST_SAVE_PATH
	for m in members:
		p.roster.append({"name": m[0], "type": m[1], "runs": 0})
		p.crew_names.append(m[0])
	p.levels = levels
	p.save()
	Progress.path_override = TEST_SAVE_PATH
	var main: Node = add(load("res://scenes/Main.tscn").instantiate())
	await physics_frames(3)
	return main

func test_crew_jobs_tick_in_the_real_scene() -> void:
	var main: Node = await _main_with_crew([["Ana", "repair"]])
	main.run_base.health = 1
	main.player.currency = 20
	main._process(0.016)
	assert_true(main.crew_jobs.working.get("Ana", false), "the Mender is working through Main._process")
	main.crew_jobs.tick(12.5, main._working_crew())
	assert_eq(main.run_base.health, 2, "the base was mended")
	assert_eq(main.player.currency, 15, "for 5 ore")
	Progress.path_override = ""

func test_stranded_or_escorted_crew_do_no_work() -> void:
	var main: Node = await _main_with_crew([["Ana", "repair"]])
	main.run_base.health = 1
	main.player.currency = 20
	main.crew_at_base.clear() # not at the base: stranded, or walking with the player
	assert_eq(main._working_crew(), [], "nobody to work")
	main.crew_jobs.tick(20.0, main._working_crew())
	assert_eq(main.run_base.health, 1, "no repair")
	assert_eq(main.player.currency, 20, "no ore spent")
	Progress.path_override = ""

func test_lamps_made_by_the_climber_land_in_the_hud_stock() -> void:
	var main: Node = await _main_with_crew([["Cole", "traversal"]], {"lamps": 1, "ladders": 1, "anchors": 1})
	main.player.currency = 100
	var lamps: int = main.lamps_left
	for i in range(3):
		main.crew_jobs.tick(60.1, main._working_crew())
	assert_eq(main.lamps_left, lamps + 1, "one rotation ends in a lamp")
	Progress.path_override = ""

func test_job_work_is_heard_through_the_noise_meter() -> void:
	var main: Node = await _main_with_crew([["Ana", "repair"]])
	main.run_base.global_position = main.mine.cell_to_world(Vector2i(40, MineGrid.GRID_HEIGHT - 2)) # the deep rock: not quiet
	main.run_base.health = 1
	main.player.currency = 50
	main.noise_meter.noise = 0.0
	main.crew_jobs.tick(CrewJobs.JOB_NOISE_INTERVAL, main._working_crew())
	assert_eq(main.noise_meter.noise, CrewJobs.JOB_NOISE, "one noise per interval of work")
	Progress.path_override = ""

func test_job_work_in_the_quiet_layers_is_not_heard() -> void:
	var main: Node = await _main_with_crew([["Ana", "repair"]])
	main.run_base.health = 1 # the base starts at the surface, a quiet layer
	main.player.currency = 50
	main.noise_meter.noise = 0.0
	main.crew_jobs.tick(10.0, main._working_crew())
	assert_eq(main.noise_meter.noise, 0.0, "nothing hears the surface")
	Progress.path_override = ""

func _four_types() -> Array:
	return [["Ana", "repair"], ["Bo", "light"], ["Cy", "noise"], ["Di", "traversal"]]

func _miner_named(main: Node, name: String) -> LostMiner:
	return main.crew_at_base.filter(func(m): return m.miner_name == name)[0]

func test_crew_stand_at_the_station_for_their_type() -> void:
	var main: Node = await _main_with_crew(_four_types(), {"crew_bunk": 3})
	var offsets := {"Ana": -34.0, "Bo": -20.0, "Cy": 20.0, "Di": 34.0}
	for name in offsets:
		var m := _miner_named(main, name)
		assert_eq(m.global_position - main.run_base.global_position, Vector2(offsets[name], Main.BASE_FLAG_HEIGHT_ABOVE_PLAYER), "%s stands at their station" % name)
	var kinds := {"repair": "bench", "light": "lantern_post", "noise": "muffling_post", "traversal": "rope_rack"}
	for type in kinds:
		var station: ArtSprite = main.stations[type]
		assert_eq(station.kind, kinds[type], "%s station is a %s" % [type, kinds[type]])
		assert_eq(station.get_parent(), main.run_base, "stations hang off the base")
	Progress.path_override = ""

func test_a_second_miner_of_a_type_stands_beside_the_first() -> void:
	var main: Node = await _main_with_crew([["Ana", "repair"], ["Ben", "repair"]], {"crew_bunk": 1})
	var first := _miner_named(main, "Ana").global_position.x
	var second := _miner_named(main, "Ben").global_position.x
	assert_eq(absf(second - first), 8.0, "8 px apart")
	assert_true(absf(second - main.run_base.global_position.x) > absf(first - main.run_base.global_position.x), "the second stands further out")
	assert_eq(main.stations.size(), 1, "one station for the type")
	Progress.path_override = ""

func test_replanting_the_base_moves_stations_and_crew() -> void:
	var main: Node = await _main_with_crew(_four_types(), {"crew_bunk": 3})
	main.run_base.global_position += Vector2(300, 120)
	main._place_crew_at_base()
	var ana := _miner_named(main, "Ana")
	assert_eq(ana.global_position - main.run_base.global_position, Vector2(-34.0, Main.BASE_FLAG_HEIGHT_ABOVE_PLAYER), "crew followed")
	var bench: ArtSprite = main.stations["repair"]
	assert_eq(bench.global_position.x - main.run_base.global_position.x, -34.0, "and so did the station")
	Progress.path_override = ""

func test_working_miners_dig_and_idle_ones_stand() -> void:
	var main: Node = await _main_with_crew([["Ana", "repair"]])
	var ana := _miner_named(main, "Ana")
	main.player.currency = 50
	main._process(0.016)
	assert_eq(ana.art.art.state, "idle", "a healthy base gives the Mender nothing to do")
	main.run_base.health = 1
	main._process(0.016)
	assert_eq(ana.art.art.state, "dig", "a damaged base puts them to work")
	main.player.currency = 0
	main._process(0.016)
	assert_eq(ana.art.art.state, "idle", "no ore: they stop")
	Progress.path_override = ""

# --- waves bring groups (rhythm of threat, milestone 55) ---------------------------------

func _new_main() -> Node:
	Progress.path_override = TEST_SAVE_PATH
	var main: Node = add(load("res://scenes/Main.tscn").instantiate())
	await physics_frames(3)
	return main

func _live(main: Node) -> Array:
	return main.get_tree().get_nodes_in_group("burrowers")

func test_a_wave_spawns_its_whole_group_spread_out() -> void:
	var main: Node = await _new_main()
	var before := _live(main).size()
	main.mine_clock.wave_number = 3 # a wave of two
	main._spawn_wave()
	var group := _live(main).slice(before)
	assert_eq(group.size(), 2, "two Burrowers")
	var xs := group.map(func(b): return b.global_position.x)
	assert_eq(xs[0] - xs[1], 3.0 * MineGrid.TILE_SIZE, "one in the base's column, one three tiles left of it")
	assert_eq(main.waves_spawned, 1, "one wave, however many Burrowers")
	Progress.path_override = ""

func test_a_peak_wave_is_four_burrowers_in_the_first_four_spread_columns() -> void:
	var main: Node = await _new_main()
	var before := _live(main).size()
	main.mine_clock.wave_number = 5
	main._spawn_wave()
	var group := _live(main).slice(before)
	assert_eq(group.size(), 4, "the peak")
	var base_x: float = main.mine.cell_to_world(main.mine.world_to_cell(main.run_base.global_position)).x
	var offsets := group.map(func(b): return roundi((b.global_position.x - base_x) / MineGrid.TILE_SIZE))
	assert_eq(offsets, [0, -3, 3, -6], "columns 0, -3, 3, -6")
	Progress.path_override = ""

func test_the_live_cap_clips_a_wave_and_counts_noise_burrowers() -> void:
	var main: Node = await _new_main()
	var start := _live(main).size()
	for i in range(6 - start):
		main._on_noise_threshold() # noise-summoned Burrowers count too
	assert_eq(_live(main).size(), 6, "six alive")
	main.mine_clock.wave_number = 5 # a peak of four
	main._spawn_wave()
	assert_eq(_live(main).size(), Main.MAX_LIVE_BURROWERS, "only two fit")
	main._spawn_wave()
	assert_eq(_live(main).size(), Main.MAX_LIVE_BURROWERS, "none fit")
	assert_eq(main.waves_spawned, 2, "both still count as waves")
	for i in range(3):
		main._on_noise_threshold()
	main._spawn_wave() # over the cap already: no error, nothing added
	assert_eq(_live(main).size(), Main.MAX_LIVE_BURROWERS + 3, "noise can exceed the cap, waves cannot")
	Progress.path_override = ""

func test_wave_positions_are_deterministic() -> void:
	var runs: Array = []
	for i in range(2):
		MineGrid.next_seed = 1001
		var main: Node = await _new_main()
		var before := _live(main).size()
		main.mine_clock.wave_number = 5
		main._spawn_wave()
		runs.append(_live(main).slice(before).map(func(b): return b.global_position))
		main.free()
		await physics_frames(2)
	assert_eq(runs[0], runs[1], "the same seed builds the same group in the same places")
	Progress.path_override = ""

# --- the wave line and the cue (rhythm of threat, milestone 55) --------------------------

func test_wave_line_is_urgent_in_the_last_ten_seconds() -> void:
	var hud: HUD = add(load("res://scenes/HUD.tscn").instantiate())
	await physics_frames(2)
	hud.update_wave("Wave in 9 s", true)
	assert_eq(hud.wave_label.text, "Wave in 9 s", "text")
	assert_eq(hud.wave_label.modulate, Color(1, 0.4, 0.3), "red when urgent")
	hud.update_wave("Wave in 40 s", false)
	assert_eq(hud.wave_label.modulate, Color(1, 1, 1), "white otherwise")

func test_main_shows_the_countdown_always_and_the_size_only_with_the_bell() -> void:
	var main: Node = await _new_main()
	main.run_seconds = 300.0
	main._process(0.016)
	assert_true(main.hud.wave_label.text.begins_with("Wave in"), "the countdown is always there (%s)" % main.hud.wave_label.text)
	assert_true(not main.hud.wave_label.text.contains("Burrower"), "no size without the bell")
	main.run_base.build_bell()
	main._process(0.016)
	assert_true(main.hud.wave_label.text.contains("Burrower"), "the bell adds the size (%s)" % main.hud.wave_label.text)
	Progress.path_override = ""

func test_a_wave_shakes_the_camera_and_the_peak_shakes_harder() -> void:
	var main: Node = await _new_main()
	var camera := main.player.get_node("Camera2D") as Camera2D
	var rest := camera.offset
	main.mine_clock.wave_number = 2
	main._spawn_wave()
	assert_eq(main._shake_pixels, Main.WAVE_SHAKE_PIXELS, "an ordinary wave")
	main._update_shake(0.1)
	assert_true(camera.offset != rest, "the camera is off its rest")
	assert_true(camera.offset.length() <= Main.WAVE_SHAKE_PIXELS * 1.5, "by no more than the amplitude")
	main._update_shake(Main.WAVE_SHAKE_SECONDS)
	assert_eq(camera.offset, rest, "restored exactly")
	main.mine_clock.wave_number = 5
	main._spawn_wave()
	assert_eq(main._shake_pixels, Main.WAVE_SHAKE_PIXELS * 2.0, "a peak shakes twice as hard")
	Progress.path_override = ""

func test_a_second_wave_mid_shake_still_restores_the_true_rest_offset() -> void:
	var main: Node = await _new_main()
	var camera := main.player.get_node("Camera2D") as Camera2D
	var rest := camera.offset
	main._shake_camera(Main.WAVE_SHAKE_SECONDS, 2.0)
	main._update_shake(0.2)
	main._shake_camera(Main.WAVE_SHAKE_SECONDS, 2.0) # a second wave while the camera is off rest
	main._update_shake(Main.WAVE_SHAKE_SECONDS + 0.1)
	assert_eq(camera.offset, rest, "the rest offset was not overwritten by the shaken one")
	Progress.path_override = ""

func test_a_run_ending_mid_shake_restores_the_camera() -> void:
	var main: Node = await _new_main()
	var camera := main.player.get_node("Camera2D") as Camera2D
	var rest := camera.offset
	main._shake_camera(Main.WAVE_SHAKE_SECONDS, 2.0)
	main._update_shake(0.1)
	main.run_ended = true
	main._process(0.1)
	assert_eq(camera.offset, rest, "restored when the run ends")
	Progress.path_override = ""

func test_the_shake_does_not_touch_the_global_random_generator() -> void:
	var main: Node = await _new_main()
	seed(7)
	var expected := randf()
	seed(7)
	main._shake_camera(Main.WAVE_SHAKE_SECONDS, 2.0)
	for i in range(10):
		main._update_shake(0.05)
	assert_eq(randf(), expected, "the shake draws from its own generator")
	Progress.path_override = ""


# --- the base grows with one key (run base as a settlement, milestone 56) --------------------

func _press(code: int) -> void:
	var e := InputEventKey.new()
	e.physical_keycode = code
	e.keycode = code
	e.pressed = true
	Input.parse_input_event(e)
	await physics_frames(3)
	e.pressed = false
	Input.parse_input_event(e)
	await physics_frames(3)

## A Main with its player standing at a base planted deep, where noise is heard.
func _main_at_a_deep_base() -> Node:
	var main: Node = await _new_main()
	main.run_base.global_position = main.mine.cell_to_world(Vector2i(40, MineGrid.GRID_HEIGHT - 2))
	main.player.global_position = main.run_base.global_position
	main.noise_meter.decay_rate = 0.0
	main.noise_meter.noise = 0.0
	return main

func test_u_grows_the_base_and_charges_the_ore() -> void:
	var main: Node = await _main_at_a_deep_base()
	main.player.currency = 200
	assert_true(main.grow_base(), "the Outpost")
	assert_eq(main.run_base.tier, 1, "tier 1")
	assert_eq(main.player.currency, 130, "70 ore")
	assert_eq(main.noise_meter.noise, RunBase.BUILD_NOISE, "a build's noise, heard at a deep base")
	assert_true(main.grow_base(), "the Fort")
	assert_eq(main.player.currency, 10, "120 more")
	assert_true(not main.grow_base(), "nothing above the Fort")
	assert_eq(main.player.currency, 10, "no ore taken")
	Progress.path_override = ""

func test_growing_is_refused_short_of_ore_away_from_the_base_and_when_fallen() -> void:
	var main: Node = await _main_at_a_deep_base()
	main.player.currency = 69
	assert_true(not main.grow_base(), "69 ore is short of 70")
	main.player.currency = 200
	main.player.global_position = main.run_base.global_position + Vector2(200, 0)
	assert_true(not main.grow_base(), "too far from the base")
	main.player.global_position = main.run_base.global_position
	main.run_base.health = 0
	assert_true(not main.grow_base(), "a fallen base cannot grow")
	assert_eq(main.run_base.tier, 0, "still a Camp")
	assert_eq(main.player.currency, 200, "nothing taken")
	assert_eq(main.noise_meter.noise, 0.0, "and no noise")
	Progress.path_override = ""

func test_the_u_key_grows_and_the_old_keys_do_nothing() -> void:
	var main: Node = await _main_at_a_deep_base()
	main.player.currency = 200
	await _press(KEY_2)
	await _press(KEY_3)
	assert_true(not main.run_base.has_beacon and not main.run_base.has_bell, "the 2 and 3 keys build nothing")
	assert_eq(main.player.currency, 200, "and charge nothing")
	assert_true(not main.has_method("build_beacon") and not main.has_method("build_bell"), "the separate builds are gone")
	await _press(KEY_U)
	assert_eq(main.run_base.tier, 1, "U grows the base")
	assert_true(main.run_base.has_beacon, "with the beacon")
	Progress.path_override = ""

func test_replanting_keeps_the_tier() -> void:
	var main: Node = await _main_at_a_deep_base()
	main.player.currency = 300
	main.grow_base()
	main.grow_base()
	main.run_base.global_position += Vector2(160, 0)
	main._place_crew_at_base()
	assert_eq(main.run_base.tier, 2, "still a Fort")
	assert_eq(main.run_base.light.max_fuel, 340.0, "with its light capacity")
	Progress.path_override = ""

func test_the_wave_size_arrives_with_the_fort() -> void:
	var main: Node = await _main_at_a_deep_base()
	main.player.currency = 300
	main.run_seconds = 300.0
	main._process(0.016)
	assert_true(not main.hud.wave_label.text.contains("Burrower"), "no size at the Camp")
	main.grow_base()
	main._process(0.016)
	assert_true(not main.hud.wave_label.text.contains("Burrower"), "nor at the Outpost")
	main.grow_base()
	main._process(0.016)
	assert_true(main.hud.wave_label.text.contains("Burrower"), "the Fort's bell adds the size (%s)" % main.hud.wave_label.text)
	Progress.path_override = ""

func test_base_line_and_prompts() -> void:
	var main: Node = await _main_at_a_deep_base()
	main.player.currency = 200
	main._process(0.016)
	assert_eq(main.hud.base_label.text, "Base: Camp 3/3  walls 0", "the Camp")
	assert_true(main._action_prompts().has("U: grow the base to an Outpost, 70 ore"), "affordable")
	main.player.currency = 10
	assert_true(main._action_prompts().has("Outpost needs 70 ore"), "short of ore")
	main.player.currency = 300
	main.grow_base()
	main._process(0.016)
	assert_eq(main.hud.base_label.text, "Base: Outpost 4/4  walls 0", "the Outpost")
	assert_true(main._action_prompts().has("U: grow the base to a Fort, 120 ore"), "article for the Fort")
	main.grow_base()
	var prompts: Array = main._action_prompts()
	assert_true(not prompts.any(func(p): return p.begins_with("U:") or p.ends_with("ore") and p.contains("needs")), "nothing to buy at the Fort")
	assert_true(not prompts.any(func(p): return p.begins_with("2:") or p.begins_with("3:")), "the old key prompts are gone")
	Progress.path_override = ""

func test_enter_on_the_summary_leaves_for_the_hub() -> void:
	Progress.path_override = TEST_SAVE_PATH
	var main: Node = add(load("res://scenes/Main.tscn").instantiate())
	await physics_frames(5)
	var seen: Array = []
	main.change_scene = func(path: String): seen.append(path)
	main.player.take_hit(Player.MAX_HEALTH, "fall")
	await physics_frames(2)
	assert_true(main.hud.run_summary.visible, "the run ended")
	var enter := InputEventKey.new()
	enter.physical_keycode = KEY_ENTER
	enter.pressed = true
	main.hud._unhandled_input(enter)
	assert_eq(seen, ["res://scenes/Hub.tscn"], "Enter goes to the hub")
	assert_true(not tree.paused, "unpaused for the next scene")
	Progress.path_override = ""

func test_main_has_no_hub_purchase_handlers() -> void:
	var main_script: GDScript = load("res://scripts/main.gd")
	var names := main_script.get_script_method_list().map(func(m): return m.name)
	assert_true(not names.has("_on_upgrade_requested"), "purchases moved to the hub")
	assert_true(not names.has("_on_crew_toggle_requested"), "crew picking moved to the hub")

func test_e_held_from_the_hub_does_not_extract_the_new_run() -> void:
	Progress.path_override = TEST_SAVE_PATH
	var e := InputEventKey.new()
	e.physical_keycode = KEY_E
	e.keycode = KEY_E
	e.pressed = true
	Input.parse_input_event(e) # the press that went down the mine is still held
	await physics_frames(3) # it was down for a few frames before the scene changed
	var main: Node = add(load("res://scenes/Main.tscn").instantiate())
	await physics_frames(6)
	assert_true(not main.run_ended, "the held E was not an extraction")
	var release := InputEventKey.new()
	release.physical_keycode = KEY_E
	release.keycode = KEY_E
	release.pressed = false
	Input.parse_input_event(release)
	tree.paused = false
	Progress.path_override = ""

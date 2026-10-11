extends TestCase

## The hub as a settlement (milestone 57): buildings and miners over Progress.

func _progress() -> Progress:
	var p := Progress.new()
	p.save_path = TEST_SAVE_PATH
	return p

func _building(kind: String, p: Progress) -> HubBuilding:
	var b := HubBuilding.new()
	b.kind = kind
	b.progress = p
	return b

func _member(npc_name: String, type: String = "repair") -> Dictionary:
	return {"name": npc_name, "type": type, "runs": 0, "found_in": 0}

func _miner(member: Dictionary, p: Progress) -> HubMiner:
	var m := HubMiner.new()
	m.member = member
	m.progress = p
	return m

func test_each_building_offers_its_upgrades() -> void:
	var p := _progress()
	assert_eq(_building("lamp_shop", p).offers(), ["lantern", "lamps"], "lamp shop")
	assert_eq(_building("smithy", p).offers(), ["hard_hat", "ladders", "anchors"], "smithy")
	assert_eq(_building("bunkhouse", p).offers(), ["crew_bunk"], "bunkhouse")
	assert_eq(_building("notice_board", p).offers(), [], "notice board")

func test_buying_takes_the_exact_ore_and_raises_the_level() -> void:
	var p := _progress()
	p.banked_ore = 100
	var shop := _building("lamp_shop", p)
	assert_true(shop.buy(1), "the lantern is bought")
	assert_eq(p.banked_ore, 100 - Progress.UPGRADES.lantern.cost_per_level, "ore taken")
	assert_eq(p.level("lantern"), 1, "level raised")

func test_a_short_or_bad_buy_changes_nothing() -> void:
	var p := _progress()
	p.banked_ore = 10
	var shop := _building("lamp_shop", p)
	assert_true(not shop.buy(1), "short of ore")
	assert_true(not shop.buy(9), "no such slot")
	assert_true(not shop.buy(0), "slots start at 1")
	assert_eq(p.banked_ore, 10, "nothing taken")
	assert_eq(p.level("lantern"), 0, "nothing bought")

func test_prompt_wording() -> void:
	var p := _progress()
	p.banked_ore = 100
	var shop := _building("lamp_shop", p)
	assert_true(shop.prompt().begins_with("1: Lantern tank Lv 0/3, 30 ore"), "lantern offer: " + shop.prompt())
	assert_true(shop.prompt().contains("2: Lamps Lv 0/1, 40 ore"), "lamps offer")
	p.banked_ore = 10
	assert_true(shop.prompt().contains("30 ore (need 20 more)"), "short of ore says what is needed: " + shop.prompt())
	p.levels["lamps"] = 1
	assert_true(shop.prompt().contains("2: Lamps OWNED"), "an unlock already bought")
	p.levels["hard_hat"] = 2
	assert_true(_building("smithy", p).prompt().contains("1: Hard hat MAX"), "a maxed upgrade")
	assert_eq(_building("notice_board", p).prompt(), "E: notice board", "the board")

func test_the_owned_cue_follows_the_first_offer() -> void:
	var p := _progress()
	var shop := _building("lamp_shop", p)
	assert_eq(shop.owned_cue(), 0.0, "cold at first")
	p.levels["lantern"] = 1
	assert_eq(shop.owned_cue(), 1.0, "lit once something is bought")
	assert_eq(_building("bunkhouse", p).owned_cue(), 0.0, "bunkhouse has no cue")

func test_a_new_save_has_sensible_board_text() -> void:
	var board := _building("notice_board", _progress())
	assert_true(board.board_text().contains("No runs logged yet"), "empty log")
	assert_true(not board.board_text().contains("Journal"), "no journal line yet")
	assert_true(not board.board_text().contains("Stranded"), "no stranded miners")

func test_board_text_shows_log_journal_and_stranded() -> void:
	var p := _progress()
	p.run_log = [{"result": "Extracted", "seconds": 90, "depth": 40, "ore": 12, "seed": 7}]
	p.journal_read = 1
	p.stranded = [{"name": "Dita", "type": "light", "layer": 0, "runs": 0, "found_in": 0}]
	var text := _building("notice_board", p).board_text()
	assert_true(text.contains("RECENT RUNS"), "heading")
	assert_true(text.contains(Progress.run_log_line(p.run_log[0])), "the run")
	assert_true(text.contains(Progress.JOURNAL[0]), "the latest journal page")
	assert_true(text.contains(p.stranded_line(p.stranded[0])), "the stranded miner")
	var board := _building("notice_board", p)
	assert_true(not board.board_open, "closed at first")
	board.toggle()
	assert_true(board.board_open, "opened")
	board.toggle()
	assert_true(not board.board_open, "closed again")

func test_the_range_is_on_x_only() -> void:
	var b := _building("smithy", _progress())
	b.position = Vector2(200, 50)
	assert_true(b.in_range(Vector2(200 + HubBuilding.RANGE - 1.0, 0)), "inside")
	assert_true(not b.in_range(Vector2(200 + HubBuilding.RANGE + 1.0, 50)), "outside")

func test_crew_toggle_respects_the_slots() -> void:
	var p := _progress()
	p.roster = [_member("Ada"), _member("Bram")]
	var ada := _miner(p.roster[0], p)
	var bram := _miner(p.roster[1], p)
	assert_true(ada.toggle_crew(), "Ada joins the one slot")
	assert_true(ada.on_crew(), "on crew")
	assert_true(not bram.toggle_crew(), "crew full")
	assert_true(bram.prompt().ends_with("Crew full"), "the prompt says so: " + bram.prompt())
	assert_true(ada.prompt().ends_with("leave crew"), "Ada can leave: " + ada.prompt())
	assert_true(ada.toggle_crew(), "leaving always works")
	assert_true(bram.toggle_crew(), "now Bram joins")
	assert_true(bram.prompt().ends_with("leave crew"), "Bram is on the crew")
	assert_true(ada.prompt().ends_with("Crew full"), "Ada sees the crew is full again")
	assert_true(bram.toggle_crew(), "Bram leaves")
	assert_true(ada.prompt().ends_with("join crew"), "a free slot reads join crew")

# --- the Hub scene -----------------------------------------------------------

const HubScene := preload("res://scenes/Hub.tscn")

## A hub over a fresh test save with this ore and roster, ready to walk.
func _hub(ore: int = 0, roster: Array = []) -> Hub:
	Progress.path_override = TEST_SAVE_PATH
	var p := _progress()
	p.banked_ore = ore
	p.roster = roster
	p.crew_names = []
	p.save()
	var hub: Hub = add(HubScene.instantiate())
	await physics_frames(3)
	return hub

func _stand(hub: Hub, x: float) -> void:
	hub.player.global_position = Vector2(x, -8.0)
	hub.player.velocity = Vector2.ZERO

func _key(code: int, down: bool) -> void:
	var e := InputEventKey.new()
	e.physical_keycode = code
	e.keycode = code
	e.pressed = down
	Input.parse_input_event(e)

func _press(hub: Hub, code: int) -> void:
	var e := InputEventKey.new()
	e.physical_keycode = code
	e.keycode = code
	e.pressed = true
	hub._unhandled_input(e)

func test_the_hub_loads_with_a_new_save() -> void:
	var hub := await _hub()
	assert_eq(hub.buildings.size(), 4, "four buildings")
	assert_eq(hub.miners.size(), 0, "no one in the bunkhouse yet")
	assert_eq(hub.hud.banked_label.text, "Banked: 0", "banked ore shown")
	assert_true(hub.get_tree().get_nodes_in_group("mine_events").is_empty(), "no mine")
	Progress.path_override = ""

func test_one_figure_per_rostered_miner_up_to_ten() -> void:
	var roster: Array = []
	for n in ["Ada", "Bram", "Cole", "Dita", "Ezra", "Fenn", "Greta", "Hale", "Ines", "Jory"]:
		roster.append(_member(n))
	var hub := await _hub(0, roster)
	assert_eq(hub.miners.size(), 10, "ten figures")
	var xs := hub.miners.map(func(m): return m.global_position.x)
	for i in range(1, xs.size()):
		assert_true(is_equal_approx(xs[i] - xs[i - 1], Hub.MINER_STEP), "figures stand %s apart" % Hub.MINER_STEP)
	assert_true(xs[-1] < Hub.BUILDING_X["notice_board"] - HubBuilding.RANGE, "all ten fit before the board")
	Progress.path_override = ""

func test_pressing_a_number_buys_at_the_nearest_building() -> void:
	var hub := await _hub(100)
	_stand(hub, Hub.BUILDING_X["lamp_shop"])
	assert_true(hub.press_number(1), "the lantern is bought at the lamp shop")
	assert_eq(hub.progress.level("lantern"), 1, "level raised")
	assert_eq(hub.progress.banked_ore, 70, "ore taken")
	_stand(hub, Hub.BUILDING_X["smithy"])
	assert_true(not hub.press_number(3), "anchors cost 100, only 70 left")
	_stand(hub, 420.0)
	assert_true(hub.nearest_building() == null, "between buildings")
	assert_true(not hub.press_number(1), "nothing to buy away from a building")
	Progress.path_override = ""

func test_use_toggles_the_nearest_miner_or_the_board() -> void:
	var hub := await _hub(0, [_member("Ada")])
	_stand(hub, hub.miners[0].global_position.x)
	assert_true(hub.press_use(), "E beside a miner")
	assert_true(hub.progress.crew_names.has("Ada"), "Ada joined the crew")
	_stand(hub, Hub.BUILDING_X["notice_board"])
	assert_true(hub.press_use(), "E beside the board")
	var board: HubBuilding = hub.buildings.filter(func(b): return b.kind == "notice_board")[0]
	assert_true(board.board_open, "the board is open")
	await physics_frames(2)
	assert_true(hub.board_label.visible, "and shown")
	Progress.path_override = ""

func test_the_entrance_changes_scene() -> void:
	var hub := await _hub()
	var seen: Array = []
	hub.change_scene = func(path: String): seen.append(path)
	_stand(hub, 10.0)
	assert_true(not hub.press_use(), "away from the entrance E does nothing")
	assert_eq(seen, [], "no scene change")
	_stand(hub, Hub.ENTRANCE_X)
	assert_true(hub.at_entrance(), "at the entrance")
	assert_true(hub.press_use(), "E at the entrance")
	assert_eq(seen, ["res://scenes/Main.tscn"], "starts a run")
	Progress.path_override = ""

func test_keys_call_the_named_functions() -> void:
	var hub := await _hub(100, [_member("Ada")])
	_stand(hub, Hub.BUILDING_X["lamp_shop"])
	_press(hub, KEY_1)
	assert_eq(hub.progress.level("lantern"), 1, "1 bought the lantern")
	_stand(hub, hub.miners[0].global_position.x)
	_press(hub, KEY_E)
	assert_true(hub.progress.crew_names.has("Ada"), "E toggled the crew")
	Progress.path_override = ""

func test_prompts_follow_the_player() -> void:
	var hub := await _hub(100, [_member("Ada")])
	_stand(hub, Hub.BUILDING_X["lamp_shop"])
	await physics_frames(2)
	assert_true(hub.hud.prompt_label.text.contains("Lantern tank"), "the lamp shop's offers")
	_stand(hub, Hub.ENTRANCE_X)
	await physics_frames(2)
	assert_true(hub.hud.prompt_label.text.contains("mine"), "the entrance's prompt")
	Progress.path_override = ""

func test_the_lantern_does_not_burn_in_the_hub() -> void:
	var hub := await _hub()
	var before: float = hub.player.light.fuel
	await physics_frames(120)
	assert_eq(hub.player.light.fuel, before, "no burn")
	assert_eq(hub.player.health, Player.MAX_HEALTH, "no harm")
	Progress.path_override = ""

func test_dig_rope_and_grapple_keys_do_nothing_in_the_hub() -> void:
	var hub := await _hub()
	for code in [KEY_SPACE, KEY_S, KEY_Q, KEY_R, KEY_T, KEY_G]:
		_key(code, true)
	await physics_frames(30)
	for code in [KEY_SPACE, KEY_S, KEY_Q, KEY_R, KEY_T, KEY_G]:
		_key(code, false)
	assert_true(hub.player.mine == null, "still no mine")
	assert_true(hub.player.global_position.y < 10.0, "still standing on the ground")
	Progress.path_override = ""

func test_the_board_panel_only_dims_the_screen_while_the_board_is_open() -> void:
	var hub := await _hub()
	assert_true(not hub.board_panel.visible, "the screen is not dimmed at load")
	_stand(hub, Hub.BUILDING_X["notice_board"])
	hub.press_use()
	await physics_frames(2)
	assert_true(hub.board_panel.visible, "dimmed behind the open board")
	hub.press_use()
	await physics_frames(2)
	assert_true(not hub.board_panel.visible, "clear again once it is closed")
	Progress.path_override = ""

func test_the_strip_has_walls_at_both_ends() -> void:
	var hub := await _hub()
	_stand(hub, 12.0)
	_key(KEY_A, true)
	await physics_frames(90)
	_key(KEY_A, false)
	assert_true(hub.player.global_position.x >= 0.0 and hub.player.global_position.y < 20.0, "stopped at the left end: %s" % hub.player.global_position)
	_stand(hub, Hub.STRIP_WIDTH - 12.0)
	_key(KEY_D, true)
	await physics_frames(90)
	_key(KEY_D, false)
	assert_true(hub.player.global_position.x <= Hub.STRIP_WIDTH and hub.player.global_position.y < 20.0, "stopped at the right end: %s" % hub.player.global_position)
	Progress.path_override = ""

func test_the_board_counts_hearts_claimed() -> void:
	var p := _progress()
	assert_true(not _building("notice_board", p).board_text().contains("Hearts"), "none claimed, no line")
	p.hearts_claimed = 2
	assert_true(_building("notice_board", p).board_text().contains("Hearts claimed: 2 - the mine decays faster each time"), "the line returns")

func test_a_saved_roster_and_crew_show_in_the_hub() -> void:
	Progress.path_override = TEST_SAVE_PATH
	var p := _progress()
	p.roster = [_member("Ada"), _member("Bram", "light")]
	p.crew_names = ["Bram"]
	p.save()
	var hub: Hub = add(HubScene.instantiate())
	await physics_frames(3)
	assert_eq(hub.miners.size(), 2, "both figures")
	assert_true(not hub.miners[0].get_node("Lantern").visible, "Ada is not on the crew: no lantern")
	assert_true(hub.miners[1].get_node("Lantern").visible, "Bram is on the crew: lantern")
	_stand(hub, hub.miners[1].global_position.x)
	await physics_frames(2)
	assert_true(hub.hud.prompt_label.text.contains("leave crew"), "his prompt offers to take him off")
	Progress.path_override = ""

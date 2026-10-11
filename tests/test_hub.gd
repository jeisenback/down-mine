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

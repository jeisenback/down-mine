extends TestCase

## Golden fingerprints (issue #74): every seed below builds the mine it built
## before generation was moved out of MineGrid. If a change is meant to alter
## layouts, re-record these from the code BEFORE the change (so they still prove
## the old behaviour was understood), paste them in, and say so in the PR: players
## who noted a seed will see a different mine. The random sources are listed in
## MineGenerator's header (issue #76).

const MineScene := preload("res://scenes/Mine.tscn")
const SEEDS := [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20,
		22, 31, 33, 35, 44, 51, 55, 89, 98, 1001, 4242]
const GOLDEN := {
	1: "2f9d9c8c8ed59cd937cf21f0c49bf27a806766a3c112e2d8f898647cf0c0fcc2",
	2: "0596d8f1038d1e538002119edb3491d830410a895cda2063439a9dd0a1bda267",
	3: "000c8a1b893f47112cafe0372c65bfad074d80a1c7974f96238aa2a9bbc5b490",
	4: "ba9b585d28f6b05bf8bad144ccc96962854fe121f6a50058a0b8a74875b8ecbe",
	5: "a33a0b739932abb88e0b0e87752942b600da814d3584dd3d92312ff0606c28d0",
	6: "bed348b724de8564e0dbb7bb9581cef283125d5e0b3f0e6e57921b9af4ee537e",
	7: "90c493fde7086abd4519f7a473e305114f9cba9666aae34fb7e4eae244708d53",
	8: "5f2dd9e51814967fc17e097b45c731e5be50a9addef09cb6d99e197d79187b45",
	9: "e8a3409b81e2a69847c07edac7ddc0fb5b07d124b87f36810996d20bcca36d8b",
	10: "1402f15f4a1458b9341cd826ff5209d017e91d3334869bb9f3c560baf44318f6",
	11: "13ff879b9b520a8e3801c1157554fe4ca7bc0c164200442cd1f82ac1af3b722a",
	12: "5dad032b00b0eff203083507d87149c6c28d4ed8ed1c47ce4362e3e704488c7e",
	13: "544a3ada963e18b947bd32cce5f3e4d1df0afbae319e3e30f17798c2e1759deb",
	14: "428b05e0057b9a90bfcd177802b0aaa2d37ce87bccdef5c9187d87a3dd9f1c06",
	15: "4328be4a6bc9e6f1a06cae70d5372a28fd9d72f2af5c7b367dc237e367c04c9e",
	16: "095ed96cf0a102b84579e70ca9cf34da77d2e0cc67600837b944806a7f88dfd7",
	17: "3f140675d2bc6b37686d86f4061538a2cd0b0e9a35ff3201a5bb2f696f75efb1",
	18: "88ddac8ca22e87c0839c5dab0d990f070a259bcfea61a70fc1c418fee8f75918",
	19: "0fbc8f61e0b508f94427760851df359faf27d0acd25c4ca65c12ab2827909d3e",
	20: "1bd06601b81f0ca65f108886aea775802d14447f89ef5494927ccf2ac71618d9",
	22: "238c3168bd86b3f312c49bcab6e10f91b31df8e30a2246c681ca335c2657f7f9",
	31: "07b53e74db89046812204c04388b3bc1d55b128721e967a83610fc667744f41c",
	33: "edee1b0b53859185aacf59f830c39052f57add599302c43285df96052f7d0398",
	35: "714284410fd28b57036b0cd1440b1f07388eedd57ace995572ac0a95e002c31c",
	44: "0a5aa2f672238285f3f74524723d5517f1c09ae6a2773977ac48389af59c7bea",
	51: "a09a83be8eb8ede4220ff305a73681ddf6e6ca5bd374eb546ba37fec9c364426",
	55: "865bbfa25353bbae079fdf2f7a3c433b94214cce47d80cad18adc59147dc587c",
	89: "ce99e8af8f372fada5d283266136ce5b78e3bdeaf3379b6ed22ae2b0cc0a9c8e",
	98: "713b74d1843594b288eff80eeff08c2ed8de13b5d40d15bba61b8110152fef3c",
	1001: "b0c1676084a850496f1be738e679b51c2f9cdf328dfc3a9c4d25a53c65b798f6",
	4242: "8ab947957c35a1fa01fb8e98795f82bfc25960eeb4a4f821054afc71a9d35669",
}

func test_every_golden_seed_matches() -> void:
	for s in SEEDS:
		assert_true(GOLDEN.has(s), "seed %d has a recorded fingerprint" % s)
		if not GOLDEN.has(s):
			continue
		MineGrid.next_seed = s
		var mine: MineGrid = add(MineScene.instantiate())
		assert_eq(MineFingerprint.of(mine), GOLDEN[s], "seed %d builds the same mine" % s)
		mine.free()

func test_the_fingerprint_covers_every_layout_field() -> void:
	for field in ["mine_seed", "shaft_end_row", "lost_miner_cell", "old_ladder_rows", "drifts", "event_rooms", "torches",
			"_room_cells", "_reserved_floors", "_plank_cells", "_debris_cells", "_vault_cells", "_spare_floor_cells"]:
		assert_true(MineFingerprint.FIELDS.has(field), "%s is fingerprinted" % field)

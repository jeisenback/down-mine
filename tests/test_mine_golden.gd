extends TestCase

## Golden fingerprints (issue #74): every seed below builds the mine it built
## before generation was moved out of MineGrid. If a change is meant to alter
## layouts, re-record these from the code BEFORE the change (so they still prove
## the old behaviour was understood), paste them in, and say so in the PR: players
## who noted a seed will see a different mine. The random sources are listed in
## MineGenerator's header (issue #76).
## Re-recorded on purpose for the old workings (M80, issue #26): long spines in every layer
## and gallery pickups changed every layout. Re-recorded again for the connectors (M81) and the
## spines moving to the upper part of their layer; and for the clues (M82): gallery torches and the posts
## at connector mouths; and for longer connectors (M85): the cap went from 70 to 100 tiles, so deeper rooms get one.

const MineScene := preload("res://scenes/Mine.tscn")
const SEEDS := [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20,
		22, 31, 33, 35, 44, 51, 55, 89, 98, 1001, 4242]
const GOLDEN := {
	1: "d563c3bfa47b3b98a85b422c456d8216b322d3fcbfdfb3bed9f523724273d9e6",
	2: "b919503bbc882fc32a4837f9dcc61fb9bbdb27debd0fbbe8fea218180761e40c",
	3: "79eed06fcfc99beacf76c8b457890a61843732774f93e45895afbe530c06828e",
	4: "2c39e1ca54ac7fe59ce25927ae8817d5f16ed68cf7d106db9a494e4f95861d98",
	5: "25cf4f5f1b64e82fc009f2d329714afce7aa06547b1fe03097a2741205de6a6b",
	6: "cfc353bc8f87ebb599060d11f2ea4d84a041aedd0695409fd104598999995193",
	7: "cb10f867c8ae5ae8c6646039ea14abc180b19ff571d09de464fdceeac2c5d319",
	8: "81b4adbd67f4ab703639f94f69eee90feb0646b0021d020ef04ee3a2a0d05eab",
	9: "46da582a86cb5ec34f29920154393e7df6c72500649a08234abbb9c728a60d0a",
	10: "bb949a5160fc96f9b4dbc46ba2b98c37c52df6bb14aa09f26cc8326abb6e8429",
	11: "6a8ab6b6fb33e99d73757e736021d450d5aec25678b28ba3b674a34ee3880259",
	12: "f36158f531f154e341a7098b915dc5b91178eeeb5db09c361510eb5c03d16e44",
	13: "f34cc2ca0e121a2ac31419a10c659f65149db977858127112463a5cff6e4b9ad",
	14: "ed384b31817da3ab26bd76def289572901eeabbab9b372711e7f82252a287100",
	15: "dfec5f9172052917cb164958c934305d308aa197dccb7c368d6d48a6c0210780",
	16: "315d66924760f607481d4e682743bd0176f617f8bb7bd5e6d2cd871d5730e487",
	17: "21c6a72715380b8a1637cfcdcf2219695133cafc9666bd9291861bd58fc50198",
	18: "9a1180eabae61f3334ffa3ae01e498aefd63f02aebd51aa4b09972e4836a932d",
	19: "f2659b06236fdab8e16e35ad19fb2beb91eb0a7fd6a8d94d29e475b9f7b426d7",
	20: "94c02646e111439ec7349662b656dd433a71fb53ba233452d6075d9d63d3832a",
	22: "524db49ffd78f596848b087ff41563f8a633c2ab70877612dd901e942a49acf2",
	31: "40d7733082e1549985daaadfbed477152a55ee0edad2f05192b5ba0b5a443744",
	33: "693f86b4012205e2e3d4bf29e9134f15b2349e11117397a314999991b7e972ce",
	35: "85c3b9d16572deecbfd1bf836ae70939a558f5472415893be3f658a43ae90d79",
	44: "93998bcfb97319403ad0f43b0049c6849103a7c23b28a478fc317e5bf3131e6e",
	51: "b120fb8b7d6f41f2c1fba66e2e85fa5ac345d9f8db748ef6a90d84f7c6f5b2fd",
	55: "9f9bbb2ec596f685b096321af5cd9f923c2aa8c998808bd33c0eb8f126dcc973",
	89: "4a41f75acb7c889db6fce553e55342fec5488ed3521242bbb4e2394eb4b94835",
	98: "b4cfa39c4da6878c9fb613b029cf7f3a31f4b11aea4b36b77d225c75acb99404",
	1001: "a135785cf9febd99b6d664af27ea214f091c103f7c32811e6d519fb5aa53651c",
	4242: "f8371aeded4a6b6ac1e1f5e617f88a0bb6a1ba33c4d4df7fb7a5fe13da06a195",
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
	for field in ["mine_seed", "shaft_end_row", "lost_miner_cell", "old_ladder_rows", "drifts", "connectors", "event_rooms", "torches",
			"_room_cells", "_reserved_floors", "_plank_cells", "_debris_cells", "_vault_cells", "_spare_floor_cells"]:
		assert_true(MineFingerprint.FIELDS.has(field), "%s is fingerprinted" % field)

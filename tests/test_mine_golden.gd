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
## at connector mouths.

const MineScene := preload("res://scenes/Mine.tscn")
const SEEDS := [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20,
		22, 31, 33, 35, 44, 51, 55, 89, 98, 1001, 4242]
const GOLDEN := {
	1: "4678f09da89199f6aa37efe11b2041bc83e7cd0d7202a844eba863407b5e048f",
	2: "b919503bbc882fc32a4837f9dcc61fb9bbdb27debd0fbbe8fea218180761e40c",
	3: "79eed06fcfc99beacf76c8b457890a61843732774f93e45895afbe530c06828e",
	4: "2c39e1ca54ac7fe59ce25927ae8817d5f16ed68cf7d106db9a494e4f95861d98",
	5: "90da77cb1301148b2790bf7dff7bda8cd1f1bc2db9e971b46a8aeafa711d1901",
	6: "cfc353bc8f87ebb599060d11f2ea4d84a041aedd0695409fd104598999995193",
	7: "cb10f867c8ae5ae8c6646039ea14abc180b19ff571d09de464fdceeac2c5d319",
	8: "a9a1c6ae9d0fed3f88dfa3ad868297de187f8c36e6dbba7caae8225b0896607c",
	9: "86b24599925599b77752ba8b09a2de5e3d4915623dedef33dabad6761e7ac41d",
	10: "a9e98f3094aad4e1715b72b6831dca4a57f7c4149b8cd3e99241dfd7f283cc73",
	11: "e618cbdba720a65bf1a11cbb9e46a2a3ad3188fc7ab8f26025632edfe7ed4617",
	12: "f36158f531f154e341a7098b915dc5b91178eeeb5db09c361510eb5c03d16e44",
	13: "f34cc2ca0e121a2ac31419a10c659f65149db977858127112463a5cff6e4b9ad",
	14: "bec1ddb29c761e078f4d4fac84d7dc67571c045add9439634ec6cf9cdacec142",
	15: "dfec5f9172052917cb164958c934305d308aa197dccb7c368d6d48a6c0210780",
	16: "315d66924760f607481d4e682743bd0176f617f8bb7bd5e6d2cd871d5730e487",
	17: "8f07396e6d10c7d4b016e6ebc7112dd90a4835f0cb31c382c3d2e5ec8ddb0684",
	18: "6d361cdb21927bcf0368943ff1a2dd7d9c7796f1de2b721ff28f08e6af8c9d79",
	19: "f2659b06236fdab8e16e35ad19fb2beb91eb0a7fd6a8d94d29e475b9f7b426d7",
	20: "bdd3caeb2a7ad4406193be22680b8994642198e7f352d1884386f3f3deb9fc6a",
	22: "524db49ffd78f596848b087ff41563f8a633c2ab70877612dd901e942a49acf2",
	31: "40d7733082e1549985daaadfbed477152a55ee0edad2f05192b5ba0b5a443744",
	33: "693f86b4012205e2e3d4bf29e9134f15b2349e11117397a314999991b7e972ce",
	35: "85c3b9d16572deecbfd1bf836ae70939a558f5472415893be3f658a43ae90d79",
	44: "93998bcfb97319403ad0f43b0049c6849103a7c23b28a478fc317e5bf3131e6e",
	51: "b120fb8b7d6f41f2c1fba66e2e85fa5ac345d9f8db748ef6a90d84f7c6f5b2fd",
	55: "4788e01bf6790c91552ce3b210186a7acac4366743b792b36772f75a2e72b279",
	89: "4a41f75acb7c889db6fce553e55342fec5488ed3521242bbb4e2394eb4b94835",
	98: "b4cfa39c4da6878c9fb613b029cf7f3a31f4b11aea4b36b77d225c75acb99404",
	1001: "a135785cf9febd99b6d664af27ea214f091c103f7c32811e6d519fb5aa53651c",
	4242: "1a7639ae8fb3480ab6fd616b86268c7f6b97eaa2785bb5f5372ff645a18a1f0a",
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

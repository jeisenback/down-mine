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
## at connector mouths; and for longer connectors (M85): the cap went from 70 to 100 tiles, so deeper rooms get one; and for the sconce beside each connector's mouth (M86); and for the torches along long passages (M87); and for the steeper connector stair with rock sealed over its roof (M88).

const MineScene := preload("res://scenes/Mine.tscn")
const SEEDS := [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20,
		22, 31, 33, 35, 44, 51, 55, 89, 98, 1001, 4242]
const GOLDEN := {
	1: "f9e1e9bb8bbb04ebf7503372c714e9eb1f67cc29ff464def6abd702fda7566a0",
	2: "6df2ceb6a4b84e96c4e6ed341e89e1ca0b2f2f899c85088d8582aece8b1ef82c",
	3: "94b583affda63d8001e51281176fb90dd3d9ad4c5b78a03b497320c31ed150eb",
	4: "3223b4e494bdeed384e788495f75dfc78b8fa1b29bcde95b4856d59cc2504f9d",
	5: "cd4a6d9cd3d281b7e7ae8f93653759e842bc8ddd51973f77ac31027d5667678d",
	6: "0c6e95c6c315b6112c8e452f96585c1c84072b43b04fa00b042c0e8693d1dd26",
	7: "c22a4e70a6b898ca4c8e09bf47a3bd0b8724a831fe7bd9da982b376c479d7956",
	8: "e767d0122dc5bb1f56552b4aa782abc85c276ad79173ab15a81dde9cf181eb60",
	9: "8ae58205ff49274cf645c5e6f124eed1a2247c79c444e2ccac4381e70da602a2",
	10: "127ec6e3685fbb4a7457eea1a753610575f13d5b155f6434578d4031d3c1eaaf",
	11: "9d0b7f4a4e4e93114f3c8e8766caee9197a0dc54c47b9b7432090c9950071780",
	12: "00417de25b23b2519705639861589c92ef90a0f7eb29ab992eb269c4d1ca411c",
	13: "45fdb1896b0a2cda63de62b79a0c192640b662217020b12fe64a2dfcc3da0bd7",
	14: "51b5349347f625c85271c3ec8bcc95e42955dba44df802de8c7e1388435970af",
	15: "f975b3cf622f91d443740abc4bd56b0c95edbdb313a2641f8069ba411142756a",
	16: "6ec88b6173d8bc8c65a17f898b8bf7b6c27f82195c0c4baa148484246e733c74",
	17: "6d8535541847f922cd0f8528cf892bd37b2fd2131229c3c19b7f1a9c8d0fb4e9",
	18: "687cbd61216e11bc65169d752b9e68fb28fb3da16945ad8514343f1a30e47b78",
	19: "b4548ab766e7efb6bd1eba6496c8b56f13f92cb3dfc279d707626a73d9385bec",
	20: "8b17e46547e1e88943ab095748ffd279d13fa6008cce414f95f0aa8321854cd0",
	22: "d935f8be3f79e19ef998a3e209657243bb3dc5cd2c5b27569fe091a1825bb999",
	31: "839173958cfda32ba8327ed61e0af6cd39c427cb589cb24f842ac44f1df9f930",
	33: "03e549cbf0868cb1ce5e0c3b381f52d4902e5621366fe5e6dd5a6a22d54f1a21",
	35: "a10e6c4cc0e2d6ef938684e4b930927a2d3f9d4d087a44996853b3a796491fc2",
	44: "beee0bd5c1b6bedda1fe5d22a473d0ebfcd764bda48d1ed57a9c07a08dac162c",
	51: "5c87cb5eb6d922177dcfa578c799b39a0a38680ace405755962bb075cfe1f321",
	55: "1a8e7abdb1bf2bd27191919959067dbfe2a3d5d24357761ae011993f3d7d2d52",
	89: "71022fa65c4da5f3b83a98f5e18149dc2d365b61dc29d51011c7541d2a2e5242",
	98: "c71286d804714d0279535fef82c92c7b3898e02012a89db91ffa01409ca56ec5",
	1001: "5f3bb77bdfad691b25b710dc51ac9c1a24e1a13930d74884369a82aa4bcb2545",
	4242: "823eda79a5de105701816044b4b9f36c37015190aab27bca55a6f106509e00f2",
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

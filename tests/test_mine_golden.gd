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
## at connector mouths; and for longer connectors (M85): the cap went from 70 to 100 tiles, so deeper rooms get one; and for the sconce beside each connector's mouth (M86); and for the torches along long passages (M87); and for the steeper connector stair with rock sealed over its roof (M88); and for the old workings' decor (M90): rails, rubble, cobwebs.

const MineScene := preload("res://scenes/Mine.tscn")
const SEEDS := [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20,
		22, 31, 33, 35, 44, 51, 55, 89, 98, 1001, 4242]
const GOLDEN := {
	1: "a2e188074eb9f843e661181ba505e2bd028e191f5a0b307a040971777343b70c",
	2: "94cc2a969cd59f044aafaa243601d2654310ddccf0843747a30baf2a44c993c6",
	3: "3a75455d866d38217bb2fbda6c06a356eb4dfb31130bf59aa48b3ccaeb2a71cc",
	4: "8a0fae313a6b630979a25e838fce17e33439a7dfb72bf86d5a4068dc1d5a5a11",
	5: "6b734b6690dadeb0df6cfc4f2ed18b03305fe6618b50f84f033866d40e1c40b7",
	6: "33fc080e2535e11263b55f793fa94cb00ec28b53aa6dcc3c2f3e651d290096a4",
	7: "403d6908b4ffa34db3f47e7a28430265ebbcacff313e051ae5c477200b1e8a54",
	8: "4261c0639a60ae69aa17b6d55a289aee8f00d90beefd8b5c5d506f2a52734b36",
	9: "f5edc4d95ec9b79608f80ade0b6fddfc2be6bf9fc8f768fd81ee38ae7aa22b1d",
	10: "77359bb7a401f1c2c46aed03c297460523fc6dde0d10604f21ea533449589e8a",
	11: "47603dc583aaf0c2208eae87c892dfcd278cc03d623ab99307cb34a7f34818af",
	12: "d599f97448656b05da538405adab3f5f0faacfe56dc9dced3cf1af531003b5c3",
	13: "0522c443257f4b72dbce2397a9a42bef9d8a06e600c3cda0706b316016c50b65",
	14: "7f75298b713c51c61f0d14b7bb92df9eff21ab6e88e6bc6e24e3c66c5e634ca5",
	15: "89f907fac609f8593090ed6222c29467a0f0c94ca19658ae0b32f554c3d2ce92",
	16: "f2e48892cc38174bc4ea483785c7be77bbd85fd3a4dc9f43b7866a2eafdc96d6",
	17: "5dc32cea2dbbe6af8b4e4ba7abda2ee194b3a6f5ed8240469501410a6b5eb109",
	18: "d44362a460878ee58bdfc78547528e3f32f63e6e1cd1a013c8a54488aa10fdde",
	19: "54367cd90107f888200825593a146a79373653bba1671d9d5d0726e7c78ad6a8",
	20: "a051e953c9875159c43279bf4052178889e4084b259a1b2a34a86fbbd4910335",
	22: "3ff50250e850a6a95a9b49c088c102abe58741e1e1aaba4eaecbf0635960c9c4",
	31: "f628c55c232f2f27f53a5ca16ebc24b6108c79f65b5fcd3ac5d78ceb3659b39f",
	33: "754eb12c2ce53c94503ceb98ce911f64a854a034b47174fb762fc43ffdf7e840",
	35: "a5a68aac779b40e18f62195bd6b67a68b53e3e343806f027ab0b939fa3846269",
	44: "3c5d5dce1ceb592d39f7563c0567390f3a17b8de3309d32851c6475d5cd4483c",
	51: "b34e13d797caff5a5ee052f32c8e62b10e6283f2e9146d10795e435e6c6387fb",
	55: "8a9a09588491e92d1d0e10751ced6ef2321bcb44f809aedba7e8073f5aed8208",
	89: "25ed4985c96db09582d4d190c17c7f1e37af09fde3d5f326999c4b4c0a3920f3",
	98: "f55ad2018786f11c3017d771447c61c519c08e848972eaccca8cfe6ce34e4529",
	1001: "926a4dd45ca50be00190bf170195d2ea203952cb2fb0d4676827cdab6051173e",
	4242: "da9bf2534a377949b7d0c6008b0d324169d0a47c6f8af926a240fed9b42e182a",
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

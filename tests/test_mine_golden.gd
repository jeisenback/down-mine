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
## at connector mouths; and for longer connectors (M85): the cap went from 70 to 100 tiles, so deeper rooms get one; and for the sconce beside each connector's mouth (M86); and for the torches along long passages (M87).

const MineScene := preload("res://scenes/Mine.tscn")
const SEEDS := [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20,
		22, 31, 33, 35, 44, 51, 55, 89, 98, 1001, 4242]
const GOLDEN := {
	1: "2c9be27573c0d771598aae1671c0ef85c764cf378f549d036877aa7acd208741",
	2: "6895229603cb0f7b6fbe91ba288457eb503fe8316bd31637e99e34f2e868a2ea",
	3: "d1b73e42a30442265f92498353cb8732a941b1dd4182a8059a2cf2b8c9dbdb3d",
	4: "41e9991a485cae5b47c36e26c8381fbc645a47bd857c447ad62519ae576e601b",
	5: "555a0699c4ac541db0fdba4c5a3430c8ee78034b9c6075cc8fd54d196070582c",
	6: "63175cb61c082aa9733967f938dcb93c4a30f7aa636f15a126950cb1900aeb7f",
	7: "cb10f867c8ae5ae8c6646039ea14abc180b19ff571d09de464fdceeac2c5d319",
	8: "7bf126910900fd1e73cb4707ce89c8280a6deba170d30c449a290c390b36b7aa",
	9: "7bf8cefda682017decdbced488ad44c7f4715ca03f0a13596b0aeaf31ba8351b",
	10: "19f3d08d8f210b2ee12fc0cb259f7b0a8184948c39c42f94a799ad447f0ab3c1",
	11: "a58237dbf34bbf140bbcd330f1d055df600d4a525a69d2ef61e47b82e8afd370",
	12: "5895dc81e5ba6611632b6dcf1108ee2a67c5eece7c5b3baa8280ced34eeef83e",
	13: "b663d5c4e3674319a7d28c76d3d032a40b7ff75ab25fc5f225ccc1d98cd6d7f6",
	14: "733247ff3759fb2bf87be1d18e1c683a504500c2fa02b0afcb03e9e4431148e3",
	15: "8565247772b94c24171ee806f2d68733a541b04315cd8152a4c459ccd80d833c",
	16: "9d31cd89e6a079cfc6ab0dae7c293ad595c4174f3a4e65aea84d7306b3d874df",
	17: "0dec59741c092e2de3e6a1bb32f160a2818f5999a29383bdc68531929362a1f5",
	18: "2bc482ff3de1a78f728048d77a75c81c71744dbc6c3fe53deb41e082f86ba71a",
	19: "ccabd4ab0c877a0c21dd50f09a0fcc46b390d20adc8fbd288874b8bf7d1c5e17",
	20: "68fe2bc6245004b5438a681356359f3742a7229b89aeff466d1a9c71060df9af",
	22: "cfffeee348a19a5842a1a3c08b68ae2b9c5e7b326593bc0b5dc5371cbbf58751",
	31: "67fce5d87d1efb1a6f4c721961e573a883445aaa3769ffc908611e9e0a244180",
	33: "e99aad4ba48af299ba6cac30e37457ee1dce8fa206a16ffa53f4cf6aa8bb1b37",
	35: "bfbfc87cacc2f82334a3450a6fca63a76f0bffb37f98231fcdabe543372089ae",
	44: "1081b3f777e9258abfb3ef188b050bb4ccfeda4b322523bad3055f7a369295ab",
	51: "6fd10f0ee50668949b6b2831f90a3073422c09da2ec9bddfe2afd170b6bfe517",
	55: "1f54b0fc36b89de74fdf8ac7143459fe85785959b393ba06de750295ee2d4537",
	89: "bfa7665ac61440f32ca1422b7f8a31a631461d6186d281fb531cd69fd6e758a6",
	98: "ae9de134b8816f5b4926f10078226f3ae50d465490a36668b46a94f4d49ca908",
	1001: "2ff05448d6ad683e4137c9ed8a7a399f48d51d0d40dd13d0f1227a62ad087ccc",
	4242: "d71d793bd2c7cfa8b88100c27b8495456d896670f930ec493434bdc4758ffe0f",
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

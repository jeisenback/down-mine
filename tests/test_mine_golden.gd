extends TestCase

## Golden fingerprints (issue #74): every seed below builds the mine it built
## before generation was moved out of MineGrid. If a change is meant to alter
## layouts, re-record these from the code BEFORE the change (so they still prove
## the old behaviour was understood), paste them in, and say so in the PR: players
## who noted a seed will see a different mine. The random sources are listed in
## MineGenerator's header (issue #76).
## Re-recorded on purpose for the old workings (M80, issue #26): long spines in every layer
## and gallery pickups changed every layout. Re-recorded again for the connectors (M81) and the
## spines moving to the upper part of their layer.

const MineScene := preload("res://scenes/Mine.tscn")
const SEEDS := [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20,
		22, 31, 33, 35, 44, 51, 55, 89, 98, 1001, 4242]
const GOLDEN := {
	1: "826758251cd7712c4bb292ca90eae9c16e57ff148f557469ecc2fea21fa605bc",
	2: "b20cbd65a82667209c9428e0bcae4cbcf21a5f477bc04ca3ae8b342666176f61",
	3: "9cb0206f140585338605ec9d93f8e9456f2ec25b852f95f78b71e02bf165761b",
	4: "a2fc8d14adbfe10dac7d5ae8d31b390c430538997a2dbf1d46a54f49444e2230",
	5: "250f47785ca1ff59c1eb84bc4995108426c2f96c88c2074c44f0e4ef1c41eab7",
	6: "00610055d8eed35defb22f836765c7745cf38d82e715090136fbb20280b06b5f",
	7: "4edb31685992814260988e389a4057cebe180d9bd4d83b5a8b9bb3da1808b683",
	8: "ae6a4015c9ea1e416fe687a6d0c98a4a45ba0532264111dba01cdf4502517abb",
	9: "f11c9b9fa754293cf86e3fb740aeda603aae89b574b06ce5cdfbd6d3f818a16c",
	10: "37f6307a182046e57d9c639702cf0fa968edf10fa253d13dfa8e639a2b5ca7da",
	11: "31dfc4f4c216bef58ce0c2da5666532c81daa9923cca73fe1fc17701fd68b9e9",
	12: "dcaa76d15fcdef3560bafa23c6077d851e4b22ac98740f2302bee97e96ac79f3",
	13: "3b0e9d4540837e011d16b30da78d01d98ab8d0e1eafaf8a1174ce3669f919fc9",
	14: "accfebc1d6ec9483278f50b1e406f597b0b9c4e1589b5dc31364731704e5c2ab",
	15: "6fc7c851b1a88f2cbca9571e525654f69e8b9b6426aa520dc70bac2b0ae738a3",
	16: "7367e4c523a93031d487087d07a8fba97d8ef8077622e87ae9d9d92c56cecbc6",
	17: "fcc59d6867b3b9fed350e2dec7f14512fda6ce7933484a07a1732687fb19b793",
	18: "c2f4d94f6b268d16b547a5fddd776ab23eddae7105e96402b7472bd0657bdf06",
	19: "2a424d93c6f1f91fc8eacff74b1e9cd735c57bde86a0c0721e3ee2a6901a04f8",
	20: "aab7071c1d3c6fbcca7227ca2dc8119fa252809d960f8cefcd4ec91b4d128eaa",
	22: "9505e4688b4f5613d1b7de4c950f8b77adac8f861ebe8b345519cf0bbbab548a",
	31: "b52b517ce8394cfc4acf679e5accf979d99f3d3c100352439cbdf72eb0c82602",
	33: "60ef34b6f30fd58150d23ce32788bf5b7757b9b583a09103c6d5acfafc8b8b5e",
	35: "bbecb968a942df160b404c76587155ebe2480587c813c5289196294742b4e922",
	44: "48b6c009003ae3710789eebf7219c9a940bd9b7d246fc4743a7018110b7b39af",
	51: "0a1b9515a55f9ecafbe5564ac34dd6301d99caf5713b1a736e6b11a6416cdb5b",
	55: "92de2f72a3186714d0369de544c6818c4bc1bd7963c4eef1f18c968c8ee62620",
	89: "4c1555ad69f0ff0652c7f0075fc9ec9531dd05c81b68b383d91d0dbb8082bb64",
	98: "1adf8a66aeb8e1cf076d3f92cbbe742f5f8d19710be3775cbbd7a95fca483235",
	1001: "7a91961cab87028e607311bed021974a79fbfdc6cece1b1611641936a36b2a87",
	4242: "32d98a54b3800493569454711acb7f4f6de83a7a740d445006b2e7f8249feb6c",
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

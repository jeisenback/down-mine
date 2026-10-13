extends TestCase

## Golden fingerprints (issue #74): every seed below builds the mine it built
## before generation was moved out of MineGrid. If a change is meant to alter
## layouts, re-record these from the code BEFORE the change (so they still prove
## the old behaviour was understood), paste them in, and say so in the PR: players
## who noted a seed will see a different mine. The random sources are listed in
## MineGenerator's header (issue #76).
## Re-recorded on purpose for the old workings (M80, issue #26): long spines in every layer
## and gallery pickups changed every layout.

const MineScene := preload("res://scenes/Mine.tscn")
const SEEDS := [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20,
		22, 31, 33, 35, 44, 51, 55, 89, 98, 1001, 4242]
const GOLDEN := {
	1: "34cc29bf3474b8ddd1bfe1ea4ac305d0a92dee83b3c712936e2d13491741c4d3",
	2: "645adf6bb5c5f42b18c91cae4d7f2f40efdd2ecdba01970955f12d2cea125d43",
	3: "fd90d2024ced46bf2e4220bf21f2a6049a86de4305e6d7fa13403bc31338a179",
	4: "4f6d0afa76da3343d5a0d390e0a22f2bd87d6e3d68e8a16ae7ffb3cd48bca830",
	5: "5e7f1bab7efe04be6396e660a02811631a808208a1a20ba8f3cc6cfe129bc3a4",
	6: "0e0656dd53bc652d2107dfb6142ff799d6858bdfc9f57b9d17f10ed46d18881f",
	7: "dcbb0a1d853307d61a348042c662a465bb8f80d44c76c0b3f105ba38ef77b00d",
	8: "f018ff942bc627124cea96b17690f707d19524a53c3c0b3ac6fe798d010867c0",
	9: "7a09c30a66d361cef55bab671a40edca47f993fdf99e25ff6e9fe099b49bf577",
	10: "5f575354284a7d81ce9c73da915d92eaf973a2d9ab1f78f567747832c61a1d97",
	11: "c70e8fa6aace0bdc5a812f313d4cca68a48476696c121d3117ffed150123c3e8",
	12: "66579b3036d66e6be68e104ea7196480e8069e22a5763944161516ed425469c0",
	13: "235153f010db73054ba96b934f924924656bb720f9d52244d9c218f63625fd08",
	14: "592726fcc80f9fb32a423a7b09cec938f239123d6ec318ba63dd955b588ebc14",
	15: "220c87a1629550e5a61e6df35054e949e5d32dedd742c1d7580fa78f262de485",
	16: "eed0cd6c97d7fdc94b3ce2e0ad61c39a5ca8f3dc2fb11aeacd69b4e6b69fca2b",
	17: "8b23e784d83a269eadad1c23f389a0f6efc83f3290536058a569e09b42566992",
	18: "c8463616cbdae0f3db367954d5335ebb04f43dd32d5166c6693f5291fcbac912",
	19: "c8614e5f45ca3f5388491b18fd044e62b9db6d6e739c1aa5f7ce46b7d63d0cbb",
	20: "4c760984596805f53d28eea3b66a96e56575b771d72d6ac56ae3a92e71f02190",
	22: "f273111b8dedc6c8799fd0b096bb50118568320d307c8fee6745a3b7d35ee4b0",
	31: "e0d0d9cadd99aff383c265f1c610a32c62ee8ede80c0ae0a4c63609503373367",
	33: "2ba24c2cf11f0e2b64918f3f25c5e4740d1595fac54d229dc6a03e8e2fe93c5d",
	35: "d0b35e491d6513df489a278258be3e40b991ce4c0b9fc86d84ee128038e8a3be",
	44: "c3c5ce3cf1071631e1b8e72c5a07db6f8a0b18b226724eaf0b4f150a66304cc6",
	51: "f61a25f48665ab342cc1ec59d2f096e2cf1773d2a8d78d721d84151e1daa6a0a",
	55: "106103c4b7af9a16ffe6d2bff718e772255cc9f0201f2fe1fc17e7885ac2ef35",
	89: "77ab75553383ca7869d6e1f58d5f87dc4ac8ccafd04b14bc9f7631ca6e2e4e46",
	98: "f3f0c0553a41fee829e59d80de24917114bcc66c7b53223ac449d446f089a067",
	1001: "eeef45d24207b78dda8173c96265a05940cb8c695d4f8c22a6af44a8ec6fb57d",
	4242: "1d81850f32221f8babb8bdea1bf6b7c1d9a193acc8410702b6f09dec540ac6f1",
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

extends TestCase

## Golden fingerprints (issue #74): every seed below builds the mine it built
## before generation was moved out of MineGrid. If a change is meant to alter
## layouts, regenerate these on purpose and say so in the PR.

const MineScene := preload("res://scenes/Mine.tscn")
const SEEDS := [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20,
		22, 31, 33, 35, 44, 51, 55, 89, 98, 1001, 4242]
const GOLDEN := {
	1: "b2ccfa43b19322531099703662530b116b91ed03de62e0aac2b4a0dede492c72",
	2: "01656c7e6ba8ac9d5629b4de0943d15dee002649fb381c243e86c126ef7e20aa",
	3: "306a4740c40a7c7d2fc419f2792de014317aaeae4e14fadf503df0a4e1cf792c",
	4: "0e0d578b901481f9ba9ac9ac4a87cfc18519e9f35c6e60a3e0b0021a78270f0e",
	5: "5493243993fc60354f8e959f005fc4264f1018f81959b9727a5ab9e908f0fdf3",
	6: "3dcf7727a9605b2068b96228bf5a4847a73481bdb3f738cd3675d01c73c6319c",
	7: "fc0ac327b421ea7c07d7bb411d4da06e30e097e017f8de414b1bc3c069c2944f",
	8: "16c0adb415b599e4feceea0beb593239516f6ed85bd324745971843fa8df881c",
	9: "51765446647c891f8b1c35178332beee026552914dec9244bb30f1b893bb3764",
	10: "60ad93ea3d6ab326ea042b516f74cf09780635fb885b0929e579a51f7ddf037d",
	11: "10827a17bbfa960d59e85e681d777cfa3757243ca082410be303cea4922bcd8a",
	12: "13aba18c922c988b818a24b4e5de080acd393fcae5b3f54921c0a40a1d2d4b30",
	13: "20ac80267c114d3fade463450a65f9bd11535c608e85c125388fe6270b7132d0",
	14: "e2426aead2bdb062e9d9b973052e29f0211e1266f12fb4840f59374064f5966a",
	15: "a0788d16c430c8145244b4c31eabac344e46338eaa600412c1eded9c4702af1a",
	16: "f80c84e6db220335e9a26b39b0c9aa6effeb0b974d1d9f54c90bcd883fda6a75",
	17: "49b710c7e05d4ae852df3ea1a51911abfe90fc5d89013a491013b5b283b3322a",
	18: "ffeb0a781edfa9eecfdd5c7b3578c87fd9313856a72be7b68c8fe8d9932ec201",
	19: "459c5fafa239c4acd8ec2c7dc67f3d46677d7d5078e05d6f38f8ba4cb5456828",
	20: "ffbffe2f445930a490402a3c8e1dd8342ca28a34a340c4ce1c998fbdba8fd857",
	22: "ae420be1fbb5d8a6eacf11b2b57304d136fd227becca68027a8e55a6d985e532",
	31: "4cc40c642997cde517cb1dede65e2635b9bc498fc0d7502ee7c7de8794509638",
	33: "33a979734cc3803402f1e941baf23723d401617652fc85854361acc17a133241",
	35: "329584e0e7db5c79af91c5954460b9b5ebf4eb5501d2d3617b67c9531e36a301",
	44: "27e5ce47bd6b8e6bd8bd5d98d26deb48cdd7d8372446a7a40c39a2daba8c068a",
	51: "2ae3eda4a222878dd1e69389ecdd2d64d1af3cfbf1a189a302e438ece78db829",
	55: "4998ec9159fc1ab18c101eade7c650cd4eab4eeb532c37ef4ab4256492423f0d",
	89: "9b88ff53edc6bfdad56075dacb0e590e23e9d272982300ba72713f878f5a2133",
	98: "55de75512ecebbd48df47a070241e01bb0cdd30144551bfd908c420d46734d3a",
	1001: "b53de28bd89293682e42a9d5935ce9ca7592c6cfbe8fee65c2a1ed01ec6b2bfc",
	4242: "8141eba8bcbba63a60a4fc255a6edb02851d75746cff6b11eb7b08029c939b51",
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

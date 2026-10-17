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
## at connector mouths; and for longer connectors (M85): the cap went from 70 to 100 tiles, so deeper rooms get one; and for the sconce beside each connector's mouth (M86).

const MineScene := preload("res://scenes/Mine.tscn")
const SEEDS := [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20,
		22, 31, 33, 35, 44, 51, 55, 89, 98, 1001, 4242]
const GOLDEN := {
	1: "d553d9e72ee7edbf92b6ad77171b4201c29b97f7c416b28573758e9cdab395c0",
	2: "67c3a117a9fe1184221ba7120485bb0bf6a97dac4280f8a0cc833f6a438bfee7",
	3: "43e793fe23ef986a491f8cc45cca5ff9a6f68926f6265b7949a2c6b220ad62e0",
	4: "d4d090ec329c9fd8dd6db9941e8c6ed1139ce408322d57056af82373e0e20f75",
	5: "7b622dafe91d3498f412a92b1d95c40aa84d5c9067f1496e45ce6338008eec1a",
	6: "8b2c3e5eda6cf839825c1342c7a5b02ff0a34b80501b9ff6db1e46b152c290bf",
	7: "cb10f867c8ae5ae8c6646039ea14abc180b19ff571d09de464fdceeac2c5d319",
	8: "cbd2bc40a0915251821a112d4ca84789609b07395f33693cfb123c04464bf935",
	9: "5266be105abbe8dee2ad24ddfa2427984931330ba1dff8e07a75e8e905dbcfc2",
	10: "ee966e27aa156279166bd6d23be2780c6d56bd4ba3008a3a2700c27ae09cb05c",
	11: "893e309086cca3b3aa4da545f5cf56dabc11dc42da6dfb0e66f419e69b387072",
	12: "801a099a32d64fc4b28380be2ae10a11fdbac782969632c4c4448d672883dc16",
	13: "532eed00c973859952249a4d470be5909a77bb49309b1e4b3b94466ca14d5c5f",
	14: "e3390de1e4325d6ab734964f3b536e4859dd0d5ce51bffca4fc8a0635a8e3c46",
	15: "8565247772b94c24171ee806f2d68733a541b04315cd8152a4c459ccd80d833c",
	16: "1cb89eb02ef7b44d199f4cc478ad947b014f84d80dc97e2eba9f3242a9ff30c5",
	17: "859b4e1bbf584c2e35cff9eb6e66bfe4a9e8e9b6046fccd8462c170a3e9931c2",
	18: "a7504a9db4328aec35136c75774a5d8b4a8567be4e351a4d3e2e1f73b40ab30a",
	19: "642a7d32972a9b98b8098dfbe9c2796ca02be346182d877b47366fabbdd129c1",
	20: "dd55851ccb9c6b3063fd5353aa714fb3b33d8613b385adb87f0c2e3e1145fbfc",
	22: "c325122af6d34ddc372f7755fba043b477cfa3d27ea10b2f50a4bd1a2b92dab0",
	31: "c33bbc57ac0ef90c68c68514b370b00757f715fcc606d0610b5f6e00de21a62c",
	33: "5c3064a6e8e6368ee157bd78e407de152001bbb6df1c00082e38e7e5b02cf1ad",
	35: "9753601f0f883ae1edcba78f717db3871ce58ce272bb810c57f16f811464e588",
	44: "1081b3f777e9258abfb3ef188b050bb4ccfeda4b322523bad3055f7a369295ab",
	51: "bb96b50b8ad9c00f8aa66acddb3f4d05896919909fe38676d964c7086d7e4403",
	55: "a6aaca0d3dc09495a4cf11e26fe03ef215cb688a8cba8b8b591c6897812e67f8",
	89: "e3f176324cc78e13e518020943759a1f0fe9edb149d7130c01a903902b7428b6",
	98: "27c3055ea3a6d44f814f1ecabc6c7bd48b9c4c3bdd90146e9bc1ade25a14a954",
	1001: "2d65b6e737e9fe606337723dd9fdcdac03957a1a31c817bc28badbbcf6de1eea",
	4242: "e13ebe5ca5562fa997ce4fe884e1a7a419b61b8cdc4249ae821a6d740147398f",
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

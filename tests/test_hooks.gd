class_name TestHooks

## The static hooks the game exposes to tests and launch options, reset in one place (milestone 67).
## run_tests.gd calls reset() around every test and playtest.gd between scenarios, so no test
## depends on what an earlier one left behind. tests/test_hygiene.gd fails when a new static
## variable is neither reset here nor explained below.

## Reset by reset().
const RESET := [
	"HUD.title_seen", "TouchControls.force", "TouchControls.seen_touch",
	"MineGrid.next_seed", "Progress.path_override", "TouchKeys._down",
]

## Static variables that are deliberately left alone, and why.
const EXPLAINED := {
	"ArtSprite._phase_rng": "art's own generator: drawing must never touch gameplay randomness, and its state is harmless",
	"Sfx._pool": "the audio player pool, created on demand and reused",
	"Sfx._lp_state": "filter state inside one sound's synthesis",
	"MineGrid._launch_seed_read": "the launch option is read once per process; tests launch without a seed",
	"FuelPickup._glint_texture": "one shared radial falloff, built on first use; it holds no per-test state",
	"TouchKeys.sent_count": "a counter; tests compare differences, never absolute values",
}

## `save_path` is where Progress saves while the test runs (never the player's real save).
static func reset(save_path: String = "") -> void:
	HUD.title_seen = true # scene tests must not start paused on the title
	TouchControls.force = false
	TouchControls.seen_touch = false
	MineGrid.next_seed = 0
	Progress.path_override = save_path
	TouchKeys.release_all()

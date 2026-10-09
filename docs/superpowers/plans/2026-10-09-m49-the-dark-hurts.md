# M49 The Dark Hurts Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A lantern at zero fuel is not a state the player can sit in: health drains, digging stops, placed tools rot, and the Stalker comes back sooner.

**Architecture:** One predicate on the player, `in_the_dark()` (lantern out and no other light reaching the player), gates everything. The drain and the dig gate live in `player.gd`; the rot lives in `rope.gd` (ropes and ladders share it); the retreat change in `stalker.gd`; the HUD prompt in `main.gd`. No new scenes or nodes.

**Tech Stack:** Godot 4.5, GDScript. Tests are `tests/test_*.gd` extending `TestCase`, run with `godot --headless --fixed-fps 60 -s tests/run_tests.gd` (the Godot binary for this session is at `/tmp/claude-0/-home-user-down-mine/24af3a60-5fbe-546c-affa-2848f7d0bf52/scratchpad/godot/godot`; run `--headless --import` once after adding scripts).

**Spec:** `docs/superpowers/specs/2026-10-09-run-loop-redesign-design.md`, section "The dark".

## Global Constraints

- The dark applies only at zero fuel: `fuel <= 0.0`. Low light keeps its existing rule (Stalker strikes below 25%).
- Being inside any light other than the player's own lantern (base, lamp, camp lantern, a miner) suspends every dark effect.
- Values from the spec: `DARK_DRAIN_SECONDS = 12.0`, `DARK_ROT_MULTIPLIER = 3.0`, Stalker retreat at zero light `1.5` s (was 3.0).
- Run log source for drain deaths is the string `"dark"`.
- No emojis anywhere. Every commit message ends with the two attribution lines used on this branch (see `git log -1`).
- Fall damage and the mine's own decay are not touched.

## Review Focus

Inputs the spec implies but no test below exercises, most likely to bite first. Each has its test added to the owning task.

1. The player's own dead lantern still has a 30 px minimum radius, so `MineLight.is_lit` with no exclusion would call the player lit by their own dead lamp. Pinned in Task 1.
2. God mode (`invincible`) must stop the drain like any other hit; `take_hit` already does this, pinned in Task 2.
3. Refuelling mid-drain must reset the drain timer, so a top-up never gets you hit a frame later. Pinned in Task 2.
4. The dig gate must not swallow the debug keys or extraction; only the four dig functions are gated. Pinned in Task 3 (extraction test exists in `test_main.gd`; the gate is in the dig functions, not the input layer).
5. A rope placed in light next to a player whose lantern is out must still rot 3x: the rot follows the player's lantern, not the rope's spot. Pinned in Task 4.

---

### Task 1: The dark predicate

**Files:**
- Modify: `scripts/light.gd:35-41` (`is_lit`), add `is_out()`
- Modify: `scripts/player.gd` (add `in_the_dark()`)
- Test: `tests/test_world.gd`

**Interfaces:**
- Produces: `static func MineLight.is_lit(tree: SceneTree, world_pos: Vector2, except: Node = null) -> bool` (a light equal to `except` is skipped); `func MineLight.is_out() -> bool` (`fuel <= 0.0`); `func Player.in_the_dark() -> bool` (`light.is_out() and not MineLight.is_lit(get_tree(), global_position, light)`).
- Later tasks call `player.in_the_dark()` and `player.light.is_out()`.

- [ ] **Step 1: Write the failing test** in `tests/test_world.gd`, after `_base`:

```gdscript
func test_in_the_dark_means_lantern_out_and_no_other_light() -> void:
	var player := _still_player(Vector2(1000, 1000), 1.0)
	assert_true(not player.in_the_dark(), "lit by own lantern")
	player.light.fuel = 0.0
	assert_true(player.in_the_dark(), "lantern out: dark, own dead lantern doesn't count")
	var lamp: Lamp = add(preload("res://scenes/Lamp.tscn").instantiate())
	lamp.global_position = player.global_position + Vector2(20, 0)
	await physics_frames(2)
	assert_true(not player.in_the_dark(), "a lamp beside you suspends the dark")
```

- [ ] **Step 2: Run it to verify it fails**

Run: `godot --headless --fixed-fps 60 -s tests/run_tests.gd 2>&1 | grep -A3 in_the_dark`
Expected: FAIL, "in_the_dark" not found on Player.

- [ ] **Step 3: Implement** `is_out()` and the `except` parameter in `scripts/light.gd` (skip `light == except` in the loop), and `in_the_dark()` in `scripts/player.gd` next to `is_on_rope()`.

- [ ] **Step 4: Run the suite**

Run: `godot --headless --fixed-fps 60 -s tests/run_tests.gd 2>&1 | tail -1`
Expected: `57 passed, 0 failed`

- [ ] **Step 5: Commit**

```bash
git add scripts/light.gd scripts/player.gd tests/test_world.gd
git commit -m "M49: in_the_dark predicate, own dead lantern doesn't count"
```

### Task 2: The drain

**Files:**
- Modify: `scripts/player.gd` (constants, `_dark_timer`, tick in `_physics_process`, reset in `MineLight.add_fuel` path)
- Test: `tests/test_world.gd`

**Interfaces:**
- Consumes: `Player.in_the_dark()` from Task 1.
- Produces: `const Player.DARK_DRAIN_SECONDS := 12.0`; `var Player._dark_timer: float` (seconds spent in the dark since the last hit, 0 when lit).

- [ ] **Step 1: Write the failing tests**

```gdscript
func test_dark_drains_health_until_lit() -> void:
	var mine: MineGrid = add(MineScene.instantiate())
	var player: Player = add(PlayerScene.instantiate())
	player.mine = mine
	player.global_position = mine.cell_to_world(_step_course(mine))
	player.light.burn_rate = 0.0
	player.light.fuel = 0.0
	player.health = 3
	await physics_frames(10)
	assert_eq(player.health, 3, "no hit before DARK_DRAIN_SECONDS")
	player._dark_timer = Player.DARK_DRAIN_SECONDS - 0.05
	await physics_frames(10)
	assert_eq(player.health, 2, "one hit after DARK_DRAIN_SECONDS in the dark")
	assert_eq(player.hits_by.get("dark", 0), 1, "logged as dark")
	player._dark_timer = Player.DARK_DRAIN_SECONDS - 0.05
	player.light.add_fuel(10.0)
	await physics_frames(10)
	assert_eq(player.health, 2, "refuelling resets the drain")
	assert_eq(player._dark_timer, 0.0, "timer cleared while lit")

func test_dark_drain_respects_god_mode() -> void:
	var mine: MineGrid = add(MineScene.instantiate())
	var player: Player = add(PlayerScene.instantiate())
	player.mine = mine
	player.global_position = mine.cell_to_world(_step_course(mine))
	player.light.burn_rate = 0.0
	player.light.fuel = 0.0
	player.invincible = true
	player._dark_timer = Player.DARK_DRAIN_SECONDS - 0.05
	await physics_frames(10)
	assert_eq(player.health, Player.MAX_HEALTH, "god mode ignores the dark")
```

- [ ] **Step 2: Run to verify they fail** (grep `dark_drain`). Expected: FAIL, `DARK_DRAIN_SECONDS` not found.

- [ ] **Step 3: Implement.** In `_physics_process`, before the grapple branches: if `in_the_dark()`, `_dark_timer += delta`; when it reaches `DARK_DRAIN_SECONDS`, subtract it and `take_hit(1, "dark")`; otherwise `_dark_timer = 0.0`. `take_hit` already honours `invincible` and records the source.

- [ ] **Step 4: Run the suite.** Expected: `59 passed, 0 failed`.

- [ ] **Step 5: Commit** `scripts/player.gd tests/test_world.gd`: "M49: the dark drains 1 health every 12 s, any light stops it".

### Task 3: No digging in the dark, and the prompt

**Files:**
- Modify: `scripts/player.gd` (`_dig_straight_down`, `_dig_straight_up`, `_dig_forward`, `_dig_staircase`)
- Modify: `scripts/main.gd:_action_prompts`
- Test: `tests/test_world.gd`, `tests/test_main.gd`

**Interfaces:**
- Consumes: `Player.in_the_dark()`.
- Produces: `func Player.can_dig() -> bool` (`mine != null and not in_the_dark()`); the HUD prompt string `"Too dark to dig"`.

- [ ] **Step 1: Write the failing tests**

In `tests/test_world.gd`:

```gdscript
func test_no_digging_in_the_dark() -> void:
	var mine: MineGrid = add(MineScene.instantiate())
	var start := _step_course(mine)
	var player := _still_player(mine.cell_to_world(start), 0.0)
	player.mine = mine
	var ahead := start + Vector2i(1, 0)
	mine.fill_cell(ahead)
	player._dig_forward()
	assert_true(mine.is_solid(ahead), "dark: forward dig does nothing")
	player._dig_straight_down()
	assert_true(mine.is_solid(start + Vector2i.DOWN), "dark: dig down does nothing")
	player.light.fuel = 10.0
	player._dig_forward()
	assert_true(not mine.is_solid(ahead), "lit: digs again")
```

In `tests/test_main.gd`:

```gdscript
func test_hud_says_too_dark_to_dig() -> void:
	Progress.path_override = TEST_SAVE_PATH
	var main: Node = add(load("res://scenes/Main.tscn").instantiate())
	await physics_frames(5)
	main.player.global_position = main.mine.cell_to_world(Vector2i(40, main.mine.quiet_floor_row() + 10))
	main.player.light.burn_rate = 0.0
	main.player.light.fuel = 0.0
	await tree.create_timer(0.1).timeout
	assert_true(main.hud.prompt_label.text.contains("Too dark to dig"), "prompt shown in the dark")
	Progress.path_override = ""
```

- [ ] **Step 2: Run to verify they fail.** Expected: `no_digging_in_the_dark` FAIL ("dark: forward dig does nothing"); `too_dark` FAIL.

- [ ] **Step 3: Implement.** Add `can_dig()`; each of the four dig functions returns early when `not can_dig()` (replace their existing `mine == null` checks). In `_action_prompts`, `if player.in_the_dark(): prompts.append("Too dark to dig")` before the surface/event prompts.

- [ ] **Step 4: Run the suite.** Expected: `61 passed, 0 failed`.

- [ ] **Step 5: Commit** `scripts/player.gd scripts/main.gd tests/test_world.gd tests/test_main.gd`: "M49: no digging in the dark; HUD says so".

### Task 4: Tools rot while the lantern is out

**Files:**
- Modify: `scripts/rope.gd:33-37`
- Modify: `scripts/player.gd:_ready` (join group `"player"`)
- Test: `tests/test_world.gd`

**Interfaces:**
- Consumes: `MineLight.is_out()`.
- Produces: `const Rope.DARK_ROT_MULTIPLIER := 3.0`; the player node is in group `"player"`.

- [ ] **Step 1: Write the failing test**

```gdscript
func test_tools_rot_three_times_faster_when_the_lantern_is_out() -> void:
	var player := _still_player(Vector2(1000, 1000), 1.0)
	var rope: Rope = add(Player.RopeScene.instantiate())
	rope.global_position = player.global_position # inside the player's light
	rope.life_seconds = 100.0
	await physics_frames(60)
	var lit_loss := 1.0 - rope.lifetime
	rope.lifetime = 1.0
	player.light.fuel = 0.0
	await physics_frames(60)
	var out_loss := 1.0 - rope.lifetime
	assert_true(out_loss > lit_loss * 2.5 and out_loss < lit_loss * 7.0,
		"lantern out: rots about 3x (lit %.4f, out %.4f)" % [lit_loss, out_loss])
```

(`Rope._process` tests its own spot with `MineLight.is_lit` and no exclusion, so the player's dead lantern, 30 px radius, keeps a rope placed on the player "lit" and the existing 2x dark rate does not stack: expect a ratio near 3. The band allows up to 7 in case a future change excludes the dead lantern there too, which would stack to 6.)

- [ ] **Step 2: Run to verify it fails.** Expected: FAIL, ratio near 1.

- [ ] **Step 3: Implement.** `Player._ready`: `add_to_group("player")`. `Rope._process`: after the existing rate, `var player := get_tree().get_first_node_in_group("player")`; if it is a `Player` and `player.light.is_out()`, `rate *= DARK_ROT_MULTIPLIER`.

- [ ] **Step 4: Run the suite.** Expected: `62 passed, 0 failed`.

- [ ] **Step 5: Commit** `scripts/rope.gd scripts/player.gd tests/test_world.gd`: "M49: ropes and ladders rot 3x while the lantern is out".

### Task 5: The Stalker comes back sooner

**Files:**
- Modify: `scripts/stalker.gd:23` (constant), `_attack`
- Test: `tests/test_world.gd`

**Interfaces:**
- Consumes: `MineLight.is_out()`.
- Produces: `const Stalker.RETREAT_SECONDS_DARK := 1.5`.

- [ ] **Step 1: Write the failing test**

```gdscript
func test_stalker_retreats_half_as_long_at_zero_light() -> void:
	var player := _still_player(Vector2(1000, 1000), 0.0)
	var stalker: Stalker = add(StalkerScene.instantiate())
	stalker.player = player
	stalker.run_base = _base(Vector2(-5000, -5000))
	stalker.global_position = player.global_position + Vector2(10, 0)
	await physics_frames(5)
	assert_true(stalker.retreat_timer > 0.0, "struck, so retreating")
	assert_true(stalker.retreat_timer <= Stalker.RETREAT_SECONDS_DARK, "short retreat at zero light (%.2f s)" % stalker.retreat_timer)
```

- [ ] **Step 2: Run to verify it fails.** Expected: FAIL, `RETREAT_SECONDS_DARK` not found.

- [ ] **Step 3: Implement.** In `_attack`: `retreat_timer = RETREAT_SECONDS_DARK if player.light.is_out() else RETREAT_SECONDS`.

- [ ] **Step 4: Run the suite.** Expected: `63 passed, 0 failed`.

- [ ] **Step 5: Commit** `scripts/stalker.gd tests/test_world.gd`: "M49: Stalker backs off 1.5 s at zero light".

### Task 6: Docs, probe, playtest

**Files:**
- Modify: `README.md` ("The Stalker" paragraph and a new "The dark" paragraph after "Mine decay"), `ROADMAP.md` (M49 line under Quality pass)
- Verify: `tests/balance_probe.gd`, `tests/playtest.gd`

- [ ] **Step 1: README.** After the "Mine decay" paragraph add "**The dark**: with the lantern at zero and no other light on you, you lose 1 health every 12s, you can't dig, ropes and ladders rot three times faster, and the Stalker only backs off for 1.5s after a strike. Any light - the base, a lamp, a camp lantern, a miner - suspends all of it." Add "(1.5s with the lantern out)" to the Stalker paragraph's "backs off for 3s".

- [ ] **Step 2: ROADMAP.** Under "Quality pass": "~~**M49 - The dark hurts.**~~ Done: at zero light you drain, can't dig, your tools rot and the Stalker returns sooner; any other light suspends it. Spec: `docs/superpowers/specs/2026-10-09-run-loop-redesign-design.md`."

- [ ] **Step 3: Probe.** Run `godot --headless --fixed-fps 60 -s tests/balance_probe.gd 2>&1 | grep -E "^(dive|dark)"`. Expected: every "dark" line ends `Died (dark)` with time about 1:36 or less (60 s of light plus about 36 s of drain); every "dive" line is no longer `Alive` at depth 444 (the bot runs out of light around row 400 and dies in the dark or to a fall). Paste before (the M48 commit message has it) and after into the commit message.

- [ ] **Step 4: Playtest.** Run `xvfb-run -a godot --fixed-fps 60 -s tests/playtest.gd 2>&1 | grep -E "ok|FAIL|scenarios"`. Expected: `12 scenarios, 0 failed`. The courses set `burn_rate = 0`, so none goes dark.

- [ ] **Step 5: Commit and push** `README.md ROADMAP.md`: "M49: the dark hurts - docs and probe", then `git push -u origin ccr-6425e3c0-cwr3jr`.

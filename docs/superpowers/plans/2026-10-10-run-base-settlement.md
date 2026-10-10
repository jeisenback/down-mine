# Run Base as a Settlement Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The run base grows in three tiers (Camp, Outpost, Fort) bought with one key at the base, raising its health, light capacity and wall strength and bringing the beacon and bell with the tiers.

**Architecture:** `RunBase` owns the tier table and a `grow()` that applies one tier; `Main` replaces the beacon and bell keys with one U key that pays the cost and calls it; `Burrower` reads the chew time from the base. Each tier shows its props (palisade, rampart, and the existing beacon and bell art) as hidden children of the base that `grow()` reveals.

**Tech Stack:** Godot 4.5, GDScript. Tests are `tests/test_*.gd` extending `TestCase`, run with `/opt/godot/godot --headless --fixed-fps 60 -s tests/run_tests.gd` (run `--headless --import` once after adding scripts). Playtest: `xvfb-run -a /opt/godot/godot --fixed-fps 60 -s tests/playtest.gd`. Record the baseline counts before Task 1.

**Spec:** `docs/superpowers/specs/2026-10-10-run-base-settlement-design.md` (planning issue #37). Related: #35 workers and jobs and #36 rhythm of threat (both merged), #38 hub as a kingdom.

## Global Constraints

- `TIER_COSTS := [0, 70, 120]`, `TIER_NAMES := ["Camp", "Outpost", "Fort"]`, `TIER_MAX_HEALTH := [3, 4, 5]`, `TIER_LIGHT_FUEL := [200.0, 260.0, 340.0]`, `TIER_WALL_CHEW_SECONDS := [2.5, 3.5, 5.0]`.
- The Outpost brings the beacon (radius range x1.5, burn x1.5, as `build_beacon` does today) and the Fort brings the bell; neither is bought separately and the 2 and 3 keys are removed. U is the one growth key.
- Buying pays the tier's ore from `Player.currency` at once, adds `BUILD_NOISE` (10) at the base, heals the base to the new max health and fills the base light to the new capacity.
- Refused (nothing taken) when: not `_near_base()`, ore short, already at the Fort, or the base has fallen (`health <= 0`).
- Tiers reset every run; replanting (P) keeps the tier and the props follow the base. No save-format change. Repair, fortify, the crew's stations and jobs, the waves and the base-light defence are unchanged.
- The Burrower reads the reinforced-wall chew time from `target.wall_chew_time()` at the moment it chews.
- No emojis anywhere. Every commit message ends with the two attribution lines used on this branch (see `git log -1`).

## Review Focus

1. Max health is now per tier: `needs_repair`, `heal`, `tick_repair`, `take_hit` and the `health_changed` signal must all use the tier's max, not the old constant (a 3/4 Outpost needs repair). Task 1.
2. The beacon's multipliers must be applied exactly once (buying the Outpost twice is impossible, replanting does not reapply, and `grow()` at the Fort does not rebuild the beacon). Task 1.
3. A Burrower mid-chase when the base grows must use the new chew time on its next chew. Task 1.
4. The old 2 and 3 keys do nothing, and everything that read `has_bell` (the wave line's size, the bell alarm, the ring animation) still works now that the bell arrives only at the Fort. Task 2.
5. Replanting keeps the tier, the props and the light capacity. Tasks 2 and 3.
6. Text that names the removed keys or separate buys (README, hub, prompts) must all be updated. Task 4.

---

### Task 1: Tiers in RunBase, and the Burrower reads the chew time

**Files:**
- Modify: `scripts/run_base.gd`, `scripts/burrower.gd` (`WALL_CHEW_TIME` use near line 79; the constant goes)
- Modify: `tests/test_art_wiring.gd:185-186`, `tests/test_world.gd:244` and any test reading `RunBase.MAX_HEALTH` where the tier matters (`MAX_HEALTH` stays as the Camp's value, 3)
- Test: `tests/test_world.gd`

**Interfaces:**
- Produces on `RunBase`: constants as in Global Constraints; `var tier: int = 0`; `func max_health() -> int`; `func tier_name() -> String`; `func next_tier_cost() -> int` (-1 at the Fort); `func wall_chew_time() -> float`; `func grow() -> bool` (false at the Fort or when `health <= 0`; otherwise `tier += 1`, sets the light's `max_fuel` to the tier's capacity and `fuel` to it, sets `health = max_health()` and emits `health_changed(health, max_health())`, calls `build_beacon()` on reaching tier index 1 and `build_bell()` on reaching tier index 2, reveals the tier's props, returns true). `signal health_changed(health, max_health)` already exists.
- `RunBase.BEACON_ORE_COST` and `BELL_ORE_COST` are removed (their cost is inside `TIER_COSTS`); `BUILD_NOISE` stays.

- [ ] **Step 1: Write the failing tests** (a `RunBase` from `RunBase.tscn` in the tree):
  - `test_tier_table_values`: for tier index 0, 1, 2 (reached by calling `grow()`): `tier_name()` is Camp, Outpost, Fort; `max_health()` 3, 4, 5; `light.max_fuel` 200, 260, 340; `wall_chew_time()` 2.5, 3.5, 5.0; `next_tier_cost()` 70, 120, -1.
  - `test_growing_heals_refills_and_signals`: base at health 1, light fuel 10: `grow()` returns true; `health == 4`, `light.fuel == 260`, `health_changed` was emitted with `(4, 4)`.
  - `test_the_beacon_arrives_with_the_outpost_and_the_bell_with_the_fort`: before: `not has_beacon and not has_bell`; after the first `grow()`: `has_beacon`, not `has_bell`, the light's `radius_max` is 1.5x and `burn_rate` is 1.5x what they were; after the second: `has_bell`; the beacon multipliers are not applied twice (Review Focus 2).
  - `test_grow_is_refused_at_the_top_and_when_fallen`: a third `grow()` returns false and changes nothing (tier, health, fuel); a base with `health == 0` refuses at any tier.
  - `test_max_health_is_per_tier_everywhere` (Review Focus 1): at the Outpost with health 3: `needs_repair()` true; `tick_repair` brings it to 4 and then stops; `heal(5)` caps at 4; `take_hit` and `health_changed` use 4 as the max.
  - `test_a_burrower_chews_for_the_current_tier_time` (Review Focus 3): a Burrower stepped by hand against a reinforced wall chews through in about 2.5 s at the Camp; after `grow()` mid-chew (say at 1 s) the next tile takes 3.5 s.
  - Update the existing tests that call `base.build_beacon()` / `build_bell()` directly (they still work; keep them) and `test_world.gd:91`'s wall-chew timing comment.
- [ ] **Step 2: Run, verify they fail** (`grow` not found / does not compile).
- [ ] **Step 3: Implement.** `max_health()` returns `TIER_MAX_HEALTH[tier]`; replace uses of `MAX_HEALTH` inside the class (`health` initial value stays `MAX_HEALTH`, the Camp's). Props are revealed in Task 3; `grow()` here only needs to be ready to call a `_show_tier_props()` that Task 3 fills (an empty method now). `Burrower` uses `target.wall_chew_time()` where it used `WALL_CHEW_TIME`.
- [ ] **Step 4: Run the whole suite, verify it passes.**
- [ ] **Step 5: Commit.**

---

### Task 2: One growth key in Main, and the HUD

**Files:**
- Modify: `scripts/main.gd` (`_check_builds` near line 542, `build_beacon` / `build_bell` near 561 to 575, the prompts near line 499, constants)
- Modify: `scripts/hud.gd:201` (`update_base`)
- Modify: `tests/test_main.gd:51-54` and other tests naming the 2 and 3 keys or `Main.build_beacon` / `build_bell`
- Test: `tests/test_main.gd`

**Interfaces:**
- Consumes: `RunBase.grow()`, `next_tier_cost()`, `tier_name()`, `max_health()`.
- Produces on `Main`: `func grow_base() -> bool` (refuses unless `_near_base()`, `run_base.health > 0`, `next_tier_cost() >= 0` and `player.currency >= next_tier_cost()`; otherwise `run_base.grow()`, `_pay_for_build(cost)` and true); the U key (`KEY_U`) calls it; `Main.build_beacon` and `Main.build_bell` and the 2 and 3 key handling are removed. `HUD.update_base(run_base, under_attack, walls)` shows `"Base: %s %d/%d  walls %d"` (tier name, health, tier max health, walls) plus the existing UNDER ATTACK suffix. The prompt at the base reads `"U: grow the base to a(n) <Next>, %d ore"` when affordable, `"<Next> needs %d ore"` when short, and nothing at the Fort.
- Note: `KEY_U` is also in `DEBUG_KEYS`; check `_check_debug_keys` and move the debug binding or guard it so U is not both (the debug keys are only live with the debug launch option; decide and ledger).

- [ ] **Step 1: Write the failing tests:**
  - `test_u_grows_the_base_and_charges_the_ore`: at the base with 200 ore: `grow_base()` is true, tier 1, currency 130, a build noise of `BUILD_NOISE` was added (use a deep base so it is heard, as the crew job noise test does); again: tier 2, currency 10; a third refused with the ore unchanged.
  - `test_growing_is_refused_short_of_ore_away_from_the_base_and_when_fallen`: each refusal leaves ore, tier and noise unchanged.
  - `test_the_removed_keys_do_nothing`: simulate the 2 and 3 key presses through `_check_builds` (as the existing build tests drive it, or by calling the match arms) and assert no beacon and no bell, and `Main` no longer has `build_beacon` or `build_bell` (`not main.has_method("build_beacon")`).
  - `test_replanting_keeps_the_tier_and_the_props` (Review Focus 5): grow twice, move the base, call `_place_crew_at_base()`: `tier == 2`, `light.max_fuel == 340`.
  - `test_the_bell_features_arrive_with_the_fort` (Review Focus 4): before the Fort the wave line has no size; after growing twice it does, and the alarm and `ring_bell` still work (the existing wave-line test, adapted).
  - `test_base_line_and_prompts`: the base line reads like `"Base: Outpost 4/4  walls 0"`; the prompt strings at each tier for enough ore, short ore, and the Fort (none).
  - Update the old bell and beacon build test (`tests/test_main.gd:51-54`) to grow instead.
- [ ] **Step 2: Run, verify they fail.**
- [ ] **Step 3: Implement.** Remove `BEACON_ORE_COST` / `BELL_ORE_COST` use from prompts. `grow_base` follows the old `build_beacon` shape.
- [ ] **Step 4: Run the whole suite and the playtest, verify both pass.**
- [ ] **Step 5: Commit.**

---

### Task 3: The tiers on screen

**Files:**
- Modify: `scripts/gear_art.gd` (gears `"palisade"`, `"rampart"` and their draw functions), `scripts/art_sprite.gd` (`GEAR_KINDS`), `scenes/RunBase.tscn` (two hidden `ArtSprite` children `Palisade` and `Rampart`, `z_index` behind the flag and stations), `scripts/run_base.gd` (`_show_tier_props`), `tools/preview_gear.gd` (add both to the sheet)
- Test: `tests/test_art_wiring.gd`, `tests/test_world.gd`

**Interfaces:**
- Consumes: `RunBase.grow()` from Task 1.
- Produces: `GearArt` gears `"palisade"` (a row of sharpened posts about 36 px across, feet at the origin) and `"rampart"` (a stone wall with a gate, about 40 px across); `RunBase` nodes `Palisade` and `Rampart` (ArtSprites, hidden until their tier): the Palisade is visible at tier index 1 only; the Rampart at tier index 2 (it replaces the palisade).

- [ ] **Step 1: Write the failing tests:**
  - `test_each_tier_prop_is_a_drawn_gear`: an `ArtSprite` of kind `"palisade"` and `"rampart"` builds a `GearArt` with that gear.
  - `test_the_base_shows_the_props_for_its_tier`: at the Camp `Palisade` and `Rampart` are hidden; after one `grow()` the Palisade is visible and the Rampart is not; after two the Rampart is visible and the Palisade is not; `Beacon` visible from the Outpost and `Bell` from the Fort (existing nodes).
  - `test_props_follow_a_replanted_base`: move the base after growing: the props' global positions keep their offsets from the base.
- [ ] **Step 2: Run, verify they fail.**
- [ ] **Step 3: Implement.** Draw the two props in code in the same style as the others (outlined, lit from the upper left, wood for the palisade and grey stone for the rampart); add them to `tools/preview_gear.gd`, render the sheet and look at it before committing; place them behind the flag and the stations so the crew stay visible (decide offsets and ledger them).
- [ ] **Step 4: Run the whole suite and the playtest, verify both pass.**
- [ ] **Step 5: Commit.**

---

### Task 4: Playtest, probe and docs

**Files:**
- Modify: `tests/playtest.gd` (new scenario), `README.md`, `ROADMAP.md`
- Test: `tests/playtest.gd`

**Interfaces:** Consumes everything above.

- [ ] **Step 1: Write the failing playtest scenario `base_grows_in_tiers`:** start a game, give the player 250 ore and stand at the base; press U through `main.grow_base()`; `check` after each of the three steps that the tier name on the HUD's base line, the base's max health, its light capacity and the props match the table, the ore falls by 70 then 120, and the third press is refused. `shot` each tier. Then plant the base deeper (P path or direct move plus `_place_crew_at_base()`) and `check` the tier survived.
- [ ] **Step 2: Run the playtest, verify the new scenario fails first** (before Tasks 1 to 3 it cannot pass; in order it should pass now, so confirm its first assertion fails by temporarily disabling `grow()`'s health change, then restore).
- [ ] **Step 3: Probe and docs.** Run `tests/balance_probe.gd` on `main` and on this branch (two worktrees, as before) and record both in the commit message; crewless bots buy nothing, so expect identical numbers (state that). Update `README.md`: the keys list (U grows the base; the beacon and bell are no longer separate keys), the base description (tiers, costs, what each gives) and anywhere the beacon or bell cost is named; update `ROADMAP.md` (M56 done; piece 3 of 4; next #38). Close #37 with links to the spec and this plan.
- [ ] **Step 4: Run the full suite and the playtest; both pass** (record counts).
- [ ] **Step 5: Commit.**

---

## Self-review notes

- Coverage: tier table and growth rules (Task 1), the key, ore, noise, refusals, prompts and HUD (Task 2), the props and replanting (Task 3), the playtest, probe and docs (Task 4). The spec's two open questions are decided in the tasks: props sit behind the flag and stations (offsets chosen in Task 3), and the short-of-ore prompt reads "<Next> needs N ore".
- Names: `RunBase.tier/max_health/tier_name/next_tier_cost/wall_chew_time/grow/TIER_*`, `Main.grow_base`, `HUD.update_base`, gears `"palisade"`, `"rampart"`, nodes `Palisade`, `Rampart`.
- Known cost of the order: after Task 1 and before Task 2 the beacon and bell can still be built by the old keys (and also arrive with tiers); do not release between them.
- The wave line's size now needs the Fort (the bell arrives at the third tier), which is a deliberate consequence of the design, called out in the README update.

# Workers and Jobs Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Crew miners do their type's job at the run base on their own, paid for in ore and noise, instead of adding a hidden start-of-run bonus.

**Architecture:** A scene-free `CrewJobs` object holds every job rule and constant; `Main` binds it to the run's base, player, noise meter and tool stocks and ticks it each frame for the crew at the base. `Progress.apply_to` drops the four type bonuses (keeping the Whisper's noise effect, now computed by `CrewJobs`). Each job gets a drawn station beside the flag where the miner stands and plays the dig pose while working.

**Tech Stack:** Godot 4.5, GDScript. Tests are `tests/test_*.gd` extending `TestCase`, run with `/opt/godot/godot --headless --fixed-fps 60 -s tests/run_tests.gd` (run `--headless --import` once after adding scripts so `class_name`s register). Playtest: `xvfb-run -a /opt/godot/godot --fixed-fps 60 -s tests/playtest.gd`. Record the baseline counts before Task 1 (currently 135 unit tests, 24 playtest scenarios).

**Spec:** `docs/superpowers/specs/2026-10-10-workers-and-jobs-design.md` (planning issue #35). Later pieces: #36 rhythm of threat, #37 run base as a settlement, #38 hub as a kingdom.

## Global Constraints

- Four jobs, rates are Rookie rates and the interval divides by `Progress.rank_of(member).strength` (Rookie 1.0, Seasoned 1.5, Veteran 2.0):
  - Mender: 1 base health per 12 s while the base is damaged, 5 ore per health.
  - Lamplighter: 4 ore becomes 20 fuel in the base light every 15 s, only while the base light is under 90% full.
  - Whisper: noise the base hears is 25% lower (times rank strength); free and silent.
  - Climber: one item every 60 s, rotating ladder, anchor, lamp; costs 6, 10 and 8 ore; honours hub unlocks; stops at 2 above the run's starting count of that item.
- Every working miner except the Whisper adds 1 noise at the base per 10 s of work, through `noise_meter.add_noise(amount, base.global_position)`.
- Jobs spend `Player.currency` (the ore carried this run) and pause when it is short; no hold key.
- Duplicate Whispers stack multiplicatively; total noise reduction is capped at 60% (factor never below 0.4).
- Jobs stop when the base has fallen (`RunBase.health == 0`) and for any miner not at the base.
- No change to the save format. No emojis anywhere. Every commit message ends with the two attribution lines used on this branch (see `git log -1`).

**Amended after the whole-branch review:** job noise is 1 per second per working miner (not per 10 s), the Climber's cap is 2 made of each item per run (`CLIMBER_MAX_MADE`), and `bind` takes `(base, player, noise_meter, unlocked, give_lamp)` with no lamp-count callable.

## Review Focus

1. Ore never goes negative and a job never runs on ore it does not have, including when two jobs would spend the last ore in one tick. Task 1.
2. A job that cannot work must not accrue noise or progress toward its next action. Task 1.
3. The Climber skips locked or capped items, rotates past them, and idles (no ore spent) when nothing is available. Task 1.
4. The old type bonuses must be gone everywhere they were read (light, noise, repair, traversal, and the hub text), with none double counted alongside the jobs. Task 2.
5. Crew who are stranded, lost or left behind do no work; crew replanted with the base move to their stations. Tasks 3 and 4.

---

### Task 1: CrewJobs

**Files:**
- Create: `scripts/crew_jobs.gd`
- Modify: `scripts/run_base.gd` (add `heal`)
- Test: `tests/test_crew_jobs.gd` (new)

**Interfaces:**
- Produces: `class_name CrewJobs extends RefCounted` with
  - constants `MENDER_INTERVAL := 12.0`, `MENDER_ORE := 5`, `LAMPLIGHTER_INTERVAL := 15.0`, `LAMPLIGHTER_ORE := 4`, `LAMPLIGHTER_FUEL := 20.0`, `LAMPLIGHTER_FULL_FRACTION := 0.9`, `CLIMBER_INTERVAL := 60.0`, `CLIMBER_ORDER := ["ladders", "anchors", "lamps"]`, `CLIMBER_COSTS := {"ladders": 6, "anchors": 10, "lamps": 8}`, `CLIMBER_CAP_OVER_START := 2`, `JOB_NOISE := 1.0`, `JOB_NOISE_INTERVAL := 10.0`, `WHISPER_REDUCTION := 0.25`, `WHISPER_MAX_REDUCTION := 0.6`
  - `func bind(base: RunBase, player: Player, noise_meter: NoiseMeter, unlocked: Dictionary, lamps: Callable, give_lamp: Callable) -> void`: stores the targets, records the starting counts (`player.ladders_left`, `player.anchors_left`, `lamps.call()`), and `unlocked` is `{"ladders": bool, "anchors": bool, "lamps": bool}`.
  - `func tick(delta: float, crew: Array) -> void` where `crew` is an Array of `{"name": String, "type": String, "strength": float}`.
  - `var working: Dictionary` mapping crew name to bool, set by the last `tick`.
  - `static func whisper_factor(strengths: Array) -> float` (Array of floats, one per Whisper): the product of `1 - WHISPER_REDUCTION * s`, never below `1 - WHISPER_MAX_REDUCTION`.
- Produces in `RunBase`: `func heal(amount: int) -> void` (adds health up to `MAX_HEALTH`, emits `health_changed`; no effect when `health == 0`).

- [ ] **Step 1: Write the failing tests** in `tests/test_crew_jobs.gd`, building a real `RunBase` (`RunBase.tscn`), a `Player` (`Player.tscn` with physics off) and a `NoiseMeter` (decay 0, `base_position` returning the base), binding with lamp stock held in a one-element array so the callables can read and change it:
  - `test_mender_heals_one_health_per_twelve_seconds_and_charges_ore`: base health 1, currency 20; tick 11.9 s: health 1, currency 20; tick 0.2 more: health 2, currency 15.
  - `test_rank_scales_every_job`: a strength 2.0 Mender heals after 6.0 s; a 1.5 Lamplighter refines after 10.0 s.
  - `test_lamplighter_refines_ore_into_base_fuel_only_below_ninety_percent`: base light fuel at 50%, currency 10; after 15 s fuel is +20 and currency 6; with fuel at 95% a further 15 s changes nothing and spends no ore.
  - `test_climber_rotates_ladder_anchor_lamp_and_charges_each`: all unlocked, currency 100; after 60 s, 120 s, 180 s: ladders +1 (currency 94), anchors +1 (84), lamps +1 via `give_lamp` (76).
  - `test_climber_respects_unlocks_and_caps`: anchors locked: the second item made is a lamp, never an anchor; with ladders already at start + 2, ladders are skipped; with every item locked or capped nothing is made and no ore is spent.
  - `test_whisper_factor_stacks_and_caps`: `whisper_factor([1.0])` is 0.75; `[2.0]` is 0.5; `[1.0, 1.0]` is 0.5625; `[2.0, 2.0, 2.0]` is 0.4 (capped).
  - `test_working_miners_make_one_noise_per_ten_seconds_except_the_whisper`: a Mender and a Whisper with the base damaged and ore available: after 10 s the noise meter holds 1.0; the `working` map shows both true.
  - `test_a_job_that_cannot_work_makes_no_noise_and_gains_no_progress` (Review Focus 2): Mender with the base at full health for 30 s: noise 0, `working` false; then damage the base: it takes the full 12 s to heal, not less.
  - `test_ore_never_goes_negative_and_jobs_wait_for_it` (Review Focus 1): currency 5, a Mender and a Lamplighter ready on the same tick: only one ore spend happens (currency never below 0, the other job's `working` false).
  - `test_nothing_works_after_the_base_falls`: base health 0: no spend, no noise, all `working` false.
  - `test_heal_stops_at_full_health_and_at_zero`: `RunBase.heal(5)` leaves health at `MAX_HEALTH`; `heal(1)` on a fallen base leaves it 0.
- [ ] **Step 2: Run the tests, verify they fail** (`CrewJobs` not declared): `/opt/godot/godot --headless --import && /opt/godot/godot --headless --fixed-fps 60 -s tests/run_tests.gd 2>&1 | grep -E "FAIL|passed"`. Expected: FAIL (does not compile).
- [ ] **Step 3: Implement `CrewJobs`** per the Interfaces. Each crew member has a work timer that accrues `delta` only on ticks where its job can work (input available and, for the Mender and Lamplighter, the target needs it); when it reaches `interval / strength` the job acts once and the timer resets. A separate per-member noise timer accrues the same way and emits `JOB_NOISE` every `JOB_NOISE_INTERVAL` (never for Whispers). Ore is checked and spent at the moment of acting, before the next member is evaluated, so two members never spend the same ore. The Climber's rotation index is per member and moves past locked, capped or already-chosen items. Implement `RunBase.heal`.
- [ ] **Step 4: Run the tests, verify they pass** and the whole suite is green (135 plus the new tests).
- [ ] **Step 5: Commit** (`git add scripts/crew_jobs.gd* scripts/run_base.gd tests/test_crew_jobs.gd*`).

---

### Task 2: Types stop being bonuses

**Files:**
- Modify: `scripts/progress.gd` (constants block 44-57; `apply_to` 343-364; `effect_text` 252-267)
- Modify: `tests/test_rules.gd:122-127`, `tests/test_world.gd:114-137` and any other test that reads a removed bonus
- Test: `tests/test_rules.gd`, `tests/test_world.gd`

**Interfaces:**
- Consumes: `CrewJobs.whisper_factor(strengths: Array) -> float`, `CrewJobs` constants.
- Produces: `Progress.apply_to(player, noise_meter, run_base)` no longer changes `light.burn_rate`, `light.radius_max`, `grapple_range`, `tool_life_multiplier`, `ladder_speed_multiplier`, `repair_cost_multiplier`, `repair_speed_multiplier`; it sets `noise_meter.noise_multiplier *= CrewJobs.whisper_factor(<strength of each Whisper on the crew>)`. New `func Progress.job_crew() -> Array` returning one `{"name", "type", "strength"}` per crew member (`strength` from `rank_of`).

- [ ] **Step 1: Write the failing tests:**
  - `test_types_no_longer_add_hidden_bonuses`: a crew of one of each type applied to a fresh player, meter and base leaves `player.light.burn_rate`, `player.light.radius_max`, `player.grapple_range`, `player.tool_life_multiplier`, `player.ladder_speed_multiplier`, `base.repair_cost_multiplier` and `base.repair_speed_multiplier` at their defaults (compare against a crewless apply); `noise_multiplier` is `0.75` for a Rookie Whisper and `0.5` for a Veteran one.
  - `test_job_crew_lists_name_type_and_rank_strength`: a roster with a Rookie and a Veteran on the crew yields strengths 1.0 and 2.0.
  - `test_effect_text_describes_the_job`: Rookie Mender "repairs the base 1 health per 12 s, 5 ore"; Veteran Mender "... per 6 s"; Rookie Lamplighter "refines 4 ore into 20 base fuel every 15 s"; Climber "makes a ladder, anchor or lamp every 60 s"; Whisper "noise -25%"; a Veteran Whisper "noise -50%" (replaces the old `test_veteran_bonus_and_title` assertion on text; the rank and title assertions stay).
  - Rewrite `test_ladders_outclimb_and_outlast_ropes_with_traversal_bonus` as `test_ladders_outclimb_and_outlast_ropes`: no Climber needed; rope life is `Player.ROPE_LIFE_SECONDS`, ladder life is `Player.LADDER_LIFE_SECONDS`, `ladder.climb_speed == Player.LADDER_CLIMB_SPEED`, ladders still climb faster than ropes, and a ladder is used up.
- [ ] **Step 2: Run, verify they fail.**
- [ ] **Step 3: Implement.** Remove the light, traversal and repair constants and their lines in `apply_to`; keep the noise reduction through `CrewJobs.whisper_factor`; keep every quirk unchanged. Rewrite `effect_text` for the four types as above (the Veteran numbers scale with `strength`). Add `job_crew`. Remove any now-unreferenced multiplier fields only if nothing else reads them (`grep` first; `RunBase.repair_cost_multiplier` and `repair_speed_multiplier` are still used by `repair_cost`/`tick_repair`, so they stay).
- [ ] **Step 4: Run the whole suite, verify it passes.**
- [ ] **Step 5: Commit.**

---

### Task 3: Main runs the jobs

**Files:**
- Modify: `scripts/main.gd` (`_ready` near 129-148, `_process` near 301-335, `_fail_run` near 700-715)
- Test: `tests/test_main.gd`

**Interfaces:**
- Consumes: `CrewJobs.bind/tick/working`, `Progress.job_crew()`, `RunBase.heal`.
- Produces: `Main.crew_jobs: CrewJobs`, bound once per run after `progress.apply_to`, with `unlocked = {"ladders": progress.has_unlock("ladders"), "anchors": progress.has_unlock("anchors"), "lamps": progress.has_unlock("lamps")}`, `lamps = func(): return lamps_left`, `give_lamp = func(): lamps_left += 1`. `Main._working_crew() -> Array` returns the `job_crew()` entries whose `name` is in `crew_at_base` (so stranded or escorted miners do nothing).

- [ ] **Step 1: Write the failing tests** in `tests/test_main.gd`, using a seeded `Main` with a saved crew:
  - `test_crew_jobs_tick_in_the_real_scene`: a Rookie Mender on the crew, the base damaged to 1 and `player.currency = 20`: after 12.5 s of frames (use `Engine.time_scale` or call `main._process(12.5)`) the base has 2 health and currency is 15.
  - `test_stranded_or_escorted_crew_do_no_work`: remove the Mender from `crew_at_base` (as a stranded miner would be) and the base stays at 1 health with no ore spent.
  - `test_lamps_made_by_the_climber_land_in_the_hud_stock`: a Climber with lamps unlocked: after 180 s of ticks `main.lamps_left` is the start count plus 1 (one rotation of ladder, anchor, lamp).
  - `test_job_work_is_heard_through_the_noise_meter`: with the base damaged and a Mender working for 10 s, `noise_meter.noise` is about 1.0 at a base planted on the surface.
- [ ] **Step 2: Run, verify they fail.**
- [ ] **Step 3: Implement the wiring.** Create and bind `crew_jobs` in `_ready` after `progress.apply_to(...)`; in `_process` call `crew_jobs.tick(delta, _working_crew())` once per frame while a run is live (not on the summary or title).
- [ ] **Step 4: Run the whole suite and the playtest, verify both pass.**
- [ ] **Step 5: Commit.**

---

### Task 4: Stations and the work pose

**Files:**
- Modify: `scripts/gear_art.gd` (four new gears, drawn like the others), `scripts/art_sprite.gd` (`GEAR_KINDS`), `scripts/main.gd` (`_place_crew_at_base`, a `_stations` list, applying `crew_jobs.working` to crew), `scripts/lost_miner.gd` (`set_working`), `tools/preview_gear.gd` (add the four to the sheet)
- Test: `tests/test_main.gd`, `tests/test_art_wiring.gd`

**Interfaces:**
- Consumes: `CrewJobs.working`, `ArtSprite` kinds. Stations are `ArtSprite` nodes added to the run base from `Main`; there is no new scene.
- Produces: `GearArt` kinds `"bench"` (Mender), `"lantern_post"` (Lamplighter), `"muffling_post"` (Whisper), `"rope_rack"` (Climber), listed in `ArtSprite.GEAR_KINDS`; `Main.STATION_KIND := {"repair": "bench", "light": "lantern_post", "noise": "muffling_post", "traversal": "rope_rack"}` and `Main.STATION_OFFSET_X := {"light": -20.0, "repair": -34.0, "noise": 20.0, "traversal": 34.0}` (px from the flag; a second miner of the same type stands 8 px further out); `LostMiner.set_working(on: bool) -> void` sets the miner art's `state` to `"dig"` when on and `"idle"` otherwise (no effect on the sitting `"lost"` art).

- [ ] **Step 1: Write the failing tests:**
  - `test_each_job_has_a_drawn_station`: for each station kind, an `ArtSprite` of that kind builds a `GearArt` with `gear` equal to it (in `test_art_wiring.gd`).
  - `test_crew_stand_at_the_station_for_their_type`: a crew of one of each type puts each miner's `global_position.x - run_base.global_position.x` at the offset for their type, on the floor line (`BASE_FLAG_HEIGHT_ABOVE_PLAYER`).
  - `test_a_second_miner_of_a_type_stands_beside_the_first`: two Menders stand 8 px apart at the same station.
  - `test_replanting_the_base_moves_stations_and_crew`: after `_check_plant`'s code path runs (or `_place_crew_at_base()` after moving the base), stations and crew follow the base.
  - `test_working_miners_dig_and_idle_ones_stand`: while `crew_jobs.working[name]` is true the miner's art state is `"dig"`, otherwise `"idle"`.
- [ ] **Step 2: Run, verify they fail.**
- [ ] **Step 3: Implement.** Draw the four stations in `GearArt` in the same style as the other props (a workbench with tools, a post with a hanging lantern, a padded post with a drum, a rack of coiled rope), each about 14 px wide; add them to `preview_gear.gd` and look at the sheet before committing. `_place_crew_at_base` now computes positions from `STATION_OFFSET_X`; `Main` creates the station `ArtSprite`s (children of `run_base`, one per crew type present) when it spawns the crew and repositions them on replant.
- [ ] **Step 4: Run the whole suite and the playtest, verify both pass.**
- [ ] **Step 5: Commit.**

---

### Task 5: Playtest, probe and docs

**Files:**
- Modify: `tests/playtest.gd` (new scenario), `README.md`, `ROADMAP.md`
- Test: `tests/playtest.gd`

**Interfaces:** Consumes everything above.

- [ ] **Step 1: Write the failing playtest scenario `crew_jobs_at_work`:** seed a save with a full crew (one Rookie of each type), start a game, damage the base to 1, set `player.currency = 100`, lower the base light to 50%, then run about 60 s of game time (`Engine.time_scale = 6.0` for 600 physics frames, restored afterwards). `check` that: base health rose, base fuel rose, a ladder or anchor or lamp was made, noise on the meter is above 0, currency fell, each miner stands at its station, and the working miners show the dig pose. Save a screenshot (`shot("crew at work")`) and look at it.
- [ ] **Step 2: Run the playtest, verify the new scenario fails first** (before Tasks 1 to 4 land it cannot pass; if executing in order it should pass now, so write it first and confirm the first failing assertion).
- [ ] **Step 3: Probe and docs.** Run `tests/balance_probe.gd` before this plan (from `main`) and after, and record both in the commit message; the crewless bots should be unchanged. Update `README.md`'s crew section (jobs, costs, noise) and add the milestone to `ROADMAP.md`; close #35 with a link to the spec and this plan.
- [ ] **Step 4: Run the full suite and the playtest; both pass** (record counts).
- [ ] **Step 5: Commit.**

---

## Self-review notes

- Coverage: the four jobs, costs, noise, the Whisper cap, unlocks and caps, base-fallen, stations, work pose, `Progress` changes, hub text, saves untouched, and every test the spec lists map to a task. "Whether job noise shows on the HUD noise line" and "station spacing with the bell and beacon present" are left to the implementer of Task 4 as the spec says; the offsets above are the plan's decision.
- Names: `CrewJobs.bind/tick/working/whisper_factor`, `RunBase.heal`, `Progress.job_crew`, `Main.crew_jobs`, `Main._working_crew`, `LostMiner.set_working`, `STATION_KIND`, `STATION_OFFSET_X`.
- Known cost of the order: between Task 2 and Task 3 the branch has no Mender or Lamplighter effect at all (the bonuses are gone and the jobs are not yet ticking). Do not release between them.

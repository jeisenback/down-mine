# M53 Drawn Creatures and Gear Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the pack's sprite frames for creatures, pickups, the miner, the base and every placed or event object with the approved procedural art (`CreatureArt`, `GearArt`), animated by code and still pixelated.

**Architecture:** One new node, `ArtSprite`, owns a small transparent `SubViewport` (one unit = one world pixel, no antialiasing), draws a `CreatureArt` or `GearArt` inside it, and shows the result through a nearest-filtered `Sprite2D`, so the art stays on the pixel grid under the camera's 3x zoom and is lit like any sprite. Each scene swaps its `Sprite2D` for an `ArtSprite` child named `Art`; each script drives `art.pose`, `art.state`, `art.t` and `flip_h` where it used to set `frame`. Collision shapes, behaviour, numbers and save data do not change.

**Tech Stack:** Godot 4.5, GDScript. Tests are `tests/test_*.gd` extending `TestCase`, run with `godot --headless --fixed-fps 60 -s tests/run_tests.gd` (the binary this session is `/opt/godot/godot`; run `--headless --import` once after adding scripts so `class_name`s register). Playtest: `xvfb-run -a godot --fixed-fps 60 -s tests/playtest.gd`. Record the baseline counts before Task 1 (`git log -1` and a first run); every task ends with both green at the same or higher counts.

**Spec:** No design doc; the approved prototypes are the spec: `docs/redraw/proc_creatures.png`, `docs/redraw/proc_player_base.png`, drawn by `scripts/creature_art.gd` and `scripts/gear_art.gd` (previews: `tools/preview_creatures.gd`, `tools/preview_gear.gd`). User decisions this session: darker and grittier; shapes redrawn, not recoloured; drawn in code in Godot; Stalker is a spider, Burrower is the low many-legged crawler with mandibles; the support is a wedged prop post; "nothing" to change on the last batch.

## Global Constraints

- Art stays pixelated: `SubViewport` with `snap_2d_transforms_to_pixel`-equivalent behaviour is not available, so the viewport is sized in world pixels, `canvas_item_default_texture_filter` is nearest, 2D MSAA off, and the displaying `Sprite2D` uses `TEXTURE_FILTER_NEAREST`.
- Art faces +x. Mirroring for a creature heading left is `ArtSprite.flip_h`, which flips the displayed sprite about the art's origin.
- Collision shapes, speeds, ranges, damage, prompts and noise values are untouched. Visible sizes may differ from the old sprites (the Stalker spider spans about 24 px, the Burrower about 30 px); that is accepted.
- Each instance starts at a random clock phase so two creatures never animate in lockstep. Art that is off screen must not render (see Task 1).
- Tests must not read pixels in headless mode (the headless renderer returns blank images); pixel assertions live in the playtest, which runs under xvfb.
- `props.png` and `tiles.png` stay (tiles, the gallery posts and the old mine still use them); only sprite nodes for the objects listed here go away.
- No emojis anywhere. Every commit message ends with the two attribution lines used on this branch (see `git log -1`).

## Review Focus

1. Mirrored creatures: a Stalker, Burrower or Snuffer moving left must show mirrored art, and a lost miner following the player must mirror like the player. Tasks 2 and 4.
2. Many creatures at once: a Stalker nest level, several Burrowers and Snuffers must not each render a viewport while off screen. Task 1.
3. Worn placed tools: ladder, rope, support and anchor art must follow `lifetime` (fresh to worn) so the player can read their remaining life. Tasks 5 and 6.
4. Scenes that other code finds by node name (`$Body`, `$Sprite2D`, `$Flag`, `$Beacon`, `$Bell`, `$Cage`, `$Haze`) must still start without script errors (the test runner fails on any script error). Every task.
5. Different lost miners must still look like different people (shirt colour). Task 4.

---

### Task 1: ArtSprite

**Files:**
- Create: `scripts/art_sprite.gd`
- Create: `tests/test_art_sprite.gd`

**Interfaces:**
- Produces: `class_name ArtSprite extends Node2D` with
  - `@export var kind: String` (one of `CreatureArt`'s kinds or `GearArt`'s gears: "stalker", "burrower", "snuffer", "fuel", "ore", "player", "flag", "beacon", "bell", "support", "lamp", "ladder", "rope", "anchor", "camp", "lift", "outpost", "nest", "heart", "relic", "vault", "lost", "sign", "gas")
  - `@export var cell: Vector2i = Vector2i(48, 48)` (viewport size in world px)
  - `@export var origin: Vector2i = Vector2i(24, 24)` (where the art's origin sits inside the cell)
  - `@export var length: float = 64.0` (passed to `GearArt.length`)
  - `var art: CreatureArt` (the drawn node; a `GearArt` for gear kinds), created in `_ready`
  - `var flip_h: bool` (setter mirrors the displayed sprite about the origin)
  - `var sprite: Sprite2D` (the displayed result, centered so the art origin lies at this node's origin)

- [ ] **Step 1: Write the failing tests** in `tests/test_art_sprite.gd`:
  - `test_a_creature_kind_builds_a_creature_art`: `ArtSprite` with `kind = "stalker"` added to the tree; after one frame `art is CreatureArt`, `not art is GearArt`, `art.kind == "stalker"`.
  - `test_a_gear_kind_builds_a_gear_art_with_its_length`: `kind = "ladder"`, `length = 40.0`; `art is GearArt`, `art.gear == "ladder"`, `art.length == 40.0`; and `kind = "player"` yields `art.gear == "player"`.
  - `test_origin_is_the_nodes_position`: `cell = Vector2i(48, 48)`, `origin = Vector2i(24, 36)`: `sprite.position == Vector2(0, -36 + 24)` and `sprite.centered` (the cell's centre sits (0, -12) from the node origin).
  - `test_flip_h_mirrors_about_the_origin`: setting `flip_h = true` makes `sprite.scale.x == -1.0` and leaves `sprite.position.y` unchanged; setting it false restores `1.0`.
  - `test_pixel_settings`: the viewport has `transparent_bg`, size equal to `cell`, `msaa_2d == Viewport.MSAA_DISABLED`; the sprite's `texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST`.
  - `test_clock_phase_differs_per_instance`: two instances of the same kind have different `art.t` after `_ready` (seed the global RNG differently or compare over ten instances: not all equal).
  - `test_offscreen_art_does_not_render`: with a `VisibleOnScreenNotifier2D` child reporting off screen, the viewport's `render_target_update_mode == SubViewport.UPDATE_DISABLED`; calling the notifier's `screen_entered` handler (`_on_screen_entered`) sets `UPDATE_ALWAYS`, `_on_screen_exited` sets it back.
  - `test_unknown_kind_is_a_script_error_free_blank`: `kind = "nope"` builds without error and `art == null`; `flip_h` and node removal still work (the runner fails the test on any script error).

- [ ] **Step 2: Run tests, verify they fail** (`ArtSprite` not declared): `/opt/godot/godot --headless --import && /opt/godot/godot --headless --fixed-fps 60 -s tests/run_tests.gd`.

- [ ] **Step 3: Implement `scripts/art_sprite.gd`.** `_ready` builds: a `SubViewport` (size `cell`, `transparent_bg = true`, `msaa_2d` disabled, `render_target_update_mode` per the notifier), the art node as its child at `Vector2(origin)` (`animate = true`, `length` set, `t = randf() * 10.0`), a `Sprite2D` with `texture = viewport.get_texture()`, `texture_filter = NEAREST`, `position = Vector2(cell) / 2.0 - Vector2(origin)`, and a `VisibleOnScreenNotifier2D` whose rect is the cell around the sprite, wired to `_on_screen_entered` / `_on_screen_exited`. Initial update mode is `UPDATE_ALWAYS`; the notifier handlers toggle it (the notifier reports the true state on its first frame). Unknown `kind` leaves `art == null` and builds no viewport.

- [ ] **Step 4: Run tests, verify they pass**; also run the full suite (counts unchanged plus the new tests).

- [ ] **Step 5: Commit** (`git add scripts/art_sprite.gd* tests/test_art_sprite.gd*`).

---

### Task 2: Creatures

**Files:**
- Modify: `scenes/Stalker.tscn`, `scenes/Burrower.tscn`, `scenes/Snuffer.tscn` (replace the `Body` / `Sprite2D` sprite node with an `ArtSprite` named `Art`: kinds "stalker", "burrower", "snuffer"; cell 64x48, origin (32, 30))
- Modify: `scripts/stalker.gd:53-63`, `scripts/burrower.gd:27-46`, `scripts/snuffer.gd:24-51` (`frame` and `ANIM_FPS`/`FRAME_COUNT` use goes away; `flip_h` stays)
- Modify: `tests/test_main.gd` or the creature tests that spawn these scenes if they name the old node (search `Body`, `Sprite2D`)
- Test: `tests/test_art_wiring.gd` (new; shared by Tasks 2-7)

**Interfaces:**
- Consumes: `ArtSprite` (Task 1).
- Produces: each creature script keeps an `@onready var art: ArtSprite = $Art`. The Stalker sets `art.art.pose = 1.0` while its state is the strike (`State.STRIKE`, or whatever the script names its attack state; read `stalker.gd`) else 0.0. The Burrower sets `art.art.pose` to 1.0 while it is attacking, 0.0 otherwise (the mandibles snap on their own when pose is 0).

- [ ] **Step 1: Write the failing tests** in `tests/test_art_wiring.gd`:
  - `test_stalker_scene_has_an_art_child_of_kind_stalker`: instance `Stalker.tscn`, in the tree one frame: `get_node("Art") is ArtSprite`, `.kind == "stalker"`, and there is no `Body` node.
  - `test_burrower_and_snuffer_likewise` (kinds "burrower", "snuffer").
  - `test_creatures_mirror_toward_their_heading`: a Stalker with `velocity = Vector2(-30, 0)` after one `_process` has `art.flip_h == true`; with `velocity = Vector2(30, 0)`, false. Burrower and Snuffer: with the player to their left, `flip_h == true` (the old tests' setup for `to_target.x < 0.0`).
  - `test_stalker_lunges_in_its_strike`: set the state the script uses for the strike, one `_process`, assert `art.art.pose == 1.0`; back to lurk, `0.0`.

- [ ] **Step 2: Run, verify they fail.**
- [ ] **Step 3: Edit the three scenes and scripts** as in the Interfaces block; remove `PixelArt.keyed` calls and the `frame` lines; keep every other behaviour line untouched.
- [ ] **Step 4: Run the full suite and the playtest; both pass.** Open one playtest screenshot with a creature in it and confirm it is the drawn art.
- [ ] **Step 5: Commit.**

---

### Task 3: Pickups

**Files:**
- Modify: `scenes/FuelPickup.tscn`, `scenes/OrePickup.tscn` (`Body` becomes `Art`, kinds "fuel" and "ore", cell 32x32, origin (16, 16))
- Modify: `scripts/fuel_pickup.gd:11-19`, `scripts/ore_pickup.gd:9` (drop the frame twinkle and keying; the art animates itself)
- Test: `tests/test_art_wiring.gd`

**Interfaces:** Consumes `ArtSprite`. Pickup collision and pickup-by-distance code is unchanged.

- [ ] **Step 1: Failing tests:** `test_fuel_pickup_draws_the_flask` and `test_ore_pickup_draws_the_cluster` (`Art` exists, right kind, no `Body`); `test_picking_up_still_frees_the_pickup` for both (spawn at the player, one physics frame: refuels / adds ore, node freed).
- [ ] **Step 2: Run, verify they fail.**
- [ ] **Step 3: Edit scenes and scripts.**
- [ ] **Step 4: Full suite and playtest pass.**
- [ ] **Step 5: Commit.**

---

### Task 4: Miner and lost miners

**Files:**
- Modify: `scenes/Player.tscn` (`Body` becomes `Art`: kind "player", cell 48x48, origin (24, 31) so the feet land where the old sprite's did; the old offset was (0, -1) on a 16x16 frame, so feet at y = +7)
- Modify: `scripts/player.gd:97-154,327-350` (`_update_animation` sets `art.art.state` to "idle", "run", "dig", "jump" or "fall" and `art.flip_h = facing < 0`; the run-cycle frame helpers and sheet constants go away if nothing else uses them; `_anim_time` feeds `art.art.t` only if the art's own clock is disabled)
- Modify: `scenes/LostMiner.tscn`, `scripts/lost_miner.gd:37-87`: kind "player" when following (state "run" or "idle" mirroring the player's logic), kind "lost" while waiting to be found; `shirt_color` tints the coat: add `@export var coat: Color` to `GearArt` used for the coat's three tones (`coat`, `coatsh`, `coatlt` derived by `darkened`/`lightened`); `ArtSprite` forwards it when set.
- Modify: `scripts/pixel_art.gd` (remove `with_shirt` and its constants if no longer used; keep `keyed` and `keyed_region` while the gallery or tiles still use them)
- Test: `tests/test_art_wiring.gd`, existing player tests

**Interfaces:**
- Consumes: `ArtSprite`, `GearArt.state` ("idle" / "run" / "dig" / "jump" / "fall").
- Produces: `GearArt.coat: Color` (default the miner's red); `ArtSprite.coat: Color` forwarded to the art on `_ready`.

- [ ] **Step 1: Failing tests:**
  - `test_player_state_follows_movement`: with the player on the floor and no input, after `_update_animation(0.0, 0.016)` state is "idle"; with `input_dir = 1.0`, "run" and `flip_h == false`; with `input_dir = -1.0` and `facing = -1`, "run" and `flip_h == true`; airborne with `velocity.y < 0` "jump", `> 0` "fall".
  - `test_digging_shows_the_dig_state`: hold the dig key (the test helper the existing player tests use for space) and assert "dig".
  - `test_lost_miners_wear_their_own_coat`: two `LostMiner` instances given different `shirt_color` have different `art.art.coat`.
  - `test_lost_miner_sits_until_found_then_runs`: waiting miner `art.kind == "lost"`; after `recruit` / follow starts, kind "player" with state "run" while moving and "idle" when stopped; moving left mirrors it.
- [ ] **Step 2: Run, verify they fail.**
- [ ] **Step 3: Implement** per the Files block. The lost miner swaps by freeing and rebuilding its `ArtSprite` child (a helper `_set_art(kind: String)`), not by changing `kind` in place.
- [ ] **Step 4: Full suite and playtest pass.** Check a playtest screenshot with the miner standing and one running.
- [ ] **Step 5: Commit.**

---

### Task 5: Base, supports, lamps, anchors

**Files:**
- Modify: `scenes/RunBase.tscn` (`Flag`, `Beacon`, `Bell` become `ArtSprite`s of kinds "flag", "beacon", "bell"; `Beacon` and `Bell` stay hidden until built; keep node names), `scripts/run_base.gd:52-56` (no change expected beyond `visible = true`; the bell's `art.art.pose = 1.0` for two seconds when the bell warns, if the script has a place that rings it: read `run_base.gd` and `main.gd`'s bell code, otherwise skip the ring)
- Modify: `scenes/Support.tscn` (`Sprite` becomes `Art`, kind "support"), `scripts/support.gd` (`_process` sets `art.art.pose = 1.0 - lifetime`)
- Modify: `scenes/Lamp.tscn` (`Sprite` becomes `Art`, kind "lamp"), `scenes/Anchor.tscn` (kind "anchor"; `scripts/anchor.gd` sets `pose` from `1.0 - lifetime` if the art uses it, else not)
- Test: `tests/test_art_wiring.gd`

**Interfaces:** Consumes `ArtSprite`. `Support.lifetime`, `Anchor.lifetime` are the existing 1.0 to 0.0 values.

- [ ] **Step 1: Failing tests:**
  - `test_run_base_keeps_its_node_names_and_kinds`: `$Flag`, `$Beacon`, `$Bell` are `ArtSprite`s with kinds "flag", "beacon", "bell"; beacon and bell hidden by default; after the base builds them (the existing build calls) they are visible.
  - `test_support_wears_with_its_lifetime`: `Support.lifetime = 1.0` then one `_process(0.0)`: `art.art.pose == 0.0`; `lifetime = 0.25`: `pose == 0.75`.
  - `test_lamp_and_anchor_scenes_build`: kinds "lamp" and "anchor", no script errors.
- [ ] **Step 2: Run, verify they fail.**
- [ ] **Step 3: Edit scenes and scripts.**
- [ ] **Step 4: Full suite and playtest pass.**
- [ ] **Step 5: Commit.**

---

### Task 6: Ladders and ropes

**Files:**
- Modify: `scenes/Ladder.tscn` (`Sprite` becomes `Art`, kind "ladder", `length = 64`, cell 32x80, origin (16, 72) so the ladder stands from the feet), `scenes/Rope.tscn` (the `Visual` Polygon2D is replaced by `Art` of kind "rope", cell 32x112, origin (16, 8), `length = 96`)
- Modify: `scripts/rope.gd:20-34` (remove the pole texture setup; the script keeps its life and climb logic; sets `art.art.pose = 1.0 - lifetime` every frame; if the player or `Main` creates ropes of other lengths by resizing the collision shape, set `art.length` from the shape's height when the node enters the tree)
- Test: `tests/test_art_wiring.gd`, existing rope and ladder tests

**Interfaces:** Consumes `ArtSprite.length` and `GearArt.pose` (wear). `Rope.lifetime` is the existing 1.0 to 0.0.

- [ ] **Step 1: Failing tests:**
  - `test_ladder_and_rope_draw_their_length`: the `Art` of an instanced `Ladder.tscn` has `art.length == 64.0`; the `Rope.tscn` one `96.0`.
  - `test_rope_length_follows_a_resized_shape`: set the rope's collision shape height to 48 before adding it to the tree: `art.length == 48.0`.
  - `test_climbing_tools_wear_with_lifetime`: for both, `lifetime = 0.2` and one `_process(0.0)` gives `art.art.pose == 0.8`.
  - Existing climbing tests (`is_on_rope`, rope decay, dark decay multiplier) keep passing unchanged.
- [ ] **Step 2: Run, verify they fail.**
- [ ] **Step 3: Edit scenes and `rope.gd`.** Remove `POLE_TEXTURE` and `POLE_REGION` only if nothing else references them (`grep`).
- [ ] **Step 4: Full suite and playtest pass.** Playtest screenshot: a placed ladder and rope.
- [ ] **Step 5: Commit.**

---

### Task 7: Event rooms and hazards

**Files:**
- Modify: `scenes/Camp.tscn` (`Tent` and `Crate` become one `Art` of kind "camp"), `scenes/Outpost.tscn` (`TentLeft`, `TentRight`, `Campfire` become one `Art` of kind "outpost"), `scenes/Lift.tscn` (`Cage` becomes `Art` kind "lift", `length = 64`; `scripts/lift.gd` keeps `cage` as the `ArtSprite` and `cage.modulate` / `cage.visible` keep working because `ArtSprite` is a `Node2D`; set `art.art.pose` to 0.0), `scenes/Nest.tscn` (`Eggs`/`Sprite`/`Scorch` become `Art` kind "nest"; the burnt state hides it as the old code hid the eggs: read `nest.gd`), `scenes/Heart.tscn` (kind "heart"), `scenes/Relic.tscn` (kind "relic"), `scenes/VaultDoor.tscn` (kind "vault"; `scripts/vault_door.gd` sets `pose = 1.0` once broken if the door stays visible, otherwise leave), `scenes/StrandedSign.tscn` (kind "sign"; `scripts/stranded_sign.gd` sets `pose` to 1.0 for veteran signs), `scenes/GasCloud.tscn` (`Haze` becomes `Art` kind "gas"; `scripts/gas_cloud.gd` sets `pose = _age / LIFE_SECONDS` each frame and the cell covers the cloud's 2-tile radius)
- Modify: `scripts/camp.gd`, `scripts/outpost.gd`, `scripts/nest.gd` and others only where they reference the removed nodes by name (search before editing)
- Test: `tests/test_art_wiring.gd`

**Interfaces:** Consumes `ArtSprite`, `GearArt.pose`. Each object's collision, prompts, costs and noise are unchanged.

- [ ] **Step 1: Failing tests:**
  - `test_each_event_scene_builds_with_its_art`: for each scene above, instance it, add it to the tree for a frame: it has an `Art` child whose `kind` is the one listed, with no script errors.
  - `test_lift_cage_still_dims_until_repaired_and_hides_when_used`: the existing lift test sets `cage.modulate`/`visible`; assert those on the new `Art`.
  - `test_gas_cloud_thins_with_age`: `_age = 0` gives `art.art.pose == 0.0`; `_age = LIFE_SECONDS / 2` gives `0.5`.
  - `test_veteran_sign_is_brighter`: a veteran `StrandedSign` has `art.art.pose == 1.0`, an ordinary one `0.0`.
  - `test_nest_hides_its_art_once_burned`: after the burn, `Art` is not visible.
- [ ] **Step 2: Run, verify they fail.**
- [ ] **Step 3: Edit scenes and scripts.**
- [ ] **Step 4: Full suite and playtest pass** (the playtest visits camp, outpost, lift, nest, heart and vault scenarios; confirm in screenshots).
- [ ] **Step 5: Commit.**

---

### Task 8: Pixel check, speed check, docs and cleanup

**Files:**
- Modify: `tests/playtest.gd` (new scenario), `README.md`, `ROADMAP.md`
- Modify: `scripts/pixel_art.gd` (delete helpers nothing uses any more)
- Delete: nothing from `assets/` (the pack stays; tiles and gallery posts use it)

**Interfaces:** Consumes everything above.

- [ ] **Step 1: Write the failing playtest scenario `drawn_art_is_on_screen_and_pixelated`:** start a game, spawn one of each kind next to the player (use the existing debug spawn helpers or instance scenes into `main`), wait 5 frames, then `check` that (a) the screenshot region around the player has at least 40 non-background pixels, (b) every `ArtSprite`'s viewport texture image has a non-zero alpha pixel (`get_texture().get_image()`), and (c) the sprite's viewport texture is exactly `cell` pixels. Add the scenario to the `scenarios` list.
- [ ] **Step 2: Run the playtest, verify it fails** until all tasks are wired (it should pass at this point; if any prior task skipped a kind, this finds it).
- [ ] **Step 3: Speed check:** a scripted run (`tests/balance_probe.gd` or a one-off in the playtest) with 12 creatures and 20 placed objects near the player measures the average frame time over 120 frames; record it in the commit message. If it exceeds 8 ms per frame at 1x, cap simultaneously rendering viewports: only art within 1.5 screen widths of the player updates (set via the notifier rect) and note the result.
- [ ] **Step 4: Remove dead code** found by `grep` (unused `PixelArt` helpers, `ANIM_FPS`/`FRAME_COUNT` constants, the old sprite constants in `player.gd`, the `Body` references in comments). README: replace the art credit line and describe that creatures, miner and objects are drawn in code (`scripts/creature_art.gd`, `scripts/gear_art.gd`, previews in `tools/`). ROADMAP: add M53 as done.
- [ ] **Step 5: Run the full suite and the playtest; both green.** Commit.

---

## Self-review notes

- Coverage: every approved art (stalker, burrower, snuffer, fuel, ore, miner, flag, beacon, bell, support, lamp, ladder, rope, anchor, camp, lift, outpost, nest, heart, relic, vault, lost miner, sign, gas) has a task; the gallery posts and old mine tiles stay as drawn in M52.
- Names: `ArtSprite.art`, `.flip_h`, `.kind`, `.cell`, `.origin`, `.length`, `.coat`; `GearArt.state`, `.pose`, `.length`, `.coat`; scene child name `Art` throughout.
- Open decision to confirm with the user: the creature viewports default to 64x48 and the miner's to 48x48; larger cells cost more fill, smaller ones may clip the Burrower's tail (about 30 px). The Task 8 speed check decides whether to shrink them.

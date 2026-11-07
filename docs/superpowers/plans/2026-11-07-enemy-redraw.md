# Enemy Redraw Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Redraw the Stalker, Burrower, Snuffer and Nest so each is memorable and shows its mechanic, in an eerie and quiet style, with the Stalker first seen as two eyes at the edge of the dark.

**Architecture:** The art stays code-drawn in `CreatureArt` (and `GearArt` for the nest) behind the same `kind`/`pose`/`flip_h` interface. One new mechanism: an optional unlit "glow" layer in `ArtSprite`, a second tiny viewport drawn through an unshaded sprite, so eyes show in total dark. A review harness renders every creature in every state so each redraw is judged by pictures.

**Tech Stack:** Godot 4.5 GDScript; unit suite `/opt/godot/godot --headless --fixed-fps 60 -s tests/run_tests.gd`; playtest `xvfb-run -a /opt/godot/godot --fixed-fps 60 -s tests/playtest.gd`.

**Spec:** `docs/superpowers/specs/2026-11-07-enemy-redraw-design.md`

## Global Constraints

- No change to speed, health, light, noise or collision of any enemy; no change to `kind` names, `pose` (0 to 1) or `flip_h`. Existing tests for enemy behaviour pass without edits.
- Cells: Stalker `Vector2i(64, 48)` origin `(32, 30)`; Burrower and Snuffer `(48, 48)` origin `(24, 24)`; the nest keeps its `GearArt` cell. Art faces +x.
- Drawing takes no numbers from the global random generator (`ArtSprite` gives art its own phase generator).
- `CreatureArt` still redraws at `REDRAW_FPS` (20) and not while off screen; the frame-time budget test (`tests/test_perf.gd`) is unchanged.
- Style (spec): one accent colour each, pale or dark bodies; silhouette reads at 1x with no interior detail; slow idle, fast only on the strike; at most one dark outline; Stalker palette bone and grey with ice blue eyes (red flash on the strike); Burrower dull bronze with a hot orange mouth; Snuffer translucent grey-blue with a magenta core; Nest bruised cream and grey with dull amber.
- Pixel assertions run in the playtest (`tests/playtest.gd`, under xvfb), not the headless unit suite: headless has no renderer. Unit tests check structure (nodes, flags, properties).
- No emojis anywhere (user preference).

## Review Focus

1. **Glow cost off screen:** a creature with a glow layer that is off screen must not render its glow viewport (`UPDATE_DISABLED`), as the lit one does not. Pinned in Task 1.
2. **Mirrored creature:** the glow sprite must mirror with `flip_h` exactly as the lit sprite does, so the eyes stay on the side the creature faces. Pinned in Task 1 and Task 3.
3. **Total dark:** with the lantern out and no light near, the eyes are still visible and the body is not. Pinned in Task 3 (playtest).
4. **Nothing clips:** no art, in any pose or variant, draws an opaque pixel on its cell's border. Pinned in Tasks 3 to 6 (playtest).
5. **Deep variant:** the Stalker woken at the nest layer draws four eyes, the others two, and a burned nest's removal leaves no orphan glow node. Pinned in Task 3.

---

## Phase 0 (one PR): the glow mechanism and the review harness

### Task 1: An unlit glow layer in `ArtSprite`

**Files:**
- Modify: `scripts/creature_art.gd` (a `glow_only` flag, a `variant`, a glow draw hook), `scripts/art_sprite.gd` (the glow layer)
- Test: `tests/test_art_sprite.gd`

**Interfaces:**
- Produces on `CreatureArt`: `var glow_only: bool = false` (when true, `_draw()` calls `_draw_glow()` instead of the lit art), `var variant: int = 0` (0 ordinary, 1 deep), `func _draw_glow() -> void` (a no-op by default; each kind overrides through a `match kind` like `_draw`).
- Produces on `ArtSprite`: `@export var glow: bool = false`; after `_ready`, when `glow` is true: `glow_viewport: SubViewport`, `glow_art: CreatureArt` (same `kind`, `glow_only = true`, `animate = false`, `set_process(false)`), `glow_sprite: Sprite2D` with `material` a `CanvasItemMaterial` whose `light_mode` is `LIGHT_MODE_UNSHADED`. All three are null when `glow` is false. The glow art copies `t`, `pose` and `variant` from the main art each time the main art draws; the glow sprite uses the same position and `flip_h` rule as `sprite`; the glow viewport updates only while on screen.

- [ ] **Step 1: Write failing tests** in `tests/test_art_sprite.gd` (use the file's existing helpers for building an `ArtSprite`):
  - `test_glow_is_off_by_default`: a stalker `ArtSprite` has `glow_viewport == null`, `glow_art == null`, `glow_sprite == null`.
  - `test_a_glow_sprite_is_unshaded_and_shares_the_pixel_grid`: with `glow = true`, `glow_sprite.material is CanvasItemMaterial`, its `light_mode == CanvasItemMaterial.LIGHT_MODE_UNSHADED`, `glow_sprite.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST`, `glow_sprite.position == sprite.position`, `glow_viewport.size == cell`.
  - `test_the_glow_mirrors_with_the_sprite`: set `flip_h = true`; `glow_sprite.scale.x == sprite.scale.x` and `glow_sprite.position == sprite.position`.
  - `test_the_glow_follows_the_lit_arts_clock_and_pose`: set `art.t = 3.5`, `art.pose = 1.0`, `art.variant = 1`, call the draw-connected sync (`_on_art_drawn()`); `glow_art.t == 3.5`, `pose == 1.0`, `variant == 1`.
  - `test_the_glow_sleeps_off_screen`: after `_on_screen_exited()`, `glow_viewport.render_target_update_mode == SubViewport.UPDATE_DISABLED`; after `_on_screen_entered()` and `_on_art_drawn()`, it is `UPDATE_ONCE`.
- [ ] **Step 2:** Run the suite. Expected: FAIL (the properties do not exist; compile error counts).
- [ ] **Step 3: Implement** `glow_only`, `variant`, `_draw_glow` in `scripts/creature_art.gd` and the glow layer in `scripts/art_sprite.gd`, following the existing viewport pattern in `ArtSprite._ready` (a second `SubViewport` of the same size, transparent, no MSAA, nearest-filtered sprite, same `_place_sprite` position and mirroring, woken and put to sleep with the lit viewport).
- [ ] **Step 4:** Run the suite. Expected: all pass, count up by 5.
- [ ] **Step 5:** Commit `Art: an optional unlit glow layer`.

### Task 2: The creature lineup harness

**Files:**
- Create: `tests/art_lineup.gd` (a `SceneTree` script, not part of the suite), a scenario in `tests/playtest.gd`
- Modify: `README.md` (one line under the testing section naming the harness)

**Interfaces:**
- Consumes: `ArtSprite` (`kind`, `glow`, `art.pose`, `art.variant`, `flip_h`).
- Produces: `godot --fixed-fps 60 -s tests/art_lineup.gd [-- kind=stalker]` under xvfb writes PNG sheets to `playtest_out/art/`: for each kind (all four, or the one named), each state (idle `pose 0`, strike `pose 1`, and for the Stalker the deep variant) on a plain background at 1x and 5x (`<kind>_<state>_1x.png`, `<kind>_<state>_5x.png`), plus a single `<kind>_sheet.png` of all states. Playtest scenario `enemy_art` (empty body now) is the hook later tasks fill.

- [ ] **Step 1:** Write the script: build an `ArtSprite` per kind and state on a `ColorRect` background, a `Camera2D` at `zoom` 1 then 5, wait 40 frames, save the viewport image. Reuse the throwaway pattern used for the M89 and M90 screenshots (a `SceneTree` script creating nodes in `_run.call_deferred()`).
- [ ] **Step 2:** Run it under xvfb on the current art. Expected: the PNGs exist and show today's four creatures. (Verification step: view `playtest_out/art/stalker_sheet.png`.)
- [ ] **Step 3:** Add the empty `enemy_art` scenario to `tests/playtest.gd` following the existing scenario registration; it passes trivially now.
- [ ] **Step 4:** Run the full suite and the playtest. Expected: unchanged counts plus the new scenario.
- [ ] **Step 5:** Commit `Art: a creature lineup harness`; open the Phase 0 PR (Tasks 1 and 2).

---

## Phase 1 (one PR): the Stalker

### Task 3: The Stalker, seen by its eyes

**Files:**
- Modify: `scripts/creature_art.gd` (`_draw_stalker`, `_draw_glow` for "stalker", the palette), `scripts/stalker.gd` (`var deep: bool = false`, set the art's `variant` in `_ready`), `scenes/Stalker.tscn` (`glow = true` on `Art`), `scripts/main.gd` (`_wake_stalker`: `hunter.deep = true` when `layer == NEST_LAYER`), `tests/playtest.gd` (`enemy_art` scenario), `tests/test_art_wiring.gd`
- Test: `tests/test_art_wiring.gd`, `tests/playtest.gd`

**Interfaces:**
- Consumes: Task 1's `glow`, `glow_only`, `variant`, `_draw_glow`.
- Produces: `Stalker.deep: bool`. `CreatureArt._draw_stalker()` draws the lit body: a tall thin hunched pale figure (about 10 to 12 px wide and 20 to 22 tall, forearms longer than its legs), bone and grey, a slow sway from `t`, forearms reaching with `pose`; it draws **no eyes**. `_draw_glow()` for "stalker" draws only the eyes: two ice blue (`variant` 0) or four (`variant` 1), a slow blink from `t`, swelling and narrowing to slits as `pose` goes 0 to 1, red at `pose` 1.

- [ ] **Step 1: Write failing tests.** Unit (`tests/test_art_wiring.gd`):
  - `test_the_stalker_scene_has_a_glow_layer`: `Stalker.tscn` instantiated: `art.glow == true` and `art.glow_art != null`.
  - `test_only_the_deep_stalker_has_four_eyes`: a Stalker with `deep = true` added to the tree: `art.art.variant == 1` and `art.glow_art.variant == 1`; one with `deep = false`: both 0.
  - `test_waking_the_nest_layer_stalker_makes_it_deep` (use `Main`'s existing wake path with `NEST_LAYER`): the spawned stalker's `deep` is true; for another layer, false.
  - `test_a_freed_stalker_leaves_no_glow_nodes_behind`: `queue_free` and a frame later, `art.glow_viewport` is not valid.
  Playtest (`enemy_art` scenario, using `check()` and pixel reads of the viewport textures):
  - `the Stalker draws inside its cell`: render the lit art and the glow art at `pose` 0 and 1 and `variant` 0 and 1; no pixel with alpha above 0.1 on the outer ring of the 64 by 48 cell.
  - `the lit art has no eyes and the glow has only eyes`: in the lit image no pixel matches the eye colours; the glow image has between 2 and 24 opaque pixels, none in the body's lower half.
  - `the deep Stalker has four eyes`: the glow image's eye pixels split into two clusters at `variant` 0 and four at `variant` 1 (count connected components of ice blue pixels).
  - `the strike changes the picture`: `pose` 1 differs from `pose` 0 in both images, and the glow at `pose` 1 contains red pixels, at `pose` 0 none.
  - `the glow mirrors`: with `flip_h` true, the glow image's eye centroid is on the opposite side of the origin from the unflipped one.
  - `eyes show in total dark`: in the real mine with the lantern out and no light within 200 px, a Stalker sprite 60 px from the player: the screenshot region around the eyes has pixels brighter than 0.4 while the body region (below the eyes) is below 0.1.
- [ ] **Step 2:** Run unit suite and playtest. Expected: FAIL.
- [ ] **Step 3: Implement** the signatures above. Guidance only: build the body from a few polygons on the pixel grid, bone `Color8(214, 208, 194)`, grey `Color8(120, 122, 126)`, dark `Color8(30, 30, 36)`; eyes ice blue `Color8(150, 215, 255)`, strike red `Color8(245, 74, 56)`. Keep the outline to one dark line. Iterate with the harness (`art_lineup.gd -- kind=stalker`) until the 1x silhouette reads as a tall thin figure, not a spider.
- [ ] **Step 4:** Run everything. Expected: all pass. View the harness sheet and the real-dark screenshot, and attach both to the PR.
- [ ] **Step 5:** Update `ROADMAP.md` (M92) and commit `Art: the Stalker, seen by its eyes`; open the Phase 1 PR.

---

## Phase 2 (one PR): the Burrower

### Task 4: The Burrower, a drill with legs

**Files:**
- Modify: `scripts/creature_art.gd` (`_draw_burrower`, palette), `tests/playtest.gd`, `tests/test_art_wiring.gd`
- Test: `tests/playtest.gd`, `tests/test_art_wiring.gd`

**Interfaces:**
- Consumes: `pose` (set by `burrower.gd`: 1 for `STRIKE_POSE_SECONDS`), `flip_h`. No script change.
- Produces: `_draw_burrower()` draws a long low (about four times as long as tall) segmented armoured worm: a fat head tapering through four or five segments that ripple front to back with `t`; a ring of pale teeth at the head that turns with `t` and flares open and spins fast with `pose`; a hot orange mouth glow (`Color8(240, 110, 40)`) inside the ring; a few rubble specks trailing off the flanks (a handful of pixels from `t`, no particles); bronze body.

- [ ] **Step 1: Write failing tests.** Existing `test_burrower_snaps_its_mandibles_when_it_strikes` must keep passing unchanged (it checks `pose`). Playtest (`enemy_art`): `the Burrower draws inside its 48 by 48 cell` (pose 0 and 1); `the Burrower is long and low` (the bounding box of opaque pixels at pose 0 is at least 3 times as wide as tall); `the strike changes the picture`; `the mouth glow is the only orange` (orange pixels exist at both poses and are inside the head's third of the box).
- [ ] **Step 2:** Run. Expected: FAIL.
- [ ] **Step 3: Implement** `_draw_burrower` per the Interfaces; iterate with `art_lineup.gd -- kind=burrower` until the 1x silhouette is a horizontal worm, unlike the Stalker's tall figure.
- [ ] **Step 4:** Run everything. Expected: all pass. Attach the sheet.
- [ ] **Step 5:** `ROADMAP.md` (M93); commit `Art: the Burrower`; open the Phase 2 PR.

---

## Phase 3 (one PR): the Snuffer

### Task 5: The Snuffer, the opposite of a lantern

**Files:**
- Modify: `scripts/creature_art.gd` (`_draw_snuffer`, a `var aim: Vector2`), `scripts/snuffer.gd` (set `art.art.pose` and `art.art.aim`), `tests/test_art_wiring.gd`, `tests/playtest.gd`
- Test: both

**Interfaces:**
- Produces: `CreatureArt.aim: Vector2` (offset in art pixels from the creature's origin to the light it is draining; `Vector2.ZERO` means none). `Snuffer` sets, each frame it drains (`to_target.length() <= DRAIN_RANGE`): `art.art.pose = 1.0` and `art.art.aim = to_target` clamped to a length of 40; otherwise `pose = 0.0`, `aim = Vector2.ZERO`. `_draw_snuffer()` keeps the bell-and-tendrils jellyfish (translucent grey-blue); the magenta core (`Color8(214, 66, 204)`) dim at `pose` 0 and bright at `pose` 1, pulsing with `t`; when `aim` is not zero a thin pale line runs from the bell toward `aim` with a slight sag.

- [ ] **Step 1: Write failing tests.** Unit: `test_the_snuffer_lights_its_core_while_it_drains`: a Snuffer placed beside a `MineLight` (reuse the wiring test's setup for `test_burrower_and_snuffer_mirror_toward_their_target`), run physics until in `DRAIN_RANGE`: `art.art.pose == 1.0` and `art.art.aim != Vector2.ZERO`; moved away: `0.0` and `ZERO`. `test_the_snuffer_does_not_drain_faster_or_slower` is the existing drain tests unchanged. Playtest: `the Snuffer draws inside its cell` (pose 0, pose 1 with aim `(30, 5)`); `the draining Snuffer is brighter at the core` (the mean brightness of the magenta pixels at pose 1 is above pose 0); `the tether appears only with an aim` (pale pixels along the line from the bell toward `aim` at pose 1 with aim, none with aim zero).
- [ ] **Step 2:** Run. Expected: FAIL.
- [ ] **Step 3: Implement** per the Interfaces; iterate with `art_lineup.gd -- kind=snuffer`.
- [ ] **Step 4:** Run everything. Expected: all pass. Attach the sheet.
- [ ] **Step 5:** `ROADMAP.md` (M94); commit `Art: the Snuffer`; open the Phase 3 PR.

---

## Phase 4 (one PR): the Nest

### Task 6: The Nest, alive before you flare it

**Files:**
- Modify: `scripts/gear_art.gd` (`_draw_nest`), `scripts/nest.gd` (drive `pose` from `burn / BURN_SECONDS`), `tests/test_art_wiring.gd`, `tests/playtest.gd`
- Test: both

**Interfaces:**
- Produces: `Nest` sets `art.art.pose = clampf(burn / BURN_SECONDS, 0.0, 1.0)` each frame while not destroyed, and `1.0` when destroyed (the existing burnt-out look, `pose > 0.5` today, is kept as the charred state). `_draw_nest()` draws a low heap of rounded pale sacs (bruised cream and grey) with faint dark veins and a dull amber glow inside (`Color8(170, 120, 50)`), breathing slowly from `t`; as `pose` rises toward 0.5 the sacs shrivel and darken.

- [ ] **Step 1: Write failing tests.** Unit: `test_the_nest_shrivels_as_it_burns`: a Nest with `burn = BURN_SECONDS * 0.5` after a frame: `art.art.pose` is about 0.5 (within 0.05); destroyed: `1.0`. Existing nest tests pass unchanged. Playtest: `the Nest draws inside its cell` at pose 0, 0.5 and 1; `the nest is low` (opaque bounding box wider than tall); `a burning nest is darker` (mean brightness at pose 0.5 below pose 0).
- [ ] **Step 2:** Run. Expected: FAIL.
- [ ] **Step 3: Implement** per the Interfaces; iterate with the harness (extend it to take `kind=nest` through `GearArt`).
- [ ] **Step 4:** Run everything. Expected: all pass. Attach the sheet.
- [ ] **Step 5:** `ROADMAP.md` (M95); commit `Art: the Nest`; open the Phase 4 PR.

---

## Self-review

- **Spec coverage:** style rules (Global Constraints and each task's palette); Stalker eyes, variants, strike (Task 3); Burrower (Task 4); Snuffer drain tether, with the `pose`/`aim` interface the spec called for (Task 5); Nest (Task 6); glow mechanism and harness (Tasks 1 and 2); testing list (structure in unit tests, pixels in the playtest, deliberately); out-of-scope items appear in no task.
- **Deviation from the spec:** the spec's "unit tests" for pixel properties are playtest scenarios here, because headless has no renderer.
- **Type consistency:** `glow`, `glow_art`, `glow_viewport`, `glow_sprite`, `glow_only`, `variant`, `aim`, `deep` are defined once (Tasks 1, 3, 5) and used under those names after.
- **Proportion:** six tasks, test names with assertions and signatures, no drawing code: the pictures decide the drawing, and the harness makes each iteration cheap.

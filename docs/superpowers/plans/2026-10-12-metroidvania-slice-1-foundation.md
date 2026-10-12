# Metroidvania Slice, Plan 1 of 3: Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A new Godot repository where a player walks and jumps in gravity, drifts, grabs, kicks and fires in zero-g, crosses gravity boundaries with momentum intact, swings at switches that flip the world's state, and is pushed by vents, all under a headless test suite run by CI.

**Architecture:** World state is a static class (`WorldState`) that rooms poll by version number; a `Compartment` area decides gravity and shows or hides its state-tagged children. The player is one `CharacterBody2D` with two movement mode objects swapped by its compartment's gravity. Everything is testable headlessly with scripted input against rooms built in code.

**Tech Stack:** Godot 4.5 stable, GDScript, GL Compatibility renderer. Test harness ported from Down Mine (`tests/run_tests.gd`, `TestCase`, `TestHooks`, `ErrorLogger`). GitHub Actions.

**Spec:** `docs/superpowers/specs/2026-10-12-metroidvania-slice-design.md` (copied into the new repository by Task 1).

## Starting in the new repository

Agreed with the author on 2026-10-12, for the session that executes this plan:

- The new repository starts empty. Task 1 creates everything; copy the spec and the plans from Down Mine's `docs/superpowers/` first, so the paths in **Spec** above resolve.
- Execution method: native (one implementer for every task, one fresh whole-branch review at the end). The tasks share the player's two modes and the compartment contract, so one implementer holding all of them avoids interface drift.
- Before Task 1, install a Godot 4.5 binary on the PATH as `godot`, the way `.github/workflows/tests.yml` does in CI. A cloud session has none by default; a SessionStart hook or setup script that downloads it is the first thing to add.
- Down Mine is the reference for conventions: its `tests/` harness is ported verbatim where this plan says so, and its `README.md` and `ROADMAP.md` are the model for the new ones.

## The three plans

The spec is one slice but three deliverables, each working on its own:

1. **Foundation (this plan).** Repository, harness, world state, compartments, switches, vents, the full movement kit, the swing against switches and hittables, sound.
2. **Combat.** Health and damage, the fire projectile, hit stop, the three enemies, the Warden, airlock checkpoints, enemy respawn.
3. **The slice.** The thirteen rooms, `WorldGraph` and the reachability test, room loading, the map, the exit, the playtest runner, the web export.

## Global Constraints

- Godot `4.5` stable, GDScript only. `config/features=PackedStringArray("4.5")`.
- Renderer `gl_compatibility` for desktop and mobile. Viewport `1152` by `648`, stretch mode `canvas_items`, aspect `expand`.
- No audio files, no texture files. Sound is synthesized in code. Art is `Polygon2D`.
- Test command, locally and in CI: `godot --headless --import` once, then `godot --headless --fixed-fps 60 -s tests/run_tests.gd`. Exit code 0 means pass. A Godot 4.5 binary named `godot` must be on the PATH.
- Every `static var` in `scripts/` is either reset by `TestHooks.reset()` or named in `TestHooks.EXPLAINED`; a test enforces it.
- Group names come from constants in `Groups`; a test fails on string literals.
- Commit the `.uid` files Godot generates beside scripts.
- Starting values from the spec: player health 5 (Plan 2), fire cooldown 0.5 s, kick speed 1.4 times run speed, recoil speed 0.8 times run speed, hit stop 3 frames (Plan 2), invulnerability 0.6 s (Plan 2), vent force in zero-g crosses the Hangar in about 2 s, vent force in gravity a tenth of that.
- Camera never rotates. Gravity, where present, is `Vector2.DOWN`.
- Commit messages are plain, no model names, no emoji.

## Review Focus

Inputs the spec implies but no feature test would exercise. Each has a pinned test in the task named.

1. **Player outside every compartment** (fell through a gap into space): must be zero-g, not a null-reference crash. Task 7.
2. **Overlapping compartments at a boundary**: when the player leaves one while still inside another, the remaining one rules; no flicker to space. Task 7.
3. **Missing or corrupt save file**: `WorldState.load()` returns false and leaves the start state intact. Task 2.
4. **Fire held down**: exactly one recoil per cooldown, never one per frame. Task 6.
5. **A vent over a body with no `velocity`** (a `StaticBody2D` prop): skipped without a script error. Task 8.

---

### Task 1: New repository, project settings, test harness, CI

**Files:**
- Create: `project.godot`, `.gitignore`, `README.md`, `ROADMAP.md`
- Create: `.github/workflows/tests.yml`
- Create: `tests/run_tests.gd`, `tests/test_case.gd`, `tests/test_hooks.gd`, `tests/error_logger.gd`, `tests/test_hygiene.gd`
- Create: `scripts/groups.gd`
- Create: `docs/superpowers/specs/2026-10-12-metroidvania-slice-design.md` (copy from Down Mine), `docs/superpowers/plans/` (this plan and its successors)

**Interfaces:**
- Produces: `TestCase` with `assert_eq(actual, expected, message)`, `assert_true(condition, message)`, `add(node) -> Node`, `physics_frames(count)`, `tree: SceneTree`, `const TEST_SAVE_PATH := "user://test_save.cfg"`. `TestHooks.reset(save_path: String = "")`, `TestHooks.RESET: Array`, `TestHooks.EXPLAINED: Dictionary`. `Groups.HITTABLE := "hittable"`. Input actions `move_left`, `move_right`, `move_up`, `move_down`, `jump`, `swing`, `fire`, `grab`.

- [ ] **Step 1: Initialise the repository and copy the harness**

In an empty directory: `git init -b main`. Copy from Down Mine, unchanged except where noted: `tests/run_tests.gd` (remove the `TestCase.free_shared_mines()` line and the `Sfx.stop_all()` line until Task 10 adds `Sfx`), `tests/error_logger.gd` (unchanged), `tests/test_case.gd` (remove `_shared_mines`, `shared_mine`, `free_shared_mines`; keep the rest). Copy the spec into `docs/superpowers/specs/`. `.gitignore`: `.godot/`, `build/`, `playtest_out/`, `export.cfg`.

- [ ] **Step 2: Write `project.godot`**

Application name `Drift`, main scene `res://scenes/TestRoom.tscn` (created in Task 11; until then the engine warns and tests still run), features `4.5`. Display and rendering per Global Constraints. Clear color `Color(0.02, 0.02, 0.03, 1)`. Input map, each action with keyboard and joypad events:

| Action | Keys | Joypad |
| --- | --- | --- |
| `move_left` | A, Left | left stick x negative, d-pad left |
| `move_right` | D, Right | left stick x positive, d-pad right |
| `move_up` | W, Up | left stick y negative, d-pad up |
| `move_down` | S, Down | left stick y positive, d-pad down |
| `jump` | Space, Z | button 0 (A) |
| `swing` | X, J | button 2 (X) |
| `fire` | C, K | button 1 (B) |
| `grab` | Shift, L | button 10 (right shoulder) |

- [ ] **Step 3: Write `scripts/groups.gd` and `tests/test_hooks.gd`**

```gdscript
class_name Groups
## Group names, so a typo is a compile error and the hygiene test can check them.
const HITTABLE := "hittable"
```

`TestHooks` as in Down Mine with `RESET: Array = []` and `EXPLAINED: Dictionary = {}` and `static func reset(save_path: String = "") -> void` whose body is empty for now. Task 2 fills it.

- [ ] **Step 4: Write `tests/test_hygiene.gd`**

Port from Down Mine: `test_every_static_variable_is_reset_or_explained`, `test_groups_are_named_by_constants_not_strings`, and the `_static_vars()` helper, unchanged. Drop every other Down Mine hygiene test.

- [ ] **Step 5: Write `.github/workflows/tests.yml`**

Down Mine's `tests.yml` with only the `test` job (no `playtest` job yet), `GODOT_VERSION: "4.5"`, on `pull_request` and `push` to `main`.

- [ ] **Step 6: Run the suite**

Run: `godot --headless --import && godot --headless --fixed-fps 60 -s tests/run_tests.gd`
Expected: `2 passed, 0 failed`, exit code 0.

- [ ] **Step 7: Write `README.md` and `ROADMAP.md`**

README: one paragraph (the spec's "What the game is known for" first paragraph), a controls table from Step 2, and the test command. ROADMAP: the three plans above as three milestones, M1 to M3, each one line, with this plan's path.

- [ ] **Step 8: Commit**

```bash
git add -A
git commit -m "New project: settings, input map, test harness, CI"
```

---

### Task 2: WorldState

**Files:**
- Create: `scripts/world_state.gd`
- Modify: `tests/test_hooks.gd`
- Test: `tests/test_world_state.gd`

**Interfaces:**
- Produces:
  ```gdscript
  class_name WorldState extends RefCounted
  const SAVE_PATH := "user://save.cfg"
  static var ring_on: bool = true
  static var vents_open: bool = false
  static var boss_down: bool = false
  static var checkpoint: String = ""        # room name of the last airlock rested at; "" means the Dock start
  static var visited: PackedStringArray = []
  static var version: int = 0               # bumps on every change; rooms poll it
  static var path_override: String = ""     # tests save here instead of SAVE_PATH
  static func reset() -> void               # start state, version 0
  static func set_ring(on: bool) -> void
  static func set_vents(open: bool) -> void
  static func flip(switch_name: String) -> void        # "ring" or "vents"
  static func switch_state(switch_name: String) -> bool
  static func set_boss_down() -> void
  static func set_checkpoint(room: String) -> void
  static func visit(room: String) -> void   # no duplicates
  static func save() -> void
  static func load() -> bool                # false and unchanged state when no file or a bad file
  ```
  Every setter bumps `version` only when the value actually changes.

- [ ] **Step 1: Write the failing tests**

```gdscript
extends TestCase

func test_start_state() -> void:
	WorldState.reset()
	assert_true(WorldState.ring_on, "ring on")
	assert_true(not WorldState.vents_open, "vents closed")
	assert_true(not WorldState.boss_down, "boss alive")
	assert_eq(WorldState.checkpoint, "", "no checkpoint")
	assert_eq(WorldState.visited.size(), 0, "nothing visited")
	assert_eq(WorldState.version, 0, "version 0")

func test_setters_bump_version_only_on_change() -> void:
	WorldState.set_ring(true)
	assert_eq(WorldState.version, 0, "same value: no bump")
	WorldState.set_ring(false)
	assert_eq(WorldState.version, 1, "changed: bump")
	WorldState.flip("vents")
	assert_true(WorldState.vents_open, "flip opens")
	assert_eq(WorldState.switch_state("vents"), true, "switch_state reads it")
	assert_eq(WorldState.switch_state("ring"), false, "ring is off")
	WorldState.visit("Dock")
	WorldState.visit("Dock")
	assert_eq(WorldState.visited.size(), 1, "visit is idempotent")
	assert_eq(WorldState.version, 3, "ring, vents, one visit")

func test_save_and_load_round_trip() -> void:
	WorldState.set_ring(false)
	WorldState.set_vents(true)
	WorldState.set_boss_down()
	WorldState.set_checkpoint("Ring Deck")
	WorldState.visit("Dock")
	WorldState.visit("Breach")
	WorldState.save()
	WorldState.reset()
	assert_true(WorldState.load(), "a file was loaded")
	assert_true(not WorldState.ring_on and WorldState.vents_open and WorldState.boss_down, "switches and boss")
	assert_eq(WorldState.checkpoint, "Ring Deck", "checkpoint")
	assert_eq(Array(WorldState.visited), ["Dock", "Breach"], "visited, in order")

func test_load_with_no_file_or_a_bad_file_keeps_the_start_state() -> void:
	assert_true(not WorldState.load(), "no file: false")
	assert_true(WorldState.ring_on, "state untouched")
	var f := FileAccess.open(WorldState.path_override, FileAccess.WRITE)
	f.store_string("not a config file [[[")
	f.close()
	assert_true(not WorldState.load(), "bad file: false")
	assert_true(WorldState.ring_on and not WorldState.vents_open, "state untouched")
```

- [ ] **Step 2: Run to verify failure**

Run: `godot --headless --fixed-fps 60 -s tests/run_tests.gd`
Expected: `test_world_state.gd does not compile` or script errors naming `WorldState`.

- [ ] **Step 3: Implement `scripts/world_state.gd`**

Persistence with `ConfigFile`, section `"world"`, keys matching the variable names. `save()` writes to `path_override` if it is non-empty, else `SAVE_PATH`. `load()` returns false if `ConfigFile.load()` returns anything but `OK`.

- [ ] **Step 4: Wire `TestHooks`**

`RESET` lists `"WorldState.ring_on"`, `"WorldState.vents_open"`, `"WorldState.boss_down"`, `"WorldState.checkpoint"`, `"WorldState.visited"`, `"WorldState.version"`, `"WorldState.path_override"`. `reset(save_path)` calls `WorldState.reset()` then sets `WorldState.path_override = save_path`.

- [ ] **Step 5: Run to verify pass**

Expected: all tests `ok`, including the hygiene static-variable test.

- [ ] **Step 6: Commit**

```bash
git add scripts/world_state.gd scripts/world_state.gd.uid tests/test_world_state.gd tests/test_world_state.gd.uid tests/test_hooks.gd
git commit -m "WorldState: switches, boss flag, checkpoint, visited rooms, save and load"
```

---

### Task 3: Compartment

**Files:**
- Create: `scripts/compartment.gd`, `scenes/Compartment.tscn`
- Test: `tests/test_compartment.gd`

**Interfaces:**
- Consumes: `WorldState.ring_on`, `WorldState.vents_open`, `WorldState.version`.
- Produces:
  ```gdscript
  class_name Compartment extends Area2D
  @export var plates_live: bool = true
  @export var room_name: String = ""
  func has_gravity() -> bool            # plates_live and WorldState.ring_on
  func apply() -> void                  # show/hide state children now (also called when version changes)
  ```
  State children by name, direct children of the Compartment: `RingOn`, `RingOff`, `VentsOpen`, `VentsClosed`. A container is active when its state holds. Inactive means `visible = false`, `process_mode = PROCESS_MODE_DISABLED`, and every `CollisionShape2D` and `CollisionPolygon2D` beneath it has `disabled = true`; active reverses all three. Bodies that enter get `enter_compartment(self)` if they have that method, bodies that leave get `exit_compartment(self)`.
  `scenes/Compartment.tscn`: `Compartment` root with a `CollisionShape2D` child named `Bounds` holding a `RectangleShape2D`; `monitoring` on, `monitorable` off, collision layer 0, mask 1 (bodies).

- [ ] **Step 1: Write the failing tests**

```gdscript
extends TestCase

func _compartment(live: bool) -> Compartment:
	var c: Compartment = load("res://scenes/Compartment.tscn").instantiate()
	c.plates_live = live
	(c.get_node("Bounds") as CollisionShape2D).shape.size = Vector2(800, 600)
	return c

func _with_state_children(c: Compartment) -> void:
	for state_name in ["RingOn", "RingOff", "VentsOpen", "VentsClosed"]:
		var holder := Node2D.new()
		holder.name = state_name
		var body := StaticBody2D.new()
		var shape := CollisionShape2D.new()
		shape.shape = RectangleShape2D.new()
		body.add_child(shape)
		holder.add_child(body)
		c.add_child(holder)

func test_gravity_follows_plates_and_the_ring() -> void:
	var live := add(_compartment(true)) as Compartment
	var dead := add(_compartment(false)) as Compartment
	assert_true(live.has_gravity(), "live plates, ring on")
	assert_true(not dead.has_gravity(), "dead plates never have gravity")
	WorldState.set_ring(false)
	assert_true(not live.has_gravity(), "ring off: no gravity anywhere")

func test_state_children_follow_the_switches() -> void:
	var c := _compartment(true)
	_with_state_children(c)
	add(c)
	await physics_frames(1)
	var shape_of := func(n: String) -> CollisionShape2D: return c.get_node(n + "/StaticBody2D/CollisionShape2D")
	assert_true(c.get_node("RingOn").visible and not c.get_node("RingOff").visible, "ring on at start")
	assert_true(shape_of.call("RingOff").disabled, "RingOff collision disabled")
	assert_true(not c.get_node("VentsOpen").visible and c.get_node("VentsClosed").visible, "vents closed at start")
	WorldState.set_ring(false)
	WorldState.set_vents(true)
	await physics_frames(1)
	assert_true(not c.get_node("RingOn").visible and c.get_node("RingOff").visible, "ring flipped")
	assert_true(shape_of.call("RingOn").disabled and not shape_of.call("RingOff").disabled, "collision follows")
	assert_true(c.get_node("VentsOpen").visible and not c.get_node("VentsClosed").visible, "vents flipped")
	assert_eq(c.get_node("RingOn").process_mode, Node.PROCESS_MODE_DISABLED, "inactive children do not process")

func test_a_compartment_without_state_children_is_fine() -> void:
	var c := add(_compartment(true)) as Compartment
	WorldState.set_ring(false)
	await physics_frames(1)
	assert_true(not c.has_gravity(), "no children, no error")
```

- [ ] **Step 2: Run to verify failure**

Expected: `test_compartment.gd does not compile` (no `Compartment` class, no scene).

- [ ] **Step 3: Implement `scripts/compartment.gd` and build `scenes/Compartment.tscn`**

Poll in `_physics_process`: if `WorldState.version != _seen_version`, call `apply()`. `apply()` also runs in `_ready()`. Connect `body_entered` and `body_exited` in `_ready()` to methods that call `enter_compartment` and `exit_compartment` on the body when `has_method` says so.

- [ ] **Step 4: Run to verify pass**

Expected: all `ok`.

- [ ] **Step 5: Commit**

```bash
git add scripts/compartment.gd scripts/compartment.gd.uid scenes/Compartment.tscn tests/test_compartment.gd tests/test_compartment.gd.uid
git commit -m "Compartment: gravity from plates and the ring, state children shown and hidden"
```

---

### Task 4: Switch

**Files:**
- Create: `scripts/switch.gd`, `scenes/Switch.tscn`
- Test: `tests/test_switch.gd`

**Interfaces:**
- Consumes: `WorldState.flip`, `WorldState.switch_state`, `Groups.HITTABLE`.
- Produces:
  ```gdscript
  class_name Switch extends StaticBody2D
  @export var switch_name: String = "ring"   # "ring" or "vents"
  func hit(from: Node2D, direction: Vector2) -> void   # flips the switch; ignores a second hit within 0.3 s
  const REHIT_DELAY := 0.3
  ```
  In group `Groups.HITTABLE`. `scenes/Switch.tscn`: root `Switch` with a `CollisionShape2D` (`RectangleShape2D` 24 by 40) on collision layer 2 (hittables), mask 0, and a `Polygon2D` panel drawn in two colours by state (bright when the switch is on, dim when off) refreshed from `WorldState.switch_state` each physics frame.

- [ ] **Step 1: Write the failing tests**

```gdscript
extends TestCase

func test_a_hit_flips_its_switch_once_per_swing() -> void:
	var s: Switch = add(load("res://scenes/Switch.tscn").instantiate())
	s.switch_name = "vents"
	assert_true(s.is_in_group(Groups.HITTABLE), "hittable")
	s.hit(null, Vector2.RIGHT)
	assert_true(WorldState.vents_open, "opened")
	s.hit(null, Vector2.RIGHT)
	assert_true(WorldState.vents_open, "a second hit inside the delay is ignored")
	await physics_frames(int(Switch.REHIT_DELAY * 60) + 2)
	s.hit(null, Vector2.RIGHT)
	assert_true(not WorldState.vents_open, "closed again")

func test_the_ring_switch_flips_the_ring() -> void:
	var s: Switch = add(load("res://scenes/Switch.tscn").instantiate())
	s.hit(null, Vector2.LEFT)
	assert_true(not WorldState.ring_on, "ring off")
```

- [ ] **Step 2: Run to verify failure**

Expected: does not compile.

- [ ] **Step 3: Implement `scripts/switch.gd` and build `scenes/Switch.tscn`**

- [ ] **Step 4: Run to verify pass**

- [ ] **Step 5: Commit**

```bash
git add scripts/switch.gd scripts/switch.gd.uid scenes/Switch.tscn tests/test_switch.gd tests/test_switch.gd.uid
git commit -m "Switch: a hittable panel that flips one WorldState switch"
```

---

### Task 5: Player in gravity: run and jump

**Files:**
- Create: `scripts/player.gd`, `scripts/player_input.gd`, `scripts/gravity_mode.gd`, `scenes/Player.tscn`
- Modify: `tests/test_case.gd` (room and player helpers)
- Test: `tests/test_gravity_mode.gd`

**Interfaces:**
- Consumes: `Compartment.has_gravity()`, `enter_compartment`/`exit_compartment` calls.
- Produces:
  ```gdscript
  class_name PlayerInput extends RefCounted
  var aim: Vector2 = Vector2.ZERO     # one of 8 unit directions or ZERO, from move_* actions
  var jump_pressed: bool = false      # edge
  var jump_held: bool = false
  var swing_pressed: bool = false     # edge
  var fire_pressed: bool = false      # edge
  var grab_held: bool = false
  static func poll() -> PlayerInput   # from the input actions
  ```
  ```gdscript
  class_name Player extends CharacterBody2D
  const RUN_SPEED := 220.0
  const RUN_ACCEL := 2400.0           # px/s^2 toward the target run speed, also the stop
  const GRAVITY := 1400.0
  const JUMP_SPEED := 520.0
  const JUMP_CUT_SPEED := 150.0       # releasing jump while rising caps upward speed here
  const KICK_SPEED := RUN_SPEED * 1.4
  const RECOIL_SPEED := RUN_SPEED * 0.8
  const FIRE_COOLDOWN := 0.5
  signal fired(direction: Vector2)    # Plan 2 spawns the projectile
  var input_override: PlayerInput = null   # tests set this; null polls real input
  var compartments: Array[Compartment] = []  # every compartment currently overlapping, last entered last
  var facing: int = 1                 # +1 right, -1 left
  var grabbed: bool = false
  var grab_normal: Vector2 = Vector2.ZERO
  var fire_cooldown: float = 0.0
  func in_zero_g() -> bool            # true when compartments is empty or the last one has no gravity
  func enter_compartment(c: Compartment) -> void
  func exit_compartment(c: Compartment) -> void
  func fire(direction: Vector2) -> bool   # false while cooling down; emits fired, starts the cooldown
  ```
  ```gdscript
  class_name GravityMode extends RefCounted
  func step(p: Player, input: PlayerInput, delta: float) -> void
  ```
  `scenes/Player.tscn`: `Player` root on collision layer 1, mask 1, with `CollisionShape2D` (`CapsuleShape2D` radius 10, height 44) and a `Polygon2D` body in the player colour. Rig and cloth come in Plan 2.

  `TestCase` helpers:
  ```gdscript
  ## A closed box of static walls (thickness 32) with a Compartment covering it. Keys: "room", "compartment", "floor_y".
  func make_room(plates_live: bool, size: Vector2 = Vector2(2000, 1200), origin: Vector2 = Vector2.ZERO) -> Dictionary
  func spawn_player(at: Vector2) -> Player     # adds Player.tscn with an empty input_override
  func frame_count(seconds: float) -> int      # ceil(seconds * 60)
  ```
  `make_room` builds a `StaticBody2D` named `Walls` with four `CollisionShape2D` rectangles named `Floor`, `Ceiling`, `Left` and `Right` just outside the box, and a `Compartment` named `Compartment` whose `Bounds` is the inside of the box; both go under one `Node2D` (the `room`). `size` is the inside of the box and `origin` its centre. `floor_y` is the floor's top surface in world space. Tests remove named walls to join rooms.

- [ ] **Step 1: Write the failing tests**

```gdscript
extends TestCase

func test_run_reaches_run_speed_and_stops() -> void:
	var r := make_room(true)
	var p := spawn_player(Vector2(0, r.floor_y - 30))
	p.input_override.aim = Vector2.RIGHT
	await physics_frames(frame_count(0.5))
	assert_true(absf(p.velocity.x - Player.RUN_SPEED) < 1.0, "at run speed, got %f" % p.velocity.x)
	assert_eq(p.facing, 1, "facing right")
	p.input_override.aim = Vector2.ZERO
	await physics_frames(frame_count(0.5))
	assert_true(absf(p.velocity.x) < 1.0, "stopped")
	assert_true(p.is_on_floor(), "stays on the floor")

func test_full_jump_is_higher_than_a_short_hop() -> void:
	var r := make_room(true)
	var p := spawn_player(Vector2(0, r.floor_y - 30))
	await physics_frames(2)
	var start_y := p.global_position.y
	p.input_override.jump_pressed = true
	p.input_override.jump_held = true
	await physics_frames(1)
	p.input_override.jump_pressed = false
	assert_true(absf(p.velocity.y + Player.JUMP_SPEED) < 1.0, "leaves at jump speed")
	var full_top := start_y
	for i in range(frame_count(1.0)):
		await physics_frames(1)
		full_top = minf(full_top, p.global_position.y)
	assert_true(p.is_on_floor(), "landed")
	p.input_override.jump_pressed = true
	p.input_override.jump_held = true
	await physics_frames(1)
	p.input_override.jump_pressed = false
	await physics_frames(3)
	p.input_override.jump_held = false
	await physics_frames(1)
	assert_true(p.velocity.y >= -Player.JUMP_CUT_SPEED - 1.0, "release caps the rise")
	var hop_top := start_y
	for i in range(frame_count(1.0)):
		await physics_frames(1)
		hop_top = minf(hop_top, p.global_position.y)
	assert_true(start_y - full_top > 80.0, "full jump clears 80 px, got %f" % (start_y - full_top))
	assert_true(start_y - hop_top < (start_y - full_top) * 0.6, "short hop is well under the full jump")

func test_jump_only_from_the_floor() -> void:
	var r := make_room(true)
	var p := spawn_player(Vector2(0, r.floor_y - 300))
	p.input_override.jump_pressed = true
	p.input_override.jump_held = true
	await physics_frames(1)
	assert_true(p.velocity.y >= 0.0, "no jump in the air")

func test_fire_in_gravity_has_no_recoil_and_cools_down() -> void:
	var r := make_room(true)
	var p := spawn_player(Vector2(0, r.floor_y - 30))
	await physics_frames(2)
	var shots := []
	p.fired.connect(func(d): shots.append(d))
	p.input_override.fire_pressed = true
	await physics_frames(frame_count(0.25))
	assert_eq(shots.size(), 1, "one shot in a quarter second of holding fire")
	assert_eq(shots[0], Vector2.RIGHT, "fires the way it faces when aim is zero")
	assert_true(absf(p.velocity.x) < 1.0, "no recoil in gravity")
```

- [ ] **Step 2: Run to verify failure**

Expected: does not compile.

- [ ] **Step 3: Implement `PlayerInput`, `Player`, `GravityMode`, the scene and the `TestCase` helpers**

`Player._physics_process(delta)`: take `input_override` or `PlayerInput.poll()`; tick `fire_cooldown` down; pick `GravityMode` when not `in_zero_g()` (Task 6 adds the other); call `step`. `GravityMode.step`: horizontal velocity moves toward `aim.x * RUN_SPEED` by `RUN_ACCEL * delta`; `facing` follows a non-zero `aim.x`; add `GRAVITY * delta` to `velocity.y` when not on the floor; `jump_pressed` on the floor sets `velocity.y = -JUMP_SPEED`; rising with `jump_held` false caps `velocity.y` at `-JUMP_CUT_SPEED`; `fire_pressed` calls `p.fire(aim if aim != ZERO else Vector2(facing, 0))`; then `move_and_slide()`. `up_direction` is `Vector2.UP`.

- [ ] **Step 4: Run to verify pass**

- [ ] **Step 5: Commit**

```bash
git add scripts/player.gd scripts/player_input.gd scripts/gravity_mode.gd scripts/*.uid scenes/Player.tscn tests/test_case.gd tests/test_gravity_mode.gd tests/test_gravity_mode.gd.uid
git commit -m "Player in gravity: run, variable jump, fire without recoil"
```

---

### Task 6: Player in zero-g: drift, grab, kick, fire recoil

**Files:**
- Create: `scripts/zero_g_mode.gd`
- Modify: `scripts/player.gd` (mode selection)
- Test: `tests/test_zero_g_mode.gd`

**Interfaces:**
- Consumes: `Player` fields from Task 5.
- Produces:
  ```gdscript
  class_name ZeroGMode extends RefCounted
  func step(p: Player, input: PlayerInput, delta: float) -> void
  ```
  Rules: no gravity, no drag. While `grabbed` and `grab_held`, velocity is zero and the body does not move. `grab_held` with a slide collision this frame latches `grabbed` and stores the collision normal in `grab_normal`. Releasing grab clears `grabbed`, velocity stays zero. `jump_pressed` while `grabbed`: velocity becomes `(aim if aim != ZERO else grab_normal) * KICK_SPEED`, `grabbed` false. `jump_pressed` while not grabbed does nothing. `fire_pressed` with cooldown ready: `p.fire(dir)` where `dir` is `aim` or facing; on success `velocity += -dir * RECOIL_SPEED` and `grabbed` becomes false. `facing` follows a non-zero `aim.x`.

- [ ] **Step 1: Write the failing tests**

```gdscript
extends TestCase

func test_drift_never_decays_and_nothing_falls() -> void:
	var r := make_room(false)
	var p := spawn_player(Vector2(-400, 0))
	p.velocity = Vector2(100, -40)
	await physics_frames(frame_count(1.0))
	assert_true(p.velocity.is_equal_approx(Vector2(100, -40)), "velocity unchanged, got %s" % p.velocity)
	p.input_override.aim = Vector2.RIGHT
	await physics_frames(frame_count(0.5))
	assert_true(p.velocity.is_equal_approx(Vector2(100, -40)), "aim alone does not steer")

func test_hitting_a_wall_stops_you() -> void:
	var r := make_room(false)
	var p := spawn_player(Vector2(900, 0))
	p.velocity = Vector2(400, 0)
	await physics_frames(frame_count(1.0))
	assert_true(absf(p.velocity.x) < 1.0, "stopped by the right wall")
	assert_true(not p.grabbed, "not grabbed without the button")

func test_grab_holds_and_release_leaves_you_at_rest() -> void:
	var r := make_room(false)
	var p := spawn_player(Vector2(900, 0))
	p.velocity = Vector2(400, 300)
	p.input_override.grab_held = true
	await physics_frames(frame_count(1.0))
	assert_true(p.grabbed, "grabbed the wall")
	assert_eq(p.velocity, Vector2.ZERO, "dead stop")
	assert_true(p.grab_normal.is_equal_approx(Vector2.LEFT), "normal points back into the room")
	var held_at := p.global_position
	await physics_frames(10)
	assert_eq(p.global_position, held_at, "does not slide while held")
	p.input_override.grab_held = false
	await physics_frames(10)
	assert_true(not p.grabbed and p.velocity == Vector2.ZERO, "released, at rest")

func test_kick_from_a_grab_in_the_aimed_direction_or_along_the_normal() -> void:
	var r := make_room(false)
	var p := spawn_player(Vector2(900, 0))
	p.velocity = Vector2(400, 0)
	p.input_override.grab_held = true
	await physics_frames(frame_count(1.0))
	p.input_override.aim = Vector2(-1, -1).normalized()
	p.input_override.jump_pressed = true
	await physics_frames(1)
	p.input_override.jump_pressed = false
	assert_true(p.velocity.is_equal_approx(Vector2(-1, -1).normalized() * Player.KICK_SPEED), "kick along the aim")
	assert_true(not p.grabbed, "let go")
	p.velocity = Vector2(400, 0)
	p.input_override.aim = Vector2.ZERO
	await physics_frames(frame_count(1.0))
	p.input_override.jump_pressed = true
	await physics_frames(1)
	p.input_override.jump_pressed = false
	assert_true(p.velocity.is_equal_approx(Vector2.LEFT * Player.KICK_SPEED), "no aim: kick along the normal")

func test_jump_in_open_space_does_nothing() -> void:
	var r := make_room(false)
	var p := spawn_player(Vector2(0, 0))
	p.input_override.jump_pressed = true
	await physics_frames(1)
	assert_eq(p.velocity, Vector2.ZERO, "no thruster on jump")

func test_fire_recoils_once_per_cooldown() -> void:
	var r := make_room(false)
	var p := spawn_player(Vector2(0, 0))
	p.input_override.aim = Vector2.UP
	p.input_override.fire_pressed = true
	await physics_frames(frame_count(Player.FIRE_COOLDOWN) - 2)
	assert_true(p.velocity.is_equal_approx(Vector2.DOWN * Player.RECOIL_SPEED), "one recoil, got %s" % p.velocity)
	await physics_frames(4)
	assert_true(p.velocity.is_equal_approx(Vector2.DOWN * Player.RECOIL_SPEED * 2), "second recoil after the cooldown")

func test_fire_breaks_a_grab() -> void:
	var r := make_room(false)
	var p := spawn_player(Vector2(900, 0))
	p.velocity = Vector2(400, 0)
	p.input_override.grab_held = true
	await physics_frames(frame_count(1.0))
	p.input_override.aim = Vector2.RIGHT
	p.input_override.fire_pressed = true
	await physics_frames(1)
	assert_true(not p.grabbed, "firing lets go")
	assert_true(p.velocity.is_equal_approx(Vector2.LEFT * Player.RECOIL_SPEED), "pushed off the wall")
```

- [ ] **Step 2: Run to verify failure**

Expected: does not compile.

- [ ] **Step 3: Implement `ZeroGMode` and select it in `Player` when `in_zero_g()`**

Grab latch uses `get_slide_collision_count()` after `move_and_slide()` and `get_slide_collision(0).get_normal()`. While held and grabbed, skip `move_and_slide()`.

- [ ] **Step 4: Run to verify pass**

- [ ] **Step 5: Commit**

```bash
git add scripts/zero_g_mode.gd scripts/zero_g_mode.gd.uid scripts/player.gd tests/test_zero_g_mode.gd tests/test_zero_g_mode.gd.uid
git commit -m "Player in zero-g: drift, grab, kick, fire recoil"
```

---

### Task 7: Gravity boundaries and compartment tracking

**Files:**
- Modify: `scripts/player.gd`
- Test: `tests/test_boundary.gd`

**Interfaces:**
- Consumes: `Compartment` enter and exit calls, `Player.compartments`, `Player.in_zero_g()`.
- Produces: the rule. `enter_compartment` appends (no duplicates) and `exit_compartment` removes; `in_zero_g()` reads the last element; empty means space, zero-g. Velocity is never touched by a mode change.

- [ ] **Step 1: Write the failing tests**

```gdscript
extends TestCase

## Two rooms side by side sharing an open boundary at x = 0: left has live plates and a floor, right has dead plates.
func _two_rooms() -> Dictionary:
	var left := make_room(true, Vector2(1000, 600), Vector2(-500, 0))
	var right := make_room(false, Vector2(1000, 600), Vector2(500, 0))
	# Open the shared wall: drop the left room's right wall and the right room's left wall.
	left.room.get_node("Walls/Right").queue_free()
	right.room.get_node("Walls/Left").queue_free()
	right.room.get_node("Walls/Floor").queue_free()
	return {"left": left, "right": right}

func test_running_off_a_plate_keeps_going_straight() -> void:
	var rooms := _two_rooms()
	await physics_frames(1)
	var p := spawn_player(Vector2(-100, rooms.left.floor_y - 30))
	p.input_override.aim = Vector2.RIGHT
	await physics_frames(frame_count(1.5))
	assert_true(p.global_position.x > 50.0, "crossed into the dead room")
	assert_true(p.in_zero_g(), "zero-g on the far side")
	assert_true(absf(p.velocity.y) < 1.0, "no fall, got vy %f" % p.velocity.y)
	assert_true(absf(p.velocity.x - Player.RUN_SPEED) < 1.0, "run speed carried across")

func test_flying_into_gravity_arcs_and_lands() -> void:
	var rooms := _two_rooms()
	await physics_frames(1)
	var p := spawn_player(Vector2(200, rooms.left.floor_y - 200))
	p.velocity = Vector2(-300, 0)
	await physics_frames(frame_count(1.5))
	assert_true(not p.in_zero_g(), "in the live room")
	assert_true(p.is_on_floor(), "landed")

func test_outside_every_compartment_is_zero_g() -> void:
	var p := spawn_player(Vector2(0, 0))
	await physics_frames(2)
	assert_true(p.compartments.is_empty(), "no compartment")
	assert_true(p.in_zero_g(), "space is zero-g")
	p.velocity = Vector2(10, 10)
	await physics_frames(10)
	assert_true(p.velocity.is_equal_approx(Vector2(10, 10)), "and nothing falls")

func test_leaving_one_of_two_overlapping_compartments_keeps_the_other() -> void:
	var live := make_room(true, Vector2(600, 600), Vector2(0, 0))
	var dead := make_room(false, Vector2(600, 600), Vector2(400, 0))
	dead.room.get_node("Walls").queue_free()
	live.room.get_node("Walls").queue_free()
	await physics_frames(1)
	var p := spawn_player(Vector2(200, 0))   # inside both
	await physics_frames(2)
	assert_eq(p.compartments.size(), 2, "in both")
	p.global_position = Vector2(550, 0)        # only the dead room now
	await physics_frames(2)
	assert_eq(p.compartments.size(), 1, "left the live room")
	assert_true(p.in_zero_g(), "the remaining one rules")
```

The node names (`Walls/Floor`, `Walls/Right` and so on) are the ones Task 5's `make_room` defines.

- [ ] **Step 2: Run to verify failure**

Expected: `test_outside_every_compartment_is_zero_g` passes already if Task 6 selected the mode from `in_zero_g()`; the others fail on compartment tracking or node names.

- [ ] **Step 3: Implement compartment tracking in `Player`**

- [ ] **Step 4: Run to verify pass**

- [ ] **Step 5: Commit**

```bash
git add scripts/player.gd tests/test_boundary.gd tests/test_boundary.gd.uid tests/test_case.gd
git commit -m "Gravity boundaries: momentum crosses intact, space is zero-g, overlaps resolve"
```

---

### Task 8: Vent

**Files:**
- Create: `scripts/vent.gd`, `scenes/Vent.tscn`
- Test: `tests/test_vent.gd`

**Interfaces:**
- Consumes: `WorldState.vents_open`, `Player.in_zero_g()`.
- Produces:
  ```gdscript
  class_name Vent extends Area2D
  @export var direction: Vector2 = Vector2.RIGHT     # normalised on ready
  const FORCE_ZERO_G := 600.0      # px/s^2: a body at rest crosses about 1200 px in 2 s
  const FORCE_GRAVITY := 60.0      # a tenth
  func is_blowing() -> bool        # WorldState.vents_open
  ```
  Each physics frame while blowing, for every overlapping body that has a `velocity` property: `velocity += direction * force * delta`, force chosen by `body.in_zero_g()` when the body has that method, else `FORCE_ZERO_G`. Bodies without `velocity` are skipped. `scenes/Vent.tscn`: `Vent` root, `CollisionShape2D` named `Bounds` with a `RectangleShape2D`, mask 1, plus a `GPUParticles2D` or `CPUParticles2D` named `Streaks` emitting only while blowing, streaked along `direction`.

- [ ] **Step 1: Write the failing tests**

```gdscript
extends TestCase

func _vent(size: Vector2, at: Vector2) -> Vent:
	var v: Vent = load("res://scenes/Vent.tscn").instantiate()
	(v.get_node("Bounds") as CollisionShape2D).shape.size = size
	v.position = at
	return add(v) as Vent

func test_blows_hard_in_zero_g_only_while_open() -> void:
	var r := make_room(false)
	var v := _vent(Vector2(1800, 1000), Vector2.ZERO)
	var p := spawn_player(Vector2(-600, 0))
	await physics_frames(frame_count(0.5))
	assert_eq(p.velocity, Vector2.ZERO, "closed: still")
	WorldState.set_vents(true)
	await physics_frames(frame_count(0.5))
	assert_true(absf(p.velocity.x - Vent.FORCE_ZERO_G * 0.5) < 15.0, "half a second of push, got %f" % p.velocity.x)

func test_barely_moves_you_on_the_ground() -> void:
	var r := make_room(true)
	var v := _vent(Vector2(1800, 1000), Vector2.ZERO)
	var p := spawn_player(Vector2(-600, r.floor_y - 30))
	WorldState.set_vents(true)
	await physics_frames(frame_count(0.5))
	assert_true(absf(p.velocity.x) < 40.0, "a gentle push, got %f" % p.velocity.x)

func test_skips_bodies_without_velocity() -> void:
	var r := make_room(false)
	var v := _vent(Vector2(400, 400), Vector2.ZERO)
	var prop := StaticBody2D.new()
	var shape := CollisionShape2D.new()
	shape.shape = RectangleShape2D.new()
	prop.add_child(shape)
	add(prop)
	WorldState.set_vents(true)
	await physics_frames(5)
	assert_true(true, "no script error reached the runner")
```

- [ ] **Step 2: Run to verify failure**

- [ ] **Step 3: Implement `scripts/vent.gd` and build `scenes/Vent.tscn`**

Use `get_overlapping_bodies()` each physics frame.

- [ ] **Step 4: Run to verify pass**

- [ ] **Step 5: Commit**

```bash
git add scripts/vent.gd scripts/vent.gd.uid scenes/Vent.tscn tests/test_vent.gd tests/test_vent.gd.uid
git commit -m "Vent: pushes bodies while the vents are open, hard in zero-g"
```

---

### Task 9: The swing: aim, hittables, pogo, ricochet

**Files:**
- Create: `scripts/swing.gd`
- Modify: `scripts/player.gd`, `scripts/gravity_mode.gd`, `scripts/zero_g_mode.gd`, `scenes/Player.tscn`
- Test: `tests/test_swing.gd`

**Interfaces:**
- Consumes: `Groups.HITTABLE`, `Switch.hit`.
- Produces:
  ```gdscript
  class_name Swing extends Area2D       # child of Player named "Swing"
  const ACTIVE := 0.1                   # seconds the hitbox is live
  const RECOVERY := 0.15                # seconds after ACTIVE before the next swing
  const REACH := 40.0                   # hitbox centre offset from the player
  signal landed(target: Node2D, direction: Vector2)   # once per target per swing
  var direction: Vector2 = Vector2.ZERO
  func start(dir: Vector2) -> bool      # false if active or recovering
  func is_busy() -> bool
  ```
  `Player` gains `@onready var swing: Swing = $Swing` and `func aim_for_swing(input: PlayerInput) -> Vector2`. Hitbox: `CollisionShape2D` with a `RectangleShape2D` 36 by 28, mask layer 2 (hittables; Plan 2 adds enemies on layer 3), `monitoring` only while active. `Player.aim_for_swing(input) -> Vector2`: in gravity, `UP` when `aim.y < 0`; `DOWN` when `aim.y > 0` and not on the floor; else `(facing, 0)`. In zero-g, `aim` if non-zero else `(facing, 0)`. On `landed(target, dir)`, `Player._on_swing_landed`: call `target.hit(self, dir)` if it has the method; then in gravity with `dir == DOWN` set `velocity.y = -JUMP_SPEED` (pogo); in zero-g set `velocity = -dir * KICK_SPEED` and `grabbed = false` (ricochet). Both modes call `p.swing.start(p.aim_for_swing(input))` on `swing_pressed`.

- [ ] **Step 1: Write the failing tests**

```gdscript
extends TestCase

func _block(at: Vector2) -> StaticBody2D:
	var b := StaticBody2D.new()
	b.collision_layer = 2
	var s := CollisionShape2D.new()
	s.shape = RectangleShape2D.new()
	s.shape.size = Vector2(60, 60)
	b.add_child(s)
	b.position = at
	b.add_to_group(Groups.HITTABLE)
	return add(b) as StaticBody2D

func test_swing_flips_a_switch_and_cannot_be_spammed() -> void:
	var r := make_room(true)
	var p := spawn_player(Vector2(0, r.floor_y - 30))
	var s: Switch = add(load("res://scenes/Switch.tscn").instantiate())
	s.switch_name = "vents"
	s.position = Vector2(Swing.REACH, r.floor_y - 30)
	p.input_override.swing_pressed = true
	await physics_frames(frame_count(Swing.ACTIVE + Swing.RECOVERY) - 2)
	assert_true(WorldState.vents_open, "one swing, one flip")
	assert_true(p.swing.is_busy(), "still recovering")
	await physics_frames(frame_count(Switch.REHIT_DELAY) + 4)
	assert_true(not WorldState.vents_open, "the next swing flips it back")

func test_down_swing_in_the_air_pogos() -> void:
	var r := make_room(true)
	var p := spawn_player(Vector2(0, r.floor_y - 200))
	_block(Vector2(0, r.floor_y - 200 + Swing.REACH + 20))
	p.input_override.aim = Vector2.DOWN
	p.input_override.swing_pressed = true
	await physics_frames(2)
	assert_true(p.velocity.y <= -Player.JUMP_SPEED + 50.0, "bounced up near jump speed (one frame of gravity allowed), got %f" % p.velocity.y)

func test_down_on_the_floor_swings_forward() -> void:
	var r := make_room(true)
	var p := spawn_player(Vector2(0, r.floor_y - 30))
	await physics_frames(2)
	p.input_override.aim = Vector2.DOWN
	assert_eq(p.aim_for_swing(p.input_override), Vector2.RIGHT, "forward, not into the floor")

func test_ricochet_in_zero_g_rebounds_in_any_direction() -> void:
	var r := make_room(false)
	var p := spawn_player(Vector2(0, 0))
	var dir := Vector2(1, 1).normalized()
	_block(dir * (Swing.REACH + 20))
	p.input_override.aim = dir
	p.input_override.swing_pressed = true
	await physics_frames(2)
	assert_true(p.velocity.is_equal_approx(-dir * Player.KICK_SPEED), "rebounds opposite the swing, got %s" % p.velocity)
```

- [ ] **Step 2: Run to verify failure**

- [ ] **Step 3: Implement `Swing`, add it to `Player.tscn`, wire both modes**

- [ ] **Step 4: Run to verify pass**

- [ ] **Step 5: Commit**

```bash
git add scripts/swing.gd scripts/swing.gd.uid scripts/player.gd scripts/gravity_mode.gd scripts/zero_g_mode.gd scenes/Player.tscn tests/test_swing.gd tests/test_swing.gd.uid
git commit -m "Swing: four-way aim, hits switches, pogo in gravity, ricochet in zero-g"
```

---

### Task 10: Sound

**Files:**
- Create: `scripts/sfx.gd`
- Modify: `scripts/player.gd`, `scripts/zero_g_mode.gd`, `scripts/switch.gd`, `scripts/swing.gd`, `tests/run_tests.gd`, `tests/test_hooks.gd`
- Test: `tests/test_sfx.gd`

**Interfaces:**
- Produces: Down Mine's `Sfx` API unchanged: `const SAMPLE_RATE := 22050`, `const POOL_SIZE := 8`, `const SOUNDS := ["swing", "hit", "shot", "kick", "grab", "switch", "hatch", "death", "ring_down"]`, `static func warm_up()`, `static func play(sound: String, volume_db: float = 0.0)`, `static func stream(sound: String) -> AudioStreamWAV`, `static func stop_all()`, `static func _make(sound: String) -> AudioStreamWAV`. Wiring: `Swing.start` plays `swing`; `Player.fire` plays `shot`; the grab latch plays `grab`; a kick plays `kick`; `Switch.hit` plays `switch`, and also `ring_down` when it has just turned the ring off. `hit`, `hatch` and `death` are synthesized now and played by Plans 2 and 3.

- [ ] **Step 1: Write the failing tests**

Port Down Mine's `test_sfx.gd` with `"swing"` in place of `"dig"` and `"ore"`, and a last test that `ring_down` is longer than half a second.

- [ ] **Step 2: Run to verify failure**

- [ ] **Step 3: Implement `scripts/sfx.gd`**

Port Down Mine's file; replace the `_make` match with the nine sounds. Each is a one-line `_render` recipe from `_tone`, `_lowpass_noise` and `_decay`; `ring_down` is a 0.8 s tone sweeping from 220 Hz to 40 Hz. Add `"Sfx._pool"` and `"Sfx._lp_state"` to `TestHooks.EXPLAINED` with Down Mine's explanations. Restore the `Sfx.stop_all()` line in `tests/run_tests.gd`.

- [ ] **Step 4: Run to verify pass**

- [ ] **Step 5: Commit**

```bash
git add scripts/sfx.gd scripts/sfx.gd.uid scripts/player.gd scripts/zero_g_mode.gd scripts/switch.gd scripts/swing.gd tests/run_tests.gd tests/test_hooks.gd tests/test_sfx.gd tests/test_sfx.gd.uid
git commit -m "Sound: nine synthesized effects, wired to swing, fire, grab, kick and switches"
```

---

### Task 11: The test room

**Files:**
- Create: `scenes/TestRoom.tscn`, `scripts/test_room.gd`
- Modify: `README.md`
- Test: `tests/test_scene.gd`

**Interfaces:**
- Produces: a playable scene, the project's main scene, with a `Player` node named `Player` and a `Camera2D` that follows it without rotating. `TestRoom` root script exposes `var player: Player`.

- [ ] **Step 1: Write the failing test**

```gdscript
extends TestCase

func test_the_test_room_runs_a_second_without_errors() -> void:
	var room = add(load("res://scenes/TestRoom.tscn").instantiate())
	await physics_frames(60)
	assert_true(room.player is Player, "has a player")
	assert_true(room.player.is_on_floor(), "starts on the floor of the live compartment")
	assert_eq(room.get_node("Camera2D").rotation, 0.0, "camera never rotates")
	WorldState.set_ring(false)
	await physics_frames(60)
	assert_true(room.player.in_zero_g(), "the ring switch reaches the player")
```

- [ ] **Step 2: Run to verify failure**

- [ ] **Step 3: Build `scenes/TestRoom.tscn` in the editor**

A box 2400 by 648 of dark hull polygons with matching `StaticBody2D` collision. Two `Compartment` instances: `Left` (x 0 to 1200, `plates_live` true, `room_name` "Test Left") with a floor; `Right` (x 1200 to 2400, `plates_live` false, `room_name` "Test Right") with no floor and one pillar to grab. The boundary at x 1200 is drawn as a bright vertical seam. A `Switch` with `switch_name` "ring" on the left wall at floor height; a `Switch` with `switch_name` "vents" on the pillar; a `Vent` covering the right compartment blowing right. A `Polygon2D` named `Tint` over each compartment, tinted warm when it has gravity and cool when not, updated each frame by `test_room.gd`. `Player` at (200, floor). `Camera2D` following the player with limits at the box, drag margins on, `rotating` off. `project.godot` main scene points here (it did since Task 1).

- [ ] **Step 4: Run to verify pass, then run the scene**

Run: the test suite. Then `godot --headless scenes/TestRoom.tscn --quit-after 120` and expect no script errors in the output. Where a display exists, run `godot` and play: walk right across the seam and keep going straight; grab the pillar with Shift, aim and kick with Space; swing (X) the ring switch and watch the tint change.

- [ ] **Step 5: README**

Add a "Try it" section: the controls table already there, plus the two switches and what to feel at the seam.

- [ ] **Step 6: Commit**

```bash
git add scenes/TestRoom.tscn scripts/test_room.gd scripts/test_room.gd.uid tests/test_scene.gd tests/test_scene.gd.uid README.md
git commit -m "Test room: two compartments, a seam, two switches and a vent"
```

---

## After this plan

Plan 2 (combat) starts from `Player.fire` emitting `fired(direction)`, `Groups.HITTABLE`, `Swing.landed`, and `Compartment` enter and exit calls on any body with `enter_compartment`. Plan 3 (the slice) starts from `Compartment.room_name`, `WorldState.visit`, `WorldState.checkpoint`, and the `RingOn`, `RingOff`, `VentsOpen`, `VentsClosed` container convention.

# Metroidvania Slice, Plan 3 of 3: The Slice Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The thirteen rooms of the Hulk as a connected, saved, mapped world that starts at the Dock and ends past the Warden's door, proven free of dead ends by a test, played end to end by a scripted playtest, and exported to the web.

**Architecture:** `WorldGraph` is hand-written data: rooms, exits, and what each crossing needs. A `Game` controller holds one `Room` scene at a time, swaps rooms when the player crosses an `Exit`, and preserves velocity across the swap. The reachability test walks the product of rooms and world states and fails on any reachable dead end. Rooms are editor-built scenes that follow plan 1's state-container convention.

**Tech Stack:** Godot 4.5, GDScript. Builds on plans 1 and 2.

**Spec:** `docs/superpowers/specs/2026-10-12-metroidvania-slice-design.md`. Plans 1 and 2 beside this file.

## Global Constraints

- Everything in plans 1 and 2's Global Constraints.
- One screen cell is `1152` by `648` px. Room sizes are whole cells. The map draws one cell as one unit.
- Gating by height is a hard rule: a gap meant to block in gravity is at least `200` px above the floor; a step meant to be passable is at most `80` px (the jump reaches `96`). A doorway is at least `96` px tall and `64` px wide.
- Room scenes live at `res://scenes/rooms/<Name>.tscn` where `Name` is the room name with spaces removed (`SpineWest.tscn`). The scene's `Room.room_name` is the spaced name (`"Spine West"`), which is also the `Compartment.room_name` and the `Checkpoint.room_name`.
- Every room has exactly one `Compartment` covering it. Dead-plate rooms: Breach, Blister. All others live.
- The spec's one deliberate change: the fallen gate between Spine West and Spine East is crossed eastward only in zero-g, and westward in any state, as a drop from Spine East's higher floor over the gate's top. Without the drop a player who restores gravity in the Control Room and descends through the Hangar is stuck east of the gate.
- Save on rest only. Visited rooms persist with the save.
- Start state: ring on, vents closed, boss alive, checkpoint `""`, which means the Dock.

## Review Focus

1. **Crossing an exit at speed in zero-g** must not re-trigger the destination's exit and bounce the player back. Task 2.
2. **A save naming a checkpoint room that does not exist** falls back to the Dock instead of crashing. Task 2.
3. **Dying before ever resting** respawns at the Dock's airlock. Task 2.
4. **An enemy or a shot drifting through an exit** must not swap rooms; only the player crosses. Task 2.
5. **Opening the map while dead or mid-swap** toggles without error. Task 6.

---

### Task 1: WorldGraph and the reachability test

**Files:**
- Create: `scripts/world_graph.gd`
- Test: `tests/test_reachability.gd`

**Interfaces:**
- Produces:
  ```gdscript
  class_name WorldGraph extends RefCounted
  ## Rooms: name -> {grid: Rect2i (cells; x right, y down), plates_live: bool, panels: Array[String] ("ring", "vents", "boss"), checkpoint: bool}
  const ROOMS := { ... }
  ## Edges: [from, from_exit, to, to_exit, needs]; needs is an Array of predicate names, all must hold:
  ## "ring_on", "ring_off", "vents_open", "vents_closed", "boss_down". Empty means any state.
  const EDGES := [ ... ]
  const START := "Dock"
  const END := "Exit"
  const REQUIRED_PATH := ["Dock", "Spine West", "Breach", "Blister", "Breach", "Spine West", "Spine East", "Vent Room", "Workshop", "Hangar", "Ring Deck", "Control Room", "Exit"]
  static func exits_of(room: String) -> Array[String]       # from_exit names declared for the room
  static func edge(from: String, from_exit: String) -> Array # the edge leaving that exit, or []
  static func allows(needs: Array, state: Dictionary) -> bool   # state: {ring_on, vents_open, boss_down}
  ```
  The rooms and their grid cells:

  | Room | Cells (x, y, w, h) | Plates | Panels | Checkpoint |
  | --- | --- | --- | --- | --- |
  | Blister | -2, 2, 1, 1 | dead | ring | |
  | Breach | -1, 2, 1, 1 | dead | | |
  | Dock | 0, 2, 1, 1 | live | | yes |
  | Spine West | 1, 2, 2, 1 | live | | |
  | Shaft | 1, 0, 1, 2 | live | | |
  | Spine East | 3, 2, 1, 1 | live | | |
  | Vent Room | 4, 2, 1, 1 | live | vents | |
  | Locker | 4, 3, 1, 1 | live | | |
  | Workshop | 5, 2, 1, 1 | live | | |
  | Hangar | 6, 0, 1, 3 | live | | |
  | Ring Deck | 1, -1, 6, 1 | live | | yes |
  | Control Room | 7, -1, 1, 1 | live | ring, boss | |
  | Exit | 8, -1, 1, 1 | live | | |

  Row 2 is the spine level, row -1 the ring deck. The Shaft stands under the Ring Deck's west end and opens into Spine West; the Hangar stands under its east end and opens into the Workshop at the spine level.

  The edges, both directions listed separately:

  | From, exit | To, exit | Needs |
  | --- | --- | --- |
  | Blister east | Breach west | |
  | Breach west | Blister east | |
  | Breach east | Dock west | |
  | Dock west | Breach east | |
  | Dock east | Spine West west | |
  | Spine West west | Dock east | |
  | Spine West up | Shaft down | ring_off |
  | Shaft down | Spine West up | |
  | Spine West east | Spine East west | ring_off |
  | Spine East west | Spine West east | |
  | Spine East east | Vent Room west | |
  | Vent Room west | Spine East east | |
  | Vent Room down | Locker up | vents_closed, ring_off |
  | Locker up | Vent Room down | vents_closed, ring_off |
  | Vent Room east | Workshop west | |
  | Workshop west | Vent Room east | |
  | Workshop east | Hangar west | vents_open |
  | Hangar west | Workshop east | vents_open |
  | Hangar up | Ring Deck down_east | ring_off |
  | Ring Deck down_east | Hangar up | |
  | Shaft up | Ring Deck down_west | vents_open, ring_off |
  | Ring Deck down_west | Shaft up | vents_open |
  | Ring Deck east | Control Room west | |
  | Control Room west | Ring Deck east | |
  | Control Room east | Exit west | boss_down |
  | Exit west | Control Room east | boss_down |

- [ ] **Step 1: Write the failing tests**

```gdscript
extends TestCase

## Nodes are [room, ring_on, vents_open, boss_down]. From a node you may cross any edge whose needs hold,
## or flip a panel in the room ("boss" only turns boss_down on, once; it never turns off).
func _neighbours(node: Array) -> Array:
	var out := []
	var state := {"ring_on": node[1], "vents_open": node[2], "boss_down": node[3]}
	for e in WorldGraph.EDGES:
		if e[0] == node[0] and WorldGraph.allows(e[4], state):
			out.append([e[2], node[1], node[2], node[3]])
	for panel in WorldGraph.ROOMS[node[0]].panels:
		match panel:
			"ring": out.append([node[0], not node[1], node[2], node[3]])
			"vents": out.append([node[0], node[1], not node[2], node[3]])
			"boss": if not node[3]: out.append([node[0], node[1], node[2], true])
	return out

func _reachable_from(start: Array) -> Dictionary:
	var seen := {start: true}
	var queue := [start]
	while not queue.is_empty():
		var n = queue.pop_front()
		for m in _neighbours(n):
			if not seen.has(m):
				seen[m] = true
				queue.append(m)
	return seen

func test_no_reachable_dead_end() -> void:
	var start := [WorldGraph.START, true, false, false]
	var reachable := _reachable_from(start)
	assert_true(reachable.size() > 13, "the product graph is explored (%d nodes)" % reachable.size())
	for node in reachable:
		var onward := _reachable_from(node)
		var ends := onward.keys().filter(func(n): return n[0] == WorldGraph.END)
		assert_true(not ends.is_empty(), "dead end: in %s with ring_on=%s vents_open=%s boss_down=%s the Exit is unreachable" % node)

func test_the_designed_path_is_walkable_with_the_designed_flips() -> void:
	var state := {"ring_on": true, "vents_open": false, "boss_down": false}
	var flips := {"Blister": "ring", "Vent Room": "vents", "Control Room": "boss"}
	var path := WorldGraph.REQUIRED_PATH
	for i in range(path.size() - 1):
		var here: String = path[i]
		if flips.has(here):
			match flips[here]:
				"ring": state.ring_on = not state.ring_on
				"vents": state.vents_open = not state.vents_open
				"boss": state.boss_down = true
			flips.erase(here)
		var edges := WorldGraph.EDGES.filter(func(e): return e[0] == here and e[2] == path[i + 1])
		assert_true(not edges.is_empty(), "an edge from %s to %s exists" % [here, path[i + 1]])
		assert_true(edges.any(func(e): return WorldGraph.allows(e[4], state)), "%s to %s is open at step %d" % [here, path[i + 1], i])

func test_the_locker_is_reachable_and_needs_both_switches() -> void:
	var reachable := _reachable_from([WorldGraph.START, true, false, false])
	var in_locker := reachable.keys().filter(func(n): return n[0] == "Locker")
	assert_true(not in_locker.is_empty(), "the secret can be reached")
	for n in in_locker:
		assert_true(not n[1] and not n[2], "only with ring off and vents closed: %s" % [n])

func test_every_edge_has_a_return_and_names_real_rooms_and_exits() -> void:
	for e in WorldGraph.EDGES:
		assert_true(WorldGraph.ROOMS.has(e[0]) and WorldGraph.ROOMS.has(e[2]), "%s names real rooms" % [e])
		var back := WorldGraph.EDGES.filter(func(b): return b[0] == e[2] and b[1] == e[3] and b[2] == e[0] and b[3] == e[1])
		assert_eq(back.size(), 1, "%s has exactly one return edge" % [e])
		for need in e[4]:
			assert_true(need in ["ring_on", "ring_off", "vents_open", "vents_closed", "boss_down"], "known predicate %s" % need)

func test_rooms_do_not_overlap_on_the_map() -> void:
	var names := WorldGraph.ROOMS.keys()
	for i in range(names.size()):
		for j in range(i + 1, names.size()):
			var a: Rect2i = WorldGraph.ROOMS[names[i]].grid
			var b: Rect2i = WorldGraph.ROOMS[names[j]].grid
			assert_true(not a.intersects(b), "%s and %s overlap" % [names[i], names[j]])
```

- [ ] **Step 2: Run to verify failure**

- [ ] **Step 3: Write `scripts/world_graph.gd` from the two tables above**

- [ ] **Step 4: Run to verify pass**

If `test_no_reachable_dead_end` fails, the failing node names the room and state; fix the graph (and so the design), never the test.

- [ ] **Step 5: Commit**

```bash
git add scripts/world_graph.gd scripts/world_graph.gd.uid tests/test_reachability.gd tests/test_reachability.gd.uid
git commit -m "WorldGraph: rooms, exits and what each crossing needs, with a dead-end test"
```

---

### Task 2: Room, Exit, the Game controller, the Title, and the first two rooms

**Files:**
- Create: `scripts/room.gd`, `scripts/exit.gd`, `scenes/Exit.tscn`, `scripts/game.gd`, `scenes/Main.tscn`, `scripts/title.gd`, `scenes/Title.tscn`
- Create: `scenes/rooms/Dock.tscn`, `scenes/rooms/Breach.tscn`
- Modify: `scripts/compartment.gd` (`BossAlive` and `BossDown` containers follow `WorldState.boss_down`), `project.godot` (main scene `Main.tscn`; action `map`: Tab, M, joypad button 3), `tests/test_hooks.gd`
- Test: `tests/test_game.gd`

**Interfaces:**
- Consumes: plan 2's `Checkpoint`, `Respawner`, `Spawner`, `Hud`; plan 1's `Compartment`, `Player`, `LaunchOptions`.
- Produces:
  ```gdscript
  class_name Room extends Node2D
  @export var room_name: String
  @export var floor_y: float = 0.0           # the main floor's top surface, in room coordinates; set per room in the editor
  @onready var compartment: Compartment = $Compartment
  func bounds() -> Rect2                     # world rect of the compartment's Bounds shape
  func exits() -> Array[Exit]                # children of $Exits
  func exit_named(n: String) -> Exit
  func checkpoint() -> Checkpoint            # the first Checkpoint child, or null
  ```
  ```gdscript
  class_name Exit extends Area2D             # mask 1; only a Player body counts
  @export var exit_name: String
  @export var inward: Vector2 = Vector2.RIGHT # unit vector pointing into the room
  signal crossed(exit: Exit)
  func arrival_point() -> Vector2            # global_position + inward * ARRIVAL_OFFSET
  const ARRIVAL_OFFSET := 48.0
  ```
  ```gdscript
  class_name Game extends Node2D             # scenes/Main.tscn root; children: Player, Camera2D, HUD, Title, Map (Task 6)
  const SWAP_COOLDOWN := 0.3                 # seconds after a swap during which exits are ignored
  var room: Room
  var player: Player
  func enter(room_name: String, exit_name: String) -> void   # frees the old room, instantiates scenes/rooms/<Name>.tscn, places the player at the exit's arrival point (or the checkpoint's spawn point when exit_name is ""), keeps velocity, clears player.tracker, sets camera limits to room.bounds(), WorldState.visit(room_name)
  func start() -> void                       # WorldState.load(); enter(checkpoint room or Dock, ""); Title unless Title.seen or LaunchOptions has "room"
  static func scene_path(room_name: String) -> String   # "res://scenes/rooms/" + room_name.replace(" ", "") + ".tscn"
  ```
  Death: `Respawner.bind(player, lookup)` where `lookup(name)` calls `enter(name if a scene exists for it else "Dock", "")` and returns `room.checkpoint()`. `LaunchOptions`: `--room=Spine%20West` (or `?room=`) starts in that room at its first exit, `--ring=off`, `--vents=open` preset the switches.
  ```gdscript
  class_name Title extends CanvasLayer       # the game's name and "Press Jump"; hides on the jump action; pauses the tree while shown
  static var seen: bool = false              # TestHooks resets it to true so scene tests never start paused
  ```
  **Dock** (1 cell, live): floor along the bottom, an airlock `Checkpoint` (room "Dock") at the west end, two `Spawner`s of `Mite.tscn` on the floor and the east wall, exits `west` (left wall, to Breach) and `east` (right wall, to Spine West). **Breach** (1 cell, dead plates): a hull split open to the stars (dark background, bright star points), no floor, three large drifting hull fragments to grab (static polygons), `Spawner`s of `Mite.tscn` on three of their faces, exits `west` and `east`.

- [ ] **Step 1: Write the failing tests**

```gdscript
extends TestCase

func _game() -> Game:
	var g: Game = load("res://scenes/Main.tscn").instantiate()
	add(g)
	return g

func test_starts_in_the_dock_with_nothing_saved() -> void:
	var g := _game()
	g.start()
	await physics_frames(2)
	assert_eq(g.room.room_name, "Dock", "the Dock")
	assert_true(Array(WorldState.visited).has("Dock"), "visited")
	assert_true(g.player.global_position.distance_to(g.room.checkpoint().spawn_point()) < 2.0, "at the airlock")
	assert_eq(g.get_node("Camera2D").limit_right, int(g.room.bounds().end.x), "camera limited to the room")

func test_crossing_an_exit_swaps_rooms_and_keeps_velocity() -> void:
	var g := _game()
	g.enter("Dock", "west")
	await physics_frames(2)
	var west := g.room.exit_named("west")
	g.player.global_position = west.global_position + west.inward * 20.0
	g.player.velocity = Vector2(-150, 0)
	g.player.input_override.aim = Vector2.LEFT
	await physics_frames(frame_count(0.5))
	assert_eq(g.room.room_name, "Breach", "swapped")
	assert_true(g.player.velocity.x < -100.0, "still moving left, got %s" % g.player.velocity)
	assert_true(g.player.in_zero_g(), "the Breach is zero-g")
	await physics_frames(frame_count(Game.SWAP_COOLDOWN))
	assert_eq(g.room.room_name, "Breach", "did not bounce back through the arrival exit")

func test_only_the_player_crosses() -> void:
	var g := _game()
	g.enter("Dock", "west")
	await physics_frames(2)
	var east := g.room.exit_named("east")
	var m: Mite = add(load("res://scenes/Mite.tscn").instantiate())
	m.global_position = east.global_position
	Shot.spawn(tree.root, null, east.global_position, Vector2.ZERO, false)
	await physics_frames(5)
	assert_eq(g.room.room_name, "Dock", "still the Dock")

func test_a_save_naming_a_missing_room_falls_back_to_the_dock() -> void:
	WorldState.set_checkpoint("Boiler Deck")
	WorldState.save()
	WorldState.reset()
	var g := _game()
	g.start()
	await physics_frames(2)
	assert_eq(g.room.room_name, "Dock", "fell back")

func test_death_before_resting_returns_to_the_dock_airlock() -> void:
	var g := _game()
	g.enter("Breach", "west")
	await physics_frames(2)
	for i in range(5):
		g.player.invulnerable_for = 0.0
		g.player.take_hit(Vector2.ZERO)
	await physics_frames(frame_count(Player.DEATH_DELAY) + 3)
	assert_eq(g.room.room_name, "Dock", "back at the Dock")
	assert_true(not g.player.dead, "alive")

func test_boss_containers_follow_the_flag() -> void:
	var c: Compartment = add(load("res://scenes/Compartment.tscn").instantiate())
	for n in ["BossAlive", "BossDown"]:
		var h := Node2D.new()
		h.name = n
		c.add_child(h)
	await physics_frames(1)
	assert_true(c.get_node("BossAlive").visible and not c.get_node("BossDown").visible, "alive")
	WorldState.set_boss_down()
	await physics_frames(1)
	assert_true(not c.get_node("BossAlive").visible and c.get_node("BossDown").visible, "down")
```

- [ ] **Step 2: Run to verify failure**

- [ ] **Step 3: Implement the scripts, build `Main.tscn`, `Exit.tscn`, `Title.tscn`, `Dock.tscn` and `Breach.tscn` in the editor**

`Exit.tscn`: `Area2D` with a `CollisionShape2D` (`RectangleShape2D` 32 by 128) and a faint bright `Polygon2D` frame. `TestHooks.RESET` gains `"Title.seen"`; `reset()` sets it true and unpauses the main loop (`(Engine.get_main_loop() as SceneTree).paused = false`), since the Title and the SliceEnd pause it. Delete `scripts/test_room.gd`, `scenes/TestRoom.tscn`, `scenes/TestArena.tscn` and `tests/test_scene.gd` from plan 2 only in Task 7, once the playtest covers what they showed.

- [ ] **Step 4: Run to verify pass**

- [ ] **Step 5: Commit**

```bash
git add scripts/room.gd scripts/exit.gd scripts/game.gd scripts/title.gd scripts/*.uid scenes/Exit.tscn scenes/Main.tscn scenes/Title.tscn scenes/rooms/Dock.tscn scenes/rooms/Breach.tscn scripts/compartment.gd project.godot tests/test_hooks.gd tests/test_game.gd tests/test_game.gd.uid
git commit -m "Rooms, exits and the Game controller; the Dock and the Breach"
```

---

### Task 3: Blister, Spine West, Shaft

**Files:**
- Create: `scenes/rooms/Blister.tscn`, `scenes/rooms/SpineWest.tscn`, `scenes/rooms/Shaft.tscn`
- Test: `tests/test_rooms_west.gd`

**Interfaces:**
- Consumes: `Switch`, `Spawner`, `Exit`, state containers.
- Produces, room by room:
  - **Blister** (1 cell, dead): an observation dome; the background is the ring itself, a large slow-turning `Polygon2D` named `Ring` that stops turning when `WorldState.ring_on` is false (a `blister.gd` script on the room reads it). Panel 2: a `Switch` (`switch_name` "ring") on the dome's inner wall. One `Drone.tscn` spawner. Exit `east`.
  - **Spine West** (2 cells wide, live): floor along the bottom. The Shaft opening in the ceiling at x in the first cell, with a tall vertical passage above the ceiling leading to exit `up` at least `400` px above the floor. The fallen gate at the east end: `RingOn` container holds the gate's collision, a wall from the floor to `200` px below the ceiling and the gate `Polygon2D` leaning; `RingOff` holds the same polygon floating near the ceiling, no collision. Spine East's floor is higher, so the `east` exit sits `220` px above Spine West's floor, reached over the gate's top from the east and only by flying from the west. Two mite spawners, one drone spawner. Exits `west`, `up`, `east`.
  - **Shaft** (1 wide, 2 tall, live): a vertical shaft with grab ledges on both walls every `150` px, mite spawners on four of them. At the top, exit `up` behind the pressure door: `VentsClosed` container holds the door's collision and a dim door polygon; `VentsOpen` holds the same door slid aside, no collision. Exit `down` at the bottom.

- [ ] **Step 1: Write the failing tests**

```gdscript
extends TestCase

func _room(name: String) -> Room:
	var r: Room = load(Game.scene_path(name)).instantiate()
	add(r)
	return r

func test_blister_holds_ring_panel_two_and_stops_the_ring() -> void:
	var r := _room("Blister")
	await physics_frames(1)
	var panels := r.find_children("*", "Switch", true, false)
	assert_eq(panels.size(), 1, "one panel")
	assert_eq(panels[0].switch_name, "ring", "the ring")
	assert_true(not r.compartment.plates_live, "dead plates")
	var ring: Node2D = r.get_node("Ring")
	var before := ring.rotation
	await physics_frames(10)
	assert_true(ring.rotation != before, "turning")
	WorldState.set_ring(false)
	await physics_frames(2)
	var stopped := ring.rotation
	await physics_frames(10)
	assert_eq(ring.rotation, stopped, "stopped")

func test_spine_west_gate_blocks_only_in_gravity() -> void:
	var r := _room("SpineWest")
	await physics_frames(1)
	var gate_shape: CollisionShape2D = r.get_node("Compartment/RingOn").find_children("*", "CollisionShape2D", true, false)[0]
	assert_true(not gate_shape.disabled, "gate solid with the ring on")
	var east := r.exit_named("east")
	var floor_y := r.floor_y
	assert_true(floor_y - east.global_position.y >= 200.0, "the east exit is a gravity-blocking height above the floor")
	assert_true(r.exit_named("up").global_position.y <= floor_y - 400.0, "the shaft mouth is well above")
	WorldState.set_ring(false)
	await physics_frames(1)
	assert_true(gate_shape.disabled, "gate gone in zero-g")

func test_shaft_door_follows_the_vents() -> void:
	var r := _room("Shaft")
	await physics_frames(1)
	var door: CollisionShape2D = r.get_node("Compartment/VentsClosed").find_children("*", "CollisionShape2D", true, false)[0]
	assert_true(not door.disabled, "sealed")
	WorldState.set_vents(true)
	await physics_frames(1)
	assert_true(door.disabled, "open")
	assert_true(r.exit_named("up").global_position.y < r.exit_named("down").global_position.y - 1000.0, "two cells tall")
```

- [ ] **Step 2: Run to verify failure**

- [ ] **Step 3: Build the three rooms in the editor**

- [ ] **Step 4: Run to verify pass**

- [ ] **Step 5: Commit**

```bash
git add scenes/rooms/Blister.tscn scenes/rooms/SpineWest.tscn scenes/rooms/Shaft.tscn scripts/blister.gd scripts/blister.gd.uid tests/test_rooms_west.gd tests/test_rooms_west.gd.uid
git commit -m "Rooms: the Blister with panel two, Spine West and its gate, the Shaft and its door"
```

---

### Task 4: Spine East, Vent Room, Locker, Workshop

**Files:**
- Create: `scenes/rooms/SpineEast.tscn`, `scenes/rooms/VentRoom.tscn`, `scenes/rooms/Locker.tscn`, `scenes/rooms/Workshop.tscn`
- Test: `tests/test_rooms_branch.gd`

**Interfaces:**
- Produces:
  - **Spine East** (1 cell, live): floor `220` px higher than Spine West's, so its `west` exit opens over the gate. One drone spawner, the first the designed path meets after the Blister. Exits `west`, `east`.
  - **Vent Room** (1 cell, live): the vents panel, a `Switch` (`switch_name` "vents") on the back wall. A floor hatch down to the Locker: `VentsOpen` holds the hatch's collision shut; `VentsClosed` the open hatch. A loose cabinet across the hatch: `RingOn` holds its collision, `RingOff` the cabinet floating clear. One `Vent` blowing east, covering the room's east half. Exits `west`, `down`, `east`.
  - **Locker** (1 cell, live): quiet, no enemies. A view port on the east wall: a `Polygon2D` window looking into a painted miniature of the Control Room with a still Warden silhouette, the slice's one secret. Exit `up`.
  - **Workshop** (1 cell, live): three `Clinger.tscn` spawners on walls and ceiling. A `Vent` blowing east across the whole room. Exits `west`, `east`.

- [ ] **Step 1: Write the failing tests**

```gdscript
extends TestCase

func _room(name: String) -> Room:
	var r: Room = load(Game.scene_path(name)).instantiate()
	add(r)
	return r

func _first_shape(node: Node) -> CollisionShape2D:
	return node.find_children("*", "CollisionShape2D", true, false)[0]

func test_vent_room_locker_hatch_needs_vents_closed_and_ring_off() -> void:
	var r := _room("VentRoom")
	await physics_frames(1)
	var hatch := _first_shape(r.get_node("Compartment/VentsOpen"))
	var cabinet := _first_shape(r.get_node("Compartment/RingOn"))
	assert_true(hatch.disabled and not cabinet.disabled, "start: hatch open, cabinet blocks")
	WorldState.set_ring(false)
	await physics_frames(1)
	assert_true(hatch.disabled and cabinet.disabled, "ring off: the way down is open")
	WorldState.set_vents(true)
	await physics_frames(1)
	assert_true(not hatch.disabled, "vents open: hatch shut")
	assert_eq(r.find_children("*", "Switch", true, false)[0].switch_name, "vents", "the vents panel")

func test_workshop_has_clingers_and_an_east_wind() -> void:
	var r := _room("Workshop")
	await physics_frames(1)
	var spawners := r.find_children("*", "Spawner", true, false)
	assert_eq(spawners.size(), 3, "three")
	assert_true(spawners.all(func(s): return s.spawned is Clinger), "all clingers")
	var vent: Vent = r.find_children("*", "Vent", true, false)[0]
	assert_true(vent.direction.is_equal_approx(Vector2.RIGHT), "east")

func test_spine_east_floor_is_higher_than_spine_west() -> void:
	var east := _room("SpineEast")
	var west := _room("SpineWest")
	assert_true(west.floor_y - east.floor_y >= 200.0, "a drop from east to west, never a jump: %f" % (west.floor_y - east.floor_y))

func test_locker_is_quiet_and_has_the_view_port() -> void:
	var r := _room("Locker")
	await physics_frames(1)
	assert_true(r.find_children("*", "Spawner", true, false).is_empty(), "no enemies")
	assert_true(r.get_node_or_null("ViewPort") != null, "the secret")
```

- [ ] **Step 2: Run to verify failure**

- [ ] **Step 3: Build the four rooms in the editor**

- [ ] **Step 4: Run to verify pass**

- [ ] **Step 5: Commit**

```bash
git add scenes/rooms/SpineEast.tscn scenes/rooms/VentRoom.tscn scenes/rooms/Locker.tscn scenes/rooms/Workshop.tscn tests/test_rooms_branch.gd tests/test_rooms_branch.gd.uid
git commit -m "Rooms: Spine East, the Vent Room and its hatch, the Locker, the Workshop"
```

---

### Task 5: Hangar, Ring Deck, Control Room, Exit

**Files:**
- Create: `scenes/rooms/Hangar.tscn`, `scenes/rooms/RingDeck.tscn`, `scenes/rooms/ControlRoom.tscn`, `scenes/rooms/Exit.tscn`, `scripts/slice_end.gd`
- Test: `tests/test_rooms_top.gd`

**Interfaces:**
- Produces:
  - **Hangar** (1 wide, 3 tall, live): its floor at the spine level with the `west` hatch from the Workshop: `VentsClosed` holds it shut. A `Vent` covering the whole room blowing east toward a shredded hull wall, which is a column of `Hazard` strips. The ceiling torn open: exit `up` at the top, at least `1000` px above the floor. Two mite spawners on the walls. Exits `west`, `up`.
  - **Ring Deck** (6 wide, live): a long corridor along the ring housing, with the housing drawn as a band of dim arcs. Exits `down_west` (floor opening at the west end, to the Shaft), `down_east` (floor opening at the east end, to the Hangar), `east`. An airlock `Checkpoint` (room "Ring Deck") near the east end. Three drone spawners spaced along it.
  - **Control Room** (1 cell, live, at least `600` px floor to ceiling): panel 1, a `Switch` (`switch_name` "ring") on the west wall at floor height. A `Spawner` of `Warden.tscn` at the centre. The boss door on the east wall: `BossAlive` holds its collision and a heavy door polygon; `BossDown` the door open. Exits `west`, `east`.
  - **Exit** (1 cell, live): a short corridor ending at a `SliceEnd` area.
  ```gdscript
  class_name SliceEnd extends Area2D        # a Player entering it pauses the tree and shows its CanvasLayer child named Screen: "End of the slice" and the time since start
  ```

- [ ] **Step 1: Write the failing tests**

```gdscript
extends TestCase

func _room(name: String) -> Room:
	var r: Room = load(Game.scene_path(name)).instantiate()
	add(r)
	return r

func _first_shape(node: Node) -> CollisionShape2D:
	return node.find_children("*", "CollisionShape2D", true, false)[0]

func test_hangar_ceiling_is_zero_g_only_and_the_wind_meets_hazards() -> void:
	var r := _room("Hangar")
	await physics_frames(1)
	assert_true(r.floor_y - r.exit_named("up").global_position.y >= 1000.0, "far above")
	var hazards := r.find_children("*", "Hazard", true, false)
	var vent: Vent = r.find_children("*", "Vent", true, false)[0]
	assert_true(hazards.size() >= 3 and vent.direction.is_equal_approx(Vector2.RIGHT), "shredded wall downwind")
	assert_true(hazards.all(func(h): return h.global_position.x > r.bounds().get_center().x), "hazards on the east")
	var hatch := _first_shape(r.get_node("Compartment/VentsClosed"))
	assert_true(not hatch.disabled, "hatch shut at start")

func test_ring_deck_has_the_second_airlock_and_both_floor_openings() -> void:
	var r := _room("RingDeck")
	await physics_frames(1)
	assert_eq(r.checkpoint().room_name, "Ring Deck", "airlock")
	assert_true(r.exit_named("down_west").global_position.x < r.exit_named("down_east").global_position.x, "west then east")
	assert_true(r.bounds().size.x >= 6 * 1152 - 1, "six cells")

func test_control_room_holds_panel_one_the_warden_and_the_door() -> void:
	var r := _room("ControlRoom")
	await physics_frames(1)
	assert_eq(r.find_children("*", "Switch", true, false)[0].switch_name, "ring", "panel one")
	assert_true(r.find_children("*", "Spawner", true, false)[0].spawned is Warden, "the Warden")
	assert_true(r.bounds().size.y >= 600.0 + 64.0, "room for the hover height")
	var door := _first_shape(r.get_node("Compartment/BossAlive"))
	assert_true(not door.disabled, "door shut")
	WorldState.set_boss_down()
	await physics_frames(1)
	assert_true(door.disabled, "door open for good")

func test_the_exit_ends_the_slice() -> void:
	var r := _room("Exit")
	await physics_frames(1)
	var end: SliceEnd = r.find_children("*", "SliceEnd", true, false)[0]
	var p := spawn_player(end.global_position)
	await physics_frames(3)
	assert_true(tree.paused, "paused at the end")
	assert_true(end.get_node("Screen").visible, "the end screen")
	tree.paused = false
```

- [ ] **Step 2: Run to verify failure**

- [ ] **Step 3: Build the four rooms and write `slice_end.gd`**

- [ ] **Step 4: Run to verify pass**

- [ ] **Step 5: Commit**

```bash
git add scenes/rooms/Hangar.tscn scenes/rooms/RingDeck.tscn scenes/rooms/ControlRoom.tscn scenes/rooms/Exit.tscn scripts/slice_end.gd scripts/slice_end.gd.uid tests/test_rooms_top.gd tests/test_rooms_top.gd.uid
git commit -m "Rooms: the Hangar, the Ring Deck, the Control Room with the Warden, the Exit"
```

---

### Task 6: Scenes match the graph; the map

**Files:**
- Create: `scripts/map.gd`, `scenes/Map.tscn`
- Modify: `scenes/Main.tscn`, `scripts/game.gd`
- Test: `tests/test_graph_scenes.gd`, `tests/test_map.gd`

**Interfaces:**
- Produces:
  ```gdscript
  class_name Map extends CanvasLayer         # child of Game named Map; hidden until toggled
  const CELL := 24.0                         # px per grid cell on screen
  func toggle() -> void
  func set_current(room_name: String) -> void
  func boxes_drawn() -> int                  # visited rooms drawn
  func panels_marked() -> int                # panels in visited rooms
  ```
  Draws, in `_draw` of a child `Control`, one box per visited room from `WorldGraph.ROOMS[name].grid` scaled by `CELL`, the current room filled bright, a small mark for each panel in a visited room, and the player's dot. `Game` toggles it on the `map` action and calls `set_current` on every `enter`. The map works while paused and while the player is dead.

- [ ] **Step 1: Write the failing tests**

```gdscript
# tests/test_graph_scenes.gd
extends TestCase

func test_every_room_in_the_graph_has_a_scene_with_the_declared_exits_and_plates() -> void:
	for name in WorldGraph.ROOMS:
		var path := Game.scene_path(name)
		assert_true(ResourceLoader.exists(path), "%s has a scene" % name)
		if not ResourceLoader.exists(path):
			continue
		var r: Room = add(load(path).instantiate())
		assert_eq(r.room_name, name, "scene names itself")
		assert_eq(r.compartment.plates_live, WorldGraph.ROOMS[name].plates_live, "%s plates" % name)
		var declared := WorldGraph.exits_of(name)
		var built := r.exits().map(func(e): return e.exit_name)
		declared.sort()
		built.sort()
		assert_eq(built, declared, "%s exits match the graph" % name)
		assert_eq(r.checkpoint() != null, WorldGraph.ROOMS[name].checkpoint, "%s checkpoint" % name)
		var panels := r.find_children("*", "Switch", true, false).map(func(s): return s.switch_name)
		for panel in WorldGraph.ROOMS[name].panels:
			if panel != "boss":
				assert_true(panels.has(panel), "%s has the %s panel" % [name, panel])
		r.free()

func test_every_exit_points_into_its_room() -> void:
	for name in WorldGraph.ROOMS:
		var r: Room = add(load(Game.scene_path(name)).instantiate())
		await physics_frames(1)
		for e in r.exits():
			assert_true(r.bounds().has_point(e.arrival_point()), "%s %s arrives inside the room" % [name, e.exit_name])
		r.free()
```

```gdscript
# tests/test_map.gd
extends TestCase

func test_map_draws_visited_rooms_and_their_panels() -> void:
	var g: Game = add(load("res://scenes/Main.tscn").instantiate())
	g.enter("Dock", "west")
	g.enter("Breach", "east")
	g.enter("Blister", "east")
	await physics_frames(1)
	var map: Map = g.get_node("Map")
	assert_true(not map.visible, "hidden until toggled")
	map.toggle()
	await physics_frames(1)
	assert_true(map.visible, "shown")
	assert_eq(map.boxes_drawn(), 3, "three visited")
	assert_eq(map.panels_marked(), 1, "the Blister's panel")

func test_map_toggles_while_dead() -> void:
	var g: Game = add(load("res://scenes/Main.tscn").instantiate())
	g.enter("Dock", "west")
	await physics_frames(1)
	for i in range(5):
		g.player.invulnerable_for = 0.0
		g.player.take_hit(Vector2.ZERO)
	g.get_node("Map").toggle()
	await physics_frames(1)
	assert_true(g.get_node("Map").visible, "open")
```

- [ ] **Step 2: Run to verify failure**

- [ ] **Step 3: Implement the map; fix any room the graph test names**

- [ ] **Step 4: Run to verify pass**

- [ ] **Step 5: Commit**

```bash
git add scripts/map.gd scripts/map.gd.uid scenes/Map.tscn scenes/Main.tscn scripts/game.gd tests/test_graph_scenes.gd tests/test_graph_scenes.gd.uid tests/test_map.gd tests/test_map.gd.uid
git commit -m "Scenes checked against the graph; the map"
```

---

### Task 7: The playtest

**Files:**
- Create: `tests/playtest.gd`
- Modify: `.github/workflows/tests.yml` (the `playtest` job), `tests/test_hooks.gd`
- Delete: `scenes/TestRoom.tscn`, `scenes/TestArena.tscn`, `scripts/test_room.gd`, `tests/test_scene.gd`

**Interfaces:**
- Consumes: `Game.enter`, `WorldGraph.REQUIRED_PATH`, `Player.input_override`.
- Produces: `tests/playtest.gd`, ported from Down Mine's runner (same `_run`, `frames`, `key_event`, `tap`, `hold`, `check`, `shot` helpers; `_start_game` instantiates `Main.tscn` and calls `start()`), with three scenarios:
  - `required_path`: for each consecutive pair in `REQUIRED_PATH`, enter the room by the exit the graph's edge names, screenshot, and where the room holds a panel the path flips (Blister, Vent Room), walk the player to the panel with held keys and swing it with a real key event, checking `WorldState` changed. In the Control Room, deal the Warden its health in one `damage` call (the fight itself is a human test), check `boss_down`, cross to the Exit, check the end screen.
  - `death_and_respawn`: rest at the Ring Deck airlock with a real swing, enter the Hangar with the ring off and the vents open, hold still in the gale until the hazards kill the player, check the respawn at the Ring Deck airlock with the switches unchanged.
  - `every_room_every_state`: for each room, for each state it is designed for (two for most, four for the vent branch), set the state and screenshot, so the state children can be accepted from the pictures.

- [ ] **Step 1: Write `tests/playtest.gd`**

- [ ] **Step 2: Run it**

Run: `xvfb-run -a godot --fixed-fps 60 -s tests/playtest.gd`
Expected: `3 scenarios, 0 failed; screenshots in playtest_out/`, and the screenshots show each room in each state.

- [ ] **Step 3: Add the `playtest` job to `tests.yml`** (Down Mine's, unchanged) **and delete the plan 2 test scenes**

- [ ] **Step 4: Run the unit suite, then commit**

```bash
git add tests/playtest.gd tests/playtest.gd.uid .github/workflows/tests.yml tests/test_hooks.gd
git rm scenes/TestRoom.tscn scenes/TestArena.tscn scripts/test_room.gd scripts/test_room.gd.uid tests/test_scene.gd tests/test_scene.gd.uid
git commit -m "Playtest: the required path, a death, every room in every state"
```

---

### Task 8: Exports, the web build, and the docs

**Files:**
- Create: `export_presets.cfg`, `.github/workflows/web.yml`
- Modify: `README.md`, `ROADMAP.md`

- [ ] **Step 1: Write `export_presets.cfg`**

Down Mine's Web preset unchanged (exclude `tests/*, playtest_out/*`), plus a `Linux` preset (`platform="Linux"`, `export_path="build/linux/drift.x86_64"`, same exclude filter).

- [ ] **Step 2: Write `.github/workflows/web.yml`**

Down Mine's, unchanged.

- [ ] **Step 3: Verify the export locally**

Run: `godot --headless --import && godot --headless --export-release "Web" build/web/index.html && test -f build/web/index.wasm`
Expected: the file exists. (Needs the Web export template installed as `web.yml` installs it.)

- [ ] **Step 4: Docs**

README: the one-paragraph pitch, controls (now with `map`), "What the slice is" (the thirteen rooms in one list, the two switches, where the airlocks are), how to run the tests and the playtest, how the web build publishes. ROADMAP: M3 done; an "After the slice" section listing what the spec left out (soul meter and spells, the shade, currency, text logs, a second section, touch controls) as unscheduled, and the two open questions.

- [ ] **Step 5: Commit**

```bash
git add export_presets.cfg .github/workflows/web.yml README.md ROADMAP.md
git commit -m "Web and Linux export presets, the Pages workflow, the slice's README and ROADMAP"
```

---

## When all three plans are done

The slice is complete when: the unit suite and the playtest are green in CI, the web build publishes, a fresh save walks Dock to Exit by the designed path, the Locker needs both switches, the Warden cannot be hit in gravity and can be staggered into reach by the switch, and dying anywhere returns you to the last airlock with the world unchanged. Then play it, and judge the feel.

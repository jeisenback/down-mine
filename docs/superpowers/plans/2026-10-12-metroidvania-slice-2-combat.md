# Metroidvania Slice, Plan 2 of 3: Combat Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Everything that can hurt or be hurt: player health, damage and death, the fire projectile, hit stop, the three enemies living in both gravity states, airlock checkpoints with respawn, the Warden fought by throwing the gravity switch, and the rigs that make all of it readable.

**Architecture:** Damage flows through two methods, `Player.take_hit` and `Enemy.damage`; everything that hurts calls one of them. Enemies share one base (`Enemy`) that owns health, knockback, stagger, contact damage, compartment tracking and death, with one behaviour script per type. Spawners own respawn. The Warden is its own script on the same base.

**Tech Stack:** Godot 4.5, GDScript. Builds on plan 1's `Player`, `Swing`, `Compartment`, `Switch`, `Vent`, `WorldState`, `Sfx`, `Groups` and the `TestCase` helpers.

**Spec:** `docs/superpowers/specs/2026-10-12-metroidvania-slice-design.md`. Plan 1: `docs/superpowers/plans/2026-10-12-metroidvania-slice-1-foundation.md`.

## Global Constraints

- Everything in plan 1's Global Constraints.
- Collision layers, fixed for the project: layer 1 world geometry and the player; layer 2 hittable props (switches, airlocks, hazards); layer 3 enemies. Shots are areas on no layer with a mask. `Compartment` and `Vent` masks become 1 and 3.
- Spec values: player health 5; a hit costs 1; invulnerability 0.6 s; hit stop 3 frames; enemy health 3; shot damage 1 with stagger; swing damage 1; enemies respawn only on a rest; no drops, no currency, no healing outside a checkpoint; dying does not reset switches.
- Every interaction with a prop is a swing: switches (plan 1) and airlocks (this plan) are hit, never "used". There is no use button.
- Enemies have one hit reaction and one death; no second phases.

## Review Focus

1. **A hit on a player who is already dead** must not drive health negative or emit `died` twice. Task 1.
2. **An enemy killed by the very swing that started hit stop**: restoring process mode on a freed node is a script error. Task 4.
3. **A shot fired while the player is pressed against a wall** must free on the wall, never hit the player, never persist. Task 3.
4. **Resting at full health with no enemies to respawn** still saves and sets the checkpoint without error. Task 8.
5. **The Warden killed during its stagger, or gravity flipped during its stagger**, sets `boss_down` once and emits `died` once. Task 9.

---

### Task 1: Player health, damage, death, the hazard and the HUD

**Files:**
- Modify: `scripts/player.gd`, `scenes/Player.tscn`
- Create: `scripts/hazard.gd`, `scenes/Hazard.tscn`, `scripts/hud.gd`, `scenes/HUD.tscn`
- Test: `tests/test_health.gd`

**Interfaces:**
- Consumes: `Player` from plan 1, `Groups.HITTABLE`, `Sfx.play("hit")`, `Sfx.play("death")`.
- Produces:
  ```gdscript
  # Player additions
  const MAX_HEALTH := 5
  const INVULNERABLE := 0.6
  const KNOCKBACK_SPEED := 250.0
  const DEATH_DELAY := 1.0            # seconds the body lies there before whoever listens respawns it
  signal health_changed(health: int)
  signal died
  var health: int = MAX_HEALTH
  var invulnerable_for: float = 0.0
  var dead: bool = false              # no input, no damage while true
  func take_hit(from: Vector2) -> bool    # false if invulnerable or dead; else health -1, knockback away from `from`, invulnerable, Sfx hit; at 0 -> dead, died, Sfx death
  func heal_full() -> void
  func respawn(at: Vector2) -> void       # full health, dead false, velocity zero, grab cleared, position at
  ```
  Knockback: in gravity `velocity = Vector2(sign(global_position.x - from.x) * KNOCKBACK_SPEED, -KNOCKBACK_SPEED * 0.6)`; in zero-g `velocity += (global_position - from).normalized() * KNOCKBACK_SPEED`. Sign of zero counts as `facing * -1`.
  ```gdscript
  class_name Hazard extends StaticBody2D   # layer 2, in Groups.HITTABLE; a Hurt Area2D child (mask 1) hurts the player each physics frame it overlaps
  ```
  ```gdscript
  class_name Hud extends CanvasLayer
  func bind(player: Player) -> void   # follows health_changed
  func pips_lit() -> int              # how many of the five pips are drawn bright
  ```

- [ ] **Step 1: Write the failing tests**

```gdscript
extends TestCase

func test_a_hit_costs_one_and_knocks_back_in_gravity() -> void:
	var r := make_room(true)
	var p := spawn_player(Vector2(0, r.floor_y - 30))
	await physics_frames(2)
	var changes := []
	p.health_changed.connect(func(h): changes.append(h))
	assert_true(p.take_hit(Vector2(-50, r.floor_y - 30)), "hit lands")
	assert_eq(p.health, 4, "one lost")
	assert_eq(changes, [4], "signal")
	assert_true(p.velocity.x > 0.0 and p.velocity.y < 0.0, "knocked right and up, got %s" % p.velocity)
	assert_true(not p.take_hit(Vector2(-50, r.floor_y - 30)), "invulnerable right after")
	await physics_frames(frame_count(Player.INVULNERABLE) + 2)
	assert_true(p.take_hit(Vector2(-50, r.floor_y - 30)), "vulnerable again")

func test_knockback_in_zero_g_is_added_velocity() -> void:
	var r := make_room(false)
	var p := spawn_player(Vector2.ZERO)
	p.velocity = Vector2(100, 0)
	p.take_hit(Vector2(0, 50))
	assert_true(p.velocity.is_equal_approx(Vector2(100, -Player.KNOCKBACK_SPEED)), "pushed away from below, got %s" % p.velocity)

func test_death_at_zero_and_never_below() -> void:
	var r := make_room(true)
	var p := spawn_player(Vector2(0, r.floor_y - 30))
	var deaths := 0
	p.died.connect(func(): deaths += 1)
	for i in range(5):
		p.invulnerable_for = 0.0
		p.take_hit(Vector2(10, 0))
	assert_true(p.dead, "dead at zero")
	assert_eq(deaths, 1, "died once")
	p.invulnerable_for = 0.0
	assert_true(not p.take_hit(Vector2(10, 0)), "the dead take no hits")
	assert_eq(p.health, 0, "never negative")
	p.input_override.aim = Vector2.RIGHT
	await physics_frames(10)
	assert_true(absf(p.velocity.x) < 1.0, "no input while dead")

func test_respawn_restores_everything() -> void:
	var r := make_room(true)
	var p := spawn_player(Vector2(0, r.floor_y - 30))
	for i in range(5):
		p.invulnerable_for = 0.0
		p.take_hit(Vector2(10, 0))
	p.respawn(Vector2(300, r.floor_y - 30))
	assert_true(not p.dead and p.health == Player.MAX_HEALTH, "alive and full")
	assert_eq(p.global_position, Vector2(300, r.floor_y - 30), "moved")
	assert_eq(p.velocity, Vector2.ZERO, "still")

func test_a_hazard_hurts_on_contact_and_can_be_pogoed() -> void:
	var r := make_room(true)
	var h: Hazard = add(load("res://scenes/Hazard.tscn").instantiate())
	h.position = Vector2(0, r.floor_y - 10)
	var p := spawn_player(Vector2(0, r.floor_y - 40))
	await physics_frames(5)
	assert_eq(p.health, 4, "touched the hazard once in the invulnerability window")
	assert_true(h.is_in_group(Groups.HITTABLE), "pogo target")

func test_hud_pips_follow_health() -> void:
	var r := make_room(true)
	var p := spawn_player(Vector2(0, r.floor_y - 30))
	var hud: Hud = add(load("res://scenes/HUD.tscn").instantiate())
	hud.bind(p)
	assert_eq(hud.pips_lit(), 5, "full")
	p.take_hit(Vector2(10, 0))
	assert_eq(hud.pips_lit(), 4, "one dark")
```

- [ ] **Step 2: Run to verify failure**

Run: `godot --headless --fixed-fps 60 -s tests/run_tests.gd`
Expected: `test_health.gd does not compile`.

- [ ] **Step 3: Implement**

`Player`: skip input and mode steps while `dead`; in gravity still apply `GRAVITY`, bring `velocity.x` to zero by `RUN_ACCEL`, and `move_and_slide` so the body lands and stops. `Hazard.tscn`: `StaticBody2D` layer 2 with a `CollisionShape2D` (`RectangleShape2D` 40 by 20), a hot-coloured `Polygon2D` of spikes, and a `Hurt` `Area2D` child (mask 1) the same size. `HUD.tscn`: `CanvasLayer` with five `Polygon2D` pips at the top left, bright in the player colour when lit, dim hull colour when not.

- [ ] **Step 4: Run to verify pass**

- [ ] **Step 5: Commit**

```bash
git add scripts/player.gd scenes/Player.tscn scripts/hazard.gd scripts/hazard.gd.uid scenes/Hazard.tscn scripts/hud.gd scripts/hud.gd.uid scenes/HUD.tscn tests/test_health.gd tests/test_health.gd.uid
git commit -m "Player health, knockback, death and respawn; hazards; the HUD"
```

---

### Task 2: Enemy base, compartment tracker, spawner

**Files:**
- Create: `scripts/enemy.gd`, `scenes/Enemy.tscn`, `scripts/compartment_tracker.gd`, `scripts/spawner.gd`, `scenes/Spawner.tscn`
- Modify: `scripts/player.gd` (use the tracker), `scripts/groups.gd`, `scenes/Compartment.tscn`, `scenes/Vent.tscn` (masks 1 and 3)
- Test: `tests/test_enemy.gd`

**Interfaces:**
- Consumes: `Compartment` enter and exit calls, `Player.take_hit`, `Groups.HITTABLE`, `Sfx`.
- Produces:
  ```gdscript
  class_name CompartmentTracker extends RefCounted
  var compartments: Array[Compartment] = []
  func enter(c: Compartment) -> void   # no duplicates
  func exit(c: Compartment) -> void
  func zero_g() -> bool                # empty or the last has no gravity
  ```
  `Player.compartments` becomes `Player.tracker: CompartmentTracker`; `Player.in_zero_g()` delegates. Plan 1's `test_boundary.gd` changes `p.compartments.size()` to `p.tracker.compartments.size()`.
  ```gdscript
  class_name Enemy extends CharacterBody2D      # layer 3, mask 1; in Groups.HITTABLE and Groups.ENEMY
  const MAX_HEALTH := 3
  const KNOCKBACK := 150.0
  const STAGGER := 0.4
  const SHARDS := 8
  signal died
  var health: int = MAX_HEALTH
  var staggered_for: float = 0.0
  var tracker := CompartmentTracker.new()
  func in_zero_g() -> bool
  func enter_compartment(c: Compartment) -> void
  func exit_compartment(c: Compartment) -> void
  func damage(amount: int, from: Vector2, stagger: bool) -> void   # health down, knockback away from `from` at KNOCKBACK, stagger sets staggered_for, Sfx hit; at 0: die()
  func hit(from: Node2D, direction: Vector2) -> void             # the swing: damage(1, from.global_position, false)
  func die() -> void                 # died, SHARDS one-shot particles reparented to the tree, Sfx death, queue_free
  func behave(delta: float) -> void  # overridden per type; not called while staggered or dead
  ```
  `_physics_process`: tick stagger; `behave(delta)` unless staggered; `move_and_slide()`; then contact damage: every `Player` in `$Hurt.get_overlapping_bodies()` gets `take_hit(global_position)`. `Enemy.tscn`: `CollisionShape2D` (`RectangleShape2D` 32 by 32), a hot-coloured `Polygon2D` named `Body`, a `Hurt` `Area2D` (mask 1) the same size, a `Shards` `CPUParticles2D` (one shot, 8 flat quads, emitting off).
  ```gdscript
  class_name Spawner extends Marker2D           # in Groups.SPAWNER
  @export var scene: PackedScene
  var spawned: Node = null
  func spawn() -> void                          # frees the old, instantiates the new as a child at the marker
  static func respawn_all(tree: SceneTree) -> void   # spawn() on every member of Groups.SPAWNER
  ```
  `Groups` gains `ENEMY := "enemy"` and `SPAWNER := "spawner"`.

- [ ] **Step 1: Write the failing tests**

```gdscript
extends TestCase

func _enemy(at: Vector2) -> Enemy:
	var e: Enemy = load("res://scenes/Enemy.tscn").instantiate()
	e.position = at
	return add(e) as Enemy

func test_three_swings_kill_and_shards_fly() -> void:
	var r := make_room(true)
	var e := _enemy(Vector2(0, r.floor_y - 16))
	var deaths := 0
	e.died.connect(func(): deaths += 1)
	var p := spawn_player(Vector2(-60, r.floor_y - 30))
	await physics_frames(2)
	e.hit(p, Vector2.RIGHT)
	assert_eq(e.health, 2, "one damage")
	assert_true(e.velocity.x > 0.0, "knocked away from the player")
	assert_eq(e.staggered_for, 0.0, "a swing does not stagger")
	e.hit(p, Vector2.RIGHT)
	e.hit(p, Vector2.RIGHT)
	assert_eq(deaths, 1, "died")
	await physics_frames(2)
	assert_true(not is_instance_valid(e), "gone")
	assert_true(tree.root.get_children().any(func(n): return n is CPUParticles2D and n.emitting), "shards left behind")

func test_a_shot_staggers() -> void:
	var r := make_room(false)
	var e := _enemy(Vector2.ZERO)
	e.damage(1, Vector2(0, 100), true)
	assert_true(absf(e.staggered_for - Enemy.STAGGER) < 0.001, "staggered")
	assert_true(e.velocity.is_equal_approx(Vector2.UP * Enemy.KNOCKBACK), "knocked up, away from below")

func test_contact_hurts_the_player_once_per_window() -> void:
	var r := make_room(true)
	var e := _enemy(Vector2(0, r.floor_y - 16))
	var p := spawn_player(Vector2(0, r.floor_y - 30))
	await physics_frames(5)
	assert_eq(p.health, 4, "one hit while overlapping")

func test_enemies_track_compartments_like_the_player() -> void:
	var r := make_room(false)
	var e := _enemy(Vector2.ZERO)
	await physics_frames(2)
	assert_true(e.in_zero_g(), "dead plates")
	assert_eq(e.tracker.compartments.size(), 1, "inside the room's compartment")

func test_spawner_respawns_a_fresh_enemy() -> void:
	var r := make_room(true)
	var s: Spawner = load("res://scenes/Spawner.tscn").instantiate()
	s.scene = load("res://scenes/Enemy.tscn")
	s.position = Vector2(100, r.floor_y - 16)
	add(s)
	await physics_frames(1)
	var first := s.spawned
	assert_true(first is Enemy, "spawned on ready")
	first.damage(3, Vector2.ZERO, false)
	await physics_frames(2)
	Spawner.respawn_all(tree)
	await physics_frames(1)
	assert_true(s.spawned is Enemy and s.spawned != first, "a new one")
	assert_eq(s.spawned.health, Enemy.MAX_HEALTH, "at full health")
```

- [ ] **Step 2: Run to verify failure**

- [ ] **Step 3: Implement, including the `Player` refactor onto `CompartmentTracker` and the mask changes**

- [ ] **Step 4: Run to verify pass, plan 1's boundary tests included**

- [ ] **Step 5: Commit**

```bash
git add scripts/enemy.gd scripts/compartment_tracker.gd scripts/spawner.gd scripts/*.uid scenes/Enemy.tscn scenes/Spawner.tscn scripts/player.gd scripts/groups.gd scenes/Compartment.tscn scenes/Vent.tscn tests/test_enemy.gd tests/test_enemy.gd.uid tests/test_boundary.gd
git commit -m "Enemy base: health, knockback, stagger, contact damage, death; spawners; shared compartment tracker"
```

---

### Task 3: The shot

**Files:**
- Create: `scripts/shot.gd`, `scenes/Shot.tscn`
- Modify: `scripts/player.gd` (spawn on fire)
- Test: `tests/test_shot.gd`

**Interfaces:**
- Consumes: `Player.fired(direction)`, `Enemy.damage`, `Player.take_hit`.
- Produces:
  ```gdscript
  class_name Shot extends Area2D        # no layer; mask 1 and 3
  const SPEED := 700.0
  const LIFETIME := 1.0
  const ENEMY_SPEED := 180.0
  const ENEMY_LIFETIME := 3.0
  var direction: Vector2
  var shooter: Node2D                   # never hit
  var from_player: bool = true
  static func spawn(parent: Node, shooter: Node2D, at: Vector2, direction: Vector2, from_player: bool) -> Shot
  ```
  Moves `direction * speed` per second (speed and lifetime by team). On `body_entered`: ignore `shooter`; a player shot on an `Enemy` calls `damage(1, global_position, true)`; an enemy shot on a `Player` calls `take_hit(global_position)`; any other body is a wall. Every non-shooter contact frees the shot. `Player.fire` spawns one at `global_position + direction * 24` under the player's parent.

- [ ] **Step 1: Write the failing tests**

```gdscript
extends TestCase

func test_a_player_shot_chips_and_staggers_an_enemy_then_dies() -> void:
	var r := make_room(false)
	var e: Enemy = add(load("res://scenes/Enemy.tscn").instantiate())
	e.position = Vector2(200, 0)
	var p := spawn_player(Vector2.ZERO)
	p.input_override.aim = Vector2.RIGHT
	p.input_override.fire_pressed = true
	await physics_frames(1)
	p.input_override.fire_pressed = false
	var shot := tree.root.get_children().filter(func(n): return n is Shot)
	assert_eq(shot.size(), 1, "one shot in flight")
	await physics_frames(frame_count(0.4))
	assert_eq(e.health, 2, "chipped")
	assert_true(e.staggered_for > 0.0, "staggered")
	assert_true(tree.root.get_children().filter(func(n): return n is Shot).is_empty(), "shot gone")

func test_a_shot_dies_on_a_wall_and_never_hits_its_shooter() -> void:
	var r := make_room(false)
	var p := spawn_player(Vector2(980, 0))   # against the right wall
	p.input_override.aim = Vector2.RIGHT
	p.input_override.fire_pressed = true
	await physics_frames(3)
	assert_eq(p.health, Player.MAX_HEALTH, "did not shoot itself")
	assert_true(tree.root.get_children().filter(func(n): return n is Shot).is_empty(), "freed on the wall")

func test_a_shot_expires() -> void:
	var r := make_room(false, Vector2(4000, 1200))
	var s := Shot.spawn(tree.root, null, Vector2.ZERO, Vector2.RIGHT, true)
	await physics_frames(frame_count(Shot.LIFETIME) + 2)
	assert_true(not is_instance_valid(s), "gone after its lifetime")

func test_an_enemy_shot_hurts_the_player() -> void:
	var r := make_room(false)
	var p := spawn_player(Vector2.ZERO)
	Shot.spawn(tree.root, null, Vector2(-100, 0), Vector2.RIGHT, false)
	await physics_frames(frame_count(1.0))
	assert_eq(p.health, 4, "hit by the slow shot")
```

- [ ] **Step 2: Run to verify failure**

- [ ] **Step 3: Implement**

`Shot.tscn`: `Area2D` with a `CollisionShape2D` (`CircleShape2D` radius 4) and a bright `Polygon2D` streak; `Sfx.play("shot")` stays on `Player.fire`.

- [ ] **Step 4: Run to verify pass**

- [ ] **Step 5: Commit**

```bash
git add scripts/shot.gd scripts/shot.gd.uid scenes/Shot.tscn scripts/player.gd tests/test_shot.gd tests/test_shot.gd.uid
git commit -m "Shot: the player's chip-and-stagger projectile and the enemies' slow one"
```

---

### Task 4: Hit stop and the flash

**Files:**
- Create: `scripts/hit_stop.gd`
- Modify: `scripts/player.gd` (on a swing landing on an `Enemy`), `scripts/enemy.gd` (flash)
- Test: `tests/test_hit_stop.gd`

**Interfaces:**
- Consumes: `Swing.landed`, `Player._on_swing_landed`.
- Produces:
  ```gdscript
  class_name HitStop extends RefCounted
  const FRAMES := 3
  static func freeze(tree: SceneTree, nodes: Array, frames: int = FRAMES) -> void   # process_mode DISABLED on each valid node, `frames` physics frames, then PROCESS_MODE_INHERIT on each node still valid
  ```
  `Player._on_swing_landed` calls `HitStop.freeze(get_tree(), [self, target])` when `target is Enemy`, after `target.hit(...)`. `Enemy.damage` sets `$Body.modulate` to white and restores it after `HitStop.FRAMES` frames.

- [ ] **Step 1: Write the failing tests**

```gdscript
extends TestCase

func test_a_landed_swing_freezes_both_for_three_frames() -> void:
	var r := make_room(false)
	var e: Enemy = add(load("res://scenes/Enemy.tscn").instantiate())
	e.position = Vector2(Swing.REACH + 10, 0)
	var p := spawn_player(Vector2.ZERO)
	p.velocity = Vector2(0, 50)
	p.input_override.aim = Vector2.RIGHT
	p.input_override.swing_pressed = true
	await physics_frames(2)
	p.input_override.swing_pressed = false
	var frozen_at := p.global_position
	await physics_frames(HitStop.FRAMES - 1)
	assert_eq(p.global_position, frozen_at, "the player holds still")
	assert_eq(p.process_mode, Node.PROCESS_MODE_DISABLED, "frozen")
	await physics_frames(3)
	assert_eq(p.process_mode, Node.PROCESS_MODE_INHERIT, "thawed")
	assert_true(p.global_position != frozen_at, "moving again")

func test_killing_with_the_freezing_swing_is_not_an_error() -> void:
	var r := make_room(false)
	var e: Enemy = add(load("res://scenes/Enemy.tscn").instantiate())
	e.position = Vector2(Swing.REACH + 10, 0)
	e.health = 1
	var p := spawn_player(Vector2.ZERO)
	p.input_override.aim = Vector2.RIGHT
	p.input_override.swing_pressed = true
	await physics_frames(HitStop.FRAMES + 4)
	assert_true(not is_instance_valid(e), "dead")
	assert_eq(p.process_mode, Node.PROCESS_MODE_INHERIT, "player thawed with no error on the freed enemy")
```

- [ ] **Step 2: Run to verify failure**

- [ ] **Step 3: Implement**

- [ ] **Step 4: Run to verify pass**

- [ ] **Step 5: Commit**

```bash
git add scripts/hit_stop.gd scripts/hit_stop.gd.uid scripts/player.gd scripts/enemy.gd tests/test_hit_stop.gd tests/test_hit_stop.gd.uid
git commit -m "Hit stop and the flash to white"
```

---

### Task 5: Hull mite

**Files:**
- Create: `scripts/mite.gd`, `scenes/Mite.tscn`
- Test: `tests/test_mite.gd`

**Interfaces:**
- Consumes: `Enemy`.
- Produces:
  ```gdscript
  class_name Mite extends Enemy
  const SPEED := 60.0
  const PROBE := 4.0                     # how far past the feet it looks for ground
  const RADIUS := 8.0
  var normal: Vector2 = Vector2.UP       # away from the surface it stands on
  var turn: int = 1                      # +1 or -1: which way around the surface it crawls
  func tangent() -> Vector2              # Vector2(-normal.y, normal.x) * turn
  ```
  `behave` ignores gravity entirely in both states; the mite is stuck to its surface. Its collision shape is a `CircleShape2D` of `RADIUS := 8.0`, so turning never overlaps a corner; only the `Polygon2D` rotates, to `normal.angle() + PI / 2`. Each frame: try `move_and_collide(tangent() * SPEED * delta)`. A collision is a concave corner: `normal` becomes the collision normal, no shift. No collision: probe `test_move(global_transform, -normal * PROBE)`; if nothing is there it is a convex corner: `normal` becomes the old tangent and the body shifts by `(new_normal - old_normal) * RADIUS` so the circle sits on the new face. Velocity stays zero (knockback from `damage` is applied as a one-frame displacement instead: `global_position += velocity * delta; velocity = ZERO` at the start of `behave`). The scene is `Enemy.tscn` with the circle shape and a many-legged `Polygon2D`.

- [ ] **Step 1: Write the failing tests**

```gdscript
extends TestCase

## A free-floating 200 by 100 block in a zero-g room; the mite starts on its top.
func _block_and_mite() -> Array:
	var r := make_room(false)
	var block := StaticBody2D.new()
	var shape := CollisionShape2D.new()
	shape.shape = RectangleShape2D.new()
	shape.shape.size = Vector2(200, 100)
	block.add_child(shape)
	add(block)
	var m: Mite = load("res://scenes/Mite.tscn").instantiate()
	m.position = Vector2(0, -50 - Mite.RADIUS)
	add(m)
	return [block, m]

func test_crawls_round_every_face_of_a_block_and_never_leaves_it() -> void:
	var pair := _block_and_mite()
	var m: Mite = pair[1]
	var normals_seen := {}
	for i in range(frame_count(12.0)):
		await physics_frames(1)
		normals_seen[m.normal.round()] = true
		var inside := Rect2(Vector2(-100, -50), Vector2(200, 100)).grow(20.0)
		assert_true(inside.has_point(m.global_position), "left the block at frame %d: %s" % [i, m.global_position])
		if normals_seen.size() == 4:
			break
	assert_eq(normals_seen.size(), 4, "visited all four faces: %s" % normals_seen.keys())

func test_turns_at_a_concave_corner() -> void:
	var r := make_room(true)
	var m: Mite = load("res://scenes/Mite.tscn").instantiate()
	m.position = Vector2(950, r.floor_y - Mite.RADIUS)
	add(m)
	await physics_frames(frame_count(2.0))
	assert_true(m.normal.is_equal_approx(Vector2.LEFT), "now on the right wall, got %s" % m.normal)
	assert_true(m.global_position.y < r.floor_y - 40, "climbing it")

func test_ignores_gravity() -> void:
	var r := make_room(true)
	var m: Mite = load("res://scenes/Mite.tscn").instantiate()
	m.position = Vector2(0, r.floor_y - 300)
	m.normal = Vector2.DOWN   # standing on a ceiling that is not there
	add(m)
	await physics_frames(10)
	assert_true(m.global_position.y < r.floor_y - 200, "did not fall")
```

- [ ] **Step 2: Run to verify failure**

- [ ] **Step 3: Implement**

- [ ] **Step 4: Run to verify pass**

- [ ] **Step 5: Commit**

```bash
git add scripts/mite.gd scripts/mite.gd.uid scenes/Mite.tscn tests/test_mite.gd tests/test_mite.gd.uid
git commit -m "Hull mite: crawls round any surface in either state"
```

---

### Task 6: Drone

**Files:**
- Create: `scripts/drone.gd`, `scenes/Drone.tscn`
- Test: `tests/test_drone.gd`

**Interfaces:**
- Consumes: `Enemy`, `Player`.
- Produces:
  ```gdscript
  class_name Drone extends Enemy
  const RANGE := 400.0
  const WINDUP := 0.6
  const CHARGE_SPEED := 450.0
  const CHARGE_TIME := 0.5
  const REST := 1.0
  const HOVER_HEIGHT := 70.0           # above the floor, in gravity
  const DRIFT_SPEED := 40.0            # toward the player while hovering in zero-g
  enum State { HOVER, WINDUP, CHARGE, REST }
  var state: State = State.HOVER
  var target: Player = null            # the nearest Player in the tree, found each frame
  var charge_direction: Vector2
  ```
  The drone ignores gravity physics. In gravity, `behave` holds `global_position.y` at `HOVER_HEIGHT` above the floor found by a downward `RayCast2D` named `Down` (length 600), moving toward it at `CHARGE_SPEED` when off; horizontal velocity is zero while hovering. In zero-g it drifts toward the player at `DRIFT_SPEED`. Within `RANGE`, hovering or not: `WINDUP` for `WINDUP` seconds (`$Body` scales up 1.3), then `CHARGE` along `charge_direction` taken at the end of the wind-up: in gravity the horizontal sign toward the player only; in zero-g the full direction. Charge ends after `CHARGE_TIME` or on a slide collision, then `REST`. A stagger (`staggered_for > 0`) returns the state to `HOVER` with zero velocity. `$Body` faces `target` (flip x).

- [ ] **Step 1: Write the failing tests**

```gdscript
extends TestCase

func _drone(at: Vector2) -> Drone:
	var d: Drone = load("res://scenes/Drone.tscn").instantiate()
	d.position = at
	return add(d) as Drone

func test_hovers_at_height_in_gravity_and_charges_level() -> void:
	var r := make_room(true)
	var d := _drone(Vector2(0, r.floor_y - 300))
	var p := spawn_player(Vector2(-380, r.floor_y - 30))   # in range, beyond one charge's length
	await physics_frames(frame_count(Drone.WINDUP + 0.2))
	assert_true(absf(d.global_position.y - (r.floor_y - Drone.HOVER_HEIGHT)) < 4.0, "at hover height, got %f" % d.global_position.y)
	assert_eq(d.state, Drone.State.CHARGE, "charging")
	assert_true(d.velocity.x < 0.0 and absf(d.velocity.y) < 1.0, "level charge toward the player, got %s" % d.velocity)
	assert_true(absf(d.velocity.length() - Drone.CHARGE_SPEED) < 1.0, "at charge speed")

func test_charges_along_the_full_line_in_zero_g() -> void:
	var r := make_room(false)
	var d := _drone(Vector2.ZERO)
	var p := spawn_player(Vector2(200, 200))
	await physics_frames(frame_count(Drone.WINDUP) + 4)
	assert_eq(d.state, Drone.State.CHARGE, "charging")
	assert_true(d.velocity.normalized().dot(Vector2(1, 1).normalized()) > 0.999, "diagonal, got %s" % d.velocity)

func test_a_shot_cancels_the_charge() -> void:
	var r := make_room(false)
	var d := _drone(Vector2.ZERO)
	var p := spawn_player(Vector2(300, 0))
	await physics_frames(frame_count(Drone.WINDUP) + 4)
	assert_eq(d.state, Drone.State.CHARGE, "charging")
	d.damage(1, p.global_position, true)
	await physics_frames(1)
	assert_eq(d.state, Drone.State.HOVER, "cancelled")
	assert_eq(d.velocity, Vector2.ZERO, "stopped")

func test_out_of_range_it_only_hovers() -> void:
	var r := make_room(false, Vector2(3000, 1200))
	var d := _drone(Vector2(-1200, 0))
	var p := spawn_player(Vector2(1200, 0))
	await physics_frames(frame_count(1.5))
	assert_eq(d.state, Drone.State.HOVER, "hovering")
	assert_true(d.velocity.length() <= Drone.DRIFT_SPEED + 1.0, "drifting at most")
```

- [ ] **Step 2: Run to verify failure**

- [ ] **Step 3: Implement**

`Drone.tscn`: `Enemy.tscn` with a `RayCast2D` named `Down` and a round `Polygon2D` body with one bright eye.

- [ ] **Step 4: Run to verify pass**

- [ ] **Step 5: Commit**

```bash
git add scripts/drone.gd scripts/drone.gd.uid scenes/Drone.tscn tests/test_drone.gd tests/test_drone.gd.uid
git commit -m "Drone: hovers, winds up, charges; level in gravity, anywhere in zero-g"
```

---

### Task 7: Clinger

**Files:**
- Create: `scripts/clinger.gd`, `scenes/Clinger.tscn`
- Test: `tests/test_clinger.gd`

**Interfaces:**
- Consumes: `Enemy`, `Shot.spawn`, `Vent`.
- Produces:
  ```gdscript
  class_name Clinger extends Enemy
  const RANGE := 500.0
  const PERIOD := 2.0
  var since_shot: float = 0.0
  ```
  `behave`: fire `Shot.spawn(get_parent(), self, global_position, (player - self).normalized(), false)` every `PERIOD` seconds while a `Player` is within `RANGE`. In gravity: `velocity.y += Player.GRAVITY * delta` until on the floor, then zero; no horizontal motion. In zero-g: velocity is left alone (drift; vents push it through the shared `velocity`). Scene: `Enemy.tscn` with a squat `Polygon2D` and a bright mouth.

- [ ] **Step 1: Write the failing tests**

```gdscript
extends TestCase

func _clinger(at: Vector2) -> Clinger:
	var c: Clinger = load("res://scenes/Clinger.tscn").instantiate()
	c.position = at
	return add(c) as Clinger

func _shots() -> Array:
	return tree.root.get_children().filter(func(n): return n is Shot and not n.from_player)

func test_fixed_in_gravity_and_shoots_on_a_period() -> void:
	var r := make_room(true)
	var c := _clinger(Vector2(0, r.floor_y - 16))
	var p := spawn_player(Vector2(300, r.floor_y - 30))
	await physics_frames(frame_count(Clinger.PERIOD * 2.5))
	assert_true(absf(c.global_position.x) < 1.0, "has not moved")
	assert_true(p.health <= 4, "the player has been shot")
	assert_true(_shots().size() <= 1, "one slow shot at a time, about")

func test_becomes_debris_in_zero_g_and_rides_the_vent() -> void:
	var r := make_room(false)
	var v: Vent = load("res://scenes/Vent.tscn").instantiate()
	(v.get_node("Bounds") as CollisionShape2D).shape.size = Vector2(1800, 1000)
	add(v)
	var c := _clinger(Vector2(-500, 0))
	WorldState.set_vents(true)
	await physics_frames(frame_count(0.5))
	assert_true(c.velocity.x > Vent.FORCE_ZERO_G * 0.4, "pushed, got %f" % c.velocity.x)

func test_keeps_shooting_while_drifting() -> void:
	var r := make_room(false)
	var c := _clinger(Vector2(-300, 0))
	c.velocity = Vector2(50, 0)
	var p := spawn_player(Vector2(200, 0))
	await physics_frames(frame_count(Clinger.PERIOD + 0.2))
	assert_true(_shots().size() >= 1 or p.health < Player.MAX_HEALTH, "shot while moving")
```

- [ ] **Step 2: Run to verify failure**

- [ ] **Step 3: Implement**

- [ ] **Step 4: Run to verify pass**

- [ ] **Step 5: Commit**

```bash
git add scripts/clinger.gd scripts/clinger.gd.uid scenes/Clinger.tscn tests/test_clinger.gd tests/test_clinger.gd.uid
git commit -m "Clinger: a turret in gravity, drifting debris that still shoots in zero-g"
```

---

### Task 8: Airlock checkpoints and the death flow

**Files:**
- Create: `scripts/checkpoint.gd`, `scenes/Checkpoint.tscn`, `scripts/respawner.gd`
- Test: `tests/test_checkpoint.gd`

**Interfaces:**
- Consumes: `Player.heal_full`, `Player.respawn`, `Player.died`, `WorldState.set_checkpoint`, `WorldState.save`, `Spawner.respawn_all`, `Groups.HITTABLE`.
- Produces:
  ```gdscript
  class_name Checkpoint extends StaticBody2D     # layer 2, in Groups.HITTABLE and Groups.CHECKPOINT
  @export var room_name: String = ""
  signal rested
  func hit(from: Node2D, direction: Vector2) -> void   # a Player swinging at it rests
  func rest(player: Player) -> void      # heal_full, WorldState.set_checkpoint(room_name), WorldState.save(), Spawner.respawn_all, Sfx hatch, rested
  func spawn_point() -> Vector2          # global position of the Marker2D child named Spawn
  ```
  ```gdscript
  class_name Respawner extends Node       # the death flow, until plan 3's game controller owns it
  func bind(player: Player, checkpoint_lookup: Callable) -> void   # lookup(room_name) -> Checkpoint or null
  ```
  On `died`: wait `Player.DEATH_DELAY`, find the checkpoint for `WorldState.checkpoint` (empty: the first `Groups.CHECKPOINT` member), `Spawner.respawn_all`, `player.respawn(checkpoint.spawn_point())`. `Groups` gains `CHECKPOINT := "checkpoint"`. Scene: a tall airlock door in two `Polygon2D` leaves, bright, with a `CollisionShape2D` 32 by 80 and a `Spawn` marker at its foot.

- [ ] **Step 1: Write the failing tests**

```gdscript
extends TestCase

func _airlock(at: Vector2, room: String) -> Checkpoint:
	var c: Checkpoint = load("res://scenes/Checkpoint.tscn").instantiate()
	c.position = at
	c.room_name = room
	return add(c) as Checkpoint

func test_a_swing_rests_heals_saves_and_respawns_enemies() -> void:
	var r := make_room(true)
	var a := _airlock(Vector2(Swing.REACH, r.floor_y - 40), "Dock")
	var s: Spawner = load("res://scenes/Spawner.tscn").instantiate()
	s.scene = load("res://scenes/Enemy.tscn")
	s.position = Vector2(400, r.floor_y - 16)
	add(s)
	await physics_frames(1)
	s.spawned.damage(3, Vector2.ZERO, false)
	var p := spawn_player(Vector2(0, r.floor_y - 30))
	p.take_hit(Vector2(-10, 0))
	p.invulnerable_for = 0.0
	await physics_frames(2)
	p.input_override.swing_pressed = true
	await physics_frames(3)
	p.input_override.swing_pressed = false
	assert_eq(p.health, Player.MAX_HEALTH, "healed")
	assert_eq(WorldState.checkpoint, "Dock", "checkpoint set")
	WorldState.reset()
	assert_true(WorldState.load() and WorldState.checkpoint == "Dock", "saved")
	assert_true(s.spawned is Enemy and s.spawned.health == Enemy.MAX_HEALTH, "enemies back")

func test_resting_at_full_health_with_nothing_to_respawn_is_fine() -> void:
	var r := make_room(true)
	var a := _airlock(Vector2.ZERO, "Ring Deck")
	var p := spawn_player(Vector2(0, r.floor_y - 30))
	a.rest(p)
	assert_eq(WorldState.checkpoint, "Ring Deck", "set")

func test_death_returns_you_to_the_checkpoint_with_the_world_as_you_left_it() -> void:
	var r := make_room(true)
	var a := _airlock(Vector2(600, r.floor_y - 40), "Dock")
	var p := spawn_player(Vector2(0, r.floor_y - 30))
	var re := add(Respawner.new()) as Respawner
	re.bind(p, func(name): return a if a.room_name == name else null)
	a.rest(p)
	WorldState.set_ring(false)
	for i in range(5):
		p.invulnerable_for = 0.0
		p.take_hit(Vector2(10, 0))
	assert_true(p.dead, "dead")
	await physics_frames(frame_count(Player.DEATH_DELAY) + 3)
	assert_true(not p.dead, "back")
	assert_true(p.global_position.distance_to(a.spawn_point()) < 2.0, "at the airlock")
	assert_true(not WorldState.ring_on, "switches untouched by death")
```

- [ ] **Step 2: Run to verify failure**

- [ ] **Step 3: Implement**

- [ ] **Step 4: Run to verify pass**

- [ ] **Step 5: Commit**

```bash
git add scripts/checkpoint.gd scripts/respawner.gd scripts/*.uid scenes/Checkpoint.tscn scripts/groups.gd tests/test_checkpoint.gd tests/test_checkpoint.gd.uid
git commit -m "Airlock checkpoints: swing to rest; death returns you there with the world unchanged"
```

---

### Task 9: The Warden

**Files:**
- Create: `scripts/warden.gd`, `scenes/Warden.tscn`
- Test: `tests/test_warden.gd`

**Interfaces:**
- Consumes: `Enemy`, `WorldState.ring_on`, `WorldState.set_boss_down`, `Player`.
- Produces:
  ```gdscript
  class_name Warden extends Enemy
  const MAX_HEALTH_WARDEN := 24
  const HALF_SIZE := 50.0
  const HOVER_HEIGHT := 280.0          # gravity: above the floor, out of reach
  const ARC_SPEED := 300.0
  const ARC_AMPLITUDE := 40.0
  const ARC_PERIOD := 2.5
  const ZERO_G_WINDUP := 0.4
  const CHARGE_SPEED := 520.0
  const CHARGE_TIME := 0.6
  const CHARGE_REST := 1.5
  const STAGGER_TIME := 2.0
  const STAGGER_HEIGHT := 60.0         # it sinks to here, within reach
  const REPAIR_AFTER := 3.0            # seconds without damage, gravity on, before it repairs
  const REPAIR_INTERVAL := 1.5         # one health per
  enum State { ARC, WINDUP, CHARGE, REST, STAGGER }
  var state: State
  var since_damage: float = 0.0
  var was_zero_g: bool
  ```
  `_ready` sets `health = MAX_HEALTH_WARDEN`; in zero-g it starts in `WINDUP`, in gravity in `ARC`. `damage(amount, from, stagger)` ignores `stagger` (shots chip, never stagger it) and resets `since_damage`. `behave`: in gravity, `ARC`: sweep horizontally across the arena at `ARC_SPEED`, turning at walls, `y = floor - HOVER_HEIGHT + sin(t * TAU / ARC_PERIOD) * ARC_AMPLITUDE`; repair one health every `REPAIR_INTERVAL` once `since_damage > REPAIR_AFTER`. In zero-g, `WINDUP` then `CHARGE` straight at the player, then `REST` drifting at 60 px/s toward the player, repeat; no repair. Transition: when `in_zero_g()` turns false while `state == CHARGE`, enter `STAGGER` for `STAGGER_TIME`: velocity zero, sink to `floor - STAGGER_HEIGHT` at `ARC_SPEED`, then back to `ARC`. `die()` calls `WorldState.set_boss_down()` once and triples the shards. Contact damage as any enemy. Scene: `Enemy.tscn` with a 100 by 100 collision box and a heavy `Polygon2D` body with a bright ring of lights.

- [ ] **Step 1: Write the failing tests**

```gdscript
extends TestCase

func _warden(at: Vector2) -> Warden:
	var w: Warden = load("res://scenes/Warden.tscn").instantiate()
	w.position = at
	return add(w) as Warden

func test_out_of_reach_by_design_in_gravity() -> void:
	var jump_height := Player.JUMP_SPEED * Player.JUMP_SPEED / (2.0 * Player.GRAVITY)
	var up_swing_top := jump_height + 22.0 + Swing.REACH + 14.0
	assert_true(Warden.HOVER_HEIGHT - Warden.ARC_AMPLITUDE - Warden.HALF_SIZE > up_swing_top, "the lowest point of the arc is above an up-swing at the apex of a jump")
	assert_true(Warden.STAGGER_HEIGHT + Warden.HALF_SIZE < up_swing_top, "staggered, it is within reach")

func test_arcs_and_repairs_in_gravity() -> void:
	var r := make_room(true, Vector2(2000, 1200))
	var w := _warden(Vector2(0, r.floor_y - Warden.HOVER_HEIGHT))
	var p := spawn_player(Vector2(-800, r.floor_y - 30))
	await physics_frames(frame_count(1.0))
	assert_eq(w.state, Warden.State.ARC, "arcing")
	assert_true(absf(w.velocity.x) > Warden.ARC_SPEED - 1.0, "sweeping")
	assert_true(absf(w.global_position.y - (r.floor_y - Warden.HOVER_HEIGHT)) <= Warden.ARC_AMPLITUDE + 2.0, "near hover height")
	w.damage(1, p.global_position, true)
	assert_eq(w.health, Warden.MAX_HEALTH_WARDEN - 1, "chipped")
	assert_eq(w.staggered_for, 0.0, "a shot does not stagger it")
	await physics_frames(frame_count(Warden.REPAIR_AFTER + Warden.REPAIR_INTERVAL + 0.1))
	assert_eq(w.health, Warden.MAX_HEALTH_WARDEN, "repaired")

func test_charges_in_zero_g_and_never_repairs_there() -> void:
	var r := make_room(false, Vector2(2000, 1200))
	var w := _warden(Vector2.ZERO)
	var p := spawn_player(Vector2(500, 0))
	w.damage(1, p.global_position, false)
	await physics_frames(frame_count(Warden.ZERO_G_WINDUP) + 3)
	assert_eq(w.state, Warden.State.CHARGE, "charging")
	assert_true(w.velocity.x > 0.0 and absf(w.velocity.length() - Warden.CHARGE_SPEED) < 1.0, "at the player")
	await physics_frames(frame_count(Warden.REPAIR_AFTER + Warden.REPAIR_INTERVAL + 0.5))
	assert_eq(w.health, Warden.MAX_HEALTH_WARDEN - 1, "no repair in zero-g")

func test_gravity_returning_mid_charge_staggers_it_into_reach() -> void:
	var r := make_room(true, Vector2(2000, 1200))
	WorldState.set_ring(false)
	var w := _warden(Vector2(0, r.floor_y - 200))
	var p := spawn_player(Vector2(500, r.floor_y - 200))
	await physics_frames(frame_count(Warden.ZERO_G_WINDUP) + 3)
	assert_eq(w.state, Warden.State.CHARGE, "charging")
	WorldState.set_ring(true)
	await physics_frames(2)
	assert_eq(w.state, Warden.State.STAGGER, "staggered")
	await physics_frames(frame_count(1.0))
	assert_true(absf(w.global_position.y - (r.floor_y - Warden.STAGGER_HEIGHT)) < 4.0, "sunk into reach, got %f" % w.global_position.y)
	await physics_frames(frame_count(Warden.STAGGER_TIME))
	assert_eq(w.state, Warden.State.ARC, "back up")

func test_death_sets_boss_down_once_even_during_a_stagger() -> void:
	var r := make_room(true, Vector2(2000, 1200))
	WorldState.set_ring(false)
	var w := _warden(Vector2.ZERO)
	var p := spawn_player(Vector2(500, 0))
	var deaths := 0
	w.died.connect(func(): deaths += 1)
	await physics_frames(frame_count(Warden.ZERO_G_WINDUP) + 3)
	WorldState.set_ring(true)
	await physics_frames(2)
	w.damage(Warden.MAX_HEALTH_WARDEN, p.global_position, false)
	WorldState.set_ring(false)
	await physics_frames(3)
	assert_true(WorldState.boss_down, "boss down")
	assert_eq(deaths, 1, "once")
```

- [ ] **Step 2: Run to verify failure**

- [ ] **Step 3: Implement**

- [ ] **Step 4: Run to verify pass**

- [ ] **Step 5: Commit**

```bash
git add scripts/warden.gd scripts/warden.gd.uid scenes/Warden.tscn tests/test_warden.gd tests/test_warden.gd.uid
git commit -m "The Warden: out of reach in gravity, lethal and reachable in zero-g, staggered by the switch"
```

---

### Task 10: Rigs and poses

**Files:**
- Create: `scripts/rig.gd`
- Modify: `scenes/Player.tscn`, `scenes/Mite.tscn`, `scenes/Drone.tscn`, `scenes/Clinger.tscn`, `scenes/Warden.tscn`, `scripts/player.gd`
- Test: `tests/test_rig.gd`

**Interfaces:**
- Produces:
  ```gdscript
  class_name Rig extends Node2D         # a Skeleton2D with Polygon2D parts, an AnimationPlayer named Anim, a Line2D named Cloth
  const POSES := ["idle", "run", "jump", "swing", "hit", "death"]
  func play(pose: String) -> void       # no restart when already playing it, except "swing" and "hit"
  func face(direction: int) -> void     # flips x
  func tilt_into(velocity: Vector2, zero_g: bool) -> void   # zero_g: rotation = clamp(velocity.x / 400, -1, 1) * 35 degrees, cloth trails opposite the velocity; gravity: rotation 0
  ```
  `Player` picks the pose each frame: `dead` -> death; swing active -> swing; `invulnerable_for > INVULNERABLE - 0.2` -> hit; in gravity: on floor and moving -> run, on floor -> idle, in the air -> jump; in zero-g: jump when drifting, idle when grabbed. Enemies get a `Rig` with `idle` and `hit` only (the Warden adds `swing` for its charge). All parts are `Polygon2D` in the palette; the player's cloth is a `Line2D` of 6 points.

- [ ] **Step 1: Write the failing tests**

```gdscript
extends TestCase

func test_the_player_rig_has_every_pose() -> void:
	var r := make_room(true)
	var p := spawn_player(Vector2(0, r.floor_y - 30))
	var rig: Rig = p.get_node("Rig")
	var anim: AnimationPlayer = rig.get_node("Anim")
	for pose in Rig.POSES:
		assert_true(anim.has_animation(pose), "has %s" % pose)

func test_poses_follow_movement() -> void:
	var r := make_room(true)
	var p := spawn_player(Vector2(0, r.floor_y - 30))
	await physics_frames(3)
	var anim: AnimationPlayer = p.get_node("Rig/Anim")
	assert_eq(anim.current_animation, "idle", "standing")
	p.input_override.aim = Vector2.RIGHT
	await physics_frames(3)
	assert_eq(anim.current_animation, "run", "running")
	p.input_override.jump_pressed = true
	p.input_override.jump_held = true
	await physics_frames(2)
	assert_eq(anim.current_animation, "jump", "in the air")

func test_tilts_into_velocity_only_in_zero_g() -> void:
	var r := make_room(false)
	var p := spawn_player(Vector2.ZERO)
	p.velocity = Vector2(200, 0)
	await physics_frames(3)
	var rig: Rig = p.get_node("Rig")
	assert_true(absf(rig.rotation) > 0.1, "tilted, got %f" % rig.rotation)
	assert_true(absf(rig.rotation) <= deg_to_rad(35.0) + 0.01, "capped")
	var g := make_room(true, Vector2(2000, 1200), Vector2(5000, 0))
	p.global_position = Vector2(5000, g.floor_y - 30)
	await physics_frames(5)
	assert_eq(rig.rotation, 0.0, "upright in gravity")

func test_every_enemy_has_a_rig_with_idle_and_hit() -> void:
	for scene in ["Mite", "Drone", "Clinger", "Warden"]:
		var e: Enemy = add(load("res://scenes/%s.tscn" % scene).instantiate())
		var anim: AnimationPlayer = e.get_node("Rig/Anim")
		assert_true(anim.has_animation("idle") and anim.has_animation("hit"), "%s poses" % scene)
```

- [ ] **Step 2: Run to verify failure**

- [ ] **Step 3: Build the rigs in the editor and write `rig.gd`**

The player rig: a torso, head, two arms and two legs as `Polygon2D` under `Skeleton2D` bones, a 6-point `Line2D` cloth from the shoulders. Poses are two-key animations (a pose and a return) except `run`, which loops four keys. `Enemy.damage` plays `hit`; `Enemy.behave` implementations play `idle`.

- [ ] **Step 4: Run to verify pass**

- [ ] **Step 5: Commit**

```bash
git add scripts/rig.gd scripts/rig.gd.uid scripts/player.gd scripts/enemy.gd scenes/Player.tscn scenes/Mite.tscn scenes/Drone.tscn scenes/Clinger.tscn scenes/Warden.tscn tests/test_rig.gd tests/test_rig.gd.uid
git commit -m "Rigs: posed polygon characters, a trailing cloth, tilt into velocity in zero-g"
```

---

### Task 11: The test room fights back, and an arena

**Files:**
- Modify: `scenes/TestRoom.tscn`, `scripts/test_room.gd`, `README.md`, `ROADMAP.md`
- Create: `scenes/TestArena.tscn`
- Test: `tests/test_scene.gd` (extend)

**Interfaces:**
- Produces: `TestRoom` with an airlock in the left compartment, spawners for two mites, a drone and a clinger, a hazard strip under the seam, the HUD bound to the player, and a `Respawner` bound to the airlock. `TestArena.tscn`: a 1600 by 800 gravity compartment with a ring `Switch` inside, an airlock at the door, a Warden spawner, the HUD and a `Respawner`; main scene stays `TestRoom`, and `--arena` (via `LaunchOptions`, ported from Down Mine) opens the arena instead.

- [ ] **Step 1: Write the failing tests**

```gdscript
func test_the_test_room_has_enemies_an_airlock_and_a_hud() -> void:
	var room = add(load("res://scenes/TestRoom.tscn").instantiate())
	await physics_frames(5)
	assert_eq(tree.get_nodes_in_group(Groups.SPAWNER).size(), 4, "four spawners")
	assert_eq(tree.get_nodes_in_group(Groups.ENEMY).size(), 4, "four enemies alive")
	assert_eq(tree.get_nodes_in_group(Groups.CHECKPOINT).size(), 1, "one airlock")
	assert_true(room.get_node("HUD") is Hud, "hud")

func test_the_arena_runs_and_the_warden_is_there() -> void:
	var arena = add(load("res://scenes/TestArena.tscn").instantiate())
	await physics_frames(60)
	assert_true(tree.get_nodes_in_group(Groups.ENEMY).any(func(e): return e is Warden), "the Warden")
	assert_true(arena.get_node("RingSwitch") is Switch, "the switch is in the room")
```

- [ ] **Step 2: Run to verify failure**

- [ ] **Step 3: Build both scenes in the editor, port `scripts/launch_options.gd` from Down Mine unchanged, extend `test_room.gd`**

- [ ] **Step 4: Run the suite, then play**

Run the suite. Then `godot -- --arena`: throw the switch, see the Warden drop into reach, hit it, throw it back, breathe. In the test room: pogo a mite, stagger the drone with C, open the vents and watch the clinger tumble, die on the hazard and wake at the airlock.

- [ ] **Step 5: README and ROADMAP**

README: a "Fighting" paragraph (swing, fire, pogo, ricochet, airlocks, what each enemy does). ROADMAP: mark M2 done, M3 next.

- [ ] **Step 6: Commit**

```bash
git add scenes/TestRoom.tscn scenes/TestArena.tscn scripts/test_room.gd scripts/launch_options.gd scripts/launch_options.gd.uid tests/test_scene.gd README.md ROADMAP.md
git commit -m "Test room with enemies and an airlock; an arena for the Warden"
```

---

## After this plan

Plan 3 (the slice) starts from: `Checkpoint.room_name` and `spawn_point()`, `Respawner.bind(player, lookup)` to be replaced by the game controller's room loading, `Spawner` as the only way enemies enter a room, `Groups.ENEMY`, `Groups.CHECKPOINT`, `Groups.SPAWNER`, `Shot.spawn`, and `Warden` as a spawner's scene in the Control Room.

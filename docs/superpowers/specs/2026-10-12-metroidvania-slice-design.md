# Metroidvania vertical slice: the Hulk

2026-10-12. Design for a new game in a new repository, agreed in conversation. This document lives in the Down Mine repository only until the new repository exists; it then moves there with the implementation plan. Numbers are starting values to tune, not commitments.

Working title: Drift (placeholder).

## Why

A metroidvania in the family of Hollow Knight and Silksong, with its own art and its own lead idea. The slice exists to answer one question: does the core loop feel right? One section of one ship, one boss, the full movement and combat kit, nothing else.

Success is a playable slice where the feel can be judged. It is not a small game and not the first milestone of a long one, though either could follow.

## What the game is known for

**The world changes because you changed it.** Progress is gated by world state the player flips, not by abilities the player gains. Metroid gates with what you carry; Zelda gates with what you did to the world. This game takes the Zelda half and makes it the lead.

Four rules keep it a dial and not a gimmick:

1. **Trade-offs, not keys.** Every switch closes something when it opens something. No state is simply better.
2. **Changes compose.** Independent switches multiply the world's states, and the player reasons about combinations.
3. **Reversible, always.** Every switch flips both ways forever. From any room in any state, a switch panel is reachable using that state's movement. A test enforces this.
4. **Seen before understood.** The player sees a switch's consequences before finding the switch.

**The switch is gravity.** The game is set aboard the Hulk, a derelict carrier drifting in a graveyard of ships. Its gravity ring can be stopped and started. With gravity a compartment is a platformer. Without it the same compartment is free movement in two dimensions, with momentum that never decays. Every room is two games.

Everything else, combat, checkpoints, exploration, map, sits at Hollow Knight's defaults in their simplest form.

## Decisions

1. **Vertical slice**, thirteen rooms, two switches, three enemies, one boss.
2. **Flat vector art**, parts animated with bones, no frame art.
3. **Keyboard first, controller supported**, web export first, desktop second. No touch in the slice.
4. **Light melee plus a gun that is also the thruster.** Melee is the main damage. The gun does chip damage and, in zero-g, moves you by recoil.
5. **Space, not water.** Water was considered (flooding compartments, swimming) and rejected: a drowned city echoes Hollow Knight's City of Tears, and water's drag and surface make a friendlier, less dynamic movement model than zero-g.
6. **Checkpoints are airlocks**, not benches. The mechanic is the same.
7. **No currency, drops, shops, charms, soul meter, healing in the field, text logs, NPCs, breath or fuel meter, or new movement abilities.** The world changes, the player does not.

## Movement

The player has one set of inputs. What they do depends on whether the compartment has gravity.

**Inputs:** move (eight directions in zero-g, left and right in gravity), jump, swing, fire, grab. Aim for swing and fire comes from the move direction. Named input actions map keyboard and controller in one place.

### With gravity

Hollow Knight's floor and nothing more.

- **Run** at a fixed speed with short acceleration.
- **Jump** with variable height: release early for a short hop.
- **Swing** aimed in four directions. The down swing in the air **pogos** off enemies and hazards, resetting the jump.
- **Fire** has no recoil in gravity; gravity plates hold the player.
- No dash, double jump, wall cling or wall jump.

### Without gravity

- **Drift.** Velocity is conserved. No drag, no sink. Releasing the stick changes nothing.
- **Grab.** On contact with any surface, holding grab stops the player dead and holds them there at any angle. While held, aim is free. Releasing grab leaves the player at rest on the surface. Grab is free and unlimited.
- **Kick.** From a grab, jump launches the player off the surface in the aimed direction at a fixed speed, faster than run speed.
- **Fire.** In zero-g a shot pushes the player the opposite way at a fixed recoil speed, lower than kick speed, with a cooldown so it cannot be held. The gun is the suit's only thruster. Fire at a wall behind you to approach a target; fire at the target to flee it.
- **Ricochet.** Hitting an enemy or hazard with the swing rebounds the player away from it, opposite the swing direction, in any of eight directions. It is pogo without a floor.

### Gravity boundaries

Where a compartment with gravity meets one without, momentum crosses intact. Flying into gravity, the player arcs and lands. Running off a gravity plate into zero-g, the player keeps going straight. Boundaries are visible edges drawn in the room.

### Venting

An open vent or hatch moves air through a compartment. In zero-g it pushes every body hard, player, enemies and debris alike. In gravity it barely moves the player. Vents are tied to switches, so a compartment's flow differs by state. Venting is the zero-g equivalent of platforms.

### Damage

A hit costs one health, knocks the player back, and grants a short invulnerability. In zero-g knockback is simply added velocity, so a hit near a hazard carries the same danger as a hit near a pit on the ground.

### Hard rules

- The camera never rotates. Where gravity exists it points down. Nothing in the slice has sideways gravity.
- Zero-g is always visibly marked: compartment tint, drifting debris, the player's pose and trailing cloth. Loose objects fall when gravity returns.
- No breath, oxygen or fuel meter. The fire cooldown is the only limit.

**Trade-off in one sentence.** Gravity: precise and gravity bound, the player pogos and commands the room. Zero-g: nothing is unreachable and the player is fastest, but cannot stop without a surface, and the things built for zero-g are better at it.

## World state

### The two switches

- **The gravity ring.** Global for the section. On, every live-plate compartment has gravity. Off, the section is zero-g. Thrown from two panels: Panel 1 in the Control Room, Panel 2 in the Blister. Both panels work in both directions, always.
- **The bulkhead vents.** Local to the vent branch (Vent Room, Locker, Workshop, Hangar). Open: wind runs east through the branch, the Hangar hatch opens, the Locker hatch shuts, the Shaft's pressure door opens. Closed: the branch is still, the Hangar hatch is shut, the Locker hatch is open, the Shaft's pressure door is sealed. One panel, in the Vent Room.

Two switches, four states. Every compartment in the vent branch is designed for all four. Every other compartment is designed for two.

### Dead plates

Compartments whose gravity plates are destroyed are zero-g regardless of the ring. They teach zero-g before the player touches a switch. They are the only exception to the ring's rule.

### What a state is

A state is a set of facts about rooms: this compartment has gravity or not, this vent blows or not, this hatch is open or shut, this gate is fallen or floating, this debris lies on the floor or drifts. Rooms are built once with every state's geometry present as nodes a world-state script shows and hides. No room has two layouts to keep in sync.

### Trade-offs in the slice

- Ring off: the Shaft and the Hangar ceiling become reachable, the Spine gate floats clear, debris floats into the lanes, Clingers become drifting hazards, and the ground fights and pogo are gone.
- Ring on: debris drops, the gate falls back, pogo returns, and the vertical routes close.
- Vents open: the Hangar and Shaft routes open, the Hangar becomes a gale in zero-g, Clingers in the Workshop tumble, and the Locker shuts.

### The one irreversible thing

The boss door opens for good when the Warden is defeated. Everything else is a switch.

### Persistence

World state is saved: both switch positions, the boss flag, the last checkpoint rested at, and the visited rooms. Loading restores the world exactly. Dying does not reset switches.

## Combat

### The player

Five health. Health refills at a checkpoint and nowhere else.

- **Swing.** One weapon, four directions, instant, short recovery. Hit stop on contact: a few frames where both parties freeze. One damage. Down swing pogos in gravity; any swing ricochets in zero-g.
- **Fire.** One shot per cooldown. One chip damage and a stagger that interrupts the target's current action. Recoil in zero-g. Nothing else.

### Enemies

Three, each living in both states so the switch changes them too. Three swing hits kill any of them. One hit reaction (knocked back), one death (gone, with a burst of shards). No drops. They respawn when the player rests at a checkpoint.

- **Hull mite.** Crawls along any surface in either state, following walls and ceilings. In gravity a floor and wall patrol to pogo over. In zero-g the same patrol, now on surfaces the player wants to grab. Slow and predictable.
- **Drone.** Floats and faces the player, then charges in a straight line after a visible wind-up. In zero-g the line crosses the whole room. In gravity it floats a little above the floor, within pogo reach. A shot cancels its charge.
- **Clinger.** A turret on a surface that spits a slow shot. Fixed in gravity. In zero-g it is debris: it drifts with venting and keeps shooting.

### The boss: the Warden

A large drone built to patrol the gravity ring, fought in the Control Room, the only room with a ring panel inside it.

- **Gravity on:** it hovers above pogo height and charges in sweeping arcs. The floor is safe and precise. The player can chip it and dodge but cannot reach it, and it repairs when not pressured, so it cannot be killed this way.
- **Gravity off:** it is fast and the whole room is its lane, but the player can reach it: ricochet off it, kick between grab points, fire at the wall behind to close. This is where damage happens and where the player dies.
- When gravity returns while it is mid-charge, it staggers hard.
- Its health does not reset within an attempt. Dying resets the fight.

Defeating it opens the boss door. The slice ends beyond it.

## The slice

The Hulk is a derelict carrier. The slice is one section: a dock, a spine corridor, a breached wing, a vent branch, and the ring deck above. Thirteen rooms, listed in the order a first run meets them; step 5 is a return visit, not a room. Start state: ring on, vents closed.

| Room | Plates | Notes |
| --- | --- | --- |
| 1 Dock | live | Checkpoint 1. Run, jump, swing. Two mites. |
| 2 Spine West | live | Long corridor. Shaft up to the ring deck, too tall to climb. Heavy fallen gate blocks the way east. |
| 3 Breach | dead | Always zero-g, open to the stars. Grab, kick, fire. Mites on every surface. |
| 4 Blister | dead | Observation dome with a view of the ring turning. Panel 2. First time gravity goes off; the ring is seen stopping. |
| 5 Spine West (return) | live | In zero-g the gate floats clear and the shaft is flyable, but the pressure door at its top is sealed. |
| 6 Spine East | live | First drone. Teaches ricochet and stagger. Its floor is higher than Spine West's, so the way back west is a drop over the gate's top in any state; only the way east needs zero-g. Without that drop, restoring gravity in the Control Room and descending through the Hangar would strand the player east of the gate. |
| 7 Vent Room | live | Vents panel. |
| 8 Locker | live | Enterable only with vents closed and ring off (hatch open, a loose cabinet floated clear). Holds the slice's one secret: a view port into the Control Room where the Warden can be watched. |
| 9 Workshop | live | Clingers on the walls. Vents open in zero-g, they tumble with the wind. |
| 10 Hangar | live | Vents open: a gentle walk in gravity; in zero-g a gale toward a shredded hull wall that is a hazard. Ceiling torn open to the ring deck, reachable only in zero-g. The fast route is riding the gale and grabbing the ceiling in passing. |
| 11 Shaft | live | The slow route up. Pressure door opens with the vents. Zero-g only. Mites on the walls. |
| 12 Ring Deck | live | Corridor along the ring housing. Drones. Checkpoint 2. |
| 13 Control Room | live | Panel 1. The Warden. |
| 14 Exit | live | Boss door, open for good once the Warden is down. The slice ends beyond it. |

**Required path.** Dock, Spine West, Breach, Blister (ring off), Spine West, Spine East, Vent Room (vents open), then Hangar or Shaft, Ring Deck, Control Room, Exit. The Locker is optional and is the composition lesson. Hangar against Shaft is the choice between fast and safe.

**Checkpoints are airlocks.** A powered airlock with a working inner door. Resting heals, saves, and respawns enemies. Dying returns the player to the last airlock rested at, with the world as they left it.

**The map.** Opens on a key. Rooms are boxes that fill in as entered, with the player's position and seen panels marked. No map item, pins or fast travel.

**Not in the slice.** Text logs, NPCs, currency, shops, a second section, a title screen beyond a name and a prompt.

## Art

**The rule.** Flat shapes, no outlines, gradients or texture. Every object is a few solid polygons. Depth comes from value: the far background darkest, the playable layer mid, hazards and interactables brightest, the player brightest of all. Bright means touchable; dim means scenery. This carries readability in zero-g, where no floor says what matters.

**Palette.** Five families: a dark hull family for scenery, a cool tint for zero-g compartments, a warm tint for gravity compartments, a hot color for hazards and enemies, and the player's color, used for nothing else. A compartment's state is told by tint first.

**Characters are rigs.** Player, three enemies and the Warden are each a `Skeleton2D` with `Polygon2D` parts and a few bones, animated pose to pose with `AnimationPlayer`. Player animations: idle, run, jump, swing, hit, death, plus a trailing cloth that shows velocity. In zero-g the rig tilts into its velocity and the cloth streams behind. No frame art.

**Rooms are polygons.** Hull geometry is `Polygon2D` over `CollisionPolygon2D`, drawn in the Godot editor. Toggled parts (gates, hatches, debris, wind) are nodes the compartment shows and hides. No tiles.

**Effects budget.** Hit stop, a flash to white on hit, a burst of flat shards on death, venting as streaked particles showing direction and speed, debris that drifts in zero-g and settles when gravity returns.

**Sound.** Synthesized in code at startup, no audio files: swing, hit, shot, kick, grab, switch, hatch, death, and the ring spinning down.

**Pipeline.** No external art tool. Polygons are drawn in the editor or generated by a script where a shape is regular. SVG import is available later without structural change.

## Architecture

Godot 4.5, GDScript. Web export first, desktop second. Named input actions.

- **`Player`** (`CharacterBody2D`): one input layer, two movement mode scripts (gravity, zero-g) swapped when the compartment's gravity changes. Each mode is testable alone with a scripted input stream in a flat test room.
- **`WorldState`** (autoload): the switch positions, the boss flag, the checkpoint, visited rooms. The only thing that knows what state means. Saves and loads itself to one file.
- **`Compartment`**: on every room. Declares live or dead plates and which switch each toggled child follows. Reads `WorldState`, shows and hides children, sets gravity for bodies inside.
- **`Switch`**: a panel the player uses. Flips one `WorldState` field. Nothing else.
- **`Vent`** (`Area2D`): applies force to bodies inside while its switch is open. Strong in zero-g, weak in gravity.
- **`Enemy`** scripts, one per type, each with the player's two-mode shape. **`Warden`** as its own script.
- **`Checkpoint`**: heals, saves through `WorldState`, respawns enemies in loaded rooms.
- **`WorldGraph`**: data, not a scene. Every room, its exits, and for each exit the states and movement that cross it. Written by hand with the rooms. Read by the reachability test.
- **`Map`**: reads visited rooms from `WorldState` and draws boxes.
- **`Sfx`**: synthesized sounds.

Rooms load one at a time with their neighbours.

**Repo shape.** `scenes/`, `scripts/`, `tests/`, `tools/`, `docs/superpowers/`, `README.md`, `ROADMAP.md`.

## Testing

The harness is Down Mine's: a headless runner with a per-test timing table, run by CI on every pull request, and a playtest job under a virtual display that screenshots scripted scenarios. Tests are written before what they test.

- **Rules.** `WorldState` round-trips through save and load. A `Compartment` shows the right children in all four states. A `Vent` pushes hard in zero-g and barely in gravity. The `Warden` staggers when gravity returns mid-charge.
- **Movement.** Scripted inputs in a flat room, asserting positions and velocities: kick speed, fire cooldown and recoil, ricochet direction, pogo height, momentum across a gravity boundary, that drift never decays, that grab stops dead.
- **Reachability.** The `WorldGraph` is walked for every state. Fails if any room cannot reach a switch panel in its state, or if the Exit cannot be reached from the Dock by the designed path. A second test checks every exit the graph declares exists in its scene.

The playtest job plays the required path end to end, dies once on purpose, and screenshots each room in each state it is meant to be seen in.

## Starting values

| Value | Start |
| --- | --- |
| Player health | 5 |
| Swing damage | 1 |
| Fire damage | 1 (chip, staggers) |
| Enemy health | 3 |
| Fire cooldown | 0.5 s |
| Kick speed | 1.4 times run speed |
| Recoil speed | 0.8 times run speed |
| Hit stop | 3 frames at 60 fps |
| Invulnerability after a hit | 0.6 s |
| Vent force in zero-g | enough to cross the Hangar in about 2 s |
| Vent force in gravity | about a tenth of that |

## Open questions

- The working title.
- What lies beyond the Exit, if the slice succeeds. Nothing in the slice depends on it.

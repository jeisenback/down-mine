# Mine Roguelike - PRD

Sep 27, 2026 · @Jordan

## Overview

A side-view extraction roguelike set in a hostile mine: you lead a crew down,
hold back the dark with decaying light, and decide when to get out. It blends
UnderMine (rescued NPCs power your progression) with Dome Keeper (a base
under pressure while you dig).

Design pillars:
- Light is everything. It keeps you safe, it decays, and it is your weapon.
- Noise is the cost of progress. Almost everything useful is loud.
- Your crew is the progression. NPCs carry the upgrades, gain experience, and can be lost.
- Loss comes from choices. Nothing is lost to pure bad luck; losses follow decisions the player made.
- One rule for upgrades. The hub grants capabilities; NPCs improve them.

## Core loop

Each run is a single trip down and a judgment call about when to leave.

1. Hub. Spend recovered finds on permanent upgrades and choose a crew for the limited slots.
2. Descend and build. Dig down, carve out a run base, and fortify it.
3. Push deeper. Better finds, rarer NPCs, and story pieces are deeper, along with more danger.
4. End the run. Extract by choice and keep everything, or fail when the base falls or you die.

## Light and decay

Light is the central resource: it burns down over time, and everything safe
in the mine depends on it.

### Decay

- Light sources (carried lanterns, placed lights, the run base's light) lose fuel over time.
- Structures (base walls, supports, placed ropes and ladders) wear down, and decay faster in darkness. Light and structures share one clock where possible.
- The mine itself decays during a run: tunnels collapse and floors crumble. Nothing carries over, since the mine regenerates.

### Fuel sources

| Source | Role |
| --- | --- |
| Mined fuel | Common, steady baseline; mining costs time and makes noise |
| Found fuel | Rare caches and special lights (flares, hotter lanterns); the reward for risky detours |
| NPC upgrades | Passive: larger radius, higher intensity, longer burn |

### Light as the weapon

Enemies avoid or take damage in light and are strong in darkness. The player
can flare light brighter to push back or hurt enemies, which burns fuel
faster, so every fight shortens the run.

## Noise meter

One per-run meter driven by sound and activity: it draws enemies during the
run and, past a threshold, triggers an attack on the run base.

What raises it: mining, building and repairing, combat, falls and collapses,
placing traversal tools, and escorted NPCs.

What keeps it low: careful movement, waiting in the dark, avoiding fights.
Quiet play costs time, and time burns light.

The core tension is light versus noise: hurry and get loud, or go slow and
let the light run down. The meter resets each run, along with the run base.

## NPCs and crew

NPCs are the core progression: found in the mine, escorted home, and kept on
a persistent roster at the hub.

- Roster. Every rescued NPC joins the roster. NPCs not on the current crew stay safe at the hub.
- Crew slots. Each run you choose a limited crew. Slots expand through permanent hub upgrades.
- Types and upgrades. Each NPC has a type that improves a system while they are on the crew and not stranded: light (radius, intensity, burn time), repair (cost, quality, speed), noise (quieter tools, dampened walls, threshold warnings), and traversal (rope life, ladder speed, grapple range).
- Veterans. NPCs gain experience by surviving runs, strengthening their upgrade and picking up a name, history, and quirks.
- Duplicates. Multiple NPCs of the same type can exist, so a backup can cover while another is stranded or fill extra slots.
- Replacements. NPCs of types missing from the roster spawn more often, which keeps recovery within reach.

### Stranding and rescue

NPCs never die outright; they get stranded, and only die if the player
leaves them too long.

What strands an NPC: being lost during an escort, being caught in a base
attack, or being left behind when a run fails. NPCs found but not yet
brought home on a failed run are stranded too.

Drift. Stranded NPCs are taken deeper into the mine. They drop a layer for
each run they are not rescued, and keep drifting during long runs, so a
rescue has to commit rather than work down slowly. If they drift far enough,
they die.

What the player knows. At the hub, the layer each stranded NPC is on and
roughly how long until they drift again. In the mine, signs such as dropped
gear, wall marks, and faint lights lead to their exact location. Veterans
leave clearer, more distinctive signs.

Death only happens through neglect, so every permanent loss follows a choice
the player made.

## Mine, layers and traversal

The mine is a side-view, regenerated each run, and gets more dangerous with
depth.

Layers. Continuous depth bands, each with its own hazards, enemies, and
look, so players always know what a given layer means even though the
layout changes. Layers set difficulty, where the good finds are, and where
stranded NPCs drift.

Fall damage. Part of movement. Digging straight down is fast but risky;
building a safe path takes time and makes noise. Escorted NPCs take fall
damage too.

Traversal tools. Going down is easy; getting back up is the hard part.

- Reusable tools (such as a grapple) are the reliable baseline.
- Consumable tools (ropes, ladders, anchors) build your route home as you descend, so a deep dive means planning the return first.
- Placed tools decay, faster in darkness, and make noise when placed.
- Escorted NPCs follow the route you built.
- New tools unlock at the hub; NPCs improve them.

## Enemies

Three starting enemy types, each pressuring a different system; more can
come later for deeper layers.

| Enemy | Behavior | Punishes | Threatens |
| --- | --- | --- | --- |
| Stalker | Waits at the edge of light, strikes when it flickers or shrinks | Low fuel | The player and crew |
| Snuffer | Puts out lanterns and placed lights | Light spread too thin | The route home |
| Burrower | Tunnels through rock toward noise | Loud play | The run base |

## Progression

Two layers, one rule: the hub grants capabilities, NPCs improve them.

| Layer | Paid with | Can be lost | Narrative source |
| --- | --- | --- | --- |
| Hub upgrades | Things recovered from the mine: ore, relics, found objects | Never | The world: journals, old equipment, traces of earlier miners |
| NPC upgrades | NPC experience from surviving runs | Yes, if the NPC dies from neglect | The NPCs: veteran names, histories, quirks |

Keeping these separate prevents a death spiral: a bad run can cost people
and their growth, but never permanent hub progress.

## Open questions (defaults used for milestone 1, revisit later)

- [x] Working title: "Down Mine" (placeholder)
- [ ] What takes stranded NPCs deeper (creatures, a shifting mine, or fleeing)
- [x] Layers before a stranded NPC dies: 3 undrifted runs (default, tune later)
- [x] Starting crew size / max slots: 1 starting, 4 max via hub upgrades (default)
- [x] Player death: light hits zero + enemy contact, or excess fall damage (default)
- [ ] Whether runs have a final goal or ending at the deepest layer
- [x] Platform and engine: Godot 4.3+ (GDScript)

## Out of scope for now

- Direct combat beyond light
- A separate base-defense phase between runs
- Persistent mine layouts between runs
- Enemy types beyond the starting three

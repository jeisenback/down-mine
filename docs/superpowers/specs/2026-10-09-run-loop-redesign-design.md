# Run loop redesign: one clock, a dark that hurts, an old mine

2026-10-09. Design for the next run of milestones, agreed in
conversation. Numbers are starting values for the balance probe to
check, not commitments.

## Why

Bots playing whole runs show the loop has a dominant strategy: hold S.
A dive reaches the bottom alive in 90 seconds with the lantern dead for
the last 30, because darkness itself costs nothing and a falling player
outruns the Stalker. Four clocks tick at once (lantern, noise meter,
mine decay, base health) at about the same size, so none reads as the
reason to turn around. The caves are random blobs with no shape worth
platforming through, and the cheapest answer to any cave is to dig
round it. Depth is legible; position is not.

## Decisions

1. **Light is the clock.** One meter the player watches. Everything
   else is sized against it.
2. **The dark hurts, both ways.** At zero light: a slow health drain,
   no digging (you cannot see the rock), placed tools rot fast, the
   Stalker strikes freely. Waiting in the dark is slow death, moving in
   it is fast death; the only answer is light.
3. **Noise has two listeners, one meter.** Every noise event carries a
   position. The base hears sound by distance through rock and that
   fills the one Burrower meter. The dark hears the player directly and
   the Stalker responds; no second bar.
4. **The base is attacked on the mine's clock late in a run,** whatever
   the player did. The choice is how deep you went and how long you
   stayed; loss follows that choice.
5. **Digging is the verb, but the old mine is built.** Rock is the
   level. The upper layers carry structure left by the earlier crew: a
   main shaft with galleries, which continues past the quiet layers
   into Stone and ends where the crew stopped. Platforming matters in
   the works, with human-made shapes; below them it is all digging.

Already in place from milestone 48 and kept: six layers from one table,
the quiet zone (Topsoil and Clay: nothing hears, nothing hunts), the
Stalker waking per layer and never rising into the quiet layers, the
steady dig-down and the staircase rule.

## The dark

Applies while the player's lantern fuel is zero (not merely low; low
light already lets the Stalker strike). Being inside any other light
(base, lamp, camp lantern, a miner) counts as lit and suspends all of
it.

- **Drain.** 1 health every `DARK_DRAIN_SECONDS` (start: 12 s). With 3
  health, standing still in the dark is dead in about 36 s. The run log
  records the source as "dark".
- **No digging.** Dig inputs do nothing; the HUD prompt says "Too dark
  to dig". Walking, jumping, climbing, the grapple and placing tools
  still work: you can get out, you cannot push on.
- **Tools rot.** Rope and ladder decay already run faster in darkness;
  multiply by `DARK_ROT_MULTIPLIER` (start: 3) while the player's
  lantern is out, so a route built in the dark does not survive.
- **The Stalker strikes freely.** Already true below 25% fuel. No
  change, but the 3 s retreat after a strike shortens to 1.5 s at zero
  light.

Not changed: fall damage, decay of the mine itself (it already has its
own dark rule per cell).

## Noise

`NoiseMeter.add_noise(amount, position)`: the position is where the
sound was made. The existing callers all know it (the player, the base,
an event room, a collapse cell). Two listeners:

**The base.** The meter adds `amount * hearing(distance)`, where
distance is tiles from the base in a straight line and `hearing` falls
linearly from 1 at 0 tiles to 0 at `BASE_HEARING_TILES` (start: 80).
Sound made in a quiet layer adds nothing, as now (nothing lives there
to be drawn; the mine's creatures come from below the quiet floor). A
base planted deep therefore hears everything done near it; a surface
base barely hears the deep. Burrowers still spawn below the player and
travel to the base, and never spawn above the quiet floor.

**The dark.** A Stalker within `STALKER_HEARING_TILES` (start: 30) of a
noise event is alerted for `ALERT_SECONDS` (start: 4): it hunts at
`SPEED` instead of `HUNT_SPEED` and its retreat timer is cleared. Loud
acts near the player make the thing in the dark close in; the player
sees it move, there is no bar.

HUD: the noise bar stays as the base's meter. The bell warns as now.

## The mine's clock

From `MINE_WAKE_SECONDS` into the run (start: 240 s, half the decay
ramp), the mine sends a Burrower at the base every `WAVE_INTERVAL`
(start: 90 s, shrinking to 45 s by the end of the decay ramp),
independent of noise. Crew waiting at the base add to the base's
hearing as they do now (they talk). Carrying the Heart halves the
interval, matching its decay effect. The bell rings for a wave 10 s
before it surfaces. The run log counts waves separately from noise
Burrowers so tuning can see both.

This is the pressure that makes "how deep, how long" the choice: early
in a run the base is attacked only if you are loud near it; late in a
run it is attacked regardless, and the longer you stay the more it
takes.

## The old mine

Generated after the caves and before the event rooms, so rooms avoid
it. Deterministic from the seed like everything else.

**The shaft.** A vertical shaft 3 tiles wide under the entrance (the
map's centre column), timbered down both sides, running from the crust
to `SHAFT_END_ROW`: a random row in the upper half of Stone. It ends in
a collapse: the shaft fills with rock for 6 rows, with timber debris
drawn over it, and below that the shaft is gone. The lift sits in the
shaft at the bottom of Clay (the old cage), replacing its random room.
An old ladder runs the shaft's full length, in pieces: each 8-row
piece has a 30% chance to be missing, so the climb needs the grapple,
a rope or a jump across a gap. Old ladders never decay.

**Galleries.** One per worked layer (Topsoil, Clay, and Stone down to
the collapse), branching from the shaft to a random side at a random
row in that layer: 2 tiles tall, 24 to 40 tiles long, timber posts
every 6 tiles. Each gallery has one feature at its end: a camp (the
camps of the worked layers move here from random rooms; the deeper
layers keep theirs as rooms), a collapsed section 4 to
8 tiles long that must be dug through, or in Stone, the lost miner's
spot (the lost miner band moves to the Stone gallery's far end).
Galleries can cross caves; where they do, a plank floor spans the gap.

**Tiles.** New tile kinds in the atlas, all drawn by `tools/make_props.py`
from the pack's palette until real art exists: timber post (open, drawn
over the background, no collision), plank floor (solid, diggable),
shaft frame (open, decorative), collapse debris (solid rock with timber
drawn over it; digs like rock). The old ladder reuses the Ladder scene
with `life_seconds = INF`.

**Below the collapse** the mine is untouched: caves as now, event rooms
as now, the Heart at the bottom. The route home from the hostile layers
starts with finding the bottom of the shaft, which is marked on the
journal's last page.

## Movement

Digging stays the main verb; nothing in the dig code changes beyond the
dark rule. In the works, the shapes are the ones the player already
has verbs for: 2-tall galleries to walk, 1-tile bumps and 2-tile ledges
at collapses, ladder gaps to grapple or rope across, plank floors over
caves. No new movement verbs. If play testing the works shows a missing
verb (most likely a wall grab at ladder gaps), it is its own milestone.

## Milestones

In this order; each is a PR with the probe output before and after.

- **M49 The dark hurts.** Drain, no digging, rot, shorter retreat. Probe
  expectation: the "dark" bot dies of the dark in about 36 s after the
  light fails instead of living to the end; the "dive" bot dies in the
  dark deep down instead of reaching the bottom at zero light.
- **M50 Two listeners and the mine's clock.** Positioned noise, base
  hearing, Stalker alerting, waves. Probe expectation: the "dive" bot's
  Burrower count falls (deep digging is quiet to a surface base) and
  its base still falls late from waves.
- **M51 The old mine.** Shaft, collapse, galleries, old ladder, moved
  camps, lift and lost miner. Playtest scenarios: climb the shaft on
  the old ladder across a gap; walk a gallery to its camp; dig through
  a collapsed section; find the shaft's end from Stone.
- **M52 Art for the works.** Replace the generated props with drawn
  tiles if the shapes hold up.

## Out of scope

- New enemies, new movement verbs, touch controls.
- Retuning the lantern size, dig noise or ore costs beyond what M49
  and M50 force; that remains the M22 tuning pass, now with less noise
  in the signal.
- Persistent mine layouts between runs. The shaft is regenerated per
  seed like everything else.

# Down Mine

Side-view extraction roguelike prototype. See `MineRoguelike_PRD.md` for the full design.

## Milestone 1 — vertical slice

Proves the core tension: light decays, digging is loud, and enemies punish
darkness. No crew, hub, or stranding yet.

**Controls**
- `A`/`D` or arrow keys — move
- `W`/Up — jump
- `S`/Down — dig downward (hold with a movement key to dig a descending staircase)
- `Space` — dig forward (in facing direction); hold with `W`/Up to dig straight up instead
- `Shift` — flare the light (brighter, burns fuel faster; the only thing that hurts a Burrower)
- `Q` — fire the grapple straight up (reusable, pulls you to the first solid ceiling within range)
- `R` — place a rope at your feet (consumable, climbable with `W`/`S`, decays over time — faster in the dark)
- `E` — extract at the run base (banks ore, ends the run)
- `1`-`3` — on the run summary (the hub), buy an upgrade with banked ore: lantern tank (+15s light), hard hat (+1 health), crew bunk (+1 crew slot, up to 4)
- `4`-`9` — on the hub, put a rescued miner on the crew or take them off
- `Enter` — start a new run from the run summary (banked ore and upgrades are saved between runs)

**Noise and the base**: when the noise meter fills, a Burrower surfaces
below you and tunnels to the run base. Your light slows it; flaring kills
it. If it takes the base from 3 health to 0, the run fails.

**Falling**: landings hurt based on impact speed. Drops under 7 tiles are
free (so plain digging down is safe), 7+ costs 1 health, +1 per 3 more
tiles. Hard landings also make noise.

**Lost miners**: each run hides one lost miner (faintly lit, each with their own shirt colour) on a
cave floor partway down. Touch them and they follow your trail; extract
with them and they join the roster. Each miner has a type that helps
while they are on your crew: Light (lantern burns 20% slower, reaches
15% further), Noise (everything 25% quieter) or Traversal (grapple
reaches 50% further). New finds lean toward types you don't have yet.
You start with one crew slot; pick who fills it at the hub.
Crew gain a run of experience whenever a run they were on ends in
extraction: Seasoned at 2 runs (bonus x1.5), Veteran at 5 (bonus x2, plus
a title such as "Ada the Lamplighter"). Fail the run while escorting and they are stranded in the layer
they were lost in: the hub shows where, they drift one layer deeper for
every run that ends without rescuing them, and drifting past Deep rock
kills them. In their layer, an arrow in their shirt colour points to them.
You can escort several miners at once; they follow in single file.

**Run it**: open the project folder in Godot 4.3+ and press Play (main scene
is `scenes/Main.tscn`).

## Project layout

- `scenes/` — Main, Player, Mine, Stalker, HUD
- `scripts/` — one script per scene/system (`mine.gd` generates its own
  placeholder tileset in code, no art assets needed yet)

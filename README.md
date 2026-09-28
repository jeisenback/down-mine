# Down Mine

Side-view extraction roguelike prototype. See `MineRoguelike_PRD.md` for the full design and `ROADMAP.md` for what comes next.

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
- `L` — set down a lamp (3 per run; burns ~90s, lights your route, slows rope decay; noisy)
- `R` — place a rope at your feet (consumable, climbable with `W`/`S`, decays over time — faster in the dark)
- `T` — place a ladder standing up from your feet (4 per run; climbs faster and lasts longer than a rope; noisy)
- `G` — hammer in an anchor where you stand (2 per run); `Q` then pulls you straight to the nearest anchor within 10 tiles in line of sight (over a ledge's lip), before trying a ceiling
- `E` — extract anywhere at the surface, above the crust (banks ore, ends the run)
- `P` — once per run, plant the run base where you stand (below the crust, on a floor)
- `F` — hold at the run base to repair it (1 health per 3s, 10 of this run's ore per point, noisy)
- `B` — at the run base, fortify: reinforce the 12 nearest plain rock tiles within 5 tiles (2 of this run's ore per tile, noisy); press again for more
- `1`-`3` — on the run summary (the hub), buy an upgrade with banked ore: lantern tank (+15s light), hard hat (+1 health), crew bunk (+1 crew slot, up to 4)
- `4`-`9` — on the hub, put a rescued miner on the crew or take them off
- `Enter` — start a new run from the run summary (banked ore and upgrades are saved between runs)

**Noise and the base**: when the noise meter fills, a Burrower surfaces
below you and tunnels to the run base. Your light slows it; flaring kills
it. If it takes the base from 3 health to 0, the run fails. Reinforced
walls around the base cost a Burrower 2.5s each to chew through (tunnels
you dug near the base are open road), and wear back to plain rock over
time - much faster when the base's light is low.

**Snuffers**: while any lamp is burning, a Snuffer appears every 45s (one
at a time). It drifts through rock to the lamp or base light furthest from
you and drains it dry. Your light drives it off; flaring kills it.

**Mine decay**: in darkness, tunnels you dug refill with rock and cave
floors near you crumble away, a little faster as the run goes on. Light
(yours, lamps, the base, miners) protects the ground around it.

**Falling**: landings hurt based on impact speed. Drops under 7 tiles are
free (so plain digging down is safe), 7+ costs 1 health, +1 per 3 more
tiles. Hard landings also make noise.

**Lost miners**: each run hides one lost miner (faintly lit, each with their own shirt colour) on a
cave floor partway down. Touch them and they follow your trail; extract
with them and they join the roster. Each miner has a type that helps
while they are on your crew: Light (lantern burns 20% slower, reaches
15% further), Noise (everything 25% quieter), Traversal (grapple
reaches 50% further, ropes/ladders last 50% longer, ladders climb 25% faster) or Repair (base repair 25% cheaper and faster). New finds lean toward types you don't have yet.
You start with one crew slot; pick who fills it at the hub.
Crew gain a run of experience whenever a run they were on ends in
extraction: Seasoned at 2 runs (bonus x1.5), Veteran at 5 (bonus x2, plus
a title such as "Ada the Lamplighter", plus a quirk - a small effect such
as Night eyes, Pack rat or Sure-footed, or the odd downside like Hums
while working). Fail the run while escorting and they are stranded in the layer
they were lost in: the hub shows where, they drift one layer deeper for
every run that ends without rescuing them, and drifting past Deep rock
kills them. Around each one, scraps of their shirt glow faintly on cave
floors, from ~18 tiles out to right beside them; Veterans leave more and
brighter ones.
You can escort several miners at once; they follow in single file.
Your crew wait at the run base. If the run fails - you die or the base
falls - they are stranded in the base's layer and lose their bonus until
rescued (experience intact), so planting the base deep is a gamble.

**The run base**: starts at the surface; plant it deeper as a forward
camp. Standing at it refills your lantern from the base's light (which
makes its walls wear faster). Stalkers won't enter the base's light, so
it is a refuge - one that shrinks as you draw on it. Extraction is always at the surface, so a
deep base doesn't shorten the climb home.

**Run it**: open the project folder in Godot 4.3+ and press Play (main scene
is `scenes/Main.tscn`).

**Run the tests**: `godot --headless --fixed-fps 60 -s tests/run_tests.gd`
(exits non-zero on failure; CI runs it on every pull request). Test
scripts are `tests/test_*.gd`, extending `TestCase`; every `test_*`
method runs. Tests write to their own save file, never the real one.

**Play in a browser**: every push to `main` builds the Web export and
publishes it to GitHub Pages (`.github/workflows/web.yml`). One-time
setup: repo Settings -> Pages -> Source: "GitHub Actions". Click the game
once to give it keyboard focus. Saves live in the browser's storage.

## Project layout

- `scenes/` — Main, Player, Mine, Stalker, HUD
- `scripts/` — one script per scene/system (`mine.gd` generates its own
  placeholder tileset in code, no art assets needed yet)

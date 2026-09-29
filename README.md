# Down Mine

Side-view extraction roguelike prototype. See `MineRoguelike_PRD.md` for the full design and `ROADMAP.md` for what comes next.

## Milestone 1 — vertical slice

Proves the core tension: light decays, digging is loud, and enemies punish
darkness. No crew, hub, or stranding yet.

**Controls**
- `Esc` — show or hide the controls (pauses the game); a title screen shows once per launch (`Enter` to start)
- `A`/`D` or arrow keys — move
- `W`/Up — jump (hold for full height, tap for a short hop); walking into a 1-tile bump steps up onto it; jumping into a 2-tile ledge while holding toward it mantles up (3 tiles is too high)
- `S`/Down — dig downward (hold with a movement key to dig a descending staircase)
- `Space` — dig forward (in facing direction); hold with `W`/Up to dig straight up instead
- `Shift` — flare the light (brighter, burns fuel faster; the only thing that hurts a Burrower)
- `Q` — fire the grapple straight up (reusable, pulls you to the first solid ceiling within range)
- `L` — set down a lamp (hub unlock; 3 per run; burns ~90s, lights your route, slows rope decay; noisy)
- `R` — place a rope at your feet (consumable, climbable with `W`/`S`, decays over time — faster in the dark)
- `T` — place a ladder standing up from your feet (hub unlock; 4 per run; climbs faster and lasts longer than a rope; noisy)
- `G` — hammer in an anchor where you stand (hub unlock; 2 per run); `Q` then pulls you straight to the nearest anchor within 10 tiles in line of sight (over a ledge's lip), before trying a ceiling
- `E` — extract anywhere at the surface, above the crust (banks ore, ends the run); in the mine, use a nearby camp, lift, outpost, survivor, vault door or relic
- `P` — once per run, plant the run base where you stand (below the crust, on a floor)
- `F` — hold at the run base to repair it (1 health per 3s, 10 of this run's ore per point, noisy)
- `B` — at the run base, fortify: reinforce the 12 nearest plain rock tiles within 5 tiles (2 of this run's ore per tile, noisy); press again for more
- `1` — build a support beam where you stand (15 of this run's ore): stops collapses and crumbling within 3 tiles; wears out, faster in the dark
- `2` / `3` — at the run base, build a beacon (30 ore: base light reaches 50% further but burns 50% faster) or an alarm bell (20 ore: warns when noise nears the Burrower threshold); one each per run
- `1`-`6` — on the run summary (the hub), spend banked ore: lantern tank (+15s light), hard hat (+1 health), crew bunk (+1 crew slot, up to 4), or unlock lamps (40), ladders (60) or anchors (100). The grapple and ropes are always available.
- `A`-`J` — on the hub, put a rescued miner on the crew or take them off
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

**Layers**: Topsoil is the calm start. Stone holds gas pockets - green-
tinted rock that releases a lingering gas cloud when you dig it out
(1 health per 1.5s inside). Deep rock is unstable: decay runs twice as
fast while you're down there, and your first descent wakes a second
Stalker. The HUD names your layer and its hazard.

**Mine events**: each run carves a few rooms into the rock. An abandoned
camp waits in every layer: search it once for light, ore (more the deeper
it is) and the next page of the old crew's journal, which carries over
between runs; searching lights its lantern, which you can relight later
from your own light. An old lift sits in Stone or Deep rock: repair it for
30 ore (loud), then ride it once straight up to the surface, escorts and
all. A survivor outpost, lit by its fire, sits in Stone or Deep rock:
trade 20 ore for a supply pack (1 lamp, 2 ladders, 1 anchor - even before
you unlock them; 2 packs per outpost) and recruit its survivor for 40
ore, who then follows you like a rescued miner. The survivors talk, so
lingering there fills the noise meter. A relic vault, a chamber walled in
unbreakable brass-tinted stone, sits in Deep rock: breaking its door is one
press but very loud (60 noise), and the relic inside is worth 150 ore if
you get it home. A collapsing gallery, a room propped with old timbers and
lined with double-value ore, sits in Stone or Deep rock: step in and its
ceiling comes down 12s later (loud). Light doesn't stop it; support beams
do. Anyone still inside is buried (1 damage, dig out), and any ore left
behind is lost. A Stalker nest of pale eggs sits in Deep rock: flare your
lantern beside it for 2s to burn it (loud). A burned nest removes Deep
rock's second Stalker for the rest of the run, or stops it ever waking.

**The Heart of the mine**: the run's goal, a glowing crystal in a chamber
near the bottom of Deep rock. Taking it is loud (50 noise) and wakes the
mine: decay runs twice as fast until the run ends. Get it to the surface
and extract to win the run: it banks 300 ore on top of what you carry.
Each Heart you claim makes every later mine decay 15% faster; the hub
shows how many you've claimed. Lose the run and the Heart stays below.

**Sound**: every effect (digging, hits, pickups, placing tools, collapses,
gas, alarms) is synthesized in code at startup (`scripts/sfx.gd`) - no
audio files. Collapses fade with distance and go quiet past 16 tiles, so
you hear the mine closing in around you.

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

## Testing and UAT

Every mine has a seed, shown in the top-right corner and in the run
summary. Report it with a bug and the same mine can be replayed:

- Web: add `?seed=1234` to the URL (applies to the first run after the
  page loads; new runs from the hub are random again).
- Godot: `godot -- --seed=1234`.

Debug keys are off unless the game is launched with `?debug` (web) or
`-- --debug` (Godot); both options combine, e.g. `?seed=1234&debug`:

- `I` god mode, `O` +100 ore, `U` refill light
- `N` teleport to the next event room (the Heart first), `K` drop into
  the next layer (from Deep rock, back to the base), `M` reveal the map

The controls overlay (`Esc`) lists them when debug is on.

`tests/playtest.gd` plays scripted scenarios in the real game with key
presses and saves a screenshot per step to `playtest_out/`:
`xvfb-run -a godot --fixed-fps 60 -s tests/playtest.gd`. CI runs it on
every pull request; the screenshots are attached to the run as
`playtest-screenshots`.

## Project layout

- `scenes/` — Main, Player, Mine, Stalker, HUD
- `scripts/` — one script per scene/system (`mine.gd` generates its own
  placeholder tileset in code, no art assets needed yet)

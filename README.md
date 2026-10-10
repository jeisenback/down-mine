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
- `R` — throw a rope up (it hangs from the ceiling, or 5 tiles up) and climb it with `W`/`S`; throw another from the top to keep climbing. `S`+`R` drops it over the edge you face, down into a drop. Unlimited, 1.5s apart; decays over time, faster in the dark
- `T` — place a ladder standing up from your feet (hub unlock; 4 per run; climbs faster and lasts longer than a rope; noisy)
- `G` — hammer in an anchor where you stand (hub unlock; 2 per run); `Q` then pulls you to the nearest anchor within 10 tiles - in a straight line, or straight up and then across (out of a narrow pit) - before trying a ceiling
- `E` — extract anywhere at the surface, above the crust (banks ore, ends the run); in the mine, use a nearby camp, lift, outpost, survivor, vault door or relic
- `P` — once per run, plant the run base where you stand (below the crust, on a floor)
- `F` — hold at the run base to repair it (1 health per 3s, 10 of this run's ore per point, noisy)
- `B` — at the run base, fortify: reinforce the 12 nearest plain rock tiles within 5 tiles (2 of this run's ore per tile, noisy); press again for more
- `1` — build a support beam where you stand (15 of this run's ore): stops collapses and crumbling within 3 tiles; wears out, faster in the dark
- `2` / `3` — at the run base, build a beacon (30 ore: base light reaches 50% further but burns 50% faster) or an alarm bell (20 ore: warns when noise nears the Burrower threshold); one each per run
- `1`-`6` — on the run summary (the hub), spend banked ore: lantern tank (+15s light), hard hat (+1 health), crew bunk (+1 crew slot, up to 4), or unlock lamps (40), ladders (60) or anchors (100). The grapple and ropes are always available.
- `A`-`J` — on the hub, put a rescued miner on the crew or take them off
- `L` — on the hub, show the last 10 runs: result and cause of death, time, depth, ore, Burrowers, damage by source, seed
- `Enter` — start a new run from the run summary (banked ore and upgrades are saved between runs)

**Noise and the base**: every sound is made somewhere, and the base hears
it by distance - in full at the base, not at all 80 tiles away - so a
surface base barely hears the deep, while a base planted deep hears
everything near it. Sounds made in the quiet layers are never heard.
When the noise meter fills, a Burrower surfaces below you and tunnels to
the run base, and the meter empties - keep
making noise and another comes. Your light slows it; flaring kills
it. If it takes the base from 3 health to 0, the run fails. Reinforced
walls around the base cost a Burrower 2.5s each to chew through (tunnels
you dug near the base are open road), and wear back to plain rock over
time - much faster when the base's light is low.

**Snuffers**: while any lamp is burning, a Snuffer appears every 45s (one
at a time). It drifts through rock to the lamp or base light furthest from
you and drains it dry. Your light drives it off; flaring kills it.

**Layers**: six equal bands, 160 tiles wide and 450 deep in all. Topsoil
and Clay are the quiet zone: nothing there hears you (noise never fills
the meter) and no Stalker ever rises into them, so climbing back up is a
real escape - they are lonely by design. Stone holds gas pockets - green-
tinted rock that releases a lingering gas cloud when you dig it out
(1 health per 1.5s inside) - and your first step into it wakes the
Stalker. Slate is unstable: decay runs twice as fast while you're down
there. Deep rock has gas and is unstable, and wakes a second Stalker.
The Hollow, at the bottom, decays three times as fast. The HUD names
your layer and its hazards; the table in `scripts/mine.gd` (`LAYERS`)
defines them.

**Mine events**: each run carves a few rooms into the rock. An abandoned
camp waits in every layer: search it once for light, ore (more the deeper
it is) and the next page of the old crew's journal, which carries over
between runs; searching lights its lantern, which you can relight later
from your own light. An old lift cage hangs in the shaft near the bottom of Clay: repair it
for 30 ore (quiet - Clay hears nothing), then ride it once straight up to
the surface, escorts and all. The journal's last page marks the depth where
the shaft's collapse ends, and once the journal is finished that page stays
readable at every later camp. A survivor outpost, lit by its fire, sits in Stone, Slate or Deep rock:
trade 20 ore for a supply pack (1 lamp, 2 ladders, 1 anchor - even before
you unlock them; 2 packs per outpost) and recruit its survivor for 40
ore, who then follows you like a rescued miner. The survivors talk, so
lingering there fills the noise meter. A relic vault, a chamber walled in
unbreakable brass-tinted stone, sits in Deep rock or the Hollow: breaking its door is one
press but very loud (60 noise), and the relic inside is worth 150 ore if
you get it home. A collapsing gallery, a room propped with old timbers and
lined with double-value ore, sits in Slate or Deep rock: step in and its
ceiling comes down 12s later (loud). Light doesn't stop it; support beams
do. Anyone still inside is buried (1 damage, dig out), and any ore left
behind is lost. A Stalker nest of pale eggs sits in Deep rock: flare your
lantern beside it for 2s to burn it (loud). A burned nest removes Deep
rock's second Stalker for the rest of the run, or stops it ever waking.

**The Heart of the mine**: the run's goal, a glowing crystal in a chamber
near the bottom of the Hollow. Taking it is loud (50 noise) and wakes the
mine: decay runs twice as fast until the run ends. Get it to the surface
and extract to win the run: it banks 300 ore on top of what you carry.
Each Heart you claim makes every later mine decay 15% faster; the hub
shows how many you've claimed. Lose the run and the Heart stays below.

**The Stalker**: it wakes the first time you enter Stone (a second one
in Deep rock), drifts through rock and always closes in on you. A
lantern above 25% (or a flare) holds it at the edge of your light; below
that it strikes, then backs off for 3s (1.5s with the lantern out) before
coming again. It never
enters the base's light, and never rises into Topsoil or Clay. Falls do
at most 2 damage, so no single fall kills you from full health.

**Sound**: every effect (digging, hits, pickups, placing tools, collapses,
gas, alarms) is synthesized in code at startup (`scripts/sfx.gd`) - no
audio files. Collapses fade with distance and go quiet past 16 tiles, so
you hear the mine closing in around you.

**Mine decay**: in darkness, tunnels you dug refill with rock and cave
floors near you crumble away, a little faster as the run goes on. Light
(yours, lamps, the base, miners) protects the ground around it.

**The dark**: with the lantern at zero and no other light on you, you lose
1 health every 12s, you can't dig, ropes and ladders rot three times
faster, and the Stalker only backs off for 1.5s after a strike. Any light -
the base, a lamp, a camp lantern, a miner - suspends all of it.

**The old mine**: an old timbered shaft runs down the map's centre column
from just under the entrance (dig the crust to get in) into the upper half
of Stone, where it ends in a collapse you have to dig through. An old
ladder runs its length in 8-row pieces, about 30% of them missing, and it
never rots. Crossing a missing piece takes a chain of ropes.

Galleries branch off the shaft, one each in Topsoil, Clay and upper Stone:
two-tile tunnels 24 to 40 tiles long on a random side, a timber post every
6 tiles, plank floors where they cross a cave. The Topsoil and Clay ones
end in that layer's camp, the Stone one at the lost miner; the Clay and
Stone ones have a collapsed section midway that you dig through. (If the
shaft's collapse sits too high in Stone, that layer gets no gallery and the
miner waits where he used to.)

**The Stalker listens**: a loud act (15 noise or more: placing a rope,
ladder or anchor, a hard fall, gas, building, the room events - not a
single dug tile or the mine crumbling) within 30 tiles of a Stalker alerts
it for 4s - it hunts at full speed and forgets any retreat. Nothing in the
base's light changes: it is still pushed out.

**The mine's clock**: from 240s into a run the mine sends waves of Burrowers at the
base, every 90s (shrinking to 45s by 480s, halved while you carry the Heart),
whatever you did. Waves come in cycles of five: 1, 1, 2, 2 and a peak of 4
Burrowers, each cycle one bigger, with a calm of twice the interval after every
peak (never more than 8 alive). A line under Base always shows the countdown
("Wave in 42 s", red in the last 10 s) and marks a peak; the alarm bell adds the
wave's size and rings 10s before it surfaces. When a wave surfaces the screen
shakes and a rumble plays. The base light fights back: a Burrower inside it is
slowed and loses health, faster the fuller the light (a full light kills one in
10s), and three times faster while you flare inside the light - so fuel, walls
and a Lamplighter are your defence while you are away.
Deep digging is quiet to a surface base, but staying long enough costs
you the base anyway.

**Falling**: landings hurt based on impact speed. Drops under 7 tiles are
free (so plain digging down is safe), 7+ costs 1 health, +1 per 3 more
tiles. Hard landings also make noise.

**Lost miners**: each run hides one lost miner (faintly lit, each with their own shirt colour) on a
cave floor around the bottom of the quiet zone. Touch them and they follow your trail; extract
with them and they join the roster. Each miner has a type, and on your crew
that type is their job at the run base, done on their own at a station beside
the flag for the whole run (rates are Rookie rates; Seasoned is 1.5x, Veteran 2x):
the Mender (Repair) mends the base 1 health per 12 s for 5 of your ore, the
Lamplighter (Light) refines 4 ore into 20 base fuel every 15 s while the base light
is under 90%, the Climber (Traversal) makes a ladder, anchor or lamp every 60 s for
6, 10 or 8 ore (only unlocked tools, at most 2 of each per run), and the
Whisper (Noise) makes everything the base hears 25% quieter, free and silent. Jobs
spend the ore you carry and pause when you have none; every working miner but the
Whisper adds a little noise at the base, so a bigger crew is a louder base (a base
in the quiet layers is not heard). New finds lean toward types you don't have yet.
You start with one crew slot; pick who fills it at the hub.
Crew gain a run of experience whenever a run they were on ends in
extraction: Seasoned at 2 runs (bonus x1.5), Veteran at 5 (bonus x2, plus
a title such as "Ada the Lamplighter", plus a quirk - a small effect such
as Night eyes, Pack rat or Sure-footed, or the odd downside like Hums
while working). Fail the run while escorting and they are stranded in the layer
they were lost in: the hub shows where, they drift one layer deeper for
every run that ends without rescuing them, and drifting past the Hollow
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
  the next layer (from the Hollow, back to the base), `M` reveal the map

The controls overlay (`Esc`) lists them when debug is on.

`tests/balance_probe.gd` has bots play whole runs (a nonstop dive, and
standing still until the light fails) over three seeds and prints each
run's log line - compare the output before and after a tuning change:
`godot --headless --fixed-fps 60 -s tests/balance_probe.gd`.

`tests/playtest.gd` plays scripted scenarios in the real game with key
presses and saves a screenshot per step to `playtest_out/`:
`xvfb-run -a godot --fixed-fps 60 -s tests/playtest.gd`. CI runs it on
every pull request; the screenshots are attached to the run as
`playtest-screenshots`.

## Project layout

- `scenes/` — Main, Player, Mine, HUD, and one scene per enemy, tool and
  mine event (Stalkers are spawned by Main as you descend)
- `scripts/` — one script per scene/system (`mine.gd` generates its own
  tileset; creatures, pickups, the miner and every placed or event object
  are drawn in code at runtime: `creature_art.gd`, `gear_art.gd`, shown
  pixelated by `art_sprite.gd`; contact-sheet previews are `tools/preview_*.gd`)

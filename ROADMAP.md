# Down Mine - Roadmap

Every pillar in `MineRoguelike_PRD.md` has a first version (milestones
1-21). What follows is the planned order for the rest, grouped by what
each step unblocks. Numbers are provisional; reorder as play testing
dictates.

## Next: tune from real play

- **M22 - Tuning pass.** Adjust from hand play testing. Known suspects:
  Stalker damage at low fuel, lamps per run (3), mine decay rate on long
  runs, Burrower speed vs wall chew time, ore costs (repair, fortify,
  upgrades), hub text size (16pt).
- ~~**M23 - Headless test harness.**~~ Done: `tests/`, run by CI on
  every pull request.

## Finish the NPC pillar

- ~~**M24 - Crew join runs.**~~ Done: crew wait at the base and are
  stranded in its layer when a run fails.
- ~~**M25 - Stranding signs.**~~ Done: glowing shirt scraps lead to each
  stranded miner; Veterans leave more, brighter ones.
- ~~**M26 - Veteran quirks.**~~ Done: six quirks, one per Veteran,
  distinct across the roster.

- ~~**M32 - Base buildings.**~~ Done: support beams, a beacon and an
  alarm bell, paid from run ore.

## Traversal depth

- ~~**M27 - Ladders and anchors.**~~ Done: ladders (T), anchors (G) the
  grapple pulls to, and the traversal miner's rope-life/ladder bonuses.
- ~~**M28 - Hub tool unlocks.**~~ Done: lamps, ladders and anchors are
  hub unlocks; the grapple and ropes stay free as the baseline.
- ~~**M38 - Movement feel.**~~ Done: step up 1-tile bumps; release jump
  early for a short hop.
- ~~**M42 - Mantle.**~~ Done: in mid-air, holding into a wall whose top
  is within 14 px of your feet pulls you over the lip - 2-tile ledges
  yes, 3-tile no.

## Content and presentation

- ~~**M29 - Layer identity.**~~ Done: gas pockets in Stone; Deep rock
  decays twice as fast and wakes a second Stalker.
- ~~**M30 - Art pass.**~~ Done: fuel, ore, the Stalker and ropes use
  tileset art. The base flag, lamps, ladders and anchors keep their
  drawn shapes - the pack has nothing that fits them.
- ~~**M39 - Custom props.**~~ Done: every placed tool, base building,
  mine event object, the gas cloud and stranding signs are pixel
  sprites drawn by `tools/make_props.py` from the pack's palette.
- ~~**M31 - Sound.**~~ Done: eight synthesized effects; collapses fade
  with distance.

## Mine events

- ~~**M33 - Event rooms, camps and the lift.**~~ Done: rooms carved each
  run; an abandoned camp per layer (light, ore, journal pages, a
  relightable lantern); an old lift that repairs for ore and noise and
  rides once to the surface.
- ~~**M34 - Survivor outpost.**~~ Done: a lit camp in Stone or Deep;
  trade ore for supply packs, recruit its survivor; lingering is noisy.
- ~~**M35 - Relic vault.**~~ Done: a sealed chamber in Deep rock; its
  door breaks with 60 noise; the relic is worth 150 ore.
- ~~**M36 - Collapsing gallery.**~~ Done: double-value ore; the room
  fills with rock 12s after you enter unless supports hold it.
- ~~**M37 - Nest.**~~ Done: flare beside the eggs for 2s to burn them;
  the deep's second Stalker is gone for the run.

## Run goal

- ~~**M40 - The Heart of the mine.**~~ Done: a crystal near the bottom;
  taking it wakes the mine (loud, decay x2); bringing it home wins the
  run (+300 ore); each claimed Heart makes later mines decay 15% faster.

## Onboarding

- ~~**M41 - Title and controls.**~~ Done: a title screen once per
  launch, and a controls overlay on Esc (pauses; hint in the corner).

## Testing tools

- ~~**M43 - Seeds and debug keys.**~~ Done: seeded mines (`?seed=`),
  seed on the HUD and summary; debug keys with `?debug`.
- ~~**M44 - Playtest runner.**~~ Done: `tests/playtest.gd` plays five
  scenarios in the real game with real keys (title and controls, digging,
  step-up and mantle, camp, the Heart run); CI uploads the screenshots.
  It found that digging down from an off-centre spot never dropped you
  into the hole - fixed.
- ~~**M45 - Run log.**~~ Done: the last 10 runs (result and cause of
  death, time, depth, ore, Burrowers, hits by source, seed) are saved;
  L at the hub shows them. The data for the M22 tuning pass.
- ~~**M58 - Touch controls.**~~ Done: on a touch device (or with `?touch`) the game shows a
  pad (move, jump, dig down, stairs), Dig, Flare, Use and one Tools menu (the tools you own and,
  at the base, Plant, Repair, Fortify and Grow), with buy buttons in the hub and Continue and
  Esc while paused; landscape only, same keys as the keyboard. After the first phone test, pushing the pad into rock digs forward by itself (touch only) and stairs need a firmer diagonal. The game now scales to the window.
  Not done: a real-device test (the first check is opening the deployed build on a phone),
  drawn icons in place of text labels. Spec: `docs/superpowers/specs/2026-10-11-touch-controls-design.md`;
  plan: `docs/superpowers/plans/2026-10-11-touch-controls.md`.
- ~~**M59 - Movement feel.**~~ Done: digging is a third slower (`DIG_COOLDOWN` 0.165), gravity is lighter
  (490), and a bump is stepped over rather than dug while falling. A jump plus mantle still reaches
  3-tile ledges, not 4. The balance probe barely moved (a pure dive still reaches depth 444 before the
  light fails). Not done: a real hand-play tuning pass (issue #26).
- ~~**M60 - Torches.**~~ Done: permanent wall torches light Topsoil and Clay, one every 10 rows down the
  old shaft and 12 on cave floors. They are lights for decay and ropes but not lamps, and Snuffers
  ignore them. Not done: taking, lighting or snuffing torches, torches below Clay.
- ~~**M61 - Gentler early decay.**~~ Done: mine decay runs at half speed in Topsoil and Clay (the
  layer's `decay` multiplier is 2.0), so tunnels refill and floors crumble half as often while you are
  in the quiet layers. Deeper layers are unchanged. The number is a starting value to tune by hand-play.
- ~~**M62 - Touch wording.**~~ Done (issue #61, from the UI/UX audit): with the touch controls showing, prompts,
  the controls overlay, the title and the run summary name the buttons (Use, Tools, Continue, Help) instead
  of keys; the top-right "Esc: controls" text is hidden, the ESC button is labelled HELP, and the prompt line
  is hidden while paused so it no longer sits under Continue. Keyboard wording is unchanged.
- ~~**M63 - HUD pass.**~~ Done (issue #62, from the UI/UX audit): Light and Health are larger, Light has a bar
  (red under 25 percent), Health shows current over maximum (new `Player.max_health`), labels are outlined, the
  layer line says "N tiles deep", the always-on seed moved into the controls overlay, and the compass arrow
  has a "Base" label. Not done: icons (they need new art).
- ~~**M64 - Hub clarity.**~~ Done (issue #63, from the UI/UX audit): a building's prompt names it and lists each
  offer with what it gives (the upgrade's effect), level and cost; the notice board prompt reads "read" and then
  "close"; a first visit shows one line saying where to go. The rest of #63 followed: the hub has a drawn gradient sky (deep indigo overhead, pale rose-purple at
  the horizon) and the notice board closes when you walk away from it.
- ~~**M65 - Touch button looks.**~~ Done (issue #64, from the UI/UX audit): the Tools menu items share one label
  size (so GRAPPLE no longer shrinks), held buttons have a double border, the Tools toggle a small up triangle,
  and a pressed button's outline turns white. Not done: audio volume, mute and text size settings (YAGNI until
  hand-play shows a need), and drawn icons.
- ~~**M66 - Abandon a run.**~~ Done (issue #68): from the controls overlay in the mine, `X` twice (or the ABANDON button
  tapped twice on touch) ends the run as a death does: the carried ore is lost, escorted and base-crew miners are
  stranded, and the run is logged as "Abandoned". Not offered in the hub, on the title or after the run ends.
- ~~**M67 - Test hygiene and group constants.**~~ Done (issue #72, from the architecture review): `TestHooks.reset` puts
  every static test or launch hook back to its baseline before and after each test and between playtest
  scenarios (the unit runner also clears the test save), so no test depends on what an earlier one left behind. A
  guard test fails when a new `static var` is neither reset nor explained, and `Groups` names the 12 node groups
  by constant (a second guard fails on a bare group string). Tests and structure only: no gameplay change.
- ~~**M68 - Typed run context for mine events, shared key edge.**~~ Done (issue #73, from the architecture review): event
  nodes (camp, lift, heart, relic, outpost, vault door, lost miner, nest, gallery) take a `RunContext` instead of an
  untyped `Main`, so what events may reach (player, HUD, noise meter, mine, and five run actions) is written down in
  one file; a guard test fails on a `use`/`prompt` that takes a bare `Node`. `KeyEdge` replaces the hand-rolled
  `_was_pressed` variables for the base, lamp, plant and extract keys and the rope, ladder, anchor and grapple keys
  (jump keeps its own, since it is only sampled off a rope). Structure only: no gameplay change.
- ~~**M69 - Versioned save file.**~~ Done (issue #77, from the architecture review): `Progress.SAVE_VERSION` is written under
  `[meta]` and `load_saved` runs `_migrate` before reading anything, one step per version, so the next change to the
  saved shape converts old saves instead of dropping them. The first step is the old inline crew default; a frozen
  pre-versioning save in the tests is the regression net. A save from a newer game loads without crashing.
- ~~**M70 - Faster unit tests.**~~ Done (issue #82): the runner prints the slowest 15 tests and each file's total, and
  tests that only read a mine share one per seed (`TestCase.shared_mine`, generated once and kept out of the tree)
  instead of generating it again; a mine costs about a second. The unit suite went from about 5:45 to 4:00 locally
  (`test_world` 206 s to 99 s). `test_main` (about 100 s, one Main scene per test) is the next cost, and the
  structural fix is the pure `MineGenerator` of #74. Tests only: no gameplay change.
- ~~**M71 - Pure mine generator.**~~ Done (issue #74, stage 1 of 2; spec and plan in `docs/superpowers/`): seed-to-layout
  generation moved out of `MineGrid` into `MineGenerator.generate(seed)`, which returns a node-free `MineLayout`;
  `MineGrid` builds the tileset, applies the layout and copies it into the fields the game already reads, so no caller
  changed and `mine.gd` went from 951 to about 635 lines. A golden fingerprint test (31 seeds, recorded from the old
  code before anything moved) proves every seed still builds the same mine, tiles, decor, rooms, pickups and torches.
  The slowest generation tests now read the layout with no scene. Suite time is about level for now (generation is
  still about 0.9 s a mine, and the golden net adds about 40 s); stage 2 rewrites the smoothing, the 0.65 s of it.
- ~~**M72 - Faster mine smoothing.**~~ Done (issue #74 stage 2, issue #82): the cave smoothing runs over a flat byte array
  (`MineGenerator.smooth`, one column-triple sum per cell instead of eight lookups), checked cell for cell against the
  old nested-array algorithm and by the 31 golden seeds. A mine takes about 0.5 s to generate, down from about 0.95 s;
  the local unit suite went from about 4:56 to 3:07 (it was 5:45 before #82). Tests and generation speed only: every
  seed still builds the same mine.
- ~~**M73 - Round-trip bot, and digging up on a rope.**~~ Done: `tests/balance_probe.gd -- trip` digs to 50, 100, 150 and 200
  tiles and climbs home on ropes. It showed the return from Stone was impossible for a reason in the code, not in
  the numbers: a player on a rope could not dig, and the mine refills dark tunnels, so a rope ending under rock
  trapped them. Holding `W` and `Space` now digs up while on a rope or ladder. With that, a perfect base-kit dive to
  200 tiles gets home with 1 to 5 seconds of light left.
- ~~**M74 - Heart-run bot.**~~ Done: `tests/balance_probe.gd -- heart` walks the surface to above the Heart (435 tiles
  down, 19 to 66 tiles off the entrance shaft), digs down onto its room, takes it and climbs home, with the lantern
  at level 3 and nothing else. On six seeds it takes the Heart every time and gets home none of them: five Stalker
  deaths on the climb, one stranded in the dark. With `flare` the Stalker deaths become six strandings in the dark
  (flaring burns light four times faster), so light is the limit; each seed has 20 to 27 fuel pickups within 6 tiles
  of the Heart's column. `detour=N` models taking them at N seconds of light each: the Heart is won on all six seeds
  up to about 8 s a detour, five of six at 15 s, none at 20 s or more. The win needs a nearby pickup to cost a player
  under about 15 seconds to reach, in the dark. Next: how findable they are.
- ~~**M75 - Typed mine data.**~~ Done (issue #75, from the architecture review): `Drift`, `EventRoom` and `TorchSite` replace the
  untyped dictionaries in `MineLayout` and `MineGrid`, so a mistyped field is an error instead of a silent `null`, and
  the cross-file contract is written in three small classes (a drift's collapse and end are now plain fields; an
  event room's `in_shaft`, `at_drift_end` and `door` replace keys that were sometimes present). Each has a `to_dict()`
  that returns the old dictionary key for key, and the golden fingerprints hash that, so all 31 recorded seeds
  still match without re-recording. The save-file dictionaries are left for later, as the issue says.
- ~~**M76 - Random numbers in generation: decision recorded.**~~ Done (issue #76, from the architecture review): generation keeps
  using the global random generator for the floor-cell shuffle and the fuel pickups' draw, because changing it would
  change every noted seed. `MineGenerator`'s header now lists every random source and its offset (51 old mine, 52 torches,
  53 next free), the rule that new randomness gets its own generator at the next offset, and the procedure for a
  deliberate layout change (re-record the golden fingerprints from the old code and say so in the PR). The pins that
  already exist stay: the golden fingerprints hash the global generator's end state, and tests pin one draw per
  pickup and that art and camera shake stay off the global generator. No seed version number until a seed is
  deliberately broken.
- ~~**M77 - HUD overlay as one state.**~~ Done (issue #78, from the architecture review): what the full-screen overlay shows is one
  enum, `HUD.Overlay { NONE, TITLE, CONTROLS, ASK_ABANDON }`, instead of `_showing_title`, `_confirm_abandon` and checks of
  `overlay.visible`. `_set_overlay` is the one way in (text, visibility and pause), `_overlay_key` is a `match` on the state
  with the transitions it always had, and `can_abandon` is derived from it. The run summary stays its own node (it can be
  open under the controls) and the hub only picks the text. A table-driven test lists every transition; behaviour is unchanged.

## Quality pass

- ~~**M46 - Gameplay quality pass.**~~ Done, from bots playing real runs:
  - The Stalker stopped dead when out of range and was blocked by rock,
    so outpacing it once made darkness safe forever. It now drifts
    through rock and hunts; it also backs off 3s after each strike (it
    used to kill in 2.4s, before you could react).
  - The noise meter stayed pinned at its cap while you kept digging, so
    nonstop noise brought one Burrower. It now empties when it fills:
    about one Burrower per 30 tiles of nonstop digging.
  - One long fall through a cave ceiling could kill from full health
    (4 damage). Falls now do at most 2.
  - `tests/balance_probe.gd` keeps the bots for tuning.
- ~~**M47 - Movement quality pass.**~~ Done, from a movement probe on
  test courses: ropes hung from your own cell into the rock below, so
  they couldn't get you up a shaft or down a drop - R now throws a rope
  up and S+R drops one over an edge. Anchors couldn't reach you in a
  narrow pit (the line clipped the pit wall) - they now pull up, then
  across. The courses (tunnel, staircase, ropes both ways, ladder,
  anchor, grapple) run in the CI playtest. Without tools you still
  can't climb out of a pit deeper than 2 tiles, by design.
- ~~**M48 - Six layers, a lonely top, a bigger mine.**~~ Done: the mine
  is 160x450 with six equal layers defined in one table
  (`MineGrid.LAYERS`: look, cave density, ore, hazards). Topsoil and
  Clay are quiet: noise never fills the meter and no Stalker rises into
  them; the Stalker now wakes on the first step into Stone (a second in
  Deep rock), spawned by Main rather than placed at the surface.
  Movement: 1-tile bumps are stepped over before Space digs them,
  digging down descends at a steady speed instead of landing every
  couple of tiles, and staircases only dig from the floor.
- ~~**M49 - The dark hurts.**~~ Done: at zero light you drain, can't dig,
  your tools rot and the Stalker returns sooner; any other light
  suspends it. Spec: `docs/superpowers/specs/2026-10-09-run-loop-redesign-design.md`.
- ~~**M50 - Two listeners and the mine's clock.**~~ Done: noise carries a
  position, the base hears by distance (80 tiles), Stalkers within 30
  tiles hear loud acts, and the mine sends a Burrower at the base every
  90s shrinking to 45s from 240s into the run. Spec: same as M49.
- ~~**M51 - The old mine**~~ Done, in three parts (spec: same as M49).
  - ~~**M51a - The shaft.**~~ Done: a timbered shaft on the centre column
    ends in a 6-row collapse in upper Stone; an old ladder of 8-row pieces
    (30% missing, never rotting) runs its length.
  - ~~**M51b - Galleries.**~~ Done: a gallery per worked layer off the
    shaft (posts, plank floors over caves); Topsoil and Clay end in their
    camp, Stone at the lost miner; Clay and Stone have a collapsed section.
  - ~~**M51c - The works' contents.**~~ Done: the lift cage hangs in the
    shaft near the bottom of Clay (its repair is quiet, Clay being a quiet
    layer); the journal's last page marks the depth where the collapse
    ends. (Camps and the lost miner moved into the galleries in M51b.)
  - **Known difficulty:** straight dig-up from below reaches only about
    two rows (a jump rises 1.8 tiles and nothing digs while on a rope or
    ladder), so the 6-row collapse is climbed with a stair dug beside it:
    dig up two cells, jump, dig the notch ahead at the apex, step in,
    repeat. It works (about 32s for the climb in `shaft_from_below`) but is
    slow and loud. The journal's last page says so.
- ~~**M52 - Art for the works.**~~ Done: the shaft frame, gallery post,
  plank floor and collapse debris are drawn tiles (`tools/make_props.py`,
  the props sheet, rows from y=176) in the pack's wood palette: outlined,
  shaded timber, with tumbled stones and splintered beams over the
  collapse. Prototypes and the choice: `docs/m52-prototypes/`.
- ~~**M53 - Drawn creatures and gear.**~~ Done: the Stalker (a spider),
  Burrower (a low many-legged crawler with mandibles), Snuffer, fuel and
  ore pickups, the miner and lost miners, the base flag, beacon and bell,
  supports, lamps, anchors, ladders, ropes, and the camp, outpost, lift,
  nest, Heart, relic, vault door, stranded signs and gas are drawn in code
  (`scripts/creature_art.gd`, `scripts/gear_art.gd`) and shown pixelated
  through small viewports (`scripts/art_sprite.gd`), redrawing at 20 fps and
  only while on screen. Ladders, ropes and supports visibly wear out. Plan:
  `docs/superpowers/plans/2026-10-10-m53-drawn-creatures-and-gear.md`.
- ~~**M54 - Workers and jobs.**~~ Done: crew types are jobs done at the run
  base on their own (Mender mends, Lamplighter refines ore into base fuel,
  Climber makes ladders, anchors and lamps, Whisper hushes the base), paid in
  carried ore and noise, at drawn stations beside the flag where the miners
  dig while they work. The old hidden type bonuses are gone. Piece 1 of the
  Two Crowns inspired design (#35); next are the rhythm of threat (#36), the run
  base as a settlement (#37) and the hub as a kingdom (#38). Spec:
  `docs/superpowers/specs/2026-10-10-workers-and-jobs-design.md`; plan:
  `docs/superpowers/plans/2026-10-10-workers-and-jobs.md`.
- ~~**M55 - Rhythm of threat.**~~ Done: the mine's waves come in cycles of five
  (1, 1, 2, 2, then a peak of 4, each cycle one bigger) with a calm after each
  peak and at most 8 Burrowers alive; the HUD always shows the countdown, the
  bell adds the size; a tremor and a rumble mark each wave; the base light now
  slows and damages Burrowers, tripled while the player flares inside it. Piece 2
  of 4 of the Two Crowns inspired design (#36); next are the run base as a
  settlement (#37) and the hub as a kingdom (#38). Spec:
  `docs/superpowers/specs/2026-10-10-rhythm-of-threat-design.md`; plan:
  `docs/superpowers/plans/2026-10-10-rhythm-of-threat.md`.
- ~~**M56 - The run base as a settlement.**~~ Done: the base grows in three tiers
  (Camp, Outpost, Fort) bought with one key (U) and carried ore, raising its max
  health (3, 4, 5), its light's fuel (200, 260, 340) and how long a reinforced wall holds
  a Burrower (2.5, 3.5, 5 s); the Outpost brings the beacon and the Fort the bell (so the
  2 and 3 keys are gone and the wave size on the HUD needs the Fort); a palisade and a stone
  rampart show the tiers. Piece 3 of 4 of the Two Crowns inspired design (#37); next is the
  hub as a kingdom (#38). Spec: `docs/superpowers/specs/2026-10-10-run-base-settlement-design.md`;
  plan: `docs/superpowers/plans/2026-10-10-run-base-settlement.md`.
- ~~**M57 - The hub as a kingdom.**~~ Done: the hub is a drawn place you walk as the miner,
  with a lamp shop, a smithy, a bunkhouse, a notice board and the mine entrance. Buildings
  sell the same upgrades at the same prices (`1` to `3` beside one), rostered miners stand by
  the bunkhouse and join or leave the crew with `E`, the board shows the run log, the journal
  and stranded miners, and the entrance starts a run. A run still ends on the summary; Enter
  goes to the hub, and the game opens there. Piece 4 of 4 of the Two Crowns inspired design
  (#38). Not done: touch controls (the Mobile item above), building levels, a second currency.
  Spec: `docs/superpowers/specs/2026-10-11-hub-as-kingdom-design.md`; plan:
  `docs/superpowers/plans/2026-10-11-hub-as-kingdom.md`.
- **Tuning knobs to revisit in M22:** dig noise per tile (6), the
  Stalker's strike threshold (25% light), lantern size (60s - a dive to
  the Heart is now ~55s one way), stranded drift (5 runs to die now,
  the PRD said 3).

## Open design questions (from the PRD)

- What takes stranded NPCs deeper: creatures, a shifting mine, or fleeing?

## Housekeeping

- Record the Deep Night asset pack's license and author credit
  (opengameart.org/content/deep-night-8x8-platformer-assets).

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
- **Mobile.** The web build doesn't open on phones. Needs looking into
  (likely the web export's requirements), then touch controls.

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
- **Tuning knobs to revisit in M22:** dig noise per tile (6), the
  Stalker's strike threshold (25% light), lantern size (60s - a dive to
  the Heart is now ~55s one way), stranded drift (5 runs to die now,
  the PRD said 3).

## Open design questions (from the PRD)

- What takes stranded NPCs deeper: creatures, a shifting mine, or fleeing?

## Housekeeping

- Record the Deep Night asset pack's license and author credit
  (opengameart.org/content/deep-night-8x8-platformer-assets).

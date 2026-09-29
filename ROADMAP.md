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
- **Next:** a committed playtest runner that drives key scenarios in CI
  and attaches screenshots; a run log for tuning.

## Open design questions (from the PRD)

- What takes stranded NPCs deeper: creatures, a shifting mine, or fleeing?

## Housekeeping

- Record the Deep Night asset pack's license and author credit
  (opengameart.org/content/deep-night-8x8-platformer-assets).

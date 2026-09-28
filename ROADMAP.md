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

## Content and presentation

- ~~**M29 - Layer identity.**~~ Done: gas pockets in Stone; Deep rock
  decays twice as fast and wakes a second Stalker.
- ~~**M30 - Art pass.**~~ Done: fuel, ore, the Stalker and ropes use
  tileset art. The base flag, lamps, ladders and anchors keep their
  drawn shapes - the pack has nothing that fits them.
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
- **M37 - Nest.** Stalker eggs in the deep; flare them out and the layer
  is safer for the rest of the run.

## Open design questions (from the PRD)

- Does a run have a final goal or ending at the deepest layer?
- What takes stranded NPCs deeper: creatures, a shifting mine, or fleeing?

## Housekeeping

- Record the Deep Night asset pack's license and author credit
  (opengameart.org/content/deep-night-8x8-platformer-assets).

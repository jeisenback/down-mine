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
- **M23 - Headless test harness.** Keep a few automated checks for the
  core rules (fall damage, repair cost, drift, Stalker strike rule) that
  run with `godot --headless`, so tuning can't silently break them.

## Finish the NPC pillar

- **M24 - Crew join runs.** Crew appear in the mine and wait at the base;
  if the base falls they are stranded (the PRD's missing stranding cause).
- **M25 - Stranding signs.** Replace the HUD arrow with in-world signs
  (dropped gear, wall marks, faint lights); Veterans leave clearer ones.
- **M26 - Veteran quirks.** One small quirk per Veteran, flavour plus a
  minor effect.

## Traversal depth

- **M27 - Ladders and anchors.** The PRD's other consumable traversal
  tools, plus the traversal miner's rope-life and ladder-speed bonuses.
- **M28 - Hub tool unlocks.** Some tools (grapple, ropes, lamps) become
  hub unlocks - "the hub grants capabilities" - giving banked ore a
  longer-term use.

## Content and presentation

- **M29 - Layer identity.** Each layer gets its own hazards and enemy
  mix (e.g. gas pockets in Stone, Burrowers only below a depth).
- **M30 - Art pass.** Replace remaining placeholder shapes (pickups,
  base flag, ropes, lamps) with tileset art.
- **M31 - Sound.** Digging, collapses, enemy cues - noise is a core
  mechanic, so audio feedback matters.

## Open design questions (from the PRD)

- Does a run have a final goal or ending at the deepest layer?
- What takes stranded NPCs deeper: creatures, a shifting mine, or fleeing?

## Housekeeping

- Record the Deep Night asset pack's license and author credit
  (opengameart.org/content/deep-night-8x8-platformer-assets).

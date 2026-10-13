# Old workings: long galleries, connectors to rooms, and visual clues (issue #26 follow-up)

From hand-play feedback on 2026-10-13: the game is too hard, the player needs room to wander, and the mine should feel like one that has decayed. PR #95 slowed the lantern (0.5 burn rate). Bots then showed that a perfect line to the Heart still has little spare, so the next lever is the mine itself, not a smaller number.

## Goal

Give the whole mine passages worth following:

- galleries are long (60 to 100 tiles), decayed (several collapses, uneven timber) and in every layer, not just the top three;
- they carry loot (fuel and ore along their floors) and lead somewhere: branches to the layer's rooms, and the deepest ones heading toward the Heart's side of the map;
- the player can tell, from light and timber, where a worked passage is.

Constraints:

- The seed stays a promise only within a version: every mine's layout changes, the golden fingerprints are re-recorded on purpose from the old code, and the PR says so.
- No new systems. Clues reuse torches, posts and frames. No new hazards.
- Fuel in the mine stays the same in total (gallery pickups replace cave pickups). Tuning light is a separate decision, made after hand play.

## What exists (read from the code)

- Six layers (0 to 5), 160 x 450 grid. The old shaft's open part reaches layers 0 to 2 only; below that it is collapsed. So a gallery cannot be fed from the shaft below Stone.
- `_carve_drifts` makes one straight two-tile `Drift` per layer 0 to 2 off the shaft: 24 to 40 long, a post every 6 tiles, one 4 to 8 tile collapse (layers 1 and 2), a camp (layers 0 and 1) or the lost miner (layer 2) at the far end.
- Rooms (`EVENT_ROOMS`, 9 x 4): Heart (layer 5, carved first), camps in layers 2 to 5, outpost (2 to 4), vault (4 or 5, sealed on purpose), gallery room (3 or 4), nest (4). They are carved after the old mine and keep out of its rectangles.
- Player: step height one tile, jump about 2.5 tiles. A passage whose floor rises or falls by one tile at a time is walkable both ways.

## Design

### Workings: one gallery system per layer

Every layer 0 to 5 gets a **working** made of a **spine** and **connectors**.

- **Spine.** A straight two-tile tunnel, 60 to 100 tiles, at a random row inside the layer.
  - Layers 0 to 2: leaves the shaft at the drift's current mouth (same landing, same planks), so the existing shaft contents keep working.
  - Layers 3 to 5: free-standing, with no shaft link. You find it by digging into it. Its ends are at least `WORKING_EDGE_MARGIN` tiles from the map edge.
- **Decay.** 2 to 4 collapses of 3 to 8 tiles per spine (layers 1 to 5), at least 4 open tiles between them and at each end. Posts every 5 to 8 tiles (random gap), a quarter of them missing. Cave crossings are floored with planks, as now.
- **Heart-ward bias.** The Heart is carved first (before the old mine) so its column is known. Each spine of layers 3 to 5 starts on the side of the map away from the Heart's column and runs toward it; the layer 5 spine stops at least `HEART_STANDOFF_TILES` (10) short of the Heart room. Layers 0 and 1 pick their shaft side at random, as now; the Stone spine (layer 2) takes the side of the shaft facing the Heart's column.
- **Ends.** Layers 0 and 1 keep a camp at the far end, layer 2 the lost miner, as now. Layers 3 to 5 have no end feature (their camps are the existing rooms).

### Connectors: passages to rooms

After the rooms are carved, each room in a layer that has a spine and is neither the vault nor the Heart gets a **connector** with probability `CONNECTOR_CHANCE` (about 0.8).

- A connector is a two-tile passage from the nearest spine cell to the room's edge, **stepped**: the floor changes by at most one tile at a time, and each level lasts at least 2 tiles, so it can be walked up and down. Fall and rise are spread along the run.
- Skipped when it would exceed `CONNECTOR_MAX_LENGTH` (70 tiles), cut through another room, the vault shell, the Heart or the shaft, or cross a spine collapse.
- Layers cross cave: planks floor the cave crossings, as spines do.
- Layers 3 to 5 therefore have a worked way to their camps, outpost, gallery room and nest. The Heart and the vault are deliberately not connected (digging onto the Heart is the finish; the vault is sealed).
- Each connector may have one collapse (layers 1 to 5).

### Loot along the way

Gallery floors take pickups: about one fuel per 12 tiles of passage and one ore per 25. They replace the same number of cave pickups (the totals `FUEL_DEPOSIT_COUNT` and `ORE_DEPOSIT_COUNT` do not change), so following a gallery is a better bet than hugging the cave floors, and the mine holds the same amount of fuel overall.

### Clues (phase 3)

- **Lit spine.** One torch per `SPINE_TORCH_SPACING` tiles (about 30) along each spine that is worked, as `TorchSite` with kind `"gallery"`. A lit torch is visible beyond the lantern radius, so a spine shows from a distance. Lit ground also spares tunnels from decay, so lit spines are partly safe corridors: this is a balance effect, flagged below.
- **Branch mouths.** A post pair (the existing frame/post decor) frames every connector's mouth, so the side branch reads at a glance.
- **Fuel glint.** A small twinkle on fuel pickups. Art only: it draws no random numbers and never touches the seed.

## Units

- `MineGenerator`: replace `_carve_drifts` with `_carve_workings` (spines) and add `_carve_connectors` (after `_carve_event_rooms`). Carve the Heart first. All new randomness uses a new `RandomNumberGenerator` seeded `mine_seed + 53` (offsets 51 and 52 keep their streams; the header documents it). The shaft end and ladder pieces are drawn before the drifts and keep their values; the lift draws after and moves.
- `Drift` stays the spine (it gains `collapses: Array[Rect2i]` in place of the single `collapse`). New typed `Connector` (`room`, `cells`, `collapses`), with a `to_dict()` for the fingerprint, like `Drift`.
- `MineLayout`: `connectors: Array[Connector]`; `room_cells`, `reserved_floors`, `plank_cells`, `debris_cells` include the new cells so existing rules (no pickups on reserved floors, no gas inside) keep working.
- `MineGrid._apply`: instantiate gallery pickups and the gallery torches; no other change. Constants live on `MineGrid` next to the existing `DRIFT_` ones.
- Anything reading `drift.collapse`, `drifts` by layer, or `old_mine_rects` (lost miner, camps at drift ends, room placement) is updated; `old_mine_rects` includes spines and connectors.

## Testing

- **Golden fingerprints** re-recorded from the old code for the layout change; the PR says so.
- **Layout-only property tests** (no scene, 31 seeds, via `shared_layout`): every spine cell is open with headroom 2 and a floor underneath (a plank where it was cave); consecutive floor cells differ by at most one; each collapse leaves clear ends; no spine or connector touches a room it should avoid; every connector reaches its room's edge; the vault and Heart have none; each layer 3 to 5 spine heads toward the Heart's column and the layer 5 one ends at least 10 short of it; gallery pickups sit on gallery floors and totals are unchanged.
- **Generation time** stays within 0.1 s of today's.
- **Bots:** `-- trip` and `-- heart` before and after, reported in the PR. Not a pass/fail gate (bots cannot judge feel).
- **Reachability:** a layout-only flood fill from the spine confirms each connector's room is reachable on foot from its spine.

## Phases

1. Spines in every layer: length, decay, Heart-ward bias, deeper layers, gallery loot.
2. Connectors to rooms.
3. Clues: lit spine torches, branch-mouth posts, fuel glint.

Each is one PR from this spec. I play after each.

## Out of scope

- New mechanics, hazards or enemies in galleries; a new ladder or lift.
- Changing the shaft, the grid size, the number of layers, the room list or their spacing.
- Light budget, damage or pickup values (tuning stays separate).
- The global random generator.

## Risks and open questions

- **Lit spines change balance.** Lit ground stops decay. If lit galleries make the mine too safe, thin the torches (`SPINE_TORCH_SPACING`) or make them dead sconces that only mark the way. Decide after phase 3 is played.
- **Connector length.** A 70-tile cap on a one-tile-per-two-tiles staircase covers a rise or fall of about 35 rows. Rooms farther away than that in one layer get no connector. Check the skip rate over the 31 seeds; raise the cap if too many rooms are left alone.
- **Free-standing workings can be missed** (that is the point: found by digging), but if the clues are too faint the player never finds them. Phase 3 is where that gets judged.
- **Generation order.** Moving the Heart earlier must not change other rooms' placement: no other code draws from the room generator between the fill and the rooms. A test confirms it by checking that, with the workings off, the fingerprint of rooms equals the old one.

## Implementation notes (phase 2)

Building the connectors changed three things from the text above; the plan's ledger has the reasons.

- A connector cannot share columns with a horizontal spine without cutting its floor. It leaves through a two-column pit and descends below the spine's floor, so only rooms at least two rows under their spine are served, and a flat run covers any remaining distance.
- Spines sit in the upper third of their layer so that most rooms lie below them. Even so only about 20% of eligible rooms are connected (11% at or above the spine, 30% too deep for the 70-tile cap, 23% lose the 0.8 chance roll, the rest meet an obstacle).
- Connectors have no collapses of their own (the spec said "may").

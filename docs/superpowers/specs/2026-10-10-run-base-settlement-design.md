# Run base as a settlement: three tiers that grow during a run

2026-10-10. Design for planning issue #37 (piece 3 of 4: workers and jobs #35 and rhythm of threat #36 are done, then this, then hub as a kingdom #38). Agreed in conversation. Numbers are starting values for the balance probe to check, not commitments.

## Why

The run base is a bundle of one-off purchases around a stat. It has 3 health; you hold F to repair it (10 ore a point), press B to fortify the rock around it (2 ore a tile), and build a beacon (30 ore) and a bell (20 ore), once each, with the 2 and 3 keys. Its light is the shared clock and the refuel tank. Since milestone 54 crew work at stations beside its flag, and since milestone 55 its light slows and damages Burrowers.

Nothing about it grows. Every spend is separate, nothing visibly changes, and the beacon and bell have no place in any larger shape. Kingdoms Two Crowns grows the kingdom in visible tiers, paid at one spot, and each tier makes the next threat survivable.

## Decisions

1. **Linear tiers.** The base has three tiers, bought one after another with ore, each raising several things together and changing how the base looks.
2. **A tier is strength plus the beacon and bell.** Each tier raises max health, the base light's fuel capacity and how long reinforced walls hold a Burrower. The beacon and bell stop being separate purchases: the beacon arrives with the second tier and the bell with the third.
3. **One key at the base.** A tier is bought with one press of U at the base, paid at once, with the same build noise as the beacon and bell today. U replaces the 2 and 3 keys.

## The tiers

All tiers reset every run (nothing persists; that is #38). Replanting the base (P) keeps the tier. The run starts as a Camp.

| Tier | Cost | Max health | Base light fuel | A reinforced wall holds a Burrower | Also |
| --- | --- | --- | --- | --- | --- |
| 1 Camp | start | 3 | 200 | 2.5 s | the flag |
| 2 Outpost | 70 ore | 4 | 260 | 3.5 s | the beacon is built in |
| 3 Fort | 120 ore | 5 | 340 | 5 s | the bell is built in |

- **Cost.** The Outpost's 70 is 40 for the tier plus the beacon's 30; the Fort's 120 is 100 plus the bell's 20. Paid from the ore the player carries, all at once. Constants: `TIER_COSTS := [0, 70, 120]`.
- **Buying heals and fills.** A purchase restores the base to its new max health and tops the base light up to its new capacity. (The light's radius range, 60 to 180 px, is unchanged except by the beacon as today.)
- **The beacon** keeps its trade-off: the base light's radius range is 50% wider and it burns 50% faster; it now arrives with tier 2 and is not bought separately. **The bell** keeps its job (warns of waves, adds the wave's size to the wave line) and arrives with tier 3.
- **Noise.** `BUILD_NOISE` (10) at the base, as the beacon and bell make now.
- **Constants.** `TIER_NAMES := ["Camp", "Outpost", "Fort"]`, `TIER_MAX_HEALTH := [3, 4, 5]`, `TIER_LIGHT_FUEL := [200.0, 260.0, 340.0]`, `TIER_WALL_CHEW_SECONDS := [2.5, 3.5, 5.0]`.

## What you see

- Each tier is drawn in code like the other props: the Outpost adds a palisade of posts around the flag, and the Fort replaces it with a stone rampart. The beacon brazier and the bell already have art and appear with their tiers.
- The HUD's Base line shows the tier ("Base: Outpost 3/4 walls 12").
- The prompt at the base says "U: grow the base to an Outpost, 70 ore" (or "Outpost needs 70 ore" when short, or nothing at the Fort).

## Components

- **`RunBase`** (modify, `scripts/run_base.gd`): `var tier: int` (0 to 2), the constants above, `func grow() -> bool` (returns false at the top tier or when the base has fallen; otherwise raises the tier, applies max health, heals, raises the light's `max_fuel`, refills it, builds the beacon at tier 2 and the bell at tier 3 through the existing `build_beacon` and `build_bell`), `func next_tier_cost() -> int` (-1 at the top), `func tier_name() -> String`, `func wall_chew_time() -> float`. `MAX_HEALTH` becomes `max_health()`; existing readers move to it.
- **`Burrower`** (modify): the reinforced-wall chew time comes from `target.wall_chew_time()` instead of its own `WALL_CHEW_TIME`.
- **`Main`** (modify): `_check_builds` replaces the 2 and 3 keys with one U key that checks distance to the base and the ore, pays `next_tier_cost()`, calls `run_base.grow()`, adds the build noise, and shows the tier's props; prompts and the wave line read the tier. The crew's job parts (stations, jobs) and the wave logic are unchanged.
- **`HUD`** (modify): the Base line shows the tier name and the tier's max health.
- **`GearArt` / `ArtSprite`** (modify): two new gears, `"palisade"` and `"rampart"`, drawn to sit around the flag (no new scenes).
- **Hub texts and README** that name the 2 and 3 keys or the beacon and bell as separate buys are updated.
- Saves and the run log: no format change.

## Edge cases

- Short of ore: nothing is taken, nothing changes, the prompt says what is needed.
- At the Fort: the key does nothing and the prompt is hidden.
- Away from the base (outside `BASE_RANGE`): the key does nothing.
- The base has fallen: the run is over; growing is refused.
- Growing while damaged heals to the new max health; growing at full health also raises it.
- Growing during a wave: allowed, and useful (heal and a fuller light); the noise is the cost.
- The base light's fuel when growing is set to the new capacity even if the player was refuelling from it that frame.
- Replanting (P): keeps the tier, its props and its light capacity; the props move with the base.
- A fortified wall built at one tier holds the Burrower for the tier's time at the moment it is chewed (the chew time is read when a Burrower reaches the wall, not when the wall was built).
- The beacon's 50% burn increase and a Fort's larger tank interact; the balance probe checks the base light still lasts to the first wave when fuelled by the Lamplighter.

## Out of scope

- A menu of independent buildings, or levels on each system (rejected for now).
- Crew gating by tier (how many can work at stations stays as it is).
- Anything that persists between runs (#38), including carrying a tier over.
- Building the tier over time, or by crew.

## Testing

- `RunBase`: each tier's max health, light capacity, wall chew time and cost; `grow()` heals, refills, applies the beacon at tier 2 and the bell at tier 3, refuses at the top and when fallen; `next_tier_cost()` and `tier_name()`.
- `Burrower`: chews a reinforced wall in the base's tier time.
- `Main`: U buys with enough ore and is refused short, far from the base and at the Fort; the noise is made; the ore is taken exactly; replanting keeps the tier; the old 2 and 3 keys do nothing.
- HUD: the Base line shows the tier and the max health; the prompt wording at each tier.
- Playtest: a scenario buys all three tiers in order with the ore it needs and checks the numbers, the props and the HUD.
- `tests/balance_probe.gd`: before and after, to see the effect on the idle bot and that a Lamplighter-fed base light lasts to the first wave.

## Open questions for the plan to settle, not the design

- Where the palisade and rampart props sit relative to the crew's stations and the flag so they do not hide the miners.
- The exact wording of the prompt when the player is at the base but short of ore.

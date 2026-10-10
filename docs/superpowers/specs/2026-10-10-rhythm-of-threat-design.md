# Rhythm of threat: waves with a calm, a build and a peak

2026-10-10. Design for planning issue #36 (piece 2 of 4: workers and jobs #35 is done, then this, then run base as a settlement #37 and hub as a kingdom #38). Agreed in conversation. Numbers are starting values for the balance probe to check, not commitments.

## Why

The mine already has a clock (milestone 50): from 240 s into a run it sends one Burrower at the base every 90 s, shrinking to every 45 s, and every 45 s again while the player carries the Heart. The waves are identical and steady, so there is no build-up, no calm and no peak: nothing to read, plan a dive around, or prepare for. The only preparation window is the 10 s warning, and only with the bell. Nothing the player or the crew does beforehand changes how a wave goes, because the only thing that hurts a Burrower is the player's own flare.

Kingdoms Two Crowns is the inspiration: a threat on a rhythm the player can learn, which the kingdom has to be ready for.

## Decisions

1. **The player prepares and also helps.** The base and crew defend on their own at a base level; the player being there adds a bonus. A dive stays the point of the run, and a wave that arrives while the player is deep is survivable if the base was ready.
2. **One threat type: Burrowers, with calm and a peak.** Waves come in repeating cycles of five, growing each cycle, with a calm after each peak. No new enemy.
3. **Countdown always, size with the bell.** The rhythm is readable from the start; the bell (20 ore) adds the wave's size and keeps its alarm.
4. **The base light is the automatic defence.** Burrowers inside the base light are slowed and take damage by how full the light is. This makes light the weapon (a PRD pillar) and gives the Lamplighter's fuel, the beacon and the walls a defensive job.

## The cycle

The mine clock keeps its start (`MINE_WAKE_SECONDS` 240) and its interval (`wave_interval`, 90 s shrinking to 45 s over the decay ramp, halved while carrying the Heart). What changes is what a wave brings and what follows it.

- A cycle is five waves. In the first cycle they bring 1, 1, 2, 2 and 4 Burrowers; the fifth is the **peak**. Each later cycle adds 1 to every count (second cycle 2, 2, 3, 3, 5).
- After a peak comes a **calm** of `CALM_MULTIPLIER` (2.0) times the current interval before the next wave, then the next cycle starts.
- `wave_size(wave_number)` and `is_peak(wave_number)` are pure functions of the wave's number (starting at 1).
- At most `MAX_LIVE_BURROWERS` (8) are alive at once; a wave that would exceed it spawns only as many as fit.
- Groups spawn spread across x (offsets of 0, -3, +3, -6, +6, -9, +9, -12 tiles from the base's column, in that order) so they do not stack, at the same depth rule as today (`BURROWER_SPAWN_OFFSET_TILES` below the base, clamped inside the walls and below the quiet floor). Positions are deterministic.
- Noise-summoned Burrowers (the noise meter threshold) are unchanged and are not counted as waves.

## The warning

- The HUD always shows the time to the next wave ("Wave in 42 s"), once the mine has woken; before that it shows the time until the mine wakes. A peak is marked ("Wave in 42 s: PEAK").
- With the bell built the line also shows the size ("Wave in 42 s: 3 Burrowers" or "... 4 Burrowers, PEAK"). The 10 s alarm stays as it is.
- The line is part of the existing HUD, not a new panel. During the calm it reads "Calm: next wave in N s".

## Defence

- **Slow:** a Burrower inside the base light's current radius moves at `LIT_SPEED_MULTIPLIER` (0.4), as it already does in the player's light.
- **Damage:** a Burrower inside the base light's current radius loses `BASE_LIGHT_DAMAGE_RATE` (0.15) times the base light's fuel fraction in health per second. Its health is 1.5, so a full light kills one in 10 s and a 40% light in about 25 s. The base light's radius also shrinks with its fuel (60 px empty to 180 px full), so a thin light is both smaller and weaker.
- **Walls** hold a Burrower inside the light longer (2.5 s per reinforced tile); **the Lamplighter** keeps the light full; **the beacon** widens it (and burns it faster); **the Mender** repairs what gets through.
- **Presence:** while the player stands inside the base light and is flaring, the base light's damage is multiplied by `PRESENCE_FLARE_MULTIPLIER` (3.0). The player's own flare still hurts Burrowers in the player's light as it does today.
- These apply to every Burrower, wave or noise-summoned. Nothing here damages the player, miners or any other creature.

## Components

- **`MineClock`** (modify, `scripts/mine_clock.gd`): keeps `tick(delta, run_seconds, carrying_heart)` returning "" / "warn" / "wave"; gains `wave_number` (starting at 0, incremented on each "wave"), `static wave_size(n)`, `static is_peak(n)`, and `seconds_to_next() -> float` (-1 before the mine wakes). After a peak wave it sets the next countdown to `CALM_MULTIPLIER` times the interval.
- **`Main`** (modify): `_spawn_wave` spawns `min(MineClock.wave_size(n), MAX_LIVE_BURROWERS - alive)` Burrowers at the spread positions; the HUD line is fed each frame from the clock and the bell state.
- **`Burrower`** (modify): inside the base light (distance to `target.global_position` below `target.light.current_radius()`) it is slowed and takes the damage above, with the presence multiplier when the player is within the base light radius and `player.light.is_flaring`.
- **`HUD`** (modify): one `update_wave(text)` line.
- Saves and the run log: no format change; `waves_spawned` keeps counting waves.

## Edge cases

- Heart carried: the interval halves as today; the calm halves with it; the cycle position is unchanged.
- Run clock before 240 s: no waves; the HUD counts down to the wake.
- Base falls: the clock stops (the run ends).
- Wave size clipped by the live cap: the shortfall is not made up later.
- A Burrower that starts inside the base light (a late spawn) is slowed and damaged at once.
- The base light is empty (fuel 0): no damage and no slow beyond the 60 px radius; the wave behaves as it does today.
- A noise-summoned Burrower arriving during a wave counts toward the live cap.

## Out of scope

- New enemy types, mixed waves, waves that follow depth (different ideas, rejected for now).
- A new crew type (a guard) or direct combat; the PRD keeps combat to light.
- Rewards for clearing a wave, and anything persistent between runs (#38).
- Base growth tiers (#37).

## Testing

- `MineClock`: `wave_size` and `is_peak` across two cycles (1, 1, 2, 2, 4 then 2, 2, 3, 3, 5; every fifth is a peak); the calm after a peak (the next wave comes 2x the interval later); `seconds_to_next` before and after the wake; the Heart's halving.
- `Main`: a wave of size 3 spawns 3 Burrowers, spread; the live cap clips a wave; a noise-summoned Burrower counts toward the cap.
- `Burrower`: slowed inside the base light and not outside; damage per second at full, 40% and empty fuel; the presence multiplier only while flaring inside the light; none for a flare outside it; dies at 1.5 health.
- HUD: the countdown always, the size only with the bell, the peak mark, and the calm wording.
- Playtest: a staged base with a full light clears a first-cycle wave without losing health, and the same base with a nearly empty light loses health.
- `tests/balance_probe.gd`: an idle probe with the new waves, before and after, to see how long a bare base survives.

## Open questions for the plan to settle, not the design

- Where the HUD wave line sits among the existing lines.
- Whether the spawned group should appear with a short tremor or sound cue (no new art or sound is planned).

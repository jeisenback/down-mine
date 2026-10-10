# Workers and jobs: crew that do things on their own

2026-10-10. Design for planning issue #35 (piece 1 of 4: workers and jobs, then rhythm of threat #36, run base as a settlement #37, hub as a kingdom #38). Agreed in conversation. Numbers are starting values for the balance probe to check, not commitments.

## Why

The game has a run base and a roster of rescued miners, but neither does anything. A miner's type is a bonus applied once at the start of a run (Light, Noise, Repair, Traversal); they stand at the base and nothing they do is visible or costs anything. Kingdoms Two Crowns is the inspiration: workers act on their own while the player explores, and what they do is paid for.

The goal is that crew are a decision (who to bring, what they cost to run) and a thing to watch (what they are doing at the base), without adding a third clock or pathfinding.

## Decisions

1. **Types become jobs.** The four types stay (Mender, Lamplighter, Whisper, Climber, all existing names). Each crew miner now does a visible job at the base instead of adding a hidden bonus. The four passive type bonuses are removed so nothing is counted twice. Ranks (Rookie 1.0, Seasoned 1.5, Veteran 2.0) scale a job's rate; quirks are unchanged.
2. **Jobs cost ore and noise.** Fuel and gear come from converting this run's carried ore. There is no free light and no free gear. Working also makes noise at the base, so a bigger crew is a louder base.
3. **Stations, not walking.** Each job has a fixed station beside the flag. The miner stands there and plays a work pose. Effects tick on a timer. There is no pathfinding and no target selection.
4. **Folded in, not new types.** Fuel generation and equipment making are the Lamplighter's and Climber's jobs, not two new types. If crafting grows into its own system it can split out later.

## The jobs

All rates are Rookie rates; the interval divides by rank strength (so a Veteran works twice as fast). A job pauses when its input is missing and resumes when it returns.

| Type | Station | Job | Spends |
| --- | --- | --- | --- |
| Mender | Bench | Repairs the base 1 health per 12 s while it is damaged | 5 ore per health, plus noise |
| Lamplighter | Lantern post | 4 ore becomes 20 fuel in the base light every 15 s, only while the base light is under 90% full | 4 ore per batch, plus noise |
| Whisper | Muffling post | Noise the base hears is 25% lower while they work (rank-scaled) | Nothing; silent |
| Climber | Rope rack | Makes one item every 60 s, rotating ladder, anchor, lamp; honours the hub's unlocks; stops at 2 above the run's starting count of that item | 6 ore (ladder), 10 (anchor), 8 (lamp), plus noise |

**Noise.** Every working miner except the Whisper adds 1 noise at the base every 10 s (`JOB_NOISE`, `JOB_NOISE_INTERVAL`). It goes through `noise_meter.add_noise(amount, base_position)`, so distance, quiet layers and the one-meter rule already apply.

**When they work.** All run long, whether or not the player is at the base. They stop when the base has fallen, or if they are not at the base (stranded, lost, or not on the crew).

**Ore.** Jobs spend the ore the player carries this run (`Player.currency`) automatically. This is blunt: a Lamplighter can use ore the player wanted for the beacon. A "hold crew work" key is a deliberate follow-up, not part of this design.

## Components

- **`CrewJobs`** (new, `scripts/crew_jobs.gd`). A plain object with no scene tree. `tick(delta, crew, targets)` applies each job and returns what happened. All constants above live here. This is what the tests drive.
- **Stations** (new art and a small scene). Four station props drawn in code like the other objects (`GearArt` kinds `bench`, `lantern_post`, `muffling_post`, `rope_rack`), placed beside the flag. `Main._place_crew_at_base` stands each crew miner at the station for their type. Miners use the drawn miner's work pose (the dig state); no new miner art.
- **`Progress`.** `apply_to` loses the four type bonuses (light burn and radius, noise, traversal, repair cost and speed). Quirks, ranks, experience and stranding are untouched. `effect_text` describes the job ("repairs the base 1 health per 12 s") instead of percentages.
- **Data flow.** Each frame `Main` calls `CrewJobs.tick` for the crew at the base. Effects write to the existing objects: `RunBase.health` for the Mender, the base `MineLight.fuel` for the Lamplighter, the noise meter for noise and for the Whisper's reduction, `Player.ladders_left`, `anchors_left` and lamps for the Climber, `Player.currency` for every ore spend.
- **Saves.** No format change. A crew member is still a type, a name and experience.

## Edge cases

- No ore: jobs that need ore wait; Whisper keeps working.
- Base light already near full: the Lamplighter waits, so ore is not wasted past 90%.
- Hub has not unlocked a tool: the Climber skips it and rotates to the next unlocked item; with none unlocked it idles and spends nothing.
- Item cap reached: the Climber skips that item.
- Base at full health: the Mender idles and spends nothing.
- Base falls mid-run: all jobs stop.
- Two crew of the same type: both work; a duplicate Whisper stacks multiplicatively, and the total noise reduction is capped at 60%.
- Crew changes between runs only (as today); the roster at run start is the crew for the run.

## Out of scope

- Walking workers, pathing, targets (a later replacement for the work pose if wanted).
- New types (Refiner, Smith).
- A hold-work key or per-job toggles.
- Anything persistent between runs beyond what exists (that is #38).
- What threatens the base (that is #36).

## Testing

- `CrewJobs`: each job's rate at Rookie, Seasoned and Veteran; ore spent per effect; noise per working miner; none for the Whisper.
- Edge cases above, each as its own test (no ore, full light, nothing unlocked, cap reached, full health, base fallen, duplicate Whisper cap).
- `Progress.apply_to`: the removed bonuses are gone; quirks still apply.
- `Main`: crew stand at the right stations; the jobs tick through the real scene.
- Playtest: a scenario with a full crew over a minute of run time checks base health, base fuel, tool counts and the noise meter move as designed.
- `tests/balance_probe.gd`: before and after numbers so the effect on run length is visible.

## Open questions for the plan to settle, not the design

- Where exactly the stations sit relative to the flag when four crew plus the bell and beacon are all present.
- Whether job noise should show on the HUD noise line or stay silent in the readout.

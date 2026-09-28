# Down Mine

Side-view extraction roguelike prototype. See `MineRoguelike_PRD.md` for the full design.

## Milestone 1 — vertical slice

Proves the core tension: light decays, digging is loud, and enemies punish
darkness. No crew, hub, or stranding yet.

**Controls**
- `A`/`D` or arrow keys — move
- `W`/Up — jump
- `S`/Down — dig downward (hold with a movement key to dig a descending staircase)
- `Space` — dig forward (in facing direction); hold with `W`/Up to dig straight up instead
- `Shift` — flare the light (brighter, burns fuel faster)
- `Q` — fire the grapple straight up (reusable, pulls you to the first solid ceiling within range)
- `R` — place a rope at your feet (consumable, climbable with `W`/`S`, decays over time — faster in the dark)
- `E` — extract at the run base (banks ore, ends the run)
- `Enter` — start a new run from the run summary (banked ore is saved between runs)

**Run it**: open the project folder in Godot 4.3+ and press Play (main scene
is `scenes/Main.tscn`).

## Project layout

- `scenes/` — Main, Player, Mine, Stalker, HUD
- `scripts/` — one script per scene/system (`mine.gd` generates its own
  placeholder tileset in code, no art assets needed yet)

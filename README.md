# Down Mine

Side-view extraction roguelike prototype. See `MineRoguelike_PRD.md` for the full design.

## Milestone 1 — vertical slice

Proves the core tension: light decays, digging is loud, and enemies punish
darkness. No crew, hub, or stranding yet.

**Controls**
- `A`/`D` or arrow keys — move
- `W`/Up — jump
- `S`/Down — dig downward (hold with a movement key to dig a descending staircase)
- `Space` — dig forward (in facing direction)
- `Shift` — flare the light (brighter, burns fuel faster)

**Run it**: open the project folder in Godot 4.3+ and press Play (main scene
is `scenes/Main.tscn`).

## Project layout

- `scenes/` — Main, Player, Mine, Stalker, HUD
- `scripts/` — one script per scene/system (`mine.gd` generates its own
  placeholder tileset in code, no art assets needed yet)

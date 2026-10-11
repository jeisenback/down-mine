extends Node2D
class_name HubBuilding

## One building in the hub (milestone 57): what it sells, whether the player
## is beside it, the prompt it shows and the actions that spend ore. The
## purchase rules stay in Progress; this only picks the upgrade and reports.
## Every action is a method, so any input (keys now, touch later) can call it.

## The upgrades each building sells, in key order (1, 2, 3 at the building).
const OFFERS := {
	"lamp_shop": ["lantern", "lamps"],
	"smithy": ["hard_hat", "ladders", "anchors"],
	"bunkhouse": ["crew_bunk"],
	"notice_board": [],
}
## How close counts as beside it, on x only (the hub is a flat strip).
const RANGE := 28.0

var kind: String = ""
var progress: Progress
var board_open: bool = false

func offers() -> Array:
	return OFFERS.get(kind, [])

func in_range(pos: Vector2) -> bool:
	return absf(pos.x - global_position.x) < RANGE

## Buys the offer in this slot (1-based). False for a bad slot, short ore or a maxed upgrade.
func buy(slot: int) -> bool:
	var list := offers()
	if slot < 1 or slot > list.size():
		return false
	return progress.try_buy(list[slot - 1])

func prompt() -> String:
	if kind == "notice_board":
		return "E: notice board"
	var parts: Array = []
	var list := offers()
	for i in range(list.size()):
		var upgrade: Dictionary = Progress.UPGRADES[list[i]]
		var cost := progress.next_cost(list[i])
		if cost < 0:
			parts.append("%d: %s %s" % [i + 1, upgrade.name, "OWNED" if upgrade.max_level == 1 else "MAX"])
			continue
		var text := "%d: %s Lv %d/%d, %d ore" % [i + 1, upgrade.name, progress.level(list[i]), upgrade.max_level, cost]
		if progress.banked_ore < cost:
			text += " (need %d more)" % (cost - progress.banked_ore)
		parts.append(text)
	return "     ".join(parts)

## The notice board opens and closes.
func toggle() -> void:
	board_open = not board_open

func board_text() -> String:
	var lines := ["RECENT RUNS (newest first)", ""]
	if progress.run_log.is_empty():
		lines.append("No runs logged yet")
	for entry in progress.run_log:
		lines.append(Progress.run_log_line(entry))
	if progress.journal_read > 0:
		lines.append("")
		lines.append("Latest journal page: " + Progress.JOURNAL[progress.journal_read - 1])
	if not progress.stranded.is_empty():
		lines.append("")
	for npc in progress.stranded:
		lines.append(progress.stranded_line(npc))
	return "\n".join(lines)

## 1.0 once the first thing this building sells has been bought, for the art's lit state.
func owned_cue() -> float:
	var list := offers()
	if kind in ["lamp_shop", "smithy"] and not list.is_empty() and progress.level(list[0]) >= 1:
		return 1.0
	return 0.0

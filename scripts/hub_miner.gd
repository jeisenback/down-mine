extends Node2D
class_name HubMiner

## A rostered miner standing in the hub (milestone 57): says who they are
## and puts them on the crew or takes them off.

## How close counts as beside them; figures stand 14 px apart, so the nearest is unambiguous.
const RANGE := 8.0

var member: Dictionary = {}
var progress: Progress

func on_crew() -> bool:
	return member.name in progress.crew_names

func in_range(pos: Vector2) -> bool:
	return absf(pos.x - global_position.x) < RANGE

## Joins or leaves the crew. Leaving always works; joining needs a free slot.
func toggle_crew() -> bool:
	if not on_crew() and progress.crew().size() >= progress.crew_slots():
		return false
	progress.toggle_crew(member.name)
	return true

func prompt() -> String:
	var action := " - leave crew"
	if not on_crew():
		action = " - join crew" if progress.crew().size() < progress.crew_slots() else " - Crew full"
	return "E: %s - %s%s" % [progress.display_name(member), progress.member_summary(member), action]

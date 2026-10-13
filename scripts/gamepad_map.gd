extends RefCounted
class_name GamepadMap

## The gamepad's layout rules, pure and static (controller support). GamepadControls applies
## them; the button-to-key tables live there next to the code that presses the keys.

## A trigger counts as pressed above this.
const TRIGGER_THRESHOLD := 0.5

## The direction keys a left-stick offset (each axis -1..1) presses: the touch pad's rule, with
## its dead zone and the stair zone for a deliberate diagonal.
static func stick_keys(offset: Vector2) -> Array:
	return TouchPad.keys_for(offset, 1.0)

## The tools Y can use, in cycling order: the tools available, then Plant when the base can be
## planted here, then the base's own actions while standing at it. Names are TouchControls widgets.
static func cycle_list(tools_available: Array, can_plant: bool, base_nearby: bool) -> Array:
	var list: Array = tools_available.duplicate()
	if can_plant:
		list.append("base_plant")
	if base_nearby:
		list.append_array(["base_repair", "base_fortify", "base_grow"])
	return list

## The next (step 1) or previous (step -1) entry, wrapping. A `current` that is not in the list
## gives the first; an empty list gives "".
static func cycle(list: Array, current: String, step: int) -> String:
	if list.is_empty():
		return ""
	var at := list.find(current)
	if at < 0:
		return list[0]
	return list[posmod(at + step, list.size())]

## "tool_rope" -> "Rope", "base_plant" -> "Plant".
static func tool_label(widget: String) -> String:
	var split := widget.find("_")
	return widget.substr(split + 1).capitalize() if split >= 0 else ""

## The keys a tool presses, from its on-screen widget.
static func tool_keys(widget: String) -> Array:
	return TouchControls.WIDGETS[widget].keys if TouchControls.WIDGETS.has(widget) else []

## Whether a tool's keys stay down while Y is held (Repair) rather than being tapped.
static func tool_holds(widget: String) -> bool:
	return TouchControls.WIDGETS[widget].hold if TouchControls.WIDGETS.has(widget) else false

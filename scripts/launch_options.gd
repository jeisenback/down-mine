extends RefCounted
class_name LaunchOptions

## Options given at launch (milestone 43), for testing and UAT: web URL
## parameters (?seed=1234&debug) or, running Godot directly, user args
## after "--" (godot -- --seed=1234 --debug).

## Whether the option was given, with or without a value.
static func has(option: String) -> bool:
	if OS.has_feature("web"):
		return bool(JavaScriptBridge.eval("new URLSearchParams(window.location.search).has('%s')" % option))
	for arg in OS.get_cmdline_user_args():
		if arg == "--" + option or arg.begins_with("--%s=" % option):
			return true
	return false

## The option's value, or "" if it wasn't given one.
static func value(option: String) -> String:
	if OS.has_feature("web"):
		var found = JavaScriptBridge.eval("new URLSearchParams(window.location.search).get('%s')" % option)
		return "" if found == null else str(found)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--%s=" % option):
			return arg.get_slice("=", 1)
	return ""

static func debug_enabled() -> bool:
	return has("debug")

extends RunContext

## A stand-in for the run in art wiring tests: the few members events touch.
var rode_from: float = -1.0

func ride_to_surface(x: float) -> void:
	rode_from = x

func nest_destroyed() -> void:
	pass

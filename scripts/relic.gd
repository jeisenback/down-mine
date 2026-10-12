extends Node2D
class_name Relic

## The relic in the vault (milestone 35): worth a lot of ore, banked only
## if you get it home.
const VALUE := 150

func _ready() -> void:
	add_to_group(Groups.MINE_EVENTS)

func prompt(_run: RunContext) -> String:
	return "E: take the relic, %d ore" % VALUE

func use(run: RunContext) -> void:
	run.player.currency += VALUE
	run.hud.show_message("The relic is heavy with old gold. Get it home.")
	Sfx.play("ore")
	queue_free()

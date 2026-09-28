extends Node2D
class_name Relic

## The relic in the vault (milestone 35): worth a lot of ore, banked only
## if you get it home.
const VALUE := 150

func _ready() -> void:
	add_to_group("mine_events")

func prompt(_main: Node) -> String:
	return "E: take the relic, %d ore" % VALUE

func use(main: Node) -> void:
	main.player.currency += VALUE
	main.hud.show_message("The relic is heavy with old gold. Get it home.")
	Sfx.play("ore")
	queue_free()

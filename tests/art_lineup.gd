extends SceneTree

## The creature review harness (M92): renders each creature in each state on a plain background and
## saves the pictures, so a redraw is judged by looking at it. Not part of the suite. Needs a display:
##   xvfb-run -a godot --fixed-fps 60 -s tests/art_lineup.gd [-- kind=stalker]
## Writes playtest_out/art/<kind>_1x.png and <kind>_5x.png: the states left to right, in the order of
## STATES (the Stalker adds its deep variant, the nest a half-burnt one). With no kind, all of them.

const OUT_DIR := "res://playtest_out/art"
const KINDS := ["stalker", "burrower", "snuffer", "nest"]
const SPACING := 40.0
const BACKGROUND := Color(0.16, 0.14, 0.12)
## [label, pose, variant]
const STATES := [["idle", 0.0, 0], ["strike", 1.0, 0]]
const EXTRA_STATES := {
	"stalker": [["deep", 0.0, 1], ["deep_strike", 1.0, 1]],
	"nest": [["burning", 0.5, 0]],
}
## Where the Snuffer's tether points in its striking (draining) state.
const AIMS := {"snuffer": Vector2(16, 3)}
const ZOOMS := [1, 5]

func _initialize() -> void:
	_run.call_deferred()

func _states_for(kind: String) -> Array:
	return STATES + EXTRA_STATES.get(kind, [])

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var kinds: Array = KINDS
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("kind="):
			kinds = [arg.substr(5)]
	for kind in kinds:
		await _render(kind)
	quit()

func _render(kind: String) -> void:
	var holder := Node2D.new()
	root.add_child(holder)
	var background := ColorRect.new()
	background.color = BACKGROUND
	background.size = Vector2(6000, 3000)
	background.position = Vector2(-3000, -1500)
	holder.add_child(background)
	var states := _states_for(kind)
	var width := SPACING * (states.size() - 1)
	for i in range(states.size()):
		var sprite := ArtSprite.new()
		sprite.kind = kind
		sprite.glow = kind == "stalker" # the only creature with unlit glow pieces (so far)
		sprite.position = Vector2(-width / 2.0 + i * SPACING, 0)
		holder.add_child(sprite)
	for i in range(states.size()):
		var sprite: ArtSprite = holder.get_child(i + 1)
		await process_frame
		sprite.art.pose = states[i][1]
		sprite.art.variant = states[i][2]
		if states[i][1] >= 0.5:
			sprite.art.aim = AIMS.get(kind, Vector2.ZERO)
	var camera := Camera2D.new()
	holder.add_child(camera)
	for zoom in ZOOMS:
		camera.zoom = Vector2(zoom, zoom)
		for i in range(40):
			await process_frame
		var path := "%s/%s_%dx.png" % [OUT_DIR, kind, zoom]
		root.get_texture().get_image().save_png(ProjectSettings.globalize_path(path))
		print("wrote ", path)
	holder.queue_free()
	await process_frame

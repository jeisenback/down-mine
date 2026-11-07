extends CanvasLayer
class_name Vignette

## A soft darkening toward the screen's corners (M89), under the HUD so its text stays clear. It
## draws no gameplay: only the look of the dark closing in around the lantern.

const STRENGTH := 0.5

const SHADER_CODE := """
shader_type canvas_item;
uniform float strength = 0.5;
void fragment() {
	vec2 offset = (UV - vec2(0.5)) * vec2(1.0, 0.85);
	float edge = smoothstep(0.3, 0.75, length(offset));
	COLOR = vec4(0.0, 0.0, 0.02, edge * strength);
}
"""

func _init() -> void:
	var shader := Shader.new()
	shader.code = SHADER_CODE
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("strength", STRENGTH)
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.material = material
	add_child(rect)

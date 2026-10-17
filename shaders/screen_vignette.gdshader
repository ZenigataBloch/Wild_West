shader_type canvas_item;
// Vignettatura leggera a tutto schermo: scurisce i bordi e porta l'occhio al centro.

uniform float strength : hint_range(0.0, 1.0) = 0.4;

void fragment() {
	float v = distance(UV, vec2(0.5)) * 1.5;
	float a = smoothstep(0.45, 1.05, v) * strength;
	COLOR = vec4(0.04, 0.02, 0.0, a);
}

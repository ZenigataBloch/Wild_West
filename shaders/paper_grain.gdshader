shader_type canvas_item;
// Grana e vignettatura leggere per dare texture ai pannelli western.

uniform float grain : hint_range(0.0, 0.3) = 0.07;
uniform float vignette : hint_range(0.0, 1.0) = 0.30;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec4 base = texture(TEXTURE, UV) * COLOR;
	float n = hash(floor(FRAGCOORD.xy * 0.75));
	float fibre = hash(vec2(floor(FRAGCOORD.x * 0.15), floor(FRAGCOORD.y * 2.0)));
	float tex = (n - 0.5) * grain + (fibre - 0.5) * grain * 0.6;
	float v = distance(UV, vec2(0.5)) * 1.4;
	float vig = 1.0 - smoothstep(0.35, 1.0, v) * vignette;
	COLOR = vec4((base.rgb + tex) * vig, base.a);
}

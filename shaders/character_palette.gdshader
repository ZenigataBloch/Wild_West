shader_type canvas_item;
// Ricolora lo sprite per regioni (pelle, capelli, camicia, pantaloni, stivali, cappello).
// La texture contiene solo l'ombreggiatura in grigio; la mappa delle regioni
// (stessa dimensione, canale rosso = id * 32) dice quale colore applicare.

uniform sampler2D region_map : filter_nearest, repeat_disable;
uniform vec4 c_skin : source_color = vec4(0.93, 0.76, 0.6, 1.0);
uniform vec4 c_hair : source_color = vec4(0.29, 0.18, 0.1, 1.0);
uniform vec4 c_shirt : source_color = vec4(0.29, 0.44, 0.65, 1.0);
uniform vec4 c_pants : source_color = vec4(0.23, 0.23, 0.32, 1.0);
uniform vec4 c_boots : source_color = vec4(0.23, 0.14, 0.09, 1.0);
uniform vec4 c_hat : source_color = vec4(0.36, 0.23, 0.12, 1.0);

void fragment() {
	vec4 base = texture(TEXTURE, UV);
	float id = floor(texture(region_map, UV).r * 255.0 / 32.0 + 0.5);
	float s = base.r * 2.0;
	vec3 col = base.rgb;
	if (id == 1.0) { col = c_skin.rgb * s; }
	else if (id == 2.0) { col = c_hair.rgb * s; }
	else if (id == 3.0) { col = c_shirt.rgb * s; }
	else if (id == 4.0) { col = c_pants.rgb * s; }
	else if (id == 5.0) { col = c_boots.rgb * s; }
	else if (id == 6.0) { col = c_hat.rgb * s; }
	COLOR = vec4(clamp(col, 0.0, 1.0), base.a);
}

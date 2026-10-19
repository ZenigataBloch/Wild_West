shader_type canvas_item;
// Terreno procedurale (Mappa 1): i dati a bassa risoluzione (altezza, umidità, sentieri, acqua, letti
// asciutti, terra battuta) vengono generati da MapData; qui si aggiungono i dettagli per pixel.
// data_a: R altezza, G umidità, B distanza dal bordo del sentiero, A distanza dal bordo dell'acqua.
// data_b: R distanza dal bordo del letto asciutto, G salina, B terra battuta della città.
// Le distanze sono codificate come (d + 80) / 280.

uniform sampler2D data_a : filter_linear, repeat_disable;
uniform sampler2D data_b : filter_linear, repeat_disable;
uniform vec4 world_rect = vec4(0.0, 0.0, 1.0, 1.0);
uniform float seed_off = 0.0;
uniform float px = 3.0;

varying vec2 wpos;

void vertex() {
	wpos = VERTEX;
}

float h21(vec2 p) {
	vec3 p3 = fract(vec3(p.x, p.y, p.x) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float vn(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	float a = h21(i);
	float b = h21(i + vec2(1.0, 0.0));
	float c = h21(i + vec2(0.0, 1.0));
	float d = h21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float fb(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * vn(p);
		p = p * 2.03 + vec2(17.1, 9.3);
		a *= 0.5;
	}
	return v / 0.9375;
}

void fragment() {
	vec2 q = floor(wpos / px) * px;
	vec2 uv = (q - world_rect.xy) / world_rect.zw;
	vec4 da = texture(data_a, uv);
	vec4 db = texture(data_b, uv);
	float h = da.r;
	float m = da.g;
	float trl = da.b * 280.0 - 80.0;
	float wat = da.a * 280.0 - 80.0;
	float wsh = db.r * 280.0 - 80.0;
	float hard = db.g;
	float yard = db.b;

	vec2 sp = q + vec2(seed_off);
	float big = fb(sp * 0.0035);
	float mid = fb(sp * 0.018);
	float fine = h21(sp);
	float jit = (mid - 0.5) * 16.0;

	// Terra di base e macchia secca / prato.
	vec3 sand_a = vec3(0.86, 0.72, 0.47);
	vec3 sand_b = vec3(0.76, 0.60, 0.38);
	vec3 col = mix(sand_b, sand_a, smoothstep(0.25, 0.75, big));
	vec3 scrub = vec3(0.62, 0.57, 0.33);
	vec3 grass = vec3(0.44, 0.54, 0.27);
	vec3 grass_d = vec3(0.32, 0.44, 0.22);
	float mm = m + (mid - 0.5) * 0.30;
	col = mix(col, scrub, smoothstep(0.40, 0.62, mm) * 0.75);
	col = mix(col, mix(grass_d, grass, mid), smoothstep(0.62, 0.78, mm));

	// Altopiani rocciosi a strati.
	float hh = h + (mid - 0.5) * 0.05;
	float hl = smoothstep(0.62, 0.66, hh);
	float sb = fract(h * 16.0);
	vec3 rock = mix(vec3(0.62, 0.35, 0.22), vec3(0.72, 0.46, 0.30), step(0.5, sb));
	rock = mix(rock, vec3(0.82, 0.62, 0.42), smoothstep(0.84, 0.95, h));
	rock *= 0.92 + 0.16 * mid;
	rock = mix(rock, rock * 0.62, smoothstep(0.90, 1.0, sb));
	col = mix(col, rock, hl);

	// Salina screpolata.
	vec3 pan = vec3(0.91, 0.85, 0.72);
	float crack = abs(vn(sp * 0.07) - 0.5);
	float cr = 1.0 - smoothstep(0.0, 0.025, crack);
	vec3 panc = mix(pan, pan * 0.82, cr * 0.8);
	col = mix(col, panc, smoothstep(0.05, 0.5, hard) * (1.0 - hl));

	// Terra battuta intorno alla città.
	vec3 dirt = vec3(0.67, 0.49, 0.30);
	col = mix(col, dirt * (0.92 + 0.12 * mid), yard * 0.9);

	// Letto asciutto del torrente.
	float wb = wsh + jit * 0.6;
	float bank = 1.0 - smoothstep(0.0, 16.0, wb);
	col = mix(col, col * 0.75, bank * 0.6);
	float inb = 1.0 - smoothstep(-1.0, 1.0, wb);
	vec3 bed = mix(vec3(0.80, 0.68, 0.48), vec3(0.70, 0.56, 0.38), mid);
	col = mix(col, bed, inb);
	if (inb > 0.5 && fine > 0.93) {
		col = vec3(0.55, 0.48, 0.40);
	}

	// Sentieri.
	float tb = trl + jit * 0.5;
	float it = 1.0 - smoothstep(-2.0, 2.0, tb);
	float te = (1.0 - smoothstep(0.0, 5.0, tb)) * (1.0 - it);
	col = mix(col, col * 0.85, te * 0.5);
	vec3 trc = mix(vec3(0.70, 0.52, 0.32), vec3(0.78, 0.62, 0.40), mid);
	col = mix(col, trc, it * 0.95);

	// Acqua: riva bagnata, fondale, correnti e schiuma.
	float wj = wat + jit * 0.7;
	float wet_bank = 1.0 - smoothstep(0.0, 18.0, wj);
	col = mix(col, col * vec3(0.72, 0.66, 0.60), wet_bank * 0.7);
	float inw = 1.0 - smoothstep(-1.0, 1.0, wj);
	float depth = 1.0 - smoothstep(-34.0, -2.0, wj);
	vec3 wc = mix(vec3(0.42, 0.66, 0.68), vec3(0.17, 0.38, 0.52), depth);
	float flow = vn(vec2(sp.x * 0.16, sp.y * 0.035 - TIME * 0.35));
	wc += vec3(0.10) * smoothstep(0.62, 0.80, flow);
	float foam = 1.0 - smoothstep(0.0, 4.0, abs(wj + 2.0));
	wc = mix(wc, vec3(0.92, 0.95, 0.92), foam * 0.6);
	col = mix(col, wc, inw);

	col *= 1.0 + (fine - 0.5) * 0.10;
	col *= 0.94 + 0.12 * big;
	COLOR = vec4(col, 1.0);
}

shader_type sky;

uniform float star_density : hint_range(10.0, 400.0) = 140.0;
uniform float star_size : hint_range(0.002, 0.06) = 0.010;
uniform float star_brightness : hint_range(0.1, 8.0) = 1.4;
uniform float twinkle_speed : hint_range(0.0, 4.0) = 1.4;
uniform float micro_star_amount : hint_range(0.0, 1.0) = 0.35;
uniform float drift_speed : hint_range(-0.05, 0.05) = 0.008;

uniform vec3 nebula_color_a : source_color = vec3(0.22, 0.07, 0.45);
uniform vec3 nebula_color_b : source_color = vec3(0.02, 0.04, 0.16);
uniform vec3 nebula_color_c : source_color = vec3(0.30, 0.03, 0.06);
uniform float nebula_amount : hint_range(0.0, 2.0) = 0.40;
uniform float nebula_scale : hint_range(0.5, 8.0) = 2.4;
uniform float nebula_speed : hint_range(0.0, 0.5) = 0.03;

float hash13(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.zyx + 31.32);
	return fract((p.x + p.y) * p.z);
}

vec3 hash33(vec3 p) {
	p = vec3(dot(p, vec3(127.1, 311.7, 74.7)),
			dot(p, vec3(269.5, 183.3, 246.1)),
			dot(p, vec3(113.5, 271.9, 124.6)));
	return fract(sin(p) * 43758.5453123);
}

float vnoise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	vec3 u = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(mix(hash13(i), hash13(i + vec3(1.0, 0.0, 0.0)), u.x),
			mix(hash13(i + vec3(0.0, 1.0, 0.0)), hash13(i + vec3(1.0, 1.0, 0.0)), u.x), u.y),
		mix(mix(hash13(i + vec3(0.0, 0.0, 1.0)), hash13(i + vec3(1.0, 0.0, 1.0)), u.x),
			mix(hash13(i + vec3(0.0, 1.0, 1.0)), hash13(i + vec3(1.0, 1.0, 1.0)), u.x), u.y),
		u.z);
}

float fbm(vec3 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 5; i++) {
		v += a * vnoise(p);
		p = p * 2.03 + vec3(17.1);
		a *= 0.5;
	}
	return v;
}

float star_layer(vec3 dir, float density, float size, float seed_off) {
	vec3 p = dir * density + vec3(seed_off);
	vec3 cell = floor(p);
	vec3 f = fract(p) - 0.5;
	vec3 rnd = hash33(cell);
	if (rnd.x < 0.78) {
		return 0.0;
	}
	vec3 off = (rnd - 0.5) * 0.7;
	float d = length(f - off);
	float star = 1.0 - smoothstep(0.0, size, d);
	star *= star;
	float tw = 0.7 + 0.3 * sin(TIME * twinkle_speed + rnd.y * 6.2831);
	return star * tw * (0.4 + 0.6 * rnd.z);
}

void sky() {
	vec3 dir = normalize(EYEDIR);
	float a = TIME * drift_speed;
	float ca = cos(a);
	float sa = sin(a);
	dir = vec3(ca * dir.x + sa * dir.z, dir.y, -sa * dir.x + ca * dir.z);

	vec3 flow = vec3(TIME * nebula_speed, TIME * nebula_speed * 0.6, -TIME * nebula_speed * 0.4);
	float n1 = fbm(dir * nebula_scale + vec3(3.7) + flow);
	float n2 = fbm(dir * nebula_scale * 2.7 + vec3(11.3) + flow * 1.3);
	float neb_p = smoothstep(0.45, 0.90, n1 * 0.65 + n2 * 0.35);
	float n3 = fbm(dir * nebula_scale * 1.6 + vec3(27.1) - flow);
	float n4 = fbm(dir * nebula_scale * 3.1 + vec3(5.9) - flow * 1.1);
	float neb_r = smoothstep(0.50, 0.92, n3 * 0.60 + n4 * 0.40);

	vec3 col = vec3(0.004, 0.004, 0.008);
	col += mix(nebula_color_b, nebula_color_a, neb_p) * neb_p * nebula_amount;
	col += nebula_color_c * neb_r * nebula_amount * 0.8;

	float s1 = star_layer(dir, star_density, star_size, 0.0);
	float s2 = star_layer(dir, star_density * 2.3, star_size * 0.55, 41.7);
	float s3 = star_layer(dir, star_density * 6.5, star_size * 0.30, 91.3);
	col += vec3(0.9, 0.9, 0.95) * (s1 + s2 * 0.6 + s3 * micro_star_amount) * star_brightness;
	COLOR = col;
}
shader_type spatial;
render_mode blend_add, unshaded, cull_disabled;

uniform vec4 tint : source_color = vec4(1.0, 0.12, 0.12, 1.0);
uniform float fade : hint_range(0.0, 1.0) = 1.0;
uniform float seed : hint_range(0.0, 100.0) = 7.0;

void fragment() {
	vec2 uv = UV * 2.0 - 1.0;
	float r = length(uv);
	if (r > 0.99) {
		discard;
	}
	float ang = atan(uv.y, uv.x);

	float a1 = sin(ang * 3.0 + seed * 1.71);
	float a2 = sin(ang * 5.0 + seed * 3.14);
	float a3 = sin(ang * 8.0 + seed * 5.43);
	float a4 = cos(ang * 13.0 + seed * 7.89);

	float raw_noise = (a1 * 0.4 + a2 * 0.3 + a3 * 0.2 + a4 * 0.1);
	float spikes = pow(max(0.0, raw_noise * 0.5 + 0.5), 1.7);
	float max_r = 0.12 + 0.78 * spikes;

	float ca = cos(seed * 0.63);
	float sa = sin(seed * 0.63);
	vec2 rot_uv = vec2(uv.x * ca - uv.y * sa, uv.x * sa + uv.y * ca);
	float streak1 = exp(-abs(rot_uv.y) * 40.0) * smoothstep(0.9, 0.0, abs(rot_uv.x));
	float streak2 = exp(-abs(rot_uv.x * 0.6 + rot_uv.y * 0.8) * 40.0) * smoothstep(0.7, 0.0, abs(-rot_uv.x * 0.8 + rot_uv.y * 0.6));
	float linear_streaks = (streak1 + streak2 * 0.6) * 0.75;

	float norm_r = r / max(max_r, 0.01);
	float ray_falloff = (r < max_r) ? pow(1.0 - norm_r, 1.6) : 0.0;
	float center_glow = (r < max_r) ? pow(1.0 - norm_r, 3.5) * 0.4 : 0.0;

	float total_shape = ray_falloff * 0.65 + center_glow + linear_streaks;
	if (total_shape <= 0.001) {
		discard;
	}

	float alpha = total_shape * fade;
	ALBEDO = tint.rgb * 2.5;
	ALPHA = alpha * tint.a;
}
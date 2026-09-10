shader_type spatial;
render_mode blend_add, unshaded, cull_disabled;

uniform vec4 tint : source_color = vec4(1.0, 0.12, 0.12, 1.0);
uniform float fade : hint_range(0.0, 1.0) = 1.0;
uniform float intensity : hint_range(0.0, 10.0) = 3.2;
uniform float core_softness : hint_range(0.1, 5.0) = 1.8;

void fragment() {
	float fresnel = clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);

	float white_core = pow(fresnel, 3.5);
	float color_glow = pow(fresnel, core_softness);
	float soft_rim = smoothstep(0.0, 0.22, fresnel);

	vec3 final_color = mix(tint.rgb * intensity, vec3(1.0, 1.0, 1.0) * (intensity * 1.6), white_core);
	float alpha = color_glow * soft_rim * fade;

	ALBEDO = final_color;
	ALPHA = alpha * tint.a;
}

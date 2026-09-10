shader_type spatial;
render_mode blend_add, unshaded, cull_disabled;

uniform vec4 tint : source_color = vec4(1.0, 0.12, 0.12, 1.0);
uniform float brightness : hint_range(1.0, 10.0) = 3.5;

void fragment() {
	float head = pow(clamp(UV.y, 0.0, 1.0), 3.0);
	vec3 base_color = tint.rgb * brightness;
	vec3 white_head = vec3(1.0, 1.0, 1.0) * (brightness * 1.6);
	vec3 final_color = mix(base_color, white_head, head);

	ALBEDO = final_color;
	ALPHA = tint.a;
}

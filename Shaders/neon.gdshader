shader_type spatial;
render_mode unshaded, blend_add, cull_disabled;

uniform vec4 color : source_color = vec4(0.54, 0.36, 1.0, 1.0);
uniform float brillo_hdr : hint_range(1.0, 8.0) = 2.5;
uniform float pulso_amount : hint_range(0.0, 1.0) = 0.25;
uniform float pulso_speed : hint_range(0.0, 10.0) = 2.0;
uniform float core_softness : hint_range(0.1, 4.0) = 1.5;

void fragment() {
	float facing = abs(dot(normalize(NORMAL), normalize(VIEW)));
	float core = pow(clamp(facing, 0.0, 1.0), core_softness);
	float pulse = 1.0 + pulso_amount * sin(TIME * pulso_speed);
	float intensity = (0.35 + 0.65 * core) * brillo_hdr * pulse;
	ALBEDO = color.rgb * intensity;
	ALPHA = clamp(0.25 + 0.75 * core, 0.0, 1.0);
}
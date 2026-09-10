shader_type canvas_item;

uniform float amp : hint_range(0.0, 0.2) = 0.06;
uniform float freq : hint_range(0.0, 40.0) = 12.0;
uniform float speed : hint_range(0.0, 10.0) = 5.0;
uniform float phase : hint_range(0.0, 6.283) = 0.0;
uniform vec4 tint : source_color = vec4(0.48, 0.12, 0.75, 1.0);
uniform float tint_mix : hint_range(0.0, 1.0) = 0.65;

void fragment() {
	vec2 uv = UV;
	uv.y += sin(TIME * speed + UV.x * freq + phase) * amp;
	vec4 col = texture(TEXTURE, uv);
	col.rgb = mix(col.rgb, tint.rgb, tint_mix);
	COLOR = col;
}
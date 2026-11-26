shader_type canvas_item;
render_mode unshaded;

uniform vec4 glow_color : source_color = vec4(1.0, 0.94, 0.57, 0.86);
uniform float strength : hint_range(0.0, 1.0) = 0.4;

uniform vec4 weather_tint : source_color = vec4(0.0);
uniform vec4 night_tint : source_color = vec4(0.0);

void fragment() {
	float center = texture(TEXTURE, UV).a;
	vec2 step_size = TEXTURE_PIXEL_SIZE;
	float neighbors = max(texture(TEXTURE, UV + vec2(step_size.x, 0.0)).a,
		texture(TEXTURE, UV - vec2(step_size.x, 0.0)).a);
	neighbors = max(neighbors, texture(TEXTURE, UV + vec2(0.0, step_size.y)).a);
	neighbors = max(neighbors, texture(TEXTURE, UV - vec2(0.0, step_size.y)).a);
	float edge = max(0.0, neighbors - center);
	vec3 tint = mix(glow_color.rgb, weather_tint.rgb, weather_tint.a);
	tint = mix(tint, night_tint.rgb, night_tint.a);
	COLOR = vec4(tint, edge * glow_color.a * strength);
}

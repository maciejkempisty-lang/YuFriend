shader_type canvas_item;
render_mode unshaded;

// Upright props now render after the background weather wash. Apply the same
// wash locally so their palette stays consistent with the original scene.
uniform vec4 weather_tint : source_color = vec4(0.0);
uniform vec4 night_tint : source_color = vec4(0.0);

void fragment() {
	COLOR.rgb = mix(COLOR.rgb, weather_tint.rgb, weather_tint.a);
	COLOR.rgb = mix(COLOR.rgb, night_tint.rgb, night_tint.a);
}

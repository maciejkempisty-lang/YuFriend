shader_type canvas_item;
render_mode unshaded;

uniform float cutoff : hint_range(0.0, 1.0) = 0.5;

uniform float dirt : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	float patch = step(0.1, sin(UV.x * 95.0) * cos(UV.y * 75.0));
	COLOR.rgb = mix(COLOR.rgb, vec3(0.38, 0.25, 0.12), dirt * patch * 0.65);
	// The delivered PNGs contain faint alpha fringes; keep originals intact.
	if (COLOR.a < cutoff) {
		discard;
	}
}

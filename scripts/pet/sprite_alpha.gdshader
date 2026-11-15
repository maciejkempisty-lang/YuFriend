shader_type canvas_item;
render_mode unshaded;

uniform float cutoff : hint_range(0.0, 1.0) = 0.5;

void fragment() {
	// The delivered PNGs contain faint alpha fringes; keep originals intact.
	if (COLOR.a < cutoff) {
		discard;
	}
}

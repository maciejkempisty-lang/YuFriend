shader_type canvas_item;
render_mode unshaded;

// The viewport has a one-art-pixel gutter. Sample between its cells only at
// physical-screen-pixel steps; nearest filtering preserves sharp pixel blocks.
uniform vec2 camera_offset = vec2(0.0);
void fragment() {
	COLOR = texture(TEXTURE, UV + camera_offset * TEXTURE_PIXEL_SIZE);
}

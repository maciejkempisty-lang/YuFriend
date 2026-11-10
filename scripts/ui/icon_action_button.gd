class_name IconActionButton
extends Button

var caption: String = "":
	set(value):
		caption = value
		tooltip_text = value
		accessibility_name = value
		queue_redraw()
var icon_name: String = "paw"
var accent := Color("e6ebd8")
var selected: bool = false:
	set(value):
		selected = value
		queue_redraw()
var navigation: bool = false

func _ready() -> void:
	custom_minimum_size = Vector2(48, 66 if navigation else 74)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		add_theme_stylebox_override(state, StyleBoxEmpty.new())
	mouse_entered.connect(queue_redraw)
	mouse_exited.connect(queue_redraw)
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)

func _draw() -> void:
	var ink := Color("24483d") if not disabled else Color("8f9487")
	var fill := accent if not disabled else Color("eae9df")
	var center := Vector2(size.x / 2, 25 if not navigation else 23)
	if navigation:
		fill = Color("e3ecd8") if selected else Color.TRANSPARENT
		ink = Color("24483d") if selected else Color("7b8172")
	if is_hovered() and not disabled: fill = fill.lightened(0.06) if fill.a > 0 else Color("f0efdf")
	if button_pressed: fill = fill.darkened(0.08)
	var pill := StyleBoxFlat.new()
	pill.bg_color = fill
	pill.set_corner_radius_all(18 if navigation else 16)
	if has_focus():
		pill.border_color = Color("67876b")
		pill.set_border_width_all(2)
	draw_style_box(pill, Rect2(center - Vector2(27 if navigation else 23, 21), Vector2(54 if navigation else 46, 42)))
	draw_texture_rect(GameIcons.texture(icon_name, ink), Rect2(center - Vector2(11, 11), Vector2(22, 22)), false)
	var font := get_theme_font("font")
	var font_size := 12 if not navigation else 13
	var width := font.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	draw_string(font, Vector2((size.x - width) / 2, 65 if not navigation else 57), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, ink)

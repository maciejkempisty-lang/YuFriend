class_name IconActionButton
extends Button

var caption: String = "":
	set(value):
		caption = value
		# The caption is drawn on the button; a hover tooltip on a phone only repeats it.
		accessibility_name = value
		queue_redraw()
var icon_name: String = "paw"
var accent := Color("e6ebd8")
var selected: bool = false:
	set(value):
		selected = value
		queue_redraw()
var navigation: bool = false
var compact: bool = false
var need_value := -1.0
var cooldown_ratio := 0.0
var cooldown_left := 0.0
var reward_ratio := -1.0
var favorite := false
var flash_left := 0.0

func _process(delta: float) -> void:
	if flash_left > 0:
		flash_left = maxf(0, flash_left - delta)
		queue_redraw()

func _ready() -> void:
	custom_minimum_size = Vector2(48, 28 if compact else (54 if navigation else 88))
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		add_theme_stylebox_override(state, StyleBoxEmpty.new())
	mouse_entered.connect(queue_redraw)
	mouse_exited.connect(queue_redraw)
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)

func _draw() -> void:
	if compact:
		var pill := StyleBoxFlat.new()
		pill.bg_color = Color("e3ecd8") if selected else Color.TRANSPARENT
		pill.set_corner_radius_all(9)
		draw_style_box(pill, Rect2(Vector2.ZERO, size))
		var color := Color("24483d") if selected else Color("7b8172")
		var font := get_theme_font("font")
		var text_width := font.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
		var x := maxf(4, (size.x - text_width - 20) / 2)
		draw_texture_rect(GameIcons.texture(icon_name, color), Rect2(x, 6, 16, 16), false)
		draw_string(font, Vector2(x + 20, 18), caption, HORIZONTAL_ALIGNMENT_LEFT, size.x - x - 20, 11, color)
		return
	var ink := Color("24483d") if not disabled else Color("8f9487")
	var fill := accent if not disabled else Color("eae9df")
	var center := Vector2(size.x / 2, 26 if not navigation else 18)
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
	if need_value >= 0:
		var color := NeedIndicator.level_color(need_value)
		draw_arc(center, 23, 0, TAU, 64, Color("dcdcca"), 4, true)
		draw_arc(center, 23, -PI / 2, -PI / 2 + TAU * clampf(need_value / 100, 0, 1), 64, color, 4, true)
		if flash_left > 0: draw_arc(center, 26, 0, TAU, 64, Color(color, flash_left / 1.2), 3, true)
	if cooldown_ratio > 0:
		var points := PackedVector2Array([center])
		for i in 49:
			var angle := -PI / 2 + TAU * cooldown_ratio * i / 48
			points.append(center + Vector2(cos(angle), sin(angle)) * 20)
		draw_colored_polygon(points, Color(0.20, 0.36, 0.28, 0.20))
	if reward_ratio >= 0:
		draw_arc(center, 24, 0, TAU, 64, Color("dedac4"), 4, true)
		draw_arc(center, 24, -PI / 2, -PI / 2 + TAU * reward_ratio, 64, Color("b08029"), 4, true)
	if favorite:
		draw_circle(center + Vector2(21, -17), 9, Color("315d49"))
		draw_texture_rect(GameIcons.texture("heart", Color("fff9ed")), Rect2(center + Vector2(15, -23), Vector2(12, 12)), false)
	if cooldown_left > 0:
		_draw_centered("%d s" % ceili(cooldown_left), center.y + 5, 14, ink)
	else:
		draw_texture_rect(GameIcons.texture(icon_name, ink), Rect2(center - Vector2(11, 11), Vector2(22, 22)), false)
	_draw_centered(caption, 66 if not navigation else 48, 12 if not navigation else 13, ink)
	if need_value >= 0:
		_draw_centered("%d%%" % roundi(need_value), 83, 12, NeedIndicator.level_color(need_value))
	elif favorite:
		_draw_centered("Ulubiona", 83, 11, Color("527c51"))

func _draw_centered(value: String, y: float, font_size: int, ink: Color) -> void:
	var font := get_theme_font("font")
	var width := font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	while width > size.x - 6 and font_size > 9:
		font_size -= 1
		width = font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	draw_string(font, Vector2((size.x - width) / 2, y), value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, ink)

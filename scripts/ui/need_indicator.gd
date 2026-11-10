class_name NeedIndicator
extends Control

var caption: String = ""
var icon_name: String = "paw"
var value: float = 100.0:
	set(next):
		value = next
		tooltip_text = "%s · %d%%" % [caption, roundi(value)]
		accessibility_name = tooltip_text
		queue_redraw()

func _ready() -> void:
	custom_minimum_size = Vector2(48, 62)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_STOP

func _draw() -> void:
	var center := Vector2(size.x / 2, 20)
	var color := Color("6d8b64") if value >= 30 else Color("b76c4f")
	draw_circle(center, 18, Color("fbf7e9"))
	draw_arc(center, 18, 0, TAU, 64, Color("dfdfca"), 3, true)
	draw_arc(center, 18, -PI / 2, -PI / 2 + TAU * clampf(value / 100, 0, 1), 64, color, 3, true)
	draw_texture_rect(GameIcons.texture(icon_name, Color("48664e")), Rect2(center - Vector2(9, 9), Vector2(18, 18)), false)
	var font := get_theme_font("font")
	var width := font.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
	draw_string(font, Vector2((size.x - width) / 2, 57), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("53634c"))

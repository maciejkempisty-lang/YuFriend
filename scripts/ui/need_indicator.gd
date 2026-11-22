class_name NeedIndicator
extends Control

var caption: String = ""
var icon_name: String = "paw"
var value: float = 100.0:
	set(next):
		value = next
		accessibility_name = "%s · %d%%" % [caption, roundi(value)]
		queue_redraw()

static func level_color(amount: float) -> Color:
	if amount < 30: return Color("b95036")
	if amount < 60: return Color("a97924")
	return Color("527c51")

func _ready() -> void:
	custom_minimum_size = Vector2(48, 80)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_STOP

func _draw() -> void:
	var center := Vector2(size.x / 2, 20)
	var color := level_color(value)
	draw_circle(center, 18, Color("fbf7e9"))
	draw_arc(center, 18, 0, TAU, 64, Color("dfdfca"), 5, true)
	draw_arc(center, 18, -PI / 2, -PI / 2 + TAU * clampf(value / 100, 0, 1), 64, color, 5, true)
	draw_texture_rect(GameIcons.texture(icon_name, Color("48664e")), Rect2(center - Vector2(9, 9), Vector2(18, 18)), false)
	var font := get_theme_font("font")
	var width := font.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
	draw_string(font, Vector2((size.x - width) / 2, 57), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("53634c"))
	var amount := "%d%%" % roundi(value)
	width = font.get_string_size(amount, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
	draw_string(font, Vector2((size.x - width) / 2, 75), amount, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, color)

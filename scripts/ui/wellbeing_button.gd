class_name WellbeingButton
extends Button

var feeling := 3
var sleeping := false

func _ready() -> void:
	custom_minimum_size = Vector2(120, 44)
	alignment = HORIZONTAL_ALIGNMENT_LEFT
	add_theme_font_size_override("font_size", 12)
	for state in ["normal", "hover", "pressed", "disabled"]:
		var style := StyleBoxEmpty.new()
		style.content_margin_left = 28
		add_theme_stylebox_override(state, style)

func _draw() -> void:
	var center := Vector2(12, size.y / 2)
	var ink := Color("52664c")
	draw_circle(center, 10, Color("e6c993") if feeling >= 2 else Color("c9d3cf"))
	for x in [-3, 3]:
		if sleeping: draw_line(center + Vector2(x - 1, -2), center + Vector2(x + 1, -2), ink, 1.5, true)
		else: draw_circle(center + Vector2(x, -2), 1, ink)
	if sleeping or feeling == 2: draw_line(center + Vector2(-3, 4), center + Vector2(3, 4), ink, 1.5, true)
	elif feeling == 3: draw_arc(center + Vector2(0, 1), 4, 0, PI, 16, ink, 1.5, true)
	else: draw_arc(center + Vector2(0, 7), 4, PI, TAU, 16, ink, 1.5, true)

class_name YardSparkle
extends Control

# A quiet pixel twinkle above a yard place the player has not tried yet.
# It never takes input: the place itself is the touch target.

const PIXEL := 3.0
var phase := 0.0

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(21, 21)
	pivot_offset = size / 2

func _process(delta: float) -> void:
	if not is_visible_in_tree(): return
	phase = fmod(phase + delta, 1.8)
	var t := sin(phase / 1.8 * TAU)
	modulate.a = 0.55 + 0.45 * maxf(0, t)
	scale = Vector2.ONE * (0.85 + 0.15 * maxf(0, t))
	queue_redraw()

func _draw() -> void:
	var gold := Color("f4cf63")
	var core := Color("fff6d8")
	var edge := Color("8a5f2488")
	var c := Vector2(9, 9)
	var long := 3 if sin(phase / 1.8 * TAU) > 0.3 else 2
	var cells: Array[Vector2] = [c]
	for i in range(1, long + 1):
		for dir in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
			cells.append(c + dir * i * PIXEL)
	# Soft outline first, then the star: readable on grass, leaves and sky.
	for cell in cells: draw_rect(Rect2(cell, Vector2(PIXEL, PIXEL)).grow(1), edge)
	for cell in cells: draw_rect(Rect2(cell, Vector2(PIXEL, PIXEL)), core if cell == c else gold)

class_name PetSpeechCloud
extends PanelContainer

# A compact speech cloud for the moving pet overlays. The body stays within
# the Control rect; the tail is drawn toward the pet in the parent's space.
const FILL := Color("fff5db")
const EDGE := Color("d5aa68")
const SHADOW := Color(0.34, 0.28, 0.18, 0.18)

var _target := Vector2.INF

func _ready() -> void:
	resized.connect(queue_redraw)

func point_to(target: Vector2) -> void:
	if _target.is_equal_approx(target): return
	_target = target
	queue_redraw()

func _draw() -> void:
	if size.x < 30 or size.y < 30: return
	var shape := _outline()
	var shadow := PackedVector2Array()
	for point in shape: shadow.append(point + Vector2(0, 3))
	draw_colored_polygon(shadow, SHADOW)
	if _target.is_finite():
		var tail := _tail()
		if not tail.is_empty():
			var tail_shadow := PackedVector2Array()
			for point in tail: tail_shadow.append(point + Vector2(0, 3))
			draw_colored_polygon(tail_shadow, SHADOW)
			draw_colored_polygon(tail, FILL)
			draw_line(tail[0], tail[1], EDGE, 2.0, true)
			draw_line(tail[1], tail[2], EDGE, 2.0, true)
	draw_colored_polygon(shape, FILL)
	shape.append(shape[0])
	draw_polyline(shape, EDGE, 2.0, true)

func _outline() -> PackedVector2Array:
	var points := PackedVector2Array()
	var center := size * 0.5
	var radius := center - Vector2(2, 2)
	for index in 64:
		var angle := TAU * float(index) / 64.0
		var x := cos(angle)
		var y := sin(angle)
		var ripple := 1.0 + 0.025 * cos(angle * 10.0)
		points.append(center + Vector2(sign(x) * pow(absf(x), 0.52) * radius.x,
			sign(y) * pow(absf(y), 0.52) * radius.y) * ripple)
	return points

func _tail() -> PackedVector2Array:
	var tip := _target - position - Vector2(0, 5)
	var below := tip.y >= size.y * 0.5
	var base_y := size.y - 5 if below else 5.0
	var base_x := clampf(tip.x, 24.0, size.x - 24.0)
	return PackedVector2Array([
		Vector2(base_x - 11.0, base_y), tip, Vector2(base_x + 11.0, base_y)
	])

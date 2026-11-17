class_name YardCourseView
extends Node2D
var playing := false
func block(point: Vector2, extent: Vector2, color: String) -> void:
	draw_rect(Rect2((point / 3).round() * 3, extent), Color(color))
func _draw() -> void:
	# A folded course sign remains visible; props unfold only during a round.
	block(Vector2(1000, 240), Vector2(6, 54), "947354")
	block(Vector2(979, 234), Vector2(54, 27), "e5ce96")
	block(Vector2(991, 246), Vector2(30, 3), "648778")
	if not playing: return
	for x in [860, 920, 980]:
		block(Vector2(x - 12, 309), Vector2(24, 6), "e7c080")
		block(Vector2(x - 9, 300), Vector2(18, 9), "cc865f")
		block(Vector2(x - 6, 291), Vector2(12, 9), "f4e3bc")
		block(Vector2(x - 3, 285), Vector2(6, 6), "cc865f")
	for x in [1085, 1115]:
		block(Vector2(x, 276), Vector2(6, 42), "a77d56")
		block(Vector2(x - 6, 315), Vector2(18, 6), "947354")
	block(Vector2(1079, 288), Vector2(48, 6), "f2d4a2")
	block(Vector2(1094, 288), Vector2(12, 6), "cc865f")
	block(Vector2(1237, 315), Vector2(66, 9), "987557")
	block(Vector2(1231, 306), Vector2(78, 9), "d6b780")
	block(Vector2(1255, 306), Vector2(30, 3), "e8d8ad")

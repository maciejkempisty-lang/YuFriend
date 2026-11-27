class_name YardCourseView
extends Node2D
var playing := false:
	set(value):
		playing = value
		for prop in get_children(): prop.visible = value
var draw_sign := true
func _ready() -> void:
	y_sort_enabled = true
	for i in 5:
		var prop := CourseProp.new()
		prop.part = i
		if i == 4: prop.z_index = -1
		prop.origin = Vector2([860, 920, 980, 1100, 1270][i], 315 if i < 3 else 321)
		if i < 3: prop.position = RoomLayoutLoader.clamp_to_level(RoomLayout.yard_stand("course") + Vector2([-150, -90, -30][i], 0), "yard")
		elif i == 3: prop.position = (YardCourse.path()[-1] + YardCourse.landing()) * 0.5
		else: prop.position = YardCourse.podium()
		prop.visible = playing
		add_child(prop)

func block(point: Vector2, extent: Vector2, color: String) -> void:
	draw_rect(Rect2((point / 3).round() * 3, extent), Color(color))
func _draw() -> void:
	# A folded course sign remains visible; props unfold only during a round.
	if draw_sign:
		block(Vector2(1000, 240), Vector2(6, 54), "947354")
		block(Vector2(979, 234), Vector2(54, 27), "e5ce96")
		block(Vector2(991, 246), Vector2(30, 3), "648778")

# Independent bases let the dog pass in front of or behind each obstacle.
# Drawing coordinates below retain the original world-space geometry.
class CourseProp extends Node2D:
	var part := 0
	var origin := Vector2.ZERO
	func block(point: Vector2, extent: Vector2, color: String) -> void:
		draw_rect(Rect2((point / 3).round() * 3 - origin, extent), Color(color))
	func _draw() -> void:
		if part < 3:
			var x: int = [860, 920, 980][part]
			block(Vector2(x - 12, 309), Vector2(24, 6), "e7c080")
			block(Vector2(x - 9, 300), Vector2(18, 9), "cc865f")
			block(Vector2(x - 6, 291), Vector2(12, 9), "f4e3bc")
			block(Vector2(x - 3, 285), Vector2(6, 6), "cc865f")
		elif part == 3:
			for x in [1085, 1115]:
				block(Vector2(x, 276), Vector2(6, 42), "a77d56")
				block(Vector2(x - 6, 315), Vector2(18, 6), "947354")
			block(Vector2(1079, 288), Vector2(48, 6), "f2d4a2")
			block(Vector2(1094, 288), Vector2(12, 6), "cc865f")
		else:
			block(Vector2(1237, 315), Vector2(66, 9), "987557")
			block(Vector2(1231, 306), Vector2(78, 9), "d6b780")
			block(Vector2(1255, 306), Vector2(30, 3), "e8d8ad")

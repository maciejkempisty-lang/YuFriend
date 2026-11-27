class_name YardRestView
extends Node2D
var drinking := false
var draw_static := true
var animate := true
var clock := 0.0
func _process(delta: float) -> void:
	if not visible or not animate: return
	if drinking:
		clock += delta
		queue_redraw()
func block(point: Vector2, extent: Vector2, color: String) -> void:
	draw_rect(Rect2((point / 3).round() * 3, extent), Color(color))
func _draw() -> void:
	# Canopy, shadow and woven bed, on the same pixel grid as the yard.
	if draw_static:
		block(Vector2(150, 307), Vector2(150, 21), "8ca374")
		for x in [156, 288]: block(Vector2(x, 213), Vector2(6, 105), "947354")
		block(Vector2(147, 198), Vector2(156, 21), "729885")
		for x in range(159, 297, 24): block(Vector2(x, 201), Vector2(9, 18), "a8b99a")
		block(Vector2(165, 306), Vector2(111, 18), "aa8661")
		block(Vector2(174, 306), Vector2(93, 12), "e3c894")
		block(Vector2(183, 303), Vector2(75, 9), "e9d7ad")
	var bowl := YardRest.bowl()
	if draw_static:
		block(bowl + Vector2(-24, -9), Vector2(48, 12), "688f8b")
		block(bowl + Vector2(-18, -12), Vector2(36, 9), "afd6d2")
		block(bowl + Vector2(-15, -9), Vector2(30, 3), "78b1ba")
		block(bowl + Vector2(-18, 3), Vector2(36, 3), "527c77")
	if drinking:
		var radius := 6 + int(clock * 14) % 12
		block(bowl + Vector2(-radius, -9), Vector2(radius * 2, 3), "d6efdf")
		if int(clock * 6) % 2 == 0:
			block(bowl + Vector2(-12, -18), Vector2(3, 6), "b6e1de")
			block(bowl + Vector2(9, -21), Vector2(3, 3), "b6e1de")

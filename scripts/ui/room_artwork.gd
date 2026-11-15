class_name RoomArtwork
extends Node2D

const ROOM_BACKGROUND = preload("res://assets/art/environments/puppy-room-pixel-v1.png")
const PIXEL := RoomLayout.PIXEL_SIZE
var kind := "room"
var area := Vector2.ZERO
var roll_phase := 0.0
var draw_count := 0

func configure(bounds: Vector2) -> void:
	if area == bounds: return
	area = bounds
	queue_redraw()

func _draw() -> void:
	draw_count += 1
	match kind:
		"room": _draw_room()
		"shadow": _pixel_ellipse(Vector2(0, 3), Vector2(53, 9), Color(0.35, 0.31, 0.20, 0.16))
		"ball": _draw_ball()
		"bed": _draw_bed()
		"food": _draw_bowl()
		"toys": _draw_toys()
		"door": _draw_door()

func _draw_room() -> void:
	if area.x <= 0: return
	draw_rect(Rect2(Vector2.ZERO, area), Color("eae9d2"))
	# Temporary high-resolution reference; the room viewport samples it on the art grid.
	var texture_scale := 0.4
	# Extend the edge colour of each scanline so the central wall has no hard seam.
	draw_texture_rect_region(ROOM_BACKGROUND, Rect2(0, 0, 400, 260), Rect2(0, 186, 1, 650))
	draw_texture_rect_region(ROOM_BACKGROUND, Rect2(901.6, 0, area.x - 901.6, 260), Rect2(1253, 186, 1, 650))
	var wall_source := Rect2(0, 186, 1254, 650)
	draw_texture_rect_region(ROOM_BACKGROUND, Rect2(400, 0, 501.6, 260), wall_source)
	var floor_source := Rect2(0, 900, 600, 354)
	var tile := floor_source.size * texture_scale
	var y := RoomLayout.FLOOR_Y
	while y < area.y:
		var x := 0.0
		while x < area.x:
			draw_texture_rect_region(ROOM_BACKGROUND, Rect2(Vector2(x, y), tile), floor_source)
			x += tile.x
		y += tile.y
	_pixel_rect(Rect2(0, RoomLayout.FLOOR_Y, area.x, 12), Color("805733"))
	_pixel_rect(Rect2(0, RoomLayout.FLOOR_Y + 3, area.x, 6), Color("c79457"))
	# Light belongs to the single window, rather than repeating in every floor tile.
	for row in range(0, 87, 3):
		if row >= 63 and row < 78: continue
		for pane in 2:
			_pixel_rect(Rect2(708 + pane * 51 - row * 0.75, RoomLayout.FLOOR_Y + 12 + row, 39, 3), Color(1.0, 0.92, 0.65, 0.24))
	var rug := Vector2(745, 324)
	_pixel_ellipse(rug + Vector2(0, 6), Vector2(256, 30), Color("b79364"))
	_pixel_ellipse(rug, Vector2(256, 30), Color("7c9064"))
	_pixel_ellipse(rug - Vector2(0, 3), Vector2(247, 27), Color("a9b582"))
	_pixel_ellipse(rug - Vector2(0, 3), Vector2(231, 21), Color("c9cc9c"))
	# A quiet corner above the bed, using the same three-unit prop grid.
	_pixel_rect(Rect2(138, 93, 78, 84), Color("805733"))
	_pixel_rect(Rect2(144, 99, 66, 72), Color("f4d8a7"))
	_pixel_rect(Rect2(150, 105, 54, 60), Color("fbefca"))
	_pixel_ellipse(Vector2(177, 141), Vector2(16, 12), Color("b8804a"))
	for toe in [Vector2(159, 126), Vector2(171, 117), Vector2(186, 117), Vector2(198, 129)]:
		_pixel_ellipse(toe, Vector2(5, 6), Color("b8804a"))
	_pixel_rect(Rect2(245, 126, 120, 9), Color("805733"))
	_pixel_rect(Rect2(251, 126, 108, 3), Color("c79457"))
	for i in 4:
		_pixel_rect(Rect2(258 + i * 12, 93 - (i % 2) * 6, 9, 33 + (i % 2) * 6), [Color("75906f"), Color("b97c53"), Color("d1b47d"), Color("8b9b89")][i])
	_pixel_rect(Rect2(321, 111, 21, 15), Color("ad7350"))
	_pixel_ellipse(Vector2(330, 102), Vector2(15, 15), Color("718960"))
	_pixel_ellipse(Vector2(336, 96), Vector2(10, 13), Color("9db37b"))

func _draw_bed() -> void:
	var center := Vector2(0, -20)
	_pixel_ellipse(center + Vector2(0, 6), Vector2(93, 31), Color("b79364"))
	_pixel_ellipse(center, Vector2(88, 34), Color("536a4f"))
	_pixel_ellipse(center - Vector2(0, 3), Vector2(81, 29), Color("7d9970"))
	_pixel_ellipse(center - Vector2(0, 3), Vector2(65, 22), Color("526d50"))
	_pixel_ellipse(center - Vector2(0, 1), Vector2(59, 18), Color("e4d9a7"))
	_pixel_rect(Rect2(-63, -6, 18, 3), Color("a2b287"))

func _draw_bowl() -> void:
	var bowl := Rect2(-25, -28, 50, 28)
	_pixel_ellipse(Vector2(0, -5), Vector2(31, 10), Color("b79364"))
	_pixel_rect(Rect2(bowl.position + Vector2(3, 7), bowl.size - Vector2(6, 7)), Color("825538"))
	_pixel_rect(Rect2(bowl.position + Vector2(6, 10), bowl.size - Vector2(12, 13)), Color("bf7852"))
	_pixel_rect(Rect2(bowl.position + Vector2(9, 24), Vector2(35, 3)), Color("df9c69"))
	var rim := Vector2(0, -22)
	_pixel_ellipse(rim, Vector2(28, 10), Color("825538"))
	_pixel_ellipse(rim - Vector2(0, 2), Vector2(25, 8), Color("e8b583"))
	_pixel_ellipse(rim - Vector2(0, 2), Vector2(19, 5), Color("65472f"))
	for i in 5:
		_pixel_rect(Rect2(rim + Vector2(-15 + i * 6, -4 + (i % 2) * 3), Vector2(3, 3)), Color("bb8c4f"))

func _draw_toys() -> void:
	_pixel_ellipse(Vector2(0, 0), Vector2(55, 12), Color("b79364"))
	_pixel_ellipse(Vector2(-17, -54), Vector2(19, 19), Color("688b88"))
	_pixel_ellipse(Vector2(-20, -59), Vector2(7, 9), Color("a7c4b4"))
	_pixel_rect(Rect2(12, -69, 12, 36), Color("e3d8af"))
	for x in [9, 24]:
		_pixel_ellipse(Vector2(x, -66), Vector2(7, 7), Color("f3e7bb"))
	_pixel_rect(Rect2(-48, -48, 96, 45), Color("805733"))
	_pixel_rect(Rect2(-42, -42, 84, 36), Color("bb8e55"))
	for y in [-39, -27, -15]:
		_pixel_rect(Rect2(-42, y, 84, 3), Color("d6ab6a"))
	for x in [-30, -6, 18, 36]:
		_pixel_rect(Rect2(x, -42, 3, 36), Color("a57546"))
	_pixel_rect(Rect2(-48, -51, 96, 9), Color("e0b87a"))
	_pixel_rect(Rect2(-15, -39, 30, 9), Color("805733"))

func _draw_door() -> void:
	_pixel_ellipse(Vector2(-15, 38), Vector2(85, 19), Color("a9956c"))
	_pixel_ellipse(Vector2(-15, 35), Vector2(78, 16), Color("bfc19a"))
	_pixel_rect(Rect2(-60, -186, 120, 186), Color("6c563a"))
	_pixel_rect(Rect2(-54, -180, 108, 180), Color("b2844f"))
	_pixel_rect(Rect2(-48, -174, 96, 174), Color("c99d61"))
	for y in [-162, -84]:
		_pixel_rect(Rect2(-36, y, 72, 66), Color("ab7c49"))
		_pixel_rect(Rect2(-30, y + 6, 60, 54), Color("c19960"))
	_pixel_rect(Rect2(32, -105, 9, 21), Color("805733"))
	_pixel_ellipse(Vector2(36, -93), Vector2(7, 7), Color("f3d797"))
	_pixel_rect(Rect2(-63, 0, 126, 6), Color("805733"))

func _draw_ball() -> void:
	var ball := Vector2.ZERO
	_pixel_ellipse(ball + Vector2(0, 13), Vector2(15, 5), Color("b79364"))
	_pixel_ellipse(ball, Vector2(14, 14), Color("4d666d"))
	_pixel_ellipse(ball - Vector2(0, 1), Vector2(11, 11), Color("709ca3"))
	_pixel_rect(Rect2(ball + Vector2(roundf(sin(roll_phase) * 2) * 3 - 3, -9), Vector2(6, 3)), Color("dce8c4"))
	_pixel_rect(Rect2(ball + Vector2(roundf(sin(roll_phase) * 2) * 3 - 6, -6), Vector2(3, 12)), Color("b7d2c2"))

func _pixel_rect(rect: Rect2, color: Color) -> void:
	var origin := (rect.position / PIXEL).round() * PIXEL
	var end := (rect.end / PIXEL).round() * PIXEL
	draw_rect(Rect2(origin, end - origin), color)

func _pixel_ellipse(center: Vector2, radii: Vector2, color: Color) -> void:
	if radii.x <= 0 or radii.y <= 0: return
	for row in range(floori((center.y - radii.y) / PIXEL), ceili((center.y + radii.y) / PIXEL)):
		var y := row * PIXEL
		var t := (y + PIXEL * 0.5 - center.y) / radii.y
		if absf(t) >= 1: continue
		var half_width := radii.x * sqrt(1.0 - t * t)
		var left := roundf((center.x - half_width) / PIXEL) * PIXEL
		var right := roundf((center.x + half_width) / PIXEL) * PIXEL
		draw_rect(Rect2(left, y, maxf(PIXEL, right - left), PIXEL), color)

class_name RoomArtwork
extends Node2D

const ROOM_BACKGROUND = preload("res://level-editor/assets/environment-puppy-room-pixel-v1.png")
const YARD_BACKGROUND = preload("res://level-editor/assets/environment-yard-sunny-background-v1.png")
const PIXEL := RoomLayout.PIXEL_SIZE
var portal_open := false
var yard_overlay_only := false
var kind := "room"
var garden_state: Dictionary = {}
var garden_key := ""
var decor: Array = []
const DECOR_ATLAS = preload("res://level-editor/assets/environment-decor-v1.png")
const DECOR_REGIONS := {"rug": Rect2(39, 474, 449, 232), "flower": Rect2(617, 293, 275, 469), "shelf": Rect2(1040, 382, 447, 329)}
var area := Vector2.ZERO
var roll_phase := 0.0
var ball_held := false
var draw_count := 0

func configure(bounds: Vector2) -> void:
	if area == bounds: return
	area = bounds
	queue_redraw()

func _draw() -> void:
	draw_count += 1
	match kind:
		"room":
			_draw_room()
			_draw_decor()
		"yard": _draw_yard()
		"yard_gate": _draw_yard_gate()
		"yard_garden": _draw_yard_garden()
		"yard_dig": _draw_yard_dig()
		"yard_fetch": _draw_yard_fetch()
		"yard_outing": _draw_yard_outing()
		"yard_bush_0": _draw_yard_bush(350)
		"yard_bush_1": _draw_yard_bush(750)
		"yard_bush_2": _draw_yard_bush(1150)
		"hide_tail": _draw_hide_tail()
		"shadow": _pixel_ellipse(Vector2(0, 3), Vector2(53, 9), Color(0.35, 0.31, 0.20, 0.16))
		"ball": _draw_ball()
		"bed": _draw_bed()
		"food": _draw_bowl()
		"toys": _draw_toys()
		"door": _draw_door()

func _draw_room() -> void:
	if area.x <= 0: return
	draw_rect(Rect2(Vector2.ZERO, area), Color("eae9d2"))
	# A medium portrait frame exposes more wall above the original panorama.
	# Continue its top edge instead of showing the viewport's clear colour.
	draw_texture_rect_region(ROOM_BACKGROUND, Rect2(0, -2400, area.x, 2400), Rect2(0, 186, 1, 1))
	# Extend the edge colour of each scanline so the central wall has no hard seam.
	draw_texture_rect_region(ROOM_BACKGROUND, Rect2(0, 0, 400, 260), Rect2(0, 186, 1, 650))
	draw_texture_rect_region(ROOM_BACKGROUND, Rect2(901.6, 0, area.x - 901.6, 260), Rect2(1253, 186, 1, 650))
	var wall_source := Rect2(0, 186, 1254, 650)
	draw_texture_rect_region(ROOM_BACKGROUND, Rect2(400, 0, 501.6, 260), wall_source)
	# Remove the baked plant before drawing wall decor. Its original pot was
	# cropped by the wall/floor split, and the new portrait covered its leaves.
	draw_texture_rect_region(ROOM_BACKGROUND, Rect2(480, 198, 78, 62), Rect2(1080, 681, 1, 155))
	_draw_window()
	_draw_floor()
	_pixel_rect(Rect2(0, RoomLayout.FLOOR_Y, area.x, 12), Color("805733"))
	_pixel_rect(Rect2(0, RoomLayout.FLOOR_Y + 3, area.x, 6), Color("c79457"))
	var rug := Vector2(745, 324)
	_pixel_ellipse(rug + Vector2(0, 6), Vector2(256, 30), Color("b79364"))
	_pixel_ellipse(rug, Vector2(256, 30), Color("7c9064"))
	_pixel_ellipse(rug - Vector2(0, 3), Vector2(247, 27), Color("a9b582"))
	_pixel_ellipse(rug - Vector2(0, 3), Vector2(231, 21), Color("c9cc9c"))
	# Window light falls across both the floor and the rug, behind all solid props.
	for row in range(0, 87, 3):
		if row >= 63 and row < 78: continue
		for pane in 2:
			_pixel_rect(Rect2(708 + pane * 51 - row * 0.75, RoomLayout.FLOOR_Y + 12 + row, 39, 3), Color(1.0, 0.92, 0.65, 0.24))
	_draw_wall_panels()
	_draw_kitchen_corner()
	_draw_lamp(Vector2(870, 270))
	_draw_music_corner()
	_draw_sleep_corner()
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

func _draw_floor() -> void:
	# The reference is a perspective illustration, not a seamless floor tile.
	# Draw whole planks on the art grid so its diagonal cuts cannot repeat.
	var wood := [Color("d7a365"), Color("dba86b"), Color("d5a064"), Color("d9a66a"), Color("d4a066")]
	var floor_bounds := Rect2(0, RoomLayout.FLOOR_Y, area.x, area.y - RoomLayout.FLOOR_Y)
	draw_rect(floor_bounds, wood[0])
	# A private seed keeps the room stable across redraws without changing gameplay RNG.
	var grain := RandomNumberGenerator.new()
	grain.seed = 72419
	var plank_height := 24.0
	var y := ceilf((RoomLayout.FLOOR_Y + 12) / PIXEL) * PIXEL
	while y < area.y:
		var x := -float(grain.randi_range(12, 72)) * PIXEL
		while x < area.x:
			var width := float(grain.randi_range(48, 88)) * PIXEL
			var color: Color = wood[grain.randi_range(0, wood.size() - 1)]
			_pixel_rect(Rect2(x, y, width, plank_height).intersection(floor_bounds), color)
			_pixel_rect(Rect2(x, y, width, PIXEL).intersection(floor_bounds), color.lightened(0.10))
			_pixel_rect(Rect2(x, y + plank_height - PIXEL, width, PIXEL).intersection(floor_bounds), Color("b88b55"))
			if x >= 0:
				_pixel_rect(Rect2(x, y + PIXEL, PIXEL, plank_height - PIXEL * 2).intersection(floor_bounds), Color("bd9059"))
			# Sparse, horizontal grain; no diagonal wedges or repeated image boundaries.
			for line in 2:
				var length := float(grain.randi_range(6, 22)) * PIXEL
				var offset := float(grain.randi_range(4, int((width - length) / PIXEL) - 4)) * PIXEL
				var mark := Rect2(x + offset, y + (6 if line == 0 else 15), length, PIXEL)
				if mark.intersects(floor_bounds):
					_pixel_rect(mark.intersection(floor_bounds), color.lightened(0.045) if line == 0 else color.darkened(0.035))
			x += width
		y += plank_height

func _draw_window() -> void:
	# Replace the baked curtain/window locally with art on the room's actual pixel grid.
	# A clean column at the same source height preserves the two-tone wall behind it.
	draw_texture_rect_region(ROOM_BACKGROUND, Rect2(654, 66, 174, 174), Rect2(1080, 351, 1, 435))
	_pixel_arch(Rect2(678, 93, 138, 141), Color(0.37, 0.31, 0.20, 0.16))
	_pixel_arch(Rect2(672, 87, 138, 141), Color("795336"))
	_pixel_arch(Rect2(675, 90, 132, 135), Color("bd8b55"))
	_pixel_arch(Rect2(681, 96, 120, 126), Color("e0b47a"))
	_pixel_arch(Rect2(684, 99, 114, 120), Color("9fc6b5"))
	# Quiet sky and garden, with the same clear central cross as the original window.
	_pixel_rect(Rect2(711, 123, 12, 6), Color("edf0d1"))
	_pixel_rect(Rect2(705, 129, 30, 6), Color("edf0d1"))
	_pixel_rect(Rect2(702, 135, 36, 3), Color("edf0d1"))
	_pixel_rect(Rect2(768, 144, 12, 6), Color("edf0d1"))
	_pixel_rect(Rect2(762, 150, 30, 6), Color("edf0d1"))
	_pixel_rect(Rect2(684, 195, 114, 24), Color("aabd79"))
	for bush in [Vector2(696, 192), Vector2(711, 183), Vector2(726, 195), Vector2(765, 192), Vector2(783, 183)]:
		_pixel_ellipse(bush, Vector2(12, 15), Color("7f9d68"))
		_pixel_rect(Rect2(bush + Vector2(-9, 0), Vector2(21, 18)), Color("7f9d68"))
	_pixel_rect(Rect2(684, 207, 114, 12), Color("b6c77d"))
	_pixel_rect(Rect2(735, 102, 9, 120), Color("936642"))
	_pixel_rect(Rect2(735, 102, 3, 117), Color("c89a61"))
	_pixel_rect(Rect2(684, 159, 114, 9), Color("936642"))
	_pixel_rect(Rect2(684, 159, 114, 3), Color("c89a61"))
	_pixel_rect(Rect2(669, 219, 144, 9), Color("97653e"))
	_pixel_rect(Rect2(663, 225, 156, 9), Color("805733"))
	_pixel_rect(Rect2(666, 225, 150, 3), Color("e1b277"))
	_pixel_rect(Rect2(669, 228, 144, 3), Color("c4925b"))
	# Both panels hang from rings; the curved folds gather at sage tiebacks.
	_pixel_rect(Rect2(654, 75, 174, 6), Color("815c3c"))
	_pixel_rect(Rect2(654, 75, 174, 3), Color("c39863"))
	for x in [651, 831]:
		_pixel_ellipse(Vector2(x, 78), Vector2(6, 6), Color("986d45"))
		_pixel_rect(Rect2(x - 3, 75, 3, 3), Color("d1a971"))
	_draw_curtain(Vector2(660, 84), 1)
	_draw_curtain(Vector2(822, 84), -1)

func _draw_curtain(top: Vector2, direction: int) -> void:
	# All coordinates are local; mirroring keeps the gathered panels balanced.
	var silhouette := PackedVector2Array([
		Vector2(0, 0), Vector2(54, 0), Vector2(54, 9), Vector2(48, 33),
		Vector2(39, 54), Vector2(27, 75), Vector2(24, 84), Vector2(30, 108),
		Vector2(36, 138), Vector2(30, 144), Vector2(21, 141), Vector2(12, 147),
		Vector2(0, 144), Vector2(-3, 138), Vector2(3, 108), Vector2(9, 84),
		Vector2(6, 63), Vector2(0, 30)])
	_curtain_polygon(top, direction, silhouette, Color("c2b898"))
	_curtain_polygon(top, direction, PackedVector2Array([
		Vector2(3, 3), Vector2(51, 3), Vector2(48, 21), Vector2(42, 39),
		Vector2(33, 60), Vector2(21, 81), Vector2(24, 99), Vector2(30, 126),
		Vector2(33, 138), Vector2(24, 138), Vector2(15, 144), Vector2(3, 141),
		Vector2(0, 135), Vector2(6, 105), Vector2(12, 84), Vector2(9, 60),
		Vector2(3, 27)]), Color("f7f2db"))
	# Broad tapered folds read as fabric, instead of a jagged diagonal stripe.
	_curtain_polygon(top, direction, PackedVector2Array([
		Vector2(12, 3), Vector2(18, 3), Vector2(18, 27), Vector2(21, 48),
		Vector2(18, 75), Vector2(15, 75), Vector2(15, 51), Vector2(12, 27)]), Color("dfd5b5"))
	_curtain_polygon(top, direction, PackedVector2Array([
		Vector2(33, 3), Vector2(39, 3), Vector2(36, 27), Vector2(30, 48),
		Vector2(21, 72), Vector2(21, 54), Vector2(27, 27)]), Color("dfd5b5"))
	_curtain_polygon(top, direction, PackedVector2Array([
		Vector2(21, 3), Vector2(30, 3), Vector2(27, 30), Vector2(21, 51),
		Vector2(18, 60), Vector2(21, 27)]), Color("fffbee"))
	_curtain_polygon(top, direction, PackedVector2Array([
		Vector2(15, 93), Vector2(18, 93), Vector2(15, 114), Vector2(12, 141),
		Vector2(6, 138), Vector2(12, 111)]), Color("dfd5b5"))
	_curtain_polygon(top, direction, PackedVector2Array([
		Vector2(21, 96), Vector2(24, 105), Vector2(30, 135), Vector2(24, 138),
		Vector2(21, 117)]), Color("e5dcc0"))
	for x in [6, 21, 36, 48]:
		_pixel_rect(Rect2(top + Vector2(x * direction - 3, -9), Vector2(3, 12)), Color("b79d70"))
		_pixel_rect(Rect2(top + Vector2(x * direction, -6), Vector2(3, 6)), Color("eee0b7"))
	var tie_x := top.x + (6 if direction > 0 else -27)
	_pixel_rect(Rect2(tie_x, top.y + 81, 24, 9), Color("7b9068"))
	_pixel_rect(Rect2(tie_x, top.y + 81, 21, 3), Color("abb68a"))
	_pixel_rect(Rect2(top + Vector2(27 * direction, 87), Vector2(6, 6)), Color("637b55"))
	_pixel_rect(Rect2(top + Vector2(30 * direction, 93), Vector2(3, 12)), Color("7b9068"))

func _curtain_polygon(origin: Vector2, direction: int, points: PackedVector2Array, color: Color) -> void:
	var vertices := PackedVector2Array()
	for point in points:
		vertices.append(((origin + Vector2(point.x * direction, point.y)) / PIXEL).round() * PIXEL)
	draw_colored_polygon(vertices, color)

func _pixel_arch(rect: Rect2, color: Color) -> void:
	var radius := rect.size.x * 0.5
	var center := rect.position + Vector2(radius, radius)
	for y in range(int(rect.position.y), int(center.y), int(PIXEL)):
		var distance := center.y - (y + PIXEL * 0.5)
		var half_width := sqrt(maxf(0, radius * radius - distance * distance))
		_pixel_rect(Rect2(center.x - half_width, y, half_width * 2, PIXEL), color)
	_pixel_rect(Rect2(rect.position.x, center.y, rect.size.x, rect.end.y - center.y), color)

func _draw_wall_panels() -> void:
	# Decor stays on the back wall, behind the walkable strip and all care props.
	for span in [Vector2(0, 399), Vector2(903, 1440)]:
		_pixel_rect(Rect2(span.x, 207, span.y - span.x, 51), Color("c7cba6"))
		_pixel_rect(Rect2(span.x, 201, span.y - span.x, 6), Color("a7af88"))
		_pixel_rect(Rect2(span.x, 201, span.y - span.x, 3), Color("e3e1bd"))
		for x in range(int(span.x) + 18, int(span.y), 72):
			_pixel_rect(Rect2(x, 210, 3, 48), Color("b4bd97"))
			_pixel_rect(Rect2(x + 3, 210, 3, 48), Color("d6d8b3"))

func _draw_kitchen_corner() -> void:
	# The feeding corner follows the sage-cabinet mockup. Everything here is
	# static scenery; the bowls remain a separate station node above the floor.
	_pixel_rect(Rect2(390, 57, 258, 201), Color("f0eed8"))
	_pixel_rect(Rect2(390, 183, 258, 75), Color("dce2c6"))
	_pixel_rect(Rect2(390, 57, 6, 201), Color("c8bb97"))
	_pixel_rect(Rect2(642, 57, 6, 201), Color("c8bb97"))
	# Cream backsplash and green tile joints.
	_pixel_rect(Rect2(399, 150, 171, 72), Color("f8f0da"))
	for y in range(150, 223, 12):
		_pixel_rect(Rect2(399, y, 171, 3), Color("ddd5b6"))
	for x in range(399, 571, 12):
		_pixel_rect(Rect2(x, 150, 3, 72), Color("ddd5b6"))
	# Small arched kitchen window, separate from the room's main window.
	_pixel_arch(Rect2(417, 81, 72, 84), Color("805733"))
	_pixel_arch(Rect2(423, 87, 60, 72), Color("a5c9b8"))
	_pixel_rect(Rect2(423, 135, 60, 24), Color("a9bc7a"))
	for x in [432, 456, 474]:
		_pixel_ellipse(Vector2(x, 138), Vector2(12, 12), Color("789565"))
	_pixel_rect(Rect2(450, 90, 6, 69), Color("926545"))
	_pixel_rect(Rect2(423, 126, 60, 6), Color("926545"))
	_pixel_rect(Rect2(414, 159, 81, 6), Color("bd8b55"))
	_pixel_rect(Rect2(414, 162, 81, 3), Color("e6ba7e"))
	# A narrow pendant lamp leaves the central window and sink readable.
	_pixel_rect(Rect2(534, 57, 3, 39), Color("866744"))
	_pixel_rect(Rect2(519, 93, 33, 6), Color("58764f"))
	_pixel_rect(Rect2(513, 99, 45, 9), Color("799567"))
	_pixel_rect(Rect2(522, 108, 27, 3), Color("e4bd78"))
	# Continuous wooden worktop and sink.
	_pixel_rect(Rect2(399, 210, 174, 12), Color("795638"))
	_pixel_rect(Rect2(399, 210, 174, 6), Color("d9aa70"))
	_pixel_rect(Rect2(426, 207, 60, 6), Color("e9d4ad"))
	_pixel_rect(Rect2(432, 210, 48, 6), Color("9ca6a0"))
	_pixel_rect(Rect2(438, 213, 36, 3), Color("d3d8c8"))
	_pixel_rect(Rect2(450, 186, 6, 24), Color("846f58"))
	_pixel_rect(Rect2(453, 183, 15, 6), Color("846f58"))
	_pixel_rect(Rect2(465, 186, 3, 6), Color("846f58"))
	# Cabinet doors and drawers use the room's three-unit pixel grid.
	_pixel_rect(Rect2(405, 222, 165, 42), Color("52694c"))
	_pixel_rect(Rect2(411, 225, 153, 33), Color("a1b487"))
	for x in [414, 462, 510]:
		_pixel_rect(Rect2(x, 228, 42, 27), Color("6e8d67"))
		_pixel_rect(Rect2(x + 3, 231, 36, 21), Color("b5c69a"))
		_pixel_rect(Rect2(x + 33, 240, 3, 6), Color("9e754e"))
	_pixel_rect(Rect2(405, 258, 165, 6), Color("51694d"))
	# Open pantry, with food jars above the puppy's reach.
	_pixel_rect(Rect2(579, 108, 60, 153), Color("735337"))
	_pixel_rect(Rect2(585, 114, 48, 138), Color("d5aa71"))
	for y in [150, 192, 231]:
		_pixel_rect(Rect2(585, y, 48, 6), Color("78583b"))
	for x in [591, 612]:
		for y in [123, 165]:
			_pixel_rect(Rect2(x, y, 15, 21), Color("f5e7c5"))
			_pixel_rect(Rect2(x + 3, y + 6, 9, 12), Color("bd955e" if x == 591 else "8b9a65"))
			_pixel_rect(Rect2(x, y - 3, 15, 3), Color("8f714c"))
	_pixel_rect(Rect2(594, 204, 33, 24), Color("af8455"))
	_pixel_rect(Rect2(597, 207, 27, 18), Color("d6b481"))
	_pixel_rect(Rect2(588, 255, 42, 6), Color("5b6f52"))

func _draw_lamp(base: Vector2) -> void:
	# Stepped translucent pools keep the warm light on the same pixel grid as the room.
	_pixel_ellipse(base + Vector2(0, -102), Vector2(69, 87), Color(1.0, 0.90, 0.59, 0.09))
	_pixel_ellipse(base + Vector2(0, -102), Vector2(51, 66), Color(1.0, 0.91, 0.62, 0.12))
	_pixel_ellipse(base + Vector2(0, 3), Vector2(63, 15), Color(1.0, 0.91, 0.64, 0.24))
	_pixel_ellipse(base + Vector2(3, 0), Vector2(30, 6), Color("ac9369"))
	_pixel_ellipse(base + Vector2(0, -3), Vector2(24, 6), Color("665a43"))
	_pixel_ellipse(base + Vector2(-3, -6), Vector2(18, 3), Color("b39860"))
	_pixel_rect(Rect2(base + Vector2(-3, -108), Vector2(6, 102)), Color("796647"))
	_pixel_rect(Rect2(base + Vector2(-3, -108), Vector2(3, 99)), Color("cbb579"))
	_pixel_rect(Rect2(base + Vector2(-3, -147), Vector2(6, 12)), Color("8a714b"))
	for row in range(0, 39, 3):
		var half_width := 24 + floori(row / 9.0) * 3
		_pixel_rect(Rect2(base + Vector2(-half_width, -138 + row), Vector2(half_width * 2, 3)), Color("99754b"))
		_pixel_rect(Rect2(base + Vector2(-half_width + 3, -138 + row), Vector2(half_width * 2 - 6, 3)), Color("f3d69a"))
		_pixel_rect(Rect2(base + Vector2(-12, -138 + row), Vector2(21, 3)), Color("fff0be"))
	_pixel_rect(Rect2(base + Vector2(-36, -102), Vector2(72, 6)), Color("bf985e"))
	_pixel_rect(Rect2(base + Vector2(-30, -99), Vector2(60, 3)), Color("ffe9a8"))
	_pixel_rect(Rect2(base + Vector2(21, -96), Vector2(3, 21)), Color("9a7d50"))
	_pixel_ellipse(base + Vector2(21, -72), Vector2(3, 3), Color("bf985e"))

func _draw_music_corner() -> void:
	# Low oak cabinet, a record player and a few books make a lived-in music corner.
	_pixel_ellipse(Vector2(1002, 270), Vector2(78, 9), Color("b79364"))
	for x in [942, 1050]:
		_pixel_rect(Rect2(x, 246, 9, 24), Color("75543a"))
	_pixel_rect(Rect2(933, 198, 135, 57), Color("78583b"))
	_pixel_rect(Rect2(939, 204, 123, 45), Color("b88c57"))
	_pixel_rect(Rect2(945, 210, 51, 33), Color("d2a66c"))
	_pixel_rect(Rect2(1002, 210, 54, 33), Color("967048"))
	for i in 5:
		var x := 1008 + i * 9
		_pixel_rect(Rect2(x, 216 + (i % 2) * 3, 6, 27 - (i % 2) * 3), [Color("8fa18a"), Color("d9bd83"), Color("b77556"), Color("e9d6a6"), Color("677f78")][i])
		_pixel_rect(Rect2(x, 222, 6, 3), Color("eddbb3"))
	_pixel_rect(Rect2(963, 222, 12, 3), Color("805e3f"))
	_pixel_rect(Rect2(927, 192, 147, 9), Color("805733"))
	_pixel_rect(Rect2(927, 192, 147, 3), Color("e0b77a"))
	# Open turntable lid, platter and tonearm.
	_pixel_rect(Rect2(942, 165, 78, 21), Color("7b5e46"))
	_pixel_rect(Rect2(948, 168, 66, 15), Color("a7815a"))
	_pixel_rect(Rect2(939, 180, 84, 12), Color("614f3e"))
	_pixel_rect(Rect2(942, 180, 78, 6), Color("c49b68"))
	_pixel_ellipse(Vector2(972, 180), Vector2(24, 6), Color("43524a"))
	_pixel_ellipse(Vector2(972, 180), Vector2(6, 3), Color("ce9e69"))
	_pixel_rect(Rect2(1008, 174, 3, 9), Color("e1c894"))
	_pixel_rect(Rect2(996, 180, 15, 3), Color("e1c894"))
	_draw_planter(Vector2(1047, 192), 0.6)
	# A short display shelf above the cabinet, with one record sleeve and trailing ivy.
	_pixel_rect(Rect2(930, 135, 186, 9), Color("805733"))
	_pixel_rect(Rect2(930, 135, 186, 3), Color("d9b17a"))
	for x in [945, 1095]:
		_pixel_rect(Rect2(x, 144, 6, 12), Color("9e7b52"))
	_pixel_rect(Rect2(948, 84, 45, 51), Color("687f77"))
	_pixel_rect(Rect2(951, 87, 39, 45), Color("adc0a5"))
	_pixel_ellipse(Vector2(972, 108), Vector2(15, 15), Color("53685f"))
	_pixel_ellipse(Vector2(972, 108), Vector2(6, 6), Color("e3c48b"))
	for i in 4:
		_pixel_rect(Rect2(1005 + i * 12, 99 - (i % 2) * 6, 9, 36 + (i % 2) * 6), [Color("bd835e"), Color("d4ba87"), Color("7e9380"), Color("a8af91")][i])
		_pixel_rect(Rect2(1005 + i * 12, 123, 9, 3), Color("ecd9ac"))
	_draw_planter(Vector2(1092, 135), 0.6)
	_draw_trailing_vine(Vector2(1104, 123), 57)
	_draw_guitar(Vector2(1182, 267))

func _draw_guitar(base: Vector2) -> void:
	_pixel_ellipse(base + Vector2(3, 3), Vector2(42, 9), Color("ae9266"))
	# Authored scanlines give an acoustic body two distinct bouts and a narrow waist.
	var half_widths := [9, 15, 21, 27, 30, 30, 30, 30, 27, 24, 21, 21, 21, 24, 27,
		30, 33, 36, 39, 39, 39, 39, 39, 36, 33, 30, 27, 21, 15, 9]
	for row in half_widths.size():
		var half: float = half_widths[row]
		var y := -90 + row * 3
		_pixel_rect(Rect2(base + Vector2(-half, y), Vector2(half * 2, 3)), Color("684731"))
		_pixel_rect(Rect2(base + Vector2(-half + 3, y), Vector2(half * 2 - 6, 3)), Color("f1cd8b"))
		if row > 1 and row < half_widths.size() - 2:
			_pixel_rect(Rect2(base + Vector2(-half + 6, y), Vector2(half * 2 - 12, 3)), Color("dfa15d"))
			_pixel_rect(Rect2(base + Vector2(-half + 6, y), Vector2(3, 3)), Color("edbb76"))
			_pixel_rect(Rect2(base + Vector2(half - 9, y), Vector2(3, 3)), Color("c08447"))
	# Straight dark fingerboard, with frets across it rather than a zigzag neck.
	_pixel_rect(Rect2(base + Vector2(-6, -135), Vector2(12, 66)), Color("624733"))
	_pixel_rect(Rect2(base + Vector2(-3, -132), Vector2(6, 60)), Color("846044"))
	for y in [-123, -114, -105, -96, -87, -78]:
		_pixel_rect(Rect2(base + Vector2(-3, y), Vector2(6, 3)), Color("c9ae7c"))
	# Tapered headstock and three separate tuning keys on each side.
	_pixel_rect(Rect2(base + Vector2(-9, -156), Vector2(18, 24)), Color("624733"))
	_pixel_rect(Rect2(base + Vector2(-6, -153), Vector2(12, 21)), Color("a67547"))
	_pixel_rect(Rect2(base + Vector2(-6, -132), Vector2(12, 3)), Color("eddbab"))
	for y in [-153, -144, -135]:
		for side in [-1, 1]:
			_pixel_rect(Rect2(base + Vector2(-15 if side < 0 else 9, y + 3), Vector2(6, 3)), Color("8e8b70"))
			_pixel_rect(Rect2(base + Vector2(-21 if side < 0 else 15, y), Vector2(6, 6)), Color("676e62"))
			_pixel_rect(Rect2(base + Vector2(-21 if side < 0 else 15, y), Vector2(6, 3)), Color("cbd0b5"))
		_pixel_rect(Rect2(base + Vector2(-3, y + 3), Vector2(6, 3)), Color("664831"))
	# Rosette, dark soundhole and tortoiseshell pickguard stay legible at native size.
	_pixel_ellipse(base + Vector2(0, -57), Vector2(15, 15), Color("805238"))
	_pixel_ellipse(base + Vector2(0, -57), Vector2(12, 12), Color("f4d89f"))
	_pixel_ellipse(base + Vector2(0, -57), Vector2(9, 9), Color("433b2d"))
	_pixel_rect(Rect2(base + Vector2(12, -51), Vector2(6, 15)), Color("98613d"))
	_pixel_rect(Rect2(base + Vector2(9, -39), Vector2(6, 6)), Color("98613d"))
	_pixel_rect(Rect2(base + Vector2(-15, -24), Vector2(30, 9)), Color("624733"))
	_pixel_rect(Rect2(base + Vector2(-9, -24), Vector2(18, 3)), Color("f0dfae"))
	for x in [-3, 3]:
		_pixel_rect(Rect2(base + Vector2(x, -129), Vector2(3, 105)), Color(0.98, 0.90, 0.72, 0.32))
	# A low stand supports the lower bout without obscuring its outline.
	for x in [-24, 18]:
		_pixel_rect(Rect2(base + Vector2(x, -9), Vector2(6, 12)), Color("58634e"))

func _draw_sleep_corner() -> void:
	_draw_planter(Vector2(66, 270), 1.5)
	_pixel_ellipse(Vector2(357, 270), Vector2(66, 9), Color("b79364"))
	_pixel_rect(Rect2(309, 225, 99, 42), Color("896442"))
	_pixel_rect(Rect2(315, 231, 87, 30), Color("c49a62"))
	for y in [237, 249]:
		_pixel_rect(Rect2(315, y, 87, 3), Color("ad814e"))
	_pixel_rect(Rect2(303, 219, 111, 12), Color("a7794d"))
	_pixel_rect(Rect2(306, 219, 105, 3), Color("dfb77b"))
	_pixel_rect(Rect2(324, 216, 45, 30), Color("799088"))
	_pixel_rect(Rect2(327, 216, 6, 30), Color("abc0ab"))
	_pixel_rect(Rect2(357, 216, 6, 30), Color("abc0ab"))
	for y in [222, 237]:
		_pixel_rect(Rect2(324, y, 45, 3), Color("c7d0b3"))
	for x in range(327, 369, 9):
		_pixel_rect(Rect2(x, 246, 3, 6), Color("ded8b2"))
	# Suspended planter fills the gap between the reading shelf and feeding area.
	_pixel_rect(Rect2(390, 48, 3, 36), Color("af9468"))
	for row in range(0, 24, 3):
		_pixel_rect(Rect2(390 - row * 0.5, 81 + row, 3, 3), Color("af9468"))
		_pixel_rect(Rect2(390 + row * 0.5, 81 + row, 3, 3), Color("af9468"))
	_draw_planter(Vector2(390, 120), 0.8)
	_draw_trailing_vine(Vector2(399, 102), 63)

func _draw_planter(base: Vector2, prop_scale: float) -> void:
	# Scaled offsets still snap to the room grid in the pixel drawing helpers.
	var dark := Color("60784f")
	var green := Color("88a46a")
	_pixel_rect(Rect2(base + Vector2(-3, -57) * prop_scale, Vector2(6, 39) * prop_scale), dark)
	for leaf in [Vector2(-15, -48), Vector2(12, -60), Vector2(15, -36), Vector2(-12, -30)]:
		_pixel_ellipse(base + leaf * prop_scale, Vector2(15, 9) * prop_scale, dark)
		_pixel_ellipse(base + (leaf + Vector2(0, -3)) * prop_scale, Vector2(12, 6) * prop_scale, green)
	_pixel_rect(Rect2(base + Vector2(-18, -24) * prop_scale, Vector2(36, 24) * prop_scale), Color("956242"))
	_pixel_rect(Rect2(base + Vector2(-12, -18) * prop_scale, Vector2(27, 18) * prop_scale), Color("c68e5e"))
	_pixel_rect(Rect2(base + Vector2(-21, -27) * prop_scale, Vector2(42, 6) * prop_scale), Color("dfae76"))
	_pixel_rect(Rect2(base + Vector2(-9, -15) * prop_scale, Vector2(6, 12) * prop_scale), Color("dba46f"))

func _draw_trailing_vine(start: Vector2, length: int) -> void:
	for row in range(0, length, 3):
		var bend := roundf(sin(float(row) / 18.0) * 2) * 3
		_pixel_rect(Rect2(start + Vector2(bend, row), Vector2(3, 6)), Color("74885b"))
		if row % 12 == 0:
			var side := -1 if row % 24 == 0 else 1
			_pixel_ellipse(start + Vector2(bend + side * 6, row + 3), Vector2(9, 6), Color("8fa774"))

func _draw_bed() -> void:
	var center := Vector2(0, -20)
	_pixel_ellipse(center + Vector2(0, 6), Vector2(93, 31), Color("b79364"))
	_pixel_ellipse(center, Vector2(88, 34), Color("536a4f"))
	_pixel_ellipse(center - Vector2(0, 3), Vector2(81, 29), Color("7d9970"))
	_pixel_ellipse(center - Vector2(0, 3), Vector2(65, 22), Color("526d50"))
	_pixel_ellipse(center - Vector2(0, 1), Vector2(59, 18), Color("e4d9a7"))
	_pixel_rect(Rect2(-63, -6, 18, 3), Color("a2b287"))

func _draw_bowl() -> void:
	# Keep the food bowl at the current feeding target; the water bowl has its own HomeDrink target.
	draw_set_transform(Vector2(24, 0))
	_pixel_ellipse(Vector2(0, -6), Vector2(60, 17), Color("7b9068"))
	_pixel_ellipse(Vector2(0, -9), Vector2(54, 12), Color("f4e9c9"))
	for center in [Vector2(-24, -18), Vector2(27, -18)]:
		_pixel_rect(Rect2(center + Vector2(-18, 0), Vector2(36, 15)), Color("9b704e"))
		_pixel_rect(Rect2(center + Vector2(-15, 3), Vector2(30, 9)), Color("f1dfbd"))
		_pixel_ellipse(center, Vector2(21, 9), Color("805733"))
		_pixel_ellipse(center - Vector2(0, 3), Vector2(18, 6), Color("f8edcf"))
	_pixel_ellipse(Vector2(-24, -22), Vector2(13, 4), Color("856243"))
	for i in 5:
		_pixel_rect(Rect2(-36 + i * 6, -25 + (i % 2) * 3, 3, 3), Color("bd8b55"))
	_pixel_ellipse(Vector2(27, -22), Vector2(13, 4), Color("82bac2"))
	_pixel_rect(Rect2(18, -24, 6, 3), Color("d8f0e5"))
	draw_set_transform(Vector2.ZERO)

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
	if portal_open:
		_pixel_rect(Rect2(-60, -186, 120, 186), Color("6c563a"))
		_pixel_rect(Rect2(-51, -177, 102, 177), Color("9bbd88"))
		_pixel_rect(Rect2(-51, -177, 24, 177), Color("b2844f"))
		_pixel_rect(Rect2(-63, 0, 126, 6), Color("805733"))
		return
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
	if not ball_held: _pixel_ellipse(ball + Vector2(0, 13), Vector2(15, 5), Color("b79364"))
	_pixel_ellipse(ball, Vector2(14, 14), Color("457d1c"))
	_pixel_ellipse(ball - Vector2(0, 1), Vector2(11, 11), Color("bded12"))
	_pixel_rect(Rect2(ball + Vector2(roundf(sin(roll_phase) * 2) * 3 - 3, -9), Vector2(6, 3)), Color("f7fff0"))
	_pixel_rect(Rect2(ball + Vector2(roundf(sin(roll_phase) * 2) * 3 - 6, -6), Vector2(3, 12)), Color("f7fff0"))

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

func _draw_yard() -> void:
	if area.x <= 0: return
	# The 3:1 source is cropped to the 4:1 playable world. Its fence and
	# grass line then meet the existing stations at y=190 and y=265.
	draw_rect(Rect2(0, -2400, area.x, 2400), Color("acd7dd"))
	draw_texture_rect_region(YARD_BACKGROUND, Rect2(0, 0, area.x, RoomLayout.SIZE.y), Rect2(0, 30, 2172, 543))
	# Portrait screens can reveal ground below the panorama. Repeat a lawn-only
	# strip from the same painting, without stretching a single scanline.
	for y in range(int(RoomLayout.SIZE.y), int(area.y), 105):
		var height := minf(105, area.y - y)
		draw_texture_rect_region(YARD_BACKGROUND, Rect2(0, y, area.x, height), Rect2(0, 480, 2172, height * 1.5))

func _draw_yard_garden() -> void:
	# Raised wooden bed. Growth remains live and comes from the saved garden state.
	if not yard_overlay_only:
		_pixel_rect(Rect2(480, 278, 144, 48), Color("715238"))
		_pixel_rect(Rect2(486, 272, 132, 42), Color("bd9160"))
		_pixel_rect(Rect2(492, 269, 120, 30), Color("6e533a"))
		_pixel_rect(Rect2(498, 275, 108, 21), Color("806444"))
		for x in [489, 612]:
			_pixel_rect(Rect2(x, 278, 6, 45), Color("e2b779"))
			_pixel_rect(Rect2(x + 6, 305, 6, 9), Color("9c7047"))
		for x in range(498, 609, 18):
			_pixel_rect(Rect2(x, 302, 12, 3), Color("d9ab72"))
	if not garden_state.is_empty() and garden_state.plant != "":
		var view := garden_state.duplicate(true)
		YardRoutines.update(view, Time.get_unix_time_from_system())
		var height := 9 + 36 * float(view.growth) / YardRoutines.GROW_TIME
		for x in [510, 550, 590]:
			_pixel_rect(Rect2(x, 294 - height, 6, height), Color("567d4b"))
			_pixel_rect(Rect2(x - 9, 280, 12, 6), Color("91ac67"))
			if view.growth >= YardRoutines.GROW_TIME:
				_pixel_ellipse(Vector2(x + 3, 294 - height), Vector2(12, 9), {"daisy": Color("fff3d5"), "poppy": Color("d97c68"), "lavender": Color("aa8cbd")}[view.plant])
				_pixel_rect(Rect2(x, 291 - height, 6, 6), Color("dfb750"))

func _draw_yard_dig() -> void:
	_pixel_ellipse(Vector2(669, 317), Vector2(65, 15), Color("6d7650"))
	_pixel_ellipse(Vector2(669, 310), Vector2(59, 18), Color("c5a676"))
	_pixel_ellipse(Vector2(669, 305), Vector2(48, 12), Color("dec492"))
	for point in [Vector2(629, 299), Vector2(692, 308), Vector2(707, 296)]:
		_pixel_rect(Rect2(point, Vector2(6, 3)), Color("f0d8a6"))

func _draw_yard_gate() -> void:
	# A separate gate opens without changing the baked fence.
	_pixel_rect(Rect2(99, 185, 99, 93), Color("765b42"))
	_pixel_rect(Rect2(105, 188, 87, 84), Color("b68a5b"))
	if portal_open:
		_pixel_rect(Rect2(120, 191, 69, 75), Color("6e8867"))
		_pixel_rect(Rect2(108, 188, 15, 84), Color("d5aa73"))
	else:
		for x in range(108, 190, 15):
			_pixel_rect(Rect2(x, 188, 12, 81), Color("dfb77d"))
			_pixel_rect(Rect2(x, 188, 3, 81), Color("f4d8a6"))
		_pixel_rect(Rect2(108, 215, 81, 6), Color("a4774e"))
		_pixel_rect(Rect2(108, 248, 81, 6), Color("a4774e"))
		_pixel_rect(Rect2(177, 233, 9, 6), Color("65533c"))
	_pixel_rect(Rect2(96, 269, 105, 6), Color("654f3e"))

func _draw_yard_fetch() -> void:
	_pixel_ellipse(Vector2(940, 310), Vector2(120, 24), Color("9ab76e"))
	_pixel_ellipse(Vector2(940, 308), Vector2(111, 18), Color("b8ca7f"))
	for x in [838, 1042]:
		_pixel_rect(Rect2(x, 263, 6, 48), Color("eed7a1"))
		_pixel_rect(Rect2(x + 6, 263, 24, 15), Color("d88363"))
		_pixel_rect(Rect2(x + 12, 278, 12, 6), Color("ae684e"))
		_pixel_rect(Rect2(x - 3, 308, 12, 6), Color("a88655"))

func _draw_yard_bush(x: int) -> void:
	_pixel_ellipse(Vector2(x, 280), Vector2(78, 18), Color("577e4e"))
	_pixel_ellipse(Vector2(x - 27, 254), Vector2(42, 32), Color("769a5d"))
	_pixel_ellipse(Vector2(x + 20, 248), Vector2(48, 39), Color("85a965"))
	_pixel_ellipse(Vector2(x - 6, 238), Vector2(41, 29), Color("99b574"))
	for offset in [-36, -12, 18, 42]:
		_pixel_rect(Rect2(x + offset, 251 + (offset % 3) * 6, 9, 6), Color("a9be7c"))
	_pixel_rect(Rect2(x - 6, 288, 12, 6), Color("caaf75"))

func _draw_yard_outing() -> void:
	_pixel_rect(Rect2(1290, 255, 9, 45), Color("8e6848"))
	_pixel_rect(Rect2(1272, 249, 48, 24), Color("9b714c"))
	_pixel_rect(Rect2(1275, 252, 42, 18), Color("e7d09d"))
	_pixel_rect(Rect2(1281, 258, 24, 3), Color("6b805c"))
	_pixel_rect(Rect2(1299, 255, 12, 3), Color("6b805c"))
	_pixel_rect(Rect2(1287, 294, 15, 6), Color("6a7650"))

func _draw_decor() -> void:
	if decor.has("heart"):
		_pixel_rect(Rect2(410, 120, 72, 72), Color("795646"))
		_pixel_rect(Rect2(416, 126, 60, 60), Color("f6e6c8"))
		var rows := ["0110110", "1111111", "1111111", "0111110", "0011100", "0001000"]
		for y in rows.size():
			for x in rows[y].length():
				if rows[y][x] == "1": _pixel_rect(Rect2(425 + x * 6, 138 + y * 6, 6, 6), Color("c87879"))
	for i in YardRoutines.PLANTS.size():
		var flower: String = YardRoutines.PLANTS.keys()[i]
		if not decor.has(flower): continue
		var x := 540 + i * 120
		var color: Color = {"daisy": Color("fff3d5"), "poppy": Color("d97c68"), "lavender": Color("aa8cbd")}[flower]
		_pixel_rect(Rect2(x, 215, 36, 42), Color("bd8b69"))
		_pixel_rect(Rect2(x - 3, 212, 42, 9), Color("d8ad87"))
		for offset in [6, 18, 30]:
			_pixel_rect(Rect2(x + offset, 170, 3, 42), Color("63905a"))
			if flower == "lavender": _pixel_rect(Rect2(x + offset - 3, 155, 9, 24), color)
			else:
				_pixel_ellipse(Vector2(x + offset, 170), Vector2(9, 9), color)
				_pixel_rect(Rect2(x + offset - 3, 167, 6, 6), Color("d9b858"))
	if decor.has("cushion"):
		_pixel_ellipse(Vector2(305, 320), Vector2(45, 18), Color("c58d75"))
		_pixel_ellipse(Vector2(305, 314), Vector2(33, 10), Color("e4b99a"))
	if decor.has("flags"):
		_pixel_rect(Rect2(550, 105, 300, 3), Color("71513f"))
		for x in range(550, 851, 50):
			_pixel_rect(Rect2(x, 108, 24, 30), Color("b7c591"))
			_pixel_rect(Rect2(x + 6, 138, 12, 6), Color("8a9f72"))
	var placements := {"rug": Rect2(600, 292, 240, 72), "flower": Rect2(990, 165, 75, 129), "shelf": Rect2(910, 75, 150, 111)}
	for key in decor:
		if placements.has(key): draw_texture_rect_region(DECOR_ATLAS, placements[key], DECOR_REGIONS[key])

func _draw_hide_tail() -> void:
	# Overlapping outline segments first, then solid fur: no stripes between pixels.
	var wag := roundf(sin(roll_phase * 7) * 3) * PIXEL
	var curve := [0, 0, 3, 6, 9, 9, 6, 0]
	for layer in 2:
		for i in curve.size():
			var x := roundf((float(curve[i]) + wag * i / 7) / PIXEL) * PIXEL
			_pixel_rect(Rect2(x - (9 if layer == 0 else 6), -i * 6, 21 if layer == 0 else 15, 12 if layer == 0 else 9), Color("674831") if layer == 0 else Color("e7a75f"))
	for i in 6:
		var x := roundf((float(curve[i]) + wag * i / 7) / PIXEL) * PIXEL
		_pixel_rect(Rect2(x - 3, -i * 6, 6, 6), Color("f6ce87"))

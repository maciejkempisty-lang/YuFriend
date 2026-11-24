class_name YardWeatherView
extends Node2D

var kind := "sun"
var night := false
var animate := true
var clock := 0.0

func _process(delta: float) -> void:
	if not visible or not animate: return
	clock += delta
	queue_redraw()

func pixel(point: Vector2, extent: Vector2, tint: Color) -> void:
	draw_rect(Rect2((point / 3).round() * 3, extent), tint)

func cloud(at: Vector2, tint: Color) -> void:
	pixel(at, Vector2(96, 18), tint)
	pixel(at + Vector2(12, -12), Vector2(69, 18), tint)
	pixel(at + Vector2(33, -21), Vector2(30, 15), tint)

func _draw() -> void:
	# Weather shades the sunny base panorama without baking a second yard image.
	if kind == "rain":
		draw_rect(Rect2(0, -1000, RoomLayout.SIZE.x, 1960), Color(0.23, 0.35, 0.39, 0.24))
	elif kind == "after_rain":
		draw_rect(Rect2(0, -1000, RoomLayout.SIZE.x, 1960), Color(0.45, 0.55, 0.55, 0.08))
	if night:
		draw_rect(Rect2(0, -1000, RoomLayout.SIZE.x, 1960), Color(0.10, 0.16, 0.28, 0.42))
	var tint := Color("b1c7c8") if kind == "rain" else Color("e8eee0")
	if kind != "rain" and not night:
		var sun := Vector2(1110, 120)
		pixel(sun, Vector2(36, 36), Color("f2d98d"))
		pixel(sun + Vector2(6, -6), Vector2(24, 48), Color("f2d98d"))
		if kind == "sun":
			for i in 8:
				var point := sun + Vector2(18, 18) + Vector2.from_angle(i * TAU / 8) * 36
				pixel(point, Vector2(6, 6), Color("f2d98d"))
	for i in (5 if kind == "rain" else 3):
		cloud(Vector2(270 + i * 240 + sin(clock * 0.06 + i) * 9, 110 + (i % 2) * 27), tint)
	if kind == "rain":
		for i in 54:
			var x := 150 + fposmod(i * 97 - clock * 24, 1260)
			var y := 155 + fposmod(i * 53 + clock * 150, 210)
			pixel(Vector2(x, y), Vector2(3, 9), Color(0.72, 0.86, 0.88, 0.7))
	if kind == "after_rain" and not night:
		for i in 5:
			pixel(Vector2(474 + i * 3, 302 - i * 3), Vector2(3, 3), Color("d9ede3"))

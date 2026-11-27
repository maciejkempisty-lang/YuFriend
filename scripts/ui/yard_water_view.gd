class_name YardWaterView
extends Node2D

# Pixel-native graphics share the yard's 3-world-unit grid and palette.
var effects_only := false
var draw_ground_base := true
var show_puddle := true
var show_sprinkler := true
var wet := true
var kind := ""
var phase := ""
var pet_world := Vector2.ZERO
var clock := 0.0

func _process(delta: float) -> void:
	if not visible: return
	clock += delta
	queue_redraw()

func block(point: Vector2, extent: Vector2, color: String) -> void:
	draw_rect(Rect2((point / 3).round() * 3, extent), Color(color))

func oval(center: Vector2, radius: Vector2, color: String) -> void:
	for y in range(-int(radius.y), int(radius.y) + 1, 3):
		var width := sqrt(maxf(0, 1 - pow(float(y) / radius.y, 2))) * radius.x
		block(center + Vector2(-width, y), Vector2(maxf(3, floorf(width * 2 / 3) * 3), 3), color)

func _draw_ground() -> void:
	var puddle: Vector2 = YardWater.spots().puddle + Vector2(0, 6)
	if draw_ground_base and show_puddle:
		oval(puddle, Vector2(63, 18), "947354")
		if wet:
			oval(puddle + Vector2(-3, -3), Vector2(51, 12), "72a9af")
			block(puddle + Vector2(-30, -9), Vector2(33, 3), "badbd4")
			block(puddle + Vector2(9, 0), Vector2(24, 3), "95c4c5")
		for offset in [Vector2(-48, 9), Vector2(42, 12), Vector2(60, 3)]:
			block(puddle + offset, Vector2(9, 6), "a08057")
	var nozzle: Vector2 = YardWater.spots().sprinkler + Vector2(75, -9)
	if draw_ground_base and show_sprinkler:
		block(nozzle + Vector2(0, 18), Vector2(72, 6), "658c69")
		block(nozzle + Vector2(66, 18), Vector2(6, 36), "658c69")
		oval(nozzle + Vector2(0, 15), Vector2(18, 6), "527f79")
		block(nozzle + Vector2(-3, -9), Vector2(6, 24), "799d98")
		block(nozzle + Vector2(-12, -12), Vector2(24, 6), "e1cd91")
		block(nozzle + Vector2(-3, -18), Vector2(6, 6), "527f79")
	if kind == "sprinkler" and phase != "shake":
		for side in [-1, 1]:
			for i in 10:
				var t := fposmod(clock * 0.8 + i * 0.1, 1.0)
				var point: Vector2 = nozzle + Vector2(side * 96 * t, -18 - 260 * t + 302 * t * t)
				block(point, Vector2(3, 6), "d5eee5" if i % 2 == 0 else "83b9bf")

func _draw() -> void:
	if not effects_only:
		_draw_ground()
		return
	if phase in ["splash", "shake"]:
		for i in 12:
			var angle := i * TAU / 12
			var spread := 12 + fposmod(clock * 50 + i * 9, 48)
			var point := pet_world + Vector2(cos(angle) * spread, -25 + sin(angle) * spread * 0.5)
			block(point, Vector2(3, 6), "8d7156" if kind == "puddle" and i % 3 == 0 else "b6e3e0")

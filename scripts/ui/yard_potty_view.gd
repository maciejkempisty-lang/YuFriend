class_name YardPottyView
extends Node2D

const SPOT := Vector2(1170, 328)
var mess := false
var progress := 0.0
var cleaning := 0.0
var animate := true

func present(has_mess: bool, amount: float) -> void:
	if mess and not has_mess: cleaning = 0.8
	mess = has_mess
	progress = amount
	queue_redraw()

func _process(delta: float) -> void:
	if not animate or not visible: return
	if cleaning > 0:
		cleaning = maxf(0, cleaning - delta)
		queue_redraw()

func block(offset: Vector2, extent: Vector2, color: String) -> void:
	draw_rect(Rect2(((SPOT + offset) / 3).round() * 3, extent), Color(color))

func _draw() -> void:
	if cleaning > 0:
		var rise := (0.8 - cleaning) * 42
		block(Vector2(-18, -30 - rise), Vector2(36, 33), "547869")
		block(Vector2(-12, -39 - rise), Vector2(24, 9), "8ba78e")
		block(Vector2(-3, -45 - rise), Vector2(6, 9), "365f50")
		return
	if not mess and progress < 0.35: return
	block(Vector2(-24, 0), Vector2(48, 6), "879260")
	block(Vector2(-21, -9), Vector2(42, 12), "78513d")
	block(Vector2(-15, -12), Vector2(30, 6), "a17950")
	if mess or progress > 0.6:
		block(Vector2(-12, -21), Vector2(27, 12), "896044")
		block(Vector2(-9, -21), Vector2(15, 3), "b88c5d")
	if mess or progress > 0.85:
		block(Vector2(-3, -30), Vector2(12, 9), "896044")
		block(Vector2(0, -33), Vector2(6, 6), "a17950")

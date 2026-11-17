class_name FenceVisitorView
extends Node2D

var kind := ""
var elapsed := 0.0

func present(guest: String) -> void:
	if guest == kind: return
	kind = guest
	elapsed = 0
	visible = not kind.is_empty()
	set_process(visible)
	queue_redraw()

func _ready() -> void:
	visible = false
	set_process(false)

func _process(delta: float) -> void:
	elapsed += delta
	queue_redraw()

func block(x: float, y: float, w: float, h: float, color: String) -> void:
	draw_rect(Rect2(Vector2(x, y).round() * 3, Vector2(w, h) * 3), Color(color))

func _draw() -> void:
	var beat := sin(elapsed * 5)
	if kind == "bird":
		var hop := -2.0 if sin(elapsed * 2) > 0.92 else 0.0
		block(-3, -8 + hop, 7, 6, "527caa")
		block(2, -11 + hop, 5, 5, "6699bd")
		block(-2, -5 + hop, 5, 3, "e9d7ae")
		block(-5, -6 + hop, 3, 2, "385679")
		block(-2, -6 + hop + (1 if beat > 0 else 0), 4, 2, "385679")
		block(5, -10 + hop, 1, 1, "273c38")
		block(7, -9 + hop, 2, 1, "d8a451")
		block(-1, -2 + hop, 1, 2, "b5794e")
		block(2, -2 + hop, 1, 2, "b5794e")
	elif kind == "butterfly":
		var bob := roundf(sin(elapsed * 2) * 3) - 12
		var wing := 2 if beat > 0 else 5
		block(-wing - 1, bob - 5, wing, 5, "cf855c")
		block(1, bob - 5, wing, 5, "cf855c")
		block(-wing, bob, wing - 1, 3, "edbd72")
		block(1, bob, wing - 1, 3, "edbd72")
		block(-wing, bob - 4, 1, 2, "ffe5a6")
		block(wing - 1, bob - 4, 1, 2, "ffe5a6")
		block(-1, bob - 5, 2, 8, "6b514a")
		block(-2, bob - 7, 1, 2, "6b514a")
		block(1, bob - 7, 1, 2, "6b514a")
	elif kind == "cat":
		block(-5, -10, 9, 10, "9a9390")
		block(-5, -17, 10, 8, "b6aaa0")
		block(-5, -20, 3, 4, "9a9390")
		block(2, -20, 3, 4, "9a9390")
		block(-4, -18, 1, 2, "d7a19b")
		block(3, -18, 1, 2, "d7a19b")
		block(-3, -14, 2, 1, "465d4b")
		block(2, -14, 2, 1, "465d4b")
		block(0, -12, 1, 1, "ac736d")
		block(-2, -9, 4, 7, "e6d9c4")
		block(-5, -1, 3, 2, "e6d9c4")
		block(2, -1, 3, 2, "e6d9c4")
		block(4, -5, 5, 2, "827c7e")
		block(8, -8 + roundf(beat * 2), 2, 5, "827c7e")

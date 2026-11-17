class_name BathView
extends Control
signal finished
var bath: BathSystem
var puppy := PetAnimator.new()
var foam := Control.new()
var initial_dirt := 0.0
var tool_point := Vector2.ZERO

func _ready() -> void:
	custom_minimum_size = Vector2(250, 330)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(puppy)
	puppy.set_skin(load("res://data/skins/puppy_pixel.tres"))
	puppy.scale = Vector2.ONE * 0.7
	puppy.request_clip("idle")
	add_child(foam)
	foam.mouse_filter = Control.MOUSE_FILTER_IGNORE
	foam.draw.connect(_draw_foam)
	resized.connect(_layout)
	_layout()

func _layout() -> void:
	puppy.position = Vector2(size.x / 2, 215)
	foam.size = size
	queue_redraw()
	foam.queue_redraw()

func zone_center(index: int) -> Vector2:
	return Vector2(size.x / 2 - 55 + index * 50, 170)

func zone_at(point: Vector2) -> int:
	for i in 3:
		if point.distance_to(zone_center(i)) <= 34: return i
	return -1

func _gui_input(event: InputEvent) -> void:
	if bath == null: return
	if event is InputEventScreenTouch:
		if event.pressed: bath.press(event.position, event.index)
		else: _release(event.index, event.canceled)
	elif event is InputEventScreenDrag: _move(event.position, event.index)
	elif event is InputEventMouseButton and event.device != -1 and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed: bath.press(event.position, -1)
		else: _release(-1, false)
	elif event is InputEventMouseMotion and event.device != -1: _move(event.position, -1)
	accept_event()
	queue_redraw()
	foam.queue_redraw()

func _move(point: Vector2, id: int) -> void:
	bath.move(point, id, zone_at(point))
	tool_point = point

func _release(id: int, canceled: bool) -> void:
	if bath.release(id, canceled) and bath.stage == 3: finished.emit()

func celebrate() -> void:
	puppy.request_clip("shake")
	queue_redraw()
	foam.queue_redraw()

func _process(_delta: float) -> void:
	if puppy.sprite.material is ShaderMaterial:
		puppy.sprite.material.set_shader_parameter("dirt", initial_dirt if bath.stage == 0 else 0.0)

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("d8e8e1"))
	for x in range(0, int(size.x), 32): draw_line(Vector2(x, 40), Vector2(x, 235), Color("b1cdc6"), 2)
	for y in range(40, 235, 32): draw_line(Vector2(0, y), Vector2(size.x, y), Color("b1cdc6"), 2)
	draw_rect(Rect2(15, 207, size.x - 30, 45), Color("f6f2dc"))
	draw_rect(Rect2(24, 252, 12, 12), Color("8b9c8a"))
	draw_rect(Rect2(size.x - 36, 252, 12, 12), Color("8b9c8a"))
	var title: String = BathSystem.LABELS[bath.stage] if bath.stage < 3 else "Czysty piesek!"
	draw_string(ThemeDB.fallback_font, Vector2(0, 25), title, HORIZONTAL_ALIGNMENT_CENTER, size.x, 20, Color("294b40"))
	var hint: String = ["Pocieraj trzy miejsca gąbką.", "Przesuwaj prysznic po sierści.", "Pocieraj ręcznikiem trzy miejsca.", "Piesek otrzepuje kropelki."][bath.stage]
	draw_string(ThemeDB.fallback_font, Vector2(0, 290), hint, HORIZONTAL_ALIGNMENT_CENTER, size.x, 14, Color("294b40"))
	draw_string(ThemeDB.fallback_font, Vector2(0, 315), "Puść palec, aby przejść dalej." if bath.stage < 3 else "Możesz wrócić do domu.", HORIZONTAL_ALIGNMENT_CENTER, size.x, 13, Color("294b40"))

func _draw_foam() -> void:
	if bath.stage >= 3: return
	for i in 3:
		var center := zone_center(i)
		var amount: float = bath.coverage[i] / 60.0
		foam.draw_arc(center, 28, 0, TAU, 24, Color("719b85"), 2)
		foam.draw_arc(center, 28, -PI / 2, -PI / 2 + TAU * amount, 24, Color("f0b75d"), 5)
		var bubbles := amount if bath.stage == 0 else (1 - amount if bath.stage == 1 else 0.0)
		for j in int(bubbles * 5):
			foam.draw_circle(center + Vector2((j % 3) * 10 - 10, (j / 3) * 12 - 5), 9, Color(0.96, 0.99, 1, 0.85))
	if bath.pointer != -2:
		if bath.stage == 1:
			for i in 4: foam.draw_line(tool_point + Vector2(i * 4, -20), tool_point + Vector2(i * 4, 12), Color("78b9dc"), 3)
		else:
			foam.draw_rect(Rect2(tool_point - Vector2(18, 10), Vector2(36, 20)), Color("e8bd70") if bath.stage == 0 else Color("d297ac"))

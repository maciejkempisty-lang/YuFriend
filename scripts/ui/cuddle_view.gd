class_name CuddleView
extends Control

signal pressed_at(point: Vector2)
signal moved_to(point: Vector2)
signal released_at(point: Vector2, cancelled: bool)
var model: CuddleSystem
var puppy := PetAnimator.new()
var _pointer := -1
var _mat := StyleBoxFlat.new()
var _guides := Control.new()

func _ready() -> void:
	custom_minimum_size = Vector2(240, 260)
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_mat.bg_color = Color("efe5d5")
	_mat.set_corner_radius_all(20)
	add_child(puppy)
	puppy.set_skin(load("res://data/skins/puppy_pixel.tres"))
	puppy.request_clip("idle_lie")
	_guides.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_guides)
	_guides.draw.connect(_draw_guides)
	gui_input.connect(_on_input)
	visibility_changed.connect(func():
		if not is_visible_in_tree():
			_pointer = -1
			if model != null: model.release(Vector2.ZERO, true))

func _process(_delta: float) -> void:
	if model == null: return
	puppy.scale = Vector2.ONE * size.x / 360.0
	puppy.position = Vector2(size.x * 0.50, size.y * 0.80)
	puppy.facing_left = false
	if puppy.current != model.reaction and puppy.pending != model.reaction:
		puppy.request_clip(model.reaction)
	queue_redraw()
	_guides.queue_redraw()

func _on_input(event: InputEvent) -> void:
	if model == null or event.device == InputEvent.DEVICE_ID_EMULATION: return
	if event is InputEventScreenTouch:
		if event.pressed: _down(event.position, event.index)
		else: _up(event.position, event.index, event.canceled)
		accept_event()
	elif event is InputEventScreenDrag:
		_move(event.position, event.index)
		accept_event()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed: _down(event.position, -2)
		else: _up(event.position, -2)
		accept_event()
	elif event is InputEventMouseMotion and _pointer == -2:
		_move(event.position, -2)
		accept_event()

func _down(point: Vector2, id: int) -> void:
	if _pointer != -1: return
	_pointer = id
	pressed_at.emit(point / size)

func _move(point: Vector2, id: int) -> void:
	if _pointer == id: moved_to.emit(point / size)

func _up(point: Vector2, id: int, cancelled: bool = false) -> void:
	if _pointer != id: return
	_pointer = -1
	released_at.emit(point / size, cancelled)

func _draw() -> void:
	draw_style_box(_mat, Rect2(Vector2.ZERO, size))
	if model == null: return
	var ink := Color("52664c")
	var font := get_theme_default_font()
	var progress := model.calm / model.target_seconds() if model.phase == "stroke" else model.favorite_time / 2.0
	if model.phase == "result": progress = 1
	draw_string(font, Vector2(16, 25), "Spokojne głaski" if model.phase == "stroke" else ("Miło być razem" if model.phase == "result" else "Ulubione miejsce"), HORIZONTAL_ALIGNMENT_LEFT, size.x - 32, 16, ink)
	draw_rect(Rect2(16, 36, size.x - 32, 5), Color("d8cebe"))
	draw_rect(Rect2(16, 36, (size.x - 32) * clampf(progress, 0, 1), 5), Color("819c77"))
	draw_string(font, Vector2(16, size.y - 18), "Możesz przerwać w każdej chwili.", HORIZONTAL_ALIGNMENT_CENTER, size.x - 32, 12, ink)

func _draw_guides() -> void:
	if model == null: return
	var ink := Color("52664c")
	var font := get_theme_default_font()
	if model.phase == "stroke":
		var a := Vector2(0.27, 0.60) * size
		var b := Vector2(0.57, 0.60) * size
		_guides.draw_line(a, b, Color("fff9e4a0"), 3, true)
		for point in [a, b]: _guides.draw_circle(point, 7, Color("fff9e4"), false, 2, true)
	elif model.phase == "find":
		for index in 2:
			var center: Vector2 = CuddleSystem.SPOTS[index] * size
			_guides.draw_circle(center, 16, Color("fff9e4"), false, 2, true)
			var label_position := Vector2(14, size.y * (0.37 if index == 0 else 0.79))
			_guides.draw_string(font, label_position, "Za uszkiem" if index == 0 else "Pod brodą", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, ink)
			_guides.draw_line(label_position + Vector2(80, -4), center - Vector2(16, 0), Color("8c8d74"), 1, true)
	if model.held:
		_guides.draw_circle(model.point * size, 10, Color("fdf8e9aa"), false, 2, true)

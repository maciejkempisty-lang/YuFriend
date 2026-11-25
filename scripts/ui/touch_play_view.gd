class_name TouchPlayView
extends Control

signal pressed_at(point: Vector2)
signal moved_to(point: Vector2)
signal released_at(point: Vector2, cancelled: bool)

var model: TouchPlaySystem
var yard_texture := preload("res://assets/art/environments/yard-sunny-background-v1.png")
var puppy := PetAnimator.new()
var prop_layer := Node2D.new()
var _pointer := -1
var _last_phase := ""
var _last_kind := ""
var _mat := StyleBoxFlat.new()

func _ready() -> void:
	custom_minimum_size = Vector2(240, 260)
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_mat.bg_color = Color("e7ecd9")
	_mat.set_corner_radius_all(20)
	add_child(puppy)
	add_child(prop_layer)
	prop_layer.z_index = 5
	prop_layer.draw.connect(_draw_disk)
	puppy.set_skin(load("res://data/skins/puppy_pixel.tres"))
	puppy.request_clip("play_bow")
	gui_input.connect(_on_input)
	visibility_changed.connect(func():
		if not is_visible_in_tree():
			_pointer = -1
			if model != null: model.release(Vector2.ZERO, true))

func _process(_delta: float) -> void:
	if model == null: return
	puppy.visible = model.kind in ["tug", "cups", "cups2", "tag", "frisbee"]
	puppy.scale = Vector2.ONE * minf(size.x / 640.0, 0.55)
	var clip := "play_bow" if model.phase in ["warning", "demo_warning"] else ("shake" if model.phase == "dog_pull" else "idle")
	if model.kind in ["cups", "cups2"]:
		puppy.scale *= 0.75
		var point := model.dog_point() * size
		if model.phase == "search":
			if absf(point.x - puppy.position.x) > 0.01: puppy.facing_left = point.x < puppy.position.x
			clip = "walk" if model.elapsed < TouchPlaySystem.SEARCH_SECONDS * 0.6 else "head_tilt_stand"
		else: clip = "head_tilt_stand" if model.phase in ["found", "hint"] else "idle"
		puppy.position = point
	elif model.kind in ["tag", "frisbee"]:
		var game := model as SkillPlaySystem
		puppy.scale *= 0.85
		var point := game.dog_point() * size
		if absf(point.x - puppy.position.x) > 0.1: puppy.facing_left = point.x < puppy.position.x
		puppy.position = point
		if game.kind == "frisbee": puppy.facing_left = false
		clip = "play_bow" if game.phase in ["bow", "feint"] else ("run" if game.phase in ["run", "flight"] else "idle")
	else:
		puppy.facing_left = false
		puppy.position = Vector2(size.x * (0.19 + (model.tug_handle.x - 0.60) * 0.16), size.y * 0.67)
	if model.phase == "result": clip = "tail_wag_stand"
	if model.kind == "frisbee" and (model as SkillPlaySystem).disk_attached(): clip = "treat_take_stand"
	if _last_phase != model.phase or _last_kind != model.kind or (puppy.current != clip and puppy.pending != clip):
		_last_phase = model.phase
		_last_kind = model.kind
		if model.kind in ["tag", "frisbee"]: puppy.remaining = 0
		puppy.request_clip(clip)
	queue_redraw()
	prop_layer.queue_redraw()

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
	if model.kind == "tug": _draw_rope()
	elif model.kind in ["cups", "cups2"]: _draw_cups()
	elif model.kind in ["tag", "frisbee"]: _draw_yard_game()

func _draw_rope() -> void:
	var start := Vector2(puppy.position.x + size.x * 0.06, size.y * 0.49)
	var end := model.tug_handle * size
	var points := PackedVector2Array()
	for index in 21:
		var t := index / 20.0
		points.append(start.lerp(end, t) + Vector2(0, sin(t * PI) * (5 if model.held else 18)))
	draw_polyline(points, Color("8b6545"), 12, true)
	draw_polyline(points, Color("d4aa70"), 6, true)
	for index in range(2, 20, 2):
		draw_line(points[index] + Vector2(-2, -4), points[index] + Vector2(2, 4), Color("b38758"), 2, true)
	draw_circle(end + Vector2(0, 3), 24, Color("b8c2a9"))
	draw_circle(end, 24, Color("ddb778"))
	draw_circle(end, 15, Color("efcf93"))
	draw_arc(end, 18, 0, TAU, 24, Color("9a7246"), 3, true)
	var font := get_theme_default_font()
	draw_string(font, Vector2(size.x * 0.1, size.y * 0.87), "Pokaz" if model.phase.begins_with("demo") else "Wymiana %d/5 · udane %d" % [mini(5, model.tug_round + 1), model.tug_good], HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("315d49"))
	var tension := 0.9 if model.phase == "dog_pull" and model.held else (0.6 if model.phase in ["warning", "demo_warning"] else 0.2)
	draw_rect(Rect2(20, 18, size.x - 40, 12), Color("c6cfb8"))
	draw_rect(Rect2(20, 18, (size.x - 40) * tension, 12), Color("a45f41") if tension > 0.5 else Color("779565"))
	if model.phase == "result":
		for star in 3:
			var shape := PackedVector2Array()
			var center := Vector2(size.x / 2 + (star - 1) * 38, 48)
			for vertex in 10:
				var angle := -PI / 2 + vertex * PI / 5
				shape.append(center + Vector2(cos(angle), sin(angle)) * (14 if vertex % 2 == 0 else 6))
			draw_colored_polygon(shape, Color("bd8b38") if star < model.tug_stars() else Color("bcc5ad"))
		return
	if model.phase in ["warning", "demo_warning"]:
		draw_string(font, Vector2(20, size.y * 0.97), "PUŚĆ PALEC", HORIZONTAL_ALIGNMENT_CENTER, size.x - 40, 16, Color("8a4c30"))
		return
	if model.phase.begins_with("demo"): return
	var direction := -1.0 if model.phase == "dog_pull" else 1.0
	var arrow := end + Vector2(direction * 44, 0)
	draw_line(arrow - Vector2(direction * 10, 0), arrow, Color("315d49"), 3, true)
	draw_line(arrow, arrow - Vector2(direction * 6, 5), Color("315d49"), 3, true)
	draw_line(arrow, arrow - Vector2(direction * 6, -5), Color("315d49"), 3, true)

func _draw_cups() -> void:
	var font := get_theme_default_font()
	for id in 3:
		var base := model.cup_point(id) * size
		draw_ellipse_shadow(base)
		var reveal := (model.kind == "cups2" and (model.phase == "show" or (model.phase == "result" and id == model.treat_cup))) or model.phase == "hide" or (model.phase == "cover" and id == model.treat_cup) or (model.phase in ["found", "result"] and id == model.selected_cup)
		if id == model.treat_cup and reveal:
			var treat := Rect2(base - Vector2(14, 13), Vector2(28, 28))
			draw_texture_rect(GameIcons.texture("treat", Color("a56f39")), treat, false)
		var lift := size.y * 0.12 if reveal else 0.0
		if model.phase == "cover": lift *= 1.0 - clampf(model.elapsed / 0.7, 0, 1)
		var width := size.x * 0.20
		var height := size.y * 0.21
		var bottom := base - Vector2(0, lift)
		var shape := PackedVector2Array([bottom + Vector2(-width / 2, 0), bottom + Vector2(-width * 0.34, -height), bottom + Vector2(width * 0.34, -height), bottom + Vector2(width / 2, 0)])
		draw_colored_polygon(shape, Color("d9b67c") if id == model.selected_cup else Color("819c77"))
		draw_polyline(PackedVector2Array([shape[0], shape[1], shape[2], shape[3], shape[0]]), Color("42634d"), 3, true)
		draw_line(bottom + Vector2(-width * 0.4, -height * 0.3), bottom + Vector2(width * 0.4, -height * 0.3), Color("edf1dd"), 7, true)
		if model.kind != "cups2" and model.phase in ["hide", "ready", "found", "result"]:
			draw_string(font, base + Vector2(-5, 38), str(id + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("315d49"))

	if model.kind == "cups2" and (model.phase == "hint" or (model.phase == "guess" and (model as SkillPlaySystem).assisted)):
		var target := model.cup_point(model.treat_cup) * size
		draw_arc(target, 28, 0, TAU, 32, Color("bd8b38"), 4, true)
	if model.phase == "search":
		var target := model.cup_point(model.search_order[model.search_index]) * size
		draw_arc(target + Vector2(0, 13), 12 + sin(model.elapsed * 8) * 3, 0, PI, 16, Color("a56f39"), 2, true)
	if model.phase == "found":
		var target := model.cup_point(model.selected_cup) * size
		draw_string(font, Vector2(maxf(8, target.x - 25), size.y * 0.66), "Jest!", HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color("315d49"))

func draw_ellipse_shadow(base: Vector2) -> void:
	draw_set_transform(base + Vector2(0, 4), 0, Vector2(1, 0.2))
	draw_circle(Vector2.ZERO, size.x * 0.12, Color("c6cfb8"))
	draw_set_transform(Vector2.ZERO)

func _draw_yard_game() -> void:
	var game := model as SkillPlaySystem
	draw_texture_rect(yard_texture, Rect2(Vector2.ZERO, size), false)
	var font := get_theme_default_font()
	if game.kind == "tag":
		var center := Vector2(game.tag_x * size.x, size.y * 0.78)
		draw_arc(center, 30, PI, TAU, 24, Color("f6d877") if game.phase == "bow" else Color("e8eedb"), 4, true)
		draw_circle(center + Vector2(25, -22), 8, Color("d78952"))
		if game.phase == "bow": draw_string(font, Vector2(12, 28), "TERAZ!", HORIZONTAL_ALIGNMENT_CENTER, size.x - 24, 20, Color("244f3d"))
	elif game.kind == "frisbee":
		if game.phase == "flight":
			var target := game.disk_position_at(game.catch_progress()) * size
			draw_arc(target, 22, 0, TAU, 32, Color("f7f3ce"), 3, true)
	if game.phase == "result":
		draw_style_box(_mat, Rect2(8, 8, size.x - 16, 42))
		draw_string(font, Vector2(12, 36), "%d / 3 gwiazdki" % game.stars, HORIZONTAL_ALIGNMENT_CENTER, size.x - 24, 20, Color("315d49"))

func _draw_disk() -> void:
	if model == null or model.kind != "frisbee": return
	var game := model as SkillPlaySystem
	var point := game.disk_point() * size
	if game.disk_attached():
		point = puppy.transform * puppy.mouth_point()
		if game.phase == "flight":
			var contact := game.disk_position_at(game.catch_at / game.flight_duration()) * size
			point = contact.lerp(point, clampf((game.elapsed - game.catch_at) / 0.10, 0, 1))
	elif game.phase in ["land", "result"]:
		point = Vector2(0.78, 0.82) * size
	prop_layer.draw_set_transform(point, 0.12 if game.disk_attached() else game.elapsed * 3, Vector2(1, 0.4))
	prop_layer.draw_circle(Vector2.ZERO, 15, Color("f3c565"))
	prop_layer.draw_arc(Vector2.ZERO, 11, 0, TAU, 32, Color("9a613b"), 3, true)
	prop_layer.draw_set_transform(Vector2.ZERO)

class_name RoomView
extends Control

signal floor_tapped(ratio: float)
signal care_requested(action: String)
signal destination_reached
signal performance_finished(trial_id: int)
var animator := PetAnimator.new()
var current_ratio: float = 0.5
var target_ratio: float = 0.5
var sleeping: bool = false
var effect: String = ""
var effect_left: float = 0.0
var moving: bool = false
var walk_performance: int = 0
var walk_ready: bool = false
var presentation_scale: float = 1.0
var elapsed: float = 0.0

func _ready() -> void:
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	clip_contents = true
	add_child(animator)
	animator.set_skin(load("res://data/skins/puppy_simple.tres"))
	animator.request_completed.connect(_on_animation_completed)
	resized.connect(update_placement)
	gui_input.connect(_on_input)

func _on_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.pressed:
		if event.device != InputEvent.DEVICE_ID_EMULATION: _interact(event.position)
		accept_event()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		# Mobile's emulated mouse must not dispatch the same care action twice.
		if event.device != InputEvent.DEVICE_ID_EMULATION: _interact(event.position)
		accept_event()

func _interact(point: Vector2) -> void:
	var action := action_at(point)
	if not action.is_empty():
		care_requested.emit(action)
	elif point.y >= size.y * 0.60:
		var margin := _walking_margin()
		var ratio := inverse_lerp(margin, size.x - margin, point.x)
		floor_tapped.emit(lerpf(0.23, 0.77, clampf(ratio, 0, 1)))

func action_at(point: Vector2) -> String:
	if bowl_rect().grow(8).has_point(point): return "feed"
	if bed_rect().grow(5).has_point(point): return "rest"
	if point.distance_to(ball_center()) < 23: return "play"
	var foot := pet_position()
	if Rect2(foot - Vector2(79, 158) * presentation_scale, Vector2(158, 168) * presentation_scale).has_point(point): return "pet"
	return ""

func _walking_margin() -> float:
	return minf(size.x * 0.37, 93 * presentation_scale + 12)

func pet_position() -> Vector2:
	var margin := _walking_margin()
	return Vector2(lerpf(margin, size.x - margin, inverse_lerp(0.23, 0.77, current_ratio)), minf(size.y * 0.79, size.y - 112))

func bowl_rect() -> Rect2:
	return Rect2(size.x - 83, size.y * 0.77, 56, 31)

func bed_rect() -> Rect2:
	return Rect2(20, size.y * 0.69, 88, 44)

func ball_center() -> Vector2:
	return Vector2(size.x * 0.77, size.y * 0.69)

func update_placement() -> void:
	presentation_scale = clampf(minf((pet_position().y - 210) / 180, (size.x - 104) / 180), 0.55, 1.55)
	animator.scale = Vector2.ONE * presentation_scale
	animator.position = pet_position()
	queue_redraw()

func move_to(ratio: float) -> void:
	target_ratio = clampf(ratio, 0.23, 0.77)
	moving = true

func play_performance(clip: String, trial_id: int) -> void:
	walk_performance = trial_id if clip == "walk" else 0
	walk_ready = false
	animator.request_clip(clip, trial_id)

func _on_animation_completed(trial_id: int) -> void:
	if trial_id == walk_performance:
		walk_ready = true
	else:
		performance_finished.emit(trial_id)

func play_clip(clip: String) -> void:
	if clip != "walk":
		moving = false
		walk_performance = 0
	animator.request_clip(clip)
	sleeping = clip == "sleep"
	if clip in ["tail_wag_sit", "tail_wag_stand", "petted_stand"]:
		effect = "♥"
		effect_left = 1.7
	elif clip == "head_tilt_stand":
		effect = "?"
		effect_left = 1.4

func _process(delta: float) -> void:
	# The completed walk still belongs to the training trial, not to the UI.
	if moving and animator.current == "walk":
		animator.facing_left = target_ratio < current_ratio
		current_ratio = move_toward(current_ratio, target_ratio, delta * 0.24)
		if is_equal_approx(current_ratio, target_ratio):
			moving = false
			if walk_performance > 0 and walk_ready:
				var completed := walk_performance
				walk_performance = 0
				performance_finished.emit(completed)
			destination_reached.emit()
	animator.position = pet_position()
	effect_left = maxf(0, effect_left - delta)
	elapsed += delta
	queue_redraw()

func _box(rect: Rect2, color: Color, radius: int = 16) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	draw_style_box(style, rect)

func _arch(rect: Rect2, color: Color) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = int(rect.size.x / 2)
	style.corner_radius_top_right = int(rect.size.x / 2)
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	draw_style_box(style, rect)

func _ellipse(center: Vector2, radii: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for i in 64:
		var angle := TAU * i / 64.0
		points.append(center + Vector2(cos(angle), sin(angle)) * radii)
	draw_colored_polygon(points, color)

func _leaf(center: Vector2, radius: Vector2, angle: float, color: Color) -> void:
	draw_set_transform(center, angle)
	_ellipse(Vector2.ZERO, radius, color)
	draw_set_transform(Vector2.ZERO)

func _draw() -> void:
	var w := size.x
	var h := size.y
	if w <= 0 or h <= 0: return
	var floor_y := h * 0.60
	# A quiet wall leaves the top of the scene readable for the compact HUD.
	for i in 40:
		var t := i / 39.0
		draw_rect(Rect2(0, h * i / 40.0, w, h / 40.0 + 1), Color("f5f2df").lerp(Color("dfe5c8"), t))
	var scene_top := maxf(182, h * 0.32)
	var window_h := clampf(floor_y - scene_top + 8, 88, 220)
	var window_w := clampf(w * 0.31, 108, 220)
	var window_x := w * 0.64 - window_w * 0.25
	var window := Rect2(window_x, scene_top, window_w, window_h)
	_arch(Rect2(window.position + Vector2(5, 5), window.size), Color(0.36, 0.40, 0.28, 0.07))
	_arch(window, Color("fffbee"))
	var sky := window.grow(-8)
	_arch(sky, Color("c5dfd8"))
	draw_circle(sky.position + Vector2(sky.size.x * 0.69, sky.size.y * 0.32), 13, Color("f7e4a6"))
	var hill_y := sky.end.y - sky.size.y * 0.3
	draw_colored_polygon(PackedVector2Array([Vector2(sky.position.x, hill_y + 7), Vector2(sky.position.x + sky.size.x * 0.33, hill_y - 10), Vector2(sky.end.x, hill_y + 8), sky.end, Vector2(sky.position.x, sky.end.y)]), Color("a5bf9b"))
	draw_line(Vector2(window.get_center().x, sky.position.y + 3), Vector2(window.get_center().x, sky.end.y), Color("fffbee"), 5, true)
	draw_line(Vector2(sky.position.x, sky.position.y + sky.size.y * 0.61), Vector2(sky.end.x, sky.position.y + sky.size.y * 0.61), Color("fffbee"), 5, true)
	_box(Rect2(window_x - 9, window.end.y, window_w + 18, 9), Color("c6aa7e"), 4)
	# A linen curtain and a small framed paw print make the room feel lived in.
	draw_line(Vector2(window_x - 8, scene_top - 7), Vector2(window.end.x + 9, scene_top - 7), Color("ae9671"), 3, true)
	_box(Rect2(window_x - 4, scene_top - 5, 19, window_h * 0.68), Color("ede2bc"), 7)
	draw_line(Vector2(window_x + 3, scene_top + 6), Vector2(window_x + 3, scene_top + window_h * 0.55), Color("ddd0a8"), 1.5, true)
	var frame := Rect2(w * 0.13, scene_top + 8, 54, 66)
	_box(Rect2(frame.position + Vector2(3, 4), frame.size), Color(0.4, 0.38, 0.22, 0.06), 7)
	_box(frame, Color("b99d76"), 5)
	_box(frame.grow(-5), Color("fbf0d9"), 2)
	draw_texture_rect(GameIcons.texture("paw", Color("c29b69")), Rect2(frame.position + Vector2(13, 17), Vector2(28, 28)), false)
	# Floor boards and a broad shaft of sunlight establish space without clutter.
	draw_rect(Rect2(0, floor_y, w, h - floor_y), Color("dfc49d"))
	draw_rect(Rect2(0, floor_y, w, 7), Color("c5ad87"))
	draw_line(Vector2(0, floor_y + 7), Vector2(w, floor_y + 7), Color("eddbb7"), 2)
	for i in range(-2, 10):
		var x := w * i / 7.0
		draw_line(Vector2(x, floor_y + 10), Vector2(x - 74, h), Color("d3b58b"), 1.2, true)
	for t in [0.32, 0.72]:
		draw_line(Vector2(0, lerpf(floor_y, h, t)), Vector2(w, lerpf(floor_y, h, t)), Color("d6b98e"), 1, true)
	draw_colored_polygon(PackedVector2Array([Vector2(window_x, floor_y + 9), Vector2(window.end.x - 5, floor_y + 9), Vector2(w * 0.73, h), Vector2(w * 0.17, h)]), Color(1.0, 0.96, 0.75, 0.21))
	# Rug follows the room, independently from the puppy's animation anchor.
	var rug := Vector2(w * 0.5, h * 0.80)
	_ellipse(rug + Vector2(0, 5), Vector2(w * 0.35, h * 0.105), Color(0.46, 0.34, 0.18, 0.06))
	_ellipse(rug, Vector2(w * 0.35, h * 0.105), Color("b3bf95"))
	_ellipse(rug, Vector2(w * 0.32, h * 0.091), Color("ccd1a8"))
	_ellipse(rug, Vector2(w * 0.29, h * 0.078), Color("d5d8b3"))
	# Plant sits beside the bed; subtle leaf motion does not distract from training.
	var pot := Vector2(w * 0.10, floor_y - 4)
	var sway := sin(elapsed * 0.7) * 0.025
	draw_line(pot - Vector2(0, 18), pot - Vector2(0, 70), Color("71865b"), 2.5, true)
	_leaf(pot + Vector2(-11, -44), Vector2(18, 8), 0.45 + sway, Color("889b6c"))
	_leaf(pot + Vector2(12, -61), Vector2(18, 8), -0.5 + sway, Color("9aab7b"))
	_leaf(pot + Vector2(-6, -72), Vector2(12, 7), 0.7 + sway, Color("789363"))
	_box(Rect2(pot.x - 15, pot.y - 24, 30, 30), Color("c58b6b"), 8)
	_box(Rect2(pot.x - 17, pot.y - 25, 34, 7), Color("d6a17e"), 3)
	var bed := bed_rect()
	_ellipse(bed.get_center() + Vector2(0, 6), bed.size * Vector2(0.53, 0.43), Color(0.4, 0.36, 0.2, 0.08))
	_ellipse(bed.get_center(), bed.size * 0.5, Color("7c9582"))
	_ellipse(bed.get_center() - Vector2(0, 3), bed.size * Vector2(0.40, 0.32), Color("b8c5a6"))
	_ellipse(bed.get_center() - Vector2(0, 2), bed.size * Vector2(0.30, 0.23), Color("c7d0b1"))
	var ball := ball_center()
	_ellipse(ball + Vector2(1, 12), Vector2(15, 5), Color(0.44, 0.34, 0.2, 0.09))
	draw_circle(ball, 12, Color("ce8968"))
	draw_arc(ball + Vector2(-4, -1), 11, -1.0, 1.4, 24, Color("edbf8d"), 2.5, true)
	var bowl := bowl_rect()
	_ellipse(bowl.get_center() + Vector2(0, 8), Vector2(32, 11), Color(0.44, 0.34, 0.2, 0.09))
	_box(bowl, Color("b9795e"), 11)
	_ellipse(Vector2(bowl.get_center().x, bowl.position.y + 5), Vector2(28, 10), Color("e4b08a"))
	_ellipse(Vector2(bowl.get_center().x, bowl.position.y + 5), Vector2(21, 6), Color("896346"))
	for i in 6:
		draw_circle(Vector2(bowl.position.x + 13 + i * 6, bowl.position.y + 4 + (i % 2) * 2), 2.5, Color("c39a5d"))
	var foot := pet_position()
	_ellipse(foot + Vector2(0, 2), Vector2(53, 9) * presentation_scale, Color(0.35, 0.31, 0.20, 0.12))
	if sleeping:
		draw_string(get_theme_font("font"), foot + Vector2(55, -124) * presentation_scale, "z Z", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color("758d77"))
	if effect_left > 0:
		var color := Color("b9745b")
		color.a = minf(1, effect_left)
		draw_string(get_theme_font("font"), foot + Vector2(55, -145) * presentation_scale - Vector2(0, (1.7 - effect_left) * 16), effect, HORIZONTAL_ALIGNMENT_LEFT, -1, 29, color)

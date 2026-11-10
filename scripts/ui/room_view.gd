class_name RoomView
extends Control

signal floor_tapped(ratio: float)
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

func _ready() -> void:
	custom_minimum_size = Vector2(0, 310)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	add_child(animator)
	animator.set_skin(load("res://data/skins/puppy_simple.tres"))
	animator.request_completed.connect(_on_animation_completed)
	resized.connect(queue_redraw)
	gui_input.connect(_on_input)

func _on_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.pressed:
		floor_tapped.emit(event.position.x / size.x)
		accept_event()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		# Physical mouse is enough on desktop; ignore synthesized touch's mouse.
		if event.device != InputEvent.DEVICE_ID_EMULATION:
			floor_tapped.emit(event.position.x / size.x)
		accept_event()

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
	# Feet stay still until a seated puppy has actually stood up.
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
	animator.position = Vector2(size.x * current_ratio, size.y * 0.84)
	effect_left = maxf(0, effect_left - delta)
	queue_redraw()

func _box(rect: Rect2, color: Color, radius: int = 16) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	draw_style_box(style, rect)

func _ellipse(center: Vector2, radii: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for i in 48:
		var angle := TAU * i / 48.0
		points.append(center + Vector2(cos(angle), sin(angle)) * radii)
	draw_colored_polygon(points, color)

func _draw() -> void:
	var w := size.x
	var h := size.y
	_box(Rect2(Vector2.ZERO, size), Color("e7ede1"), 26)
	_box(Rect2(0, h * 0.60, w, h * 0.40), Color("e4cdb2"), 25)
	draw_rect(Rect2(0, h * 0.60, w, 10), Color("ccb99e"))
	for i in range(1, 8):
		draw_line(Vector2(w * i / 8.0, h * 0.64), Vector2(w * i / 8.0 - 22, h), Color("d8c0a4"), 1.2)
	# Window, sky and a few soft clouds.
	var wx := w * 0.57
	_box(Rect2(wx, 28, 132, 116), Color("fff8e9"), 15)
	_box(Rect2(wx + 8, 36, 116, 100), Color("bddbd3"), 9)
	draw_circle(Vector2(wx + 93, 57), 14, Color("fae6a5"))
	_ellipse(Vector2(wx + 44, 75), Vector2(29, 8), Color("e9f4ed"))
	draw_line(Vector2(wx + 66, 36), Vector2(wx + 66, 136), Color("fff8e9"), 5)
	draw_line(Vector2(wx + 8, 90), Vector2(wx + 124, 90), Color("fff8e9"), 5)
	_box(Rect2(wx - 6, 140, 144, 8), Color("ad9478"), 3)
	# Shelf and small plant.
	_box(Rect2(28, 102, 104, 6), Color("b79b7a"), 2)
	_box(Rect2(45, 73, 27, 29), Color("bd8b70"), 5)
	draw_line(Vector2(58, 77), Vector2(58, 43), Color("69866b"), 3)
	_ellipse(Vector2(48, 56), Vector2(14, 6), Color("779b76"))
	_ellipse(Vector2(67, 47), Vector2(12, 6), Color("8da780"))
	_box(Rect2(91, 76, 10, 26), Color("d7a271"), 2)
	_box(Rect2(104, 70, 10, 32), Color("91a69c"), 2)
	# Rug, bed and food bowl are independent from the dog sprite.
	_ellipse(Vector2(w * 0.50, h * 0.84), Vector2(w * 0.30, h * 0.12), Color("f3e5cb"))
	_ellipse(Vector2(65, h * 0.77), Vector2(42, 19), Color("829c8e"))
	_ellipse(Vector2(65, h * 0.755), Vector2(34, 12), Color("bac9ad"))
	_box(Rect2(w - 82, h * 0.78, 55, 22), Color("b77c64"), 8)
	_ellipse(Vector2(w - 55, h * 0.78), Vector2(28, 9), Color("dfb092"))
	_ellipse(Vector2(w - 55, h * 0.78), Vector2(20, 5), Color("836044"))
	for i in 5:
		draw_circle(Vector2(w - 68 + i * 6, h * 0.78), 2.4, Color("b18a54"))
	_ellipse(Vector2(w * current_ratio, h * 0.855), Vector2(53, 9), Color(0.36, 0.30, 0.22, 0.12))
	if sleeping:
		draw_string(ThemeDB.fallback_font, Vector2(w * current_ratio + 65, h * 0.42), "z Z", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color("6b7e83"))
	if effect_left > 0:
		var color := Color("bd7868")
		color.a = minf(1, effect_left)
		draw_string(ThemeDB.fallback_font, Vector2(w * current_ratio + 40, h * 0.34 - (1.7 - effect_left) * 16), effect, HORIZONTAL_ALIGNMENT_LEFT, -1, 29, color)

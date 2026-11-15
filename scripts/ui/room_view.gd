class_name RoomView
extends Control

signal floor_tapped(world_position: Vector2)
signal care_requested(action: String)
signal destination_reached
signal performance_finished(trial_id: int)
signal station_reached(token: int)

const WALK_SPEED := 85.0
const DRAG_THRESHOLD := 9.0
var animator := PetAnimator.new()
var backdrop := RoomArtwork.new()
var ball_art := RoomArtwork.new()
var shadow := RoomArtwork.new()
var viewport := SubViewport.new()
var display := TextureRect.new()
var world := Node2D.new()
var actors := Node2D.new()
var puppy := Node2D.new()
var camera := Camera2D.new()
var station_nodes: Dictionary = {}
var effect_label := Label.new()
var sleep_label := Label.new()
var return_button := Button.new()
var room_hint := Label.new()
var pet_world: Vector2 = RoomLayout.START
var target_world: Vector2 = RoomLayout.START
var ball_world: Vector2 = RoomLayout.STATIONS.ball.position
var ball_target: Vector2 = ball_world
var moving := false
var presentation_scale: float = RoomLayout.PUPPY_SCALE
var hud_bottom := 0.0
var render_rect := Rect2()
var walk_performance := 0
var walk_ready := false
var station_token := 0
var station_action := ""
var anchored_station := ""
var effect_left := 0.0
var camera_manual := false
var interaction_focus := false
var focus_left := 0.0
var base_zoom := 1.0
var _manual_zoom := 1.0
var _camera_initialized := false
var _pointer_id := -1
var _press_point := Vector2.ZERO
var _press_camera := Vector2.ZERO
var _press_zoom := 1.0
var _dragged := false
var _touch_masks: Dictionary = {}

func _ready() -> void:
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	clip_contents = true
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var wall := ColorRect.new()
	wall.color = Color("eae9d2")
	wall.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(wall)
	wall.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	viewport.world_2d = World2D.new()
	viewport.disable_3d = true
	viewport.gui_disable_input = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	viewport.add_child(world)
	world.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	backdrop.z_index = -5
	world.add_child(backdrop)
	backdrop.configure(RoomLayout.SIZE)
	world.add_child(actors)
	actors.y_sort_enabled = true
	for id in RoomLayout.STATIONS:
		if id == "ball": continue
		var node := RoomArtwork.new()
		node.kind = id
		node.position = RoomLayout.STATIONS[id].position
		if id in ["bed", "window", "door"]: node.z_index = -1
		actors.add_child(node)
		station_nodes[id] = node
	actors.add_child(puppy)
	shadow.kind = "shadow"
	puppy.add_child(shadow)
	puppy.add_child(animator)
	ball_art.kind = "ball"
	actors.add_child(ball_art)
	for label in [effect_label, sleep_label]:
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.add_theme_font_size_override("font_size", 23)
		label.add_theme_color_override("font_color", Color("758d77"))
		puppy.add_child(label)
		label.hide()
	effect_label.add_theme_color_override("font_color", Color("b9745b"))
	sleep_label.text = "z Z"
	viewport.add_child(camera)
	camera.position_smoothing_enabled = false
	camera.enabled = true
	display.texture = viewport.get_texture()
	display.mouse_filter = Control.MOUSE_FILTER_IGNORE
	display.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	add_child(display)
	room_hint.text = "Przesuń pokój ↔"
	room_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	room_hint.add_theme_font_size_override("font_size", 11)
	room_hint.add_theme_color_override("font_color", Color("78826c"))
	add_child(room_hint)
	return_button.text = "Do pieska"
	return_button.add_theme_font_size_override("font_size", 12)
	return_button.pressed.connect(func(): focus_pet(false))
	add_child(return_button)
	return_button.hide()
	animator.set_skin(load("res://data/skins/puppy_pixel.tres"))
	animator.request_completed.connect(_on_animation_completed)
	resized.connect(update_placement)
	gui_input.connect(_on_input)
	update_placement()

func _on_input(event: InputEvent) -> void:
	if event.device == InputEvent.DEVICE_ID_EMULATION: return
	if event is InputEventScreenTouch:
		if event.pressed: _pointer_down(event.position, event.index)
		else: _pointer_up(event.position, event.index)
		accept_event()
	elif event is InputEventScreenDrag:
		_pointer_move(event.position, event.index)
		accept_event()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed: _pointer_down(event.position, -2)
		else: _pointer_up(event.position, -2)
		accept_event()
	elif event is InputEventMouseMotion and _pointer_id == -2:
		_pointer_move(event.position, -2)
		accept_event()

func _pointer_down(point: Vector2, id: int) -> void:
	if _pointer_id != -1 or not render_rect.has_point(point): return
	_pointer_id = id
	_press_point = point
	_press_camera = camera.position
	_press_zoom = camera.zoom.x
	_dragged = false

func _pointer_move(point: Vector2, id: int) -> void:
	if id != _pointer_id: return
	if point.distance_to(_press_point) >= DRAG_THRESHOLD: _dragged = true
	if not _dragged: return
	camera_manual = true
	_manual_zoom = _press_zoom
	camera.zoom = Vector2.ONE * _press_zoom
	camera.position = _clamp_camera(_press_camera - Vector2((point.x - _press_point.x) / _press_zoom, 0), _press_zoom)
	camera.force_update_scroll()
	return_button.show()

func _pointer_up(point: Vector2, id: int) -> void:
	if id != _pointer_id: return
	_pointer_move(point, id)
	_pointer_id = -1
	if not _dragged and render_rect.has_point(point): _interact(point)

func _interact(point: Vector2) -> void:
	var action := action_at(point)
	if not action.is_empty(): care_requested.emit(action)
	elif screen_to_world(point).y >= RoomLayout.FLOOR_Y:
		floor_tapped.emit(RoomLayout.clamp_walk(screen_to_world(point)))

func action_at(point: Vector2) -> String:
	if not render_rect.has_point(point): return ""
	var where := screen_to_world(point)
	if where.distance_to(ball_world) < maxf(18, 21 / camera.zoom.x): return "play"
	# Crate/bowl in front of the puppy keep the same priority as Y-sorted rendering.
	for id in ["toys", "food"]:
		if RoomLayout.STATIONS[id].position.y > pet_world.y and station_bounds(id).has_point(where):
			return RoomLayout.STATIONS[id].action
	if _hits_pet(where): return "rest" if animator.pose == "sleep" else "pet"
	for id in RoomLayout.STATIONS:
		if id != "ball" and station_bounds(id).grow(5).has_point(where): return RoomLayout.STATIONS[id].action
	if Rect2(pet_world - Vector2(100, 190) * presentation_scale, Vector2(200, 200) * presentation_scale).has_point(where): return "pet"
	return ""

func _hits_pet(where: Vector2) -> bool:
	var sprite := animator.sprite
	if sprite.sprite_frames == null: return false
	var texture := sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
	if texture == null: return false
	var pixel := Vector2i(sprite.to_local(where).floor())
	if pixel.x < 0 or pixel.y < 0 or pixel.x >= texture.get_width() or pixel.y >= texture.get_height(): return false
	if sprite.flip_h: pixel.x = texture.get_width() - 1 - pixel.x
	if not _touch_masks.has(texture):
		var mask := BitMap.new()
		mask.create_from_image_alpha(texture.get_image(), 0.5)
		_touch_masks[texture] = mask
	return _touch_masks[texture].get_bitv(pixel)

func world_to_screen(point: Vector2) -> Vector2:
	return render_rect.get_center() + (point - camera.position) * camera.zoom

func screen_to_world(point: Vector2) -> Vector2:
	return camera.position + (point - render_rect.get_center()) / camera.zoom

func pet_position() -> Vector2:
	return world_to_screen(pet_world)

func station_bounds(id: String) -> Rect2:
	var data: Dictionary = RoomLayout.STATIONS[id]
	return Rect2(data.position + data.bounds.position, data.bounds.size)

func _screen_rect(rect: Rect2) -> Rect2:
	return Rect2(world_to_screen(rect.position), rect.size * camera.zoom)

func bowl_rect() -> Rect2:
	return _screen_rect(station_bounds("food"))

func bed_rect() -> Rect2:
	return _screen_rect(station_bounds("bed"))

func ball_center() -> Vector2:
	return world_to_screen(ball_world)

func station_point(action: String) -> Vector2:
	if action in ["play", "bored"]:
		var direction := 1.0 if ball_target.x >= pet_world.x else -1.0
		return RoomLayout.clamp_walk(ball_target + Vector2(-direction * 70 * presentation_scale, 10))
	return RoomLayout.station(action).get("stand", pet_world)

func update_placement() -> void:
	if not is_inside_tree() or size.x <= 0: return
	render_rect = Rect2(0, hud_bottom, size.x, maxf(80, size.y - hud_bottom))
	display.position = render_rect.position
	display.size = render_rect.size
	viewport.size = Vector2i(render_rect.size.ceil())
	base_zoom = minf(render_rect.size.y / RoomLayout.SIZE.y, render_rect.size.x / (RoomLayout.SIZE.x / 3.0))
	animator.scale = Vector2.ONE * presentation_scale
	shadow.scale = Vector2.ONE * presentation_scale
	room_hint.position = render_rect.position + Vector2(20, 10)
	return_button.position = Vector2(size.x - 112, hud_bottom + 6)
	return_button.size = Vector2(96, 32)
	if not _camera_initialized:
		camera.zoom = Vector2.ONE * base_zoom
		camera.position = _clamp_camera(Vector2(pet_world.x, RoomLayout.SIZE.y * 0.5), base_zoom)
		_manual_zoom = base_zoom
		_camera_initialized = true
	else:
		# Keep the view's relative zoom when rotating, without changing any world point.
		camera.zoom = Vector2.ONE * base_zoom * (1.38 if interaction_focus or focus_left > 0 else 1.0)
		_manual_zoom = camera.zoom.x
		camera.position = _clamp_camera(camera.position, camera.zoom.x)
	camera.force_update_scroll()
	_sync_layers()

func _clamp_camera(point: Vector2, zoom_level: float) -> Vector2:
	var half := render_rect.size / maxf(0.01, zoom_level) * 0.5
	return Vector2(clampf(point.x, minf(half.x, RoomLayout.SIZE.x * 0.5), maxf(RoomLayout.SIZE.x - half.x, RoomLayout.SIZE.x * 0.5)), clampf(point.y, minf(half.y, RoomLayout.SIZE.y * 0.5), maxf(RoomLayout.SIZE.y - half.y, RoomLayout.SIZE.y * 0.5)))

func focus_pet(close_up: bool = false) -> void:
	camera_manual = false
	if close_up: focus_left = 3.5
	return_button.hide()

func set_interaction_focus(value: bool) -> void:
	if value and not interaction_focus: focus_pet(false)
	interaction_focus = value

func look_at_world(point: Vector2) -> void:
	camera_manual = true
	_manual_zoom = camera.zoom.x
	camera.position = _clamp_camera(point, _manual_zoom)
	camera.force_update_scroll()
	return_button.show()

func _update_camera(delta: float) -> void:
	if not _camera_initialized or _pointer_id != -1: return
	var zoom_target := _manual_zoom if camera_manual else base_zoom * (1.38 if interaction_focus or focus_left > 0 else 1.0)
	var blend := 1.0 - exp(-6.0 * delta)
	var next_zoom := lerpf(camera.zoom.x, zoom_target, blend)
	camera.zoom = Vector2.ONE * next_zoom
	if not camera_manual:
		var y := RoomLayout.SIZE.y * 0.5
		if interaction_focus or focus_left > 0:
			y = pet_world.y - render_rect.size.y / next_zoom * 0.14
		var desired := _clamp_camera(Vector2(pet_world.x, y), next_zoom)
		camera.position = camera.position.lerp(desired, blend)
	camera.position = _clamp_camera(camera.position, next_zoom)
	camera.force_update_scroll()
	return_button.visible = camera_manual
	room_hint.visible = camera_manual or not (interaction_focus or focus_left > 0)

func move_to(point: Vector2) -> void:
	cancel_activity()
	target_world = RoomLayout.clamp_walk(point)
	moving = true

func approach_station(action: String, token: int) -> void:
	cancel_activity()
	station_action = action
	station_token = token
	if action == "play":
		ball_target = RoomLayout.clamp_walk(Vector2(clampf(pet_world.x + (230 if pet_world.x < RoomLayout.SIZE.x * 0.58 else -230), 280, 1180), 317))
		animator.request_clip("play_bow")
	target_world = station_point(action)
	moving = true
	animator.request_clip("walk")

func place_at_station(action: String) -> void:
	anchored_station = action
	pet_world = station_point(action)
	target_world = pet_world
	animator.facing_left = RoomLayout.station(action).get("facing_left", false)
	_sync_layers()
	if not camera_manual:
		camera.position = _clamp_camera(Vector2(pet_world.x, RoomLayout.SIZE.y * 0.5), camera.zoom.x)
		camera.force_update_scroll()

func cancel_activity() -> void:
	moving = false
	station_token = 0
	station_action = ""
	anchored_station = ""
	walk_performance = 0
	walk_ready = false
	ball_target = ball_world
	_pointer_id = -1

func play_performance(clip: String, trial_id: int) -> void:
	if clip == "walk" and not moving: move_to(RoomLayout.come_target(pet_world))
	walk_performance = trial_id if clip == "walk" else 0
	walk_ready = false
	animator.request_clip(clip, trial_id)

func _on_animation_completed(trial_id: int) -> void:
	if trial_id == walk_performance: walk_ready = true
	else: performance_finished.emit(trial_id)

func play_clip(clip: String) -> void:
	if clip != "walk":
		moving = false
		walk_performance = 0
	animator.request_clip(clip)
	if clip in ["tail_wag_sit", "tail_wag_stand", "petted_stand"]:
		effect_label.text = "♥"
		effect_left = 1.7
	elif clip == "head_tilt_stand":
		effect_label.text = "?"
		effect_left = 1.4

func _process(delta: float) -> void:
	if moving and animator.current == "walk":
		var difference := target_world - pet_world
		if absf(difference.x) > 0.1: animator.facing_left = difference.x < 0
		var speed := WALK_SPEED * (1.6 if station_action == "play" else 1.0)
		pet_world = pet_world.move_toward(target_world, speed * delta)
		if pet_world.is_equal_approx(target_world):
			moving = false
			if station_token > 0:
				var token := station_token
				station_token = 0
				if station_action not in ["play", "bored"]:
					anchored_station = station_action
					animator.facing_left = RoomLayout.station(station_action).get("facing_left", false)
				elif station_action == "bored":
					ball_target.x = clampf(ball_world.x + (35 if not animator.facing_left else -35), 200, 1230)
				station_reached.emit(token)
			else:
				if walk_performance > 0 and walk_ready:
					var completed := walk_performance
					walk_performance = 0
					performance_finished.emit(completed)
				destination_reached.emit()
	# Preserve the delivered walk's stride-to-distance ratio at the chosen world speed.
	animator.sprite.speed_scale = WALK_SPEED / (60 * presentation_scale) * (1.6 if station_action == "play" else 1.0) if animator.current == "walk" else 1.0
	if not ball_world.is_equal_approx(ball_target):
		var before := ball_world.x
		ball_world = ball_world.move_toward(ball_target, delta * 290)
		ball_art.roll_phase += (ball_world.x - before) / 12
		ball_art.queue_redraw()
	effect_left = maxf(0, effect_left - delta)
	focus_left = maxf(0, focus_left - delta)
	_sync_layers()
	_update_camera(delta)

func _sync_layers() -> void:
	puppy.position = pet_world
	ball_art.position = ball_world
	effect_label.visible = effect_left > 0
	effect_label.position = Vector2(55, -150) * presentation_scale - Vector2(0, (1.7 - effect_left) * 12)
	effect_label.modulate.a = minf(1, effect_left)
	sleep_label.visible = animator.current == "sleep"
	sleep_label.position = Vector2(55, -100) * presentation_scale

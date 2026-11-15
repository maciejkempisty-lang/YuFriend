class_name RoomView
extends Control

signal floor_tapped(world_position: Vector2)
signal care_requested(action: String)
signal destination_reached
signal performance_finished(trial_id: int)
signal station_reached(token: int)

const WALK_SPEED := 60.0 * RoomLayout.PUPPY_SCALE
const DRAG_THRESHOLD := 9.0
var animator := PetAnimator.new()
var backdrop := RoomArtwork.new()
var ball_art := RoomArtwork.new()
var shadow := RoomArtwork.new()
var viewport := SubViewport.new()
var display := Sprite2D.new()
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
var pixel_scale := 1
var zoom_level := 1
var _view_size := Vector2i.ONE
var _scroll_offset := Vector2.ZERO
var _scroll_material := ShaderMaterial.new()
var _base_pixel_scale := 1
var _available_rect := Rect2()
var _follow_position := Vector2.ZERO
var _output_transform := Transform2D.IDENTITY
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
	world.scale = Vector2.ONE / RoomLayout.PIXEL_SIZE
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
	_scroll_material.shader = preload("res://scripts/ui/room_scroll.gdshader")
	display.material = _scroll_material
	display.region_enabled = true
	# Control pixel snapping happens before UI stretch; a sprite preserves the
	# physical-pixel alignment computed below, even at e.g. 1080 / 390 scale.
	display.centered = false
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
	get_viewport().size_changed.connect(update_placement.call_deferred)
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
	_press_camera = camera_center()
	_press_zoom = screen_scale().x
	_dragged = false

func _pointer_move(point: Vector2, id: int) -> void:
	if id != _pointer_id: return
	if point.distance_to(_press_point) >= DRAG_THRESHOLD: _dragged = true
	if not _dragged: return
	camera_manual = true
	_set_camera_center(_press_camera - Vector2((point.x - _press_point.x) / _press_zoom, 0))
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
	if where.distance_to(ball_world) < maxf(18, 21 / screen_scale().x): return "play"
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
	var pixel := Vector2i(sprite.to_local(where / RoomLayout.PIXEL_SIZE).floor())
	if pixel.x < 0 or pixel.y < 0 or pixel.x >= texture.get_width() or pixel.y >= texture.get_height(): return false
	if sprite.flip_h: pixel.x = texture.get_width() - 1 - pixel.x
	if not _touch_masks.has(texture):
		var mask := BitMap.new()
		mask.create_from_image_alpha(texture.get_image(), 0.5)
		_touch_masks[texture] = mask
	return _touch_masks[texture].get_bitv(pixel)

func camera_center() -> Vector2:
	return (camera.position + _scroll_offset) * RoomLayout.PIXEL_SIZE

func screen_scale() -> Vector2:
	return render_rect.size / Vector2(_view_size) / RoomLayout.PIXEL_SIZE

func world_to_screen(point: Vector2) -> Vector2:
	return render_rect.get_center() + (point - camera_center()) * screen_scale()

func screen_to_world(point: Vector2) -> Vector2:
	return camera_center() + (point - render_rect.get_center()) / screen_scale()

func pet_position() -> Vector2:
	return world_to_screen(pet_world)

func station_bounds(id: String) -> Rect2:
	var data: Dictionary = RoomLayout.STATIONS[id]
	return Rect2(data.position + data.bounds.position, data.bounds.size)

func _screen_rect(rect: Rect2) -> Rect2:
	return Rect2(world_to_screen(rect.position), rect.size * screen_scale())

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
	_available_rect = Rect2(0, hud_bottom, size.x, maxf(1, size.y - hud_bottom))
	# Work in actual window pixels, including the outer UI stretch transform.
	# Only the room is rasterized at low resolution; UI text stays sharp.
	_output_transform = get_viewport().get_final_transform() * get_global_transform_with_canvas()
	var output_scale := _output_transform.get_scale().abs()
	_base_pixel_scale = maxi(1, floori(_available_rect.size.x * output_scale.x / 160.0))
	_apply_pixel_scale(_wanted_zoom())
	animator.scale = Vector2.ONE * presentation_scale
	shadow.scale = Vector2.ONE * presentation_scale
	room_hint.position = render_rect.position + Vector2(20, 6)
	return_button.position = Vector2(size.x - 112, render_rect.position.y + 4)
	return_button.size = Vector2(96, 32)
	if not _camera_initialized:
		_follow_position = Vector2(pet_world.x, RoomLayout.SIZE.y - _visible_world_size().y * 0.5)
		_camera_initialized = true
	_set_camera_center(_follow_position)
	_sync_layers()

func _wanted_zoom() -> int:
	if camera_manual: return zoom_level
	var focused := interaction_focus or focus_left > 0
	var height_pixels := _available_rect.size.y * _output_transform.get_scale().y
	# Keep the whole puppy visible on short screens, even during an interaction.
	return 2 if focused and height_pixels / (_base_pixel_scale * 2) >= 52 else 1

func _apply_pixel_scale(level: int) -> void:
	zoom_level = level
	pixel_scale = _base_pixel_scale * zoom_level
	var transform := _output_transform
	var output_scale := transform.get_scale().abs()
	var origin := (transform * _available_rect.position).ceil()
	var end := (transform * _available_rect.end).floor()
	var available := (end - origin).max(Vector2.ONE)
	var logical_size := (available / pixel_scale).floor().max(Vector2.ONE)
	logical_size = logical_size.min(RoomLayout.SIZE / RoomLayout.PIXEL_SIZE / zoom_level)
	_view_size = Vector2i(logical_size)
	viewport.size = _view_size + Vector2i(2, 2)
	display.region_rect = Rect2(Vector2.ONE, Vector2(_view_size))
	var physical_size := Vector2(_view_size) * pixel_scale
	var physical_origin := (origin + (available - physical_size) * 0.5).floor()
	render_rect = Rect2(transform.affine_inverse() * physical_origin, physical_size / output_scale)
	display.position = render_rect.position
	display.scale = render_rect.size / Vector2(_view_size)
	# Magnification happens after rasterization, so zoom never invents smaller pixels.
	camera.zoom = Vector2.ONE

func _visible_world_size() -> Vector2:
	return Vector2(_view_size) * RoomLayout.PIXEL_SIZE

func _clamp_camera(point: Vector2) -> Vector2:
	var half := _visible_world_size() * 0.5
	return point.clamp(half, RoomLayout.SIZE - half)

func _set_camera_center(point: Vector2) -> void:
	_follow_position = _clamp_camera(point)
	var half := Vector2(_view_size) * 0.5
	# Rasterize on the art grid, then scroll inside the gutter in physical pixels.
	var origin := _follow_position / RoomLayout.PIXEL_SIZE - half
	var screen_origin := (origin * pixel_scale).round() / pixel_scale
	camera.position = screen_origin.floor() + half
	_scroll_offset = screen_origin - screen_origin.floor()
	_scroll_material.set_shader_parameter("camera_offset", _scroll_offset)
	camera.force_update_scroll()

func _clear_ball_from_pet() -> void:
	if absf(ball_world.x - pet_world.x) >= 120: return
	var direction := 1.0 if ball_world.x >= pet_world.x else -1.0
	var x := pet_world.x + direction * 140
	if x < RoomLayout.WALK_AREA.position.x or x > RoomLayout.WALK_AREA.end.x:
		x = pet_world.x - direction * 140
	ball_target = RoomLayout.clamp_walk(Vector2(x, ball_world.y))

func focus_pet(close_up: bool = false) -> void:
	camera_manual = false
	if close_up:
		focus_left = 3.5
		_clear_ball_from_pet()
	return_button.hide()

func set_interaction_focus(value: bool) -> void:
	if value and not interaction_focus:
		focus_pet(false)
		_clear_ball_from_pet()
	interaction_focus = value

func look_at_world(point: Vector2) -> void:
	camera_manual = true
	_set_camera_center(point)
	return_button.show()

func _update_camera(delta: float) -> void:
	if not _camera_initialized or _pointer_id != -1: return
	var wanted_zoom := _wanted_zoom()
	if zoom_level != wanted_zoom: _apply_pixel_scale(wanted_zoom)
	if not camera_manual:
		var y := RoomLayout.SIZE.y - _visible_world_size().y * 0.5
		if zoom_level > 1: y = pet_world.y - _visible_world_size().y * 0.38
		var desired := _clamp_camera(Vector2(pet_world.x, y))
		_set_camera_center(_follow_position.lerp(desired, 1.0 - exp(-6.0 * delta)))
	else:
		_set_camera_center(_follow_position)
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
		_set_camera_center(Vector2(pet_world.x, RoomLayout.SIZE.y - _visible_world_size().y * 0.5))

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
		var speed := WALK_SPEED
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
	# Keep the authored timing. A faster chase needs a separate run clip.
	animator.sprite.speed_scale = 1.0
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
	puppy.position = (pet_world / RoomLayout.PIXEL_SIZE).round() * RoomLayout.PIXEL_SIZE
	ball_art.position = (ball_world / RoomLayout.PIXEL_SIZE).round() * RoomLayout.PIXEL_SIZE
	effect_label.visible = effect_left > 0
	effect_label.position = Vector2(55, -150) * presentation_scale - Vector2(0, (1.7 - effect_left) * 12)
	effect_label.modulate.a = minf(1, effect_left)
	sleep_label.visible = animator.current == "sleep"
	sleep_label.position = Vector2(55, -100) * presentation_scale

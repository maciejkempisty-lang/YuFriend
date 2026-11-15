class_name RoomView
extends Control

signal floor_tapped(world_position: Vector2)
signal care_requested(action: String)
signal destination_reached
signal performance_finished(trial_id: int)
signal station_reached(token: int)
signal sound_requested(effect: String)
signal first_pan
signal ball_thrown(target: Vector2)

const WALK_SPEED := 60.0 * RoomLayout.PUPPY_SCALE
const DRAG_THRESHOLD := 9.0
# The initial bowl-to-ball span, including both silhouettes, fits in 480 world units.
const HOME_FRAME_WIDTH := 480.0
const DECORATION_TOP := 60.0
var animator := PetAnimator.new()
var backdrop := RoomArtwork.new()
var wall_clock := preload("res://scripts/ui/wall_clock.gd").new()
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
var overview_button := Button.new()
var overview := false
var _render_pixel_size := RoomLayout.PIXEL_SIZE
var room_hint := Label.new()
var pet_world: Vector2 = RoomLayout.START
var target_world: Vector2 = RoomLayout.START
var ball_world: Vector2 = RoomLayout.STATIONS.ball.position
var ball_target: Vector2 = ball_world
var moving := false
var mood_walk_speed: float = 1.0
var presentation_scale: float = RoomLayout.PUPPY_SCALE
var hud_bottom := 0.0
var content_bottom := 0.0
var overlay_right := 0.0
var overlay_left := 12.0
var pan_hint_dismissed := false
var prop_bounces: Dictionary = {}
var prop_markers: Dictionary = {}
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
var _step_distance := 0.0
var _ball_was_rolling := false
var ball_throw_enabled := true
var throw_guide := Line2D.new()
var _drag_ball := false
var _throw_target := Vector2.ZERO
var _ball_flight_left := 0.0
var _ball_flight_total := 0.0
var _ball_flight_from := Vector2.ZERO
var _ball_lift := 0.0

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
	world.scale = Vector2.ONE / _render_pixel_size
	backdrop.z_index = -5
	world.add_child(backdrop)
	# Extra floor continues behind the floating controls; gameplay coordinates stay fixed.
	backdrop.configure(Vector2(RoomLayout.SIZE.x, 960))
	wall_clock.position = Vector2(471, 141)
	wall_clock.z_index = -4
	world.add_child(wall_clock)
	world.add_child(actors)
	throw_guide.width = 4
	throw_guide.default_color = Color("fff3be")
	throw_guide.z_index = 10
	world.add_child(throw_guide)
	throw_guide.hide()
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
	for id in ["food", "bed", "ball"]:
		var marker := PanelContainer.new()
		marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var badge := StyleBoxFlat.new()
		badge.bg_color = Color("fff9eddd")
		badge.set_corner_radius_all(12)
		badge.content_margin_left = 4
		badge.content_margin_right = 4
		badge.content_margin_top = 4
		badge.content_margin_bottom = 4
		marker.add_theme_stylebox_override("panel", badge)
		var tap := TextureRect.new()
		tap.texture = GameIcons.texture("gesture", Color("527c51"))
		tap.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tap.custom_minimum_size = Vector2(16, 16)
		tap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		marker.add_child(tap)
		add_child(marker)
		prop_markers[id] = marker
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
	overview_button.text = "Cały pokój"
	overview_button.add_theme_font_size_override("font_size", 12)
	overview_button.pressed.connect(func():
		if overview: focus_pet()
		else: show_overview())
	add_child(overview_button)
	animator.set_skin(load("res://data/skins/puppy_pixel.tres"))
	animator.request_completed.connect(_on_animation_completed)
	animator.clip_started.connect(_on_clip_started)
	resized.connect(update_placement)
	get_viewport().size_changed.connect(update_placement.call_deferred)
	gui_input.connect(_on_input)
	update_placement()

func _on_input(event: InputEvent) -> void:
	if event.device == InputEvent.DEVICE_ID_EMULATION: return
	if event is InputEventScreenTouch:
		if event.pressed: _pointer_down(event.position, event.index)
		else: _pointer_up(event.position, event.index, event.canceled)
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
	_drag_ball = not overview and ball_throw_enabled and action_at(point) == "play"
	_throw_target = ball_world

func _pointer_move(point: Vector2, id: int) -> void:
	if id != _pointer_id: return
	if point.distance_to(_press_point) >= DRAG_THRESHOLD: _dragged = true
	if not _dragged or overview: return
	if _drag_ball:
		var drag := (point - _press_point) / _press_zoom
		_throw_target = RoomLayout.clamp_walk(ball_world + Vector2(drag.x * 2.0, 0))
		var points := PackedVector2Array()
		for index in 13:
			var t := index / 12.0
			points.append(ball_world.lerp(_throw_target, t) - Vector2(0, sin(t * PI) * 65))
		throw_guide.points = points
		throw_guide.show()
		return
	if not pan_hint_dismissed:
		pan_hint_dismissed = true
		room_hint.hide()
		first_pan.emit()
	camera_manual = true
	_set_camera_center(_press_camera - Vector2((point.x - _press_point.x) / _press_zoom, 0))
	return_button.show()

func _pointer_up(point: Vector2, id: int, cancelled: bool = false) -> void:
	if id != _pointer_id: return
	if not cancelled: _pointer_move(point, id)
	_pointer_id = -1
	throw_guide.hide()
	var ball_drag := _drag_ball
	_drag_ball = false
	if cancelled: return
	if ball_drag and _dragged:
		if _throw_target.distance_to(ball_world) >= 40: ball_thrown.emit(_throw_target)
		return
	if not _dragged and render_rect.has_point(point): _interact(point)

func _interact(point: Vector2) -> void:
	if overview:
		look_at_world(screen_to_world(point))
		return
	var action := action_at(point)
	if not action.is_empty():
		var id := RoomLayout.station_id(action)
		if not id.is_empty(): prop_bounces[id] = 0.36
		care_requested.emit(action)
	elif screen_to_world(point).y >= RoomLayout.FLOOR_Y:
		floor_tapped.emit(RoomLayout.clamp_walk(screen_to_world(point)))

func action_at(point: Vector2) -> String:
	if not render_rect.has_point(point): return ""
	for id in prop_markers:
		if prop_markers[id].visible and prop_markers[id].get_rect().has_point(point):
			return RoomLayout.STATIONS[id].action
	var where := screen_to_world(point)
	if ball_touch_rect().has_point(point): return "play"
	# Crate/bowl in front of the puppy keep the same priority as Y-sorted rendering.
	for id in ["toys", "food"]:
		if RoomLayout.STATIONS[id].position.y > pet_world.y and station_bounds(id).has_point(where):
			return RoomLayout.STATIONS[id].action
	if _hits_pet(where): return "rest" if animator.pose == "sleep" else "pet"
	for id in RoomLayout.STATIONS:
		if id != "ball" and station_touch_rect(id).has_point(point): return RoomLayout.STATIONS[id].action
	if Rect2(pet_world - Vector2(100, 190) * presentation_scale, Vector2(200, 200) * presentation_scale).has_point(where): return "pet"
	return ""

func _hits_pet(where: Vector2) -> bool:
	var sprite := animator.sprite
	if sprite.sprite_frames == null: return false
	var texture := sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
	if texture == null: return false
	var pixel := Vector2i(sprite.to_local(where / _render_pixel_size).floor())
	if pixel.x < 0 or pixel.y < 0 or pixel.x >= texture.get_width() or pixel.y >= texture.get_height(): return false
	if sprite.flip_h: pixel.x = texture.get_width() - 1 - pixel.x
	if not _touch_masks.has(texture):
		var mask := BitMap.new()
		mask.create_from_image_alpha(texture.get_image(), 0.5)
		_touch_masks[texture] = mask
	return _touch_masks[texture].get_bitv(pixel)

func camera_center() -> Vector2:
	return (camera.position + _scroll_offset) * _render_pixel_size

func screen_scale() -> Vector2:
	return render_rect.size / Vector2(_view_size) / _render_pixel_size

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
	return world_to_screen(ball_world - Vector2(0, _ball_lift))

func station_touch_rect(id: String) -> Rect2:
	var bounds := _screen_rect(station_bounds(id))
	var target_size := bounds.size.max(Vector2(48, 48))
	return Rect2(bounds.get_center() - target_size / 2, target_size)

func ball_touch_rect() -> Rect2:
	var diameter := maxf(48, 36 * screen_scale().x)
	return Rect2(ball_center() - Vector2.ONE * diameter / 2, Vector2.ONE * diameter)

func station_point(action: String) -> Vector2:
	if action in ["play", "bored"]:
		var direction := 1.0 if ball_target.x >= pet_world.x else -1.0
		return RoomLayout.clamp_walk(ball_target + Vector2(-direction * 70 * presentation_scale, 10))
	return RoomLayout.station(action).get("stand", pet_world)

func update_placement() -> void:
	if not is_inside_tree() or size.x <= 0: return
	_pointer_id = -1
	_drag_ball = false
	throw_guide.hide()
	_available_rect = Rect2(Vector2.ZERO, size)
	# Work in actual window pixels, including the outer UI stretch transform.
	# Only the room is rasterized at low resolution; UI text stays sharp.
	_output_transform = get_viewport().get_final_transform() * get_global_transform_with_canvas()
	var output_scale := _output_transform.get_scale().abs()
	var stage_height := content_bottom if content_bottom > 0 else size.y
	_render_pixel_size = RoomLayout.PIXEL_SIZE
	# Frame roughly two to three room sections instead of filling the height
	# with a small horizontal slice. Interaction still offers a 2x close-up.
	_base_pixel_scale = maxi(1, roundi(size.x * output_scale.x / 200.0))
	if size.y > size.x:
		# Use the largest whole-pixel magnification that still fits both care props.
		_base_pixel_scale = maxi(1, floori(size.x * output_scale.x / (HOME_FRAME_WIDTH / RoomLayout.PIXEL_SIZE)))
	if overview:
		var available_width := size.x * output_scale.x
		_render_pixel_size *= maxf(1, ceil((RoomLayout.SIZE.x / RoomLayout.PIXEL_SIZE) / available_width))
		_base_pixel_scale = maxi(1, floori(available_width / (RoomLayout.SIZE.x / _render_pixel_size)))
		_available_rect = Rect2(0, hud_bottom + 54, size.x, maxf(1, stage_height - hud_bottom - 66))
	world.scale = Vector2.ONE / _render_pixel_size
	_apply_pixel_scale(_wanted_zoom())
	animator.scale = Vector2.ONE * presentation_scale
	shadow.scale = Vector2.ONE * presentation_scale
	room_hint.position = Vector2(20, hud_bottom + 54)
	room_hint.text = "Dotknij miejsca, aby przybliżyć" if overview else "Przesuń pokój ↔"
	overview_button.text = "Do pieska" if overview else "Cały pokój"
	overview_button.position = Vector2(overlay_left, hud_bottom)
	overview_button.size = Vector2(112, 44)
	return_button.position = Vector2((overlay_right if overlay_right > 0 else size.x - 12) - 100, hud_bottom)
	return_button.size = Vector2(100, 44)
	if not _camera_initialized:
		_follow_position = Vector2(pet_world.x, _world_bottom() - _visible_world_size().y * 0.5)
		_camera_initialized = true
	else:
		# Panning is horizontal. Recompose vertically after a tab/device resize,
		# even when the player has paused automatic horizontal following.
		_follow_position.y = _world_bottom() - _visible_world_size().y * 0.5
	_set_camera_center(_follow_position)
	_sync_layers()

func _wanted_zoom() -> int:
	if overview: return 1
	var focused := interaction_focus or focus_left > 0
	var height_pixels := (content_bottom if content_bottom > 0 else size.y) * _output_transform.get_scale().y
	# Keep the whole puppy visible on short screens, even during an interaction.
	var fits := height_pixels / (_base_pixel_scale * 2) >= 60 and size.x * _output_transform.get_scale().x / (_base_pixel_scale * 2) >= 68
	if camera_manual: return 2 if zoom_level == 2 and fits else 1
	return 2 if focused and fits else 1

func _apply_pixel_scale(level: int) -> void:
	zoom_level = level
	pixel_scale = _base_pixel_scale * zoom_level
	var transform := _output_transform
	var output_scale := transform.get_scale().abs()
	var origin := (transform * _available_rect.position).ceil()
	var end := (transform * _available_rect.end).floor()
	var available := (end - origin).max(Vector2.ONE)
	var logical_size := (available / pixel_scale).floor().max(Vector2.ONE)
	logical_size.x = minf(logical_size.x, RoomLayout.SIZE.x / _render_pixel_size)
	if overview: logical_size.y = minf(logical_size.y, RoomLayout.SIZE.y / _render_pixel_size)
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
	return Vector2(_view_size) * _render_pixel_size

func _clamp_camera(point: Vector2) -> Vector2:
	if overview: return RoomLayout.SIZE * 0.5
	var half := _visible_world_size() * 0.5
	# The wall may continue above world zero on tall screens. Keep the floor
	# above the action panel instead of forcing the entire room to the top.
	return Vector2(clampf(point.x, half.x, RoomLayout.SIZE.x - half.x),
		_world_bottom() - half.y)

func _world_bottom() -> float:
	if content_bottom <= 0: return RoomLayout.SIZE.y
	var scene_bottom := content_bottom
	if not overview and size.y > size.x:
		# Place the decorated room beneath the toolbar. Surplus height becomes floor
		# below the puppy instead of a large blank wall above the window.
		var scene_top := hud_bottom + 72.0
		var art_height := (RoomLayout.SIZE.y - DECORATION_TOP) * screen_scale().y
		var spare_height := maxf(0, scene_bottom - scene_top - art_height)
		scene_bottom -= spare_height * 0.75
	return RoomLayout.SIZE.y + maxf(0, size.y - scene_bottom) / screen_scale().y

func _set_camera_center(point: Vector2) -> void:
	_follow_position = _clamp_camera(point)
	var half := Vector2(_view_size) * 0.5
	# Rasterize on the art grid, then scroll inside the gutter in physical pixels.
	var origin := _follow_position / _render_pixel_size - half
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

func show_overview() -> void:
	overview = true
	camera_manual = false
	focus_left = 0
	update_placement()
	return_button.hide()

func focus_pet(close_up: bool = false) -> void:
	overview = false
	camera_manual = false
	if close_up:
		focus_left = 3.5
		_clear_ball_from_pet()
	update_placement()
	return_button.hide()

func set_interaction_focus(value: bool) -> void:
	if value and not interaction_focus:
		focus_pet(false)
		_clear_ball_from_pet()
	interaction_focus = value

func look_at_world(point: Vector2) -> void:
	if overview:
		overview = false
		update_placement()
	camera_manual = true
	_set_camera_center(Vector2(point.x, _world_bottom() - _visible_world_size().y * 0.5))
	return_button.show()

func _update_camera(delta: float) -> void:
	if not _camera_initialized or _pointer_id != -1: return
	var wanted_zoom := _wanted_zoom()
	if zoom_level != wanted_zoom: _apply_pixel_scale(wanted_zoom)
	if not camera_manual:
		var y := _world_bottom() - _visible_world_size().y * 0.5
		var desired := _clamp_camera(Vector2(pet_world.x, y))
		_set_camera_center(_follow_position.lerp(desired, 1.0 - exp(-6.0 * delta)))
	else:
		_set_camera_center(_follow_position)
	return_button.visible = camera_manual and not overview
	room_hint.visible = overview or (not pan_hint_dismissed and not (interaction_focus or focus_left > 0))

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

func throw_ball(target: Vector2, token: int) -> void:
	cancel_activity()
	station_action = "play"
	station_token = token
	ball_target = RoomLayout.clamp_walk(target)
	_ball_flight_from = ball_world
	_ball_flight_total = clampf(ball_world.distance_to(ball_target) / 350.0, 0.3, 1.0)
	_ball_flight_left = _ball_flight_total
	target_world = station_point("play")
	moving = true
	animator.request_clip("walk")
	sound_requested.emit("ball_roll")

func present_invitation(kind: String) -> void:
	if kind in ["tug", "cups"]:
		effect_label.text = "↔" if kind == "tug" else "?"
		effect_left = 2.5

func place_at_station(action: String) -> void:
	anchored_station = action
	pet_world = station_point(action)
	target_world = pet_world
	animator.facing_left = RoomLayout.station(action).get("facing_left", false)
	_sync_layers()
	if not camera_manual:
		_set_camera_center(Vector2(pet_world.x, _world_bottom() - _visible_world_size().y * 0.5))

func cancel_activity() -> void:
	moving = false
	_step_distance = 0.0
	_ball_was_rolling = false
	station_token = 0
	station_action = ""
	anchored_station = ""
	walk_performance = 0
	walk_ready = false
	ball_target = ball_world
	_pointer_id = -1
	_drag_ball = false
	throw_guide.hide()
	_ball_flight_left = 0
	_ball_lift = 0

func play_performance(clip: String, trial_id: int) -> void:
	if clip == "walk" and not moving: move_to(RoomLayout.come_target(pet_world))
	walk_performance = trial_id if clip == "walk" else 0
	walk_ready = false
	animator.request_clip(clip, trial_id)

func _on_animation_completed(trial_id: int) -> void:
	if trial_id == walk_performance: walk_ready = true
	else: performance_finished.emit(trial_id)

func _on_clip_started(clip: String) -> void:
	# Wait for pose transitions and use one trigger for every barking action.
	if clip == "bark_stand": sound_requested.emit("bark")

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
		var speed := WALK_SPEED * mood_walk_speed
		var previous := pet_world
		pet_world = pet_world.move_toward(target_world, speed * delta)
		_step_distance += previous.distance_to(pet_world)
		if _step_distance >= WALK_SPEED * 0.25:
			_step_distance = fmod(_step_distance, WALK_SPEED * 0.25)
			sound_requested.emit("step")
		if pet_world.is_equal_approx(target_world) and _ball_flight_left <= 0:
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
	# Match the walk cycle to the small mood-dependent change in movement speed.
	animator.sprite.speed_scale = mood_walk_speed if animator.current == "walk" else 1.0
	if _ball_flight_left > 0:
		_ball_flight_left = maxf(0, _ball_flight_left - delta)
		var progress := 1.0 - _ball_flight_left / _ball_flight_total
		ball_world = _ball_flight_from.lerp(ball_target, progress)
		_ball_lift = sin(progress * PI) * 65
		if _ball_flight_left <= 0:
			ball_world = ball_target
			_ball_lift = 0
	elif not ball_world.is_equal_approx(ball_target):
		if not _ball_was_rolling: sound_requested.emit("ball_roll")
		_ball_was_rolling = true
		var before := ball_world.x
		ball_world = ball_world.move_toward(ball_target, delta * 290)
		ball_art.roll_phase += (ball_world.x - before) / 12
		ball_art.queue_redraw()
	else:
		_ball_was_rolling = false
	effect_left = maxf(0, effect_left - delta)
	focus_left = maxf(0, focus_left - delta)
	for id in prop_bounces:
		prop_bounces[id] = maxf(0, float(prop_bounces[id]) - delta)
	_update_camera(delta)
	_sync_layers()

func _sync_layers() -> void:
	puppy.position = (pet_world / RoomLayout.PIXEL_SIZE).round() * RoomLayout.PIXEL_SIZE
	ball_art.position = ((ball_world - Vector2(0, _ball_lift)) / RoomLayout.PIXEL_SIZE).round() * RoomLayout.PIXEL_SIZE
	for id in prop_bounces:
		var node: Node2D = ball_art if id == "ball" else station_nodes[id]
		var origin: Vector2 = ball_world if id == "ball" else RoomLayout.STATIONS[id].position
		var lift := sin((1 - float(prop_bounces[id]) / 0.36) * PI) * 10
		if id == "ball": lift += _ball_lift
		node.position = ((origin - Vector2(0, lift)) / RoomLayout.PIXEL_SIZE).round() * RoomLayout.PIXEL_SIZE
	for id in prop_markers:
		var marker: Control = prop_markers[id]
		var bounds := ball_touch_rect() if id == "ball" else _screen_rect(station_bounds(id))
		marker.position = Vector2(bounds.get_center().x - 12, bounds.position.y - 28)
		marker.visible = not overview and marker.position.x >= 4 and marker.position.x + 24 <= size.x - 4 and marker.position.y >= hud_bottom + 44 and marker.position.y + 24 < (content_bottom if content_bottom > 0 else size.y)
	effect_label.visible = effect_left > 0
	effect_label.position = Vector2(55, -150) * presentation_scale - Vector2(0, (1.7 - effect_left) * 12)
	effect_label.modulate.a = minf(1, effect_left)
	sleep_label.visible = animator.current == "sleep"
	sleep_label.position = Vector2(55, -100) * presentation_scale

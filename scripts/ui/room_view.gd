class_name RoomView
extends Control

signal floor_tapped(world_position: Vector2)
signal care_requested(action: String)
signal destination_reached
signal performance_finished(trial_id: int)
signal station_reached(token: int)
signal sound_requested(effect: String)
signal room_viewed(point: Vector2)
signal first_pan
signal ball_thrown(target: Vector2)
signal yard_place_used(id: String)

const WALK_SPEED := 60.0 * RoomLayout.PUPPY_SCALE
const DRAG_THRESHOLD := 9.0
const YARD_COLUMNS := 6
# Small props first, so a sign or flag wins over a bush or lawn behind it.
const YARD_HIT_ORDER := ["outing", "sprinkler", "course", "fetch", "gate", "dig", "garden", "puddle", "shade", "bush_0", "bush_1", "bush_2"]
# The initial bowl-to-ball span, including both silhouettes, fits in 480 world units.
const HOME_FRAME_WIDTH := 480.0
const DECORATION_TOP := 60.0
var animator := PetAnimator.new()
var backdrop := RoomArtwork.new()
var fence_visitor := FenceVisitorView.new()
var ambient_life := AmbientLifeView.new()
var yard_water := YardWaterView.new()
var yard_weather := YardWeatherView.new()
var yard_course := YardCourseView.new()
var yard_rest := YardRestView.new()
var yard_potty := YardPottyView.new()
var jump_motion := PuppyJump.new()
var jump_lift := 0.0
var jump_clip := ""
var water_drops := YardWaterView.new()
var wall_clock := preload("res://scripts/ui/wall_clock.gd").new()
var ball_art := RoomArtwork.new()
var shadow := RoomArtwork.new()
var viewport := SubViewport.new()
var display := Sprite2D.new()
var world := preload("res://scripts/ui/scene_layers.gd").new()
# Compatibility alias used by movement and existing integration tests.
var actors: Node2D = world.middle_ground
var puppy := Node2D.new()
var camera := Camera2D.new()
var yard_markers: Dictionary = {}
var yard_nodes: Dictionary = {}
var yard_sparkles: Dictionary = {}
# Places the player has already tried; untried ones get a quiet twinkle.
var yard_seen: Dictionary = {}
var yard_controls_bottom := 0.0
var hide_phase := ""
var hide_spot := -1
var hide_tail := RoomArtwork.new()
var catch_active := false
var catch_ring := Line2D.new()
var throw_power := Label.new()
var station_nodes: Dictionary = {}
var effect_label := Label.new()
var sleep_label := Label.new()
var return_button := Button.new()
var overview_button := Button.new()
var overview := false
var in_yard := false
var _render_pixel_size := RoomLayout.PIXEL_SIZE
var room_hint := Label.new()
var pet_world: Vector2 = RoomLayout.START
var target_world: Vector2 = RoomLayout.START
var carrying_ball := false
var ball_world: Vector2 = RoomLayout.STATIONS.ball.position
var ball_target: Vector2 = ball_world
var portal_speed := 0.0
var moving := false
var mood_walk_speed: float = 1.0
var presentation_scale: float = RoomLayout.PUPPY_SCALE * 1.15
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
var _pet_frame_bounds: Dictionary = {}
var _step_distance := 0.0
var _ball_was_rolling := false
var ball_throw_enabled := true
var throw_guide := Line2D.new()
var _drag_ball := false
var _throw_target := Vector2.ZERO
var ball_motion := BallMotion.new()
const BALL_HOLD_SECONDS := 2.4
var ball_hold_left := 0.0
var ball_catch_left := 0.0
var ball_catch_precise := false
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
	world.background.add_child(backdrop)
	# Extra floor continues behind the floating controls; gameplay coordinates stay fixed.
	backdrop.configure(Vector2(RoomLayout.SIZE.x, 960))
	for id in RoomLayout.YARD_STATIONS:
		var station := YardStationView.new()
		station.configure(id)
		if YardSpriteLayout.GROUND_ONLY.has(id): station.z_index = -1
		station.hide()
		(world.background if YardSpriteLayout.GROUND_ONLY.has(id) else actors).add_child(station)
		yard_nodes[id] = station
	wall_clock.position = Vector2(607, 81)
	wall_clock.radius = 24
	wall_clock.z_index = -4
	world.background.add_child(wall_clock)
	yard_water.z_index = -2
	yard_water.draw_ground_base = false
	yard_water.hide()
	world.background.add_child(yard_water)
	yard_weather.z_index = -1
	yard_weather.hide()
	world.background.add_child(yard_weather)
	yard_course.draw_sign = false
	yard_course.hide()
	actors.add_child(yard_course)
	yard_rest.z_index = -1
	yard_rest.draw_static = false
	yard_rest.hide()
	world.background.add_child(yard_rest)
	yard_potty.z_index = 2
	yard_potty.hide()
	world.foreground.add_child(yard_potty)
	water_drops.effects_only = true
	water_drops.z_index = 5
	water_drops.hide()
	world.foreground.add_child(water_drops)
	ambient_life.z_index = 0
	actors.add_child(ambient_life)
	fence_visitor.position = YardVisitors.FENCE
	fence_visitor.scale = Vector2.ONE * 1.5
	actors.add_child(fence_visitor)
	throw_guide.width = 4
	throw_guide.default_color = Color("fff3be")
	throw_guide.z_index = 10
	world.foreground.add_child(throw_guide)
	throw_guide.hide()
	throw_power.hide()
	actors.y_sort_enabled = true
	for id in RoomLayout.STATIONS:
		if id == "ball": continue
		var node := RoomArtwork.new()
		node.kind = id
		node.position = RoomLayout.STATIONS[id].position
		# Flat bed and wall fixtures remain behind the puppy, including sleep.
		(world.background if id in ["bed", "window", "door"] else actors).add_child(node)
		station_nodes[id] = node
	catch_ring.width = 4
	catch_ring.default_color = Color("ffe29a")
	var ring := PackedVector2Array()
	for i in 33:
		var angle := i * TAU / 32
		ring.append(Vector2(cos(angle) * 65, sin(angle) * 20 - 8))
	catch_ring.points = ring
	puppy.add_child(catch_ring)
	catch_ring.hide()
	actors.add_child(puppy)
	shadow.kind = "shadow"
	puppy.add_child(shadow)
	puppy.add_child(animator)
	ball_art.kind = "ball"
	actors.add_child(ball_art)
	RenderingServer.frame_pre_draw.connect(_sync_held_ball)
	hide_tail.kind = "hide_tail"
	hide_tail.hide()
	world.foreground.add_child(hide_tail)
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
	throw_power.add_theme_font_size_override("font_size", 14)
	throw_power.add_theme_color_override("font_color", Color("24483d"))
	throw_power.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(throw_power)
	throw_power.hide()
	for id in RoomLayout.YARD_STATIONS:
		var marker := Button.new()
		var entry: Dictionary = RoomLayout.YARD_STATIONS[id]
		marker.text = entry.label
		marker.icon = GameIcons.texture(entry.icon)
		marker.expand_icon = true
		marker.add_theme_constant_override("icon_max_width", 16)
		marker.add_theme_font_size_override("font_size", 12)
		var badge := StyleBoxFlat.new()
		badge.bg_color = Color("fff9eded")
		badge.set_corner_radius_all(10)
		marker.add_theme_stylebox_override("normal", badge)
		marker.custom_minimum_size = Vector2(82, 44)
		marker.pressed.connect(func():
			mark_yard_place(id)
			care_requested.emit("yard_" + id))
		marker.hide()
		add_child(marker)
		yard_markers[id] = marker
		var sparkle := YardSparkle.new()
		sparkle.phase = yard_markers.size() * 0.37
		sparkle.hide()
		add_child(sparkle)
		yard_sparkles[id] = sparkle
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
	# If a LevelProject was loaded, swap procedural RoomArtwork for editor sprites.
	# This runs AFTER station_nodes/yard_nodes exist so we can hide them in one pass.
	_apply_editor_art()
	update_placement()

func _apply_editor_art() -> void:
	var project: Dictionary = RoomLayoutLoader.active_project
	var textures: Dictionary = RoomLayoutLoader.active_textures
	if project.is_empty() or textures.is_empty(): return
	# Hide EVERY handcrafted/procedural piece — editor is the only source of
	# visible content now, besides the puppy itself.
	backdrop.hide()
	ball_art.hide()
	wall_clock.hide()
	ambient_life.hide()
	for id in station_nodes:
		var node = station_nodes[id]
		if node is CanvasItem: node.hide()
	for id in yard_nodes:
		var node = yard_nodes[id]
		if node is CanvasItem: node.hide()
	for id in yard_markers:
		yard_markers[id].hide()
	for id in yard_sparkles:
		yard_sparkles[id].hide()
	for id in prop_markers:
		prop_markers[id].hide()
	var assets_by_id := {}
	for a in project.assets: assets_by_id[a.id] = a
	for level in project.levels:
		for e in level.elements:
			if not textures.has(e.asset): continue
			var sprite := Sprite2D.new()
			sprite.texture = textures[e.asset]
			sprite.centered = false
			var a: Dictionary = assets_by_id[e.asset]
			sprite.scale = Vector2(float(e.width) / float(a.width), float(e.height) / float(a.height))
			sprite.position = Vector2(float(e.x), float(e.y)) - Vector2(float(e.pivot.x), float(e.pivot.y)) * sprite.scale
			sprite.visible = bool(e.get("visible", true))
			sprite.z_index = -4 if e.layer == "background" else (4 if e.layer == "foreground" else 0)
			# Only the current level's sprites should be visible at a time; both
			# home and yard draw into the same world, so hide the off-level ones.
			sprite.set_meta("level_id", level.id)
			sprite.visible = sprite.visible and level.id == "home"
			var layer: Node2D = world.background if e.layer == "background" else (world.foreground if e.layer == "foreground" else actors)
			layer.add_child(sprite)

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
		_throw_target = YardFetch.target(ball_world, drag) if in_yard else RoomLayout.clamp_walk(ball_world + Vector2(drag.x * 2.0, 0))
		if in_yard:
			throw_power.text = ("Siła %d%% · %.1f m" % [roundi(minf(1, drag.length() * 3 / YardFetch.MAX_DISTANCE) * 100), ball_world.distance_to(_throw_target) / 100]).replace(".", ",")
			throw_power.position = Vector2(clampf(point.x - 65, 8, size.x - 145), maxf(hud_bottom + 8, point.y - 50))
			throw_power.show()
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
	return_button.visible = not (in_yard and hide_phase in ["hiding", "guess"])

func _pointer_up(point: Vector2, id: int, cancelled: bool = false) -> void:
	if id != _pointer_id: return
	if not cancelled: _pointer_move(point, id)
	_pointer_id = -1
	throw_guide.hide()
	throw_power.hide()
	var ball_drag := _drag_ball
	_drag_ball = false
	if cancelled: return
	if ball_drag and _dragged:
		if _throw_target.distance_to(ball_world) >= 40: ball_thrown.emit(_throw_target)
		return
	if _dragged and not overview: room_viewed.emit(Vector2(camera_center().x, RoomLayout.FLOOR_Y + 50))
	if not _dragged and render_rect.has_point(point): _interact(point)

func _interact(point: Vector2) -> void:
	if in_yard and hide_phase in ["choose", "guess"]:
		var where := screen_to_world(point)
		for spot in 3:
			if Rect2(350 + spot * 400 - 100, 195, 200, 100).has_point(where):
				care_requested.emit("yard_bush_%d" % spot)
				return
	if overview:
		look_at_world(screen_to_world(point))
		return
	var action := action_at(point)
	if action.begins_with("yard_") and RoomLayout.YARD_STATIONS.has(action.trim_prefix("yard_")):
		mark_yard_place(action.trim_prefix("yard_"))
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
	if in_yard:
		if fence_visitor.visible and visitor_touch_rect().has_point(point): return "visitor"
		if yard_potty.mess and _screen_rect(Rect2(YardPottyView.SPOT - Vector2(24, 36), Vector2(48, 42))).grow(12).has_point(point): return "yard_outing"
		if catch_active and Rect2(pet_world - Vector2(90, 170) * presentation_scale, Vector2(180, 190) * presentation_scale).has_point(where): return "catch"
		if ball_touch_rect().has_point(point): return "play"
		if _hits_pet(where): return "pet"
		var place := yard_place_at(point)
		return "" if place.is_empty() else "yard_" + place
	if ball_touch_rect().has_point(point): return "play"
	var water_center := world_to_screen(HomeDrink.BOWL)
	if water_touch_rect().has_point(point) and point.distance_to(water_center) < point.distance_to(world_to_screen(RoomLayout.STATIONS.food.position - Vector2(0, 22))): return "drink"
	# Crate/bowl in front of the puppy keep the same priority as Y-sorted rendering.
	for id in ["toys", "food"]:
		if RoomLayout.STATIONS[id].position.y > pet_world.y and station_bounds(id).has_point(where):
			return RoomLayout.STATIONS[id].action
	if _hits_pet(where): return "rest" if animator.pose == "sleep" else "pet"
	for id in RoomLayout.STATIONS:
		if id != "ball" and station_touch_rect(id).has_point(point): return RoomLayout.STATIONS[id].action
	if Rect2(pet_world - Vector2(100, 190) * presentation_scale, Vector2(200, 200) * presentation_scale).has_point(where): return "pet"
	return ""

func yard_place_at(point: Vector2) -> String:
	if not in_yard or overview or yard_course.playing or not yard_water.kind.is_empty() or catch_active or not hide_phase.is_empty(): return ""
	for id in YARD_HIT_ORDER:
		# Small props keep a finger-sized target without growing the large bushes.
		var place := _screen_rect(RoomLayout.YARD_STATIONS[id].bounds)
		var target := place.size.max(Vector2(44, 44))
		if Rect2(place.get_center() - target / 2, target).has_point(point): return id
	return ""

func mark_yard_place(id: String) -> void:
	if yard_seen.has(id): return
	yard_seen[id] = true
	yard_place_used.emit(id)
	_sync_layers()

func _hits_pet(where: Vector2) -> bool:
	if not puppy.visible: return false
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

func pet_screen_bounds() -> Rect2:
	var sprite := animator.sprite
	if sprite.sprite_frames == null: return Rect2(pet_position(), Vector2.ZERO)
	var texture := sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
	if texture == null: return Rect2(pet_position(), Vector2.ZERO)
	# Cache the alpha bounds: reading the texture on every UI frame is expensive.
	if not _pet_frame_bounds.has(texture):
		_pet_frame_bounds[texture] = Rect2(texture.get_image().get_used_rect())
	var used: Rect2 = _pet_frame_bounds[texture]
	if sprite.flip_h: used.position.x = texture.get_width() - used.end.x
	var transformed := sprite.get_global_transform() * used
	return _screen_rect(Rect2(transformed.position * _render_pixel_size, transformed.size * _render_pixel_size))

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
	throw_power.hide()
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
	if not overview:
		# A wide/short window must fit the puppy above the panel too. Preserve
		# the normal framing whenever it already fits, using whole art pixels.
		var usable_height := maxf(0, stage_height - hud_bottom - 24) * output_scale.y
		_base_pixel_scale = mini(_base_pixel_scale, maxi(1, floori(usable_height / 80.0)))
		# When an editor project drives the scene, prefer a slightly closer look
		# than the default horizontal slice — but not so close that the player
		# loses the hand-authored room around the puppy. One step of magnification
		# above the native fit is enough.
		if not RoomLayoutLoader.active_project.is_empty():
			var max_by_height := maxi(1, floori(usable_height / 80.0))
			_base_pixel_scale = clampi(_base_pixel_scale + 1, 1, mini(max_by_height, 3))
	if overview:
		var available_width := size.x * output_scale.x
		_render_pixel_size *= maxf(1, ceil((RoomLayout.SIZE.x / RoomLayout.PIXEL_SIZE) / available_width))
		_base_pixel_scale = maxi(1, floori(available_width / (RoomLayout.SIZE.x / _render_pixel_size)))
		var top := maxf(hud_bottom + 54, yard_controls_bottom + ceilf(RoomLayout.YARD_STATIONS.size() / float(YARD_COLUMNS)) * 48) if in_yard else hud_bottom + 54
		_available_rect = Rect2(0, top, size.x, maxf(1, stage_height - top - 12))
	world.scale = Vector2.ONE / _render_pixel_size
	_apply_pixel_scale(_wanted_zoom())
	animator.scale = Vector2.ONE * presentation_scale
	shadow.scale = Vector2.ONE * presentation_scale
	room_hint.position = Vector2(20, hud_bottom + 54)
	room_hint.text = (YardWeather.LABELS[yard_weather.kind] + " · wybierz miejsce" if in_yard else "Dotknij miejsca, aby przybliżyć") if overview else (YardWeather.LABELS[yard_weather.kind] + " · przesuń ↔" if in_yard else "Przesuń pokój ↔")
	overview_button.text = "Do pieska" if overview else ("Całe podwórko" if in_yard else "Cały pokój")
	if overview_button.get_parent() == self:
		overview_button.position = Vector2(overlay_left, hud_bottom)
		overview_button.size = Vector2(112, 44)
	room_hint.visible = in_yard and not pan_hint_dismissed
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
	var height_pixels := maxf(0, (content_bottom if content_bottom > 0 else size.y) - hud_bottom - 24) * _output_transform.get_scale().y
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
	if overview and not in_yard: logical_size.y = minf(logical_size.y, RoomLayout.SIZE.y / _render_pixel_size)
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
		# Bring the puppy closer to the care panel, with a cap on empty wall
		# so tall phones keep the decorated room in the usable scene.
		var scene_top := hud_bottom + 72.0
		var art_height := (RoomLayout.SIZE.y - DECORATION_TOP) * screen_scale().y
		var spare_height := maxf(0, scene_bottom - scene_top - art_height)
		scene_bottom -= spare_height * 0.40
		scene_bottom = minf(scene_bottom, hud_bottom + 160.0 + (RoomLayout.SIZE.y - 75.0) * screen_scale().y)
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
	return_button.visible = not (in_yard and hide_phase in ["hiding", "guess"])

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
	return_button.visible = camera_manual and not overview and not (in_yard and hide_phase in ["hiding", "guess"])
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
	ball_motion.start(ball_world, ball_target)
	_ball_flight_total = ball_motion.duration
	_ball_flight_left = _ball_flight_total
	target_world = station_point("play")
	moving = true
	animator.request_clip("run" if in_yard else "walk")
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
	update_placement()

func start_course_jump(target: Vector2) -> void:
	cancel_activity()
	jump_motion.start(pet_world, target)
	jump_clip = ""

func cancel_activity() -> void:
	if ball_catch_left > 0 or ball_hold_left > 0 or carrying_ball:
		ball_world = RoomLayout.clamp_walk(Vector2(ball_world.x, pet_world.y))
	ball_catch_left = 0
	ball_hold_left = 0
	ball_motion.cancel()
	animator.rotation = 0
	jump_motion.cancel()
	jump_lift = 0
	animator.position.y = 0
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
	throw_power.hide()
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
	if clip not in ["walk", "run"]:
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
	if jump_motion.active():
		var landed := jump_motion.advance(delta)
		var sample := jump_motion.sample()
		pet_world = sample.point
		jump_lift = sample.lift
		if jump_clip != sample.clip:
			jump_clip = sample.clip
			animator.remaining = 0
			animator.request_clip(jump_clip)
		if landed:
			jump_motion.cancel()
			jump_lift = 0
			destination_reached.emit()
	if hide_tail.visible:
		hide_tail.roll_phase += delta
		hide_tail.queue_redraw()
	if moving and animator.current in ["walk", "run"]:
		var difference := target_world - pet_world
		if absf(difference.x) > 0.1: animator.facing_left = difference.x < 0
		var speed := portal_speed if portal_speed > 0 else WALK_SPEED * mood_walk_speed * (2.5 if animator.current == "run" else 1.0)
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
	if ball_motion.running:
		var before := ball_world.x
		var sample := ball_motion.advance(delta)
		_ball_flight_left = maxf(0, ball_motion.duration - ball_motion.elapsed)
		ball_world = sample.point
		_ball_lift = sample.lift
		ball_art.roll_phase += (ball_world.x - before) / 12
		ball_art.queue_redraw()
	elif not ball_world.is_equal_approx(ball_target):
		if not _ball_was_rolling: sound_requested.emit("ball_roll")
		_ball_was_rolling = true
		var before := ball_world.x
		ball_world = ball_world.move_toward(ball_target, delta * 290)
		ball_art.roll_phase += (ball_world.x - before) / 12
		ball_art.queue_redraw()
	else:
		_ball_was_rolling = false
	var hold_delta := delta
	if ball_catch_left > 0:
		hold_delta = maxf(0, delta - ball_catch_left)
		ball_catch_left = maxf(0, ball_catch_left - delta)
		if ball_catch_left == 0:
			ball_hold_left = BALL_HOLD_SECONDS
			animator.remaining = 0
			animator.request_clip("tail_wag_stand")
			animator.rotation = 0
	if ball_hold_left > 0:
		ball_hold_left = maxf(0, ball_hold_left - hold_delta)
		if ball_hold_left == 0 and not carrying_ball:
			var ground := RoomLayout.clamp_walk(Vector2(ball_world.x, pet_world.y))
			ball_target = RoomLayout.clamp_walk(ground + Vector2(-25 if animator.facing_left else 25, 0))
			ball_motion.drop(ground, ball_target, maxf(1, pet_world.y - ball_world.y))
			ball_world = ground
			_ball_flight_total = ball_motion.duration
			_ball_flight_left = ball_motion.duration
			_ball_lift = ball_motion.drop_height
			animator.remaining = 0
			animator.request_clip("idle")
	effect_left = maxf(0, effect_left - delta)
	focus_left = maxf(0, focus_left - delta)
	for id in prop_bounces:
		prop_bounces[id] = maxf(0, float(prop_bounces[id]) - delta)
	_update_camera(delta)
	_sync_layers()

func _sync_layers() -> void:
	for id in yard_nodes:
		yard_nodes[id].set_weather(yard_weather.kind, yard_weather.night)
		# Keep the existing visibility of props while the course is unfolded.
		yard_nodes[id].visible = in_yard and (id not in ["shade", "puddle", "sprinkler"] or not yard_course.playing)
	var garden_art: RoomArtwork = yard_nodes.garden.art
	if garden_art.garden_key != backdrop.garden_key:
		garden_art.garden_key = backdrop.garden_key
		garden_art.garden_state = backdrop.garden_state
		garden_art.queue_redraw()
	yard_potty.visible = in_yard and not yard_course.playing
	yard_rest.visible = in_yard and not yard_course.playing
	yard_course.visible = in_yard
	var catch_t := 1.0 - ball_catch_left / 0.9
	var catch_lift := sin(clampf(catch_t / 0.7, 0, 1) * PI) * (24 if ball_catch_precise else 8) if ball_catch_left > 0 else 0.0
	animator.position.y = -roundf((jump_lift + catch_lift) / 3) * 3
	if ball_catch_left > 0: animator.rotation = sin(catch_t * PI) * (-0.06 if animator.facing_left else 0.06)
	yard_weather.visible = in_yard
	yard_water.wet = yard_weather.kind != "sun" or yard_water.kind == "puddle"
	yard_nodes.puddle.set_puddle_wet(yard_water.wet)
	yard_water.visible = in_yard and not yard_course.playing
	yard_water.pet_world = pet_world
	water_drops.kind = yard_water.kind
	water_drops.phase = yard_water.phase
	water_drops.pet_world = pet_world
	water_drops.visible = in_yard and yard_water.phase in ["splash", "shake"]
	puppy.position = (pet_world / RoomLayout.PIXEL_SIZE).round() * RoomLayout.PIXEL_SIZE
	if carrying_ball or ball_catch_left > 0 or ball_hold_left > 0:
		ball_world = puppy.position + animator.transform * animator.ball_grip_point()
		ball_target = ball_world
		_ball_lift = 0
	_set_ball_held(carrying_ball or ball_catch_left > 0 or ball_hold_left > 0)
	ball_art.position = ((ball_world - Vector2(0, _ball_lift)) / RoomLayout.PIXEL_SIZE).round() * RoomLayout.PIXEL_SIZE
	for id in prop_bounces:
		var node: Node2D = ball_art if id == "ball" else station_nodes[id]
		var origin: Vector2 = ball_world if id == "ball" else RoomLayout.STATIONS[id].position
		var lift := sin((1 - float(prop_bounces[id]) / 0.36) * PI) * 10
		if id == "ball": lift += _ball_lift
		node.position = ((origin - Vector2(0, lift)) / RoomLayout.PIXEL_SIZE).round() * RoomLayout.PIXEL_SIZE
	var editor_art: bool = not RoomLayoutLoader.active_project.is_empty()
	for id in prop_markers:
		var marker: Control = prop_markers[id]
		var bounds := ball_touch_rect() if id == "ball" else _screen_rect(station_bounds(id))
		marker.position = Vector2(bounds.get_center().x - 12, bounds.position.y - 28)
		marker.visible = not editor_art and (not in_yard or id == "ball") and not overview and marker.position.x >= 4 and marker.position.x + 24 <= size.x - 4 and marker.position.y >= hud_bottom + 44 and marker.position.y + 24 < (content_bottom if content_bottom > 0 else size.y)
	puppy.visible = not (in_yard and hide_phase in ["hiding", "guess"])
	if not puppy.visible: return_button.hide()
	hide_tail.visible = in_yard and hide_phase == "guess" and hide_spot >= 0
	if hide_tail.visible: hide_tail.position = Vector2(350 + hide_spot * 400 + 70, 250)
	catch_ring.visible = in_yard and catch_active
	# Places are touched directly in the scene. Labelled buttons appear only on the
	# whole-yard map; in the normal view an untried place gets a quiet twinkle.
	var yard_free := in_yard and not yard_course.playing and yard_water.kind.is_empty() and not catch_active and hide_phase.is_empty()
	for id in yard_nodes:
		yard_nodes[id].highlight.visible = yard_free and not overview and not yard_seen.has(id)
	var lower_limit := (content_bottom - 52 if fence_visitor.visible else content_bottom) if content_bottom > 0 else size.y
	for id in yard_markers:
		var marker: Button = yard_markers[id]
		marker.text = str(int(id.trim_prefix("bush_")) + 1) if id.begins_with("bush_") else ""
		marker.custom_minimum_size = Vector2(44, 44)
		marker.size = Vector2(44, 44)
		var index := RoomLayout.YARD_STATIONS.keys().find(id)
		marker.position = Vector2(12 + (index % YARD_COLUMNS) * (size.x - 68) / (YARD_COLUMNS - 1), maxf(yard_controls_bottom, render_rect.position.y - ceilf(RoomLayout.YARD_STATIONS.size() / float(YARD_COLUMNS)) * 48) + (index / YARD_COLUMNS) * 48)
		marker.accessibility_name = "Sprzątnij kupę" if id == "outing" and yard_potty.mess else RoomLayout.YARD_STATIONS[id].label
		marker.visible = overview and in_yard and not yard_course.playing and yard_water.kind.is_empty() and not catch_active and marker.position.x >= 2 and marker.get_rect().end.x <= size.x - 2 and marker.position.y >= maxf(hud_bottom + 8, yard_controls_bottom) and marker.get_rect().end.y < lower_limit
		var sparkle: Control = yard_sparkles[id]
		var place := _screen_rect(RoomLayout.YARD_STATIONS[id].bounds)
		sparkle.position = Vector2(place.get_center().x - sparkle.size.x / 2, place.position.y - sparkle.size.y - 2)
		sparkle.visible = yard_free and not overview and not yard_seen.has(id) and sparkle.position.x >= 2 and sparkle.position.x + sparkle.size.x <= size.x - 2 and sparkle.position.y >= hud_bottom + 8 and sparkle.position.y + sparkle.size.y < lower_limit
	effect_label.visible = effect_left > 0
	effect_label.position = Vector2(55, -150) * presentation_scale - Vector2(0, (1.7 - effect_left) * 12)
	effect_label.modulate.a = minf(1, effect_left)
	sleep_label.visible = animator.current == "sleep"
	sleep_label.position = Vector2(55, -100) * presentation_scale

func set_yard(enabled: bool) -> void:
	cancel_activity()
	in_yard = enabled
	if not enabled: fence_visitor.present("")
	backdrop.kind = "yard" if enabled else "room"
	backdrop.queue_redraw()
	wall_clock.visible = not enabled
	# Editor sprites carry a level_id meta tag — swap visibility on yard toggle.
	for layer in [world.background, actors, world.foreground]:
		for child in layer.get_children():
			if child is Sprite2D and child.has_meta("level_id"):
				child.visible = (child.get_meta("level_id") == ("yard" if enabled else "home"))
	# Procedural station art stays hidden when the editor project is active;
	# otherwise behave as before.
	var editor_active: bool = not RoomLayoutLoader.active_project.is_empty()
	for node in station_nodes.values():
		node.visible = not enabled and not editor_active
	pet_world = RoomLayout.START
	target_world = pet_world
	ball_world = RoomLayout.STATIONS.ball.position
	ball_target = ball_world
	camera_manual = false
	animator.request_clip("idle")
	_sync_layers()
	_set_camera_center(Vector2(pet_world.x, _world_bottom() - _visible_world_size().y * 0.5))
	update_placement()

func present_hide(phase: String, spot: int) -> void:
	var previous := hide_phase
	hide_phase = phase
	hide_spot = spot
	if previous != phase:
		if phase == "choose": show_overview()
		elif phase == "hiding": look_at_world(Vector2(750, 310))
		elif phase == "walk" and previous == "choose": focus_pet(false)
	_sync_layers()

func reveal_hide(spot: int) -> void:
	cancel_activity()
	pet_world = Vector2(350 + spot * 400, 302)
	target_world = pet_world
	hide_phase = ""
	hide_spot = -1
	look_at_world(pet_world)
	_sync_layers()

func animate_ball_catch(precise: bool) -> void:
	ball_motion.cancel()
	_ball_flight_left = 0
	_ball_lift = 0
	ball_hold_left = 0
	ball_catch_left = 0.9
	ball_catch_precise = precise
	moving = false
	animator.remaining = 0
	animator.request_clip("treat_take_stand")
	_sync_layers()

func water_touch_rect() -> Rect2:
	var center := world_to_screen(HomeDrink.BOWL)
	return Rect2(center - Vector2(22, 22), Vector2(44, 44))

func visitor_touch_rect() -> Rect2:
	var rect := _screen_rect(Rect2(YardVisitors.FENCE - Vector2(35, 95), Vector2(80, 95)))
	var target := rect.size.max(Vector2(44, 44))
	return Rect2(rect.get_center() - target / 2, target)

func _set_ball_held(held: bool) -> void:
	# The muzzle occludes the top of the ball: it is gripped, not floating in front.
	ball_art.z_index = -1 if held else 0
	if ball_art.ball_held != held:
		ball_art.ball_held = held
		ball_art.queue_redraw()

func _sync_held_ball() -> void:
	var held := carrying_ball or ball_catch_left > 0 or ball_hold_left > 0
	_set_ball_held(held)
	if not held: return
	ball_world = puppy.position + animator.transform * animator.ball_grip_point()
	ball_target = ball_world
	_ball_lift = 0
	ball_art.position = (ball_world / RoomLayout.PIXEL_SIZE).round() * RoomLayout.PIXEL_SIZE

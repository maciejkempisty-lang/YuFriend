extends SceneTree

var failed: int = 0
var passed: int = 0
var app: Control
var directory: String

func _initialize() -> void:
	create_timer(45).timeout.connect(func():
		printerr("UI timeout: integration test did not complete")
		quit(1))
	call_deferred("_run")

func check(condition: bool, label: String) -> void:
	if condition:
		passed += 1
		print("PASS UI " + label)
	else:
		failed += 1
		push_error("FAIL UI " + label)

func _run() -> void:
	root.size = Vector2i(390, 844)
	root.content_scale_size = Vector2i(390, 844)
	directory = "user://qa-integration-%s" % Time.get_ticks_usec()
	app = load("res://scenes/Main.tscn").instantiate()
	app.save_path_override = directory + "/pet.json"
	root.add_child(app)
	var game: GameSession = app.session
	game.set_process(false)
	game._brain_left = INF
	app.room.set_process(false)
	app.room.animator.set_process(false)
	await process_frame
	await process_frame
	check(game.pet != null and game.save_ok, "startup creates and saves a puppy")
	check(game.pet.skin == "pixel" and app.room.animator.real_clip and app.room.animator.skin.frames.get_animation_names().size() == 22, "new puppy uses the complete pixel animation pack")
	await capture("01-care.png")
	check_pixel_grid("390 x 844")
	check(app.room.render_rect.end.y <= app.bubble.position.y - 7, "the whole room fits above the message and action panel")
	check(curtain_clears_needs(), "curtain rod stays below need labels with a safe margin")
	var room_draws: int = app.room.backdrop.draw_count
	step_game(0.5)
	await process_frame
	await RenderingServer.frame_post_draw
	check(app.room.backdrop.draw_count == room_draws, "idle animation does not rebuild the static room draw list")
	var contact: float = game.pet.needs.contact
	await click_at(app.room.world_to_screen(app.room.pet_world - Vector2(0, 85) * app.room.presentation_scale))
	check(game.pet.needs.contact > contact and game.last_message.begins_with("Przymyka"), "clicking the puppy pets it exactly once through the room")
	var bond: float = game.pet.bond
	var pet_events: int = game.pet.history[0].events.get("pet", 0)
	check(game.act("pet") and not app.care_buttons.pet.disabled, "immediate repeated petting receives a reaction")
	check(game.pet.bond == bond and game.pet.history[0].events.get("pet", 0) == pet_events, "repeated petting does not farm bond or history during the gain cooldown")
	step_game(2.2)
	game.move_to(Vector2(1300, 310), false)
	check(not app.care_buttons.feed.disabled and not app.care_buttons.play.disabled and not app.care_buttons.clean.disabled, "care controls stay enabled during autonomous walking")
	var hunger: float = game.pet.needs.fullness
	app.care_buttons.feed.pressed.emit()
	check(game.activity == "approach" and game.pet.needs.fullness == hunger, "feeding first sends the puppy to the bowl without granting food")
	wait_for_arrival()
	check(game.activity == "feed" and float(game.pet.needs.fullness) > hunger and app.room.pet_world.distance_to(app.room.station_point("feed")) < 1, "food is granted only after reaching the bowl")
	var fed: float = game.pet.needs.fullness
	game.arrive_at(game._approach_token)
	check(game.pet.needs.fullness == fed, "a repeated arrival cannot duplicate care gains")
	check(game.pet.milestones.has("feed"), "feeding adds real event to journal")
	step_game(1.0)
	await capture("12-feeding.png")
	await click_at(app.room.world_to_screen(app.room.pet_world - Vector2(0, 85) * app.room.presentation_scale))
	check(game.activity == "feed" and game.last_message.contains("zajada"), "touching the eating puppy gives contextual feedback through the room")
	step_game(2.0)
	app.tab_buttons.training.pressed.emit()
	app.trick_buttons.sit.pressed.emit()
	app.guided_button.pressed.emit()
	check(game.training.phase == "attempt", "guided button begins selected sit trial")
	app.command_edit.text = "podaj łapę"
	app._submit_command()
	check(app.selected_trick == "sit" and game.training.trick == "sit", "text command cannot switch an ongoing training trial")
	check(not game.give_reward("praise"), "UI cannot reward before performance")
	game._process(game.training.time_left + 0.05)
	check(game.training.phase == "attempt", "reward waits for completed animation")
	step_game(1.3)
	check(game.training.phase == "reward" and not app.reward_buttons.praise.disabled, "reward controls activate at correct moment")
	await capture("02-training-reward.png")
	check(visible_above_navigation(app.reward_buttons.praise), "reward buttons fit above navigation without scrolling")
	app.reward_buttons.praise.pressed.emit()
	check(float(game.pet.skills.sit.mastery) > 0, "reward button commits learning")
	var learned: float = game.pet.skills.sit.mastery
	check(not game.give_reward("praise") and game.pet.skills.sit.mastery == learned, "repeated click cannot duplicate reward")
	step_game(1.5)
	game.begin_training("sit", true)
	step_game(game.training.time_left + 0.1)
	game.suspend_session()
	check(not game.give_reward("praise"), "backgrounding invalidates reward")
	game.resume_session()
	check(game.pet.skills.sit.mastery == learned, "resume preserves earned progress only")
	app.tab_buttons.journal.pressed.emit()
	await capture("03-journal.png")
	game.rename_pet("Fado")
	app.tab_buttons.care.pressed.emit()
	await capture("04-pixel.png")
	var reloaded := SaveSystem.new(directory + "/pet.json").load_pet()
	check(reloaded.pet.pet_name == "Fado" and reloaded.pet.skin == "pixel" and reloaded.pet.skills.sit.mastery == learned, "reload keeps name, skin and learned command")
	app.room.look_at_world(RoomLayout.STATIONS.bed.position)
	await touch_at(app.room.bed_rect().get_center())
	check(game.activity == "approach" and not game.pet.resting, "touching the bed starts a walk before resting")
	wait_for_arrival()
	check(game.pet.resting and app.room.pet_world.distance_to(app.room.station_point("rest")) < 1, "puppy starts resting inside its bed")
	var energy: float = game.pet.needs.energy
	step_game(4)
	check(game.pet.resting and game.pet.needs.energy > energy, "rest restores energy")
	await capture("13-sleeping.png")
	game.act("rest")
	game.pet.needs.fullness = 60.0
	app.room.look_at_world(RoomLayout.STATIONS.food.position)
	await click_at(app.room.bowl_rect().get_center())
	check(game.activity == "approach", "clicking the bowl starts a new feeding approach")
	wait_for_arrival()
	check(game.activity == "feed" and game.last_message.begins_with("Mała porcja"), "clicking the bowl feeds once after waking and walking")
	step_game(3.2)
	app.room.look_at_world(app.room.ball_world)
	var ball_before: Vector2 = app.room.ball_world
	await touch_at(app.room.ball_center())
	check(game.activity == "approach", "touching the ball starts a chase")
	step_game(0.4)
	check(app.room.ball_world.distance_to(ball_before) > 10, "the ball rolls while the puppy follows it")
	wait_for_arrival()
	check(game.activity == "play", "catching the ball completes play")
	step_game(2.2)
	check(game.pet.history.size() == 1 and int(game.pet.history[0].events.get("feed", 0)) >= 2 and int(game.pet.history[0].events.get("reward_praise", 0)) == 1, "session records care and rewards in the event history")
	game.pet.habits = ["time_evening", "cuddler", "playful", "student"]
	game.pet.needs.contact = 40.0
	game.pet.needs.play = 95.0
	game.pet.fatigue = 90.0
	game._spontaneous(0.0)
	check(game.activity == "habit" and game.last_message.contains("czeka na głaskanie"), "a habit shows up as spontaneous behaviour")
	check(game.act("pet") and game.activity == "pet", "player can answer a habit invitation immediately")
	step_game(2.2)
	game.pet.fatigue = 0.0
	game.pet.skin = "simple"
	game.flush()
	var legacy_state := SaveSystem.new(directory + "/pet.json").load_pet()
	check(legacy_state.pet.skin == "simple" and app.room.animator.skin.pixel_art and app.room.animator.real_clip, "legacy skin field round-trips without switching the pixel presentation")
	await _test_living_room()
	await _test_world_room()
	app._show_profile()
	check(app.profile_traits.text.contains("Przytulas"), "profile lists habits")
	await capture("05-profile.png")
	check(app.profile_dialog.size.y <= root.size.y - 40 and app.profile_dialog.get_ok_button().get_global_rect().end.y <= app.profile_dialog.size.y, "profile dialog and save button fit on screen")
	app.profile_dialog.hide()
	app._show_command()
	await capture("08-command.png")
	check(app.text_dialog.size.y <= root.size.y - 40 and app.text_dialog.get_ok_button().get_global_rect().end.y <= app.text_dialog.size.y, "command dialog and submit button fit on screen")
	app.text_dialog.hide()
	app._select_tab("care")
	var world_before_resize: Vector2 = app.room.pet_world
	var ball_before_resize: Vector2 = app.room.ball_world
	# Wider and narrower layouts exercise the same touch UI.
	root.size = Vector2i(540, 960)
	root.content_scale_size = Vector2i(540, 960)
	await capture("06-wide.png")
	root.size = Vector2i(360, 800)
	root.content_scale_size = Vector2i(360, 800)
	await capture("07-narrow.png")
	var overflowing := []
	_find_overflow(app, overflowing)
	check(overflowing.is_empty(), "narrow controls stay inside viewport: " + str(overflowing))
	check(visible_above_navigation(app.care_buttons.train), "narrow care actions fit above navigation")
	app._select_tab("training")
	await capture("09-narrow-training.png")
	check(visible_above_navigation(app.guided_button), "narrow training actions fit above navigation")
	check(curtain_clears_needs(), "narrow training layout keeps the curtain below the HUD")
	root.size = Vector2i(1080, 2340)
	root.content_scale_size = Vector2i(390, 844)
	app._select_tab("care")
	await capture("20-phone-resolution.png")
	check_pixel_grid("1080 x 2340 with fractional UI stretch")
	# Exercise the actual stretch configuration, without changing the base viewport.
	root.size = Vector2i(1100, 720)
	root.content_scale_size = Vector2i(390, 844)
	app._select_tab("care")
	await capture("10-landscape.png")
	check_pixel_grid("landscape")
	check(app.layout_wide and app.room.size.x <= app.sheet.position.x, "wide window places controls beside the room")
	check(visible_above_navigation(app.care_buttons.train), "wide action panel stays usable")
	root.size = Vector2i(320, 640)
	root.content_scale_size = Vector2i(390, 844)
	app._select_tab("training")
	await capture("11-short-training.png")
	check_pixel_grid("short phone")
	overflowing.clear()
	_find_overflow(app, overflowing)
	check(overflowing.is_empty() and visible_above_navigation(app.guided_button), "small training viewport keeps actions within bounds: " + str(overflowing))
	check(curtain_clears_needs(), "short phone layout keeps curtain clear of need labels")
	app.room.look_at_world(app.room.ball_world)
	check(app.room.action_at(app.room.ball_center()) == "play", "foreground ball remains touchable in the compact room")
	check(app.room.pet_world == world_before_resize and app.room.ball_world == ball_before_resize, "resizing and tab changes preserve puppy and ball world positions")
	# Save warnings must not cover the last action in the panel.
	game.save_ok = false
	app._refresh()
	await process_frame
	check(app.footer_label.visible and app.sheet.get_rect().end.y <= app.footer_label.position.y, "save warning has its own space below actions")
	await capture_panorama()
	game.active = false
	app.queue_free()
	await process_frame
	_cleanup()
	print("UI RESULTS: %d passed, %d failed" % [passed, failed])
	quit(1 if failed else 0)

func _test_living_room() -> void:
	var game: GameSession = app.session
	game.pet.needs.fullness = 20.0
	game.pet.needs.energy = 80.0
	game.pet.needs.play = 80.0
	game._spontaneous(0.0)
	check(game.activity == "approach" and game._pending_action == "hungry", "hungry puppy independently approaches the bowl")
	wait_for_arrival()
	check(game.activity == "need" and game.pet.needs.fullness <= 20 and game.last_message.contains("szczeka"), "asking at the bowl signals hunger without feeding itself")
	check(game.act("pet"), "a need invitation can be answered immediately with petting")
	step_game(1.5)
	game.pet.needs.fullness = 80.0
	game.pet.needs.play = 20.0
	game._spontaneous(0.0)
	wait_for_arrival()
	var ball_before: float = app.room.ball_world.x
	step_game(0.5)
	check(game.activity == "need" and not is_equal_approx(app.room.ball_world.x, ball_before) and game.pet.needs.play <= 20, "bored puppy nudges the ball without granting play rewards")
	step_game(2)
	game.pet.needs.play = 80.0
	game.cooldowns.feed = 0
	game.act("feed")
	var cancelled_token: int = game._approach_token
	var fullness: float = game.pet.needs.fullness
	game.suspend_session()
	game.arrive_at(cancelled_token)
	check(not app.room.moving and game.pet.needs.fullness == fullness, "backgrounding cancels walking and rejects a late care completion")
	game.resume_session()
	game.arrive_at(cancelled_token)
	check(game.activity == "idle" and game.pet.needs.fullness <= fullness, "resuming cannot revive a cancelled care request")
	game.pet.needs.energy = 20.0
	game._spontaneous()
	check(game._pending_action == "rest" and not game.pet.resting, "tired puppy walks to its bed before automatic sleep")
	wait_for_arrival()
	step_game(4)
	check(game.pet.resting and app.room.animator.current == "sleep", "automatic sleep uses the actual sleep clip in the bed")
	var sprite: AnimatedSprite2D = app.room.animator.sprite
	var picture: Texture2D = sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
	var used := picture.get_image().get_used_rect()
	check(used.size.x * sprite.scale.x * app.room.presentation_scale <= app.room.station_bounds("bed").size.x, "sleeping puppy fits within the width of its bed")
	game.pet.needs.energy = 84.0
	step_game(6)
	check(not game.pet.resting and game.activity == "idle", "restored energy automatically wakes the puppy")
	step_game(3)
	check(app.room.animator.pose == "stand", "waking completes the transition back to standing")
	# Flush the pending redraw after viewport resize/zoom before measuring walking.
	await process_frame
	await RenderingServer.frame_post_draw
	var backdrop_draws: int = app.room.backdrop.draw_count
	game.move_to(Vector2(700, 320))
	for i in 3:
		step_game(0.2)
		await process_frame
		await RenderingServer.frame_post_draw
	check(app.room.backdrop.draw_count == backdrop_draws, "walking does not redraw the static room")
	step_game(15)

func _test_world_room() -> void:
	var room: RoomView = app.room
	var game: GameSession = app.session
	room.focus_pet()
	step_game(5)
	var screens := RoomLayout.SIZE.x / (room.viewport.size.x * RoomLayout.PIXEL_SIZE)
	check(screens >= 2 and screens <= 3.01 and RoomLayout.STATIONS.size() == 6, "one world spans two to three screens and holds six stations")
	var sample := Vector2(1090, 310)
	check(room.screen_to_world(room.world_to_screen(sample)).distance_to(sample) < 0.01, "camera screen/world conversion round-trips away from the puppy")
	var bond: float = game.pet.bond
	var pet_before: Vector2 = room.pet_world
	var camera_before: Vector2 = room.camera_center()
	var header_before: Vector2 = app.header.position
	var start := room.world_to_screen(room.pet_world - Vector2(0, 80) * room.presentation_scale)
	await drag_touch(start, start + Vector2(150, 0))
	check(room.camera_manual and room.camera_center().x < camera_before.x - 100, "horizontal touch drag pans the camera across the room")
	check(game.pet.bond == bond and room.pet_world == pet_before and game.activity == "idle", "a drag beginning on the puppy does not pet it or issue a walk")
	check(app.header.position == header_before, "panning leaves the HUD in place")
	var manual_position: Vector2 = room.camera.position
	step_game(1)
	check(room.camera.position == manual_position and room.return_button.visible, "manual browsing stays put until follow is requested")
	await click_at(room.return_button.get_global_rect().get_center())
	step_game(1)
	check(not room.camera_manual and absf(room.camera_center().x - pet_before.x) < 3, "return button smoothly restores puppy following")
	room.ball_world = room.pet_world + Vector2(15, 0)
	room.ball_target = room.ball_world
	game.act("pet")
	step_game(1)
	check(absf(room.ball_world.x - room.pet_world.x) >= 120, "interaction rolls the ball clear of the puppy's paws")
	check(room.zoom_level == 2, "petting brings the camera closer")
	await capture("14-petting-closeup.png")
	check_pixel_grid("petting closeup")
	step_game(4)
	check(room.zoom_level == 1, "camera returns to room scale after the interaction")
	room.look_at_world(Vector2(-10000, 240))
	check(room.screen_to_world(room.render_rect.position).x >= -0.01, "manual pan cannot reveal space beyond the left wall")
	await capture("15-left-room.png")
	await touch_at(room.world_to_screen(Vector2(320, 310)))
	await touch_at(room.world_to_screen(Vector2(370, 310)))
	check(game.activity == "walk" and room.target_world.distance_to(Vector2(370, 310)) < 0.1, "second floor touch redirects an ongoing walk")
	game.act("pet")
	step_game(4)
	room.look_at_world(Vector2(10000, 240))
	check(room.screen_to_world(room.render_rect.end).x <= RoomLayout.SIZE.x + 0.01, "manual pan cannot reveal space beyond the right wall")
	await capture("16-right-room.png")
	game.pet.needs.play = 60.0
	for id in ["window", "toys", "door"]:
		room.look_at_world(RoomLayout.STATIONS[id].position)
		await click_at(room.world_to_screen(room.station_bounds(id).get_center()))
		check(game.activity == "approach" and game._pending_action == id, "world station responds after panning: " + id)
		wait_for_arrival()
		check(room.pet_world.distance_to(room.station_point(id)) < 0.1 and game.activity == "need", "puppy reaches station and shows its behaviour: " + id)
		step_game(3.3)
	var before_auto: float = game.pet.needs.play
	game.show_habit("playful")
	check(game.activity == "approach" and game._pending_action == "toys", "playful habit sends the puppy to its toy basket")
	wait_for_arrival()
	check(game.pet.needs.play <= before_auto, "autonomous station visits do not farm care rewards")
	step_game(3.3)
	game.move_to(Vector2(1090, 290))
	step_game(4)
	room.look_at_world(Vector2(1090, 240))
	check(room.actors.y_sort_enabled and room.puppy.position.y < room.station_nodes.toys.position.y, "shallow movement places the puppy behind the toy basket")
	await capture("17-behind-toys.png")
	game.move_to(Vector2(1090, 328))
	step_game(1)
	check(room.puppy.position.y > room.station_nodes.toys.position.y, "walking closer puts the puppy in front of the basket")
	await capture("18-front-of-toys.png")
	room.focus_pet()
	step_game(1)
	check(game.begin_training("come", true), "come training starts from an arbitrary world position")
	var remaining := 10.0
	while game.training.phase == "attempt" and remaining > 0:
		step_game(0.02)
		remaining -= 0.02
	check(game.training.phase == "reward" and not room.moving and room.zoom_level == 2, "come reward waits for world-space arrival and keeps the closeup")
	game.give_reward("praise")
	step_game(6)

func drag_touch(start: Vector2, end: Vector2) -> void:
	var press := InputEventScreenTouch.new()
	press.position = start
	press.pressed = true
	root.push_input(press, true)
	var drag := InputEventScreenDrag.new()
	drag.position = end
	drag.relative = end - start
	root.push_input(drag, true)
	press = press.duplicate()
	press.position = end
	press.pressed = false
	root.push_input(press, true)
	await process_frame

func wait_for_arrival() -> void:
	var remaining := 40.0
	while app.session.activity == "approach" and remaining > 0:
		step_game(0.02)
		remaining -= 0.02

func curtain_clears_needs() -> bool:
	return app.room.render_rect.position.y >= app.needs_row.get_rect().end.y + 15.9

func click_at(point: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	root.push_input(motion, true)
	var event := InputEventMouseButton.new()
	event.position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	root.push_input(event, true)
	event = event.duplicate()
	event.pressed = false
	root.push_input(event, true)
	await process_frame

func touch_at(point: Vector2) -> void:
	var event := InputEventScreenTouch.new()
	event.position = point
	event.pressed = true
	root.push_input(event, true)
	event = event.duplicate()
	event.pressed = false
	root.push_input(event, true)
	await process_frame

func visible_above_navigation(control: Control) -> bool:
	return control.is_visible_in_tree() and control.get_global_rect().end.y <= app.navigation.position.y and control.get_global_rect().position.y >= 0

func capture(name: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var output := ProjectSettings.globalize_path("res://test-results")
	DirAccess.make_dir_recursive_absolute(output)
	var ignore := FileAccess.open(output.path_join(".gdignore"), FileAccess.WRITE)
	if ignore != null: ignore.close()
	var shot := root.get_texture().get_image()
	if not shot.is_empty():
		shot.save_png(output.path_join(name))

func capture_panorama() -> void:
	var room: RoomView = app.room
	var previous_size: Vector2i = room.viewport.size
	var previous_position: Vector2 = room.camera.position
	var previous_zoom: Vector2 = room.camera.zoom
	room.viewport.size = Vector2i(RoomLayout.SIZE / RoomLayout.PIXEL_SIZE)
	room.camera.position = RoomLayout.SIZE / RoomLayout.PIXEL_SIZE * 0.5
	room.camera.zoom = Vector2.ONE
	room.camera.force_update_scroll()
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	room.viewport.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://test-results/19-panorama.png"))
	room.viewport.size = previous_size
	room.camera.position = previous_position
	room.camera.zoom = previous_zoom
	room.camera.force_update_scroll()

func step_game(seconds: float) -> void:
	var left := seconds
	while left > 0:
		var delta := minf(left, 0.02)
		app.session._process(delta)
		app.room._process(delta)
		app.room.animator._process(delta)
		left -= delta

func _find_overflow(node: Node, result: Array) -> void:
	if node is Control and node.is_visible_in_tree():
		var rect: Rect2 = node.get_global_rect()
		if rect.end.x > app.size.x + 2 and not node is ScrollContainer:
			result.append(str(node.name) + ":" + str(rect.end.x))
	for child in node.get_children():
		if not child is Window and not child is SubViewport: _find_overflow(child, result)

func _cleanup() -> void:
	var absolute := ProjectSettings.globalize_path(directory)
	var dir := DirAccess.open(absolute)
	if dir != null:
		for file in dir.get_files(): DirAccess.remove_absolute(absolute.path_join(file))
		DirAccess.remove_absolute(absolute)

func check_pixel_grid(label: String) -> void:
	var room: RoomView = app.room
	var transform := root.get_final_transform() * room.get_global_transform_with_canvas()
	var size_pixels := room.render_rect.size * transform.get_scale()
	var origin_pixels := transform * room.render_rect.position
	var scale_pixels := size_pixels / Vector2(room.viewport.size)
	check(scale_pixels.is_equal_approx(Vector2.ONE * room.pixel_scale) and origin_pixels.distance_to(origin_pixels.round()) < 0.01 and room.camera.zoom == Vector2.ONE, "room pixels use uniform integer magnification: " + label)
	var offset := room.camera.position - Vector2(room.viewport.size) * 0.5
	check(offset.distance_to(offset.round()) < 0.01, "camera origin stays on the art grid: " + label)
	# Check actual rendered blocks, not only the scale calculation (UI stays high-res).
	var shot := root.get_texture().get_image()
	var start := Vector2i(origin_pixels.round())
	var uniform := true
	var first_mismatch := Vector2i(-1, -1)
	for y in range(room.viewport.size.y / 2, room.viewport.size.y - 2):
		for x in range(2, room.viewport.size.x - 2):
			var point := start + Vector2i(x, y) * room.pixel_scale
			if point.x < 0 or point.y < 0 or point.x + room.pixel_scale > shot.get_width() or point.y + room.pixel_scale > shot.get_height():
				uniform = false
				continue
			var color := shot.get_pixelv(point)
			for dy in room.pixel_scale:
				for dx in room.pixel_scale:
					if shot.get_pixelv(point + Vector2i(dx, dy)) != color:
						uniform = false
						if first_mismatch.x < 0: first_mismatch = point + Vector2i(dx, dy)
	if not uniform:
		print("PIXEL DEBUG ", label, " start=", start, " scale=", room.pixel_scale, " size=", shot.get_size(), " first=", first_mismatch, " room=", transform, " root=", root.get_screen_transform(), " final=", root.get_final_transform(), " mode=", root.content_scale_mode, " filter=", room.display.texture_filter, " parentfilter=", room.texture_filter, " stretch=", root.get_stretch_transform())
	check(uniform, "rendered room contains equal-sized solid pixel blocks: " + label)

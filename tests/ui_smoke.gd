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
	var test_root := OS.get_environment("YUFRIEND_TEST_ROOT")
	directory = ("user://" if test_root.is_empty() else test_root).path_join("qa-integration-%s" % Time.get_ticks_usec())
	app = load("res://scenes/Main.tscn").instantiate()
	app.save_path_override = directory + "/pet.json"
	app.session.local_clock = func(): return 100 * 86400.0 + 12 * 3600.0
	root.add_child(app)
	var game: GameSession = app.session
	game.set_process(false)
	game.initiatives_enabled = false # This suite drives autonomous behaviour explicitly.
	game._brain_left = INF
	app.room.set_process(false)
	app.room.animator.set_process(false)
	await process_frame
	await process_frame
	check(game.pet != null and game.save_ok, "startup creates and saves a puppy")
	check(game.pet.skin == "pixel" and app.room.animator.real_clip and app.room.animator.skin.frames.get_animation_names().size() == 27, "new puppy uses the complete pixel animation pack")
	await _test_music()
	_test_effects()
	await capture("01-care.png")
	check_pixel_grid("390 x 844")
	check(app.room.content_bottom / app.size.y >= 0.74 and app.room.size == app.size, "home room fills the screen with at least 74 percent above care controls")
	check(app.care_buttons.size() == 5 and app.needs_ui.fullness == app.care_buttons.feed, "one row owns both the need level and its action")
	await _test_redesigned_ui()
	await process_frame
	await RenderingServer.frame_post_draw
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
	app._show_tricks()
	await process_frame
	var tricks_dialog: AcceptDialog
	for child in app.get_children():
		if child is AcceptDialog and child.title == "Sztuczki pieska": tricks_dialog = child
	check(tricks_dialog != null and tricks_dialog.visible, "trick catalogue opens")
	var rows := tricks_dialog.get_child(0).get_child(0)
	check(rows.get_child_count() == 10 and rows.get_child(4).disabled, "catalogue lists nine tricks and locks advanced ones")
	await capture("24-trick-catalogue.png")
	tricks_dialog.hide()
	app._choose_trick("sit")
	app._celebrate_mastery()
	await process_frame
	for child in app.get_children():
		if child is AcceptDialog and child.title == "Umiem!":
			check(child.dialog_text.contains("Leżeć"), "celebration names the unlocked trick")
			await capture("25-mastery.png")
			child.hide()
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
	check(not app.bubble.visible and app.sheet.size.y <= 280, "training uses a compact panel without a duplicate bubble over the puppy")
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
	check(float(app.room.prop_bounces.get("ball", 0)) > 0, "touching the ball starts a brief visual bounce")
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
	check(game.activity == "walk" and game._sequence_id == "patrol", "weighted choice starts an interruptible behavior sequence")
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
	check(app.profile_badges.get_children().any(func(badge): return badge.text.contains("Ochota na pieszczoty")), "profile lists habits as badges")
	check(app.profile_life.text.contains("Małe dziwactwa") and app.profile_life.text.contains(LifeSystem.mood_label(game.pet)), "profile includes quirks and daily mood")
	await capture("05-profile.png")
	check(app.profile_dialog.size.y <= root.size.y - 40 and app.profile_dialog.get_ok_button().get_global_rect().end.y <= app.profile_dialog.size.y, "profile dialog and save button fit on screen")
	app.profile_dialog.hide()
	app._show_command()
	await capture("08-command.png")
	check(app.text_dialog.size.y <= root.size.y - 40 and app.text_dialog.get_ok_button().get_global_rect().end.y <= app.text_dialog.size.y, "command dialog and submit button fit on screen")
	app.text_dialog.hide()
	await _test_life_ui()
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
	check(visible_above_navigation(app.care_buttons.feed), "narrow care actions fit above navigation")
	app._select_tab("training")
	await capture("09-narrow-training.png")
	check(visible_above_navigation(app.guided_button), "narrow training actions fit above navigation")
	check(app.header.get_rect().end.y < app.sheet.position.y, "narrow training keeps space for the puppy below the HUD")
	root.size = Vector2i(1080, 2340)
	root.content_scale_size = Vector2i(390, 844)
	app._select_tab("care")
	await capture("20-phone-resolution.png")
	check_pixel_grid("1080 x 2340 with fractional UI stretch")
	var phone_safe := Rect2(32, 47, app.size.x - 60, app.size.y - 81)
	app.safe_area_override = root.get_final_transform() * phone_safe
	app._fit_room()
	await process_frame
	check(app.safe_rect.position.distance_to(phone_safe.position) < 0.01 and app.safe_rect.size.distance_to(phone_safe.size) < 0.01, "physical safe-area insets convert correctly through fractional high-DPI scaling")
	check(app.header.position.x >= phone_safe.position.x and app.header.get_rect().end.x <= phone_safe.end.x and app.navigation.get_rect().end.x <= phone_safe.end.x and app.navigation.get_rect().end.y <= phone_safe.end.y, "left, right and bottom insets keep controls clear on a high-DPI phone")
	app.safe_area_override = Rect2()
	app._fit_room()
	await _test_slow_pan()
	# Exercise the actual stretch configuration, without changing the base viewport.
	root.size = Vector2i(1100, 720)
	root.content_scale_size = Vector2i(390, 844)
	app._select_tab("care")
	await capture("10-landscape.png")
	check_pixel_grid("landscape")
	check(app.layout_wide and app.room.size.x <= app.sheet.position.x, "wide window places controls beside the room")
	check(visible_above_navigation(app.care_buttons.feed), "wide action panel stays usable")
	root.size = Vector2i(320, 640)
	root.content_scale_size = Vector2i(390, 844)
	app._select_tab("training")
	await capture("11-short-training.png")
	check_pixel_grid("short phone")
	overflowing.clear()
	_find_overflow(app, overflowing)
	check(overflowing.is_empty() and visible_above_navigation(app.guided_button), "small training viewport keeps actions within bounds: " + str(overflowing))
	check(app.header.get_rect().end.y < app.sheet.position.y, "short phone keeps training below the HUD")
	app.room.look_at_world(app.room.ball_world)
	check(app.room.action_at(app.room.ball_center()) == "play", "foreground ball remains touchable in the compact room")
	check(app.room.pet_world == world_before_resize and app.room.ball_world == ball_before_resize, "resizing and tab changes preserve puppy and ball world positions")
	await _test_training_visibility()
	await _test_phone_framing()
	await _test_room_overview()
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

func _test_life_ui() -> void:
	var game: GameSession = app.session
	var original_name := game.pet.pet_name
	game.pet.pet_name = "Gloria"
	game.pet.life.quirks = ["window_watch", "ball_guard"]
	game.pet.life.discovered = []
	game.pet.life.observations = {}
	for index in 3:
		game._approach("window", true)
		wait_for_arrival()
		step_game(3.1)
	check(game.pet.life.discovered.has("window_watch") and game.pet.milestones.has("quirk_window_watch"), "visiting the window reveals the corresponding quirk through gameplay")
	app._show_profile()
	check(app.profile_life.text.contains("Patrol przy oknie") and app.profile_life.text.contains("Jeszcze nieznane"), "profile separates a discovered quirk from a hidden one")
	await capture("22-life-profile.png")
	app.profile_dialog.hide()
	game.pet.life.mood = "sleepy"
	app._refresh()
	var slow: float = app.room.mood_walk_speed
	game.pet.life.mood = "playful"
	app._refresh()
	check(slow < app.room.mood_walk_speed and app.care_status.text.contains("Ochota na psoty"), "daily mood reaches both care status and room movement")
	game.suspend_session()
	game.pet.last_seen_at = Time.get_unix_time_from_system() - 3600
	game.pet.life.away_report = {}
	game.resume_session()
	check(app.reunion_dialog.visible and app.reunion_text.text.contains("Gloria") and app.reunion_text.text.contains("Albumie"), "return presents the dog-specific story")
	await capture("23-life-reunion.png")
	check(app.reunion_dialog.size.y <= root.size.y - 40, "return story fits the phone viewport")
	app.reunion_dialog.hide()
	app._select_tab("journal")
	await capture("24-life-album.png")
	check(game.pet.journal[0].title == "Kiedy Cię nie było" and app.journal_list.get_child_count() == game.pet.journal.size(), "return story is also available in the album")
	game.suspend_session()
	game.resume_session()
	check(not app.reunion_dialog.visible, "a quick resume does not reopen the same story")
	game.pet.pet_name = original_name
	game._brain_left = INF

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
	game._cancel_motion()
	game.activity = "idle"
	game.activity_left = 0
	game._brain_left = INF
	game.player_activity()
	room.pet_world = RoomLayout.START
	room.target_world = RoomLayout.START
	room.play_clip("idle")
	room.focus_pet()
	step_game(5)
	var screens := RoomLayout.SIZE.x / (room._view_size.x * RoomLayout.PIXEL_SIZE)
	check(screens >= 2 and screens <= 10 and RoomLayout.STATIONS.size() == 6, "enlarged room retains its six stations and horizontal panorama")
	var sample := Vector2(1090, 310)
	check(room.screen_to_world(room.world_to_screen(sample)).distance_to(sample) < 0.01, "camera screen/world conversion round-trips away from the puppy")
	var bond: float = game.pet.bond
	var pet_before: Vector2 = room.pet_world
	var camera_before: Vector2 = room.camera_center()
	var header_before: Vector2 = app.header.position
	var start := room.world_to_screen(room.pet_world - Vector2(0, 80) * room.presentation_scale)
	await drag_touch(start, start + Vector2(150, 0))
	check(room.camera_manual and room.camera_center().x < camera_before.x - 50, "horizontal touch drag pans the camera across the room")
	check(game.pet.bond == bond and room.pet_world == pet_before and game.activity == "idle", "a drag beginning on the puppy does not pet it or issue a walk")
	check(app.header.position == header_before, "panning leaves the HUD in place")
	check(room.pan_hint_dismissed and not room.room_hint.visible, "first drag permanently dismisses the room hint")
	var config := ConfigFile.new()
	config.load(app.ui_settings_path)
	check(config.get_value("tutorial", "room_dragged", false), "first-drag preference is saved for the next launch")
	room.pan_hint_dismissed = false
	app._load_ui_preferences()
	check(room.pan_hint_dismissed and not room.room_hint.visible, "reloading UI preferences does not repeat the tutorial")
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
	check(room.focus_left > 0 and room.zoom_level == room._wanted_zoom(), "petting focuses the puppy without cropping it in the enlarged room")
	await capture("14-petting-closeup.png")
	check_pixel_grid("petting closeup")
	step_game(4)
	check(room.zoom_level == 1, "camera returns to room scale after the interaction")
	room.look_at_world(Vector2(-10000, 240))
	check(room.screen_to_world(room.render_rect.position).x >= -0.01, "manual pan cannot reveal space beyond the left wall")
	await capture("15-left-room.png")
	var floor_x := room.screen_to_world(room.render_rect.end).x - 30
	var floor_y := room.screen_to_world(Vector2(0, room.content_bottom - 12)).y
	await touch_at(room.world_to_screen(Vector2(floor_x - 30, floor_y)))
	await touch_at(room.world_to_screen(Vector2(floor_x, floor_y)))
	check(game.activity == "walk" and room.target_world.distance_to(RoomLayout.clamp_walk(Vector2(floor_x, floor_y))) < 0.1, "second floor touch redirects an ongoing walk")
	game.act("pet")
	step_game(4)
	room.look_at_world(Vector2(10000, 240))
	check(room.screen_to_world(room.render_rect.end).x <= RoomLayout.SIZE.x + 0.01, "manual pan cannot reveal space beyond the right wall")
	await capture("16-right-room.png")
	game.pet.needs.play = 60.0
	for id in ["window", "toys", "door"]:
		room.look_at_world(RoomLayout.STATIONS[id].position)
		await click_at(room.world_to_screen(room.station_bounds(id).get_center()))
		if id == "door":
			check(game.in_yard and room.in_yard, "door enters the yard")
			app._toggle_yard()
			check(not game.in_yard and room.station_nodes.food.visible, "return restores indoor stations")
			continue
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
	check(game.training.phase == "reward" and not room.moving and room.interaction_focus, "come reward waits for world-space arrival and keeps focus")
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
		app._process(delta)
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
	var scale_pixels := size_pixels / Vector2(room._view_size)
	check(scale_pixels.is_equal_approx(Vector2.ONE * room.pixel_scale) and origin_pixels.distance_to(origin_pixels.round()) < 0.01 and room.camera.zoom == Vector2.ONE, "room pixels use uniform integer magnification: " + label)
	var offset := room.camera.position - Vector2(room.viewport.size) * 0.5
	check(offset.distance_to(offset.round()) < 0.01, "camera origin stays on the art grid: " + label)
	# Check actual rendered blocks, not only the scale calculation (UI stays high-res).
	var shot := root.get_texture().get_image()
	var start := Vector2i((origin_pixels - room._scroll_offset * room.pixel_scale).round())
	var uniform := true
	var first_mismatch := Vector2i(-1, -1)
	for y in range(room._view_size.y / 2, room._view_size.y - 2):
		for x in range(2, room._view_size.x - 2):
			var point := start + Vector2i(x, y) * room.pixel_scale
			if point.x < 0 or point.y < 0 or point.x + room.pixel_scale > shot.get_width() or point.y + room.pixel_scale > shot.get_height():
				uniform = false
				continue
			var block := Rect2(Vector2(point), Vector2.ONE * room.pixel_scale)
			var under_ui := false
			for control in [app.yard_toolbar, app.header, app.sheet, app.navigation, app.bubble, app.companion_card, app.gain_label, app.footer_label, room.return_button, room.overview_button, room.room_hint] + room.prop_markers.values():
				if control.is_visible_in_tree():
					var ui_rect: Rect2 = root.get_final_transform() * control.get_global_rect().grow(24)
					if ui_rect.intersects(block): under_ui = true
			if under_ui: continue
			var color := shot.get_pixelv(point)
			for dy in room.pixel_scale:
				for dx in room.pixel_scale:
					if shot.get_pixelv(point + Vector2i(dx, dy)) != color:
						uniform = false
						if first_mismatch.x < 0: first_mismatch = point + Vector2i(dx, dy)
	if not uniform:
		print("PIXEL DEBUG ", label, " start=", start, " scale=", room.pixel_scale, " size=", shot.get_size(), " first=", first_mismatch, " room=", transform, " root=", root.get_screen_transform(), " final=", root.get_final_transform(), " mode=", root.content_scale_mode, " filter=", room.display.texture_filter, " parentfilter=", room.texture_filter, " stretch=", root.get_stretch_transform())
	check(uniform, "rendered room contains equal-sized solid pixel blocks: " + label)

func _test_slow_pan() -> void:
	var room: RoomView = app.room
	room.look_at_world(Vector2(700, 300))
	var start := room.render_rect.get_center()
	room._pointer_down(start, 12)
	room._pointer_move(start + Vector2(15, 0), 12)
	var physical_scale := (root.get_final_transform() * room.get_global_transform_with_canvas()).get_scale().x
	var previous := room.world_to_screen(Vector2(700, 300)).x
	var smooth := true
	for i in range(1, 25):
		room._pointer_move(start + Vector2(15 + i / physical_scale, 0), 12)
		var current := room.world_to_screen(Vector2(700, 300)).x
		if absf((current - previous) * physical_scale - 1.0) > 0.02: smooth = false
		previous = current
	check(smooth, "slow drag advances every physical pixel instead of whole enlarged art pixels")
	await process_frame
	await RenderingServer.frame_post_draw
	var before_image := root.get_texture().get_image()
	var patch := Vector2i((root.get_final_transform() * room.world_to_screen(Vector2(740, 195))).round())
	room._pointer_move(start + Vector2(15 + 25 / physical_scale, 0), 12)
	await process_frame
	await RenderingServer.frame_post_draw
	var after_image := root.get_texture().get_image()
	var image_shifted := true
	for y in range(-20, 20):
		for x in range(-20, 20):
			var point := patch + Vector2i(x, y)
			if before_image.get_pixelv(point) != after_image.get_pixelv(point + Vector2i(1, 0)): image_shifted = false
	check(image_shifted, "rendered background translates by exactly one physical pixel during slow drag")
	previous = room.world_to_screen(Vector2(700, 300)).x
	room._pointer_up(start + Vector2(15 + 25 / physical_scale, 0), 12)
	step_game(0.2)
	check(absf(room.world_to_screen(Vector2(700, 300)).x - previous) < 0.01, "releasing a slow drag does not snap the camera back")
	await capture("21-smooth-pan.png")
	check_pixel_grid("subpixel camera phase")

func _test_music() -> void:
	check(app.music.stream.get_length() > 107 and app.music.stream.get_length() < 108 and app.music.stream.loop_mode == AudioStreamWAV.LOOP_FORWARD, "provided video2 audio is imported at full length with looping")
	app.music.seek(app.music.stream.get_length() - 0.1)
	await create_timer(0.4).timeout
	check(app.music.playing and app.music.get_playback_position() < 2, "music crosses the loop boundary without stopping")
	app._notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	check(app.music.stream_paused, "backgrounding the app pauses its music")
	app._notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	check(not app.music.stream_paused, "returning to the app resumes enabled music")
	app.music_toggle.button_pressed = false
	var restored := BackgroundMusic.new()
	root.add_child(restored)
	restored.start(app.music.settings_path)
	check(not restored.enabled and restored.stream_paused, "profile music switch persists across reloads")
	restored.free()
	app._notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	app._notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	check(app.music.stream_paused, "returning to the app respects music disabled in profile")
	app.music_toggle.button_pressed = true

func _test_effects() -> void:
	var loaded_count := 0
	var valid_recordings: bool = app.effects.recordings.size() == 11
	for id in SoundEffects.GROUPS:
		var variants: Array = app.effects.recordings.get(id, [])
		valid_recordings = valid_recordings and variants.size() == maxi(1, SoundEffects.GROUPS[id][1])
		for recording in variants:
			loaded_count += 1
			valid_recordings = valid_recordings and recording is AudioStreamWAV and recording.mix_rate == 48000 and not recording.stereo and recording.loop_mode == AudioStreamWAV.LOOP_DISABLED and recording.get_length() > 0 and recording.get_length() <= 3
	check(valid_recordings and loaded_count == 22, "all 22 production effects load in 11 groups as short mono 48 kHz one-shots")
	check(app.effects.recordings["step"].all(func(recording): return recording.get_length() <= 0.17), "footstep one-shots end before the next walking contact")
	var heard: Array[String] = []
	var game := GameSession.new()
	root.add_child(game)
	game.set_process(false)
	game.start(directory + "/effects-pet.json")
	game.sound_requested.connect(func(id: String): heard.append(id))
	game.pet.needs.fullness = 100
	check(not game.act("feed") and heard.is_empty(), "rejected care does not request an effect")
	game.pet.needs.fullness = 40
	game.act("feed")
	check(heard.is_empty(), "food does not crunch while the puppy is still walking to the bowl")
	game.arrive_at(game._approach_token)
	game.arrive_at(game._approach_token)
	check(heard == ["eat"], "arrival requests eating audio once, matching the actual meal")
	game.act("pet")
	check(heard == ["eat"], "petting a busy eating puppy does not play a misleading stroke")
	game._process(3)
	game.act("pet")
	check(heard == ["eat", "pet", "pet_happy"], "accepted petting requests a fur stroke and a happy puppy squeak")
	heard.clear()
	game.give_reward("treat")
	game.training.phase = "reward"
	game.training.time_left = 1
	game.training.trick = "sit"
	game.give_reward("treat")
	game.give_reward("treat")
	check(heard == ["success", "treat"], "only one valid training reward requests success and treat sounds")
	game.free()

	var room := RoomView.new()
	room.size = Vector2(390, 430)
	root.add_child(room)
	room.set_process(false)
	room.animator.set_process(false)
	var movement: Array[String] = []
	room.sound_requested.connect(func(id: String): movement.append(id))
	room.move_to(room.pet_world + Vector2(50, 0))
	room.play_clip("walk")
	room._process(0.26)
	room.cancel_activity()
	room._process(1)
	check(movement == ["step"], "steps follow actual world movement and stop when movement is cancelled")
	movement.clear()
	room.ball_target = room.ball_world + Vector2(100, 0)
	room._process(0.1)
	room._process(0.1)
	check(movement == ["ball_roll"], "one rolling sound starts per continuous ball movement")
	room.free()

	var sounds := SoundEffects.new()
	root.add_child(sounds)
	sounds.start(directory + "/audio-test.cfg")
	sounds.recordings.clear()
	check(not sounds.play_effect("eat") and not sounds.play_effect("unknown"), "missing and unknown effects remain safely silent")
	# A silent one-second fixture tests the mixer without depending on production recordings.
	var fixture := AudioStreamWAV.new()
	fixture.format = AudioStreamWAV.FORMAT_16_BITS
	fixture.mix_rate = 44100
	var bytes := PackedByteArray()
	bytes.resize(88200)
	fixture.data = bytes
	for id in ["eat", "pet", "brush", "step", "bark"]: sounds.recordings[id] = [fixture]
	check(sounds.play_effect("pet") and not sounds.play_effect("pet"), "rapid repeated effects are rate limited")
	var filled := sounds.play_effect("eat") and sounds.play_effect("brush") and sounds.play_effect("step")
	check(filled and not sounds.play_effect("bark") and sounds.players.size() == SoundEffects.MAX_VOICES, "effect playback has a bounded voice pool")
	sounds.set_backgrounded(true)
	check(not sounds.players.any(func(player): return player.playing) and not sounds.play_effect("bark"), "backgrounding stops effects and rejects new playback")
	sounds.set_backgrounded(false)
	check(not sounds.players.any(func(player): return player.playing), "returning does not replay stale one-shot effects")
	sounds.free()
	app.effects_toggle.button_pressed = false
	app.music_toggle.button_pressed = false
	var config := ConfigFile.new()
	config.load(app.music.settings_path)
	check(not config.get_value("audio", "music_enabled", true) and not config.get_value("audio", "effects_enabled", true), "music and effects switches preserve each other's preferences")
	app.music_toggle.button_pressed = true
	var restored := SoundEffects.new()
	root.add_child(restored)
	restored.start(app.music.settings_path)
	check(not restored.enabled and not restored.play_effect("pet"), "effects mute persists independently when music is enabled again")
	restored.free()
	app.effects_toggle.button_pressed = true

func _test_redesigned_ui() -> void:
	var game: GameSession = app.session
	var original := game.pet.needs.duplicate()
	game.pet.needs.fullness = 21.0
	app._refresh()
	check(app.care_buttons.feed.need_value == 21 and app.care_buttons.feed.caption == "Głód", "low need has a readable percentage and a status caption")
	check(NeedIndicator.level_color(35) != NeedIndicator.level_color(100) and NeedIndicator.level_color(20) != NeedIndicator.level_color(35), "critical, medium and satisfied needs use distinct colors")
	game.cooldowns.feed = 6.0
	app._refresh()
	check(is_equal_approx(app.care_buttons.feed.cooldown_ratio, 0.6) and not app.care_buttons.feed.disabled, "cooldown drains the button fill while keeping explanation available")
	app._care_action("feed")
	check(app.bubble.visible and not app.message_label.text.is_empty(), "tapping a waiting action provides visible feedback")
	game.cooldowns.clear()
	game.pet.needs = original
	app._show_feedback("Krótka wiadomość")
	app._process(7)
	check(not app.bubble.visible, "speech bubble expires without waiting for another action")
	app._show_gain("feed", {"fullness": 5.5})
	check(app.gain_label.text.contains("+6") and app.needs_ui.fullness.flash_left > 0, "actual capped care gain floats above the puppy and flashes its need")
	app._process(2)
	check(not app.gain_label.visible, "floating gain also expires")
	check(app.room.ball_touch_rect().size.x >= 48 and app.room.station_touch_rect("food").size.y >= 48, "ball and bowl keep at least 48 point touch targets")
	app.name_label.pressed.emit()
	check(app.profile_dialog.visible and not app.settings_dialog.visible and not app.music_toggle.is_visible_in_tree(), "name opens the dog card without audio settings")
	app.profile_dialog.hide()
	app._show_settings()
	check(app.settings_dialog.visible and app.music_toggle.is_visible_in_tree() and not app.name_edit.is_visible_in_tree(), "gear opens separate immediately saved settings")
	await capture("22-settings.png")
	app.settings_dialog.hide()
	app._select_tab("journal")
	check(app.sheet.size.y > app.size.y * 0.85 and not app.header.visible, "album uses a full-height card")
	check(app._journal_icon("feed") != app._journal_icon("rest") and app._journal_icon("first_sit") == "spark", "album distinguishes care, sleep and learning events")
	app._select_tab("training")
	game.pet.milestones.erase("favorite_reward")
	app._refresh()
	check(not app.reward_buttons.values().any(func(button): return button.favorite), "undiscovered favorite does not bias any reward")
	game.pet.milestones.append("favorite_reward")
	app._refresh()
	check(app.reward_buttons[game.pet.favorite_reward].favorite and app.reward_buttons.values().filter(func(button): return button.favorite).size() == 1, "exactly the discovered favorite is highlighted")
	game.pet.milestones.erase("favorite_reward")
	app.guidance_toggle.button_pressed = false
	check(app.guided_button.text == "Powiedz komendę" and app.training_hint.text.contains("pamięta"), "guidance switch explains independent recall")
	app.guidance_toggle.button_pressed = true
	app._select_tab("care")
	# Convert synthetic device insets through the same physical-to-UI transform.
	var transform := root.get_final_transform()
	app.safe_area_override = transform * Rect2(0, 47, app.size.x, app.size.y - 81)
	app._fit_room()
	await process_frame
	check(app.header.position.y >= 47 and app.navigation.get_rect().end.y <= app.size.y - 34, "notch and home-indicator insets protect floating controls")
	app._show_profile()
	await process_frame
	check(app.profile_dialog.position.y - 34 >= 47 and app.profile_dialog.position.y + app.profile_dialog.size.y <= app.size.y - 34, "dog card and its title fit inside the safe area")
	app.profile_dialog.hide()
	await capture("23-safe-area.png")
	app.safe_area_override = Rect2()
	app._fit_room()
	app._refresh()
	app.room.camera_manual = true
	app.room.zoom_level = 2
	app._fit_room()
	check(app.room.zoom_level == app.room._wanted_zoom() and app.room.pet_position().y < app.sheet.position.y - 20, "resizing a manually panned closeup reframes the puppy above care controls")
	app.room.focus_pet()

func _puppy_screen_bounds() -> Rect2:
	var sprite: AnimatedSprite2D = app.room.animator.sprite
	var texture: Texture2D = sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
	var used := Rect2(texture.get_image().get_used_rect())
	if sprite.flip_h: used.position.x = texture.get_width() - used.end.x
	var start: Vector2 = app.room.world_to_screen(sprite.to_global(used.position) * RoomLayout.PIXEL_SIZE)
	var end: Vector2 = app.room.world_to_screen(sprite.to_global(used.end) * RoomLayout.PIXEL_SIZE)
	return Rect2(start, end - start)

func _test_training_visibility() -> void:
	var game: GameSession = app.session
	game._cancel_motion()
	game.activity = "idle"
	game.activity_left = 0
	game.pet.resting = false
	game.pet.fatigue = 0
	game.training.trick = "sit"
	app._select_tab("training")
	for layout in [Vector2i(390, 844), Vector2i(360, 800), Vector2i(320, 640), Vector2i(1080, 2340)]:
		root.size = layout
		root.content_scale_size = Vector2i(390, 844) if layout.x in [320, 1080] else layout
		await process_frame
		await process_frame
		if layout.x == 1080:
			app.safe_area_override = root.get_final_transform() * Rect2(0, 47, app.size.x, app.size.y - 81)
		app._fit_room()
		for phase in ["idle", "attempt", "reward"]:
			game.training.phase = phase
			game.training.time_left = 2
			game.training.reward_duration = 3
			app._refresh()
			app.room.update_placement()
			app.room.look_at_world(app.room.pet_world)
			app._show_feedback("Udało się! Teraz nagródź pieska.")
			app._show_gain("pet", {"contact": 18})
			await process_frame
			var bounds := _puppy_screen_bounds()
			check(not app.bubble.visible and not app.gain_label.visible and bounds.position.y >= app.header.get_rect().end.y + 12 and bounds.end.y <= app.sheet.position.y - 12, "training puppy remains fully clear of HUD, messages and panel: %s / %s" % [layout, phase])
			check(app.sheet.size.y <= 280 and app.sheet.get_rect().end.y < app.navigation.position.y and (app.sheet.position.y - app.header.get_rect().end.y) / app.safe_rect.size.y >= 0.43, "training reserves space for the puppy and keeps controls above navigation: %s / %s" % [layout, phase])
		await capture("training-clear-%d.png" % layout.x)
		app.safe_area_override = Rect2()
	game.training.phase = "idle"
	app._show_feedback("Okazja minęła. Zrobimy kolejną próbę.")
	app._refresh()
	check(app.training_hint.text.contains("Okazja minęła") and not app.bubble.visible, "missed training feedback remains readable inside the panel")
	app._process(5)
	app._refresh()
	check(not app.training_hint.text.contains("Okazja minęła"), "training outcome expires and restores the current instruction")
	app._show_feedback("Krótki wynik próby")
	app._select_tab("care")
	check(not app.bubble.visible, "leaving training does not resurrect its old message over the puppy")
	app._select_tab("training")

func _test_phone_framing() -> void:
	app._select_tab("care")
	app.session._cancel_motion()
	app.session.activity = "idle"
	app.session.pet.resting = false
	app.session._cancel_invitation()
	app.bubble_left = 0
	app.room.pan_hint_dismissed = true
	app.room.pet_world = RoomLayout.START
	app.room.target_world = RoomLayout.START
	app.room.ball_world = RoomLayout.STATIONS.ball.position
	app.room.ball_target = app.room.ball_world
	for layout in [Vector2i(390, 844), Vector2i(320, 640), Vector2i(1080, 2340), Vector2i(860, 1864)]:
		root.size = layout
		root.content_scale_size = Vector2i(390, 844)
		await process_frame
		await process_frame
		app.safe_area_override = Rect2()
		if layout.x >= 860:
			app.safe_area_override = root.get_final_transform() * Rect2(12, 54, app.size.x - 24, app.size.y - 88)
		app._fit_room()
		app.room.focus_left = 0
		app.room.set_interaction_focus(false)
		app.room.focus_pet()
		app.room._update_camera(10)
		app.room._sync_layers()
		app._position_feedback()
		await capture("phone-framing-%d.png" % layout.x)
		var room: RoomView = app.room
		var clear_top := room.hud_bottom + 54
		var stage := Rect2(0, clear_top, room.size.x, room.content_bottom - clear_top - 12)
		var ball := room._screen_rect(Rect2(room.ball_world - Vector2(14, 14), Vector2(28, 32)))
		check(stage.encloses(_puppy_screen_bounds()) and stage.encloses(room.bowl_rect()) and stage.encloses(ball), "phone frame keeps the entire puppy, bowl and ball between toolbar and care panel: " + str(layout))
		var window_top := room.world_to_screen(Vector2(740, 75)).y
		check(window_top >= clear_top and window_top - clear_top <= 110, "phone frame limits blank wall below the toolbar to 110 UI points: " + str(layout))
		check(room.pet_world == RoomLayout.START and room.ball_world == RoomLayout.STATIONS.ball.position, "phone reframing preserves world positions: " + str(layout))
		check_pixel_grid("phone framing " + str(layout))
	app.safe_area_override = Rect2()
	app._fit_room()

func _test_room_overview() -> void:
	app._select_tab("care")
	app.session.pet.pet_name = "Gloria"
	app.session.invitation = {"kind": "cuddle", "remaining": 30.0}
	check(app._activity_status() == "Gloria zaprasza Cię do wspólnej chwili", "invitation caption accepts a Polish female name without a wrong case")
	app.session._cancel_invitation()
	for layout in [Vector2i(390, 844), Vector2i(320, 640), Vector2i(1080, 2340)]:
		root.size = layout
		root.content_scale_size = Vector2i(390, 844)
		await process_frame
		app._fit_room()
		app.room.focus_pet()
		app.room.focus_left = 0
		app.room.set_interaction_focus(false)
		app.room.pet_world = RoomLayout.START
		app.room.target_world = RoomLayout.START
		step_game(3)
		await capture("room-medium-%d.png" % layout.x)
		var visible_width: float = app.room._visible_world_size().x
		check(visible_width >= 450 and visible_width <= 720, "default phone frame shows at least a third of the room at " + str(layout))
		check(app.room.render_rect.encloses(app.room.bowl_rect()) and app.room.render_rect.has_point(app.room.ball_center()), "default frame includes bowl and ball beside the dog at " + str(layout))
		app.room.overview_button.pressed.emit()
		step_game(0.1)
		await capture("room-overview-%d.png" % layout.x)
		var room: RoomView = app.room
		var all_visible := true
		for id in RoomLayout.STATIONS:
			var bounds := room._screen_rect(room.station_bounds(id))
			all_visible = all_visible and room.render_rect.encloses(bounds)
		check(room.overview and all_visible, "overview shows every station at " + str(layout))
		check(room.render_rect.position.y >= room.hud_bottom + 44 and room.render_rect.end.y <= room.content_bottom, "overview fits between HUD and controls at " + str(layout))
		var physical := room.screen_scale().x * room._render_pixel_size * root.get_final_transform().get_scale().x
		check(absf(physical - roundf(physical)) < 0.001, "overview retains whole physical pixels at " + str(layout))
		var target := room.world_to_screen(RoomLayout.STATIONS.toys.position)
		await touch_at(target)
		check(not room.overview and room.camera_manual and absf(room.camera_center().x - RoomLayout.STATIONS.toys.position.x) < 3, "overview tap opens selected part of the room at " + str(layout))
		room.overview_button.pressed.emit()
		room.overview_button.pressed.emit()
		step_game(2)
		check(not room.overview and not room.camera_manual, "overview button returns to following the dog at " + str(layout))

extends SceneTree

var passed := 0
var failed := 0
var app: Control
var directory: String

func _initialize() -> void:
	create_timer(120).timeout.connect(func():
		printerr("PLAY UI timeout")
		quit(1))
	call_deferred("_run")

func check(condition: bool, label: String) -> void:
	if condition:
		passed += 1
		print("PASS PLAY UI " + label)
	else:
		failed += 1
		push_error("FAIL PLAY UI " + label)

func _run() -> void:
	root.size = Vector2i(390, 844)
	root.content_scale_size = Vector2i(390, 844)
	var test_root := OS.get_environment("YUFRIEND_TEST_ROOT")
	directory = ("user://" if test_root.is_empty() else test_root).path_join("qa-play-ui-%s" % Time.get_ticks_usec())
	app = load("res://scenes/Main.tscn").instantiate()
	app.save_path_override = directory.path_join("pet.json")
	app.room.ambient_life.life.autoplay = false
	app.session.local_clock = func(): return 100 * 86400.0 + 12 * 3600.0
	root.add_child(app)
	# These scenarios begin after the greeting on waking.
	app.session.player_activity()
	var game: GameSession = app.session
	game.set_process(false)
	game._brain_left = INF
	app.room.set_process(false)
	app.set_process(false)
	app.play_view.set_process(false)
	game.pet.pet_name = "Gloria"
	game.pet.needs.energy = 90
	game.pet.needs.play = 50
	app._refresh()
	await process_frame
	check(game.offer_initiative("ball"), "dog offers the ball on its own")
	step(1)
	await capture("30-invitation.png")
	check(app.companion_notice.visible and app.companion_title.text.contains("Gloria") and app.companion_action.text.contains("piłkę"), "invitation presents a named dog and an actionable response")
	check(app.companion_notice.size.y < 180 and app.companion_notice.get_rect().end.y < app.care_buttons.play.get_global_rect().position.y, "invitation stays compact and leaves the room and care controls visible")
	var time_left: float = game.invitation.remaining
	app._show_profile()
	step(50)
	check(is_equal_approx(float(game.invitation.remaining), time_left), "reading the dog card does not count as ignoring the invitation")
	app.profile_dialog.hide()
	step(0.02)
	await process_frame
	await process_frame
	# The synthetic touch resumes the main window after the native profile closes.
	app.app_foreground = true
	app._update_attention()
	app._refresh_companion()
	app._position_companion()
	var accept_point: Vector2 = app.companion_action.get_global_rect().get_center()
	await touch(accept_point, true, 0)
	await touch(accept_point, false, 0)
	step(0.3)
	check(game.invitation.is_empty() and game.pet.social.responses.ball.accepted == 1, "invitation button records acceptance and prepares a throw")
	var room: RoomView = app.room
	room.look_at_world(room.ball_world)
	var start := room.ball_center()
	var end := start + Vector2(125, -20)
	if end.x > room.size.x - 10: end = start - Vector2(125, 20)
	var camera_before := room.camera_center()
	await touch(start, true, 0)
	await drag(start, end, 0)
	check(room.throw_guide.visible and room.camera_center().is_equal_approx(camera_before), "dragging the ball previews a throw without panning the room")
	await capture("31-ball-aim.png")
	var needs_before := game.pet.needs.duplicate()
	await touch(end, false, 0)
	check(game._pending_action == "touch_ball" and game.pet.needs == needs_before, "releasing the gesture starts the chase without an early reward")
	step(0.15)
	check(room._ball_lift > 0 and not room.throw_guide.visible, "the thrown ball follows a visible arc")
	await capture("32-ball-flight.png")
	await_arrival()
	check(game.pet.social.games.ball == 1 and game.pet.needs.play > needs_before.play, "the actual catch completes and rewards the throw")
	step(2)
	room.look_at_world(room.ball_world)
	start = room.ball_center()
	end = start + Vector2(-120, 0)
	await touch(start, true, 0)
	await drag(start, end, 1)
	check(not room.throw_guide.visible, "a second finger cannot take over the ball gesture")
	await drag(start, end, 0)
	await touch(end, false, 0, true)
	check(game.activity != "approach" and game.pet.social.games.ball == 1 and not room.throw_guide.visible, "cancelled touch neither throws nor grants a reward")
	app.care_buttons.play.pressed.emit()
	check(app.play_menu.visible, "the play action opens the three-game chooser")
	await capture("33-play-menu.png")
	app._choose_play("tug")
	await process_frame
	await process_frame
	check(app.play_dialog.visible and game.play.kind == "tug", "rope selection opens an interactive scene")
	var view: TouchPlayView = app.play_view
	check(game.play.phase == "demo_pull", "first rope round teaches the gesture")
	var demo_before := game.pet.needs.duplicate()
	control_touch(view, game.play.tug_handle, true, 0)
	control_drag(view, Vector2(0.84, 0.54), 0)
	check(game.play.phase == "demo_warning", "demo waits for release after warning")
	control_touch(view, Vector2(0.84, 0.54), false, 0)
	app._refresh()
	check(app.play_cue.visible and game.pet.needs == demo_before, "demonstration unlocks round without changing needs")
	app.play_cue.pressed.emit()
	for index in 5:
		control_touch(view, game.play.tug_handle, true, 0)
		control_drag(view, Vector2(0.84, 0.54), 1)
		check(not game.play.tug_pulled, "second finger cannot pull rope")
		control_drag(view, Vector2(0.84, 0.54), 0)
		step(2)
		if index == 0: await capture("34-rope.png")
		control_touch(view, Vector2(0.84, 0.54), false, 0)
		step(2)
	check(game.play.phase == "result" and game.pet.social.games.tug == 1 and game.play.tug_good == 5, "five timed exchanges settle one round")
	check(game.play.tug_best == 5 and TugRecord.read(game.storage.path).best == 5, "record saved after actual round")
	await capture("35-rope-result.png")
	check(not app.play_again.disabled, "rope replay is immediately available")
	app.play_again.pressed.emit()
	check(game.play.phase == "pull" and game.play.tug_best == 5, "replay skips completed demo and retains record")
	app.play_dialog.hide()
	step(2)
	app.play_dialog.hide()
	game.pet.social.last_offer_at = 0
	game.offer_initiative("cups")
	app.companion_action.pressed.emit()
	await process_frame
	check(game.pet.social.responses.cups.accepted == 1 and game.play.phase == "hide", "accepting the sniffing invitation asks the player to hide a treat")
	await capture("36-cups-hide.png")
	check(view.puppy.visible and not app.play_cue.visible, "dog is present while the player prepares the hiding place")
	var point := game.play.cup_point(2) - Vector2(0, 0.1)
	control_touch(view, point, true)
	control_touch(view, point, false)
	step(1)
	check(game.play.phase == "ready" and app.play_cue.visible and app.play_cue.text == "Szukaj!", "hiding unlocks the search command")
	await capture("37-cups-ready.png")
	app.play_cue.pressed.emit()
	step(0.7)
	check(game.play.phase == "search" and not app.play_cue.visible, "dog searches independently after the command")
	await capture("37-cups-search.png")
	step(5)
	check(game.play.phase == "found" and game.play.selected_cup == 2 and app.play_cue.text == "Brawo!" and game.pet.social.games.cups == 0, "dog finds the chosen hiding place and asks for praise")
	await capture("38-cups-found.png")
	app.play_cue.pressed.emit()
	check(game.play.success and game.pet.social.games.cups == 1, "praise completes the shared game")
	await capture("38-cups-result.png")
	step(2)
	app.play_again.pressed.emit()
	check(game.play.phase == "hide" and game.pet.social.games.cups == 1, "replay starts with a new hiding place")
	app._notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	check(not app.play_dialog.visible and game.play.kind.is_empty(), "backgrounding closes and cancels unfinished touch play")
	app._notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	game.pet.social.last_offer_at = 0
	game.offer_initiative("tug")
	game.decline_invitation()
	app._show_profile()
	await process_frame
	await process_frame
	var scroll: ScrollContainer = app.profile_social.get_parent().get_parent()
	scroll.ensure_control_visible(app.profile_social)
	await capture("39-response-memory.png")
	check(app.profile_social.text.contains("Piłka") and app.profile_social.text.contains("później"), "the dog card shows remembered player responses")
	app.profile_dialog.hide()
	for viewport_size in [Vector2i(320, 640), Vector2i(1100, 720)]:
		root.size = viewport_size
		root.content_scale_size = viewport_size
		await process_frame
		game.start_touch_game("cups")
		var hide_point := game.play.cup_point(0) - Vector2(0, 0.1)
		control_touch(view, hide_point, true)
		control_touch(view, hide_point, false)
		step(1)
		await capture("40-play-%d.png" % viewport_size.x)
		var action_rect: Rect2 = app.play_cue.get_global_rect()
		check(app.play_cue.visible and action_rect.position.y >= 0 and action_rect.end.y <= app.play_dialog.size.y - 40, "search action stays visible without scrolling at " + str(viewport_size))
		check(app.play_dialog.position.x >= 0 and app.play_dialog.position.y >= 0 and app.play_dialog.position.x + app.play_dialog.size.x <= root.size.x and app.play_dialog.position.y + app.play_dialog.size.y <= root.size.y, "touch play dialog fits " + str(viewport_size))
		check(view.size.x >= 240 and view.size.y >= 220, "play surface remains usable at " + str(viewport_size))
		app.play_dialog.hide()
		game.start_touch_game("tug")
		step(20)
		await capture("41-rope-result-%d.png" % viewport_size.x)
		check(game.play.phase == "result" and game.play.tug_good == 0 and game.play.tug_best == 5, "idle replay keeps previous record")
		check(app.play_again.visible and not app.play_again.disabled and app.play_again.get_global_rect().end.y <= app.play_dialog.size.y - 40, "rope replay remains visible on " + str(viewport_size))
		check(app.play_dialog.position.y + app.play_dialog.size.y <= root.size.y, "rope result fits small and wide windows")
		app.play_dialog.hide()
	game.active = false
	app.queue_free()
	await process_frame
	for file in DirAccess.get_files_at(directory): DirAccess.remove_absolute(directory.path_join(file))
	DirAccess.remove_absolute(directory)
	print("PLAY UI RESULTS: %d passed, %d failed" % [passed, failed])
	quit(1 if failed else 0)

func step(seconds: float) -> void:
	var remaining := seconds
	while remaining > 0:
		var delta := minf(remaining, 0.02)
		app.app_foreground = true
		app._update_attention()
		app.session._process(delta)
		app.room._process(delta)
		app.room.animator._process(delta)
		app.play_view._process(delta)
		app._process(delta)
		remaining -= delta

func await_arrival() -> void:
	var remaining := 40.0
	while app.session.activity == "approach" and remaining > 0:
		step(0.02)
		remaining -= 0.02

func touch(point: Vector2, down: bool, id: int, cancelled: bool = false) -> void:
	var event := InputEventScreenTouch.new()
	event.position = point
	event.index = id
	event.pressed = down
	event.canceled = cancelled
	root.push_input(event, true)
	await process_frame

func drag(from: Vector2, to: Vector2, id: int) -> void:
	var event := InputEventScreenDrag.new()
	event.index = id
	event.position = to
	event.relative = to - from
	root.push_input(event, true)
	await process_frame

func control_touch(view: TouchPlayView, normalized: Vector2, down: bool, id: int = 0) -> void:
	var event := InputEventScreenTouch.new()
	event.position = normalized * view.size
	event.index = id
	event.pressed = down
	view.gui_input.emit(event)

func control_drag(view: TouchPlayView, normalized: Vector2, id: int) -> void:
	var event := InputEventScreenDrag.new()
	event.index = id
	event.position = normalized * view.size
	view.gui_input.emit(event)

func capture(name: String) -> void:
	# This harness drives frames manually and simulates an attended foreground window.
	app._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	app._update_attention()
	app._refresh()
	app.play_view._process(0)
	for index in 3:
		await process_frame
		app.app_foreground = true
		app._process(0)
	await RenderingServer.frame_post_draw
	var output := ProjectSettings.globalize_path("res://test-results")
	DirAccess.make_dir_recursive_absolute(output)
	root.get_texture().get_image().save_png(output.path_join(name))

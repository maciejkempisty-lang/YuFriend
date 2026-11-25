extends SceneTree
var passed := 0
var failed := 0
var app: Control
var directory: String

func _initialize() -> void:
	create_timer(100).timeout.connect(func(): quit(1))
	call_deferred("_run")

func check(ok: bool, message: String) -> void:
	if ok: passed += 1
	else:
		failed += 1
		push_error(message)

func _run() -> void:
	directory = preload("res://tests/helper_paths.gd").data_root().path_join("ui-wellbeing-%d" % Time.get_ticks_usec())
	root.size = Vector2i(390, 844)
	root.content_scale_size = root.size
	app = load("res://scenes/Main.tscn").instantiate()
	app.save_path_override = directory.path_join("pet.json")
	app.room.ambient_life.life.autoplay = false
	app.session.local_clock = func(): return 100 * 86400.0 + 12 * 3600
	root.add_child(app)
	app.session.player_activity()
	app.session.set_process(false)
	app.session._brain_left = INF
	app.room.set_process(false)
	app.set_process(false)
	app.session.pet.pet_name = "Gloria"
	app.session.wellbeing.begin(app.session.pet)
	app._refresh()
	await process_frame
	await capture("header-390")
	check(app.wellbeing_button.visible and app.wellbeing_button.text == "Radosna", "header has readable emotional face")
	app.wellbeing_button.pressed.emit()
	check(app.wellbeing_dialog.visible and app.wellbeing_dialog.dialog_text.contains("przytulić"), "face explains what player can do")
	check(app.wellbeing_dialog.ok_button_text == "Zamknij" and not app.text_dialog.visible, "emotion explanation is independent of training commands")
	app.wellbeing_dialog.hide()
	await process_frame
	await process_frame
	# Native dialog focus returns asynchronously; the test disables the UI tick.
	app.app_foreground = true
	app._update_attention()
	step(0.01)
	for key in app.session.wellbeing.parts: app.session.wellbeing.parts[key] = 30.0
	app.session.wellbeing.parts.contact = 10.0
	app.session.wellbeing.joy = 0
	app._refresh()
	app._refresh_companion()
	check(app.companion_action.text == "Przytul" and app.companion_label.text.contains("Posiedzisz"), "sad dog asks for concrete soothing action")
	app.companion_action.pressed.emit()
	await process_frame
	await process_frame
	check(app.cuddle_dialog.visible and app.session.cuddle.running(), "request opens cuddle scene")
	await capture("cuddle-390")
	var view: CuddleView = app.cuddle_view
	var model: CuddleSystem = app.session.cuddle
	press(view, Vector2(0.30, 0.60), true, 0)
	move(view, Vector2(0.45, 0.60), 1)
	check(model.point.is_equal_approx(Vector2(0.30, 0.60)), "second finger cannot take over cuddle")
	for index in 340:
		step(0.05)
		var x := 0.30 + (1 - absf(fmod((index + 1) * 0.05, 4.0) - 2) / 2) * 0.30
		move(view, Vector2(x, 0.60), 0)
		if model.phase != "stroke": break
	press(view, model.point, false, 0)
	check(model.phase == "find", "touch movement really advances cuddle")
	await capture("favorite-390")
	var center: Vector2 = CuddleSystem.SPOTS[model.favorite]
	press(view, center + Vector2(0.03, 0), true, 0)
	for index in 50:
		step(0.05)
		move(view, center + Vector2.from_angle((index + 1) * 0.2) * 0.03, 0)
	press(view, center, false, 0)
	step(0.01)
	check(model.phase == "result" and app.session.pet.milestones.has("cuddle_favorite"), "touch completion records favorite")
	check(WellbeingSystem.state(app.session.wellbeing.score()) >= 2, "sadness visibly improves within one ritual")
	await capture("result-390")
	app.cuddle_dialog.hide()
	app._show_profile()
	check(app.profile_life.text.contains(WellbeingSystem.favorite_label(app.session.pet)), "profile shows discovered favorite")
	app.profile_dialog.hide()
	for viewport_size in [Vector2i(320, 640), Vector2i(1100, 720)]:
		root.size = viewport_size
		root.content_scale_size = viewport_size
		await process_frame
		app._fit_room()
		app._care_action("pet")
		await process_frame
		await process_frame
		await capture("cuddle-%d" % viewport_size.x)
		check(app.cuddle_dialog.position.x >= 0 and app.cuddle_dialog.position.y >= 0 and app.cuddle_dialog.position.x + app.cuddle_dialog.size.x <= root.size.x and app.cuddle_dialog.position.y + app.cuddle_dialog.size.y <= root.size.y, "cuddle fits viewport " + str(viewport_size))
		check(view.size.x >= 240 and view.size.y >= 240, "touch area remains usable")
		app._notification(Node.NOTIFICATION_APPLICATION_PAUSED)
		check(not app.cuddle_dialog.visible and model.phase == "idle", "background closes and cancels ritual")
		app._notification(Node.NOTIFICATION_APPLICATION_RESUMED)
		app.session.player_activity()
	app.session.active = false
	app.queue_free()
	await process_frame
	print("WELLBEING UI RESULTS: %d passed, %d failed" % [passed, failed])
	quit(1 if failed else 0)

func step(seconds: float) -> void:
	app.app_foreground = true
	app._update_attention()
	app.session._process(seconds)
	app._refresh()
	app.cuddle_view._process(seconds)

func press(view: Control, point: Vector2, down: bool, index: int) -> void:
	var event := InputEventScreenTouch.new()
	event.position = point * view.size
	event.index = index
	event.pressed = down
	view._on_input(event)

func move(view: Control, point: Vector2, index: int) -> void:
	var event := InputEventScreenDrag.new()
	event.position = point * view.size
	event.index = index
	view._on_input(event)

func capture(label: String) -> void:
	app._refresh()
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/private/tmp/wellbeing-" + label + ".png")

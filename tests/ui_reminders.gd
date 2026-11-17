extends SceneTree

var failed := 0
var passed := 0
var app: Control

func _initialize() -> void:
	create_timer(40).timeout.connect(func(): quit(1))
	call_deferred("_run")

func check(value: bool, message: String) -> void:
	if value: passed += 1
	else:
		failed += 1
		push_error(message)

func settle() -> void:
	await process_frame
	await process_frame

func tap(button: Button) -> void:
	var event := InputEventScreenTouch.new()
	event.position = button.get_global_rect().get_center()
	event.pressed = true
	root.push_input(event, true)
	event = event.duplicate()
	event.pressed = false
	root.push_input(event, true)
	await settle()

func _run() -> void:
	root.size = Vector2i(390, 844)
	root.content_scale_size = root.size
	var test_root := OS.get_environment("YUFRIEND_TEST_ROOT")
	var directory := ("user://" if test_root.is_empty() else test_root).path_join("qa-reminder-ui-%s" % Time.get_ticks_usec())
	app = load("res://scenes/Main.tscn").instantiate()
	app.save_path_override = directory.path_join("pet.json")
	app.room.ambient_life.life.autoplay = false
	app.session.local_clock = func(): return 100 * 86400.0 + 12 * 3600.0
	root.add_child(app)
	app.session.set_process(false)
	app.set_process(false)
	await settle()
	app._show_settings()
	check(app.reminders_toggle.disabled and not app.reminders.enabled, "Desktop shows unavailable reminders without opting in")
	app.reminders.start(app.save_path_override, true)
	app.reminders_toggle.disabled = false
	app.reminders_toggle.button_pressed = true
	check(app.reminders.enabled and FileAccess.file_exists(directory.path_join("reminders.json")), "UI toggle publishes an opt-in command")
	var response := FileAccess.open(directory.path_join("reminders-status.json"), FileAccess.WRITE)
	response.store_string(JSON.stringify({"request": app.reminders.request, "status": "denied"}))
	response.close()
	app._process(1)
	check(app.reminders_status.text.contains("Ustawieniach iPhone"), "Native denial updates the visible settings")
	for layout in [Vector2i(390, 844), Vector2i(320, 640), Vector2i(860, 1864), Vector2i(1290, 2796), Vector2i(1100, 720), Vector2i(844, 390)]:
		root.size = layout
		root.content_scale_size = Vector2i(430, 932) if layout.x in [860, 1290] else layout
		await settle()
		var margins := Rect2(0, 62, app.size.x, app.size.y - 96)
		if layout.x > layout.y: margins = Rect2(59, 0, app.size.x - 118, app.size.y - 21)
		app.safe_area_override = root.get_final_transform() * margins
		app._fit_room()
		app._show_settings()
		await settle()
		var dialog: Rect2 = app.settings_dialog.get_global_rect()
		check(app.safe_rect.encloses(dialog), "Settings fit safe bounds at " + str(layout))
		check(app.reminders_toggle.size.y >= 44, "Toggle has a touch target at " + str(layout))
		check(app.settings_scroll.get_global_rect().end.y <= app.settings_close.get_global_rect().position.y, "Scrollable content cannot cover the exit at " + str(layout))
		for button in [app.settings_close, app.settings_close_top]:
			check(app.safe_rect.encloses(button.get_global_rect()) and button.size.y >= 44, "Exit stays below island and above home indicator at " + str(layout))
		var close_position: Vector2 = app.settings_close.global_position
		app.settings_scroll.scroll_vertical = 10000
		await settle()
		check(app.settings_close.global_position == close_position, "Exit does not scroll away at " + str(layout))
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://test-results/reminders-settings-%d.png" % layout.x)
		await tap(app.settings_close)
		check(not app.settings_dialog.visible and not app._dialog_open(), "Touching return closes settings at " + str(layout))
		app._show_settings()
		await settle()
		await tap(app.settings_close_top)
		check(not app.settings_dialog.visible, "Touching top close also exits at " + str(layout))
	app.reminders_toggle.button_pressed = false
	check(not app.reminders.enabled, "UI opt-out is saved")
	app.session.active = false
	app.queue_free()
	await process_frame
	for filename in DirAccess.get_files_at(directory): DirAccess.remove_absolute(directory.path_join(filename))
	DirAccess.remove_absolute(directory)
	print("REMINDER UI RESULTS: %d passed, %d failed" % [passed, failed])
	quit(1 if failed else 0)

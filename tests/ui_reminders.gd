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

func _run() -> void:
	root.size = Vector2i(390, 844)
	root.content_scale_size = root.size
	var test_root := OS.get_environment("YUFRIEND_TEST_ROOT")
	var directory := ("user://" if test_root.is_empty() else test_root).path_join("qa-reminder-ui-%s" % Time.get_ticks_usec())
	app = load("res://scenes/Main.tscn").instantiate()
	app.save_path_override = directory.path_join("pet.json")
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
	for layout in [Vector2i(390, 844), Vector2i(320, 640), Vector2i(1100, 720)]:
		root.size = layout
		root.content_scale_size = layout
		await settle()
		app._fit_room()
		app._show_settings()
		await settle()
		var dialog: Rect2 = Rect2(app.settings_dialog.position, app.settings_dialog.size)
		check(app.safe_rect.encloses(dialog), "Settings fit safe bounds at " + str(layout))
		check(app.reminders_toggle.size.y >= 44, "Toggle has a touch target at " + str(layout))
		check(app.reminders_status.get_global_rect().end.y < app.settings_dialog.get_ok_button().get_global_rect().position.y, "Permission explanation fits above Done at " + str(layout))
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://test-results/reminders-settings-%d.png" % layout.x)
	app.reminders_toggle.button_pressed = false
	check(not app.reminders.enabled, "UI opt-out is saved")
	app.session.active = false
	app.queue_free()
	await process_frame
	for filename in DirAccess.get_files_at(directory): DirAccess.remove_absolute(directory.path_join(filename))
	DirAccess.remove_absolute(directory)
	print("REMINDER UI RESULTS: %d passed, %d failed" % [passed, failed])
	quit(1 if failed else 0)

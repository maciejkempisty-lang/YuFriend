extends SceneTree

var passed := 0
var failed := 0
var app: GameUI
var directory: String

func _initialize() -> void:
	create_timer(45).timeout.connect(func(): quit(1))
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(390, 844)
	root.content_scale_size = root.size
	directory = (OS.get_environment("YUFRIEND_TEST_ROOT") if not OS.get_environment("YUFRIEND_TEST_ROOT").is_empty() else "user://").path_join("qa-hud-%s" % Time.get_ticks_usec())
	app = load("res://scenes/Main.tscn").instantiate()
	app.save_path_override = directory.path_join("pet.json")
	app.room.ambient_life.life.autoplay = false
	app.session.local_clock = func(): return 12.0 * 3600
	root.add_child(app)
	app.session.set_process(false)
	app.set_process(false)
	app.room.set_process(false)
	app.room.animator.set_process(false)
	app.session.initiatives_enabled = false
	app.session.pet.pet_name = "Gloria"
	app._refresh()
	await process_frame
	check(app.header.visible and app.header.position.y == app.safe_rect.position.y, "header touches the top safe edge")
	check(app.name_label.visible and app.bond_bar.visible and app.today_button.visible, "header keeps name, progress and daily plan")
	check(not app.bond_label.visible and not app.bond_detail.visible and not app.wellbeing_button.visible, "extra header details are hidden")
	check(app.today_button.text == "Plan na dziś", "daily plan has a clear label")
	check(app.care_status.get_parent() == app and not app.yard_toolbar.visible, "care panel contains only activity icons; any status floats separately")
	for button in app.care_buttons.values(): check(button.icon_only, "care action is icon-only")
	var order := ["care", "training", "journal", "map", "settings"]
	for index in order.size(): check(app.navigation.get_child(0).get_child(index) == app.tab_buttons[order[index]], "navigation order %d" % index)
	app._show_map()
	check(app.room.overview and app.tab_buttons.map.selected, "map opens whole room")
	check(app.yard_button.visible and app.yard_bath_button.visible, "map keeps yard and bath entrances")
	await process_frame
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png("res://test-results/hud-map-390.png")
	app._return_to_location()
	check(not app.room.overview and app.tab_buttons.care.selected, "location button returns from map")
	app.session.in_yard = true
	app.room.set_yard(true)
	app._refresh()
	app._select_tab("training")
	check(app.session.in_yard and app.room.in_yard and app.selected_tab == "training", "training preserves the yard location")
	app._select_tab("journal")
	check(app.header.visible and app.session.in_yard and app.selected_tab == "journal", "album keeps the header and yard location")
	app._return_to_location()
	check(app.selected_tab == "care" and app.tab_buttons.care.caption == "Podwórko", "location button returns to the yard")
	app._show_map()
	check(app.room.overview and app.room.in_yard, "map shows the current yard")
	app._return_to_location()
	app._show_settings()
	check(app.settings_dialog.visible and app.tab_buttons.settings.selected, "options button opens settings")
	app._hide_settings()
	check(not app.settings_dialog.visible and not app.tab_buttons.settings.selected, "closing options resets navigation")
	for width in [320, 390]:
		root.size = Vector2i(width, 844)
		root.content_scale_size = root.size
		await process_frame
		app._fit_room()
		for key in order:
			var rect: Rect2 = app.tab_buttons[key].get_global_rect()
			check(rect.size.x >= 48 and app.safe_rect.encloses(rect), "%s remains tappable at %d px" % [key, width])
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://test-results/hud-navigation-390.png")
	app.session.active = false
	app.queue_free()
	await process_frame
	for file in DirAccess.get_files_at(directory): DirAccess.remove_absolute(directory.path_join(file))
	DirAccess.remove_absolute(directory)
	print("HUD NAVIGATION RESULTS: %d passed, %d failed" % [passed, failed])
	quit(1 if failed else 0)

func check(condition: bool, message: String) -> void:
	if condition: passed += 1
	else:
		failed += 1
		push_error("FAIL " + message)

extends SceneTree
var app: GameUI
var passed := 0
var failed := 0

func _initialize() -> void:
	create_timer(60).timeout.connect(func(): quit(1))
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	if ok: passed += 1
	else:
		failed += 1
		push_error(label)

func settle() -> void:
	await process_frame
	await process_frame
	app._fit_room()
	await process_frame

func reset_action() -> void:
	app.session._cancel_motion()
	app.session.activity = "idle"
	app.session.activity_left = 0
	app.session.invitation.clear()
	app.session.visitors.wait_left = INF
	app.session.pet.resting = false
	app.room.overview = false
	app.app_foreground = true
	app._refresh()

func run() -> void:
	root.size = Vector2i(390, 844)
	root.content_scale_size = root.size
	app = load("res://scenes/Main.tscn").instantiate()
	app.save_path_override = preload("res://tests/helper_paths.gd").data_root() + "/yuf-menu-%s/pet.json" % Time.get_ticks_usec()
	app.session.local_clock = func(): return 100 * 86400.0 + 12 * 3600
	app.room.ambient_life.life.autoplay = false
	root.add_child(app)
	# Exercise both water actions with deterministic, permitted weather.
	app.session.weather.override_kind = "after_rain"
	app.session.set_process(false)
	app.room.set_process(false)
	app.room.animator.set_process(false)
	app.session.visitors.wait_left = INF
	app.session._brain_left = 500
	await settle()
	app._toggle_yard(false)
	reset_action()
	var menu := app.yard_menu
	var pet_before := app.session.pet.to_dict().duplicate(true)
	var timer_before := app.session._brain_left
	var position_before := app.room.pet_world
	app.room.look_at_world(Vector2(750, 260))
	var touch := app.room.world_to_screen(Vector2(730, 230))
	check(app.room.action_at(touch) == "yard_bush_1", "test touch targets the actual bush")
	app.room._interact(touch)
	await settle()
	check(menu.visible and menu.station_id == "bush_1" and menu.primary.text == "Szukaj" and menu.secondary.text == "Chowanka", "touching a bush offers both activities")
	check(app.session.pet.to_dict() == pet_before and app.room.pet_world == position_before and app.session._brain_left == timer_before, "reading choices does not move the dog change progress or overwrite the autonomy timer")
	check(not app.care_actions.visible and not app.care_status.visible and app.tab_buttons.map.is_visible_in_tree(), "menu replaces care icons and keeps map available")
	check(not app.session.attention_available, "companion invitations yield while choosing")
	for layout in [Vector2i(320, 640), Vector2i(390, 844), Vector2i(844, 390), Vector2i(1080, 2340)]:
		root.size = layout
		root.content_scale_size = Vector2i(360, 780) if layout.x == 1080 else layout
		await settle()
		var panel := app.sheet.get_global_rect()
		for button in [menu.back, menu.primary, menu.secondary]:
			check(panel.encloses(button.get_global_rect()) and app.safe_rect.encloses(button.get_global_rect()) and button.size.y >= 44, "choice remains tappable inside panel at " + str(layout))
		check(not menu.get_global_rect().intersects(app.navigation.get_global_rect()), "menu stays clear of navigation at " + str(layout))
		if layout.x in [320, 390]:
			RenderingServer.force_draw()
			root.get_texture().get_image().save_png("/tmp/yuf-menu-%d.png" % layout.x)
	root.size = Vector2i(390, 844)
	root.content_scale_size = root.size
	await settle()
	menu.primary.pressed.emit()
	check(not menu.visible and app.session.activity == "sniff_walk" and app.session.sniff_spot == 1, "choice starts the existing search at the selected bush")
	var target := app.room.target_world
	menu.primary.pressed.emit()
	check(app.room.target_world == target and app.session.sniff_spot == 1, "repeated stale button press cannot start another action")
	reset_action()
	check(menu.offer("bush_0"), "bush menu can reopen")
	menu.secondary.pressed.emit()
	var hide_dialog: AcceptDialog
	for child in app.get_children():
		if child is AcceptDialog and child.title == "Zabawy w krzakach": hide_dialog = child
	check(is_instance_valid(hide_dialog) and hide_dialog.visible and not menu.visible, "secondary choice opens the existing three-game dialog")
	if is_instance_valid(hide_dialog): hide_dialog.hide()
	await process_frame
	reset_action()
	for id in ["puddle", "sprinkler"]:
		check(menu.offer(id) and menu.secondary.text == "Kąpiel", "water offers bath: " + id)
		menu.back.pressed.emit()
		check(not menu.visible and app.care_actions.visible and app.session.attention_available, "back restores care and attention")
	check(menu.offer("sprinkler"), "sprinkler menu opens before play")
	menu.primary.pressed.emit()
	check(app.session.water.active() and app.session.water.kind == "sprinkler" and not menu.visible, "water choice starts the existing approach and play")
	reset_action()
	app.session.pet.needs.hygiene = 40
	check(menu.offer("puddle"), "puddle menu opens before bath")
	menu.secondary.pressed.emit()
	check(app.session.in_bath and app.bath_dialog.visible and not menu.visible, "bath choice uses existing bathroom flow")
	if is_instance_valid(app.bath_dialog): app.bath_dialog.hide()
	await process_frame
	app._toggle_yard(false)
	reset_action()
	check(not menu.offer("fetch"), "fetch without an available command retains direct throw controls")
	app.session.outdoor_commands.offer_recall(Vector2(700, 315))
	check(menu.offer("fetch") and menu.secondary.text == TrainingSystem.LABELS.come, "recall offer adds a meaningful command choice")
	app.session.outdoor_commands.cancel()
	menu.sync()
	check(not menu.visible, "expired command closes stale fetch choices")
	check(menu.offer("bush_0"), "menu before floor tap")
	app.room.floor_tapped.emit(Vector2(900, 320))
	check(not menu.visible and app.session.activity == "walk", "floor tap closes choices and preserves walking")
	reset_action()
	menu.offer("bush_0")
	app.room.show_overview()
	menu.sync()
	check(not menu.visible, "overview closes menu")
	reset_action()
	menu.offer("bush_0")
	app.session.writable = false
	menu.primary.pressed.emit()
	check(not menu.visible and app.session.activity == "idle", "write protection rechecked at activation")
	app.session.writable = true
	reset_action()
	menu.offer("bush_0")
	app.session.pet.yard_routines.mess = true
	app._refresh()
	check(not menu.visible and app.potty_action.visible and app.potty_action.text == "Sprzątnij", "cleanup takes precedence over choices")
	app.session.pet.yard_routines.mess = false
	reset_action()
	menu.offer("bush_0")
	app._select_tab("journal")
	check(not menu.visible and app.panels.journal.visible, "album cannot retain a stale menu")
	app._select_tab("care")
	app._toggle_yard(false)
	reset_action()
	menu.offer("bush_0")
	app._notification(MainLoop.NOTIFICATION_APPLICATION_PAUSED)
	check(not menu.visible and app.session.suspended, "background closes the menu before suspending")
	app.music.stop()
	app.effects.stop_all()
	app.queue_free()
	await process_frame
	await process_frame
	print("YARD MENU UI: %d passed, %d failed" % [passed, failed])
	quit(1 if failed else 0)

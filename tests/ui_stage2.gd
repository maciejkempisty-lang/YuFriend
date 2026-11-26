extends SceneTree
var failed := 0
var app: GameUI
func check(ok: bool, label: String) -> void:
	if not ok:
		failed += 1
		push_error(label)
func _initialize() -> void:
	create_timer(60).timeout.connect(func(): quit(1))
	call_deferred("run")
func spawn(path: String) -> void:
	app = load("res://scenes/Main.tscn").instantiate()
	app.save_path_override = path
	app.enable_test_onboarding = true
	app.session.local_clock = func(): return 20000 * 86400.0 + 12 * 3600
	root.add_child(app)
	app.session.set_process(false)
	app.room.ambient_life.life.autoplay = false
func shot(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/yuf-stage2-"+name+".png")
func run() -> void:
	root.size = Vector2i(320,680)
	root.content_scale_size = root.size
	var path := preload("res://tests/helper_paths.gd").data_root() + "/yuf-stage2-onboarding-%s/pet.json" % Time.get_ticks_usec()
	spawn(path)
	await process_frame
	check(app.first_meeting != null and app.first_meeting.visible, "new puppy opens naming")
	check(app.name_label.text == "Piesek", "header hides the default name before naming")
	app.first_meeting.hide()
	app.first_meeting.canceled.emit()
	await process_frame
	await process_frame
	check(app.first_meeting.visible and app.naming_pending, "close button or Escape cannot skip naming")
	check(not app.first_meeting.dialog_close_on_escape, "Escape does not dismiss naming")
	check(app.first_meeting.borderless, "naming uses a card without native title chrome")
	app.keyboard_height_override = 280
	app._position_dialog(app.first_meeting, Vector2i(340,330))
	check(app.first_meeting.position.y + app.first_meeting.size.y <= 400, "naming fits above keyboard")
	app.keyboard_height_override = -1
	await shot("welcome")
	check(Rect2(Vector2.ZERO, app.size).encloses(Rect2(Vector2(app.first_meeting.position), Vector2(app.first_meeting.size))), "naming dialog fits small phone")
	app.queue_free()
	await process_frame
	spawn(path)
	await process_frame
	check(app.first_meeting != null and app.first_meeting.visible, "interrupted first meeting resumes")
	app.first_name.text = "   "
	app._finish_first_meeting()
	check(app.first_meeting.visible, "blank name cannot complete")
	var id := app.session.pet.pet_id
	app.first_name.text = "Luna"
	app._finish_first_meeting()
	check(not app.first_meeting.visible and app.session.pet.pet_name == "Luna", "name accepted")
	app._refresh()
	check(app.name_label.text == "Luna", "header shows the chosen name")
	check(app.session.storage.load_pet().pet.pet_name == "Luna", "name persisted")
	app.queue_free()
	await process_frame
	spawn(path)
	await process_frame
	check(app.first_meeting == null and app.session.pet.pet_id == id, "restart retains identity without onboarding")
	app.app_foreground = true
	app.session.weather.override_kind = "rain"
	app.session.change_yard(true)
	app._refresh()
	await process_frame
	check(app.yard_toolbar.get_parent()==app.panels.care, "yard actions next to instructions")
	check(not app.care_buttons.feed.visible and not app.care_buttons.clean.visible, "home-only actions absent outside")
	check(app.yard_button.text == "Do domu" and RoomLayout.YARD_STATIONS.gate.label == "Do domu", "yard exit is not a second Dom tab")
	check(app.sniff_button.text == "Chowany", "hide games are named by the game")
	# The yard status may currently show another instruction (e.g. a potty walk).
	check(not GameUI.fetch_hint(0.0).contains("rekord"), "no record is shown before the first fetch")
	check(GameUI.fetch_hint(4.25).contains("4,2") or GameUI.fetch_hint(4.25).contains("4,3"), "fetch record uses a decimal comma")
	await shot("yard")
	check(app.care_actions.get_global_rect().end.y < app.navigation.position.y, "all care actions fit above navigation")
	app._show_feedback("Teraz odpoczywam. Spróbuj za chwilę.")
	app._position_feedback()
	check(app.bubble.visible, "yard refusal remains visible when idle")
	check(app.session.offer_initiative("yard_puddle",Time.get_unix_time_from_system()+600), "yard invitation offered")
	app._refresh()
	await process_frame
	await shot("invitation")
	check(not app.bubble.visible and not app.care_actions.visible, "invitation shows one instruction and contextual actions")
	check(app.yard_invite_accept.text == "Do kałuży", "invitation names its action")
	check(app.yard_toolbar.get_global_rect().end.y <= app.navigation.position.y, "context actions fit above navigation")
	check(app.sheet.size.y <= 176.0 and app.sheet.get_rect().end.y <= app.navigation.position.y, "context panel fits while care icons are hidden")
	app.session.change_yard(false)
	app._refresh()
	check(app.yard_toolbar.get_parent()==app.panels.care and app.care_buttons.feed.visible, "home restores actions")
	await shot("home")
	await process_frame
	check(app.sheet.get_global_rect().end.x <= app.size.x, "home panel shrinks after yard invitation")
	check(app.care_buttons.pet.get_global_rect().end.x <= app.size.x, "all five home actions remain visible")
	app.queue_free()
	await process_frame
	print("STAGE2 UI FAILURES: ",failed)
	quit(1 if failed else 0)

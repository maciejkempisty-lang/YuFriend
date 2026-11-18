extends SceneTree
var app: GameUI
var passed := 0
var failed := 0
var day := 102
var hour := 12
func _initialize() -> void:
	create_timer(60).timeout.connect(func(): quit(1))
	call_deferred("run")
func check(ok: bool, label: String) -> void:
	if ok: passed += 1
	else:
		failed += 1
		push_error(label)
func today() -> AcceptDialog:
	for child in app.get_children():
		if child is AcceptDialog and child.title == "Dziś" and child.visible: return child
	return null
func run() -> void:
	root.size = Vector2i(320, 680)
	root.content_scale_size = root.size
	app = load("res://scenes/Main.tscn").instantiate()
	app.save_path_override = preload("res://tests/helper_paths.gd").data_root() + "/yuf-today-ui-%s/pet.json" % Time.get_ticks_usec()
	app.room.ambient_life.life.autoplay = false
	app.session.local_clock = func(): return day * 86400.0 + hour * 3600
	root.add_child(app)
	app.session.set_process(false)
	app.session.pet.pet_name = "Gloria"
	await process_frame
	app.today_button.pressed.emit()
	await process_frame
	var dialog := today()
	check(dialog != null and dialog.visible, "Today opens directly from care")
	check(not app.session.attention_available, "reading Today pauses yard encounters and invitations")
	check(dialog.size.x <= 320, "Today fits narrow screen")
	var buttons := dialog.find_children("*", "Button", true, false)
	check(buttons.any(func(b): return b.text == "Do treningu"), "training suggestion has shortcut")
	check(buttons.any(func(b): return b.text == "Do ogródka"), "garden suggestion has shortcut")
	check(buttons.any(func(b): return b.text == "Do pieska"), "untracked together suggestion has shortcut")
	var labels := dialog.find_children("*", "Label", true, false)
	check(labels.all(func(l): return not l.text.contains("/2") and not l.text.contains("/3") and not l.text.contains("seria")), "Today has no quota or streak")
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/yuf-today-320.png")
	day = 103
	await create_timer(1.1).timeout
	labels = dialog.find_children("*", "Label", true, false)
	check(labels.any(func(l): return l.text.contains("Zapachy i skarby")), "open suggestions refresh after midnight")
	buttons = dialog.find_children("*", "Button", true, false)
	for button in buttons:
		if button.text == "Do treningu": button.pressed.emit(); break
	check(app.selected_tab == "training", "shortcut opens training")
	check(not app.practice_label.text.contains("Seria") and not app.practice_label.text.contains("Dziś"), "training no longer presents daily checklist")
	DailyAdventure.record(app.session.pet, "trick", app.session._local_now())
	DailyAdventure.record(app.session.pet, "treasure", app.session._local_now())
	app._select_tab("journal")
	await process_frame
	check(app.today_button.get_parent() == app.album_actions, "album uses shared Today without progress badge")
	check(app.session.pet.milestones.has("adventure_1"), "existing keepsakes preserved")
	app.today_button.pressed.emit()
	await process_frame
	dialog = today()
	check(dialog != null, "album opens same Today panel")
	labels = dialog.find_children("*", "Label", true, false)
	check(labels.any(func(l): return l.text.contains("Miła chwila już za Wami")), "completed ideas described without extra obligations")
	hour = 23
	await create_timer(1.1).timeout
	buttons = dialog.find_children("*", "Button", true, false)
	check(not buttons.any(func(b): return b.text in ["Do treningu", "Do ogródka", "Poszukajmy"]), "night replaces active tasks with quiet ideas")
	dialog.hide()
	await process_frame
	hour = 12
	app._select_tab("care")
	for width in [320, 390, 1100]:
		root.size = Vector2i(width, 680 if width < 400 else 720)
		root.content_scale_size = root.size
		await process_frame
		await process_frame
		check(app.today_button.get_global_rect().end.x <= width, "Today entry fits " + str(width))
		check(app.care_buttons.play.get_global_rect().end.y <= app.navigation.position.y, "care actions stay above navigation " + str(width))
		app.today_button.pressed.emit()
		await process_frame
		dialog = today()
		check(dialog.size.x <= width and dialog.position.y >= 0, "Today dialog fits " + str(width))
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/yuf-today-%d.png" % width)
		dialog.hide()
		await process_frame
	app.app_foreground = true
	app._update_attention()
	check(app.session.attention_available, "closing Today restores attention")
	print("TODAY UI RESULTS: %d passed, %d failed" % [passed, failed])
	app.queue_free()
	await process_frame
	quit(1 if failed else 0)

extends SceneTree
var app: GameUI
var passed := 0
var failed := 0
var day := 102
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	if ok: passed += 1
	else:
		failed += 1
		push_error(label)
func run() -> void:
	root.size = Vector2i(320, 680)
	root.content_scale_size = root.size
	app = load("res://scenes/Main.tscn").instantiate()
	app.save_path_override = "/tmp/yuf-adventure-ui-%s/pet.json" % Time.get_ticks_usec()
	root.add_child(app)
	app.session.set_process(false)
	app.session.pet.pet_name = "Gloria"
	app.session.local_clock = func(): return day * 86400.0 + 12 * 3600
	app._select_tab("journal")
	await process_frame
	check(app.adventure_button.text.contains("0/2"), "album entry shows optional progress")
	check(app.adventure_button.get_global_rect().end.x <= 320, "album entry fits 320px")
	app.adventure_button.pressed.emit()
	await process_frame
	var dialog: AcceptDialog
	for child in app.get_children():
		if child is AcceptDialog and child.title == "Mała przygoda dnia": dialog = child
	check(dialog != null and dialog.visible, "adventure opens from album")
	check(dialog.size.x <= 320, "dialog fits narrow screen")
	var buttons := dialog.find_children("*", "Button", true, false)
	check(buttons.any(func(b): return b.text == "Do treningu"), "task has training shortcut")
	check(buttons.any(func(b): return b.text == "Na podwórko"), "task has yard shortcut")
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/yuf-adventure-plan.png")
	day = 103
	await create_timer(1.1).timeout
	var labels := dialog.find_children("*", "Label", true, false)
	check(labels.any(func(l): return l.text.contains("Tropem łapek")), "open plan refreshes after midnight")
	for button in buttons:
		if button.text == "Do treningu": button.pressed.emit(); break
	check(app.selected_tab == "training", "shortcut opens training")
	DailyAdventure.record(app.session.pet, "trick", app.session._local_now())
	DailyAdventure.record(app.session.pet, "treasure", app.session._local_now())
	app._select_tab("journal")
	await process_frame
	check(app.adventure_button.text.contains("pamiątka"), "completed status visible")
	check(app.adventure_button.get_global_rect().end.x <= 320, "completed label fits 320px")
	check(app.session.pet.milestones.has("adventure_1"), "album keepsake unlocked")
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/yuf-adventure-album.png")
	print("ADVENTURE UI RESULTS: %d passed, %d failed" % [passed, failed])
	app.queue_free()
	await process_frame
	quit(1 if failed else 0)

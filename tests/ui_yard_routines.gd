extends SceneTree
var app: Control
var failed := 0
func check(ok: bool, label: String) -> void:
	if not ok:
		failed += 1
		push_error(label)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	root.size = Vector2i(320, 680)
	root.content_scale_size = root.size
	app = load("res://scenes/Main.tscn").instantiate()
	app.save_path_override = "/tmp/yuf-garden-ui-%s/pet.json" % Time.get_ticks_usec()
	root.add_child(app)
	app.session.local_clock = func(): return 100 * 86400.0 + 12 * 3600
	app.session._brain_left = INF
	await process_frame
	app._toggle_yard(false)
	app.room.yard_markers.garden.pressed.emit()
	await process_frame
	var dialog: AcceptDialog
	for child in app.get_children():
		if child is AcceptDialog and child.title == "Ogródek": dialog = child
	check(dialog != null and dialog.visible, "garden station opens dialog")
	check(dialog.size.x <= 320 and dialog.size.y <= 600, "garden fits 320 px")
	var buttons := dialog.find_children("*", "Button", true, false)
	for button in buttons:
		if button.text == "Posadź: Stokrotka": button.pressed.emit(); break
	await process_frame
	check(app.session.pet.yard_routines.plant == "daisy", "seed button plants")
	for child in app.get_children():
		if child is AcceptDialog and child.visible:
			for button in child.find_children("*", "Button", true, false):
				if button.text == "Podlej": button.pressed.emit(); break
	await process_frame
	check(app.session.pet.yard_routines.water_until > Time.get_unix_time_from_system(), "water button waters")
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/yuf-garden-ui.png")
	for child in app.get_children():
		if child is AcceptDialog: child.hide()
	app.room.yard_markers.outing.pressed.emit()
	app.session.destination_reached()
	app.session._process(4.1)
	app.room.yard_markers.outing.pressed.emit()
	check(app.session.pet.yard_routines.outday == 100, "outing station praises dog")
	app.room.show_overview()
	app.room.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/yuf-garden-overview.png")
	print("GARDEN UI FAILURES: ", failed)
	app.queue_free()
	await process_frame
	quit(1 if failed else 0)

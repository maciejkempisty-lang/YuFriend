extends SceneTree
var app: GameUI
var failed := 0
func _initialize() -> void:
	call_deferred("run")
func check(ok: bool, label: String) -> void:
	if not ok:
		failed += 1
		push_error(label)
func close() -> void:
	for child in app.get_children():
		if child is AcceptDialog: child.hide()
func shot(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/yuf-dig-" + name + ".png")
func run() -> void:
	root.size = Vector2i(320, 680)
	root.content_scale_size = root.size
	app = load("res://scenes/Main.tscn").instantiate()
	app.save_path_override = preload("res://tests/helper_paths.gd").data_root() + "/yuf-dig-ui-%s/pet.json" % Time.get_ticks_usec()
	app.room.ambient_life.life.autoplay = false
	root.add_child(app)
	app.session.local_clock = func(): return 100 * 86400.0 + 12 * 3600
	app.session._brain_left = INF
	app.session.pet.bond = 75
	app.session.set_process(false)
	await process_frame
	ProgressionPanels.bond(app)
	await process_frame
	for child in app.get_children():
		if child is AcceptDialog and child.visible:
			check(child.size.x <= 320 and child.size.y <= 600, "bond panel fits narrow screen")
	await shot("bond")
	close()
	app._toggle_yard(false)
	app.room.yard_markers.dig.pressed.emit()
	check(app.session.activity == "dig_walk", "sandbox starts approach")
	for i in 80:
		app.room._process(0.1)
		app.room.animator._process(0.1)
		if app.session.activity == "digging": break
	check(app.session.activity == "digging", "actual movement reaches sandbox")
	for i in 5: app.room.animator._process(0.1)
	check(app.room.animator.current == "dig", "new digging clip is active")
	await shot("animation")
	check(not app.bubble.visible or app.bubble.modulate.a == 0 or not app.bubble.get_rect().intersects(app.yard_toolbar.get_rect()), "dig message avoids yard toolbar")
	app.session._process(4.1)
	check(app.session.pet.exploration.items.size() == 1, "dig completion adds real item")
	ProgressionPanels.collection(app)
	await process_frame
	for child in app.get_children():
		if child is AcceptDialog and child.visible: check(child.size.x <= 320 and child.size.y <= 600, "collection scrolls within narrow screen")
	await shot("collection")
	close()
	app._show_decor()
	await shot("decor")
	close()
	print("DIG UI FAILURES: ", failed)
	app.queue_free()
	await process_frame
	quit(1 if failed else 0)

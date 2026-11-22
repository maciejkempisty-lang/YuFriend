extends SceneTree
var app: GameUI
var failed := 0
const NOW := 20000 * 86400.0 + 12 * 3600
func _initialize() -> void: call_deferred("run")
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
	root.get_texture().get_image().save_png("/tmp/yuf-bond-" + name + ".png")
func run() -> void:
	root.size = Vector2i(320, 680)
	root.content_scale_size = root.size
	app = load("res://scenes/Main.tscn").instantiate()
	app.save_path_override = preload("res://tests/helper_paths.gd").data_root() + "/yuf-bond-ui-%s/pet.json" % Time.get_ticks_usec()
	app.session.local_clock = func(): return NOW
	app.room.ambient_life.life.autoplay = false
	root.add_child(app)
	app.session.set_process(false)
	app.session.pet.pet_name = "Gloria"
	app.session.pet.bond = 140
	app.naming_pending = false
	close()
	BondLevels.add(app.session.pet, 17.5, NOW)
	app._refresh()
	await process_frame
	check(app.bond_label.text == "Nierozłączni ♥2" and is_equal_approx(app.bond_bar.value, 35), "header and bar show heart progress")
	check(app.bond_detail.text == "Do ♥3: 35% · dziś +17,5", "target and daily gain visible")
	check(app.bond_detail.get_global_rect().end.x <= 320 and app.bond_label.get_global_rect().end.x <= 320, "header fits narrow phone")
	await shot("header-320")
	ProgressionPanels.bond(app)
	await process_frame
	for child in app.get_children():
		if child is AcceptDialog and child.visible:
			check(child.size.x <= 320 and child.size.y <= 600, "reward panel fits narrow phone and scrolls")
	await shot("rewards-320")
	close()
	await app._take_photo()
	check(app.session.pet.photos.size() == 1, "camera still completes without a frame chooser below heart four")
	BondLevels.add(app.session.pet, 162.5, NOW)
	check(KeepsakeSystem.toggle_decor(app.session, "heart"), "new room decoration activates")
	app._refresh()
	await shot("decor-320")
	app._take_photo()
	await process_frame
	var frame_button := find_button(app, "Z ramką: Nasze serca")
	check(frame_button != null, "frame offered after heart four")
	await shot("frame-choice-320")
	if frame_button != null: frame_button.pressed.emit()
	await process_frame
	await RenderingServer.frame_post_draw
	await process_frame
	check(app.session.pet.photos.size() == 2, "frame choice captures photo")
	root.size = Vector2i(390, 844)
	root.content_scale_size = root.size
	close()
	app._select_tab("journal")
	await shot("album-390")
	print("BOND HEART UI FAILURES: ", failed)
	app.queue_free()
	await process_frame
	quit(1 if failed else 0)
func find_button(node: Node, title: String) -> Button:
	if node is Button and node.text == title: return node
	for child in node.get_children():
		var found := find_button(child, title)
		if found != null: return found
	return null

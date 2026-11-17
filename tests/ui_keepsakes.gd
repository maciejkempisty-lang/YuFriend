extends SceneTree
var app: Control
var failed := 0
func _initialize() -> void:
	create_timer(40).timeout.connect(func(): quit(1))
	call_deferred("run")
func check(ok: bool, label: String) -> void:
	if not ok:
		failed += 1
		push_error(label)
	else: print("PASS EXTRA " + label)
func shot(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/yuf-extra-" + name + ".png")
func close_windows() -> void:
	for child in app.get_children():
		if child is AcceptDialog: child.hide()
func run() -> void:
	root.size = Vector2i(390, 844)
	root.content_scale_size = root.size
	app = load("res://scenes/Main.tscn").instantiate()
	app.save_path_override = "/tmp/yuf-extra-%s/pet.json" % Time.get_ticks_usec()
	root.add_child(app)
	var game: GameSession = app.session
	game.set_process(false)
	game.pet.bond = 75 # This suite previews every unlocked decoration.
	game.pet.skills.sit.mastery = 100
	game.pet.skills.bow.mastery = 100
	game.pet.skills.lie.mastery = 100
	game.pet.skills.paw.mastery = 57
	game.pet.remember("yard_find_0", "Kamyk", "Znalezisko")
	await create_timer(0.5).timeout
	for key in KeepsakeSystem.DECOR:
		check(KeepsakeSystem.toggle_decor(game, key), "decoration toggles: " + key)
	check(app.room.backdrop.decor == game.pet.decor, "scene receives selected decorations")
	app._show_decor()
	await shot("decor-menu")
	close_windows()
	app.room.show_overview()
	await shot("decor-room")
	await app._take_photo()
	check(game.pet.photos.size() == 1, "camera saves actual scene")
	var photo: Dictionary = game.pet.photos[0]
	print("PHOTO_PATH ", KeepsakeSystem.photo_path(game.storage.path, photo.id))
	app._select_tab("journal")
	await shot("album")
	check(app.photos_list.get_child_count() == 1, "album renders captured photo")
	app._select_tab("care")
	app._toggle_yard()
	await app._take_photo()
	check(game.pet.photos.size() == 2 and game.pet.photos[0].caption.ends_with("Podwórko"), "camera also saves outdoor scene")
	app._select_tab("training")
	for key in ["spin", "roll"]:
		app._choose_trick(key)
		check(game.begin_training(key, true), "new trick starts: " + key)
		check(app.room.animator.current == key or app.room.animator.pending == key, "correct generated clip requested")
		for i in 40:
			app.room.animator._process(0.1)
			app.room._process(0.1)
			game._process(0.1)
			if game.training.phase == "reward": break
		check(game.training.phase == "reward", "new trick waits for performance then permits reward")
		check(game.give_reward("praise") and float(game.pet.skills[key].mastery) > 0, "new trick earns progress")
		game._process(2)
		game.activity = "idle"
		game.activity_left = 0
		game._cancel_motion()
	root.size = Vector2i(320, 640)
	root.content_scale_size = root.size
	await process_frame
	app._show_tricks()
	await shot("tricks-narrow")
	for child in app.get_children():
		if child is AcceptDialog and child.title == "Sztuczki pieska":
			check(child.size.y <= 576 and child.get_child(0) is ScrollContainer, "nine tricks use scrollable phone catalogue")
	close_windows()
	app._show_decor()
	await shot("decor-narrow")
	for child in app.get_children():
		if child is AcceptDialog and child.title == "Dekoracje pokoju": check(child.size.x <= 320 and child.size.y <= 576, "decorations fit narrow phone")
	close_windows()
	game.flush()
	var loaded: PetState = game.storage.load_pet().pet
	check(loaded.photos.size() == 2 and loaded.decor.size() == KeepsakeSystem.DECOR.size() and loaded.skills.paw.mastery == 57, "reload keeps new extras and old partial mastery")
	app._select_tab("journal")
	var remove_id: String = game.pet.photos[0].id
	app._confirm_remove_photo(remove_id)
	await process_frame
	var removal: ConfirmationDialog
	for child in app.get_children():
		if child is ConfirmationDialog: removal = child
	check(removal != null and removal.visible and removal.size.x <= 320, "photo removal requires readable confirmation")
	removal.hide()
	await process_frame
	check(game.pet.photos.size() == 2, "cancel confirmation preserves both photos")
	app._confirm_remove_photo(remove_id)
	await process_frame
	for child in app.get_children():
		if child is ConfirmationDialog and child.visible:
			child.confirmed.emit()
			child.hide()
	await process_frame
	check(game.pet.photos.size() == 1 and app.photos_list.get_child_count() == 1, "confirmed removal updates album immediately")
	check(game.storage.load_pet().pet.photos.size() == 1, "confirmed removal persists")
	app.queue_free()
	await process_frame
	print("EXTRAS FAILURES: ", failed)
	quit(1 if failed else 0)

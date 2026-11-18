extends SceneTree
var failed := 0
var app: Control
func _initialize() -> void:
	create_timer(35).timeout.connect(func(): quit(1))
	call_deferred("run")
func check(ok: bool, label: String) -> void:
	if not ok:
		failed += 1
		push_error(label)
	else: print("PASS BATH " + label)
func wash_zone(view: BathView, zone: int) -> void:
	var start := view.zone_center(zone)
	var press := InputEventScreenTouch.new()
	press.index = 0
	press.position = start
	press.pressed = true
	view._gui_input(press)
	for i in 12:
		var move := InputEventScreenDrag.new()
		move.index = 0
		move.position = start + Vector2(-10 if i % 2 == 0 else 10, 0)
		view._gui_input(move)
	press.pressed = false
	view._gui_input(press)
func shot(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/yuf-bath-" + name + ".png")
func run() -> void:
	root.size = Vector2i(390, 844)
	root.content_scale_size = root.size
	app = load("res://scenes/Main.tscn").instantiate()
	app.save_path_override = preload("res://tests/helper_paths.gd").data_root() + "/yuf-bath-%s/pet.json" % Time.get_ticks_usec()
	app.room.ambient_life.life.autoplay = false
	app.session.local_clock = func(): return 100 * 86400.0 + 12 * 3600.0
	root.add_child(app)
	var game: GameSession = app.session
	game.set_process(false)
	game.pet.needs.hygiene = 40
	game.pet.skills.sit.mastery = 100
	game.pet.skills.paw.mastery = 57
	game.pet.remember("yard_find_0", "Kamyk", "Pamiątka")
	var identity: String = game.pet.pet_id
	await create_timer(0.5).timeout
	app._show_bath()
	await process_frame
	check(game.in_bath and game.busy(), "bath reserves session")
	check(not game.finish_bath(), "cannot claim cleanliness before gestures")
	var view: BathView = app.bath_dialog.get_child(0)
	wash_zone(view, 0)
	check(game.bath.stage == 0, "one patch cannot skip whole stage")
	app.bath_dialog.hide()
	await process_frame
	check(not game.in_bath and game.pet.needs.hygiene == 40, "cancel preserves hygiene")
	app._show_bath()
	await process_frame
	view = app.bath_dialog.get_child(0)
	await shot("soap")
	for stage in 3:
		for zone in 3: wash_zone(view, zone)
		check(game.bath.stage == stage + 1, "all areas advance exactly one stage")
		if stage < 2:
			check(game.pet.needs.hygiene == 40, "unfinished bath does not grant cleanliness")
			await shot("stage-%d" % (stage + 1))
	check(game.pet.needs.hygiene == 85 and game.pet.milestones.has("first_bath"), "towel completion cleans and records first bath")
	check(not game.finish_bath(), "duplicate completion rejected")
	check(view.puppy.current == "shake", "completion plays generated shake animation")
	await shot("shake")
	app.bath_dialog.hide()
	await process_frame
	var loaded := game.storage.load_pet()
	check(loaded.pet.pet_id == identity and loaded.pet.skills.sit.mastery == 100 and loaded.pet.skills.paw.mastery == 57 and loaded.pet.milestones.has("yard_find_0"), "reload preserves identity skills and finds")
	check(loaded.pet.needs.hygiene == 85, "bath cleanliness survives reload")
	game.change_yard(true)
	check(game.start_sniff(), "outdoor search starts")
	game.destination_reached()
	game._finish_sniff()
	check(game.pet.needs.hygiene == 77, "completed outdoor sniff dirties coat")
	game.change_yard(false)
	app._show_bath()
	await process_frame
	app._notification(MainLoop.NOTIFICATION_APPLICATION_PAUSED)
	check(not game.in_bath and game.suspended and game.pet.needs.hygiene == 77, "background cancels bath without reward")
	game.resume_session()
	root.size = Vector2i(320, 640)
	root.content_scale_size = root.size
	await process_frame
	app._show_bath()
	await process_frame
	await shot("narrow")
	check(app.bath_dialog.size.x <= 320 and app.bath_dialog.size.y <= 640, "bath fits narrow screen")
	app.bath_dialog.hide()
	await process_frame
	app.queue_free()
	await process_frame
	print("BATH FAILURES: ", failed)
	quit(1 if failed else 0)

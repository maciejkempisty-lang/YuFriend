extends SceneTree
var app: Control
var failed := 0
var passed := 0
func _initialize() -> void:
	create_timer(60).timeout.connect(func(): quit(1))
	call_deferred("run")
func check(ok: bool, label: String) -> void:
	if ok:
		passed += 1
		print("PASS HIDE UI " + label)
	else:
		failed += 1
		push_error(label)
func tick(count: int) -> void:
	for i in count:
		app.room.animator._process(0.1)
		app.room._process(0.1)
		app.session._process(0.1)
func shot(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/yuf-hide-" + name + ".png")
func run() -> void:
	root.size = Vector2i(390, 844)
	root.content_scale_size = root.size
	app = load("res://scenes/Main.tscn").instantiate()
	app.save_path_override = "/tmp/yuf-hide-ui-%s/pet.json" % Time.get_ticks_usec()
	root.add_child(app)
	var game: GameSession = app.session
	game.local_clock = func(): return 100 * 86400.0 + 12 * 3600
	game.set_process(false)
	game._brain_left = INF
	app.room.set_process(false)
	app.room.animator.set_process(false)
	game.pet.skills.sit.mastery = 100
	game.pet.yard_record = 4.5
	var identity := game.pet.pet_id
	app._toggle_yard(false)
	app.sniff_button.pressed.emit()
	await process_frame
	var menu: AcceptDialog
	for child in app.get_children():
		if child is AcceptDialog and child.title == "Zabawy w krzakach": menu = child
	check(menu != null and menu.visible, "bush toolbar opens three-game menu")
	await shot("menu")
	menu.get_child(0).get_child(1).pressed.emit()
	await process_frame
	check(game.hide_game.phase == "choose" and app.room.overview and app.room.puppy.visible, "treat game shows selectable bushes and waiting dog")
	var chosen: int = game.hide_game.search_order[2]
	app.room.yard_markers["bush_%d" % chosen].pressed.emit()
	check(game.activity == "hide_walk" and not app.room.overview, "chosen bush starts visible search")
	var visits := {}
	for i in 1100:
		tick(1)
		if game.activity == "hide_sniff":
			visits[game.hide_game.search_spot()] = true
			if visits.size() == 1 and game.hide_game.elapsed < 0.15: await shot("sniff")
		if not game.hide_game.active(): break
	check(visits.size() == 3, "dog physically visits and sniffs all three bushes when treat is last")
	check(game.pet.milestones.has("yard_hide_treat") and app.room.animator.current == "tail_wag_stand", "discovery celebrates and saves memory")
	tick(20)
	for width in [390, 320]:
		root.size = Vector2i(width, 844 if width == 390 else 640)
		root.content_scale_size = root.size
		await process_frame
		await process_frame
		check(game.start_hide("dog", width), "dog mode starts at width %d" % width)
		check(not app.room.puppy.visible and not app.room.hide_tail.visible, "setup conceals dog before revealing tail")
		tick(13)
		check(game.hide_game.phase == "guess" and app.room.hide_tail.visible and not app.room.puppy.visible, "only tail reveals hiding place")
		var position: Vector2 = app.room.hide_tail.position
		check(position.x == 420 + 400 * game.hide_game.hiding_spot, "tail belongs to correct physical bush")
		var phase: float = app.room.hide_tail.roll_phase
		tick(2)
		check(app.room.hide_tail.roll_phase != phase, "visible tail wags")
		check(not app.room.overview, "dog search starts at readable zoom")
		# Pan to the clue as the player does; the camera must not auto-reveal it.
		app.room.look_at_world(Vector2(350 + 400 * game.hide_game.hiding_spot, 310))
		await shot("tail-%d" % width)
		check(app.care_status.get_global_rect().end.x <= width, "instructions fit narrow care panel")
		check(not app.companion_card.visible and not app.bubble.visible and not app.gain_label.visible and not app.room.return_button.visible, "hidden dog has no floating companion or bubble")
		var wrong: int = (game.hide_game.hiding_spot + 1) % 3
		app.room.yard_markers["bush_%d" % wrong].pressed.emit()
		check(game.hide_game.phase == "guess" and not app.room.puppy.visible, "wrong bush keeps dog concealed")
		chosen = game.hide_game.hiding_spot
		# Touch actual bush artwork, rather than a hidden correct-answer button.
		var point: Vector2 = app.room.world_to_screen(Vector2(350 + 400 * chosen, 250))
		app.room._pointer_down(point, 0)
		app.room._pointer_up(point, 0)
		check(not game.hide_game.active() and app.room.puppy.visible and not app.room.hide_tail.visible, "correct bush touch reveals dog")
		check(absf(app.room.pet_world.x - (350 + chosen * 400)) < 1, "dog emerges at chosen bush")
		tick(20)
	check(game.pet.milestones.has("yard_hide_dog"), "dog memory persists")
	check(game.start_hide("treat"), "another round can start")
	app.sniff_button.pressed.emit()
	check(not game.hide_game.active() and app.room.puppy.visible, "stop button cancels selection")
	game.start_hide("dog")
	tick(13)
	app._notification(MainLoop.NOTIFICATION_APPLICATION_PAUSED)
	check(game.suspended and not game.hide_game.active() and app.room.puppy.visible and not app.room.hide_tail.visible and not game.in_yard, "background restores dog and cancels round")
	var loaded := game.storage.load_pet()
	check(loaded.pet.pet_id == identity and loaded.pet.skills.sit.mastery == 100 and loaded.pet.yard_record == 4.5, "real reload keeps identity mastery and fetch record")
	check(loaded.pet.milestones.has("yard_hide_treat") and loaded.pet.milestones.has("yard_hide_dog"), "both memories survive reload")
	app.queue_free()
	await process_frame
	await process_frame
	print("YARD HIDE UI RESULTS: %d passed, %d failed" % [passed, failed])
	quit(1 if failed else 0)

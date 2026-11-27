extends SceneTree
var app: GameUI
var passed := 0
var failed := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	if ok: passed += 1
	else:
		failed += 1
		push_error(label)
func shot(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/yuf-visitor-" + name + ".png")
func tick(count: int) -> void:
	for i in count:
		app.room._process(0.1)
		app.room.animator._process(0.1)
		app.session._process(0.1)
func run() -> void:
	root.size = Vector2i(320, 680)
	root.content_scale_size = root.size
	app = load("res://scenes/Main.tscn").instantiate()
	app.save_path_override = preload("res://tests/helper_paths.gd").data_root() + "/yuf-visitor-ui-%s/pet.json" % Time.get_ticks_usec()
	app.room.ambient_life.life.autoplay = false
	# Set the daytime fixture before startup synchronizes automatic sleep.
	app.session.local_clock = func(): return 100 * 86400.0 + 12 * 3600
	root.add_child(app)
	var s := app.session
	s.local_clock = func(): return 100 * 86400.0 + 12 * 3600
	s.set_process(false)
	s._brain_left = INF
	app.room.set_process(false)
	app.room.animator.set_process(false)
	s.pet.traits = {"curiosity": 0.65, "patience": 0.8, "sociability": 0.4, "sensitivity": 0.25}
	await process_frame
	app._toggle_yard(false)
	for guest in YardVisitors.KINDS:
		s.visitors.begin_visit()
		check(s.visitors.start(s, guest), "start " + guest)
		tick(150)
		await process_frame
		check(app.room.fence_visitor.visible and app.room.fence_visitor.kind == guest, "guest rendered")
		check(app.visitor_soothe_button.visible and app.visitor_recall_button.visible and app.tab_buttons.map.visible and app.tab_buttons.care.caption == "Podwórko", "visitor actions and location navigation remain available")
		check(app.visitor_recall_button.get_global_rect().end.x <= 320, "controls fit 320px")
		check(not app.visitor_soothe_button.get_global_rect().intersects(app.visitor_recall_button.get_global_rect()), "controls separate")
		check(app.visitor_toolbar.get_global_rect().position.y >= app.yard_toolbar.get_global_rect().end.y, "visitor responses have a separate row")
		await shot(guest)
		if guest == "cat":
			app.visitor_recall_button.pressed.emit()
			check(s.visitors.active() and app.room.moving, "recall uses real movement")
			tick(100)
			check(app.room.pet_world.distance_to(YardVisitors.safe_spot()) < 1, "returns to player")
		else:
			app.visitor_soothe_button.pressed.emit()
			tick(30)
		check(not s.visitors.active() and not app.room.fence_visitor.visible, "finished guest removed")
	s.visitors.start(s, "cat")
	app._toggle_yard(false)
	check(not s.visitors.active() and not app.room.fence_visitor.visible, "home clears guest")
	# Exercise the actual UI routes, not only the session API.
	s.change_yard(true)
	s.visitors.begin_visit()
	s.visitors.start(s, "cat")
	app._room_care_action("play")
	check(s.play.running() and not s.visitors.active(), "first ball tap starts fetch during a visit")
	s.cancel_touch_game()
	s.visitors.begin_visit()
	s.visitors.start(s, "bird")
	app.sniff_button.pressed.emit()
	await process_frame
	var games: AcceptDialog
	for child in app.get_children():
		if child is AcceptDialog and child.title == "Zabawy w krzakach" and child.visible: games = child
	check(games != null, "bush menu accessible during a visit")
	if games != null:
		for button in games.find_children("*", "Button", true, false):
			if button.text == "Schowaj smakołyk": button.pressed.emit(); break
	check(s.hide_game.active() and not s.visitors.active(), "first hide selection starts play during a visit")
	s.cancel_hide()
	s.visitors.begin_visit()
	s.visitors.start(s, "cat")
	app.room.look_at_world(Vector2(650, 315))
	app.room.update_placement()
	await process_frame
	# The dog may stand on the sandbox: touch a visible part of it, as a player would.
	var sandbox := Vector2.INF
	var area: Rect2 = app.room._screen_rect(RoomLayout.YARD_STATIONS.dig.bounds).grow(10)
	for y in range(int(area.position.y), int(area.end.y), 4):
		for x in range(int(area.position.x), int(area.end.x), 4):
			if sandbox == Vector2.INF and app.room.action_at(Vector2(x, y)) == "yard_dig": sandbox = Vector2(x, y)
	check(sandbox != Vector2.INF, "sandbox stays touchable in the scene during a visit")
	app.room._interact(sandbox)
	check(s.activity == "dig_walk" and not s.visitors.active(), "first sandbox tap starts digging during a visit")
	print("UI VISITORS RESULTS: %d passed, %d failed" % [passed, failed])
	app.queue_free()
	await process_frame
	quit(1 if failed else 0)

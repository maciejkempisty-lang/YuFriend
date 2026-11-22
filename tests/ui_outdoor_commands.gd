extends SceneTree
var app: GameUI
var failed := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	if not ok:
		failed += 1
		push_error(label)
func shot(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/yuf-outdoor-" + name + ".png")
func tick(count: int) -> void:
	for i in count:
		app.room._process(0.1)
		app.room.animator._process(0.1)
		app.session._process(0.1)
func guided() -> void:
	app.yard_command_button.pressed.emit()
	for child in app.get_children():
		if child is AcceptDialog and child.visible:
			check(child.size.x <= 320, "command dialog fits narrow display")
			for button in child.find_children("*", "Button", true, false):
				if button.text == "Komenda z gestem": button.pressed.emit(); return
func run() -> void:
	root.size = Vector2i(320, 680)
	root.content_scale_size = root.size
	app = load("res://scenes/Main.tscn").instantiate()
	app.save_path_override = preload("res://tests/helper_paths.gd").data_root() + "/yuf-outdoor-ui-%s/pet.json" % Time.get_ticks_usec()
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
	s.pet.skills.come.mastery = 100
	s.pet.skills.sit.mastery = 100
	s.pet.skills.stay.mastery = 100
	PracticeSystem.sync(s.pet, s._local_now())
	s.pet.practice.targets = ["come", "stay"]
	await process_frame
	app._toggle_yard(false)
	s.throw_ball(Vector2(1100, 310), Vector2(700, 310))
	for i in 150:
		tick(1)
		if s.fetch.catching: break
	s.catch_ball()
	tick(15)
	check(app.yard_command_button.visible and app.yard_command_button.text == "Przyjdź", "recall replaces bath in toolbar")
	guided()
	for i in 150:
		tick(1)
		if s.outdoor_commands.phase == "praise": break
	check(s.outdoor_commands.phase == "praise", "actual recall arrives")
	check(app.yard_command_button.text == "Pochwal", "praise is actionable")
	await shot("recall")
	app.yard_command_button.pressed.emit()
	check(s.pet.practice.done.has("come"), "UI praise credits recall")
	check(s.start_hide("treat", 42), "treat hide ready")
	check(app.yard_command_button.text == "Zostań", "stay offered before hiding")
	guided()
	tick(25)
	await shot("stay")
	app.yard_command_button.pressed.emit()
	check(s.pet.practice.rewarded, "UI commands complete daily training")
	check(s.choose_hide_bush(0), "hide game continues after stay")
	s.change_yard(false)
	s.pet.yard_routines.flowers = ["daisy", "poppy", "lavender"]
	for plant in YardRoutines.PLANTS: KeepsakeSystem.toggle_decor(s, plant)
	app.room.show_overview()
	await shot("flowers-room")
	app._show_decor()
	await shot("flowers-menu")
	for child in app.get_children():
		if child is AcceptDialog and child.visible: check(child.size.x <= 320 and child.size.y <= 616, "eight decorations scroll on 320 px")
	print("OUTDOOR UI FAILURES: ", failed)
	app.queue_free()
	await process_frame
	quit(1 if failed else 0)

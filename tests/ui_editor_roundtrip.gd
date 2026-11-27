extends SceneTree
## Can consume JSON saved by the browser editor, or create equivalent fixtures.
var passed := 0
var failed := 0
var app: GameUI
var directory: String

func _initialize() -> void:
	create_timer(90).timeout.connect(func(): quit(1))
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	if ok: passed += 1
	else:
		failed += 1
		push_error(label)

func open_game(project_path: String) -> void:
	app = load("res://scenes/Main.tscn").instantiate()
	app.project_path_override = project_path
	app.save_path_override = directory.path_join("pet.json")
	app.session.local_clock = func(): return 100 * 86400.0 + 12 * 3600.0
	root.add_child(app)
	await process_frame
	await process_frame
	app.set_process(false)
	app.session.set_process(false)
	app.room.set_process(false)
	app.room.animator.set_process(false)
	for child in app.get_children():
		if child is Window: child.hide()
	app.naming_pending = false
	app.session.player_activity()
	app.session._cancel_motion()
	app.session.pet.resting = false
	app.session.night_sleep = false
	app.session.scheduled_sleep = false
	app.session.automatic_nap = false
	app.session.activity = "idle"
	app.session.activity_left = 0
	app.session._brain_left = INF
	app.session.pet.needs.energy = 90
	app.app_foreground = true
	app._update_attention()
	app._refresh()
	await process_frame

func close_game() -> void:
	app.session.active = false
	app.music.stop()
	app.effects.stop_all()
	app.queue_free()
	await process_frame

func step(seconds: float) -> void:
	var left := seconds
	while left > 0:
		var delta := minf(left, 0.02)
		app.app_foreground = true
		app._update_attention()
		app.session._process(delta)
		app.room._process(delta)
		app.room.animator._process(delta)
		app._process(delta)
		left -= delta

func advance_until(done: Callable) -> void:
	var left := 60.0
	while not done.call() and left > 0:
		step(0.02)
		left -= 0.02
	check(done.call(), "activity reaches its next phase within 60 seconds")

func tap(script: String) -> void:
	var element := RoomLayoutLoader.element_for_script(script, "home")
	var asset: Dictionary
	for candidate in RoomLayoutLoader.active_project.assets:
		if candidate.id == element.asset: asset = candidate
	var center := LevelProject.element_rect(element, asset).get_center()
	app.room.look_at_world(center)
	var point := app.room.world_to_screen(center)
	check(app.room.editor_element_at(point).get("script") == script, "authored hit area: " + script)
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = point
	event.pressed = true
	app.room.gui_input.emit(event)
	event = event.duplicate()
	event.pressed = false
	app.room.gui_input.emit(event)

func fixture(hidden: bool) -> String:
	var supplied := OS.get_environment("YUFRIEND_EDITOR_HIDDEN" if hidden else "YUFRIEND_EDITOR_MOVED")
	if not supplied.is_empty(): return supplied
	var project: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://level-editor/projects/ver2.json"))
	for element in project.levels[0].elements:
		if element.id in ["food", "drink"]:
			element.x = 980 if element.id == "food" else 1100
			element.visible = not hidden
	var path := directory.path_join("hidden.json" if hidden else "moved.json")
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(project))
	return path

func run() -> void:
	root.size = Vector2i(1100, 720)
	root.content_scale_size = root.size
	directory = load("res://tests/helper_paths.gd").data_root().path_join("qa-editor-roundtrip-%d" % Time.get_ticks_usec())
	DirAccess.make_dir_recursive_absolute(directory)
	await open_game("res://level-editor/projects/ver2.json")
	var original_food := Vector2(RoomLayout.STATIONS.food.position)
	var original_drink := HomeDrink.bowl()
	var original_stand := HomeDrink.stand()
	await close_game()
	await open_game(fixture(false))
	check(RoomLayout.STATIONS.food.position.x == 980 and HomeDrink.bowl().x == 1100, "restart loads both moved bowls")
	check(HomeDrink.stand().x > original_stand.x + 400, "water destination follows moved bowl")
	app.session.pet.needs.fullness = 20
	tap("feed")
	check(app.session._pending_action == "feed", "click starts feeding approach")
	advance_until(func(): return app.session._pending_action.is_empty())
	check(app.room.pet_world.distance_to(RoomLayout.STATIONS.food.stand) < 1, "dog walks to moved food bowl")
	check(app.session.pet.needs.fullness > 35 and app.session._pending_action.is_empty(), "feeding completes after arrival")
	step(2.1)
	tap("drink")
	check(app.session.home_drink.active(), "click starts drinking approach")
	advance_until(func(): return app.session.home_drink.phase == "drink")
	check(app.room.pet_world.distance_to(HomeDrink.stand()) < 1, "dog walks to moved water bowl")
	advance_until(func(): return not app.session.home_drink.active())
	check(not app.session.home_drink.active() and app.session.activity == "idle", "drinking completes")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/yufriend-editor-roundtrip.png")
	await close_game()
	await open_game(fixture(true))
	check(not RoomLayoutLoader.has_script("feed", "home") and not RoomLayoutLoader.has_script("drink", "home"), "restart removes hidden mechanics")
	check(not app.care_buttons.feed.visible, "feeding shortcut disappears")
	check(not app.session.act("feed") and not app.session.home_drink.start(app.session), "hidden mechanics cannot start through system entry points")
	var fullness: float = app.session.pet.needs.fullness
	app._on_editor_interaction("food", "feed", {})
	check(app.session._pending_action.is_empty() and app.session.pet.needs.fullness == fullness, "stale element callback cannot feed")
	app.room.look_at_world(Vector2(980, 490))
	check(app.room.editor_element_at(app.room.world_to_screen(Vector2(980, 490))).is_empty(), "hidden bowl leaves no click target")
	await close_game()
	await open_game("res://level-editor/projects/ver2.json")
	check(RoomLayout.STATIONS.food.position == original_food and HomeDrink.bowl() == original_drink and HomeDrink.stand() == original_stand, "reopening original project resets positions without drift")
	await close_game()
	for name in DirAccess.get_files_at(directory): DirAccess.remove_absolute(directory.path_join(name))
	DirAccess.remove_absolute(directory)
	print("EDITOR ROUNDTRIP UI: %d passed, %d failed" % [passed, failed])
	quit(1 if failed else 0)

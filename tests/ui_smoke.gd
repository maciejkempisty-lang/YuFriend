extends SceneTree

var failed: int = 0
var passed: int = 0
var app: Control
var directory: String

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, label: String) -> void:
	if condition:
		passed += 1
		print("PASS UI " + label)
	else:
		failed += 1
		push_error("FAIL UI " + label)

func _run() -> void:
	root.size = Vector2i(390, 844)
	root.content_scale_size = Vector2i(390, 844)
	directory = "user://qa-integration-%s" % Time.get_ticks_usec()
	app = load("res://scenes/Main.tscn").instantiate()
	app.save_path_override = directory + "/pet.json"
	root.add_child(app)
	var game: GameSession = app.session
	game.set_process(false)
	game._brain_left = INF
	app.room.set_process(false)
	app.room.animator.set_process(false)
	await process_frame
	await process_frame
	check(game.pet != null and game.save_ok, "startup creates and saves a puppy")
	await capture("01-care.png")
	var contact: float = game.pet.needs.contact
	await click_at(app.room.pet_position() - Vector2(0, 75))
	check(game.pet.needs.contact > contact and game.last_message.begins_with("Przymyka"), "clicking the puppy pets it exactly once through the room")
	step_game(2.2)
	var hunger: float = game.pet.needs.fullness
	app.care_buttons.feed.pressed.emit()
	check(float(game.pet.needs.fullness) > hunger, "feeding button changes needs")
	check(game.pet.milestones.has("feed"), "feeding adds real event to journal")
	step_game(2.2)
	app.tab_buttons.training.pressed.emit()
	app.trick_buttons.sit.pressed.emit()
	app.guided_button.pressed.emit()
	check(game.training.phase == "attempt", "guided button begins selected sit trial")
	app.command_edit.text = "podaj łapę"
	app._submit_command()
	check(app.selected_trick == "sit" and game.training.trick == "sit", "text command cannot switch an ongoing training trial")
	check(not game.give_reward("praise"), "UI cannot reward before performance")
	game._process(game.training.time_left + 0.05)
	check(game.training.phase == "attempt", "reward waits for completed animation")
	step_game(1.3)
	check(game.training.phase == "reward" and not app.reward_buttons.praise.disabled, "reward controls activate at correct moment")
	await capture("02-training-reward.png")
	check(visible_above_navigation(app.reward_buttons.praise), "reward buttons fit above navigation without scrolling")
	app.reward_buttons.praise.pressed.emit()
	check(float(game.pet.skills.sit.mastery) > 0, "reward button commits learning")
	var learned: float = game.pet.skills.sit.mastery
	check(not game.give_reward("praise") and game.pet.skills.sit.mastery == learned, "repeated click cannot duplicate reward")
	step_game(1.5)
	game.begin_training("sit", true)
	step_game(game.training.time_left + 0.1)
	game.suspend_session()
	check(not game.give_reward("praise"), "backgrounding invalidates reward")
	game.resume_session()
	check(game.pet.skills.sit.mastery == learned, "resume preserves earned progress only")
	app.tab_buttons.journal.pressed.emit()
	await capture("03-journal.png")
	game.rename_pet("Fado")
	game.change_skin("pixel")
	app.tab_buttons.care.pressed.emit()
	await capture("04-pixel.png")
	var reloaded := SaveSystem.new(directory + "/pet.json").load_pet()
	check(reloaded.pet.pet_name == "Fado" and reloaded.pet.skin == "pixel" and reloaded.pet.skills.sit.mastery == learned, "reload keeps name, skin and learned command")
	await touch_at(app.room.bed_rect().get_center())
	check(game.pet.resting, "touching the bed starts rest through scene input")
	var energy: float = game.pet.needs.energy
	step_game(5)
	check(game.pet.resting and game.pet.needs.energy > energy, "rest button restores energy")
	game.act("rest")
	await click_at(app.room.bowl_rect().get_center())
	check(game.activity == "feed" and game.last_message.begins_with("Mała porcja"), "clicking the bowl feeds once through scene input")
	step_game(3.2)
	await touch_at(app.room.ball_center())
	check(game.activity == "play", "touching the ball starts play through scene input")
	step_game(2.2)
	game.change_skin("simple")
	app._show_profile()
	await capture("05-profile.png")
	check(app.profile_dialog.size.y <= root.size.y - 40 and app.profile_dialog.get_ok_button().get_global_rect().end.y <= app.profile_dialog.size.y, "profile dialog and save button fit on screen")
	app.profile_dialog.hide()
	app._show_command()
	await capture("08-command.png")
	check(app.text_dialog.size.y <= root.size.y - 40 and app.text_dialog.get_ok_button().get_global_rect().end.y <= app.text_dialog.size.y, "command dialog and submit button fit on screen")
	app.text_dialog.hide()
	app._select_tab("care")
	# Wider and narrower layouts exercise the same touch UI.
	root.size = Vector2i(540, 960)
	root.content_scale_size = Vector2i(540, 960)
	await capture("06-wide.png")
	root.size = Vector2i(360, 800)
	root.content_scale_size = Vector2i(360, 800)
	await capture("07-narrow.png")
	var overflowing := []
	_find_overflow(app, overflowing)
	check(overflowing.is_empty(), "narrow controls stay inside viewport: " + str(overflowing))
	check(visible_above_navigation(app.care_buttons.train), "narrow care actions fit above navigation")
	app._select_tab("training")
	await capture("09-narrow-training.png")
	check(visible_above_navigation(app.guided_button), "narrow training actions fit above navigation")
	# Exercise the actual stretch configuration, without changing the base viewport.
	root.size = Vector2i(1100, 720)
	root.content_scale_size = Vector2i(390, 844)
	app._select_tab("care")
	await capture("10-landscape.png")
	check(app.layout_wide and app.room.size.x <= app.sheet.position.x, "wide window places controls beside the room")
	check(visible_above_navigation(app.care_buttons.train), "wide action panel stays usable")
	root.size = Vector2i(320, 640)
	root.content_scale_size = Vector2i(390, 844)
	app._select_tab("training")
	await capture("11-short-training.png")
	overflowing.clear()
	_find_overflow(app, overflowing)
	check(overflowing.is_empty() and visible_above_navigation(app.guided_button), "small training viewport keeps actions within bounds: " + str(overflowing))
	# Save warnings must not cover the last action in the panel.
	game.save_ok = false
	app._refresh()
	await process_frame
	check(app.footer_label.visible and app.sheet.get_rect().end.y <= app.footer_label.position.y, "save warning has its own space below actions")
	game.active = false
	app.queue_free()
	await process_frame
	_cleanup()
	print("UI RESULTS: %d passed, %d failed" % [passed, failed])
	quit(1 if failed else 0)

func click_at(point: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	root.push_input(motion, true)
	var event := InputEventMouseButton.new()
	event.position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	root.push_input(event, true)
	event = event.duplicate()
	event.pressed = false
	root.push_input(event, true)
	await process_frame

func touch_at(point: Vector2) -> void:
	var event := InputEventScreenTouch.new()
	event.position = point
	event.pressed = true
	root.push_input(event, true)
	event = event.duplicate()
	event.pressed = false
	root.push_input(event, true)
	await process_frame

func visible_above_navigation(control: Control) -> bool:
	return control.is_visible_in_tree() and control.get_global_rect().end.y <= app.navigation.position.y and control.get_global_rect().position.y >= 0

func capture(name: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var output := ProjectSettings.globalize_path("res://test-results")
	DirAccess.make_dir_recursive_absolute(output)
	var ignore := FileAccess.open(output.path_join(".gdignore"), FileAccess.WRITE)
	if ignore != null: ignore.close()
	var shot := root.get_texture().get_image()
	if not shot.is_empty():
		shot.save_png(output.path_join(name))

func step_game(seconds: float) -> void:
	var left := seconds
	while left > 0:
		var delta := minf(left, 0.02)
		app.session._process(delta)
		app.room._process(delta)
		app.room.animator._process(delta)
		left -= delta

func _find_overflow(node: Node, result: Array) -> void:
	if node is Control and node.is_visible_in_tree():
		var rect: Rect2 = node.get_global_rect()
		if rect.end.x > app.size.x + 2 and not node is ScrollContainer:
			result.append(str(node.name) + ":" + str(rect.end.x))
	for child in node.get_children():
		if not child is Window: _find_overflow(child, result)

func _cleanup() -> void:
	var absolute := ProjectSettings.globalize_path(directory)
	var dir := DirAccess.open(absolute)
	if dir != null:
		for file in dir.get_files(): DirAccess.remove_absolute(absolute.path_join(file))
		DirAccess.remove_absolute(absolute)

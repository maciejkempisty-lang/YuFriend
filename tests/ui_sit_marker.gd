extends SceneTree
var app: GameUI
var failed := 0
var observed := false
func check(ok: bool, label: String) -> void:
	if not ok:
		failed += 1
		push_error(label)
func _initialize() -> void:
	create_timer(60).timeout.connect(func(): quit(1))
	call_deferred("run")
func shot(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/yuf-sit-"+name+".png")
func run() -> void:
	root.size = Vector2i(390,844)
	root.content_scale_size = root.size
	app = load("res://scenes/Main.tscn").instantiate()
	app.save_path_override = preload("res://tests/helper_paths.gd").data_root() + "/yuf-marker-%s/pet.json" % Time.get_ticks_usec()
	app.session.local_clock = func(): return 20000 * 86400.0 + 12 * 3600
	root.add_child(app)
	app.session.set_process(false)
	app.room.ambient_life.life.autoplay = false
	app.session.pet.skills.sit.mastery = 100
	app.session.pet.needs.energy = 100
	app.session.pet.needs.fullness = 100
	app._select_tab("training")
	app._choose_trick("sit")
	check(not app.guidance_toggle.button_pressed, "mastered sit starts with a word")
	app.session.pet.skills.sit.mastery = 39
	app._choose_trick("sit")
	check(not app.guidance_toggle.button_pressed, "default follows learning instead of forcing full gesture")
	app.session.pet.skills.sit.mastery = 100
	await shot("ready")
	for attempt in 5:
		app._train(true)
		await shot("lure")
		if is_instance_valid(app.gesture_dialog) and app.gesture_dialog.visible: break
	if not is_instance_valid(app.gesture_dialog):
		push_error("Gesture unavailable: " + app.session.last_message)
		quit(1)
		return
	check(app.gesture_dialog.visible and app.gesture_dialog.borderless, "full gesture available for mastered trick")
	app.gesture_dialog.hide()
	await process_frame
	app.room.animator.sitting_contact.connect(func(id):
		if app.session.training.marker_mode and app.session.training.phase == "attempt":
			observed = true
			check(app.room.animator.sprite.frame == PetAnimator.SIT_CONTACT_FRAME, "marker uses authored contact frame")
			app.marker_button.button_down.emit())
	app._train(false)
	await shot("attempt")
	for i in 300:
		if observed: break
		await process_frame
	check(observed and app.session.training.phase == "reward", "real animation plus click opens reward")
	check(app.session.training.marker_grade == "perfect", "contact-frame click is ideal")
	app.session.training.advance(60)
	check(app.session.training.phase == "reward", "reward remains available without countdown")
	await shot("reward")
	app._reward("treat")
	check(app.session.pet.skills.sit.mastery == 100 and app.session.pet.skills.sit.successes > 0, "real reward preserves mastery and records success")
	check(app.session.storage.load_pet().pet.skills.sit.mastery == 100, "mastery persisted")
	root.size = Vector2i(320,680)
	root.content_scale_size = root.size
	app.session.activity = "idle"
	app.session.activity_left = 0
	app._refresh()
	await shot("narrow")
	check(app.guided_button.get_global_rect().end.x <= 320, "sit controls fit narrow phone")
	check(app.training_actions.get_global_rect().end.y <= app.navigation.position.y, "controls clear navigation")
	app._train(false)
	app._select_tab("care")
	check(app.session.training.phase == "idle", "leaving training cancels marker trial")
	app.queue_free()
	await process_frame
	print("SIT MARKER UI FAILURES: ",failed)
	quit(1 if failed else 0)

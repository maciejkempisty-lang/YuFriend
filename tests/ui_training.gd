extends SceneTree
var failures := 0
func _initialize() -> void:
	create_timer(20).timeout.connect(func(): quit(1))
	call_deferred("run")
func check(ok: bool, text: String) -> void:
	if not ok:
		failures += 1
		push_error(text)
	else: print("PASS " + text)
func run() -> void:
	root.size = Vector2i(390, 844)
	root.content_scale_size = root.size
	var app = load("res://scenes/Main.tscn").instantiate()
	app.save_path_override = "/tmp/yuf-training-%s/pet.json" % Time.get_ticks_usec()
	app.room.ambient_life.life.autoplay = false
	root.add_child(app)
	app.session.set_process(false)
	app.session.pet.skills.sit.mastery = 100
	app._select_tab("training")
	for key in ["lie", "stay"]:
		app._choose_trick(key)
		app._train(true)
		await process_frame
		var dialog: AcceptDialog = app.gesture_dialog
		var gesture: TrainingGesture = dialog.get_child(0)
		check(app.session.training.phase == "idle", "gesture waits before charging energy")
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/yuf-gesture-%s.png" % key)
		var start := gesture.point(0.5 if key == "stay" else 0.0)
		gesture.press(start, 0)
		if key == "stay":
			for i in 22: gesture._process(0.1)
		else: gesture.move(gesture.point(1), 0)
		gesture.release(start if key == "stay" else gesture.point(1), 0)
		check(app.session.training.phase == "attempt" and app.session.training.will_succeed, "successful gesture begins guaranteed guided performance")
		app.session.training.cancel()
		app.session.activity = "idle"
		await process_frame
	app.session.pet.practice = PracticeSystem.initial()
	app._show_tricks(true)
	await process_frame
	for child in app.get_children():
		if child is AcceptDialog and child.title == "Dziś":
			check(child.find_children("*", "Button", true, false).size() >= 3, "training opens the shared Today suggestions")
			child.hide()
	await process_frame
	app._choose_trick("sit")
	app.session.pet.practice.forms.sit.value = 75
	app.session.training.begin(app.session.pet, "sit", true)
	app.session.training.advance(app.session.training.time_left)
	app._reward("praise")
	check(app.training_feedback.contains("Forma +25") and not app.training_feedback.contains("Dziś"), "mastered trick reports form without daily counters")
	for width in [390, 320]:
		root.size = Vector2i(width, 844 if width == 390 else 640)
		root.content_scale_size = root.size
		await process_frame
		await process_frame
		check(app.practice_label.get_global_rect().end.x <= width, "practice indicator fits %d points" % width)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/yuf-practice-ui-%d.png" % width)
	app.queue_free()
	await process_frame
	await process_frame
	print("Training UI failures: ", failures)
	quit(1 if failures else 0)

extends SceneTree

var passed := 0
var failed := 0
var app: Control
var now := 100 * 86400.0 + 23 * 3600
var directory := "/tmp/yufriend-ui-rhythm-%s" % Time.get_ticks_usec()

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, label: String) -> void:
	if ok:
		passed += 1
		print("PASS " + label)
	else:
		failed += 1
		push_error("FAIL " + label)

func _run() -> void:
	root.size = Vector2i(390, 844)
	root.content_scale_size = root.size
	app = load("res://scenes/Main.tscn").instantiate()
	app.save_path_override = directory.path_join("pet.json")
	app.room.ambient_life.life.autoplay = false
	app.session.local_clock = func(): return now
	root.add_child(app)
	app.session.set_process(false)
	app.room.set_process(false)
	app.room.animator.set_process(false)
	app.set_process(false)
	app.session.initiatives_enabled = false
	app.session._brain_left = INF
	app.app_foreground = true
	await process_frame
	advance(5)
	check(not app.session.is_sleeping() and app.room.animator.pose == "stand", "real night startup greets with an awake dog")
	check(app.session.play_readiness().is_empty(), "new night player can play immediately")
	await capture("rhythm-night-greeting-390.png")
	app.session._brain_left = INF
	for index in 6000:
		advance(0.05)
		if app.session.night_sleep: break
	advance(4)
	check(app.session.night_sleep and app.room.animator.current == "sleep", "inactivity eventually reaches the sleep animation")
	check(app.room.pet_world.distance_to(RoomLayout.STATIONS.bed.stand) < 1, "bedtime walk places dog inside bed")
	check(app.care_buttons.rest.caption == "Obudź" and app.companion_data.action == "rest", "both UI routes offer waking")
	await capture("rhythm-night-390.png")
	app.room.care_requested.emit("pet")
	advance(4)
	check(not app.session.is_sleeping() and app.room.animator.pose == "stand", "touch wakes through real animator transitions")
	check(app.session.start_touch_game("tug"), "night player opens real tug game")
	advance(5)
	check(app.play_dialog.visible and not app.session.night_sleep, "night game panel remains available")
	await capture("rhythm-night-play-390.png")
	app.session.cancel_touch_game()
	app.session._idle_seconds = 100
	app.session._woken_at_night = true
	advance(0.2)
	check(app.session.sleep_warning and app.companion_data.action == "pet", "night warning renders an actionable cuddle button")
	await capture("rhythm-warning-390.png")
	app.session.player_activity()
	now = 101 * 86400.0 + 20 * 3600
	app.session._start_behavior("carpet")
	advance(45)
	check(app.room.animator.pose == "lie" and app.room.pet_world.distance_to(Vector2(640, 324)) < 1, "evening sequence reaches carpet and lying pose")
	await capture("rhythm-evening-390.png")
	app.session._cancel_motion()
	app.session.activity = "idle"
	app.session.activity_left = 0
	app.session.player_activity()
	now = 102 * 86400.0 + 12 * 3600
	app.session._start_behavior("window")
	var history: Array = app.session.pet.history.duplicate(true)
	for index in 1800:
		advance(0.05)
		if app.session._sequence_id.is_empty(): break
	advance(1)
	check(app.session._sequence_id.is_empty() and app.room.animator.pose == "lie", "real movement completes window-to-carpet sequence")
	check(app.session.pet.history == history, "visible autonomous sequence adds no player activity")
	await capture("rhythm-window-return-390.png")
	app._select_tab("training")
	advance(1)
	var training_position: Vector2 = app.room.pet_world
	check(app.session.begin_training("sit", true), "training trial starts through the real session")
	for index in 200:
		advance(0.05)
		if app.session.training.phase == "reward": break
	check(app.session.give_reward("praise"), "training reward accepted with real animator completion")
	advance(20)
	check(app.room.pet_world == training_position and not app.room.moving and app.room.animator.pose == "sit", "training tab keeps dog seated at the same place between trials")
	await capture("rhythm-training-stay-390.png")
	check(app.session.begin_training("sit", true), "next training repetition stays available")
	app.session.training.cancel()
	app._select_tab("care")
	app.session._start_behavior("night")
	app.session.suspend_session()
	check(app.session._sequence.is_empty() and not app.room.moving, "background cancels queued movement in both logic and view")
	app.session.resume_session()
	app.queue_free()
	await process_frame
	for file in DirAccess.get_files_at(directory): DirAccess.remove_absolute(directory.path_join(file))
	DirAccess.remove_absolute(directory)
	print("RHYTHM UI RESULTS: %d passed, %d failed" % [passed, failed])
	quit(1 if failed else 0)

func advance(seconds: float) -> void:
	for index in ceili(seconds / 0.05):
		app.app_foreground = true
		app._update_attention()
		app.session._process(0.05)
		app.room.animator._process(0.05)
		app.room._process(0.05)
		app._process(0.05)

func capture(name: String) -> void:
	app._refresh()
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://test-results/" + name)

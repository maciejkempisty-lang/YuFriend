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
func tick() -> void:
	app.room.animator._process(0.1)
	app.room._process(0.1)
	app.session._process(0.1)
func until(phase: String) -> void:
	for i in 600:
		if app.session.course.phase == phase: return
		tick()
	check(false, "timed out reaching " + phase)
func shot(name: String) -> void:
	app._refresh()
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/yuf-course-" + name + ".png")
func run() -> void:
	root.size = Vector2i(320, 680)
	root.content_scale_size = root.size
	app = load("res://scenes/Main.tscn").instantiate()
	app.save_path_override = preload("res://tests/helper_paths.gd").data_root() + "/yuf-course-ui-%s/pet.json" % Time.get_ticks_usec()
	# Set the daytime fixture before startup synchronizes automatic sleep.
	app.session.local_clock = func(): return 100 * 86400.0 + 12 * 3600
	root.add_child(app)
	app.session.set_process(false)
	app.room.set_process(false)
	app.room.animator.set_process(false)
	app.session.pet.pet_name = "Gloria"
	app.session.pet.skills.sit.mastery = 100
	app.session.pet.needs.energy = 95
	app.session.pet.needs.fullness = 95
	app.session.weather.override_kind = "sun"
	app.session.local_clock = func(): return 100 * 86400.0 + 12 * 3600
	app.session._brain_left = INF
	app.session.visitors.wait_left = INF
	await process_frame
	app._toggle_yard(false)
	app.room.show_overview()
	await shot("overview")
	check(app.room.yard_markers.size() == 12, "twelve places")
	for a in app.room.yard_markers.values():
		check(a.visible, "overview marker visible")
		for b in app.room.yard_markers.values():
			if a != b: check(not a.get_rect().intersects(b.get_rect()), "station targets do not overlap")
	app.room.yard_markers.course.pressed.emit()
	check(app.session.course.active() and app.room.yard_course.playing, "course marker starts round")
	until("jump_ready")
	await shot("fence")
	check(app.room.pet_world.distance_to(YardCourse.PATH[-1]) < 1, "real slalom reaches fence")
	check(app.course_action.visible and app.course_action.text == "Skacz", "jump action offered")
	check(app.course_stop.get_global_rect().end.x <= 320, "course buttons fit narrow screen")
	app.course_action.pressed.emit()
	for i in 7: tick()
	await shot("jump")
	check(app.room.jump_lift > 50 and app.room.animator.position.y < -50, "Gloria visibly airborne")
	check(app.room.shadow.position.y == 0, "shadow stays on ground")
	until("stay_ready")
	await shot("podium")
	check(app.room.pet_world.distance_to(YardCourse.PODIUM) < 1 and app.room.jump_lift == 0, "land then reach podium")
	app.course_action.pressed.emit()
	until("praise")
	await shot("stay")
	check(app.course_action.text == "Pochwal", "praise actual stay")
	app.course_action.pressed.emit()
	check(not app.session.course.active() and app.session.pet.skills.stay.successes == 1, "UI finishes and trains stay")
	check(app.session.pet.milestones.has("yard_course"), "UI finish adds album memory")
	app.session.pet.fatigue = 0
	app.room.yard_markers.course.pressed.emit()
	until("jump_ready")
	app.course_action.pressed.emit()
	for i in 7: tick()
	app.session.suspend_session()
	app._refresh()
	check(not app.room.jump_motion.active() and app.room.animator.position.y == 0 and not app.room.yard_course.visible, "background cancels airborne pose and course")
	app.music.stop()
	app.effects.stop_all()
	app.queue_free()
	app = null
	await process_frame
	await create_timer(0.3).timeout
	print("COURSE UI RESULTS: %d passed, %d failed" % [passed, failed])
	quit(1 if failed else 0)

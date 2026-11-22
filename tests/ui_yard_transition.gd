extends SceneTree
var app: GameUI
var passed := 0
var failed := 0
func check(ok: bool, label: String) -> void:
	if ok: passed += 1
	else:
		failed += 1
		push_error(label)
func _initialize() -> void: call_deferred("run")
func step(count: int) -> void:
	for i in count:
		app.room.animator._process(0.05)
		app.room._process(0.05)
		app.yard_transition._process(0.05)
func finish() -> void:
	for i in 400:
		step(1)
		if app.yard_transition.phase.is_empty(): return
func shot(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/yuf-transition-" + name + ".png")
func run() -> void:
	root.size = Vector2i(320, 680)
	root.content_scale_size = root.size
	app = load("res://scenes/Main.tscn").instantiate()
	app.save_path_override = preload("res://tests/helper_paths.gd").data_root() + "/yuf-transition-%s/pet.json" % Time.get_ticks_usec()
	app.room.ambient_life.life.autoplay = false
	app.session.local_clock = func(): return 100 * 86400.0 + 12 * 3600
	root.add_child(app)
	app.session.set_process(false)
	app.room.set_process(false)
	app.room.animator.set_process(false)
	app.yard_transition.set_process(false)
	await process_frame
	var before := app.session.pet.to_dict()
	app.yard_button.pressed.emit()
	check(app.yard_transition.phase == "approach" and not app.session.in_yard, "button starts approach without teleporting")
	check(app.session.busy() and not app.yard_transition.start(true), "double tap cannot restart crossing")
	var start := app.room.pet_world
	step(20)
	check(app.room.pet_world.x > start.x, "dog moves toward indoor door")
	await shot("approach")
	for i in 250:
		step(1)
		if app.yard_transition.phase == "fade_out": break
	check(app.room.station_nodes.door.portal_open, "door opens on arrival")
	await shot("door-open")
	for i in 30:
		step(1)
		if app.yard_transition.phase == "fade_in": break
	check(app.session.in_yard and app.room.pet_world.x < 270, "crossing places dog at gate not room center")
	await shot("enter-yard")
	finish()
	check(app.session.in_yard and app.yard_transition.phase.is_empty() and not app.session.busy(), "exit animation ends on yard")
	check(not app.yard_transition.visible and app.room.puppy.modulate.a == 1 and app.room.portal_speed == 0, "overlay opacity and speed reset")
	app._room_care_action("yard_gate")
	check(app.yard_transition.phase == "approach", "gate starts homeward animation")
	finish()
	check(not app.session.in_yard and app.room.pet_world.x > 1100, "return enters through indoor door")
	var after := app.session.pet.to_dict()
	before.erase("last_seen_at") # Focus changes may flush the visit timestamp.
	after.erase("last_seen_at")
	check(after == before, "both directions preserve all puppy progress")
	await shot("home")
	app.yard_button.pressed.emit()
	step(10)
	app.yard_transition.cancel_button.pressed.emit()
	check(not app.session.in_yard and not app.session.portal_active and not app.room.moving, "cancel leaves current scene usable")
	app.yard_button.pressed.emit()
	app._notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	check(app.yard_transition.phase.is_empty() and not app.yard_transition.visible and app.session.suspended, "background cancels overlay and movement")
	app.session.suspended = false
	app.session.local_clock = func(): return 100 * 86400.0 + 23 * 3600
	check(not app.yard_transition.start(true) and not app.yard_transition.visible, "night blocks exit before animation")
	app.session.local_clock = func(): return 100 * 86400.0 + 12 * 3600
	app.yard_transition.start(true)
	app.session.local_clock = func(): return 100 * 86400.0 + 23 * 3600
	finish()
	check(not app.session.in_yard and not app.yard_transition.visible, "night at threshold safely cancels crossing")
	print("TRANSITION UI: %d passed, %d failed" % [passed, failed])
	app.queue_free()
	await process_frame
	quit(1 if failed else 0)

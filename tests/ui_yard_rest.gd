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
		if app.session.yard_rest.phase == phase: return
		tick()
	check(false, "timed out reaching " + phase)
func shot(name: String) -> void:
	app._refresh()
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/yuf-rest-" + name + ".png")
func run() -> void:
	root.size = Vector2i(320, 680)
	root.content_scale_size = root.size
	app = load("res://scenes/Main.tscn").instantiate()
	app.save_path_override = "/tmp/yuf-rest-ui-%s/pet.json" % Time.get_ticks_usec()
	root.add_child(app)
	app.session.set_process(false)
	app.room.set_process(false)
	app.room.animator.set_process(false)
	app.session.pet.pet_name = "Gloria"
	app.session.pet.skills.sit.mastery = 100
	app.session.pet.needs.energy = 50
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
	app.room.yard_markers.shade.pressed.emit()
	var dialog: AcceptDialog
	for child in app.get_children():
		if child is AcceptDialog and child.title == "Chwila w cieniu": dialog = child
	check(is_instance_valid(dialog), "shade opens choices")
	check(dialog.size.x <= 320, "choices fit narrow screen")
	for button in dialog.find_children("*", "Button", true, false):
		if button.text == "Napij się wody": button.pressed.emit()
	until("drink")
	for i in 20: tick()
	await shot("drink")
	check(app.room.animator.current == "eat_loop" and app.room.yard_rest.drinking and not app.room.animator.facing_left, "lapping and water ripples animate together")
	check(app.yard_rest_stop.visible and app.yard_rest_stop.get_global_rect().end.x <= 320, "stop fits narrow screen")
	until("")
	app._care_action("rest")
	until("rest")
	for i in 35: tick()
	await shot("nap")
	check(app.session.in_yard and app.session.pet.resting and app.room.animator.current == "sleep", "care rest button naps outdoors")
	check(app.room.pet_world.distance_to(YardRest.BED) < 1, "nap reaches shaded bed")
	app._select_tab("journal")
	check(not app.session.in_yard and app.session.pet.resting, "album keeps nap indoors")
	check(app.room.pet_world.distance_to(app.room.station_point("rest")) < 1, "home bed placement survives tab change")
	app.music.stop()
	app.effects.stop_all()
	app.queue_free()
	app = null
	await process_frame
	await create_timer(0.3).timeout
	print("YARD REST UI RESULTS: %d passed, %d failed" % [passed, failed])
	quit(1 if failed else 0)

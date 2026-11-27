extends SceneTree
var passed := 0
var failed := 0
var app: GameUI
func _initialize() -> void:
	create_timer(45).timeout.connect(func(): quit(1))
	call_deferred("run")
func check(ok: bool, label: String) -> void:
	if ok: passed += 1
	else: failed += 1; push_error(label)
func settle() -> void:
	await process_frame
	await process_frame
func shot(name: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/yufriend-scene-" + name + ".png")
func run() -> void:
	root.size = Vector2i(1100, 720)
	root.content_scale_size = root.size
	app = load("res://scenes/Main.tscn").instantiate()
	app.project_path_override = "res://level-editor/projects/ver2.json"
	app.save_path_override = "/tmp/yufriend-scene-ui-%d/pet.json" % Time.get_ticks_usec()
	app.session.local_clock = func(): return 12.0 * 3600.0
	root.add_child(app)
	await settle()
	app.session.set_process(false)
	for child in app.get_children():
		if child is Window: child.hide()
	app.naming_pending = false
	app.session.pet.resting = false
	app.session.night_sleep = false
	app.session.scheduled_sleep = false
	app.session.automatic_nap = false
	app.session.activity = "idle"
	app.session.pet.needs.energy = 90
	app._refresh()
	check(app.care_buttons.feed.visible and app.tab_buttons.training.visible, "authored care and training controls visible")
	app.room.set_yard(true)
	app.session.in_yard = true
	app.room._sync_layers()
	app._refresh()
	for node in app.room.yard_nodes.values(): check(not node.visible, "legacy yard prop remains hidden after refresh")
	check(not app.room.ambient_life.visible, "ambient procedural creatures stay disabled")
	await settle()
	await shot("yard")
	app.room.set_yard(false)
	app.session.in_yard = false
	app._refresh()
	check(not app.room.wall_clock.visible, "legacy clock does not return on home transition")
	await settle()
	await shot("home")
	var original := RoomLayoutLoader.active_project.duplicate(true)
	var empty := original.duplicate(true)
	for level in empty.levels: level.elements.clear()
	RoomLayoutLoader.active_project = empty
	app._refresh()
	check(not app.care_buttons.feed.visible and not app.care_buttons.play.visible, "missing care controls hidden")
	check(not app.tab_buttons.training.visible and not app.room.ball_throw_enabled, "missing training and canvas throw disabled")
	var before := app.session.pet.to_dict()
	app._on_editor_interaction("not-an-element", "bath", {"script": "bath"})
	app._care_action("feed")
	app._choose_play("tug")
	check(app.session.pet.to_dict() == before and not app.session.in_bath and not app.session.play.running(), "stale UI callbacks cannot start absent mechanics")
	var point := app.room.world_to_screen(RoomLayout.STATIONS.food.position)
	check(app.room.action_at(point) == "", "old bowl rectangle is not an invisible hotspot")
	RoomLayoutLoader.active_project = original
	app.queue_free()
	await settle()
	print("SCENE UI: %d passed, %d failed" % [passed, failed])
	quit(1 if failed else 0)

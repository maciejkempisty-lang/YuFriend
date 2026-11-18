extends SceneTree
var failures := 0
var app: GameUI
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func _initialize() -> void:
	create_timer(60).timeout.connect(func(): quit(1))
	call_deferred("run")
func capture(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/yuf-potty-" + name + ".png")
func run() -> void:
	root.size = Vector2i(320, 680)
	root.content_scale_size = root.size
	app = load("res://scenes/Main.tscn").instantiate()
	app.save_path_override = preload("res://tests/helper_paths.gd").data_root() + "/yuf-potty-ui-%s/pet.json" % Time.get_ticks_usec()
	app.session.local_clock = func(): return 20000 * 86400.0 + 12 * 3600
	root.add_child(app)
	app.session.set_process(false)
	app.session.initiatives_enabled = false
	app.room.ambient_life.life.autoplay = false
	app.session.weather.override_kind = "sun"
	app.session.change_yard(true)
	app._refresh()
	check(app.potty_action.visible and app.potty_action.text == "Na potrzebę", "due outing has a direct action without searching the yard")
	app.potty_action.pressed.emit()
	check(app.session.activity == "outing_walk", "outing action starts walk")
	app.room.pet_world = Vector2(1220, 322)
	app.room.target_world = app.room.pet_world
	app.session.destination_reached()
	app.session.activity_left = 1.0
	app._refresh()
	app.room.focus_pet()
	app.room._update_camera(10)
	await capture("animation")
	check(app.room.yard_potty.progress > 0.5 and app.potty_action.disabled, "animation runs before cleanup becomes available")
	app.session._process(1.1)
	app._refresh()
	await capture("mess")
	check(app.potty_action.visible and not app.potty_action.disabled, "cleanup action available")
	check(app.potty_action.get_global_rect().end.y < app.navigation.position.y, "cleanup fits small phone")
	check(app.room.action_at(app.room.world_to_screen(YardPottyView.SPOT)) == "yard_outing", "pile itself is tappable")
	app.potty_action.pressed.emit()
	app._refresh()
	check(not YardRoutines.has_mess(app.session) and app.room.yard_potty.cleaning > 0, "cleanup removes pile with bag animation")
	await capture("clean")
	app.session.change_yard(false)
	app._refresh()
	check(not app.potty_action.visible, "cleanup hidden at home")
	app.queue_free()
	await process_frame
	print("POTTY UI FAILURES: ", failures)
	quit(1 if failures else 0)

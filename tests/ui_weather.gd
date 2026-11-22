extends SceneTree
var app: GameUI
var failed := 0
var passed := 0
func check(ok: bool, label: String) -> void:
	if ok: passed += 1
	else:
		failed += 1
		push_error(label)
func _initialize() -> void: call_deferred("run")
func shot(name: String) -> void:
	app._refresh()
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/yuf-weather-" + name + ".png")
func run() -> void:
	root.size = Vector2i(320, 680)
	root.content_scale_size = root.size
	app = load("res://scenes/Main.tscn").instantiate()
	app.save_path_override = preload("res://tests/helper_paths.gd").data_root() + "/yuf-weather-ui-%s/pet.json" % Time.get_ticks_usec()
	app.room.ambient_life.life.autoplay = false
	# Set the daytime fixture before startup synchronizes automatic sleep.
	app.session.local_clock = func(): return 100 * 86400.0 + 12 * 3600
	root.add_child(app)
	app.session.set_process(false)
	app.session.pet.pet_name = "Gloria"
	for key in PetState.NEED_KEYS: app.session.pet.needs[key] = 90.0
	app.session.local_clock = func(): return 100 * 86400.0 + 12 * 3600
	app.session._brain_left = INF
	app.session.visitors.wait_left = INF
	await process_frame
	app._toggle_yard(false)
	app.room.show_overview()
	for state in YardWeather.LABELS:
		app.session.weather.override_kind = state
		await shot(state)
		check(app.room.yard_weather.visible and app.room.yard_weather.kind == state, "weather art follows " + state)
		check(app.room.yard_water.wet == (state != "sun"), "puddle art follows " + state)
		check(app.room.yard_markers.values().all(func(m): return m.visible), "all places visible at 320px: " + state)
	app.session.weather.override_kind = "rain"
	app.room.yard_markers.sprinkler.pressed.emit()
	check(not app.session.water.active() and app.session.last_message.contains("Deszcz"), "rain explains unavailable sprinkler from actual marker")
	app.room.focus_pet(false)
	await process_frame
	app.app_foreground = true
	app._update_attention()
	app.session.pet.social.last_offer_at = 0
	check(app.session.offer_initiative("yard_puddle"), "yard invitation starts")
	for i in 500:
		app.room._process(0.1)
		if app.session.invitation.get("arrived", false): break
	check(app.session.invitation.get("arrived", false), "actual walking reaches invitation station")
	await shot("invitation")
	check(app.yard_invite_accept.visible and app.care_status.text.contains("kałuża"), "yard invitation rendered")
	check(app.yard_invite_later.get_global_rect().end.x <= 320, "accept fits 320px")
	check(app.yard_invite_later.visible, "optional later action")
	app.yard_invite_accept.pressed.emit()
	check(app.session.water.kind == "puddle", "real UI accept starts puddle")
	app.session.water.finish(app.session)
	app.session.pet.yard_routines.plant = "daisy"
	check(app.session.weather.water_garden(app.session), "rain waters UI garden")
	app._show_garden()
	await shot("garden")
	check(app._dialog_open(), "garden explanation opens")
	for child in app.get_children():
		if child is AcceptDialog: child.hide()
	await process_frame
	app._toggle_yard(false)
	await shot("home")
	check(not app.room.yard_weather.visible, "weather hidden inside home")
	app.music.stop()
	app.effects.stop_all()
	app.queue_free()
	app = null
	await process_frame
	await create_timer(0.25).timeout
	print("WEATHER UI RESULTS: %d passed, %d failed" % [passed, failed])
	quit(1 if failed else 0)

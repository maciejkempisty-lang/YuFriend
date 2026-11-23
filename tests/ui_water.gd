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
	for i in 400:
		if app.session.water.phase == phase: return
		tick()
	check(false, "water phase timed out: " + phase)
	quit(1)
func shot(name: String) -> void:
	app._refresh()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/yuf-water-" + name + ".png")
func run() -> void:
	root.size = Vector2i(320, 680)
	root.content_scale_size = root.size
	app = load("res://scenes/Main.tscn").instantiate()
	app.save_path_override = "/tmp/yuf-water-ui-%s/pet.json" % Time.get_ticks_usec()
	app.room.ambient_life.life.autoplay = false
	root.add_child(app)
	var s := app.session
	s.set_process(false)
	s._brain_left = INF
	s.visitors.wait_left = INF
	s.pet.pet_name = "Gloria"
	s.pet.needs.energy = 90
	s.pet.needs.hygiene = 100
	s.weather.override_kind = "after_rain"
	s.local_clock = func(): return 100 * 86400.0 + 12 * 3600
	app.room.set_process(false)
	app.room.animator.set_process(false)
	await process_frame
	app._toggle_yard(false)
	app.room.show_overview()
	await shot("overview")
	check(app.room.yard_markers.size() == 12, "twelve yard stations")
	check(app.room.yard_markers.values().all(func(m): return m.visible), "all overview targets visible at 320px")
	for a in app.room.yard_markers.values():
		for b in app.room.yard_markers.values():
			if a == b: continue
			check(not a.get_rect().intersects(b.get_rect()), "overview targets do not overlap")
	app.room.yard_markers.puddle.pressed.emit()
	until("ready")
	check(app.room.pet_world.distance_to(YardWater.SPOTS.puddle - Vector2(24, 0)) < 1, "approach reaches puddle")
	check(app.water_splash_button.visible and app.water_shake_button.visible, "water actions shown")
	await shot("puddle-ready")
	check(app.water_shake_button.get_global_rect().end.x <= 320, "water toolbar fits")
	for i in 3:
		app.water_splash_button.pressed.emit()
		until("splash")
		check(s.water.splashes == i + 1, "actual crossing commits once")
		if i == 0: await shot("puddle-splash")
		until("ready" if i < 2 else "shake")
	for i in 10:
		if app.room.animator.current == "shake": break
		tick()
	await shot("shake")
	check(app.room.animator.current == "shake", "real shaking clip")
	check(float(app.room.animator.sprite.material.get_shader_parameter("dirt")) > 0.2, "mud visible on coat")
	until("")
	check(not app.yard_toolbar.visible and not app.water_splash_button.visible, "temporary water actions clear after play")
	app._select_yard_station("puddle")
	for i in 200:
		if app.yard_action_bubble.visible: break
		tick()
	check(app.yard_action_bubble.visible and app.yard_action_secondary.text == "Kąpiel", "puddle offers a contextual bath")
	app.yard_action_secondary.pressed.emit()
	check(s.in_bath and app.bath_dialog.visible and not app.room.yard_water.visible, "water leads to bathroom without lingering effects")
	s.bath.stage = 3
	check(s.finish_bath() and s.pet.needs.hygiene > 95, "bath washes mud")
	app.bath_dialog.hide()
	app._toggle_yard(false)
	s.water.cooldown = 0
	app.room.yard_markers.sprinkler.pressed.emit()
	until("ready")
	await shot("sprinkler")
	app.water_splash_button.pressed.emit()
	until("splash")
	await shot("sprinkler-splash")
	app.water_shake_button.pressed.emit()
	until("")
	app.room.show_overview()
	app._toggle_yard(false)
	check(not app.room.yard_water.visible, "home hides water graphics")
	# Audio playback is released by the mixer asynchronously. Do not terminate
	# the engine in the same frame that queues the whole scene for deletion.
	var released := tracked_resources()
	app.set_process(false)
	app.music.stop()
	app.effects.stop_all()
	app.queue_free()
	app = null
	await process_frame
	await process_frame
	var deadline := Time.get_ticks_msec() + 2000
	while released.any(func(ref): return ref.get_ref() != null) and Time.get_ticks_msec() < deadline:
		await process_frame
	check(released.all(func(ref): return ref.get_ref() == null), "scene and audio resources released before engine shutdown")
	print("WATER UI RESULTS: %d passed, %d failed" % [passed, failed])
	quit(1 if failed else 0)

func tracked_resources() -> Array[WeakRef]:
	# Keep collection outside run(): its coroutine must not retain the last clip.
	var refs: Array[WeakRef] = [weakref(app), weakref(app.session), weakref(app.room), weakref(app.room.yard_water), weakref(app.music), weakref(app.effects)]
	for variants in app.effects.recordings.values():
		for recording in variants: refs.append(weakref(recording))
	return refs

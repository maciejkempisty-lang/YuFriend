extends SceneTree
# Integration regression: replacement artwork follows existing state without
# changing progress, input routing or discovery rules.
var app: GameUI
var passed := 0
var failed := 0

func _initialize() -> void:
	create_timer(40).timeout.connect(func(): quit(1))
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	if ok: passed += 1
	else:
		failed += 1
		push_error(label)

func shot(label: String) -> void:
	await process_frame
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png("/tmp/yuf-graphics-" + label + ".png")

func run() -> void:
	root.size = Vector2i(390, 844)
	root.content_scale_size = root.size
	app = load("res://scenes/Main.tscn").instantiate()
	app.save_path_override = preload("res://tests/helper_paths.gd").data_root() + "/yuf-sprites-%s/pet.json" % Time.get_ticks_usec()
	app.room.ambient_life.life.autoplay = false
	app.session.local_clock = func(): return 100 * 86400.0 + 12 * 3600
	root.add_child(app)
	app.session.set_process(false)
	app.room.set_process(false)
	app.room.animator.set_process(false)
	await process_frame
	var room := app.room
	check(room.yard_nodes.values().all(func(n): return not n.visible), "yard sprites stay hidden at home")
	await shot("kitchen-390")
	app.session.in_yard = true
	room.set_yard(true)
	app._refresh()
	room._sync_layers()
	var before := app.session.pet.to_dict().duplicate(true)
	check(room.yard_nodes.size() == 12 and room.yard_nodes.values().all(func(n): return n.visible), "all twelve sprites appear outside")
	check(room.yard_nodes.values().all(func(n): return n.sprite.texture.get_image().get_used_rect().has_area()), "all imported sprites contain visible pixels")
	check(not room.yard_water.draw_ground_base and not room.yard_course.draw_sign and not room.yard_rest.draw_static, "old static props do not render a second time")
	room.yard_weather.kind = "sun"
	room._sync_layers()
	check(room.yard_nodes.puddle.sprite.texture == YardStationView.PUDDLE_DRY, "sun shows the dry puddle")
	room.yard_weather.kind = "rain"
	room._sync_layers()
	check(room.yard_nodes.puddle.sprite.texture == YardStationView.SPRITES.puddle, "rain restores the wet puddle")
	room.yard_weather.kind = "sun"
	room.yard_water.kind = "puddle"
	room._sync_layers()
	check(room.yard_nodes.puddle.sprite.texture == YardStationView.SPRITES.puddle, "active puddle play keeps water visible in sun")
	room.yard_water.kind = ""
	app.yard_transition._open(true)
	check(room.yard_nodes.gate.sprite.texture == YardStationView.GATE_OPEN and room.station_nodes.door.portal_open, "existing transition opens both door and gate graphics")
	app.yard_transition._open(false)
	check(room.yard_nodes.gate.sprite.texture == YardStationView.SPRITES.gate, "existing transition closes the gate graphics")
	room._sync_layers()
	check(room.yard_nodes.bush_1.highlight.visible, "untried places retain their visual hint")
	room.mark_yard_place("bush_1")
	check(not room.yard_nodes.bush_1.highlight.visible and not room.yard_sparkles.bush_1.visible, "discovery removes both hint layers")
	room.yard_course.playing = true
	room._sync_layers()
	check(not room.yard_nodes.shade.visible and not room.yard_nodes.puddle.visible and not room.yard_nodes.sprinkler.visible, "course retains the existing visibility of rest and water props")
	check(room.yard_nodes.values().all(func(n): return not n.highlight.visible), "course hides discovery highlights")
	room.yard_course.playing = false
	room._sync_layers()
	check(app.session.pet.to_dict() == before, "rendering and discovery preserve puppy progress")
	for growth in [0.0, YardRoutines.GROW_TIME]:
		app.session.pet.yard_routines.plant = "daisy"
		app.session.pet.yard_routines.growth = growth
		app.session.pet.yard_routines.checked_at = Time.get_unix_time_from_system()
		app._refresh()
		room._sync_layers()
		check(room.yard_nodes.garden.art.garden_state.plant == "daisy" and room.yard_nodes.garden.art.garden_state.growth == growth, "plant overlay follows refreshed growth: " + str(growth))
	app.session.pet.yard_routines.plant = ""
	app._refresh()
	room._sync_layers()
	check(room.yard_nodes.garden.art.garden_state.plant.is_empty(), "harvesting clears the plant overlay")
	await shot("yard-390")
	root.size = Vector2i(320, 640)
	root.content_scale_size = root.size
	await process_frame
	app._fit_room()
	await shot("yard-320")
	room.show_overview()
	room._sync_layers()
	check(room.yard_nodes.values().all(func(n): return not n.highlight.visible), "overview retains map buttons without extra highlights")
	await shot("yard-overview")
	app.session.in_yard = false
	room.set_yard(false)
	check(room.yard_nodes.values().all(func(n): return not n.visible), "returning home hides every yard sprite")
	app.set_process(false)
	app.music.stop()
	app.effects.stop_all()
	app.queue_free()
	await process_frame
	await process_frame
	print("YARD SPRITES UI: %d passed, %d failed" % [passed, failed])
	quit(1 if failed else 0)

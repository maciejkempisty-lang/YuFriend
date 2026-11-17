extends SceneTree
var app: Control
var failed := 0
func _initialize() -> void:
	create_timer(45).timeout.connect(func(): quit(1))
	call_deferred("run")
func check(ok: bool, text: String) -> void:
	if not ok:
		failed += 1
		push_error(text)
	else: print("PASS YARD " + text)
func tick(count: int) -> void:
	for i in count:
		app.room.animator._process(0.1)
		app.room._process(0.1)
		app.session._process(0.1)
func shot(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/yuf-yard-" + name + ".png")
func run() -> void:
	root.size = Vector2i(390, 844)
	root.content_scale_size = root.size
	app = load("res://scenes/Main.tscn").instantiate()
	app.save_path_override = "/tmp/yuf-yard-%s/pet.json" % Time.get_ticks_usec()
	app.room.ambient_life.life.autoplay = false
	root.add_child(app)
	var game: GameSession = app.session
	game.local_clock = func(): return 100 * 86400.0 + 12 * 3600
	game.set_process(false)
	game._brain_left = INF
	app.room.set_process(false)
	app.room.animator.set_process(false)
	game.pet.skills.sit.mastery = 100
	game.pet.skills.paw.mastery = 43
	var identity: String = game.pet.pet_id
	await process_frame
	app._toggle_yard(false)
	check(game.in_yard and app.room.in_yard, "entry changes scene")
	check(not app.room.station_nodes.food.visible and not app.room.wall_clock.visible, "indoor props hidden outside")
	await shot("entry")
	check(app.room.yard_markers.size() == 12, "yard has gate lawn bushes garden and outing stations")
	app.room.yard_markers.bush_2.pressed.emit()
	check(game.sniff_spot == 2, "third bush starts search at that actual location")
	app._toggle_yard(false)
	app._toggle_yard(false)
	check(game.start_sniff(), "sniff begins at available spot")
	tick(15)
	app._toggle_yard(false)
	game.destination_reached()
	tick(40)
	check(not game.pet.milestones.has("yard_find_0"), "leaving before arrival grants no find")
	app._toggle_yard(false)
	for i in 3:
		check(game.start_sniff(), "start search %d" % i)
		for j in 400:
			tick(1)
			if game.activity == "sniff": break
		check(game.activity == "sniff", "arrival starts sniff animation")
		if i == 0: await shot("sniff")
		tick(32)
		check(game.pet.milestones.has("yard_find_%d" % i), "find saved only after sniffing")
	var count := game.pet.milestones.size()
	game.start_sniff()
	tick(400)
	check(game.pet.milestones.size() == count, "repeat sniff does not duplicate collection")
	check(game.throw_ball(Vector2(1100, 310)), "ball throw starts outside")
	tick(15)
	check(app.room.animator.current == "run", "chase uses generated running clip")
	await shot("run")
	tick(400)
	check(game.pet.social.games.ball > 0, "reaching ball completes a round")
	game.flush()
	var loaded := game.storage.load_pet()
	check(loaded.pet.pet_id == identity and loaded.pet.skills.sit.mastery == 100 and loaded.pet.skills.paw.mastery == 43, "reload preserves identity and skill progress")
	check(loaded.pet.milestones.has("yard_find_2"), "reload preserves discoveries")
	app._toggle_yard(false)
	check(not game.in_yard and app.room.station_nodes.food.visible, "return restores room")
	app._toggle_yard(false)
	root.size = Vector2i(320, 640)
	root.content_scale_size = root.size
	await process_frame
	await process_frame
	await shot("narrow")
	check(app.yard_toolbar.get_global_rect().end.x <= 320, "yard controls fit narrow screen")
	# Exercise real drag input, not just the session API.
	game.pet.needs.energy = 90
	game.pet.fatigue = 0
	game.pet.social.last_reward_at = 0
	game.activity = "idle"
	game.activity_left = 0
	app.room.pet_world = Vector2(650, 322)
	app.room.ball_world = Vector2(890, 317)
	app.room.ball_target = app.room.ball_world
	app.room.look_at_world(app.room.ball_world)
	app._refresh()
	await process_frame
	var start: Vector2 = app.room.ball_center()
	app.room._pointer_down(start, 0)
	app.room._pointer_move(start + Vector2(-90, -8), 0)
	app.room._pointer_up(start + Vector2(-90, -8), 0, true)
	check(not game.fetch.active and not app.room.throw_power.visible, "cancelled swipe has no throw or lingering preview")
	app.room._pointer_down(start, 0)
	app.room._pointer_move(start + Vector2(-90, -8), 1)
	check(not app.room.throw_power.visible, "second finger cannot move active throw")
	app.room._pointer_move(start + Vector2(-90, -8), 0)
	check(app.room.throw_power.visible and app.room.throw_guide.visible, "swipe previews power and flight")
	var expected: float = app.room.ball_world.distance_to(app.room._throw_target) / 100
	app.room._pointer_up(start + Vector2(-90, -8), 0)
	check(game.fetch.active and game.pet.yard_record < expected, "swipe starts an unrecorded chase")
	for i in 800:
		tick(1)
		if game.fetch.catching: break
	check(game.fetch.catching and app.room.catch_active, "arrival opens actual touch window")
	await shot("catch")
	var touch: Vector2 = app.room.world_to_screen(app.room.pet_world - Vector2(0, 50))
	app.room._pointer_down(touch, 0)
	app.room._pointer_up(touch, 0)
	check(not game.fetch.active and game.last_message.contains("+1 więzi"), "touching dog in window grants precision bonus")
	check(is_equal_approx(game.pet.yard_record, expected), "record matches actual gesture distance")
	check(is_equal_approx(game.storage.load_pet().pet.yard_record, game.pet.yard_record), "gesture record is persisted")
	tick(20)
	app.room.show_overview()
	await process_frame
	await shot("stations")
	var visible_stations := 0
	var marker_rects: Array[Rect2] = []
	for marker in app.room.yard_markers.values():
		if marker.visible:
			visible_stations += 1
			check(not marker.get_global_rect().intersects(app.yard_toolbar.get_global_rect()), "station is clear of yard toolbar")
			for previous in marker_rects:
				check(not marker.get_rect().intersects(previous), "overview station targets do not overlap")
			marker_rects.append(marker.get_rect())
	check(visible_stations == 12, "overview shows all twelve station targets on narrow screen")
	game.local_clock = func(): return 100 * 86400.0 + 23 * 3600
	game.player_activity()
	tick(310)
	check(not game.in_yard and not app.room.in_yard and app.room.station_nodes.food.visible, "night return restores actual room and props")
	tick(1200)
	check(game.is_sleeping() and app.room.animator.current == "sleep", "yard night return reaches bed and sleep animation")
	app.queue_free()
	await process_frame
	await process_frame
	print("YARD FAILURES: ", failed)
	quit(1 if failed else 0)

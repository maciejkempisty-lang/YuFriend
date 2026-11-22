extends SceneTree
var app: GameUI
var failed := 0
var passed := 0
func _initialize() -> void:
	create_timer(90).timeout.connect(func(): quit(1))
	call_deferred("run")
func check(ok: bool, label: String) -> void:
	if ok: passed += 1
	else:
		failed += 1
		push_error(label)
func tick() -> void:
	app.app_foreground = true
	app._update_attention()
	app.session._process(0.05)
	app.room.animator._process(0.05)
	app.room._process(0.05)
	app._process(0.05)
	app.room.ambient_life.set_process(false)
	app.room.ambient_life._process(0.05)
func run() -> void:
	for width in [390, 320]:
		root.size = Vector2i(width, 844 if width == 390 else 680)
		root.content_scale_size = root.size
		app = load("res://scenes/Main.tscn").instantiate()
		app.save_path_override = preload("res://tests/helper_paths.gd").data_root() + "/yuf-auto-npc-%d-%d/pet.json" % [width, Time.get_ticks_usec()]
		app.session.local_clock = func(): return 100 * 86400.0 + 12 * 3600
		app.session.weather.override_kind = "sun"
		root.add_child(app)
		app.set_process(false)
		app.session.set_process(false)
		app.room.set_process(false)
		app.room.animator.set_process(false)
		app.session.initiatives_enabled = false
		app.session._brain_left = INF
		await process_frame
		app._toggle_yard(false)
		app.room.look_at_world(Vector2(620, 290))
		var before_bond := app.session.pet.bond
		var seen := {}
		var guests := {}
		var walked := false
		for frame in 6400:
			tick()
			for kind in app.room.ambient_life.life.actors: seen[kind] = true
			if app.session.visitors.active(): guests[app.session.visitors.kind] = true
			if not walked and seen.has("butterfly") and seen.has("snail"):
				walked = true
				app.session.move_to(Vector2(700, 312), false)
				app._update_attention()
				check(not app.room.ambient_life.life.actors.snail.leaving and not app.room.ambient_life.life.actors.butterfly.leaving, "ordinary walk keeps snail and butterfly visible at %d" % width)
				await process_frame
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png("/tmp/yuf-npc-auto-garden-%d.png" % width)
			if app.session.visitors.kind == "cat":
				app.room._update_camera(10)
				app._refresh()
				await process_frame
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png("/tmp/yuf-npc-auto-cat-%d.png" % width)
				break
		check(walked and seen.has("snail") and seen.has("butterfly"), "both garden animals appear automatically at %d" % width)
		check(guests.has("bird") and guests.has("butterfly") and guests.has("cat"), "one real yard visit automatically reaches all three guests at %d" % width)
		check(app.room.fence_visitor.visible and app.room.fence_visitor.kind == "cat", "automatic cat renders at %d" % width)
		check(app.session.pet.bond == before_bond, "waiting for animals grants no artificial bond")
		app.queue_free()
		await process_frame
	print("AUTOMATIC NPC UI RESULTS: %d passed, %d failed" % [passed, failed])
	quit(1 if failed else 0)

extends SceneTree
var app: GameUI
var passed := 0
var failed := 0
func _initialize() -> void:
	create_timer(90).timeout.connect(func(): quit(1))
	call_deferred("run")
func check(ok: bool, label: String) -> void:
	if ok: passed += 1
	else:
		failed += 1
		push_error(label)
func sync() -> void:
	app.app_foreground = true
	app._refresh()
	app.room.ambient_life.set_process(false)
func step(seconds: float) -> void:
	for i in ceili(seconds / 0.05):
		sync()
		app.room.ambient_life._process(0.05)
func check_squirrel_visibility() -> void:
	var sprite: Sprite2D = app.room.ambient_life.sprites.squirrel
	var top_left := app.room.world_to_screen(sprite.position + sprite.offset * sprite.scale)
	var bottom_right := app.room.world_to_screen(sprite.position + (sprite.offset + Vector2(16, 16)) * sprite.scale)
	var bounds := Rect2(top_left, bottom_right - top_left)
	check(app.room.render_rect.encloses(bounds), "whole squirrel fits the rendered scene")
	for marker in app.room.yard_markers.values():
		if marker.visible: check(not marker.get_rect().intersects(bounds), "yard controls do not cover the resting squirrel")

func shot(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/yuf-ambient-" + name + ".png")
func run() -> void:
	root.size = Vector2i(390, 844)
	root.content_scale_size = root.size
	app = load("res://scenes/Main.tscn").instantiate()
	app.save_path_override = "/tmp/yuf-ambient-ui-%s/pet.json" % Time.get_ticks_usec()
	app.room.ambient_life.life.autoplay = false
	app.session.weather.override_kind = "sun"
	app.session.local_clock = func(): return 100 * 86400.0 + 12 * 3600
	root.add_child(app)
	app.set_process(false)
	var s := app.session
	s.set_process(false)
	s._brain_left = INF
	s.visitors.wait_left = INF
	app.room.set_process(false)
	app.room.animator.set_process(false)
	await process_frame
	app.room.look_at_world(Vector2(740, 250))
	sync()
	var view := app.room.ambient_life
	var before := s.pet.to_dict()
	var save_hash := FileAccess.get_sha256(s.storage.path)
	check(view.life.start("window_bird"), "window bird starts in the visible room")
	step(2)
	check(view.sprites.window_bird.visible and not view.sprites.sparrow.visible, "only window bird is rendered indoors")
	check(view.pane.clip_contents and view.pane.mouse_filter == Control.MOUSE_FILTER_IGNORE, "outside bird clipped to glass without stealing input")
	check(view.pane.get_rect().encloses(Rect2(view.life.actors.window_bird.position - Vector2(18, 27), Vector2(36, 27))), "perched bird fits the glass below the crossbar")
	check(s.pet.to_dict() == before, "window event changes no progress")
	check(FileAccess.get_sha256(s.storage.path) == save_hash, "window event performs no save")
	await shot("window-390")
	app._select_tab("journal")
	check(view.life.actors.is_empty() and not view.is_processing() and not view.visible, "Album stops and removes ambient animation")
	app._select_tab("care")
	sync()
	app.today_button.pressed.emit()
	check(view.life.actors.is_empty() and not view.is_processing(), "Today panel pauses ambient scheduling")
	for child in app.get_children():
		if child is AcceptDialog and child.title == "Dziś": child.hide()
	await process_frame
	app._toggle_yard(false)
	s.pet.yard_routines.plant = "daisy"
	s.pet.yard_routines.growth = YardRoutines.GROW_TIME
	app.room.look_at_world(Vector2(660, 310))
	sync()
	before = s.pet.to_dict()
	save_hash = FileAccess.get_sha256(s.storage.path)
	check(view.life.start("butterfly") and view.life.start("sparrow"), "butterfly and sparrow coexist on the visible yard")
	step(4)
	check(view.sprites.butterfly.visible and view.sprites.sparrow.visible, "both yard sprites rendered")
	check(not s.busy() and s.play_readiness().is_empty() and app.room.ball_throw_enabled, "background never locks session or throw gesture")
	await shot("yard-flight-390")
	step(4.1)
	check(view.life.actors.butterfly.position.is_equal_approx(Vector2(553, 255)), "butterfly sits on the rendered flower")
	await shot("garden-perch-390")
	check(s.pet.to_dict() == before and FileAccess.get_sha256(s.storage.path) == save_hash, "yard atmosphere changes no needs, counters, memories or save")
	check(s.throw_ball(Vector2(1100, 315), Vector2(890, 317)), "first throw works during background events")
	sync()
	check(view.life.actors.values().all(func(a): return a.leaving), "throw immediately sends scenery animals away")
	step(0.85)
	check(view.life.actors.is_empty() and s.play.running(), "animals leave while fetch continues")
	s.cancel_touch_game()
	sync()
	check(view.life.start("butterfly"), "ambient can resume after play")
	check(s.start_hide("treat", 42), "first hide choice works during ambient flight")
	sync()
	step(0.85)
	check(view.life.actors.is_empty() and s.hide_game.active(), "hiding proceeds without ambient interruption")
	s.cancel_hide()
	app.room.look_at_world(Vector2(620, 290))
	sync()
	before = s.pet.to_dict()
	save_hash = FileAccess.get_sha256(s.storage.path)
	check(view.life.start("snail") and view.life.start("squirrel"), "snail and squirrel appear in the yard")
	step(4)
	check(view.sprites.snail.visible and view.sprites.squirrel.visible, "both new pixel sprites render")
	check(view.sprites.snail.texture == view.snail_frames[view.life.actors.snail.frame] and view.sprites.squirrel.texture == view.squirrel_frames[2], "each species uses its own texture frames")
	check(not s.busy() and app.room.ball_throw_enabled, "ground animals do not lock the throw gesture")
	check_squirrel_visibility()
	await shot("snail-squirrel-390")
	check(s.pet.to_dict() == before and FileAccess.get_sha256(s.storage.path) == save_hash, "ground animals never change progress or write saves")
	check(DiggingSystem.start(s), "digging starts immediately with both ground animals present")
	sync()
	step(0.85)
	check(view.life.actors.is_empty() and s.activity == "dig_walk", "ground animals leave without interrupting digging")
	s._cancel_motion()
	s.activity = "idle"
	app.room.look_at_world(Vector2(550, 310))
	sync()
	view.life.start("butterfly")
	check(s.visitors.start(s, "cat"), "real visitor can still arrive")
	sync()
	check(view.life.actors.is_empty() and not view.visible, "real visitor temporarily has the scene to itself")
	s.visitors.finish(s, "")
	s.local_clock = func(): return 100 * 86400.0 + 23 * 3600
	sync()
	check(view.life.actors.is_empty() and not view.is_processing(), "night has no daytime animals")
	s.local_clock = func(): return 100 * 86400.0 + 12 * 3600
	root.size = Vector2i(320, 680)
	root.content_scale_size = root.size
	await process_frame
	app.room.look_at_world(Vector2(550, 310))
	sync()
	check(view.life.start("butterfly"), "flower event remains visible at 320px")
	step(8.1)
	await shot("garden-perch-320")
	view.life.actors.clear()
	app.room.look_at_world(Vector2(620, 290))
	sync()
	check(view.life.start("snail") and view.life.start("squirrel"), "new species fit the narrow yard view")
	step(4)
	check_squirrel_visibility()
	await shot("snail-squirrel-320")
	app._toggle_yard(false)
	app.room.look_at_world(Vector2(740, 250))
	sync()
	check(view.life.start("window_bird"), "window bird remains visible at 320px")
	step(2)
	await shot("window-320")
	app.app_foreground = false
	app._update_attention()
	check(not view.is_processing() and view.life.actors.is_empty(), "backgrounding stops animation work")
	app.music.stop()
	app.effects.stop_all()
	app.queue_free()
	await process_frame
	await process_frame
	print("AMBIENT UI RESULTS: %d passed, %d failed" % [passed, failed])
	quit(1 if failed else 0)

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
func run() -> void:
	root.size = Vector2i(320, 680)
	root.content_scale_size = root.size
	app = load("res://scenes/Main.tscn").instantiate()
	app.save_path_override = preload("res://tests/helper_paths.gd").data_root() + "/yuf-memory-ui-%s/pet.json" % Time.get_ticks_usec()
	app.room.ambient_life.life.autoplay = false
	root.add_child(app)
	app.session.set_process(false)
	app.session.pet.pet_name = "Gloria"
	app.session.local_clock = func(): return 100 * 86400.0 + 12 * 3600
	app.session.change_yard(true)
	app.session.visitors.start(app.session, "cat")
	app.session.visitors.respond(app.session, "soothe")
	app.session.visitors.advance(app.session, 2.6)
	app._select_tab("journal")
	await process_frame
	await process_frame
	check(app.visitor_album_status.text.contains("Pierwsze spokojne spotkanie"), "album shows saved familiarity")
	check(app.visitor_album_status.text.contains("Jeszcze się nie poznali"), "unknown guests stay unknown")
	check(app.visitor_album_status.get_global_rect().end.x <= 320, "status fits narrow screen")
	check(app.journal_count >= 2, "first encounter and calm day in album")
	var texture := load("res://assets/art/visitors/fence-friends-v1.png") as Texture2D
	check(texture != null and texture.get_width() > 0, "generated illustration loads")
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/yuf-memory-album.png")
	app._select_tab("care")
	app.session.change_yard(true)
	app.session.visitors.start(app.session, "cat")
	check(app.care_status.text.contains("Znowu razem"), "recognition visible on return")
	app.session.visitors.finish(app.session, "")
	print("VISITOR MEMORY UI RESULTS: %d passed, %d failed" % [passed, failed])
	app.queue_free()
	await process_frame
	quit(1 if failed else 0)

extends SceneTree

var failed := 0

func check(ok: bool, label: String) -> void:
	if not ok:
		failed += 1
		push_error(label)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	root.size = Vector2i(390, 844)
	var app: GameUI = load("res://scenes/Main.tscn").instantiate()
	var save_path := "user://qa-golden-fetch-%d.json" % Time.get_ticks_usec()
	app.save_path_override = save_path
	app.project_path_override = "res://level-editor/projects/ver1.json"
	app.session.local_clock = func(): return 100 * 86400.0 + 12 * 3600.0
	root.add_child(app)
	await process_frame
	await process_frame
	app.set_process(false)
	app.session.set_process(false)
	app.room.set_process(false)
	app.room.animator.set_process(false)
	app.session.change_yard(true)
	app.room.set_yard(true)
	var pack: PetAnimationSet = load("res://data/animations/puppy_pixel.res")
	for clip in ["walk", "run", "ball_play", "aport"]:
		check(pack.frames.has_animation(clip) and pack.frames.get_frame_count(clip) == 16, "new 16-frame clip: " + clip)
	var clips: Array[String] = []
	app.room.animator.clip_started.connect(func(clip: String): clips.append(clip))
	var origin := app.room.ball_world
	var target := RoomLayout.clamp_walk(origin + Vector2(230, 0))
	check(app.session.throw_ball(target, origin), "throw starts")
	var saw_play := false
	var saw_return := false
	for frame in 400:
		app.room.animator._process(0.05)
		app.room._process(0.05)
		app.session._process(0.05)
		if app.room._fetch_ball_hidden and app.room.animator.current == "ball_play": saw_play = true
		if app.room._fetch_ball_hidden and app.room.animator.current == "aport": saw_return = true
		if app.session.pet.social.games.ball == 1: break
	check(saw_play and saw_return, "play and return animate with one hidden external ball")
	check(clips.find("run") >= 0 and clips.find("ball_play") > clips.find("run") and clips.find("aport") > clips.find("ball_play"), "clips run in throw order")
	check(app.session.pet.social.games.ball == 1 and not app.session.fetch.active, "round settles after return")
	check(app.room.pet_world.distance_to(origin) < 1.0 and not app.room._fetch_ball_hidden and app.room.ball_world.distance_to(origin) <= 140.0, "dog returns to throw point and ball reappears nearby")
	app.queue_free()
	await process_frame
	if FileAccess.file_exists(save_path): DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
	print("GOLDEN FETCH: %d failed" % failed)
	quit(1 if failed else 0)

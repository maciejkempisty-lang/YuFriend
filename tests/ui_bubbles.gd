extends SceneTree

var passed := 0
var failed := 0
var app: Control
var directory: String

func _initialize() -> void:
	create_timer(60).timeout.connect(func(): quit(1))
	call_deferred("_run")

func _run() -> void:
	directory = (OS.get_environment("YUFRIEND_TEST_ROOT") if not OS.get_environment("YUFRIEND_TEST_ROOT").is_empty() else "user://").path_join("qa-bubbles-%s" % Time.get_ticks_usec())
	app = load("res://scenes/Main.tscn").instantiate()
	app.save_path_override = directory.path_join("pet.json")
	app.session.local_clock = func(): return 12.0 * 3600
	root.add_child(app)
	app.session.set_process(false)
	app.session.initiatives_enabled = false
	app.set_process(false)
	app.room.set_process(false)
	app.room.animator.set_process(false)
	app.session.pet.pet_name = "Gloria"
	for key in PetState.NEED_KEYS: app.session.pet.needs[key] = 80.0
	app.session.pet.life.mood = "calm"
	var shown := {"thought": 0, "feedback": 0, "gain": 0}
	for layout in [Vector2i(390, 844), Vector2i(320, 640), Vector2i(1080, 2340), Vector2i(860, 1864), Vector2i(1100, 720)]:
		root.size = layout
		root.content_scale_size = Vector2i(390, 844) if layout.x in [1080, 860] else layout
		await process_frame
		await process_frame
		app.safe_area_override = Rect2()
		if layout.x in [1080, 860]:
			app.safe_area_override = root.get_final_transform() * Rect2(12, 54, app.size.x - 24, app.size.y - 88)
		app._fit_room()
		for closeup in [false, true]:
			app.room.focus_left = 10 if closeup else 0
			app.room.focus_pet()
			for x in [RoomLayout.START.x, 180.0, 1260.0]:
				app.room.pet_world = Vector2(x, RoomLayout.START.y)
				app.room.target_world = app.room.pet_world
				app.room._update_camera(10)
				app.room._sync_layers()
				for clip in ["idle", "sit_idle", "play_bow", "sleep"]:
					app.room.animator._start(clip)
					app.room.animator.sprite.pause()
					app.room.animator.facing_left = x > 1000
					app.room.animator._apply_transform()
					app.app_foreground = true
					app._update_attention()
					app._refresh_companion()
					app._show_feedback("Lubię być blisko! Za uszkiem jest najprzyjemniej.")
					app._show_gain("pet", {"contact": 18})
					for frame in 4:
						await process_frame
						app.app_foreground = true
						app._process(0)
					var dog := puppy_bounds()
					check(app.room.pet_screen_bounds().is_equal_approx(dog), "visible bounds: %s / %s / %s" % [layout, clip, closeup])
					if not closeup and x == RoomLayout.START.x:
						check(app.bubble.modulate.a > 0, "immediate feedback remains visible on %s / %s" % [layout, clip])
					var visible_rects: Array[Rect2] = []
					for pair in [["thought", app.companion_card], ["feedback", app.bubble], ["gain", app.gain_label]]:
						var control: Control = pair[1]
						if not control.visible or control.modulate.a == 0: continue
						shown[pair[0]] += 1
						var rect := control.get_global_rect()
						check(not rect.intersects(dog.grow(8)), "%s clears dog: %s / %s / zoom %s" % [pair[0], layout, clip, closeup])
						check(app.safe_rect.encloses(rect) and rect.end.y <= app.room.content_bottom - 8, "%s stays inside usable screen" % pair[0])
						for other in visible_rects: check(not rect.intersects(other), "messages do not overlap each other")
						visible_rects.append(rect)
					if layout.x in [390, 320, 1080] and x == RoomLayout.START.x and clip == "sit_idle":
						await RenderingServer.frame_post_draw
						root.get_texture().get_image().save_png("res://test-results/bubbles-%d-%s.png" % [layout.x, "close" if closeup else "normal"])
	for key in shown: check(shown[key] >= 20, "%s remains readable in ordinary layouts (%d cases)" % [key, shown[key]])
	app.session.active = false
	app.queue_free()
	await process_frame
	for file in DirAccess.get_files_at(directory): DirAccess.remove_absolute(directory.path_join(file))
	DirAccess.remove_absolute(directory)
	print("BUBBLE UI RESULTS: %d passed, %d failed" % [passed, failed])
	quit(1 if failed else 0)

func puppy_bounds() -> Rect2:
	var sprite: AnimatedSprite2D = app.room.animator.sprite
	var texture := sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
	var used := Rect2(texture.get_image().get_used_rect())
	if sprite.flip_h: used.position.x = texture.get_width() - used.end.x
	var start: Vector2 = app.room.world_to_screen(sprite.to_global(used.position) * RoomLayout.PIXEL_SIZE)
	var end: Vector2 = app.room.world_to_screen(sprite.to_global(used.end) * RoomLayout.PIXEL_SIZE)
	return Rect2(start, end - start)

func check(condition: bool, message: String) -> void:
	if condition: passed += 1
	else:
		failed += 1
		push_error("FAIL " + message)

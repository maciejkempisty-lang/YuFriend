extends SceneTree

var passed := 0
var failed := 0
var app: Control
var directory: String

func _initialize() -> void:
	create_timer(60).timeout.connect(func():
		printerr("COMPANION UI timeout")
		quit(1))
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(390, 844)
	root.content_scale_size = root.size
	var test_root := OS.get_environment("YUFRIEND_TEST_ROOT")
	directory = ("user://" if test_root.is_empty() else test_root).path_join("qa-companion-%s" % Time.get_ticks_usec())
	app = load("res://scenes/Main.tscn").instantiate()
	app.save_path_override = directory.path_join("pet.json")
	app.room.ambient_life.life.autoplay = false
	app.session.local_clock = func(): return 100 * 86400.0 + 12 * 3600.0
	root.add_child(app)
	var game: GameSession = app.session
	game.set_process(false)
	game.initiatives_enabled = false
	game._brain_left = INF
	game.wake_report_left = 0 # This suite exercises the regular voice after the wake report.
	app.set_process(false)
	app.room.set_process(false)
	app.room.animator.set_process(false)
	game.pet.pet_name = "Gloria"
	for key in PetState.NEED_KEYS: game.pet.needs[key] = 80.0
	game.pet.life.mood = "calm"
	app.bubble_left = 0
	await settle()
	check(app.companion_card.visible and app.companion_data.kind == "thought", "quiet home shows a thought in the top bubble")
	for layout in [Vector2i(390, 844), Vector2i(320, 640), Vector2i(860, 1864), Vector2i(1100, 720)]:
		root.size = layout
		root.content_scale_size = Vector2i(390, 844) if layout.x == 860 else layout
		await process_frame
		await process_frame
		app.safe_area_override = Rect2()
		if layout.x == 860:
			app.safe_area_override = root.get_final_transform() * Rect2(12, 54, app.size.x - 24, app.size.y - 88)
		app._fit_room()
		app.room.focus_left = 0
		app.room.focus_pet()
		app.room._update_camera(10)
		app.room._sync_layers()
		await settle()
		var camera: Vector2 = app.room.camera_center()
		var scale: Vector2 = app.room.screen_scale()
		var pet_point: Vector2 = app.room.pet_position()
		await capture("companion-thought-%d.png" % layout.x)
		if layout.x == 320:
			game.say("Znów w domu.")
			app.bubble_left = 3
			await settle()
			check(app.bubble.visible and app.companion_card.modulate.a == 0, "narrow screen: a reply bubble replaces a passing thought")
			app.bubble_left = 0
			await settle()
			check(app.companion_card.visible and app.companion_card.modulate.a > 0, "narrow screen: the thought returns after the reply")
		game.pet.needs.fullness = 20
		await settle()
		await capture("companion-need-%d.png" % layout.x)
		check(app.companion_data.action == "feed" and app.companion_action.text == "Nakarm", "hungry bubble routes to feeding at " + str(layout))
		check(app.room.camera_center() == camera and app.room.screen_scale() == scale and app.room.pet_position() == pet_point, "bubble does not change camera, scale or dog position at " + str(layout))
		var rect: Rect2 = app.companion_card.get_global_rect()
		check(app.safe_rect.encloses(rect) and rect.position.y >= app.room.overview_button.get_rect().end.y + 4, "bubble fits below the toolbar inside safe bounds at " + str(layout))
		var ball: Rect2 = app.room._screen_rect(Rect2(app.room.ball_world - Vector2(14, 14), Vector2(28, 32)))
		check(not rect.intersects(puppy_bounds()) and not rect.intersects(app.room.bowl_rect()) and not rect.intersects(ball), "bubble leaves the dog, bowl and ball unobscured at " + str(layout))
		check(rect.encloses(app.companion_action.get_global_rect()) and app.companion_action.size.y >= 44 and app.companion_label.get_line_count() <= 3, "action is tappable and text stays short at " + str(layout))
		game.pet.needs.fullness = 80
	root.size = Vector2i(390, 844)
	root.content_scale_size = root.size
	app.safe_area_override = Rect2()
	await process_frame
	app._fit_room()
	game.pet.needs.fullness = 20
	await settle()
	await tap(app.companion_action)
	check(game._pending_action == "feed" and game.pet.needs.fullness == 20, "touching Nakarm starts the real approach without an early reward")
	await settle()
	check(app.companion_data.kind == "activity" and not app.companion_action.visible, "care in progress replaces the action with a status")
	game._cancel_motion()
	game.activity = "idle"
	game.pet.needs.fullness = 80
	game.pet.remember("first_sit", "Pierwsze siad", "Zapisane ćwiczenie")
	await settle()
	await capture("companion-memory-390.png")
	check(app.companion_data.kind == "memory" and app.companion_action.text == "Zobacz album", "real journal event appears as a memory")
	await tap(app.companion_action)
	check(app.selected_tab == "journal" and not app.companion_card.visible, "memory button opens the album")
	app._select_tab("care")
	game.pet.needs.play = 20
	await settle()
	await tap(app.companion_action)
	check(app.play_menu.visible and not app.companion_card.visible, "play need opens the game chooser and yields to the dialog")
	app.play_menu.hide()
	await settle() # Refresh attention after closing the modal.
	game.pet.needs.play = 80
	game.initiatives_enabled = true
	game.offer_initiative("ball")
	game.pet.needs.fullness = 20
	await settle()
	var remaining: float = game.invitation.remaining
	game._process(1)
	check(game.invitation.remaining == remaining and not app.companion_later.visible, "urgent need hides the invitation and pauses its response clock")
	game.pet.needs.fullness = 80
	await settle()
	await capture("companion-invitation-390.png")
	check(app.companion_data.kind == "invitation" and app.companion_later.visible, "invitation returns when the need is satisfied")
	await tap(app.companion_later)
	check(game.invitation.is_empty() and game.pet.social.responses.ball.declined == 1, "Później records exactly one declined invitation")
	app._show_profile()
	await settle()
	check(not app.companion_card.visible, "profile hides the top bubble")
	app.profile_dialog.hide()
	app.room.show_overview()
	await settle()
	check(not app.companion_card.visible, "room overview has no top bubble")
	app.room.focus_pet()
	app._select_tab("training")
	await settle()
	check(not app.companion_card.visible, "training has no top bubble")
	app._select_tab("care")
	game.pet.pet_name = "Fado"
	await settle()
	check(app.companion_title.text.begins_with("Fado"), "renaming updates the voice header")
	app.app_foreground = false
	app._process(0)
	check(not app.companion_card.visible, "backgrounding hides the bubble")
	game.active = false
	app.queue_free()
	await process_frame
	for file in DirAccess.get_files_at(directory): DirAccess.remove_absolute(directory.path_join(file))
	DirAccess.remove_absolute(directory)
	print("COMPANION UI RESULTS: %d passed, %d failed" % [passed, failed])
	quit(1 if failed else 0)

func settle() -> void:
	app.app_foreground = true
	app._refresh()
	for index in 4:
		await process_frame
		app.app_foreground = true
		app._process(0)

func tap(button: Button) -> void:
	var event := InputEventScreenTouch.new()
	event.position = button.get_global_rect().get_center()
	event.pressed = true
	root.push_input(event, true)
	event = event.duplicate()
	event.pressed = false
	root.push_input(event, true)
	await process_frame

func puppy_bounds() -> Rect2:
	var sprite: AnimatedSprite2D = app.room.animator.sprite
	var texture: Texture2D = sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
	var used := Rect2(texture.get_image().get_used_rect())
	if sprite.flip_h: used.position.x = texture.get_width() - used.end.x
	var start: Vector2 = app.room.world_to_screen(sprite.to_global(used.position) * RoomLayout.PIXEL_SIZE)
	var end: Vector2 = app.room.world_to_screen(sprite.to_global(used.end) * RoomLayout.PIXEL_SIZE)
	return Rect2(start, end - start)

func capture(name: String) -> void:
	await settle()
	await RenderingServer.frame_post_draw
	var output := ProjectSettings.globalize_path("res://test-results")
	DirAccess.make_dir_recursive_absolute(output)
	root.get_texture().get_image().save_png(output.path_join(name))

func check(condition: bool, label: String) -> void:
	if condition:
		passed += 1
		print("PASS " + label)
	else:
		failed += 1
		push_error("FAIL " + label)

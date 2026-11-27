extends SceneTree

var passed := 0
var failed := 0

func _initialize() -> void:
	create_timer(30).timeout.connect(func(): quit(1))
	call_deferred("_run")

func _check(ok: bool, label: String) -> void:
	if ok: passed += 1
	else:
		failed += 1
		push_error(label)

func _run() -> void:
	root.size = Vector2i(390, 844)
	root.content_scale_size = root.size
	var directory := "user://qa-editor-main-%d" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	var project_path := directory.path_join("project.json")
	var project: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://level-editor/projects/ver1.json"))
	var food := {"id": "editor_food", "name": "Miska", "asset": "food", "layer": "middle",
		"x": 690, "y": 505, "width": 60, "height": 36, "pivot": {"x": 10, "y": 10},
		"visible": true, "locked": false, "static": true, "script": "feed",
		"params": {"fullness": 22, "message": "Mniam!", "clip": "eat_loop"}}
	var note := {"id": "editor_note", "name": "Wiadomość", "asset": "toys", "layer": "middle",
		"x": 900, "y": 505, "width": 102, "height": 78, "pivot": {"x": 17, "y": 25},
		"visible": true, "locked": false, "static": true, "script": "message",
		"params": {"text": "Wiadomość z edytora", "duration": 5}}
	project.levels[0].elements.append(food)
	project.levels[0].elements.append(note)
	var file := FileAccess.open(project_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(project))
	file.close()
	var app: GameUI = load("res://scenes/Main.tscn").instantiate()
	app.project_path_override = project_path
	app.save_path_override = directory.path_join("pet.json")
	app.session.local_clock = func(): return 100 * 86400.0 + 12 * 3600.0
	root.add_child(app)
	await process_frame
	await process_frame
	app.session.set_process(false)
	app.room.set_process(false)
	_check(RoomLayout.STATIONS.food.position.x == 690, "editor feed script maps a generated ID to the food station")
	var assets := {}
	for asset in project.assets: assets[asset.id] = asset
	var food_point: Vector2 = app.room.world_to_screen(LevelProject.element_rect(food, assets[food.asset]).get_center())
	_check(app.room.editor_element_at(food_point).get("id", "") == "editor_food", "tap resolves the scripted editor sprite")
	app.session.pet.needs.fullness = 20
	app.room._interact(food_point)
	_check(app.session._pending_action == "feed", "tap dispatches feed to the real game session")
	var note_point: Vector2 = app.room.world_to_screen(LevelProject.element_rect(note, assets[note.asset]).get_center())
	app.room.look_at_world(Vector2(float(note.x), float(note.y)))
	note_point = app.room.world_to_screen(LevelProject.element_rect(note, assets[note.asset]).get_center())
	_check(app.room.editor_element_at(note_point).get("id", "") == "editor_note", "camera can tap the authored message")
	app.room._interact(note_point)
	_check(app.message_label.text == "Wiadomość z edytora" and app.bubble_left == 5, "message parameters reach the game UI")
	app._on_editor_interaction("editor_note", "thought", {"x": note.x, "y": note.y, "params": {"text": "Myśl z edytora", "duration": 2, "from_dog": false}})
	_check(app.message_label.text == "Myśl z edytora" and app.editor_feedback_world_target.is_finite(), "thought can point to its editor element")
	var ball_entry: Dictionary = app.room.editor_ball_sprites.get("home", {})
	_check(not ball_entry.is_empty(), "authored ball has a movable game sprite")
	if not ball_entry.is_empty():
		var ball_sprite: Node2D = ball_entry.node
		var before_x := ball_sprite.position.x
		app.room.ball_world.x += 30
		app.room._sync_layers()
		_check(absf(ball_sprite.position.x - before_x - 30) < 0.1, "editor ball follows game ball motion")
	app.queue_free()
	await process_frame
	for name in DirAccess.get_files_at(directory): DirAccess.remove_absolute(ProjectSettings.globalize_path(directory.path_join(name)))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(directory))
	print("EDITOR MAIN SCRIPTS: %d passed, %d failed" % [passed, failed])
	quit(1 if failed else 0)

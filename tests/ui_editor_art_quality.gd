extends SceneTree

var failed := 0

func _initialize() -> void:
	call_deferred("_run")

func _check(ok: bool, label: String) -> void:
	if not ok:
		failed += 1
		push_error(label)

func _run() -> void:
	var result := RoomLayoutLoader.new().apply("res://level-editor/projects/ver1.json")
	_check(result.ok, "current editor project loads")
	_check(RoomLayoutLoader.active_hd_art, "game uses HD rendering for authored HD artwork")
	var project: Dictionary = RoomLayoutLoader.active_project
	var assets := {}
	for asset in project.assets: assets[asset.id] = asset
	var app: GameUI = load("res://scenes/Main.tscn").instantiate()
	app.project_path_override = "res://level-editor/projects/ver1.json"
	var save_path := "user://qa-art-quality-%d.json" % Time.get_ticks_usec()
	app.save_path_override = save_path
	root.add_child(app)
	await process_frame
	await process_frame
	app.session.set_process(false)
	app.room.set_process(false)
	_check(app.room.puppy.z_index > 0 and not app.room.puppy.z_as_relative, "dog stays above middle artwork")
	_check(is_equal_approx(app.room._render_pixel_size, 1.0), "HD artwork uses a full-resolution viewport")
	for level in project.levels:
		for element in level.elements:
			if not RoomLayoutLoader.active_hd_asset_ids.has(element.asset): continue
			var texture: Texture2D = RoomLayoutLoader.active_textures[element.asset]
			_check(texture.get_width() == assets[element.asset].width, "authored HD texture selected for " + element.asset)
			var parent: Node2D = app.room.world.background if element.layer == "background" else (app.room.world.foreground if element.layer == "foreground" else app.room.actors)
			var anchor: Node2D = parent.get_node_or_null(str(element.id))
			_check(anchor != null, "authored anchor exists for " + str(element.id))
			if anchor == null: continue
			var sprite: Sprite2D = anchor.get_child(0)
			var actual := Rect2(anchor.position + sprite.position, sprite.texture.get_size() * sprite.scale)
			var expected := LevelProject.element_rect(element, assets[element.asset])
			_check(actual.position.distance_to(expected.position) < 0.1 and actual.size.distance_to(expected.size) < 0.1, "HD art keeps authored bounds for " + str(element.id))
	app.queue_free()
	await process_frame
	if FileAccess.file_exists(save_path): DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
	print("EDITOR ART QUALITY: %d failed" % failed)
	quit(1 if failed else 0)

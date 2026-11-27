extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var path := "res://level-editor/projects/starter.json"
	var level_id := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--project="): path = arg.trim_prefix("--project=")
		if arg.begins_with("--level="): level_id = arg.trim_prefix("--level=")
	var result := LevelProject.read_project(path)
	if not result.ok:
		printerr("Projekt poziomów: ", result.errors)
		quit(1); return
	if not level_id.is_empty() and not result.project.levels.any(func(l): return l.id == level_id):
		printerr("Nie znaleziono poziomu: ", level_id)
		quit(1); return
	root.title = "YuFriend · Podgląd poziomów"
	root.size = Vector2i(1200, 720)
	root.content_scale_size = Vector2i(1200, 720)
	var preview := LevelPreview.new()
	if not preview.open_project(result.project, level_id):
		printerr("Nie można wczytać grafik projektu.")
		preview.free(); quit(1); return
	root.add_child(preview)

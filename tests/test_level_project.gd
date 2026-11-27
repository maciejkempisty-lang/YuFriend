extends SceneTree
var passed := 0
var failed := 0
func check(ok: bool, label: String) -> void:
	if ok: passed += 1
	else: failed += 1; push_error(label)
func _initialize() -> void:
	var result := LevelProject.read_project("res://level-editor/projects/ver1.json")
	check(result.ok, "ver1 is accepted by game loader")
	if not result.ok: print(result.errors); quit(1); return
	var project: Dictionary = result.project
	for a in project.assets: check(LevelProject.texture(a) != null, "native PNG resolves: " + a.id)
	var embedded: Dictionary = project.assets[0].duplicate()
	embedded.source = "data:image/png;base64," + Marshalls.raw_to_base64(FileAccess.get_file_as_bytes(embedded.source))
	check(LevelProject.texture(embedded) != null, "embedded custom PNG decodes")
	embedded.width += 1
	check(LevelProject.texture(embedded) == null, "PNG dimension mismatch rejected")
	# Script registry loads from scripts.json.
	var scripts := LevelProject.scripts()
	for id in ["none", "message", "thought", "portal", "feed", "pet", "clean", "rest", "ball", "bark", "greet", "play_clip", "walk_to"]:
		check(scripts.has(id), "registered script: " + id)
	check(scripts.ball.get("static") == false, "ball script forces non-static")
	# Door portal has params.target; migration already applied.
	var door: Dictionary = {}
	for e in project.levels[0].elements:
		if e.script == "portal" and e.get("params", {}).get("target") == "yard": door = e
	check(door.get("script") == "portal" and door.get("params", {}).get("target") == "yard", "door migrated to portal params")
	# Legacy project migration.
	var legacy := {
		"format": "yufriend-levels", "version": 1, "name": "legacy", "startLevel": "home",
		"assets": project.assets,
		"levels": [{
			"id": "home", "name": "Dom", "width": 1440, "height": 360,
			"spawn": {"x": 670, "y": 322},
			"walk": {"x": 95, "y": 286, "width": 1250, "height": 42},
			"elements": [{
				"id": "bed", "name": "Legowisko", "asset": "bed", "layer": "background",
				"x": 205, "y": 322, "width": 180, "height": 72,
				"pivot": {"x": 30, "y": 18}, "visible": true, "locked": false, "static": true,
				"interactive": true, "behavior": "rest", "target": "", "script": "", "text": ""
			}]
		}]
	}
	var migrated: Dictionary = LevelProject.migrate(legacy)
	var bed: Dictionary = migrated.levels[0].elements[0]
	check(bed.get("script") == "rest" and bed.get("params", {}).has("energy"), "legacy rest migrated with params")
	check(migrated.levels[0].get("walkSpeed") == 70, "legacy level picks up walkSpeed default")
	for mutation in ["version", "portal", "script", "duplicate", "position", "static_ball", "null", "param"]:
		var bad := project.duplicate(true)
		match mutation:
			"version": bad.version = 99
			"portal":
				for e in bad.levels[0].elements:
					if e.script == "portal": e.params.target = "missing"
			"script":
				bad.levels[0].elements[0].script = "res://bad.gd"
			"duplicate": bad.levels.append(bad.levels[0].duplicate(true))
			"position": bad.levels[0].spawn.x = -1
			"static_ball":
				for e in bad.levels[0].elements:
					if e.script == "ball": e.static = true
			"null": bad.levels[0].elements.append(null)
			"param":
				for e in bad.levels[0].elements:
					if e.script == "ball": e.params.arc = 999
		check(not LevelProject.validate(bad).is_empty(), "rejects " + mutation)
	check(not LevelProject.source_allowed("res://assets/../secret.png"), "path traversal rejected")
	# A synthetic element checks pivot math independently of the edited scene.
	var food: Dictionary = {"x": 485, "y": 505, "width": 60, "height": 36, "pivot": {"x": 10, "y": 10}}
	var food_asset: Dictionary = {}
	for a in project.assets:
		if a.id == "food": food_asset = a
	check(LevelProject.element_rect(food, food_asset) == Rect2(455, 475, 60, 36), "pivot preserves game coordinates")
	print("LEVEL PROJECT: %d passed, %d failed" % [passed, failed])
	quit(1 if failed else 0)

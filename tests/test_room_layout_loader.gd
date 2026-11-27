extends SceneTree
var passed := 0
var failed := 0
func check(ok: bool, label: String) -> void:
	if ok: passed += 1
	else: failed += 1; push_error(label)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	# Snapshot defaults so other test runs stay deterministic after we mutate.
	var bed_default: Vector2 = RoomLayout.STATIONS.bed.position
	var food_default: Vector2 = RoomLayout.STATIONS.food.position
	var door_default: Vector2 = RoomLayout.STATIONS.door.position
	var door_stand_default: Vector2 = RoomLayout.STATIONS.door.stand
	var yard_shade_default: Vector2 = RoomLayout.YARD_STATIONS.shade.point
	const Loader = preload("res://scripts/model/room_layout_loader.gd")
	var loader = Loader.new()
	# The edited scene may move interactive objects; untouched stations retain defaults.
	var r: Dictionary = loader.apply()
	check(r.ok, "loader applied ver1.json successfully")
	check(r.home_elements >= 4, "home elements traversed")
	check(RoomLayout.STATIONS.bed.position == bed_default, "bed stays at authored position")
	check(RoomLayout.STATIONS.food.position == food_default, "food stays at authored position")
	var edited_door: Vector2 = RoomLayout.STATIONS.door.position
	var edited_door_stand: Vector2 = RoomLayout.STATIONS.door.stand
	# Yard station point is not touched — only bounds can change.
	check(RoomLayout.YARD_STATIONS.shade.point == Vector2(144, 366), "yard point follows authored shade")
	# Move the portal +60 in X in a synthetic project and verify the override.
	var synthetic := _load_json("res://level-editor/projects/ver1.json")
	for e in synthetic.levels[0].elements:
		if e.script == "portal": e.x += 60
	var scratch := OS.get_environment("YUFRIEND_TEST_ROOT")
	var temp_path := scratch.path_join("_rll_test.json") if not scratch.is_empty() else "user://_rll_test.json"
	_write_json(temp_path, synthetic)
	var r2: Dictionary = loader.apply(temp_path)
	check(r2.ok, "loader applied override project")
	check(RoomLayout.STATIONS.door.position.x == edited_door.x + 60, "door moved to editor x")
	check(RoomLayout.STATIONS.door.stand.x == edited_door_stand.x + 60, "door stand nudged by same delta")
	# Restore defaults so downstream tests see clean state.
	RoomLayout.STATIONS.bed.position = bed_default
	RoomLayout.STATIONS.door.position = door_default
	RoomLayout.STATIONS.door.stand = door_stand_default
	print("ROOM LAYOUT LOADER: %d passed, %d failed" % [passed, failed])
	var absolute := ProjectSettings.globalize_path(temp_path)
	if FileAccess.file_exists(temp_path): DirAccess.remove_absolute(absolute)
	quit(1 if failed else 0)

func _load_json(path: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(path))

func _write_json(path: String, data: Dictionary) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(data, "  "))
	f.close()

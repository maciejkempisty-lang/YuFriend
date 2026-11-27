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
	var bed_stand_default: Vector2 = RoomLayout.STATIONS.bed.stand
	var yard_shade_default: Vector2 = RoomLayout.YARD_STATIONS.shade.point
	const Loader = preload("res://scripts/model/room_layout_loader.gd")
	var loader = Loader.new()
	# Default starter positions match handcrafted defaults, so applying is a no-op.
	var r: Dictionary = loader.apply()
	check(r.ok, "loader applied starter.json successfully")
	check(r.home_elements >= 4, "home elements traversed")
	check(RoomLayout.STATIONS.bed.position == bed_default, "bed stays at authored position")
	check(RoomLayout.STATIONS.food.position == food_default, "food stays at authored position")
	# Yard station point is not touched — only bounds can change.
	check(RoomLayout.YARD_STATIONS.shade.point == yard_shade_default, "yard point preserved")
	# Now move bed +60 in X in a synthetic project and verify override.
	var synthetic := _load_json("res://level-editor/projects/starter.json")
	for e in synthetic.levels[0].elements:
		if e.id == "bed": e.x += 60
	_write_json("user://_rll_test.json", synthetic)
	var r2: Dictionary = loader.apply("user://_rll_test.json")
	check(r2.ok, "loader applied override project")
	check(RoomLayout.STATIONS.bed.position.x == bed_default.x + 60, "bed moved to editor x")
	check(RoomLayout.STATIONS.bed.stand.x == bed_stand_default.x + 60, "bed stand nudged by same delta")
	# Restore defaults so downstream tests see clean state.
	RoomLayout.STATIONS.bed.position = bed_default
	RoomLayout.STATIONS.bed.stand = bed_stand_default
	print("ROOM LAYOUT LOADER: %d passed, %d failed" % [passed, failed])
	var da := DirAccess.open("user://"); if da and da.file_exists("_rll_test.json"): da.remove("_rll_test.json")
	quit(1 if failed else 0)

func _load_json(path: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(path))

func _write_json(path: String, data: Dictionary) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(data, "  "))
	f.close()

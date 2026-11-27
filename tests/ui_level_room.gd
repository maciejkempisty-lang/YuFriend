extends SceneTree
var passed := 0
var failed := 0
func check(ok: bool, label: String) -> void:
	if ok: passed += 1
	else: failed += 1; push_error(label)
func _initialize() -> void:
	create_timer(30).timeout.connect(func(): quit(1))
	call_deferred("run")
func run() -> void:
	root.size = Vector2i(1200, 720)
	root.content_scale_size = root.size
	var tmp := "user://pet_ui_level_room_test.json"
	if FileAccess.file_exists(ProjectSettings.globalize_path(tmp)):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(tmp))
	const RoomScript = preload("res://scripts/levels/level_room.gd")
	var room = RoomScript.new()
	room.save_path = tmp
	root.add_child(room)
	await process_frame
	await process_frame
	check(room.session.pet != null, "session.start seeded a real PetState")
	check(room.preview.external_pet == room.session.pet, "preview bound to session's pet")
	check(room.preview.game_mode, "preview switched to game mode")
	check(not room.preview.needs.visible, "preview's test-pet HUD is hidden")
	check(not room.preview.selector.visible, "preview's level selector is hidden in game mode")
	check(room.preview.current.id == "home", "home level loaded from starter.json")
	var before_fullness: int = room.session.pet.needs.fullness
	# Trigger feed script by finding the food element and calling activate directly.
	var food: Dictionary
	for e in room.preview.current.elements:
		if e.id == "food": food = e; break
	check(not food.is_empty(), "food element present in starter home")
	room.preview.activate(food, Vector2.ZERO)
	for i in 400: room.preview._process(.05)
	check(room.session.pet.needs.fullness >= before_fullness, "session.act drove real pet needs")
	await process_frame
	print("LEVEL ROOM: %d passed, %d failed" % [passed, failed])
	# Clean the test save.
	var globalized := ProjectSettings.globalize_path(tmp)
	if FileAccess.file_exists(globalized): DirAccess.remove_absolute(globalized)
	quit(1 if failed else 0)

extends SceneTree
var passed := 0
var failed := 0
func check(ok: bool, label: String) -> void:
	if ok: passed += 1
	else: failed += 1; push_error(label)
func _initialize() -> void:
	create_timer(40).timeout.connect(func(): quit(1))
	call_deferred("run")
func run() -> void:
	root.size = Vector2i(1200, 720)
	var base := "/tmp/yufriend-level-room-%d" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(base)
	var room := LevelRoom.new()
	room.project_path = "res://level-editor/projects/ver2.json"
	room.save_path = base.path_join("pet.json")
	root.add_child(room)
	await process_frame
	await process_frame
	room.session.set_process(false)
	room.preview.set_process(false)
	check(room.session.pet != null and room.preview.external_pet == room.session.pet, "real session bound")
	check(room.preview.game_mode and not room.preview.needs.visible, "preview test HUD hidden")
	check(room.preview.current.id == "home", "home project loaded")
	check(room.naming_pending, "fresh isolated pet opens naming")
	room.naming_input.text = "Luna"
	room._finish_naming()
	check(room.session.pet.pet_name == "Luna" and not room.naming_pending, "naming persisted")
	room.session.pet.resting = false
	room.session.night_sleep = false
	room.session.scheduled_sleep = false
	room.session.automatic_nap = false
	room.session._cancel_motion()
	room.session.activity = "idle"
	room.session.pet.needs.fullness = 40
	room.session.pet.needs.energy = 90
	var food := RoomLayoutLoader.element_for_script("feed", "home")
	room.preview.activate(food, Vector2.ZERO)
	check(room.session.activity == "approach", "authored food starts session approach")
	for i in 300: room.preview._process(0.1)
	check(room.session.pet.needs.fullness == 62, "arrival grants real feed exactly once")
	for i in 30: room.preview._process(0.1)
	check(room.session.pet.needs.fullness == 62, "no duplicate preview reward")
	var before := room.session.pet.to_dict()
	room._on_interaction("forged", "bath", {"script": "bath"})
	check(not room.session.in_bath and room.session.pet.to_dict() == before, "missing element cannot start bath or change save")
	room._on_interaction(str(food.id), "bath", food)
	check(not room.session.in_bath, "forged script on existing id rejected")
	room.preview.show_level("yard")
	check(room.session.in_yard, "yard mode follows level")
	room.preview.show_level("home")
	check(not room.session.in_yard, "home mode follows level")
	check(room.needs_bars.size() == 5 and room.tabs.get_child_count() >= 2, "HUD preserved")
	room.queue_free()
	await process_frame
	print("LEVEL ROOM: %d passed, %d failed" % [passed, failed])
	quit(1 if failed else 0)

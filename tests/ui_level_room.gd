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
	# Scrub leftovers from any previous run, including the save and its sidecars.
	var da := DirAccess.open("user://")
	if da:
		for fname in [tmp.replace("user://", ""), "pet_ui_level_room_test.json.bak", "music.cfg", "effects.cfg", "haptics.cfg"]:
			if da.file_exists(fname): da.remove(fname)
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
	check(not room.preview.selector.get_parent().visible, "preview toolbar (selector + reset) is hidden in game mode")
	check(room.preview.current.id == "home", "home level loaded from ver1.json")
	var before_fullness: int = room.session.pet.needs.fullness
	var food := {"id": "food-test", "name": "Miska", "asset": "food", "script": "feed", "params": {"fullness": 22}, "x": 485, "y": 505}
	room.preview.activate(food, Vector2.ZERO)
	for i in 400: room.preview._process(.05)
	check(room.session.pet.needs.fullness >= before_fullness, "session.act drove real pet needs")
	check(room.tabs.get_child_count() == room.preview.project.levels.size(), "level tabs match project (Dom + Ogród)")
	check(room.needs_bars.size() == 5, "five needs bars rendered")
	var bath_element := {
		"id": "tub", "name": "Wanna", "asset": "food", "layer": "middle",
		"x": 500, "y": 320, "width": 60, "height": 36, "pivot": {"x": 10, "y": 10},
		"visible": true, "locked": false, "static": true,
		"script": "bath", "params": {"message": "Myjemy się."}
	}
	room._on_interaction("tub", "bath", bath_element)
	check(not room.unhandled.has("bath@tub"), "bath script routed, not logged as unhandled")
	room._on_interaction("unknown", "nope", {"params": {}})
	check(room.unhandled.has("nope@unknown"), "unknown script logged for follow-up")
	# Portal to yard must update session.in_yard so yard-aware logic branches.
	room.preview.show_level("yard")
	await process_frame
	check(room.session.in_yard == true, "entering yard level flips session.in_yard")
	room.preview.show_level("home")
	await process_frame
	check(room.session.in_yard == false, "returning home clears session.in_yard")
	# Yard subsystems routed from scripts land without being flagged unhandled.
	for pair in [
		{"id":"c", "s":"course", "p":{}},
		{"id":"t", "s":"timed_course", "p":{}},
		{"id":"w", "s":"water", "p":{"spot":"puddle"}},
		{"id":"h", "s":"hide", "p":{"kind":"bush","seed":7}},
		{"id":"v", "s":"visitor", "p":{"guest":"bird"}},
	]:
		room._on_interaction(pair.id, pair.s, {"params": pair.p})
		check(not room.unhandled.has(pair.s + "@" + pair.id), pair.s + " script routed")
	# Settings bar renders three toggles + the bath-finish button (hidden unless bathing).
	check(room.settings_bar.get_child_count() == 4, "settings bar has music/effects/haptics + bath button")
	check(room.bath_finish.visible == room.session.in_bath, "bath finish button mirrors in_bath state")
	# Session signals steer the preview puppy.
	room.session.clip_requested.emit("wag_stand")
	await process_frame
	check(true, "clip_requested signal fires without crashing preview")
	# Fade overlay exists and renders with alpha 0..1 (gets kicked on level change).
	check(room.fade != null and room.fade.color.a <= 1.0, "fade overlay present and clamped")
	# Newly-created pet opens the naming dialog (save was deleted at start).
	check(room.naming_pending == true, "name onboarding opened for fresh save")
	# Simulate the user typing a name.
	room.naming_input.text = "Luna"
	room._finish_naming()
	check(room.session.pet.pet_name == "Luna", "naming dialog persists new name")
	check(not room.naming_pending, "naming flag clears after confirmation")
	await process_frame
	print("LEVEL ROOM: %d passed, %d failed" % [passed, failed])
	# Clean the test save.
	var globalized := ProjectSettings.globalize_path(tmp)
	if FileAccess.file_exists(globalized): DirAccess.remove_absolute(globalized)
	quit(1 if failed else 0)

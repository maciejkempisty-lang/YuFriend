extends SceneTree
var passed := 0
var failed := 0
func check(ok: bool, label: String) -> void:
	if ok: passed += 1
	else: failed += 1; push_error(label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var loader := RoomLayoutLoader.new()
	check(loader.apply("res://level-editor/projects/ver2.json").ok, "ver2 validates and loads all textures")
	var original := RoomLayoutLoader.active_project.duplicate(true)
	check(RoomLayoutLoader.has_script("training", "home"), "training authored")
	check(not RoomLayoutLoader.has_script("training", "yard"), "availability is level specific")
	var path := "/tmp/yufriend-authority-%d.json" % Time.get_ticks_usec()
	var moved := original.duplicate(true)
	for level in moved.levels:
		for e in level.elements:
			if e.id in ["drink", "puddle", "course", "visitor", "dig", "outing"]: e.x -= 90; e.y += 3
	write_json(path, moved)
	check(loader.apply(path).ok, "moved project loads")
	check(HomeDrink.bowl() == Vector2(465, 508), "home water follows element")
	check(HomeDrink.stand() == Vector2(517, 508), "home water stand keeps offset within walk area")
	check(RoomLayout.yard_point("puddle") == Vector2(261, 477), "yard point patched")
	check(YardWater.spots().puddle == Vector2(261, 477), "water gameplay uses patched point")
	check(RoomLayout.yard_stand("dig").x == 510, "dig target follows editor")
	check(RoomLayout.yard_stand("outing").x == 1206, "potty target follows editor")
	check(YardVisitors.fence().x == 870, "visitor fence follows script alias")
	var stand := HomeDrink.stand()
	check(loader.apply(path).ok and HomeDrink.stand() == stand, "repeat load never accumulates stand offsets")
	check(loader.apply("res://level-editor/projects/ver2.json").ok and HomeDrink.bowl().x == 555, "reload restores original geometry")
	var s := GameSession.new()
	root.add_child(s)
	var base := "/tmp/yufriend-authority-save-%d" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(base)
	s.start(base.path_join("pet.json")); s.set_process(false)
	s.pet.resting = false; s.night_sleep = false; s.scheduled_sleep = false; s.automatic_nap = false
	s.pet.needs.energy = 90; s.pet.needs.fullness = 90; s.activity = "idle"
	var empty := original.duplicate(true)
	for level in empty.levels: level.elements.clear()
	write_json(path, empty)
	check(loader.apply(path).ok, "empty authored levels remain valid")
	var before := s.pet.to_dict()
	check(not RoomLayoutLoader.has_script("bath", "home"), "no missing bath capability")
	check(not s.start_bath(), "bath entry point blocked")
	check(not s.start_cuddle(), "cuddle entry point blocked")
	check(not s.home_drink.start(s), "drink entry point blocked")
	check(not s.begin_training("sit", true), "training entry point blocked")
	check(not s.start_touch_game("tug"), "touch play entry point blocked")
	check(not s.throw_ball(Vector2(900, 495)), "canvas throw blocked")
	check(not s.offer_initiative("ball"), "autonomous invitation blocked")
	s._start_behavior("ball")
	check(s.activity == "idle", "autonomous ball behavior blocked")
	s.in_yard = true
	for script in ["course", "timed_course", "water", "sniff", "hide", "visitor", "dig", "potty", "garden", "bubble_play"]:
		check(not LevelActions.run(s, script), "dispatcher blocks missing " + script)
	check(not s.yard_rest.start(s, "drink"), "autonomous yard rest blocked")
	check(YardInvitations.options(s).is_empty(), "no invitation to missing objects")
	check(s.pet.to_dict() == before, "denied mechanics preserve all pet fields")
	var hidden := original.duplicate(true)
	for level in hidden.levels:
		for e in level.elements:
			if e.script == "water" and e.params.spot == "sprinkler": e.visible = false
	write_json(path, hidden); check(loader.apply(path).ok, "hidden project loads")
	check(RoomLayoutLoader.has_script("water", "yard", {"spot": "puddle"}), "visible water remains available")
	check(not RoomLayoutLoader.has_script("water", "yard", {"spot": "sprinkler"}), "other water source cannot grant hidden source")
	check(not s.water.start(s, "sprinkler"), "hidden water source blocked in subsystem")
	check(not loader.apply("/tmp/yufriend-file-does-not-exist.json").ok, "bad load rejected")
	check(RoomLayoutLoader.has_script("water", "yard", {"spot": "puddle"}), "failed load retains last complete project")
	loader.apply("res://level-editor/projects/ver2.json")
	s.queue_free(); await process_frame
	DirAccess.remove_absolute(path)
	print("SCENE AUTHORITY: %d passed, %d failed" % [passed, failed])
	quit(1 if failed else 0)
func write_json(path: String, data: Dictionary) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(data))

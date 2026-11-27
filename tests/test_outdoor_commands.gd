extends SceneTree
var passed := 0
var failed := 0
func check(ok: bool, label: String) -> void:
	if ok: passed += 1
	else:
		failed += 1
		push_error(label)
func game() -> GameSession:
	var s := GameSession.new()
	s.pet = PetState.create(42)
	s.storage = SaveSystem.new(preload("res://tests/helper_paths.gd").data_root() + "/yuf-command-%s/pet.json" % Time.get_ticks_usec())
	s.local_clock = func(): return 100 * 86400.0 + 12 * 3600
	s.active = true
	s._brain_left = INF
	s.pet.skills.come.mastery = 100.0
	s.pet.skills.sit.mastery = 100.0
	s.pet.skills.stay.mastery = 100.0
	PracticeSystem.sync(s.pet, s._local_now())
	s.pet.practice.targets = ["come", "stay"]
	s.pet.practice.forms.come.value = 50
	s.pet.practice.forms.stay.value = 50
	s.change_yard(true)
	return s
func _initialize() -> void:
	var s := game()
	s.outdoor_commands.offer_recall(Vector2(700, 310))
	check(s.outdoor_commands.available_key(s) == "come", "recall offer is available")
	s._process(1.5)
	check(s.outdoor_commands.start(s, true), "guided recall starts")
	s._process(2.5)
	check(not s.outdoor_commands.praise(s) and s.pet.practice.done.is_empty(), "travel must finish before praise")
	s.destination_reached()
	s._process(0.1)
	check(s.outdoor_commands.phase == "praise", "arrival opens praise")
	check(s.outdoor_commands.praise(s), "successful recall rewarded")
	check(s.pet.practice.done.has("come") and s.pet.practice.forms.come.value == 75, "recall refreshes form and daily target")
	check(not s.outdoor_commands.praise(s), "duplicate praise ignored")
	check(s.start_hide("treat", 42), "treat hide starts")
	check(s.outdoor_commands.available_key(s) == "stay", "hide offers stay")
	check(s.outdoor_commands.start(s, true), "stay starts")
	check(not s.choose_hide_bush(0), "cannot hide during hold")
	s._process(2.5)
	check(s.outdoor_commands.praise(s), "completed stay praised")
	check(s.pet.practice.done.size() == 2 and s.pet.practice.rewarded and s.pet.practice.streak == 1, "outdoor commands complete same daily plan")
	check(s.pet.practice.forms.stay.value == 75, "stay form refreshed")
	check(s.outdoor_commands.available_key(s).is_empty(), "one stay per round")
	check(s.choose_hide_bush(0), "normal search continues")
	var loaded: PetState = s.storage.load_pet().pet
	check(loaded.practice.done == s.pet.practice.done and loaded.practice.rewarded, "daily credit survives reload")
	s.change_yard(false)
	s.free()
	s = game()
	s.outdoor_commands.offer_recall(Vector2(700, 310))
	check(s.outdoor_commands.start(s, false, 0.99), "free command can fail")
	s._process(2.5)
	check(s.pet.practice.done.is_empty() and s.pet.practice.forms.come.value == 50, "failed command gives no practice")
	s.pet.fatigue = 0
	s.outdoor_commands.offer_recall(Vector2(700, 310))
	s.outdoor_commands.start(s, true)
	s.change_yard(false)
	s.destination_reached()
	s._process(3)
	check(not s.outdoor_commands.praise(s) and s.pet.practice.done.is_empty(), "leaving invalidates recall")
	s.change_yard(true)
	s.pet.fatigue = 0
	s.outdoor_commands.offer_recall(Vector2(700, 310))
	s.outdoor_commands.start(s, true)
	s.suspend_session()
	s.destination_reached()
	check(not s.outdoor_commands.praise(s) and not s.outdoor_commands.running(), "background invalidates trial")
	s.suspended = false
	s.active = true
	s.change_yard(true)
	s.pet.fatigue = 0
	s.outdoor_commands.offer_recall(Vector2(700, 310))
	s.outdoor_commands.start(s, true)
	s.destination_reached()
	s._process(2.5)
	var before_failure := s.pet.to_dict()
	var file := FileAccess.open(s.storage.path, FileAccess.WRITE)
	file.store_string(JSON.stringify({"schema_version": 99, "pet": before_failure}))
	file.close()
	check(not s.outdoor_commands.praise(s), "failed save rejects reward")
	check(s.pet.to_dict() == before_failure, "failed save restores skills form bond and daily credit")
	check(not s.outdoor_commands.praise(s), "failed reward cannot repeat")
	s.storage = SaveSystem.new(preload("res://tests/helper_paths.gd").data_root() + "/yuf-command-flower-%s/pet.json" % Time.get_ticks_usec())
	for plant in YardRoutines.PLANTS:
		check(not KeepsakeSystem.unlock_reason(s.pet, plant).is_empty(), "ungrown flower locked")
		s.pet.yard_routines.flowers.append(plant)
		check(KeepsakeSystem.toggle_decor(s, plant), "existing grown flower unlocks unique decoration")
	check(s.storage.load_pet().pet.decor == s.pet.decor, "three flower decorations persist")
	var old := s.pet.to_dict()
	old.decor = ["rug", "flower"]
	var migrated := SaveSystem.migrate(old, 13)
	for key in old: check(old[key] == migrated[key], "v13 preserves " + key)
	check(PetState.from_dict(migrated) != null, "v13 remains readable")
	s.free()
	print("OUTDOOR COMMANDS: %d passed, %d failed" % [passed, failed])
	quit(1 if failed else 0)

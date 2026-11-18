extends SceneTree
var passed := 0
var failed := 0
var day := 102 # garden + trick
func check(ok: bool, label: String) -> void:
	if ok: passed += 1
	else:
		failed += 1
		push_error(label)
func game() -> GameSession:
	var s := GameSession.new()
	s.pet = PetState.create(42)
	s.storage = SaveSystem.new(preload("res://tests/helper_paths.gd").data_root() + "/yuf-adventure-%s/pet.json" % Time.get_ticks_usec())
	s.storage.save_pet(s.pet)
	s.pet = s.storage.load_pet().pet
	s.local_clock = func(): return day * 86400.0 + 12 * 3600
	s.active = true
	s._brain_left = INF
	s.in_yard = true
	return s
func train(s: GameSession) -> bool:
	s.activity = "idle"
	s.activity_left = 0
	s.training.begin(s.pet, "sit", true)
	s.training.advance(s.training.time_left + 0.01)
	return s.give_reward("praise")
func _initialize() -> void:
	var s := game()
	var before := s.pet.to_dict()
	var view := DailyAdventure.view(s.pet, s._local_now())
	check(view.day == day and view.done.is_empty() and s.pet.to_dict() == before, "view has no persistent side effects")
	check(not s.give_reward("praise") and s.pet.adventure.done.is_empty(), "unearned praise not counted")
	check(YardRoutines.garden(s, "daisy"), "plant succeeds")
	check(s.pet.adventure.done == ["garden"], "plant records one step")
	check(YardRoutines.garden(s, "water"), "water succeeds")
	check(s.pet.adventure.done.size() == 1, "same category cannot complete both steps")
	check(train(s), "successful rewarded trick")
	check(s.pet.adventure.rewarded and s.pet.milestones.has("adventure_0"), "two activities give album keepsake")
	var loaded: PetState = s.storage.load_pet().pet
	check(loaded.adventure.rewarded and loaded.adventure.done.size() == 2, "reward persisted atomically")
	var journal_count := s.pet.journal.size()
	var bond := s.pet.bond
	check(not DailyAdventure.record(s.pet, "garden", s._local_now()), "completion cannot repeat")
	check(s.pet.journal.size() == journal_count and s.pet.bond == bond, "no duplicate reward or extra bond")
	day = 101
	check(not DailyAdventure.record(s.pet, "treasure", s._local_now()) and s.pet.adventure.day == 102, "rollback preserves high-water mark")
	day = 105
	s.activity = "idle"
	s.activity_left = 0
	check(YardRoutines.garden(s, "observe"), "already watered garden can be checked")
	check(s.pet.adventure.day == day and s.pet.adventure.done == ["garden"], "new day starts without backlog")
	check(s.pet.bond == bond and s.pet.milestones.has("adventure_0"), "missed days do not remove rewards")
	s.free()
	day = 104 # garden + treasure
	s = game()
	YardRoutines.garden(s, "daisy")
	check(s.start_sniff(0), "sniff starts")
	check(s.pet.adventure.done == ["garden"], "starting search is not finishing")
	s.destination_reached()
	s._finish_sniff()
	check(s.pet.adventure.rewarded and s.pet.milestones.has("adventure_2"), "completed sniff counts")
	day = 107
	YardRoutines.garden(s, "water")
	s.start_sniff(0)
	s.destination_reached()
	s._finish_sniff()
	check(s.pet.adventure.rewarded, "known treasure counts again on another day")
	check(s.pet.journal.filter(func(e): return e.key == "adventure_2").size() == 1, "collectible not duplicated")
	s.free()
	day = 103 # trick + treasure
	s = game()
	train(s)
	s.activity = "idle"
	s.activity_left = 0
	check(DiggingSystem.start(s), "dig starts")
	s.destination_reached()
	check(DiggingSystem.finish(s), "dig finishes")
	check(s.pet.adventure.rewarded and s.pet.milestones.has("adventure_1"), "dig integrates with training")
	s.free()
	day = 102
	s = game()
	s.storage = SaveSystem.new("/dev/null/pet.json")
	before = s.pet.to_dict()
	check(not YardRoutines.garden(s, "daisy"), "failed save rejects garden action")
	check(s.pet.to_dict() == before, "failed save rolls back garden and task together")
	check(not train(s), "failed training reward save rejected")
	check(s.pet.adventure.done.is_empty() and not s.pet.milestones.has("adventure_0"), "failed training grants no adventure")
	s.free()
	day = 103
	s = game()
	s.outdoor_commands.offer_recall(Vector2(700, 310))
	check(s.outdoor_commands.start(s, true), "outdoor recall starts")
	s._process(2.5)
	check(s.pet.adventure.done.is_empty(), "outdoor command needs arrival and praise")
	s.destination_reached()
	s._process(0.1)
	check(s.outdoor_commands.praise(s), "outdoor praise succeeds")
	check(s.pet.adventure.done == ["trick"], "outdoor command counts toward same adventure")
	s.free()
	var legacy := PetState.create(42).to_dict()
	legacy.erase("adventure")
	var migrated := SaveSystem.migrate(legacy, 14)
	check(migrated.adventure == DailyAdventure.initial(), "v14 gains empty adventure only")
	for key in legacy: check(legacy[key] == migrated[key], "migration preserves " + key)
	check(PetState.from_dict(migrated) != null, "migrated state valid")
	for bad in [{"day": 2, "done": ["garden", "garden"], "rewarded": true}, {"day": -1, "done": [], "rewarded": true}, {"day": 1, "done": ["garden"], "rewarded": false}, {"day": 1, "done": [], "rewarded": true}]:
		check(not DailyAdventure.valid(bad), "invalid task state rejected")
	print("ADVENTURE RESULTS: %d passed, %d failed" % [passed, failed])
	quit(1 if failed else 0)

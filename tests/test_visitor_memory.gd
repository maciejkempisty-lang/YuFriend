extends SceneTree
var passed := 0
var failed := 0
var day := 100
func check(ok: bool, label: String) -> void:
	if ok: passed += 1
	else:
		failed += 1
		push_error(label)
func game() -> GameSession:
	var s := GameSession.new()
	s.pet = PetState.create(42)
	s.storage = SaveSystem.new("/tmp/yuf-memory-%s/pet.json" % Time.get_ticks_usec())
	s.storage.save_pet(s.pet)
	s.pet = s.storage.load_pet().pet
	s.local_clock = func(): return day * 86400.0 + 12 * 3600
	s.active = true
	s.in_yard = true
	s._brain_left = INF
	return s
func soothe(s: GameSession, guest: String) -> void:
	check(s.visitors.start(s, guest), "encounter starts")
	check(s.visitors.respond(s, "soothe"), "soothe accepted")
	s.visitors.advance(s, 2.6)
func _initialize() -> void:
	var s := game()
	var original := s.pet.to_dict()
	check(not VisitorMemory.known(s.pet, "cat"), "old save has no invented encounters")
	s.visitors.start(s, "cat")
	check(VisitorMemory.known(s.pet, "cat"), "first sight recorded")
	check(not s.visitors.familiar, "first encounter not called familiar")
	s.visitors.advance(s, 31)
	check(VisitorMemory.level(s.pet, "cat") == 0, "ignoring does not grant peaceful credit")
	soothe(s, "cat")
	check(VisitorMemory.level(s.pet, "cat") == 1, "first calm day")
	soothe(s, "cat")
	check(VisitorMemory.level(s.pet, "cat") == 1, "same day cannot farm progress")
	var restored: PetState = s.storage.load_pet().pet
	check(VisitorMemory.level(restored, "cat") == 1, "progress survives reload")
	s.pet = restored
	day = 99
	soothe(s, "cat")
	check(VisitorMemory.level(s.pet, "cat") == 1, "clock rollback cannot grant progress")
	day = 101
	s.visitors.start(s, "cat")
	check(s.visitors.familiar and s.visitors.hint().contains("Znowu razem"), "returning visitor recognized")
	s.visitors.respond(s, "recall")
	s.visitors.advance(s, 2)
	check(VisitorMemory.level(s.pet, "cat") == 1, "recall requires arrival")
	s.destination_reached()
	check(VisitorMemory.level(s.pet, "cat") == 2, "recall arrival records calm day")
	day = 102
	s.visitors.start(s, "cat")
	s.visitors.respond(s, "soothe")
	s.change_yard(false)
	check(VisitorMemory.level(s.pet, "cat") == 2, "cancelled soothing not credited")
	s.in_yard = true
	soothe(s, "cat")
	check(VisitorMemory.level(s.pet, "cat") == 3, "third distinct calm day")
	var count := s.pet.journal.size()
	day = 103
	soothe(s, "cat")
	check(VisitorMemory.level(s.pet, "cat") == 3 and s.pet.journal.size() == count, "bounded memories after completion")
	check(VisitorMemory.level(s.pet, "bird") == 0, "guests have independent memories")
	for key in original:
		if key not in ["journal", "milestones", "last_seen_at"]:
			check(original[key] == s.pet.to_dict()[key], "preserves " + key)
	var shy := {"curiosity": 0.4, "patience": 0.8, "sociability": 0.25, "sensitivity": 0.85}
	check(YardVisitors.reaction_for(shy, "cat", 0) == "shy", "new cat frightening")
	check(YardVisitors.reaction_for(shy, "cat", 1) == "wary", "known cat watched cautiously")
	check(YardVisitors.reaction_for(shy, "cat", 3) == "calm", "familiar cat less intimidating")
	shy.sensitivity = 1
	shy.sociability = 0
	check(YardVisitors.reaction_for(shy, "cat", 3) == "wary", "very sensitive dog retains caution")
	s.free()
	s = game()
	s.storage = SaveSystem.new("/dev/null/pet.json")
	var before := s.pet.to_dict()
	check(not VisitorMemory.record(s, "bird", true), "save failure reported")
	check(s.pet.to_dict() == before, "save failure restores all state")
	s.free()
	print("VISITOR MEMORY RESULTS: %d passed, %d failed" % [passed, failed])
	quit(1 if failed else 0)

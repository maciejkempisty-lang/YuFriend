extends SceneTree
var passed := 0
var failed := 0
var directory := preload("res://tests/helper_paths.gd").data_root() + "/yuf-npc-%s" % Time.get_ticks_usec()
func check(ok: bool, label: String) -> void:
	if ok: passed += 1
	else:
		failed += 1
		push_error(label)
func game(pet: PetState = null) -> GameSession:
	var s := GameSession.new()
	s.pet = PetState.create(42) if pet == null else pet
	s.storage = SaveSystem.new(directory.path_join("pet.json"))
	s.active = true
	s.local_clock = func(): return 100 * 86400.0 + 12 * 3600
	s.initiatives_enabled = false
	s._brain_left = INF
	s.change_yard(true)
	return s
func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(directory)
	var s := game()
	var bond := s.pet.bond
	var skills := s.pet.skills.duplicate(true)
	for guest in YardVisitors.KINDS:
		s.visitors.advance(s, s.visitors.wait_left)
		check(s.visitors.kind == guest, "one yard entry automatically reaches " + guest)
		s.visitors.finish(s, "")
	s.visitors.advance(s, 1000)
	check(not s.visitors.active() and s.visitors.visits == 3, "visit cap still prevents endless interruptions")
	check(s.pet.bond == bond and s.pet.skills == skills, "new schedule never grants training or bond")
	s.free()
	s = game()
	for guest in YardVisitors.KINDS:
		s.visitors.advance(s, YardVisitors.FIRST_WAIT)
		check(s.visitors.kind == guest, "rotation survives restart before " + guest)
		var loaded: PetState = s.storage.load_pet().pet
		s.free()
		s = game(loaded)
	s.activity = "walk"
	s.visitors.advance(s, YardVisitors.FIRST_WAIT)
	check(s.visitors.wait_left == 0 and not s.visitors.active(), "walking counts toward wait but is not interrupted")
	s.activity = "idle"
	s.visitors.advance(s, 0.01)
	check(s.visitors.active(), "ready guest arrives after the walk")
	s.visitors.finish(s, "")
	s.visitors.begin_visit()
	var before := s.pet.to_dict()
	s.storage.path = "/dev/null/unwritable-npc.json"
	check(not s.visitors.start(s, "cat") and not s.visitors.active() and s.visitors.visits == 0, "failed save consumes neither visit nor rotation")
	check(s.pet.to_dict() == before, "failed visitor persistence rolls back all progress")
	for invalid in [-1, 3, 0.5, "cat", NAN]:
		var data := s.pet.to_dict()
		data.yard_routines.visitor_next = invalid
		check(PetState.from_dict(data) == null, "invalid rotation rejected")
	s.free()
	for name in DirAccess.get_files_at(directory): DirAccess.remove_absolute(directory.path_join(name))
	DirAccess.remove_absolute(directory)
	print("NPC SCHEDULE RESULTS: %d passed, %d failed" % [passed, failed])
	quit(1 if failed else 0)

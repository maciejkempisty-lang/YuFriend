extends SceneTree
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func _initialize() -> void:
	var s := GameSession.new()
	s.pet = PetState.create(42)
	s.storage = SaveSystem.new(preload("res://tests/helper_paths.gd").data_root() + "/yuf-potty-%s/pet.json" % Time.get_ticks_usec())
	s.local_clock = func(): return 20000 * 86400.0 + 12 * 3600
	s.active = true
	s.weather.override_kind = "sun"
	s._brain_left = INF
	s.in_yard = true
	var original := s.pet.to_dict()
	check(PetState.from_dict(original).to_dict() == original, "legacy save is not rewritten with extra fields")
	check(not YardRoutines.clean_up(s), "no cleanup reward without a mess")
	check(YardRoutines.start_outing(s), "new daily outing")
	check(not YardRoutines.clean_up(s), "cannot clean before toilet animation")
	s.destination_reached()
	check(s.activity == "outing_pause", "arrival starts toilet pose")
	var bond := s.pet.bond
	s._process(4.1)
	check(YardRoutines.has_mess(s) and not YardRoutines.due(s), "finished toilet leaves mess and consumes daily outing")
	check(s.pet.bond == bond, "reward waits for cleanup")
	var restored := s.storage.load_pet().pet as PetState
	check(restored.yard_routines.mess, "mess survives save and reload")
	s.pet = restored
	s.activity = "idle"
	check(YardRoutines.clean_up(s) and s.pet.bond == bond + 0.5, "cleanup works after restart and rewards once")
	check(not YardRoutines.clean_up(s) and not s.storage.load_pet().pet.yard_routines.mess, "double tap cannot duplicate cleanup reward")
	s.local_clock = func(): return 19999 * 86400.0 + 12 * 3600
	check(not YardRoutines.due(s), "rollback cannot renew outing")
	s.local_clock = func(): return 20001 * 86400.0 + 12 * 3600
	check(YardRoutines.start_outing(s), "next day outing")
	s.change_yard(false)
	s.destination_reached()
	check(not YardRoutines.has_mess(s) and s.pet.yard_routines.outday == 20000, "leaving before completion creates no mess")
	s.in_yard = true
	s.activity = "outing_pause"
	var before := s.pet.to_dict()
	s.storage = SaveSystem.new("/dev/null/pet.json")
	check(not YardRoutines.finish_outing(s) and s.pet.to_dict() == before, "failed toilet save rolls back all progress")
	s.pet.yard_routines.mess = true
	before = s.pet.to_dict()
	s.activity = "outing_praise"
	check(not YardRoutines.clean_up(s) and s.pet.to_dict() == before, "failed cleanup keeps mess and bond")
	s.storage = SaveSystem.new(preload("res://tests/helper_paths.gd").data_root() + "/yuf-potty-sleep-%s/pet.json" % Time.get_ticks_usec())
	s.pet.resting = true
	s.activity = "sleep"
	check(YardRoutines.clean_up(s) and s.activity == "sleep" and s.pet.resting, "picking up an old mess does not wake the dog")
	var malformed := before.duplicate(true)
	malformed.yard_routines.mess = "yes"
	check(PetState.from_dict(malformed) == null, "invalid mess flag rejected")
	s.free()
	print("POTTY FAILURES: ", failures)
	quit(1 if failures else 0)

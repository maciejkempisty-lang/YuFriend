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
	s.storage = SaveSystem.new("/tmp/yuf-visitors-%s/pet.json" % Time.get_ticks_usec())
	s.local_clock = func(): return 100 * 86400.0 + 12 * 3600
	s.active = true
	s._brain_left = INF
	s.change_yard(true)
	return s
func _initialize() -> void:
	var shy := {"curiosity": 0.4, "patience": 0.8, "sociability": 0.25, "sensitivity": 0.85}
	var eager := {"curiosity": 0.85, "patience": 0.25, "sociability": 0.85, "sensitivity": 0.25}
	var curious := {"curiosity": 0.65, "patience": 0.8, "sociability": 0.4, "sensitivity": 0.25}
	var calm := {"curiosity": 0.25, "patience": 0.8, "sociability": 0.4, "sensitivity": 0.25}
	for guest in YardVisitors.KINDS:
		check(YardVisitors.reaction_for(eager, guest) == "bark", guest + " eager barks")
		check(YardVisitors.reaction_for(curious, guest) == "curious", guest + " curious approaches")
		check(YardVisitors.reaction_for(calm, guest) == "calm", guest + " calm watches")
	check(YardVisitors.reaction_for(shy, "cat") == "shy", "sensitive dog retreats from cat")
	check(YardVisitors.reaction_for(shy, "butterfly") == "calm", "butterfly less intimidating")
	var s := game()
	var before := s.pet.to_dict()
	for guest in YardVisitors.KINDS:
		s.visitors.begin_visit()
		s.pet.traits = curious.duplicate()
		check(s.visitors.start(s, guest), guest + " starts")
		check(s.busy() and s.play_readiness().is_empty(), "visit protects autonomy but leaves player games ready")
		s.destination_reached()
		check(s.visitors.phase == "watch", "arrival keeps encounter")
		check(s.visitors.respond(s, "soothe"), "soothe accepted")
		check(not s.visitors.respond(s, "recall"), "double response rejected")
		s.visitors.advance(s, 2.6)
		check(not s.visitors.active() and not s.busy(), "soothing completes")
	check(s.pet.bond == before.bond and s.pet.skills == before.skills and s.pet.practice == before.practice and s.pet.needs == before.needs, "visitors do not farm rewards or consume needs")
	check(s.visitors.start(s, "cat") and s.visitors.respond(s, "recall"), "recall starts")
	s.visitors.advance(s, 5)
	check(s.visitors.phase == "recall", "elapsed time alone does not finish recall")
	s.destination_reached()
	check(not s.visitors.active(), "actual arrival finishes recall")
	check(not s.visitors.respond(s, "recall"), "stale response ignored")
	s.visitors.begin_visit()
	s.visitors.start(s, "bird")
	s.visitors.advance(s, 31)
	check(not s.busy(), "ignored encounter expires")
	check(not s.visitors.start(s, "unknown"), "unknown guest rejected")
	s.outdoor_commands.offer_recall(Vector2(700, 310))
	check(not s.visitors.start(s, "cat"), "pending fetch command protected")
	s.outdoor_commands.cancel()
	s.portal_active = true
	check(not s.visitors.start(s, "cat"), "doorway protected")
	s.portal_active = false
	s.activity = "walk"
	check(not s.visitors.start(s, "bird"), "unfinished walk protected")
	s.activity = "idle"
	s.writable = false
	check(not s.visitors.start(s, "bird"), "read-only save protected")
	s.writable = true
	s.visitors.wait_left = 1
	s.attention_available = false
	s.visitors.advance(s, 50)
	check(not s.visitors.active() and s.visitors.wait_left == 1, "hidden yard pauses schedule")
	s.attention_available = true
	for guest in YardVisitors.KINDS:
		s.visitors.begin_visit()
		s.visitors.advance(s, YardVisitors.FIRST_WAIT)
		check(s.visitors.kind == guest, "rotation " + guest)
		s.visitors.finish(s, "")
	s.visitors.begin_visit()
	s.visitors.start(s, "cat")
	s.local_clock = func(): return 100 * 86400.0 + 23 * 3600
	s._process(0.1)
	check(not s.visitors.active(), "night dismisses guest")
	check(not s.visitors.start(s, "cat"), "no night guests")
	s._process(30)
	check(not s.in_yard, "night return still works")
	for step in 30:
		if s.activity == "walk": s.destination_reached()
		elif s.activity == "behavior": s._process(s.activity_left + 0.01)
		else: break
	check(s.is_sleeping(), "returned dog goes to sleep")
	s.free()
	s = game()
	s.visitors.start(s, "bird")
	s.pet.needs.energy = 27
	s._process(0.1)
	check(not s.visitors.active() and not s.in_yard, "tired dog leaves despite visit")
	s.free()
	s = game()
	s.visitors.start(s, "butterfly")
	s.suspend_session()
	check(not s.visitors.active() and not s.in_yard, "background clears encounter")
	var saved := s.storage.load_pet()
	check(saved.writable and saved.pet.pet_name == s.pet.pet_name, "save reload intact")
	check(not saved.pet.to_dict().has("visitors"), "encounters remain ephemeral; no schema change")
	s.free()
	print("VISITORS RESULTS: %d passed, %d failed" % [passed, failed])
	quit(1 if failed else 0)

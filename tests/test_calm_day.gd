extends SceneTree
var passed := 0
var failed := 0
var local_time := 100 * 86400.0 + 18 * 3600
func check(ok: bool, label: String) -> void:
	if ok: passed += 1
	else:
		failed += 1
		push_error(label)
func game() -> GameSession:
	var s := GameSession.new()
	s.pet = PetState.create(42)
	s.storage = SaveSystem.new("/tmp/yuf-calm-%s/pet.json" % Time.get_ticks_usec())
	s.local_clock = func(): return local_time
	s.weather.override_kind = "after_rain"
	s.active = true
	s._brain_left = INF
	s.change_yard(true)
	return s
func _initialize() -> void:
	for phase in ["watch", "approach", "soothe", "recall"]:
		for action in ["ball", "hide", "dig", "pet", "sniff", "garden", "outing", "water", "bath", "training"]:
			var s := game()
			check(s.visitors.start(s, "cat"), "start guest for " + phase + "/" + action)
			s.visitors.phase = phase
			s.visitors.response_left = 2.5
			var accepted := false
			match action:
				"ball": accepted = s.throw_ball(Vector2(900, 315), Vector2(600, 315))
				"hide": accepted = s.start_hide("treat", 42)
				"dig": accepted = DiggingSystem.start(s)
				"pet": accepted = s.act("pet")
				"sniff": accepted = s.start_sniff()
				"garden": accepted = YardRoutines.garden(s, "daisy")
				"outing": accepted = YardRoutines.start_outing(s)
				"water": accepted = s.water.start(s, "puddle")
				"bath":
					s.pet.needs.hygiene = 40
					accepted = s.start_bath()
				"training": accepted = s.begin_training("sit", true)
			check(accepted and not s.visitors.active(), "first action starts and dismisses " + phase + "/" + action)
			s.visitors.advance(s, 31)
			check(VisitorMemory.level(s.pet, "cat") == 0, "interrupted guest never grants calm credit " + phase + "/" + action)
			s.free()
	var s := game()
	for i in YardVisitors.SESSION_LIMIT:
		s.visitors.advance(s, 1000)
		check(s.visitors.active(), "scheduled guest " + str(i))
		s.visitors.finish(s, "")
	s.visitors.advance(s, 10000)
	check(not s.visitors.active() and not s.visitors.start(s, "cat"), "at most two visits per yard stay")
	s.change_yard(true)
	check(not s.visitors.start(s, "cat"), "reselecting yard cannot reset quota")
	s.change_yard(false)
	s.change_yard(true)
	check(s.visitors.visits == 0 and s.visitors.wait_left == YardVisitors.FIRST_WAIT, "real reentry resets visitor quota and delay")
	s.visitors.advance(s, YardVisitors.FIRST_WAIT - 1)
	check(not s.visitors.active(), "new stay does not spawn immediately")
	s.visitors.advance(s, 1)
	check(s.visitors.active(), "first wait counts only visible idle yard time")
	s.visitors.finish(s, "")
	s.free()
	# The elapsed clock and local calendar are deliberately independent (DST).
	s = game()
	var now := 10000000.0
	check(YardRoutines.garden(s, "daisy", now), "plant for calendar test")
	check(YardRoutines.garden(s, "water", now), "water in the evening")
	check(not YardRoutines.garden(s, "water", now + 1), "same local day cannot water twice")
	local_time = 101 * 86400.0 + 8 * 3600
	check(YardRoutines.garden(s, "water", now + 14 * 3600), "next morning waters before 24 hours")
	check(s.pet.yard_routines.water_until == now + 14 * 3600 + 86400, "early watering does not stack stored water")
	var saved: PetState = s.storage.load_pet().pet
	check(saved.yard_routines.watered_day == 101, "calendar day persists across restart")
	s.pet = saved
	check(not YardRoutines.garden(s, "water", now + 15 * 3600), "restart cannot repeat watering")
	local_time = 100 * 86400.0 + 20 * 3600
	check(not YardRoutines.garden(s, "water", now + 16 * 3600), "date rollback cannot reset watering")
	local_time = 102 * 86400.0 + 8 * 3600
	check(YardRoutines.garden(s, "water", now + 37 * 3600), "23 hour DST day permits next date")
	local_time = 103 * 86400.0 + 8 * 3600
	check(YardRoutines.garden(s, "water", now + 62 * 3600), "25 hour DST day permits next date")
	local_time = 104 * 86400.0 + 8 * 3600
	var before := s.pet.to_dict()
	s.storage = SaveSystem.new("/dev/null/pet.json")
	check(not YardRoutines.garden(s, "water", now + 63 * 3600), "failed watering save reported")
	check(s.pet.to_dict() == before, "failed save restores growth, day and water")
	var legacy := YardRoutines.initial()
	legacy.erase("watered_day")
	legacy.plant = "daisy"
	legacy.water_until = now + 86400
	check(YardRoutines.valid(legacy), "existing v15 garden still accepted")
	check(YardRoutines.watering_day(legacy, 100 * 86400.0 + 18 * 3600, now) == 100, "legacy watering derives local day")
	legacy.watered_day = "today"
	check(not YardRoutines.valid(legacy), "invalid calendar field rejected")
	s.free()
	var pet := PetState.create(12)
	for day in [100, 101, 102]:
		var at: float = day * 86400.0 + 12 * 3600
		var before_plan := pet.to_dict()
		var ideas := TodayPlan.suggestions(pet, at)
		check(ideas.size() == 3 and ideas[-1].id == "together", "three optional suggestions with untracked together time")
		check(ideas == TodayPlan.suggestions(pet, at) and pet.to_dict() == before_plan, "view stable and never writes progress")
		for task in DailyAdventure.PLANS[day % 3]: DailyAdventure.record(pet, task, at)
		check(TodayPlan.suggestions(pet, at).size() == 3, "completion never adds more obligations")
	check(TodayPlan.suggestions(pet, 103 * 86400.0 + 23 * 3600).all(func(idea): return idea.id in ["rest", "album"]), "night offers only quiet indoor activities")
	print("CALM DAY RESULTS: %d passed, %d failed" % [passed, failed])
	quit(1 if failed else 0)

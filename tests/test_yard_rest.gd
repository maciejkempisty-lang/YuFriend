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
	s.storage = SaveSystem.new(preload("res://tests/helper_paths.gd").data_root() + "/yuf-rest-%s/pet.json" % Time.get_ticks_usec())
	s.storage.save_pet(s.pet)
	s.pet = s.storage.load_pet().pet
	s.pet.needs.energy = 50.0
	s.pet.needs.fullness = 90.0
	s.local_clock = func(): return 100 * 86400.0 + 12 * 3600
	s.weather.override_kind = "sun"
	s.in_yard = true
	s.active = true
	s._brain_left = INF
	s.visitors.wait_left = INF
	return s
func _initialize() -> void:
	var s := game()
	var before := s.pet.to_dict()
	check(s.yard_rest.start(s, "drink"), "water starts")
	check(not s.pet.resting and s.pet.to_dict() == before, "walking to water grants nothing")
	check(s.busy() and not s.water.start(s, "puddle") and not s.visitors.start(s, "bird"), "drinking excludes other activities")
	s.destination_reached()
	check(s.yard_rest.phase == "drink", "arrival starts drinking")
	s.yard_rest.advance(s, 1)
	check(s.yard_rest.drink_stage == 1, "lapping loop")
	s.yard_rest.advance(s, 2.5)
	check(s.yard_rest.drink_stage == 2, "drinking exit")
	s.yard_rest.advance(s, 1)
	check(not s.yard_rest.active() and s.pet.to_dict() == before, "water creates no stat, reward or save change")
	check(s.yard_rest.start(s, "bed"), "bed starts")
	check(not s.pet.resting, "no energy before bed arrival")
	s.destination_reached()
	check(s.pet.resting and s.is_sleeping(), "existing resting flag used")
	check(s.storage.load_pet().pet.resting, "nap persisted for offline recovery")
	var energy: float = s.pet.needs.energy
	s._process(1)
	check(is_equal_approx(s.pet.needs.energy - energy, 0.8 - 5.0 / 3600), "existing rest rate applied once")
	check(s.pet.bond == before.bond and s.pet.skills == before.skills, "rest leaves progression alone")
	check(s.act("rest") and not s.pet.resting and not s.yard_rest.active(), "regular rest button wakes outdoors")
	check(s.yard_rest.start(s, "bed"), "second nap")
	s.destination_reached()
	s.suspend_session()
	check(not s.in_yard and s.suspended and s.pet.resting and not s.yard_rest.active(), "background transfers nap to house")
	check(s.storage.load_pet().pet.resting, "offline nap remains saved")
	s.free()
	s = game()
	s.yard_rest.note_play()
	s.yard_rest.advance(s, 5)
	check(not s.yard_rest.active(), "recovery waits for idle break")
	s.yard_rest.advance(s, 1.1)
	check(s.yard_rest.phase == "walk_drink", "play naturally leads to water")
	s.destination_reached()
	s.yard_rest.advance(s, 4.3)
	check(s.yard_rest.phase == "walk_bed", "water naturally leads to bed")
	s.destination_reached()
	s.pet.needs.energy = 84.9
	s._sleep_elapsed = 6
	s._process(1)
	check(not s.pet.resting and not s.yard_rest.active(), "existing wake threshold ends nap")
	check(s.yard_rest.cooldown > 0, "no immediate repeat of autonomous ritual")
	s.free()
	s = game()
	s.pet.needs.energy = 95
	s.yard_rest.start(s, "bed")
	s.destination_reached()
	check(not s.pet.resting, "well rested dog only lounges")
	s.yard_rest.advance(s, 8.1)
	check(not s.yard_rest.active() and s.pet.needs.energy == 95, "lounging grants no energy bonus")
	s.free()
	s = game()
	s.yard_rest.start(s, "bed")
	s.destination_reached()
	s.weather.override_kind = "rain"
	s.yard_rest.advance(s, 0.1)
	check(not s.in_yard and s.pet.resting, "rain moves nap indoors")
	s.free()
	s = game()
	s.yard_rest.start(s, "drink")
	s.local_clock = func(): return 100 * 86400.0 + 23 * 3600
	s.yard_rest.advance(s, 0.1)
	check(not s.in_yard and s.night_sleep, "night returns drinking dog home to sleep")
	s.free()
	s = game()
	s.pet.needs.energy = 27
	s.yard_rest.note_play()
	s._process(7)
	check(not s.in_yard and not s.yard_rest.active(), "exhaustion keeps existing return-home priority")
	s.free()
	s = game()
	s.yard_rest.start(s, "bed")
	before = s.pet.to_dict()
	s.storage = SaveSystem.new("/dev/null/blocked.json")
	s.destination_reached()
	check(not s.pet.resting and not s.yard_rest.active(), "failed save does not start nap")
	check(s.pet.needs == before.needs and s.pet.bond == before.bond, "failed nap preserves needs and progress")
	s.free()
	print("YARD REST RESULTS: %d passed, %d failed" % [passed, failed])
	quit(1 if failed else 0)

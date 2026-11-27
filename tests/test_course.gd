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
	s.storage = SaveSystem.new(preload("res://tests/helper_paths.gd").data_root() + "/yuf-course-%s/pet.json" % Time.get_ticks_usec())
	s.storage.save_pet(s.pet)
	s.pet = s.storage.load_pet().pet
	s.pet.skills.sit.mastery = 100.0
	s.pet.needs.energy = 90
	s.pet.needs.fullness = 90
	s.local_clock = func(): return 100 * 86400.0 + 12 * 3600
	s.in_yard = true
	s.active = true
	return s
func reach_podium(s: GameSession) -> void:
	for i in YardCourse.path().size(): s.destination_reached()
	check(s.course.phase == "jump_ready", "slalom ends at jump gate")
	check(s.course.jump(s) and not s.course.jump(s), "jump consumes one command")
	s.destination_reached()
	check(s.course.phase == "podium", "landing leads to podium")
	s.destination_reached()
	check(s.course.phase == "stay_ready", "arrival enables stay")
func _initialize() -> void:
	var s := game()
	var before := s.pet.to_dict()
	check(s.course.start(s), "course starts")
	check(s.busy() and not s.water.start(s, "puddle") and not s.visitors.start(s, "cat"), "course excludes other games and visitors")
	check(not s.course.stay(s) and not s.course.praise(s), "cannot skip stations")
	reach_podium(s)
	check(s.course.stay(s), "stay uses real trial")
	check(s.pet.skills.stay.attempts == 1 and s.pet.fatigue == before.fatigue + 12, "existing training attempt and fatigue")
	check(not s.course.praise(s), "no early praise")
	s.course.advance(s, 2.5)
	check(s.course.phase == "praise", "hold finishes before reward")
	check(s.course.praise(s), "praise finishes course")
	check(not s.course.active() and not s.course.praise(s), "single finish reward")
	check(s.pet.skills.stay.successes == 1 and s.pet.skills.stay.mastery > 0, "stay mastery progresses")
	check(s.pet.practice.forms.stay.practiced_day == 100, "shared daily form")
	check(s.pet.milestones.has("yard_course"), "first finish remembered")
	check(s.storage.load_pet().pet.milestones.has("yard_course"), "memory survives reload")
	check(s.pet.needs.energy == 85, "round plus training energy paid once")
	s.free()
	s = game()
	check(s.course.start(s), "retry course starts")
	reach_podium(s)
	check(s.course.stay(s, false, 1), "unguided trial allowed")
	s.course.advance(s, 2.5)
	check(s.course.phase == "stay_ready" and not s.pet.milestones.has("yard_course"), "failed command does not award finish")
	check(s.course.stay(s), "guided retry")
	s.course.advance(s, 2.5)
	s.course.advance(s, 5)
	check(s.course.phase == "stay_ready" and s.pet.skills.stay.successes == 0, "late praise earns nothing")
	s.suspend_session()
	check(not s.course.active() and not s.in_yard, "background clears course")
	s.free()
	s = game()
	s.pet.skills.sit.mastery = 0
	check(not s.course.start(s) and s.last_message.contains("Siad"), "locked stay is explained")
	s.pet.skills.sit.mastery = 100
	check(s.course.start(s), "unlocked course")
	s.local_clock = func(): return 100 * 86400.0 + 23 * 3600
	s.course.advance(s, 0.1)
	check(not s.course.active(), "night ends course safely")
	s.free()
	s = game()
	s.course.start(s)
	reach_podium(s)
	s.course.stay(s)
	s.course.advance(s, 2.5)
	before = s.pet.to_dict()
	s.storage = SaveSystem.new("/dev/null/blocked.json")
	check(not s.course.praise(s), "save failure rejects reward")
	check(s.pet.skills == before.skills and s.pet.bond == before.bond and not s.pet.milestones.has("yard_course"), "failed reward rolls back progress")
	check(not s.course.active(), "failed reward cannot be claimed twice")
	s.free()
	var jump := PuppyJump.new()
	jump.start(Vector2.ZERO, Vector2(120, 0))
	check(jump.sample().lift == 0 and jump.sample().clip == "play_bow", "jump anticipation on ground")
	jump.advance(0.7)
	check(is_equal_approx(jump.sample().lift, 60) and is_equal_approx(jump.sample().point.x, 60), "jump apex clears fence")
	check(jump.advance(1) and is_equal_approx(jump.sample().lift, 0) and jump.sample().point == Vector2(120, 0), "jump lands at target")
	jump.cancel()
	check(not jump.active(), "jump cancellation")
	print("COURSE RESULTS: %d passed, %d failed" % [passed, failed])
	quit(1 if failed else 0)

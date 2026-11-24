extends SceneTree
class FailingSave extends SaveSystem:
	func save_pet(_pet: PetState) -> bool:
		return false

var passed := 0
var failed := 0
var directory := ""

func check(ok: bool, message: String) -> void:
	if ok: passed += 1
	else:
		failed += 1
		push_error(message)

func _initialize() -> void:
	directory = preload("res://tests/helper_paths.gd").data_root().path_join("wellbeing-%d" % Time.get_ticks_usec())
	DirAccess.make_dir_recursive_absolute(directory)
	for pair in [[0, 0], [34.99, 0], [35, 1], [54.99, 1], [55, 2], [74.99, 2], [75, 3], [100, 3]]:
		check(WellbeingSystem.state(pair[0]) == pair[1], "emotion threshold " + str(pair))
	_test_absence()
	_test_gestures()
	_test_session()
	_test_gloria()
	print("WELLBEING RESULTS: %d passed, %d failed" % [passed, failed])
	quit(1 if failed else 0)

func _test_absence() -> void:
	for away in [60.0, 4 * 3600.0, 8 * 3600.0, 7 * 86400.0, -3600.0]:
		var pet := PetState.create(42, 1000000)
		var wellbeing := WellbeingSystem.new()
		wellbeing.begin(pet)
		wellbeing.add_joy("ball", 12)
		var score := wellbeing.score()
		var joy := wellbeing.joy
		NeedsSystem.catch_up_rhythm(pet, 1000000 + away, 100 * 86400.0 + 12 * 3600.0)
		var after_catchup := pet.to_dict()
		wellbeing.returned(pet, maxf(0, away))
		check(wellbeing.score() >= score and wellbeing.joy == joy, "absence or clock rollback never reduces emotion: " + str(away))
		check(pet.to_dict() == after_catchup, "protection never rewrites the actual pet")
		wellbeing.observe(pet)
		wellbeing.advance(61, true)
		wellbeing.observe(pet)
		check(WellbeingSystem.state(wellbeing.score()) == 3, "no deferred sadness when greeting ends")
		var restarted := WellbeingSystem.new()
		restarted.begin(pet, maxf(0, away))
		check(WellbeingSystem.state(restarted.score()) == 3, "cold launch is always welcoming")
	var pet := PetState.create(42)
	var wellbeing := WellbeingSystem.new()
	wellbeing.begin(pet)
	wellbeing.add_joy("tug", 12)
	var score := wellbeing.score()
	NeedsSystem.advance_sleep(pet, 18 * 3600)
	wellbeing.observe(pet, false)
	wellbeing.advance(18 * 3600, false)
	check(wellbeing.score() >= score and wellbeing.joy == 12, "sleep cannot worsen wellbeing or consume joy")
	wellbeing.advance(1200, true)
	check(is_equal_approx(wellbeing.joy, 6), "joy halves after twenty awake foreground minutes")
	var first := wellbeing.joy
	wellbeing.add_joy("ball", 6)
	wellbeing.add_joy("ball", 6)
	check(is_equal_approx(wellbeing.joy, first + 6), "click repetition cannot farm joy")
	wellbeing.advance(30, true)
	first = wellbeing.joy
	wellbeing.add_joy("ball", 6)
	check(is_equal_approx(wellbeing.joy, first + 3), "same activity has diminishing joy")
	for key in wellbeing.parts: wellbeing.parts[key] = 10.0
	wellbeing.joy = 0
	wellbeing.comfort()
	check(WellbeingSystem.state(wellbeing.score()) == 2, "one cuddle comforts even a very sad dog")
	wellbeing.begin(pet)
	first = wellbeing.score()
	NeedsSystem.change(pet, {"contact": -10})
	wellbeing.observe(pet)
	check(wellbeing.score() < first, "foreground need changes affect emotion")
	NeedsSystem.change(pet, {"contact": 15})
	wellbeing.observe(pet)
	check(wellbeing.score() > first, "care has immediate emotional effect")

func stroke(model: CuddleSystem, seconds: float = 20) -> void:
	model.press(Vector2(0.30, 0.60))
	for index in int(seconds / 0.05):
		model.advance(0.05)
		var x := 0.30 + (1 - absf(fmod((index + 1) * 0.05, 4.0) - 2) / 2) * 0.30
		model.move(Vector2(x, 0.60))
		if model.phase != "stroke": break
	model.release()

func favorite_strokes(model: CuddleSystem) -> void:
	var center: Vector2 = CuddleSystem.SPOTS[model.favorite]
	model.press(center + Vector2(0.03, 0))
	for index in 50:
		model.advance(0.05)
		model.move(center + Vector2.from_angle((index + 1) * 0.2) * 0.03)
	model.release()

func _test_gestures() -> void:
	var model := CuddleSystem.new()
	model.start(1, false)
	model.press(Vector2(0.4, 0.6))
	model.advance(100)
	model.move(Vector2(0.41, 0.6))
	check(model.calm == 0, "holding and delayed movement earn nothing")
	model.advance(0.01)
	model.move(Vector2(0.6, 0.6))
	check(model.calm == 0 and model.reaction == "head_tilt_stand", "fast swipe asks gently to slow down")
	model.release(Vector2.ZERO, true)
	model.move(Vector2(0.4, 0.6))
	check(model.calm == 0 and not model.held, "cancelled finger cannot continue scoring")
	model.start(1, false)
	stroke(model)
	check(model.phase == "find", "smooth real movement advances to finding favorite spot")
	model.press(CuddleSystem.SPOTS[0])
	for index in 60:
		model.advance(0.05)
		model.move(CuddleSystem.SPOTS[0] + Vector2.from_angle(index * 0.2) * 0.03)
	model.release()
	check(model.favorite_time == 0, "wrong spot cannot complete ritual")
	favorite_strokes(model)
	check(model.phase == "result", "favorite gentle circular strokes complete ritual")
	check(model.elapsed < 30, "normal ritual takes about twenty seconds of attention")
	model.start(1, true)
	stroke(model)
	favorite_strokes(model)
	check(model.phase == "result" and model.elapsed < 12, "reunion ritual is shorter")

func game() -> GameSession:
	var result := GameSession.new()
	result.pet = PetState.create(42)
	result.local_clock = func(): return 100 * 86400.0 + 12 * 3600
	result.storage = SaveSystem.new(directory.path_join("pet.json"))
	result.wellbeing.begin(result.pet)
	result.active = true
	return result

func _test_session() -> void:
	var session := game()
	var original := session.pet.to_dict()
	check(session.start_cuddle(), "cuddle can start while awake")
	session.cuddle_press(Vector2(0.4, 0.6))
	session.suspend_session()
	check(session.cuddle.phase == "idle" and not session.pet.milestones.has("cuddle_favorite"), "background cancels ritual without reward")
	check(session.pet.skills == original.skills and session.pet.bond == original.bond, "cancellation preserves progress")
	session.pet.last_seen_at -= 8 * 3600
	session.resume_session()
	check(session.wellbeing.reunion_left == 60 and session.wellbeing.label() == "Stęskniona", "real resume arms a welcoming reunion")
	check(session.start_cuddle() and session.cuddle.shortened, "reunion offers short cuddle")
	stroke(session.cuddle)
	favorite_strokes(session.cuddle)
	session.cuddle_move(Vector2.ZERO)
	check(session.pet.milestones.has("cuddle_favorite") and session.wellbeing.reunion_left == 0, "completion saves discovery and consumes reunion once")
	var saved := session.pet.to_dict()
	session.cuddle_move(Vector2.ZERO)
	check(session.pet.to_dict() == saved, "completion is settled once")
	var restored := session.storage.load_pet()
	check(restored.pet.milestones.has("cuddle_favorite") and WellbeingSystem.favorite(restored.pet) == WellbeingSystem.favorite(session.pet), "favorite and discovery survive restart in v17")
	for key in ["skills", "bond", "bond_progress", "photos", "decor", "personality_seed", "traits", "exploration", "adventure"]:
		check(session.pet.to_dict()[key] == original[key], "cuddle preserves " + key)
	session.cancel_cuddle()
	session.pet.resting = true
	check(not session.start_cuddle(), "cuddle never wakes sleeping dog")
	session.pet.resting = false
	session.start_cuddle()
	session.local_clock = func(): return 100 * 86400.0 + 13 * 3600
	session._tick_rhythm(0.1)
	check(not session.cuddle.running(), "scheduled sleep can interrupt cuddle")
	session.free()
	var failed_save := game()
	failed_save.storage = FailingSave.new(directory.path_join("failing.json"))
	original = failed_save.pet.to_dict()
	failed_save.start_cuddle()
	stroke(failed_save.cuddle)
	favorite_strokes(failed_save.cuddle)
	failed_save.cuddle_move(Vector2.ZERO)
	check(failed_save.pet.to_dict() == original, "failed save rolls back every pet field")
	check(not failed_save.pet.milestones.has("cuddle_favorite"), "failed save does not announce a discovery")
	failed_save.free()

func _test_gloria() -> void:
	var source := OS.get_environment("YUFRIEND_GLORIA_FIXTURE")
	if source.is_empty(): return
	var original: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(source))
	var path := directory.path_join("gloria-copy.json")
	DirAccess.copy_absolute(source, path)
	var storage := SaveSystem.new(path)
	var loaded := storage.load_pet()
	check(loaded.writable and loaded.pet.pet_name == "Gloria", "real Gloria copy loads")
	check(storage.save_pet(loaded.pet), "real Gloria copy saves")
	var restored := storage.load_pet()
	check(JSON.parse_string(JSON.stringify(restored.pet.to_dict())) == original.pet, "all real Gloria fields survive round trip unchanged")
	check(SaveSystem.VERSION == 17, "save schema remains v17")
	var wellbeing := WellbeingSystem.new()
	wellbeing.begin(restored.pet, 7 * 86400)
	wellbeing.advance(61, true)
	check(JSON.parse_string(JSON.stringify(restored.pet.to_dict())) == original.pet and WellbeingSystem.state(wellbeing.score()) == 3, "wellbeing leaves Gloria entirely unchanged after a week away")

extends SceneTree
var passed := 0
var failed := 0
var now := 100 * 86400.0 + 12 * 3600
func check(ok: bool, label: String) -> void:
	if ok: passed += 1
	else:
		failed += 1
		push_error(label)
func _initialize() -> void:
	var pet := PetState.create(42)
	pet.skills.sit.mastery = 100
	pet.bond = 20
	var skills := pet.skills.duplicate(true)
	PracticeSystem.sync(pet, now)
	check(PracticeSystem.form(pet, "sit") == 100, "upgrade starts at full form")
	var targets: Array = pet.practice.targets.duplicate()
	pet.skills.lie.mastery = 100
	check(not PracticeSystem.sync(pet, now) and pet.practice.targets == targets, "unlock does not replace today's targets")
	pet.skills = skills.duplicate(true)
	PracticeSystem.sync(pet, now + 86400)
	check(PracticeSystem.form(pet, "sit") == 100, "initial day is grace period")
	PracticeSystem.sync(pet, now + 2 * 86400)
	check(PracticeSystem.form(pet, "sit") == 90, "one full missed day lowers form ten points")
	check(pet.skills == skills, "form decline never removes mastery or attempts")
	PracticeSystem.record(pet, "sit", now + 2 * 86400)
	check(PracticeSystem.form(pet, "sit") == 100, "rewarded practice restores form")
	PracticeSystem.sync(pet, now + 3 * 86400)
	check(PracticeSystem.form(pet, "sit") == 100, "yesterday's practice protects form")
	PracticeSystem.sync(pet, now + 30 * 86400)
	check(PracticeSystem.form(pet, "sit") == 50, "long absence has a fifty percent floor")
	PracticeSystem.record(pet, "sit", now + 30 * 86400)
	check(PracticeSystem.form(pet, "sit") == 75, "one successful repetition restores 25 points")
	var low := TrainingSystem.new()
	low.begin(pet, "sit", true)
	var low_window := low.reward_duration
	pet.fatigue = 0
	PracticeSystem.record(pet, "sit", now + 30 * 86400)
	var full := TrainingSystem.new()
	full.begin(pet, "sit", true)
	check(is_equal_approx(full.reward_duration, low_window), "form preserves accessible reward window")
	pet = PetState.create(42)
	pet.skills.sit.mastery = 100
	pet.bond = 20
	PracticeSystem.sync(pet, now)
	var first: String = pet.practice.targets[0]
	check(not PracticeSystem.record(pet, first, now), "partial practice has no daily bonus")
	var restored := PetState.from_dict(pet.to_dict())
	check(restored != null and restored.practice.done == [first], "partial completion survives serialization")
	pet = restored
	var bonus_count := 0
	for key in pet.practice.targets.duplicate():
		if PracticeSystem.record(pet, key, now): bonus_count += 1
	check(bonus_count == 1 and pet.bond == 22 and pet.practice.streak == 1, "daily completion grants one bonus and first streak day")
	for key in pet.practice.targets.duplicate():
		check(not PracticeSystem.record(pet, key, now), "same-day repeat gives no extra daily bonus")
	pet = PetState.from_dict(pet.to_dict())
	check(not PracticeSystem.record(pet, first, now) and pet.bond == 22, "restart cannot repeat bonus")
	check(not PracticeSystem.sync(pet, now - 86400) and pet.practice.rewarded, "clock rollback cannot reset completion")
	PracticeSystem.sync(pet, now + 86400)
	for key in pet.practice.targets.duplicate(): PracticeSystem.record(pet, key, now + 86400)
	check(pet.practice.streak == 2 and pet.practice.total_days == 2, "consecutive daily completion grows streak")
	PracticeSystem.sync(pet, now + 3 * 86400)
	check(pet.practice.streak == 0, "missed day resets streak")
	for key in pet.practice.targets.duplicate(): PracticeSystem.record(pet, key, now + 3 * 86400)
	check(pet.practice.streak == 1 and pet.practice.total_days == 3, "new streak preserves total completed days")
	var game := GameSession.new()
	game.storage = SaveSystem.new("/tmp/yuf-practice-session-%s/pet.json" % Time.get_ticks_usec())
	game.pet = pet
	game.local_clock = func(): return now + 4 * 86400
	PracticeSystem.sync(pet, game._local_now())
	var before := pet.practice.duplicate(true)
	check(not game.give_reward("praise") and pet.practice == before, "reward outside a successful trial cannot count")
	game.training.begin(pet, "sit", true)
	game.training.advance(100)
	check(not game.give_reward("praise") and pet.practice == before, "expired reward cannot count")
	pet.fatigue = 0
	game.training.begin(pet, "sit", true)
	game.training.advance(game.training.time_left)
	check(game.give_reward("praise") and pet.practice.forms.sit.practiced_day == 104, "session records valid training reward")
	before = pet.practice.duplicate(true)
	check(not game.give_reward("praise") and pet.practice == before, "duplicate session reward cannot count")
	game.free()
	var legacy := pet.to_dict()
	legacy.erase("practice")
	var path := "/tmp/yuf-practice-%s/pet.json" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify({"schema_version": 8, "pet": legacy}))
	file.close()
	var store := SaveSystem.new(path)
	var loaded := store.load_pet()
	check(loaded.writable and loaded.pet.pet_id == pet.pet_id, "v8 migration keeps identity")
	var migrated: Dictionary = loaded.pet.to_dict()
	migrated.erase("practice")
	check(JSON.parse_string(JSON.stringify(migrated)) == JSON.parse_string(JSON.stringify(legacy)), "v8 migration preserves every previous field")
	check(FileAccess.file_exists(path + ".v8") and PracticeSystem.form(loaded.pet, "sit") == 100, "migration archives v8 and initializes form")
	check(store.save_pet(loaded.pet) and store.load_pet().pet != null, "new schema saves and reloads")
	print("PRACTICE RESULTS: %d passed, %d failed" % [passed, failed])
	quit(1 if failed else 0)

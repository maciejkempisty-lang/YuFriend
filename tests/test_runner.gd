extends SceneTree

var passed: int = 0
var failed: int = 0
var directory: String

func _initialize() -> void:
	directory = "user://qa-domain-%s" % Time.get_ticks_usec()
	_test_personality()
	_test_needs()
	_test_training()
	_test_saving()
	_test_commands()
	_cleanup()
	print("TEST RESULTS: %d passed, %d failed" % [passed, failed])
	quit(1 if failed > 0 else 0)

func check(condition: bool, label: String) -> void:
	if condition:
		passed += 1
		print("PASS " + label)
	else:
		failed += 1
		push_error("FAIL " + label)

func _test_personality() -> void:
	var first := PetState.create(42, 1000)
	var same := PetState.create(42, 1000)
	var other := PetState.create(62, 1000)
	check(first.traits == same.traits and first.favorite_reward == same.favorite_reward, "seed preserves personality")
	check(first.traits != other.traits, "different puppies have different traits")
	first.pet_name = "Łapek"
	first.skills.sit.mastery = 32.0
	var restored := PetState.from_dict(first.to_dict())
	check(restored != null and restored.pet_name == "Łapek" and restored.skills.sit.mastery == 32, "state roundtrip retains Polish name and learning")
	var data := first.to_dict()
	data.needs.energy = "full"
	check(PetState.from_dict(data) == null, "reject malformed needs")
	data = first.to_dict()
	data.skills.paw.mastery = NAN
	check(PetState.from_dict(data) == null, "reject nonfinite progress")
	data = first.to_dict()
	data.life_stage = "unknown"
	check(PetState.from_dict(data) == null, "reject unsupported life stage")
	check(not first.remember("welcome", "Duplicate", ""), "milestones are not duplicated")
	for index in 60:
		first.remember("event_%d" % index, "Event", "")
	check(first.journal.size() == 40, "journal has bounded storage")

func _test_needs() -> void:
	var pet := PetState.create(1, 10000)
	var initial := pet.needs.duplicate()
	NeedsSystem.advance(pet, -100)
	check(pet.needs == initial, "negative elapsed time does not alter needs")
	var elapsed := NeedsSystem.catch_up(pet, 9000)
	check(elapsed == 0 and pet.last_seen_at == 10000, "clock rollback does not rewind watermark")
	elapsed = NeedsSystem.catch_up(pet, 10000 + 86400 * 100)
	check(elapsed == NeedsSystem.MAX_OFFLINE_SECONDS, "absence capped at eight hours")
	check(pet.needs.fullness >= 15 and pet.needs.energy >= 15, "long absence has gentle lower bound")
	var bounded := PetState.create(1, 10000)
	NeedsSystem.catch_up(bounded, 10000 + int(NeedsSystem.MAX_OFFLINE_SECONDS))
	check(pet.needs == bounded.needs, "one long absence applies exactly capped simulation")
	pet.resting = true
	pet.needs.energy = 40.0
	pet.fatigue = 60.0
	NeedsSystem.advance(pet, 15)
	check(pet.needs.energy > 40 and pet.fatigue < 60, "rest restores energy and attention")
	NeedsSystem.change(pet, {"fullness": 1000, "energy": -1000})
	check(pet.needs.fullness == 100 and pet.needs.energy == 0, "effects clamp needs")

func _test_training() -> void:
	var pet := PetState.create(4, 1000)
	var train := TrainingSystem.new()
	check(not train.begin(pet, "paw", true).ok, "paw requires basic sit learning")
	check(train.begin(pet, "sit", true).ok, "guided unknown command can be demonstrated")
	check(not train.reward(pet, "praise").ok and pet.skills.sit.mastery == 0, "early reward does not grant progress")
	check(not train.begin(pet, "come", true).ok, "cannot overlap attempts")
	var event := train.advance(train.time_left + 0.1)
	check(event.event == "ready", "successful demonstration opens reward window")
	var result := train.reward(pet, pet.favorite_reward)
	check(result.ok and pet.skills.sit.mastery == 10, "timely favorite reward grants guided learning")
	var mastery: float = pet.skills.sit.mastery
	check(not train.reward(pet, "treat").ok and pet.skills.sit.mastery == mastery, "double reward cannot duplicate progress")
	train.begin(pet, "sit", true)
	train.advance(train.time_left + train.reward_duration + 1)
	check(train.phase == "idle" and not train.reward(pet, "praise").ok, "long frame cannot reopen expired reward window")
	check(pet.skills.sit.mastery == mastery, "unrewarded practice grants no mastery")
	train.begin(pet, "come", false, 0.999)
	event = train.advance(train.time_left + 0.1)
	check(event.event == "miss" and train.phase == "idle", "unguided failure closes attempt without reward")
	pet.fatigue = 0
	train.begin(pet, "sit", true)
	train.advance(train.time_left + 0.1)
	train.cancel()
	check(not train.reward(pet, "praise").ok, "interruption invalidates pending reward")
	pet.needs.energy = 10.0
	check(not train.begin(pet, "sit", true).ok, "low energy blocks training")
	pet.needs.energy = 80.0
	pet.fatigue = 90.0
	check(not train.begin(pet, "sit", true).ok, "fatigue asks for a break")
	pet.fatigue = 0
	pet.skills.sit.mastery = 30.0
	check(train.begin(pet, "paw", true).ok, "learned sit unlocks paw")
	train.advance(train.time_left + 0.1)
	check(not train.reward(pet, "invalid").ok and train.phase == "reward", "unknown reward does not consume legitimate opportunity")
	check(train.reward(pet, "praise").ok, "legitimate reward remains available")

func _test_saving() -> void:
	var store := SaveSystem.new(directory + "/pet.json")
	var loaded := store.load_pet()
	check(loaded.status == "new" and loaded.writable, "missing save creates new writable pet")
	var pet := PetState.create(9, 1000)
	pet.pet_name = "Bąbel"
	check(store.save_pet(pet), "first save succeeds")
	pet.skills.sit.mastery = 40.0
	check(store.save_pet(pet), "second atomic save succeeds")
	loaded = store.load_pet()
	check(loaded.pet.pet_name == "Bąbel" and loaded.pet.skills.sit.mastery == 40, "save reload retains current progress")
	var file := FileAccess.open(store.path, FileAccess.WRITE)
	file.store_string("broken JSON")
	file.close()
	loaded = store.load_pet()
	check(loaded.status == "recovered" and loaded.pet.pet_name == "Bąbel" and loaded.pet.skills.sit.mastery == 0, "corruption recovers last validated backup")
	check(store.save_pet(loaded.pet), "recovered state can be saved")
	file = FileAccess.open(store.path, FileAccess.WRITE)
	file.store_string(JSON.stringify({"schema_version": 99, "pet": pet.to_dict()}))
	file.close()
	loaded = store.load_pet()
	check(loaded.status == "unsupported" and not loaded.writable, "newer schema is not silently downgraded via backup")
	check(not store.save_pet(pet), "save refuses to overwrite newer schema")
	var blocker := FileAccess.open(directory + "/blocker", FileAccess.WRITE)
	blocker.store_string("not a directory")
	blocker.close()
	var invalid_path := SaveSystem.new(directory + "/blocker/pet.json")
	check(not invalid_path.save_pet(pet) and not invalid_path.last_error.is_empty(), "write failure is surfaced")

func _test_commands() -> void:
	check(LocalCommands.interpret("  USIĄDŹ!  ") == "sit", "Polish accents and punctuation")
	check(LocalCommands.interpret("Podaj łapę") == "paw", "paw alias")
	check(LocalCommands.interpret("do mnie") == "come", "come alias")
	check(LocalCommands.interpret("naucz się wszystkiego") == "", "unsupported command cannot bypass training")

func _cleanup() -> void:
	var absolute := ProjectSettings.globalize_path(directory)
	var dir := DirAccess.open(absolute)
	if dir != null:
		for file in dir.get_files(): DirAccess.remove_absolute(absolute.path_join(file))
		DirAccess.remove_absolute(absolute)

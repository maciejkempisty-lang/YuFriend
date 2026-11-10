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
	_test_habits()
	_test_personality_edges()
	_test_migration()
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

const DAY := 86400.0

func _fill(pet: PetState, day: int, hour: float, events: Dictionary) -> void:
	for key in events:
		for index in events[key]:
			PersonalitySystem.record(pet, key, day * DAY + hour * 3600.0)

func _test_habits() -> void:
	check(PersonalitySystem.part_of(6 * 3600.0) == "morning" and PersonalitySystem.part_of(19 * 3600.0) == "evening" and PersonalitySystem.part_of(2 * 3600.0) == "night", "day parts follow local hours")
	var pet := PetState.create(7, 1000)
	check(pet.traits == PetState.base_traits(7), "birth traits are reproducible from the seed")
	PersonalitySystem.record(pet, "unknown", 100 * DAY)
	check(pet.history.is_empty(), "unknown events are not recorded")
	_fill(pet, 100, 19, {"pet": 5, "play": 4, "feed": 1, "train_guided": 2, "reward_praise": 2})
	check(pet.history.size() == 1 and pet.history[0].events.pet == 5 and pet.history[0].parts.evening == 14, "events are counted per day and day part")
	var before := pet.traits.duplicate()
	check(PersonalitySystem.reflect(pet, 100 * DAY + 20 * 3600.0).is_empty() and pet.traits == before, "an unfinished day changes nothing")
	var notes := PersonalitySystem.reflect(pet, 101 * DAY + 8 * 3600.0, 2000)
	check(pet.traits.sociability > before.sociability and pet.traits.patience > before.patience and pet.traits.curiosity > before.curiosity, "a day of contact, play and timely rewards shifts traits")
	check(absf(pet.traits.sociability - before.sociability) <= PersonalitySystem.MAX_STEP + 0.0001, "daily drift is small")
	check(not notes.is_empty() and pet.milestones.has("trait_sociability_up") and pet.habits.is_empty(), "drift is explained in memories; one day is not yet a habit")
	var after := pet.traits.duplicate()
	check(PersonalitySystem.reflect(pet, 101 * DAY + 9 * 3600.0).is_empty() and pet.traits == after, "a day is reflected only once")
	_fill(pet, 101, 19, {"pet": 5, "play": 4, "feed": 1})
	PersonalitySystem.reflect(pet, 102 * DAY + 8 * 3600.0, 3000)
	check(pet.habits.has("cuddler") and pet.habits.has("playful") and pet.habits.has("time_evening") and not pet.habits.has("student"), "repeated patterns on two days become habits")
	check(pet.milestones.has("habit_cuddler") and PersonalitySystem.habit_labels(pet).has("Przytulas"), "new habit is named and remembered")
	var restored := PetState.from_dict(pet.to_dict())
	check(restored != null and restored.habits == pet.habits and restored.history.size() == 2 and restored.reflected_day == 101, "personality data survives a roundtrip")
	PersonalitySystem.reflect(pet, 160 * DAY, 4000)
	check(pet.habits.has("cuddler") and pet.traits == restored.traits, "long absence removes neither habits nor traits")
	_fill(pet, 160, 8, {"feed": 2})
	_fill(pet, 161, 8, {"feed": 2})
	PersonalitySystem.reflect(pet, 162 * DAY, 5000)
	check(not pet.habits.has("cuddler") and not pet.habits.has("time_evening"), "habits fade when the pattern is gone on active days")
	var drifter := PetState.create(7, 1000)
	for day in 40:
		_fill(drifter, 200 + day, 12, {"pet": 4})
		PersonalitySystem.reflect(drifter, (201 + day) * DAY)
	var base := PetState.base_traits(7)
	check(drifter.traits.sociability <= minf(0.95, base.sociability + PersonalitySystem.MAX_DRIFT) + 0.0001 and drifter.traits.sociability > base.sociability + 0.1, "drift is bounded around birth traits")
	check(drifter.history.size() == PetState.MAX_HISTORY_DAYS, "event history has bounded storage")
	var guarded := PetState.create(7, 1000)
	PersonalitySystem.apply(guarded, {"trait_deltas": {"patience": 5.0, "curiosity": "a lot"}, "habits": ["cuddler", "fly", "time_morning", "time_night", 7],
		"notes": [{"key": "x", "title": "", "detail": "pusty"}, "tekst"]}, 300)
	check(absf(guarded.traits.patience - base.patience - PersonalitySystem.MAX_STEP) < 0.0001 and guarded.traits.curiosity == base.curiosity, "untrusted proposal is clamped")
	check(guarded.habits == ["cuddler", "time_morning"] and not guarded.milestones.has("x"), "untrusted proposal cannot add unknown habits or malformed notes")
	check(PetState.from_dict(guarded.to_dict()) != null, "state after an untrusted proposal is still valid")
	var data := guarded.to_dict()
	data.habits = ["fly"]
	check(PetState.from_dict(data) == null, "reject unknown habit in save")
	data = guarded.to_dict()
	data.history = [{"day": 1, "events": {"pet": -1}, "parts": {}}]
	check(PetState.from_dict(data) == null, "reject malformed event history")
	var summary := PersonalitySystem.summary(pet, 162)
	check(not summary.has("pet_name") and not summary.has("pet_id") and summary.days.size() == 2, "AI context carries no identity")

func _test_personality_edges() -> void:
	var absentee := PetState.create(7, 1000)
	_fill(absentee, 300, 19, {"pet": 4})
	_fill(absentee, 301, 19, {"pet": 4})
	PersonalitySystem.reflect(absentee, 302 * DAY)
	_fill(absentee, 302, 8, {"feed": 1})
	_fill(absentee, 303, 8, {"feed": 1})
	var delayed := PetState.from_dict(absentee.to_dict())
	PersonalitySystem.reflect(absentee, 304 * DAY)
	var habits := absentee.habits.duplicate()
	PersonalitySystem.reflect(absentee, 309 * DAY)
	check(habits.has("cuddler") and absentee.habits == habits, "aging the seven-day window during absence does not remove a habit")
	PersonalitySystem.reflect(delayed, 309 * DAY)
	check(delayed.habits == habits, "returning late evaluates pending activity as of its last day")
	var single_evening := PetState.create(7, 1000)
	_fill(single_evening, 400, 19, {"pet": 16})
	_fill(single_evening, 401, 8, {"feed": 1})
	PersonalitySystem.reflect(single_evening, 402 * DAY)
	check(not single_evening.habits.has("time_evening"), "a time-of-day habit needs that pattern on two days")
	var guarded := PetState.create(7, 1000)
	var proposal := {"trait_deltas": {"patience": 0.06}}
	PersonalitySystem.apply(guarded, proposal, 500)
	var patience: float = guarded.traits.patience
	PersonalitySystem.apply(guarded, proposal, 500)
	check(guarded.traits.patience == patience, "a repeated proposal cannot change the same day twice")
	for index in 199: guarded.remember("filled_%d" % index, "Event", "")
	PersonalitySystem.apply(guarded, {"notes": [{"key": "extra", "title": "Event", "detail": "Detail"}]}, 501)
	check(PetState.from_dict(guarded.to_dict()) != null and not guarded.milestones.has("extra"), "proposal notes cannot overflow the persistent milestone limit")

func _test_migration() -> void:
	var store := SaveSystem.new(directory + "/old/pet.json")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory + "/old"))
	var old := PetState.create(11, 1000)
	old.pet_name = "Stary"
	old.skills.sit.mastery = 55.0
	var data := old.to_dict()
	for field in ["history", "habits", "reflected_day"]: data.erase(field)
	var file := FileAccess.open(store.path, FileAccess.WRITE)
	file.store_string(JSON.stringify({"schema_version": 1, "pet": data}))
	file.close()
	var loaded := store.load_pet()
	check(loaded.status == "loaded" and loaded.writable and loaded.pet.pet_name == "Stary" and loaded.pet.skills.sit.mastery == 55 and absf(loaded.pet.traits.patience - old.traits.patience) < 0.0001, "version 1 save is migrated without losing the puppy")
	check(loaded.pet.history.is_empty() and loaded.pet.habits.is_empty(), "migrated puppy starts with empty personality history")
	check(FileAccess.file_exists(store.path + ".v1"), "original version 1 file is kept")
	check(store.save_pet(loaded.pet) and store.load_pet().pet.pet_name == "Stary", "migrated puppy saves in the current schema")
	var parsed: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(store.path))
	check(parsed.schema_version == SaveSystem.VERSION and parsed.pet.has("history"), "saved file uses schema version 2")
	var example: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://docs/przyklady/zapis-v2.json"))
	check(example.schema_version == SaveSystem.VERSION and PetState.from_dict(example.pet) != null, "documented example save is valid")
	var legacy := JSON.stringify({"schema_version": 1, "pet": data})
	var recovered := SaveSystem.new(directory + "/old/recovered.json")
	file = FileAccess.open(recovered.path + ".bak", FileAccess.WRITE)
	file.store_string(legacy)
	file.close()
	var recovery := recovered.load_pet()
	var recovered_saves := recovered.save_pet(recovery.pet) and recovered.save_pet(recovery.pet)
	check(recovery.status == "recovered" and recovered_saves and FileAccess.file_exists(recovered.path + ".v1") and FileAccess.get_file_as_string(recovered.path + ".v1") == legacy, "legacy recovery backup survives subsequent backup rotation")
	var blocked := SaveSystem.new(directory + "/old/blocked.json")
	file = FileAccess.open(blocked.path, FileAccess.WRITE)
	file.store_string(legacy)
	file.close()
	var blocker := ProjectSettings.globalize_path(blocked.path + ".v1")
	DirAccess.make_dir_recursive_absolute(blocker)
	var blocked_load := blocked.load_pet()
	check(not blocked_load.writable and FileAccess.get_file_as_string(blocked.path) == legacy, "failed legacy snapshot blocks migration without changing the original")
	check(not blocked.save_pet(blocked_load.pet) and FileAccess.get_file_as_string(blocked.path) == legacy, "direct save cannot bypass a failed legacy snapshot")
	DirAccess.remove_absolute(blocker)
	var absolute := ProjectSettings.globalize_path(directory + "/old")
	for name in DirAccess.get_files_at(absolute): DirAccess.remove_absolute(absolute.path_join(name))
	DirAccess.remove_absolute(absolute)

func _cleanup() -> void:
	var absolute := ProjectSettings.globalize_path(directory)
	var dir := DirAccess.open(absolute)
	if dir != null:
		for file in dir.get_files(): DirAccess.remove_absolute(absolute.path_join(file))
		DirAccess.remove_absolute(absolute)

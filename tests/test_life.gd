extends SceneTree

var passed := 0
var failed := 0
var directory: String

func _initialize() -> void:
	var test_root := OS.get_environment("YUFRIEND_TEST_ROOT")
	directory = ("user://" if test_root.is_empty() else test_root).path_join("qa-life-%s" % Time.get_ticks_usec())
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	_test_quirks()
	_test_mood()
	_test_reports()
	_test_migration_and_resume()
	for file in DirAccess.get_files_at(directory): DirAccess.remove_absolute(directory.path_join(file))
	DirAccess.remove_absolute(directory)
	print("LIFE RESULTS: %d passed, %d failed" % [passed, failed])
	quit(1 if failed else 0)

func check(condition: bool, label: String) -> void:
	if condition:
		passed += 1
		print("PASS " + label)
	else:
		failed += 1
		push_error("FAIL " + label)

func _test_quirks() -> void:
	var pet := PetState.create(42, 1000)
	check(pet.life == PetState.create(42, 1000).life, "birth quirks are deterministic")
	var variants: Dictionary = {}
	var valid := true
	for seed_value in range(1, 100):
		var candidate := PetState.create(seed_value, 1000)
		valid = valid and PetState.valid_life(candidate.life)
		variants[str(candidate.life.quirks)] = true
	check(valid and variants.size() > 20, "different seeds give two or three unique quirks from the catalog")
	check(LifeSystem.quirk_lines(pet).count("Jeszcze nieznane") == pet.life.quirks.size(), "new profile hides all quirks")
	var id: String = pet.life.quirks[0]
	var event: String = LifeSystem.QUIRKS[id].event
	LifeSystem.observe(pet, "unknown", 1010)
	check(pet.life.observations.is_empty(), "unrelated actions do not reveal quirks")
	LifeSystem.observe(pet, event, 1020)
	LifeSystem.observe(pet, event, 1030)
	check(pet.life.discovered.is_empty(), "two observations keep the discovery hidden")
	LifeSystem.observe(pet, event, 1040)
	check(pet.life.discovered.has(id) and pet.milestones.has("quirk_" + id), "third observation discovers and remembers a quirk")
	var count := pet.journal.size()
	LifeSystem.observe(pet, event, 1050)
	check(pet.journal.size() == count, "rediscovery cannot duplicate the memory")
	var restored := PetState.from_dict(pet.to_dict())
	check(restored != null and restored.life == pet.life, "discoveries and progress survive reload")
	var full := PetState.create(42, 1000)
	for index in 199: full.remember("full_%d" % index, "Event", "", 1000)
	for index in 3: LifeSystem.observe(full, event, 1040)
	check(full.life.discovered.has(id) and full.journal[0].key.begins_with("quirk_") and PetState.from_dict(full.to_dict()) != null, "a full legacy milestone list still permits a discovery in the album")
	for mutation in ["duplicate", "foreign_discovery", "unknown_mood", "huge_count", "bad_report", "missing"]:
		var data := pet.to_dict()
		match mutation:
			"duplicate": data.life.quirks = [id, id]
			"foreign_discovery": data.life.discovered = ["not_a_quirk"]
			"unknown_mood": data.life.mood = "angry"
			"huge_count": data.life.observations[id] = INF
			"bad_report": data.life.away_report = {"from": 100, "until": 99, "events": ["a", "b"]}
			"missing": data.erase("life")
		check(PetState.from_dict(data) == null, "malformed life state is rejected: " + mutation)

func _test_mood() -> void:
	var pet := PetState.create(42, 1000)
	pet.history = [{"day": 99, "events": {"play": 5}, "parts": {}}, {"day": 100, "events": {"pet": 10}, "parts": {}}]
	check(LifeSystem.refresh_mood(pet, 100 * 86400 + 5 * 3600) and pet.life.mood == "playful", "morning mood uses yesterday and ignores today's actions")
	var mood := pet.life.duplicate(true)
	check(not LifeSystem.refresh_mood(pet, 101 * 86400 + 4 * 3600) and pet.life == mood, "mood stays fixed through the night before 05:00")
	check(not LifeSystem.refresh_mood(pet, 98 * 86400) and pet.life == mood, "clock rollback does not reroll mood")
	check(LifeSystem.refresh_mood(pet, 101 * 86400 + 5 * 3600) and pet.life.mood == "cuddly", "the next morning reflects yesterday's contact")
	var restored := PetState.from_dict(pet.to_dict())
	check(not LifeSystem.refresh_mood(restored, 101 * 86400 + 6 * 3600) and restored.life == pet.life, "restart does not reroll the daily mood")
	var needs := pet.needs.duplicate()
	var bond := pet.bond
	LifeSystem.refresh_mood(pet, 200 * 86400)
	check(pet.needs == needs and pet.bond == bond, "missing days do not incur mood penalties")
	pet.life.mood = "sleepy"
	var slow := LifeSystem.walk_speed(pet)
	pet.life.mood = "playful"
	check(slow < 1 and LifeSystem.walk_speed(pet) > 1, "mood changes walking pace")
	var counts := {}
	for seed_value in range(1, 401):
		var candidate := PetState.create(seed_value, 1000)
		LifeSystem.refresh_mood(candidate, 100 * 86400 + 5 * 3600)
		counts[candidate.life.mood] = int(counts.get(candidate.life.mood, 0)) + 1
	print("MOOD DISTRIBUTION: ", counts)
	check(int(counts.get("sleepy", 0)) >= 20 and counts.size() == 5, "sleepy mood occurs naturally across four hundred new dogs")
	var game := GameSession.new()
	game.local_clock = func(): return 100 * 86400.0 + 12 * 3600.0
	game.pet = PetState.create(42)
	game.active = true
	game._save_left = 25
	game._process(0.2)
	check(game.pet.life.mood_day >= 0, "an active tick computes morning mood independently of the autosave interval")
	game.free()

func _test_reports() -> void:
	var pet := PetState.create(42, 1000)
	var before := pet.to_dict()
	check(not LifeSystem.report_away(pet, 1000, 2799, false), "short app switches do not create reports")
	check(LifeSystem.report_away(pet, 1000, 2800, false) and pet.life.away_report.events.size() == 2, "half an hour produces two events")
	check(pet.needs == before.needs and pet.bond == before.bond and pet.skills == before.skills and pet.history == before.history and pet.traits == before.traits, "offline stories invent no player activity or rewards")
	var same := PetState.create(42, 1000)
	LifeSystem.report_away(same, 1000, 2800, false)
	check(same.life.away_report == pet.life.away_report, "same interval has a reproducible story")
	var count := pet.journal.size()
	check(not LifeSystem.report_away(pet, 1000, 2800, false) and pet.journal.size() == count, "same interval cannot duplicate the report")
	check(not LifeSystem.report_away(pet, 2000, 4000, false), "overlapping interval cannot replay offline time")
	check(not LifeSystem.report_away(pet, 3000, 1000, false), "clock rollback creates no away report")
	check(LifeSystem.report_away(pet, 2800, 2800 + 3 * 86400, false) and pet.life.away_report.events.size() == 3, "long absence produces at most three events")
	var rested := PetState.create(42, 1000)
	rested.resting = true
	LifeSystem.report_away(rested, 1000, 2800, true)
	check(rested.life.away_report.events[0].contains("drzemce") and rested.life.observations.is_empty(), "a sleeping dog does not perform an awake quirk")
	pet.remember("first_sit", "Pierwsze Siad", "Ćwiczenie", 3000)
	var milestones := pet.milestones.size()
	for index in 60:
		var from := 1000000.0 + index * 3600
		LifeSystem.report_away(pet, from, from + 3600, false)
	check(pet.journal.size() == PetState.MAX_RECENT_ENTRIES + milestones and pet.milestones.size() == milestones and PetState.from_dict(pet.to_dict()) != null, "repeated reports stay bounded without filling milestone storage")
	check(pet.life.discovered.is_empty() and pet.life.observations.is_empty(), "sixty returns never discover quirks or increment observations")
	var store := SaveSystem.new(directory.path_join("album.json"))
	check(store.save_pet(pet), "expanded album saves successfully")
	var restored: PetState = store.load_pet().pet
	var keys: Array = []
	for entry in restored.journal: keys.append(entry.key)
	check(keys.has("welcome") and keys.has("first_sit") and keys.has("away_1216000") and not keys.has("away_1003600"), "reload retains first day and first sit while rotating oldest reports")
	check(LifeSystem.greeting(pet, 3600).clip == "tail_wag_stand" and LifeSystem.greeting(pet, 3 * 86400).clip == "head_tilt_stand", "hour and three-day absences get different greetings")

func _test_migration_and_resume() -> void:
	var legacy: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://docs/przyklady/zapis-v2.json"))
	var raw := JSON.stringify(legacy)
	var path := directory.path_join("legacy.json")
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(raw)
	file.close()
	var store := SaveSystem.new(path)
	var loaded := store.load_pet()
	var same_skills := true
	for key in PetState.TRICK_KEYS:
		for field in ["mastery", "attempts", "successes"]:
			same_skills = same_skills and loaded.pet.skills[key][field] == legacy.pet.skills[key][field]
	check(loaded.writable and loaded.pet.pet_id == legacy.pet.pet_id and same_skills, "v2 migration keeps identity and training")
	check(FileAccess.get_file_as_string(path + ".v2") == raw, "v2 original is preserved byte-for-byte")
	check(loaded.pet.life == PetState.initial_life(int(legacy.pet.personality_seed)) and store.save_pet(loaded.pet), "v2 gets deterministic hidden quirks and saves in the current schema")
	var broken := FileAccess.open(path, FileAccess.WRITE)
	broken.store_string("broken")
	broken.close()
	loaded = store.load_pet()
	check(loaded.status == "recovered" and loaded.pet.pet_id == legacy.pet.pet_id and store.save_pet(loaded.pet), "v2 recovery backup migrates safely")
	var pet := PetState.create(42, Time.get_unix_time_from_system() - 4 * 86400)
	pet.pet_name = "Gloria"
	var session_path := directory.path_join("session.json")
	SaveSystem.new(session_path).save_pet(pet)
	var game := GameSession.new()
	game.local_clock = func(): return 100 * 86400.0 + 12 * 3600.0
	var reports: Array = []
	game.away_report_ready.connect(func(): reports.append(true))
	game.start(session_path)
	check(reports.size() == 1 and game.last_message.contains("spokojnie Cię obwąchuje"), "startup keeps the real absence length beyond the eight-hour need cap")
	check(game.pet.pet_id == pet.pet_id and game.pet.bond == pet.bond and game.pet.skills == pet.skills, "long return preserves the same dog, bond and skills")
	game.suspend_session()
	game.resume_session()
	check(reports.size() == 1, "immediate resume does not show the report twice")
	game.suspend_session()
	game.pet.last_seen_at = Time.get_unix_time_from_system() - 3600
	game.pet.life.away_report = {}
	game.resume_session()
	check(reports.size() == 2 and game.pet.life.away_report.events.size() == 2, "resume records and presents a new elapsed interval")
	game.free()

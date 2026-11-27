extends SceneTree
var passed := 0
var failed := 0
func check(ok: bool, label: String) -> void:
	if ok: passed += 1
	else:
		failed += 1
		push_error(label)
func _initialize() -> void:
	var pet := PetState.create(42)
	PracticeSystem.sync(pet, 100 * 86400)
	PracticeSystem.sync(pet, 107 * 86400)
	check(PracticeSystem.form(pet, "roll") == 100 and pet.practice.forms.roll.value == 100, "locked trick does not decay")
	pet.skills.sit.mastery = 50
	PracticeSystem.sync(pet, 114 * 86400)
	check(PracticeSystem.form(pet, "sit") == 100, "learning trick does not decay")
	for key in PetState.TRICK_KEYS: pet.skills[key].mastery = 100
	pet.practice = PracticeSystem.initial()
	for day in range(200, 228):
		PracticeSystem.sync(pet, day * 86400)
		for key in pet.practice.targets.duplicate(): PracticeSystem.record(pet, key, day * 86400)
		var minimum := 100.0
		for key in PetState.TRICK_KEYS: minimum = minf(minimum, PracticeSystem.form(pet, key))
		check(minimum >= 80, "daily plan maintains healthy form day %d" % day)
	check(pet.practice.streak == 28, "daily streak survives full simulation")
	var training := TrainingSystem.new()
	pet.practice.forms.sit.value = 50
	pet.fatigue = 0
	training.begin(pet, "sit", false, 0.8)
	check(not training.will_succeed, "low form affects unassisted execution")
	training.cancel()
	pet.fatigue = 0
	pet.practice.forms.sit.value = 100
	training.begin(pet, "sit", false, 0.8)
	check(training.will_succeed, "same roll succeeds with full form")
	training.cancel()
	pet.fatigue = 0
	pet.practice.forms.sit.value = 50
	training.begin(pet, "sit", true, 0.99)
	check(training.will_succeed, "guidance remains reliable")
	training.cancel()
	pet.fatigue = 0
	pet.skills.sit.mastery = 95
	pet.practice.forms.sit.value = 50
	training.begin(pet, "sit", true)
	training.advance(training.time_left)
	training.reward(pet, "praise")
	check(pet.skills.sit.mastery == 100 and PracticeSystem.form(pet, "sit") == 100, "newly mastered trick starts at full form even with legacy low form")
	var session := GameSession.new()
	session.pet = PetState.create(52)
	session.active = true
	session.local_clock = func(): return 300 * 86400.0 + 12 * 3600
	session._brain_left = INF
	session.change_yard(true)
	var start_bond := session.pet.bond
	for i in 5:
		# Cooldown has its own regression; here force eligibility to test the daily cap through real settlement.
		session.pet.social.last_reward_at = 0
		session.throw_ball(Vector2(1100, 310), Vector2(700, 310))
		var token := session._approach_token
		session.arrive_at(token)
		session.catch_ball()
		session._process(YardFetch.PLAY_SECONDS + 0.1)
		session.finish_fetch_return(token)
		session._process(2)
	check(is_equal_approx(session.pet.bond - start_bond, 4.05), "session settlement honors total daily fetch bond budget")
	check(session.pet.fetch_rewards.precise == 3 and session.pet.social.games.ball == 5, "later rounds still count without extra bond")
	session.free()
	var total := 0.0
	for i in 20:
		var award := FetchRewards.award(pet, true, 300 * 86400)
		total += award.bond
		check(award.bonus == (i < 3), "only first three precise catches award bonus")
	check(is_equal_approx(total, 4.05), "twenty rewarded fetches capped at 4.05 bond")
	pet = PetState.from_dict(pet.to_dict())
	check(FetchRewards.award(pet, true, 300 * 86400).bond == 0, "restart preserves spent budget")
	check(FetchRewards.award(pet, true, 299 * 86400).bond == 0, "clock rollback cannot renew budget")
	check(is_equal_approx(FetchRewards.award(pet, true, 301 * 86400).bond, 1.35), "next day renews budget")
	var legacy := pet.to_dict()
	legacy.erase("fetch_rewards")
	var path := preload("res://tests/helper_paths.gd").data_root() + "/yuf-balance-%s/pet.json" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify({"schema_version": 10, "pet": legacy}))
	file.close()
	var store := SaveSystem.new(path)
	var loaded := store.load_pet()
	check(loaded.writable and FileAccess.file_exists(path + ".v10"), "migration archives original v10")
	var migrated: Dictionary = loaded.pet.to_dict()
	migrated.erase("fetch_rewards")
	check(JSON.parse_string(JSON.stringify(migrated)) == JSON.parse_string(JSON.stringify(legacy)), "migration preserves every old field")
	check(store.save_pet(loaded.pet) and store.load_pet().pet.fetch_rewards.base == 0, "new budget persists")
	print("BALANCE RESULTS: %d passed, %d failed" % [passed, failed])
	quit(1 if failed else 0)

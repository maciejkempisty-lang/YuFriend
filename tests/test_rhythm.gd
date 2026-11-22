extends SceneTree

var passed := 0
var failed := 0
var now := 100 * 86400.0 + 12 * 3600.0
var directory := preload("res://tests/helper_paths.gd").data_root() + "/yufriend-rhythm-%s" % Time.get_ticks_usec()

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(directory)
	_test_clock()
	_test_choices()
	_test_greetings_and_training()
	_test_night()
	_test_sequences()
	_test_yard_night()
	_test_save()
	for file in DirAccess.get_files_at(directory): DirAccess.remove_absolute(directory.path_join(file))
	DirAccess.remove_absolute(directory)
	print("RHYTHM RESULTS: %d passed, %d failed" % [passed, failed])
	quit(1 if failed else 0)

func check(ok: bool, label: String) -> void:
	if ok:
		passed += 1
		print("PASS " + label)
	else:
		failed += 1
		push_error("FAIL " + label)

func game_at(hour: float) -> GameSession:
	now = 100 * 86400.0 + hour * 3600
	var game := GameSession.new()
	game.storage = SaveSystem.new(directory.path_join("session-%s.json" % Time.get_ticks_usec()))
	game.local_clock = func(): return now
	game.pet = PetState.create(42)
	game.pet.life.mood = "calm"
	game.pet.life.mood_day = 100
	game.active = true
	game.initiatives_enabled = false
	game._brain_left = INF
	return game

func arrive_sequence(game: GameSession) -> void:
	for step in 30:
		if game.activity == "walk": game.destination_reached()
		elif game.activity == "behavior": game._process(game.activity_left + 0.01)
		else: return
	check(false, "sequence terminates")

func _test_clock() -> void:
	var pet := PetState.create(42)
	for boundary in [[0, "night"], [5.99, "night"], [6, "morning"], [9, "day"], [13, "siesta"], [15, "afternoon"], [19, "evening"], [22, "night"]]:
		check(DailyRhythm.phase(pet, 100 * 86400 + boundary[0] * 3600) == boundary[1], "phase boundary %s" % boundary[0])
	pet.habits = ["time_night"]
	for day in range(100, 106):
		DailyRhythm.adapt(pet, day * 86400)
		check(pet.rhythm.offset_minutes == (day - 99) * 30, "night habit changes by thirty minutes on day %d" % day)
		check(not DailyRhythm.adapt(pet, day * 86400 + 600), "same day does not shift again")
	check(DailyRhythm.phase(pet, 106 * 86400 + 0.5 * 3600) == "evening", "night player can be active after midnight")
	check(DailyRhythm.phase(pet, 106 * 86400 + 9 * 3600) == "morning", "night player's wake time is nine")
	check(not DailyRhythm.adapt(pet, 90 * 86400), "clock rollback cannot change rhythm")
	pet.habits = ["time_morning"]
	DailyRhythm.adapt(pet, 200 * 86400)
	check(pet.rhythm.offset_minutes == 150, "long absence still changes by only thirty minutes")
	check(DailyRhythm.schedule_label(pet).contains("08:30"), "schedule wraps midnight")

func _test_choices() -> void:
	var pet := PetState.create(42)
	var noon := 100 * 86400.0 + 12 * 3600
	var weights := BehaviorSystem.weights(pet, noon)
	var penalized := BehaviorSystem.weights(pet, noon, ["window", "door", "carpet"], "window")
	check(penalized.window < weights.window * 0.02 and penalized.window > 0, "recent behavior and destination receive soft penalties")
	var choices := {}
	for index in 1000: choices[BehaviorSystem.choose(weights, index / 1000.0)] = true
	check(choices.size() == 9, "awake pool excludes random naps")
	var night := BehaviorSystem.weights(pet, 100 * 86400 + 23 * 3600, BehaviorSystem.BEHAVIORS.keys(), "carpet")
	check(night.ball == 0 and night.toys == 0 and night.nap == 0 and night.patrol == 0, "night has quiet choices and no random sleep")
	check(BehaviorSystem.choose(night, 0.99) in ["window", "door", "bowl", "carpet", "wait", "approach"], "penalized quiet pool still has valid choices")
	DailyRhythm.note_nap(pet, noon)
	check(not DailyRhythm.nap_allowed(pet, noon + 1799) and DailyRhythm.nap_allowed(pet, noon + 1800), "automatic naps have a thirty minute interval")
	DailyRhythm.note_nap(pet, noon + 3600)
	check(not DailyRhythm.nap_allowed(pet, noon + 7200), "siesta permits one automatic nap per day")
	check(DailyRhythm.nap_allowed(pet, noon + 86400 + 3600), "next day's siesta is available")
	for id in BehaviorSystem.BEHAVIORS:
		for step in BehaviorSystem.steps(id, pet):
			if step.has("clip"): check(PetAnimator.CLIPS.has(step.clip), "existing animation: " + step.clip)

func _test_night() -> void:
	var game := game_at(23)
	game.pet.needs.energy = 90
	var needs := game.pet.needs.duplicate()
	var bond := game.pet.bond
	game._sync_rhythm_on_return()
	check(game.night_sleep and game.scheduled_sleep and game.pet.resting, "night return preserves sleep even with full energy")
	check(game.pet.needs == needs and game.pet.bond == bond, "sleep transition has no instant reward")
	game._process(3600)
	check(game.is_sleeping() and game.pet.resting and game.pet.needs.energy == 100, "full energy never wakes scheduled sleep")
	check(game.act("pet") and not game.is_sleeping(), "explicit touch grants short visit")
	var until: float = game.pet.rhythm.awake_until
	check(game.start_touch_game("tug"), "manual wake allows a game")
	now += 601
	game._tick_rhythm(30)
	check(not game.is_sleeping(), "sleep waits for active game to finish")
	game.cancel_touch_game()
	game.player_activity()
	check(game.pet.rhythm.awake_until == until, "stroking cannot extend the visit indefinitely")
	game._tick_rhythm(20)
	arrive_sequence(game)
	check(game.is_sleeping(), "dog independently returns to bed after visit")
	now = 101 * 86400.0 + 6 * 3600
	game._process(0.1)
	check(not game.is_sleeping() and game.wake_report_left > 0 and game.last_message.begins_with("Już nie śpię"), "natural morning wake reports needs")
	game.free()

	game = game_at(13)
	game.set_training_view(true)
	game._tick_rhythm(20)
	arrive_sequence(game)
	check(game.scheduled_sleep, "empty training tab does not block afternoon sleep")
	game.free()

func _test_sequences() -> void:
	var game := game_at(12)
	var before := game.pet.history.duplicate(true)
	game._start_behavior("window")
	arrive_sequence(game)
	check(game.activity == "idle" and game.pose == "lie", "window sequence ends lying on the carpet")
	check(game.pet.history == before, "autonomous sequence does not invent player activity")
	game._start_behavior("patrol")
	check(game.act("pet") and game._sequence.is_empty(), "touch cancels queued movement")
	game.destination_reached()
	check(game.activity == "pet", "stale movement completion cannot restart a canceled sequence")
	game._process(1)
	now = 100 * 86400.0 + 13 * 3600
	game._start_behavior("nap")
	arrive_sequence(game)
	game.pet.needs.energy = 90
	game._process(20)
	check(game.is_sleeping(), "automatic nap has a minimum duration")
	game._process(41)
	check(game.is_sleeping(), "day sleep lasts beyond the old one-minute nap")
	now = 100 * 86400.0 + 15 * 3600
	game._process(0.1)
	check(not game.is_sleeping(), "day nap ends at next wake window")
	game._brain_left = INF
	game.follow_room(Vector2(1100, 310))
	game._process(3)
	check(game.activity == "walk", "dog follows room viewing after a short delay")
	game.free()

func _test_save() -> void:
	var game := game_at(23)
	game.pet.habits = ["time_evening"]
	DailyRhythm.adapt(game.pet, now)
	var data := game.pet.to_dict()
	data.erase("rhythm")
	var path := directory.path_join("legacy.json")
	var broken_v4 := data.duplicate(true)
	broken_v4.erase("social")
	check(PetState.from_dict(SaveSystem.migrate(broken_v4, 4)) == null, "v4 migration must not silently replace missing social memory")
	var raw := JSON.stringify({"schema_version": 4, "pet": data})
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(raw)
	file.close()
	var store := SaveSystem.new(path)
	var loaded := store.load_pet()
	check(loaded.writable and loaded.pet.pet_id == game.pet.pet_id and loaded.pet.rhythm == DailyRhythm.initial(), "v4 migration preserves dog and initializes rhythm")
	check(FileAccess.get_file_as_string(path + ".v4") == raw, "original v4 save preserved byte for byte")
	check(store.save_pet(game.pet) and store.load_pet().pet.rhythm == game.pet.rhythm, "rhythm survives real save and reload")
	var restored: PetState = store.load_pet().pet
	check(not DailyRhythm.adapt(restored, now) and restored.rhythm.offset_minutes == 30, "restart cannot apply a second daily shift")
	for broken in [NAN, -60, 181, 2.5, "night"]:
		var invalid := game.pet.to_dict()
		invalid.rhythm.offset_minutes = broken
		check(PetState.from_dict(invalid) == null, "invalid rhythm rejected: " + str(broken))
	game.storage = store
	game._enter_sleep("night", false)
	game.suspend_session()
	game.resume_session()
	check(game.night_sleep and game.activity == "sleep", "short background resume retains night sleep")
	game.act("pet")
	game.suspend_session()
	game.resume_session()
	check(not game.is_sleeping(), "short app switch does not force a woken dog back to sleep")
	game.free()

func _test_greetings_and_training() -> void:
	var game := game_at(22.5)
	game.start(directory.path_join("new-night.json"))
	check(game.is_sleeping(), "first launch at night does not wake dog")
	game.suspend_session()
	game.pet.last_seen_at -= 120
	game.resume_session()
	check(game.is_sleeping(), "longer background return does not wake dog")
	game.free()
	for reward in TrainingSystem.REWARDS:
		game = game_at(12)
		check(game.begin_training("sit", true), "start training before " + reward)
		game.performance_finished(game.training.trial_id)
		game._process(2.5)
		check(game.give_reward(reward), "accept training reward " + reward)
		game._process(1.5)
		check(game.activity == "idle" and game.pose == "sit" and game._sequence_id.is_empty(), "training reward stays seated instead of walking to carpet: " + reward)
		game.set_training_view(true)
		game._brain_left = 0
		game._process(20)
		check(game.activity == "idle" and game._sequence_id.is_empty(), "training tab blocks autonomous wandering between trials: " + reward)
		check(game.begin_training("sit", true), "next repetition remains available: " + reward)
		game.training.cancel()
		game.set_training_view(false)
		game._brain_left = 0
		game._process(0.1)
		check(not game._sequence_id.is_empty(), "leaving training restores autonomy: " + reward)
		game.free()
	game = game_at(12)
	game._start_behavior("carpet")
	game.set_training_view(true)
	check(game.activity == "idle" and game._sequence.is_empty(), "entering training cancels a queued autonomous walk")
	game.set_training_view(false)
	game.act("feed")
	game.arrive_at(game._approach_token)
	game._process(2.1)
	check(game._sequence_id == "carpet", "food still leads to a quiet rest")
	game.free()

func _test_yard_night() -> void:
	var game := game_at(23)
	check(not game.change_yard(true) and not game.in_yard, "night refuses yard entry")
	check(game.last_message == "Za ciemno, pora spać.", "night entry explains bedtime")
	now = 100 * 86400.0 + 21 * 3600
	check(game.change_yard(true), "evening still permits yard")
	game.follow_room(Vector2(1100, 310))
	game._process(3)
	check(game.activity == "walk", "yard follows viewed location")
	game._process(91)
	check(game._travel_left <= 0 and game.activity != "walk", "yard travel times out without arrival")
	check(game.start_sniff(), "sniff starts before bedtime")
	now = 100 * 86400.0 + 23 * 3600
	game._process(31)
	check(game.in_yard, "active sniff approach is not interrupted by bedtime")
	game._process(60)
	check(not game.in_yard, "stuck approach times out and returns home at night")
	arrive_sequence(game)
	check(game.is_sleeping() and game.night_sleep, "return home leads to night sleep")
	game.free()
	game = game_at(21)
	game.change_yard(true)
	now = 100 * 86400.0 + 23 * 3600
	game._process(20)
	check(not game.in_yard, "sleep schedule returns an idle dog home")
	game.player_activity()
	game._process(20)
	check(not game.in_yard, "stroking does not cancel scheduled return home")
	game._process(11)
	check(not game.in_yard, "thirty idle seconds returns dog indoors")
	arrive_sequence(game)
	check(game.is_sleeping(), "idle yard dog sleeps after return")
	game.free()

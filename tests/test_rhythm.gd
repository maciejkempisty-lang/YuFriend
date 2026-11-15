extends SceneTree

var passed := 0
var failed := 0
var now := 100 * 86400.0 + 12 * 3600.0
var directory := "/tmp/yufriend-rhythm-%s" % Time.get_ticks_usec()

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(directory)
	_test_clock()
	_test_choices()
	_test_greetings_and_training()
	_test_night()
	_test_sequences()
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
	check(DailyRhythm.schedule_label(pet) == "Zwykły sen: 00:30–08:30", "schedule wraps midnight")

func _test_choices() -> void:
	var pet := PetState.create(42)
	var noon := 100 * 86400.0 + 12 * 3600
	var weights := BehaviorSystem.weights(pet, noon)
	var penalized := BehaviorSystem.weights(pet, noon, ["window", "door", "carpet"], "window")
	check(penalized.window < weights.window * 0.02 and penalized.window > 0, "recent behavior and destination receive soft penalties")
	var choices := {}
	for index in 1000: choices[BehaviorSystem.choose(weights, index / 1000.0)] = true
	check(choices.size() == 10, "weighted pool can select every eligible behavior")
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
	game._enter_sleep("night", false)
	check(game.night_sleep and game.is_sleeping() and game.activity == "sleep", "bedtime sleep continues even above eighty-five energy")
	check(game.pet.needs == needs and game.pet.bond == bond, "entering night sleep grants no immediate reward or penalty")
	game._process(20)
	check(game.is_sleeping() and not game.pet.resting, "energy threshold does not end visible night sleep")
	check(CompanionVoice.new().describe(game).label == "Obudź", "night sleep offers waking after regeneration ends")
	var before_wake := game.pet.to_dict()
	check(game.act("pet") and not game.is_sleeping() and game.groggy_left > 0, "touch wakes gently")
	check(game.pet.needs == before_wake.needs and game.pet.bond == before_wake.bond, "waking has no need or bond penalty")
	check(game.walk_speed() < LifeSystem.walk_speed(game.pet), "newly awakened dog walks more slowly")
	check(game.start_touch_game("tug"), "player may start energetic play after waking at night")
	game._tick_rhythm(250)
	check(not game.is_sleeping() and game._idle_seconds == 0, "night sleep never interrupts a game")
	game.cancel_touch_game()
	game._brain_left = INF
	game._tick_rhythm(99)
	check(not game.sleep_warning, "no premature wake-to-sleep warning")
	game._tick_rhythm(1)
	check(game.sleep_warning and CompanionVoice.new().describe(game).action == "pet", "twenty-second warning allows a player response")
	game._tick_rhythm(20)
	check(game._sequence_id == "night", "two idle minutes after waking start the walk to bed")
	arrive_sequence(game)
	check(game.night_sleep, "arrival at bed starts night sleep")
	now = 101 * 86400.0 + 6 * 3600
	game._process(0.1)
	check(not game.is_sleeping(), "scheduled morning wakes dog regardless of energy")
	game.free()

	game = game_at(21.99)
	game._tick_rhythm(1)
	now = 100 * 86400.0 + 22 * 3600
	game._tick_rhythm(160)
	check(game.sleep_warning and not game.is_sleeping(), "evening crossing into night warns before sleep")
	game.act("pet")
	game._process(1)
	check(not game.sleep_warning and game._idle_seconds == 0, "stroking resets the night timer")
	game._tick_rhythm(180)
	check(game._sequence_id == "night", "three minutes of inactivity start bedtime")
	check(game.act("feed") and game._sequence_id.is_empty(), "feeding interrupts bedtime walk")
	game.arrive_at(game._approach_token)
	game._tick_rhythm(200)
	check(not game.night_sleep, "night sleep never interrupts feeding")
	game.free()

	game = game_at(23)
	game.initiatives_enabled = true
	check(not game.offer_initiative("ball"), "dog does not initiate night ball games")
	check(game.offer_initiative() and game.invitation.kind == "cuddle", "night invitation is closeness")
	game._cancel_invitation()
	check(game.begin_training("sit", true), "awake dog can train at night")
	game._tick_rhythm(250)
	check(not game.is_sleeping(), "night never interrupts training")
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
	game._start_behavior("nap")
	arrive_sequence(game)
	game.pet.needs.energy = 90
	game._process(20)
	check(game.is_sleeping(), "automatic nap has a minimum duration")
	game._process(41)
	check(not game.is_sleeping() and not DailyRhythm.nap_allowed(game.pet, now), "nap ends and cannot immediately recur")
	game._brain_left = INF
	game.follow_room(Vector2(1100, 310))
	game._tick_rhythm(3)
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
	var path := directory.path_join("new-night.json")
	game.start(path)
	check(not game.is_sleeping() and game.last_message.contains("Dobrze, że jesteś"), "first launch at 22:30 greets without requiring a wake action")
	check(game.play_readiness().is_empty() and game.begin_training("sit", true), "new night player can play and start training immediately")
	game.training.cancel()
	game._enter_sleep("night", false)
	var needs := game.pet.needs.duplicate()
	var bond := game.pet.bond
	game._sync_rhythm_on_return()
	check(not game.is_sleeping() and game.pet.needs == needs and game.pet.bond == bond, "greeting wakes an existing dog without a stat bonus or penalty")
	game._tick_rhythm(159)
	check(not game.sleep_warning and game._sequence_id.is_empty(), "arrival gives three minutes before bedtime")
	game._tick_rhythm(1)
	check(game.sleep_warning and game.last_message.begins_with("Chce mi się spać"), "bedtime warning uses gender-neutral wording")
	game._tick_rhythm(20)
	check(game._sequence_id == "night", "greeting still leads to sleep after inactivity")
	arrive_sequence(game)
	game.act("pet")
	check(game.last_message.begins_with("Jeszcze chwila na rozbudzenie"), "wake text is neutral for Gloria and other names")
	game._enter_sleep("night", false)
	game.suspend_session()
	game.pet.last_seen_at -= 120
	game.resume_session()
	check(not game.is_sleeping() and game.last_message.contains("Dobrze, że jesteś"), "return from a longer absence greets at night")
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

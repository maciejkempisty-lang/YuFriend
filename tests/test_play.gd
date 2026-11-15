extends SceneTree

var passed := 0
var failed := 0
var directory: String
var serial := 0

func _initialize() -> void:
	var test_root := OS.get_environment("YUFRIEND_TEST_ROOT")
	directory = ("user://" if test_root.is_empty() else test_root).path_join("qa-play-%s" % Time.get_ticks_usec())
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	_test_memory()
	_test_invitations()
	_test_games()
	_test_rewards_and_interruptions()
	_test_migration()
	for file in DirAccess.get_files_at(directory): DirAccess.remove_absolute(directory.path_join(file))
	DirAccess.remove_absolute(directory)
	print("PLAY RESULTS: %d passed, %d failed" % [passed, failed])
	quit(1 if failed else 0)

func check(condition: bool, label: String) -> void:
	if condition:
		passed += 1
		print("PASS " + label)
	else:
		failed += 1
		push_error("FAIL " + label)

func _game() -> GameSession:
	var game := GameSession.new()
	game.pet = PetState.create(42)
	game.pet.pet_name = "Gloria"
	game.active = true
	game._brain_left = INF
	serial += 1
	game.storage = SaveSystem.new(directory.path_join("pet-%d.json" % serial))
	game.flush()
	return game

func _test_memory() -> void:
	var pet := PetState.create(42, 1000)
	var weights := InitiativeSystem.weights(pet)
	var bond := pet.bond
	var traits := pet.traits.duplicate()
	for index in 3: InitiativeSystem.record(pet, "ball", "accepted", 1000 + index)
	InitiativeSystem.record(pet, "cups", "declined", 1010)
	InitiativeSystem.record(pet, "tug", "ignored", 1020)
	var after := InitiativeSystem.weights(pet)
	check(float(after.ball) > float(weights.ball) and float(after.cups) < float(weights.cups) and float(after.tug) < float(weights.tug), "responses change which invitations the dog prefers")
	check(pet.bond == bond and pet.traits == traits, "declining or ignoring does not punish bond or temperament")
	check(pet.milestones.has("initiative_ball") and pet.social.responses.ball.accepted == 3, "three accepted invitations form a remembered ritual")
	check(InitiativeSystem.profile_text(pet).contains("Piłka") and InitiativeSystem.profile_text(pet).contains("później"), "profile explains recent responses")
	for index in 60: InitiativeSystem.record(pet, "ball", "ignored", 1100 + index)
	check(pet.social.recent.size() == 12 and float(pet.social.responses.ball.interest) >= 0.15, "response history and preference adaptation are bounded")
	var restored := PetState.from_dict(pet.to_dict())
	check(restored != null and restored.social == pet.social, "personal response memory survives serialization")
	pet.needs.energy = 20
	check(InitiativeSystem.choose(pet, 0.0) == "cuddle" and InitiativeSystem.choose(pet, 0.99) == "cuddle", "a tired dog proposes quiet contact instead of energetic play")
	var before := pet.social.duplicate(true)
	check(not InitiativeSystem.record(pet, "unknown", "accepted", 2000) and not InitiativeSystem.record(pet, "ball", "invalid", 2000) and pet.social == before, "unknown reactions cannot modify memory")
	for invalid in ["missing", "unknown", "negative", "fraction", "nonfinite", "oversized"]:
		var data := pet.to_dict()
		match invalid:
			"missing": data.erase("social")
			"unknown": data.social.recent = [{"kind": "fly", "response": "accepted", "at": 1000}]
			"negative": data.social.games.ball = -1
			"fraction": data.social.responses.ball.accepted = 1.5
			"nonfinite": data.social.last_reward_at = NAN
			"oversized": data.social.recent.resize(13)
		check(PetState.from_dict(data) == null, "reject malformed response state: " + invalid)

func _test_invitations() -> void:
	var autonomous := _game()
	autonomous._initiative_wait = 0
	autonomous._brain_left = 0.01
	autonomous._process(0.1)
	check(not autonomous.invitation.is_empty() and autonomous.pet.social.last_offer_at > 0, "idle session initiates an invitation without a player action")
	autonomous.free()
	var game := _game()
	check(game.offer_initiative("cuddle"), "an idle dog can initiate contact")
	check(game.accept_invitation() and game.pet.social.responses.cuddle.accepted == 1 and game.invitation.is_empty(), "accepting the invitation performs care and records exactly one response")
	check(not game.accept_invitation() and game.pet.social.responses.cuddle.accepted == 1, "double acceptance cannot duplicate a response")
	check(not game.offer_initiative("ball"), "invitations respect a persistent spacing limit")
	game._process(2)
	game.pet.social.last_offer_at = 0
	game.offer_initiative("cups")
	check(game.activity == "approach" and game._pending_action == "toys" and not game.busy(), "an invitation approaches the toys and remains interruptible")
	game.attention_available = false
	game._process(60)
	check(not game.invitation.is_empty() and game.pet.social.responses.cups.ignored == 0, "hidden invitations do not count as ignored")
	game.attention_available = true
	game._process(InitiativeSystem.RESPONSE_SECONDS + 1)
	check(game.invitation.is_empty() and game.pet.social.responses.cups.ignored == 1, "visible unanswered invitation is remembered once")
	game._process(50)
	check(game.pet.social.responses.cups.ignored == 1, "elapsed time cannot repeat the same ignored response")
	game.pet.social.last_offer_at = 0
	game.offer_initiative("tug")
	game.decline_invitation()
	check(game.pet.social.responses.tug.declined == 1 and game.pet.social.responses.tug.ignored == 0, "later is recorded separately from silence")
	check(game.activity == "idle" and game._pending_action.is_empty(), "declining also cancels the invitation approach")
	game.pet.social.last_offer_at = 0
	game.offer_initiative("ball")
	var before: Dictionary = game.pet.social.responses.duplicate(true)
	game.suspend_session()
	game._process(120)
	game.resume_session()
	check(game.invitation.is_empty() and game.pet.social.responses == before, "backgrounding cancels an invitation without inventing a response")
	game.pet.social.last_offer_at = 0
	game.offer_initiative("ball")
	game.pet.needs.energy = 15
	check(not game.accept_invitation() and not game.invitation.is_empty() and game.pet.social.responses.ball.accepted == 0, "rejected play does not record a false acceptance")
	game.pet.needs.energy = 70
	game.act("clean")
	check(game.invitation.is_empty() and game.pet.social.responses.ball.ignored == 0, "another accepted activity cancels without a negative response")
	game._process(3)
	game.pet.social.last_offer_at = 0
	game.offer_initiative("cuddle")
	var memory: Dictionary = game.pet.social.responses.cuddle.duplicate(true)
	check(game.act("feed") and game.invitation.is_empty() and game.pet.social.responses.cuddle == memory, "feeding during a cuddle invitation leaves response counts and interest unchanged")
	game.arrive_at(game._approach_token)
	game._process(3)
	var last_offer := float(game.pet.social.last_offer_at)
	check(not game.offer_initiative("cuddle", last_offer + 299), "restarting cannot bypass the five minute invitation interval")
	check(game.offer_initiative("cuddle", last_offer + 300), "an invitation is eligible after five minutes")
	game._cancel_invitation()
	game.pet.social.last_offer_at = 0
	game.attention_available = false
	check(not game.offer_initiative("ball"), "no invitation is issued behind a dialog or another tab")
	game.attention_available = true
	game.writable = false
	check(not game.offer_initiative("ball"), "a blocked save cannot mutate invitation memory")
	game.free()

func _win_tug(play: TouchPlaySystem) -> void:
	play.press(play.tug_handle)
	for index in 6: play.move(Vector2(0.44 if index % 2 == 0 else 0.82, 0.54))

func _test_games() -> void:
	var play := TouchPlaySystem.new()
	check(play.start("tug", 42), "tug game starts")
	play.press(Vector2(0.1, 0.1))
	play.move(Vector2(0.8, 0.5))
	check(play.strokes == 0 and not play.held, "rope must be grabbed by its visible knot")
	play.press(play.tug_handle)
	play.advance(500)
	for index in 50: play.move(Vector2(0.78 + (0.005 if index % 2 == 0 else 0), 0.54))
	check(play.strokes == 0 and play.phase == "pull", "holding and tiny pointer jitter cannot win the rope game")
	play.release(Vector2.ZERO, true)
	_win_tug(play)
	check(play.phase == "result" and play.success and play.strokes == 6, "six alternating deliberate pulls finish the rope game")
	play.move(Vector2(0.1, 0.1))
	check(play.strokes == 6, "a completed round cannot accumulate additional strokes")
	play.start("cups", 62)
	var treat := play.treat_cup
	play.press(play.cup_point(treat) - Vector2(0, 0.1))
	play.release(play.cup_point(treat) - Vector2(0, 0.1))
	check(play.phase == "reveal", "cup guesses are rejected while the treat is visible")
	play.advance(1.9)
	var first := play.cup_point(play.swap_pair.x)
	play.advance(0.375)
	check(play.cup_point(play.swap_pair.x).distance_to(first) > 0.05, "cup swaps expose a continuous trackable movement")
	play.advance(10)
	var slots := play.cups.duplicate()
	slots.sort()
	check(play.phase == "guess" and slots == [0, 1, 2] and play.swaps == 3, "three visible swaps retain a valid permutation")
	var target := play.cup_point(treat) - Vector2(0, 0.1)
	play.press(target)
	play.move(target + Vector2(0.15, 0))
	play.release(target)
	check(play.phase == "guess", "dragging across a cup does not become an accidental guess")
	play.press(target)
	play.release(target)
	check(play.phase == "result" and play.success, "following the treat-bearing cup succeeds after shuffling")
	play.start("cups", 62)
	play.advance(10)
	target = play.cup_point((play.treat_cup + 1) % 3) - Vector2(0, 0.1)
	play.press(target)
	play.release(target)
	check(play.phase == "result" and not play.success and play.hint().contains("spróbować"), "a wrong cup reveals the answer and offers a gentle retry")
	play.start("tug")
	play.press(Vector2(NAN, 0.5))
	check(not play.held, "nonfinite input does not enter a gesture")
	play.reset()
	play.finish_ball()
	check(play.phase.is_empty(), "a stale ball finish cannot complete another or cancelled game")

func _test_rewards_and_interruptions() -> void:
	var game := _game()
	var initial := game.pet.needs.duplicate()
	check(not game.throw_ball(Vector2(NAN, 300)) and game.pet.needs == initial, "invalid ball destinations have no effects")
	check(game.throw_ball(Vector2(1200, 317)) and game.pet.needs == initial, "throwing starts a chase without granting its reward early")
	var token := game._approach_token
	game.arrive_at(token - 1)
	check(game.pet.needs == initial, "an old arrival token cannot finish the ball game")
	game.arrive_at(token)
	var earned := game.pet.to_dict()
	check(game.pet.needs.play > initial.play and game.pet.social.games.ball == 1 and game.pet.social.last_reward_at > 0, "the confirmed catch grants a bounded play reward")
	game.arrive_at(token)
	check(game.pet.needs == earned.needs and game.pet.bond == earned.bond and game.pet.social.games.ball == 1, "duplicate catch cannot grant duplicate rewards")
	game._process(2)
	game.start_touch_game("tug")
	_win_tug(game.play)
	var before := game.pet.needs.duplicate()
	game._settle_touch_game()
	check(game.pet.needs == before and game.pet.social.games.tug == 1, "shared reward cooldown allows another game without farming needs")
	game._settle_touch_game()
	check(game.pet.social.games.tug == 1, "a result is settled exactly once")
	game.cancel_touch_game()
	game.start_touch_game("cups")
	before = game.pet.needs.duplicate()
	game.play.advance(10)
	var wrong := game.play.cup_point((game.play.treat_cup + 1) % 3) - Vector2(0, 0.1)
	game.play_press(wrong)
	game.play_release(wrong)
	check(game.pet.needs == before and game.pet.social.games.cups == 1, "a wrong guess has neither reward nor penalty")
	game.cancel_touch_game()
	game.throw_ball(Vector2(1000, 317))
	token = game._approach_token
	before = game.pet.needs.duplicate()
	game.suspend_session()
	game.arrive_at(token)
	game.resume_session()
	check(game.play.kind.is_empty() and game.pet.social.games.ball == 1 and absf(game.pet.needs.play - float(before.play)) < 0.01, "pause invalidates an unfinished throw without granting it on resume")
	game.start_touch_game("tug")
	game.play_press(game.play.tug_handle)
	game.suspend_session()
	game.play_move(Vector2(0.44, 0.54))
	game.resume_session()
	check(not game.play.held and game.play.kind.is_empty() and game.pet.social.games.tug == 1, "backgrounding clears a held rope and does not complete it")
	var loaded := game.storage.load_pet()
	check(loaded.status == "loaded" and loaded.pet.social.games == game.pet.social.games and absf(float(loaded.pet.social.last_reward_at) - float(game.pet.social.last_reward_at)) < 0.001, "game totals and the shared reward timestamp survive reload")
	game.free()

func _test_migration() -> void:
	var old := PetState.create(62, 1000)
	LifeSystem.observe(old, LifeSystem.QUIRKS[old.life.quirks[0]].event, 1010)
	LifeSystem.refresh_mood(old, 2000000)
	var data := old.to_dict()
	data.erase("social")
	var path := directory.path_join("v3.json")
	var raw := JSON.stringify({"schema_version": 3, "pet": data})
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(raw)
	file.close()
	var store := SaveSystem.new(path)
	var loaded := store.load_pet()
	check(loaded.writable and loaded.pet.pet_id == old.pet_id and loaded.pet.life.quirks == old.life.quirks and loaded.pet.life.discovered == old.life.discovered and loaded.pet.life.mood == old.life.mood and loaded.pet.life.mood_day == old.life.mood_day and loaded.pet.life.observations[old.life.quirks[0]] == old.life.observations[old.life.quirks[0]], "v3 migration preserves identity, quirks, discoveries and daily mood")
	check(loaded.pet.social == PetState.initial_social() and FileAccess.get_file_as_string(path + ".v3") == raw, "v3 original is retained and response memory starts empty")
	check(store.save_pet(loaded.pet) and store.load_pet().writable, "migrated v3 state saves and reloads in v4")
	data.erase("life")
	check(PetState.from_dict(SaveSystem.migrate(data, 3)) == null, "v3 missing life data is rejected instead of silently rerolling the dog")

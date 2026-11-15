extends SceneTree

var passed := 0
var failed := 0

func _initialize() -> void:
	var game := GameSession.new()
	game.local_clock = func(): return 100 * 86400.0 + 12 * 3600.0
	game.pet = PetState.create(42)
	var voice := CompanionVoice.new()
	var before := game.pet.to_dict().duplicate(true)
	var quiet := voice.describe(game)
	check(quiet.kind == "thought", "a new happy dog has a thought, not an invented memory")
	for index in 100: check_same(voice.describe(game).text == quiet.text)
	check(voice.describe(game, 44).text == quiet.text, "refresh and short pauses keep the same thought")
	check(before == game.pet.to_dict(), "reading the voice does not change the pet or its journal")
	for key in CompanionVoice.NEEDS:
		reset_needs(game)
		game.pet.needs[key] = 25
		var line := voice.describe(game)
		check(line.kind == "need" and line.action == CompanionVoice.NEEDS[key][1], "need routes to existing care: " + key)
	reset_needs(game)
	game.pet.needs.play = 15
	game.pet.needs.energy = 20
	check(voice.describe(game).action == "rest", "exhaustion has priority over even lower play")
	game.pet.needs.energy = 80
	game.pet.fatigue = 80
	check(voice.describe(game).action == "rest", "fatigue recommends rest even with a full energy meter")
	game.pet.fatigue = 0
	game.invitation = {"kind": "ball", "remaining": 30.0}
	check(voice.describe(game).kind == "need", "need preempts an invitation")
	reset_needs(game)
	check(voice.describe(game).action == "invite:ball", "invitation preempts quiet thoughts")
	game.pet.needs.fullness = 20
	game.cooldowns.feed = 5
	check(not voice.describe(game).enabled, "need button respects the real care cooldown")
	game.cooldowns.clear()
	game.activity = "approach"
	game._pending_by_player = true
	game._pending_action = "feed"
	check(voice.describe(game).kind == "activity" and voice.describe(game).action.is_empty(), "care in progress does not offer a second action")
	game.activity = "idle"
	game.pet.resting = true
	check(voice.describe(game).action == "rest" and voice.describe(game).label == "Obudź", "a sleeping dog offers waking, not impossible feeding")
	game.pet.resting = false
	game.invitation.clear()
	reset_needs(game)
	game.pet.remember("first_sit", "Pierwszy siad", "Prawdziwe wydarzenie")
	var memory := voice.describe(game)
	check(memory.kind == "memory" and memory.text.contains("siad") and memory.action == "album", "a recorded first sit becomes a memory linking to the album")
	check(voice.describe(game, 44).text == memory.text, "new memories have a full quiet interval")
	check(voice.describe(game, 2).kind == "thought", "a memory gives way to a thought after 45 visible seconds")
	game.pet.needs.contact = 20
	check(voice.describe(game, 100).kind == "need", "a new need immediately interrupts quiet content")
	reset_needs(game)
	check(voice.describe(game).kind == "thought", "time spent on needs does not rotate unseen thoughts")
	game.pet.life.discovered.append("sun_napper")
	voice.describe(game)
	voice.describe(game, 46)
	check(voice.describe(game, 46).text == CompanionVoice.QUIRKS.sun_napper, "only discovered quirks join quiet thoughts")
	game.writable = false
	game.pet.needs.fullness = 20
	check(not voice.describe(game).enabled, "read-only sessions cannot mutate through the bubble")
	game.writable = true
	game.suspended = true
	check(not voice.describe(game).enabled, "suspended sessions cannot mutate through the bubble")
	game.free()
	print("COMPANION RESULTS: %d passed, %d failed" % [passed, failed])
	quit(1 if failed else 0)

func reset_needs(game: GameSession) -> void:
	for key in PetState.NEED_KEYS: game.pet.needs[key] = 80.0

func check_same(condition: bool) -> void:
	if not condition:
		failed += 1
		push_error("FAIL refreshing changed a quiet thought")

func check(condition: bool, label: String) -> void:
	if condition:
		passed += 1
		print("PASS " + label)
	else:
		failed += 1
		push_error("FAIL " + label)

extends SceneTree
var passed := 0
var failed := 0
func check(ok: bool, label: String) -> void:
	if ok: passed += 1
	else:
		failed += 1
		push_error(label)
func game() -> GameSession:
	var session := GameSession.new()
	session.pet = PetState.create(42)
	session.pet.skills.sit.mastery = 100
	session.pet.yard_record = 4.5
	session.pet.decor = ["rug"]
	session.pet.remember("yard_find_0", "Kamyk", "Wcześniejsze znalezisko")
	session.active = true
	session.local_clock = func(): return 100 * 86400.0 + 12 * 3600
	PracticeSystem.sync(session.pet, session._local_now())
	session.initiatives_enabled = false
	session._brain_left = INF
	session.change_yard(true)
	return session
func _initialize() -> void:
	var hide := YardHide.new()
	check(not hide.start("invalid"), "unknown mode rejected")
	check(hide.start("treat", 42) and hide.phase == "choose", "treat starts by choosing a bush")
	check(not hide.start("dog"), "active round cannot be replaced")
	check(hide.select(-1).is_empty() and hide.select(3).is_empty(), "invalid bushes rejected")
	check(hide.advance(4).is_empty() and hide.phase == "choose", "no search before hiding treat")
	var chosen := hide.search_order[2]
	check(hide.select(chosen) == "walk", "chosen bush starts search")
	check(hide.select(0).is_empty(), "cannot move treat during search")
	for index in 3:
		check(hide.phase == "walk" and hide.search_spot() == hide.search_order[index], "search visits physical bush in order")
		check(hide.advance(0.1).is_empty(), "travel alone cannot discover treat")
		check(hide.arrive() and not hide.arrive(), "only one arrival begins sniffing")
		check(hide.advance(1).is_empty(), "must finish sniffing")
		check(hide.advance(1) == ("found" if index == 2 else "walk"), "wrong bush continues and correct bush finishes")
	check(hide.phase == "found" and hide.select(chosen).is_empty(), "finished search cannot reward twice")
	hide.reset()
	check(hide.start("dog", 10) and hide.phase == "hiding", "dog has a concealed setup phase")
	check(hide.select(hide.hiding_spot).is_empty(), "cannot guess during setup")
	check(hide.advance(1.2) == "guess", "tail clue becomes available")
	check(hide.select((hide.hiding_spot + 1) % 3) == "wrong" and hide.phase == "guess", "wrong guess leaves round playable")
	check(hide.select(hide.hiding_spot) == "found", "right guess reveals dog")
	hide.reset()
	hide.start("dog", 1)
	check(hide.advance(121) == "timeout", "idle rounds have finite duration")
	var session := game()
	PracticeSystem.record(session.pet, session.pet.practice.targets[0], session._local_now())
	var original := session.pet.to_dict()
	check(session.start_hide("treat", 42), "session starts treat game")
	check(session.busy() and not session.throw_ball(Vector2(1100, 310)), "hide blocks competing fetch")
	check(not session.start_bath() and not session.start_sniff(), "hide blocks bath and regular sniff")
	chosen = session.hide_game.search_order[2]
	check(session.choose_hide_bush(chosen), "session accepts chosen hiding place")
	var bond := session.pet.bond
	for i in 3:
		check(session.activity == "hide_walk" and session.pet.bond == bond, "no prize before actual discovery")
		session.destination_reached()
		check(session.activity == "hide_sniff", "arrival starts sniff animation state")
		session._process(2.1)
	check(not session.hide_game.active() and session.pet.milestones.has("yard_hide_treat"), "successful search remembers first treat game")
	check(is_equal_approx(session.pet.bond - bond, 0.5), "successful game awards bounded bond")
	bond = session.pet.bond
	session.destination_reached()
	check(not session.choose_hide_bush(chosen) and session.pet.bond == bond, "late input cannot duplicate reward")
	session._process(2)
	check(session.start_hide("dog", 2), "can start dog game after result")
	chosen = session.hide_game.hiding_spot
	session._process(1.3)
	check(session.choose_hide_bush((chosen + 1) % 3) and session.pet.bond == bond, "wrong guess has no reward or penalty")
	check(session.choose_hide_bush(chosen) and session.pet.bond == bond, "second game respects shared reward cooldown")
	check(session.pet.milestones.has("yard_hide_dog"), "dog game has its own one-time memory")
	session._process(2)
	session.start_hide("dog", 3)
	session._process(1.3)
	session.suspend_session()
	check(not session.hide_game.active() and not session.in_yard, "background cancels hidden dog and returns inside")
	check(not session.choose_hide_bush(0), "background input ignored")
	session.suspended = false
	session.change_yard(true)
	session.start_hide("treat", 4)
	session.choose_hide_bush(1)
	session.change_yard(false)
	check(not session.hide_game.active(), "leaving yard cancels search")
	session.change_yard(true)
	session.start_hide("dog", 5)
	session._process(121)
	check(not session.hide_game.active() and session.pet.bond == bond, "timeout cancels without reward")
	for key in ["pet_id", "skills", "practice", "photos", "decor", "yard_record"]:
		check(session.pet.to_dict()[key] == original[key], "previous progress preserved: " + key)
	var path := "/tmp/yuf-hide-%s/pet.json" % Time.get_ticks_usec()
	var store := SaveSystem.new(path)
	check(store.save_pet(session.pet), "game result saves")
	var loaded := store.load_pet()
	check(loaded.pet.yard_record == 4.5 and loaded.pet.skills.sit.mastery == 100 and loaded.pet.milestones.has("yard_hide_dog") and loaded.pet.milestones.has("yard_hide_treat"), "reload preserves previous progress and new memories")
	check(SaveSystem.VERSION == 11, "current save schema")
	check(session.pet.milestones.has("yard_find_0"), "older collection survives both new games")
	session.start_hide("dog", 3)
	session.local_clock = func(): return 100 * 86400.0 + 23 * 3600
	session._process(121)
	session._process(31)
	check(not session.in_yard and not session.hide_game.active(), "abandoned hide cannot block nighttime return indefinitely")
	session.writable = false
	check(not session.start_hide("dog"), "read-only pet cannot begin hide")
	session.free()
	print("YARD HIDE RESULTS: %d passed, %d failed" % [passed, failed])
	quit(1 if failed else 0)

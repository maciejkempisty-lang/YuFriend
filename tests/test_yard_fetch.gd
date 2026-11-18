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
	session.active = true
	session.local_clock = func(): return 100 * 86400.0 + 12 * 3600
	session.initiatives_enabled = false
	session._brain_left = INF
	PracticeSystem.sync(session.pet, session._local_now())
	session.change_yard(true)
	return session
func _initialize() -> void:
	var origin := Vector2(700, 310)
	check(YardFetch.target(origin, Vector2(50, 0)).x == 850, "short swipe has proportional distance")
	check(YardFetch.target(origin, Vector2(100, 0)).x == 1000, "longer swipe travels farther")
	check(YardFetch.target(origin, Vector2(-100, 0)).x == 400, "left swipe throws left")
	check(YardFetch.target(origin, Vector2(1000, 0)).x == 1300, "strength has a maximum")
	check(YardFetch.target(Vector2(1300, 310), Vector2(200, 100)) == Vector2(1345, 328), "landing stays inside walkable lawn")
	var session := game()
	var before := session.pet.to_dict()
	check(not session.throw_ball(origin + Vector2(10, 0), origin), "tiny throw cannot start round")
	check(not session.throw_ball(Vector2.INF, origin), "nonfinite throw rejected")
	check(session.throw_ball(origin + Vector2(300, 0), origin), "yard throw starts")
	check(not session.catch_ball(), "early tap cannot earn bonus")
	check(session.pet.yard_record == 0, "incomplete chase has no record")
	var token := session._approach_token
	session.arrive_at(token)
	check(session.fetch.catching and session.pet.yard_record == 0, "arrival opens catch window before settling")
	var bond := session.pet.bond
	check(session.catch_ball(), "tap in window earns precision")
	check(is_equal_approx(session.pet.bond - bond, 1.35), "precision adds one bond beyond normal reward")
	check(session.pet.yard_record == 3, "completed throw records actual distance")
	check(not session.catch_ball(), "duplicate tap cannot settle again")
	session.arrive_at(token)
	check(session.pet.social.games.ball == 1, "stale arrival cannot duplicate round")
	session._process(2)
	session.throw_ball(origin + Vector2(200, 0), origin)
	session.arrive_at(session._approach_token)
	bond = session.pet.bond
	session.catch_ball()
	check(session.pet.bond == bond, "precision respects shared thirty-second reward cooldown")
	check(session.pet.yard_record == 3, "shorter throw cannot reduce record")
	session._process(2)
	session.throw_ball(origin + Vector2(500, 0), origin)
	session.arrive_at(session._approach_token)
	session._process(0.9)
	check(not session.fetch.active and session.pet.yard_record == 5, "missed window still finishes fetch and record")
	check(not session.catch_ball(), "late tap earns no precision")
	session._process(2)
	session.throw_ball(origin + Vector2(600, 0), origin)
	session.cancel_touch_game()
	check(session.pet.yard_record == 5 and not session.fetch.active, "cancellation does not overwrite record")
	session.throw_ball(origin + Vector2(600, 0), origin)
	session._process(91)
	check(not session.fetch.active and not session.play.running() and session.pet.yard_record == 5, "stalled chase times out without reward")
	check(session.pet.pet_id == before.pet_id and session.pet.skills == before.skills and session.pet.practice == before.practice, "fetch preserves identity skills and practice")
	session.throw_ball(origin + Vector2(600, 0), origin)
	session.arrive_at(session._approach_token)
	session.suspend_session()
	check(not session.fetch.active and session.pet.yard_record == 5 and not session.in_yard, "background during catch cancels without changing record")
	check(not session.catch_ball(), "background cannot accept a catch")
	var data := session.pet.to_dict()
	var path := preload("res://tests/helper_paths.gd").data_root() + "/yuf-fetch-%s/pet.json" % Time.get_ticks_usec()
	var store := SaveSystem.new(path)
	check(store.save_pet(session.pet) and store.load_pet().pet.yard_record == 5, "record survives real save and reload")
	data.yard_record = -1
	check(PetState.from_dict(data) == null, "negative record rejected")
	data.erase("yard_record")
	var legacy_path := path + "-legacy"
	var file := FileAccess.open(legacy_path, FileAccess.WRITE)
	file.store_string(JSON.stringify({"schema_version": 9, "pet": data}))
	file.close()
	var legacy_store := SaveSystem.new(legacy_path)
	var migrated := legacy_store.load_pet()
	check(migrated.writable and FileAccess.file_exists(legacy_path + ".v9"), "v9 migration preserves versioned original")
	var restored: Dictionary = migrated.pet.to_dict()
	check(restored.yard_record == 0, "legacy record starts empty")
	restored.erase("yard_record")
	check(JSON.parse_string(JSON.stringify(restored)) == JSON.parse_string(JSON.stringify(data)), "migration preserves every existing field")
	session.free()
	print("YARD FETCH RESULTS: %d passed, %d failed" % [passed, failed])
	quit(1 if failed else 0)

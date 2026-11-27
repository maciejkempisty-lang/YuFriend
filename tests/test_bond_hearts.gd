extends SceneTree
var failed := 0
var passed := 0
const NOW := 20000 * 86400.0 + 12 * 3600
func check(ok: bool, label: String) -> void:
	if ok: passed += 1
	else:
		failed += 1
		push_error(label)
func _initialize() -> void:
	thresholds()
	ledger()
	migration()
	rewards()
	sources()
	activity_sources()
	print("BOND HEARTS RESULTS: %d passed, %d failed" % [passed, failed])
	quit(1 if failed else 0)
func thresholds() -> void:
	var pet := PetState.create(42)
	for number in range(1, 12):
		var value := BondLevels.threshold(number)
		pet.bond = value - 0.01
		check(BondLevels.heart(pet) == number - 1 and BondLevels.progress(pet) < 100, "below heart %d" % number)
		BondLevels.add(pet, 0.01, NOW)
		check(BondLevels.heart(pet) == number and is_zero_approx(BondLevels.progress(pet)), "exact heart %d" % number)
		check(BondLevels.summary(pet) == "Nierozłączni ♥%d" % number, "title heart %d" % number)
	for pair in [[100, 1], [140, 2], [190, 3], [250, 4], [320, 5], [400, 6], [480, 7]]:
		pet.bond = pair[0]
		check(BondLevels.heart(pet) == pair[1], "specified threshold %d" % pair[0])
	pet.bond = 157.5
	check(is_equal_approx(BondLevels.progress(pet), 35), "progress is within current heart")
	pet.bond = 37.5
	check(is_equal_approx(BondLevels.progress(pet), 50), "early progress is within named level")
	pet.bond = 139.99
	check(BondLevels.detail(pet, NOW).contains("99%"), "no premature 100% rounding")
func ledger() -> void:
	var pet := PetState.create(42)
	pet.bond = 100
	BondLevels.add(pet, 0.6, NOW)
	BondLevels.add(pet, 0.35, NOW)
	BondLevels.add(pet, 1.5, NOW)
	check(is_equal_approx(BondLevels.today(pet, NOW), 2.45) and is_equal_approx(pet.bond, 102.45), "exact mixed gains above 100")
	pet = PetState.from_dict(pet.to_dict())
	check(is_equal_approx(BondLevels.today(pet, NOW), 2.45), "restart retains daily gain")
	var before := pet.to_dict()
	check(BondLevels.today(pet, NOW + 86400) == 0 and pet.to_dict() == before, "new day read does not change earned bond")
	BondLevels.add(pet, 0.5, NOW + 86400)
	BondLevels.add(pet, 0.5, NOW)
	check(BondLevels.today(pet, NOW) == 0 and BondLevels.today(pet, NOW + 86400) == 1, "rollback cannot reset latest ledger")
	before = pet.to_dict()
	for bad in [-1.0, 0.0, INF, NAN]: BondLevels.add(pet, bad, NOW)
	check(pet.to_dict() == before, "invalid gain never removes or corrupts progress")
	var invalid := pet.to_dict()
	invalid.bond_progress.earned = -1
	check(PetState.from_dict(invalid) == null, "invalid daily ledger rejected")
func migration() -> void:
	var pet := PetState.create(42, 1000)
	pet.pet_name = "Gloria"
	pet.bond = 100
	pet.skills.sit.mastery = 100
	pet.skills.paw.mastery = 57
	pet.practice.streak = 7
	pet.photos = [{"id": "abc123", "at": 1000, "caption": "Gloria"}]
	pet.decor = ["rug", "cushion", "flags"]
	pet.remember("first_bath", "Kąpiel", "Nasze wspomnienie")
	var legacy := pet.to_dict()
	legacy.erase("bond_progress")
	var original := legacy.duplicate(true)
	var path := preload("res://tests/helper_paths.gd").data_root() + "/yuf-bond-%s/pet.json" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify({"schema_version": 15, "pet": legacy}))
	file.close()
	var hash_value := FileAccess.get_sha256(path)
	var store := SaveSystem.new(path)
	var loaded := store.load_pet()
	check(loaded.writable and loaded.pet != null and loaded.pet.bond == 100, "v15 Gloria starts at heart one")
	var migrated: Dictionary = loaded.pet.to_dict()
	for key in original:
		check(JSON.parse_string(JSON.stringify({"value": migrated[key]})) == JSON.parse_string(JSON.stringify({"value": original[key]})), "migration preserves " + key)
	check(legacy == original and BondLevels.today(loaded.pet, NOW) == 0, "no mutation or invented historical daily gains")
	check(FileAccess.get_sha256(path + ".v15") == hash_value, "v15 archive is byte identical")
	BondLevels.add(loaded.pet, 57.5, NOW)
	check(store.save_pet(loaded.pet) and store.save_pet(loaded.pet), "new schema can save repeatedly")
	var roundtrip: PetState = store.load_pet().pet
	check(roundtrip.bond == 157.5 and BondLevels.today(roundtrip, NOW) == 57.5 and roundtrip.pet_id == pet.pet_id, "high bond ledger and identity survive disk reload")
	var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	check(raw.schema_version == SaveSystem.VERSION and FileAccess.get_sha256(path + ".v15") == hash_value, "new header and protected legacy archive")
	# A damaged new ledger must recover the last good high-bond backup.
	raw.pet.erase("bond_progress")
	file = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(raw))
	file.close()
	loaded = store.load_pet()
	check(loaded.status == "recovered" and loaded.pet.bond == 157.5, "corrupt v16 ledger recovers without resetting bond")
func rewards() -> void:
	var s := GameSession.new()
	s.pet = PetState.create(42)
	s.pet.bond = 100
	s.local_clock = func(): return NOW
	s.storage = SaveSystem.new(preload("res://tests/helper_paths.gd").data_root() + "/yuf-bond-rewards-%s/pet.json" % Time.get_ticks_usec())
	check(not KeepsakeSystem.unlock_reason(s.pet, "heart").is_empty(), "heart decor locked initially")
	BondLevels.add(s.pet, 40, NOW)
	check(s.pet.milestones.has("bond_heart_2"), "heart two creates memory")
	var voice := CompanionVoice.new()
	var seen := false
	for i in 12:
		if voice.describe(s, 46).text == BondLevels.thought(s.pet): seen = true
	check(seen, "unlocked thought appears in actual voice rotation")
	BondLevels.add(s.pet, 50, NOW)
	check(BondLevels.ritual(s) and BondLevels.HEART_RITUALS.has(s.last_message), "heart three plays new ritual")
	check(not BondLevels.ritual(s), "new ritual still limited once daily")
	var picture := Image.create(120, 120, false, Image.FORMAT_RGBA8)
	picture.fill(Color.BLUE)
	check(not KeepsakeSystem.save_photo(s, picture, "Za wcześnie", true), "frame locked before heart four")
	BondLevels.add(s.pet, 60, NOW)
	check(KeepsakeSystem.save_photo(s, picture, "Nasze serca", true), "heart four frame saves actual photo")
	var saved := Image.load_from_file(KeepsakeSystem.photo_path(s.storage.path, s.pet.photos[0].id))
	check(saved.get_pixel(0, 0) != Color.BLUE and picture.get_pixel(0, 0) == Color.BLUE and saved.get_pixel(60, 60) == Color.BLUE, "frame preserves original and photo center")
	BondLevels.add(s.pet, 70, NOW)
	check(KeepsakeSystem.toggle_decor(s, "heart") and s.storage.load_pet().pet.decor.has("heart"), "heart five decor can be selected and reloaded")
	var count := s.pet.milestones.size()
	BondLevels.add(s.pet, 10000, NOW)
	check(s.pet.milestones.size() == count + 1 and s.pet.milestones.has("bond_heart_latest"), "many hearts use only one recurring milestone")
	BondLevels.add(s.pet, 80, NOW)
	var entries := 0
	for entry in s.pet.journal:
		if entry.key == "bond_heart_latest":
			entries += 1
			check(entry.title == BondLevels.summary(s.pet), "latest keepsake reflects current heart")
	check(entries == 1 and s.pet.milestones.size() == count + 1, "latest keepsake updates without duplicate milestones")
	var before := s.pet.to_dict()
	s.storage.path = "/dev/null/yuf-bond-fail/pet.json"
	s.in_yard = true
	s.pet.yard_routines.mess = true
	before = s.pet.to_dict()
	check(not YardRoutines.clean_up(s) and s.pet.to_dict() == before, "failed save restores bond ledger and memories together")
	s.free()
func sources() -> void:
	var s := GameSession.new()
	s.pet = PetState.create(42)
	s.pet.bond = 100
	s.active = true
	s.local_clock = func(): return NOW
	s.storage = SaveSystem.new(preload("res://tests/helper_paths.gd").data_root() + "/yuf-bond-sources-%s/pet.json" % Time.get_ticks_usec())
	check(s.act("pet") and is_equal_approx(BondLevels.today(s.pet, NOW), 0.6), "petting reaches daily ledger")
	s.activity = "idle"
	s.activity_left = 0
	s.training.begin(s.pet, "come", true)
	s.training.advance(s.training.time_left)
	check(s.give_reward(s.pet.favorite_reward) and is_equal_approx(BondLevels.today(s.pet, NOW), 2.1), "training uses session day and ledger")
	var before := s.pet.bond
	for key in s.pet.practice.targets.duplicate(): PracticeSystem.record(s.pet, key, NOW)
	check(s.pet.bond == before + 2 and is_equal_approx(BondLevels.today(s.pet, NOW), 4.1), "daily completion counted once above 100")
	for key in s.pet.practice.targets.duplicate(): PracticeSystem.record(s.pet, key, NOW)
	check(is_equal_approx(BondLevels.today(s.pet, NOW), 4.1), "repeat daily plan gives no duplicate gain")
	s.free()
	# Compare actual unassisted decisions over the full roll range at low mastery.
	for i in range(101):
		var decisions := []
		for bond in [100.0, 10000.0]:
			var pet := PetState.create(42)
			pet.bond = bond
			var training := TrainingSystem.new()
			training.begin(pet, "come", false, i / 100.0)
			decisions.append(training.will_succeed)
		check(decisions[0] == decisions[1], "training balance unchanged at roll %d" % i)

func activity_sources() -> void:
	var s := GameSession.new()
	s.pet = PetState.create(42)
	s.pet.bond = 100
	s.active = true
	s.local_clock = func(): return NOW
	s.storage = SaveSystem.new(preload("res://tests/helper_paths.gd").data_root() + "/yuf-bond-activities-%s/pet.json" % Time.get_ticks_usec())
	s._brain_left = INF
	# Complete an ordinary touch game through its actual settlement entry point.
	s.play.kind = "tug"
	s.play.phase = "result"
	s.play.success = true
	s._settle_touch_game()
	check(is_equal_approx(BondLevels.today(s.pet, NOW), 0.35), "ordinary touch game credits today")
	s._settle_touch_game()
	check(is_equal_approx(BondLevels.today(s.pet, NOW), 0.35), "duplicate game settlement cannot credit today")
	s.activity = "idle"
	s.activity_left = 0
	s.play.reset()
	s.change_yard(true)
	s.pet.social.last_reward_at = 0
	check(s.throw_ball(Vector2(1100, 310), Vector2(700, 310)), "fetch begins")
	var fetch_token := s._approach_token
	s.arrive_at(fetch_token)
	s.catch_ball()
	s._process(YardFetch.PLAY_SECONDS + 0.1)
	s.finish_fetch_return(fetch_token)
	s._process(2)
	check(is_equal_approx(BondLevels.today(s.pet, NOW), 1.7), "fetch base and precision credit today")
	s.activity = "idle"
	s.activity_left = 0
	s.outdoor_commands.cancel()
	s.pet.social.last_reward_at = 0
	check(s.start_hide("dog", 2), "hide begins")
	var spot := s.hide_game.hiding_spot
	s._process(1.3)
	check(s.choose_hide_bush(spot), "hide finishes")
	check(is_equal_approx(BondLevels.today(s.pet, NOW), 2.2), "hide credits today")
	s.activity = "idle"
	s.activity_left = 0
	s.pet.yard_routines.mess = true
	check(YardRoutines.clean_up(s) and is_equal_approx(BondLevels.today(s.pet, NOW), 2.7), "cleanup credits today")
	check(not YardRoutines.clean_up(s) and is_equal_approx(BondLevels.today(s.pet, NOW), 2.7), "duplicate cleanup does not credit today")
	check(is_equal_approx(s.storage.load_pet().pet.bond_progress.earned, 2.7), "all activity gains persisted on session day")
	# A failed training save at a heart boundary must not award a heart or its memory.
	s.pet.bond = 139
	s.training.begin(s.pet, "come", true)
	s.training.advance(s.training.time_left)
	var before := s.pet.to_dict()
	s.storage.path = "/dev/null/yuf-bond-training/pet.json"
	check(not s.give_reward(s.pet.favorite_reward) and s.pet.to_dict() == before, "failed training save rolls back crossed heart and daily gain")
	s.free()

extends SceneTree
var failed := 0
var passed := 0
var now := 100 * 86400.0 + 12 * 3600
var directory := preload("res://tests/helper_paths.gd").data_root() + "/yuf-auto-sleep-%s" % Time.get_ticks_usec()
func check(ok: bool, label: String) -> void:
	if ok: passed += 1
	else:
		failed += 1
		push_error(label)
func game() -> GameSession:
	var s := GameSession.new()
	s.pet = PetState.create(42)
	s.storage = SaveSystem.new(directory.path_join("pet.json"))
	s.local_clock = func(): return now
	s.active = true
	s._brain_left = INF
	s.initiatives_enabled = false
	return s
func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(directory)
	var s := game()
	for offset in [-30, 0, 90, 180]:
		s.pet.rhythm.offset_minutes = offset
		var minutes := 0
		for minute in 1440:
			if DailyRhythm.should_sleep(s.pet, 100 * 86400.0 + minute * 60): minutes += 1
		check(minutes == 1080, "18h sleep for habit offset %d" % offset)
	s.pet.rhythm.offset_minutes = 0
	s.pet.needs.fullness = 22
	s.pet.needs.contact = 28
	s.pet.yard_routines.outday = 100
	now = 100 * 86400.0 + 13 * 3600
	s._tick_rhythm(20)
	s.destination_reached()
	check(s.scheduled_sleep and s.is_sleeping(), "day sleep starts without rest button")
	var before := s.pet.needs.duplicate()
	s._process(3600)
	check(s.is_sleeping() and s.pet.needs.energy >= before.energy, "sleep continues while energy recovers")
	check(is_equal_approx(before.fullness - s.pet.needs.fullness, 7 * 0.35), "sleep slows hunger decay")
	now = 100 * 86400.0 + 15 * 3600
	s._process(0.1)
	var voice := CompanionVoice.new().describe(s)
	check(not s.is_sleeping() and voice.kind == "wake" and voice.action == "feed", "wake bubble points to actual lowest need")
	check(voice.text.contains("zjeść") and voice.text.contains("głaski"), "wake report includes two real needs")
	s.wake_report_left = 0
	s._sync_rhythm_on_return()
	check(s.wake_report_left == 0, "reopen does not repeat same wake announcement")
	var saved: PetState = s.storage.load_pet().pet
	check(saved.rhythm.wake_notice_at == s.pet.rhythm.wake_notice_at, "announcement watermark survives restart")
	now = 100 * 86400.0 + 16 * 3600
	s._sync_rhythm_on_return()
	check(s.is_sleeping(), "return during afternoon nap stays asleep")
	s.act("pet")
	var until: float = s.pet.rhythm.awake_until
	s._sync_rhythm_on_return()
	check(not s.is_sleeping() and s.pet.rhythm.awake_until == until, "short visit persists through return")
	now += 601
	s._sync_rhythm_on_return()
	check(s.is_sleeping(), "visit expires even across background time")
	# An abandoned result panel must not keep the dog awake all afternoon.
	s._wake()
	s.play.start("cups")
	s.play.phase = "result"
	s.play.settled = true
	s.activity = "idle"
	now += 601
	s._tick_rhythm(20)
	s.destination_reached()
	check(s.play.kind.is_empty() and s.is_sleeping(), "finished game result cannot block automatic sleep")
	var offline := PetState.create(42, 100 * 86400.0 + 6 * 3600)
	offline.needs.energy = 50
	NeedsSystem.catch_up_rhythm(offline, 100 * 86400.0 + 10 * 3600, 100 * 86400.0 + 10 * 3600)
	check(is_equal_approx(offline.needs.energy, 66), "offline crosses wake, sleep, wake with exact recovery")
	check(offline.resting, "offline current hour determines sleeping state")
	var frozen := offline.needs.duplicate()
	NeedsSystem.catch_up_rhythm(offline, offline.last_seen_at - 100, 100 * 86400.0 + 10 * 3600 - 100)
	check(offline.needs == frozen, "clock rollback never changes needs")
	var legacy := s.pet.to_dict()
	legacy.rhythm.erase("awake_until")
	legacy.rhythm.erase("wake_notice_at")
	var path := directory.path_join("legacy.json")
	var raw := JSON.stringify({"schema_version": 16, "pet": legacy})
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(raw)
	file.close()
	var store := SaveSystem.new(path)
	var loaded := store.load_pet()
	check(loaded.writable and loaded.pet.pet_id == s.pet.pet_id, "v16 migration keeps pet identity")
	var migrated: Dictionary = loaded.pet.to_dict()
	migrated.rhythm.erase("awake_until")
	migrated.rhythm.erase("wake_notice_at")
	check(JSON.parse_string(JSON.stringify(migrated)) == JSON.parse_string(raw).pet, "all existing progress fields survive migration")
	check(FileAccess.get_file_as_string(path + ".v16") == raw, "original v16 save retained byte for byte")
	for field in ["awake_until", "wake_notice_at"]:
		for invalid in [-1, NAN, "bad"]:
			var data := s.pet.to_dict()
			data.rhythm[field] = invalid
			check(PetState.from_dict(data) == null, "invalid sleep persistence rejected")
	s.free()
	for name in DirAccess.get_files_at(directory): DirAccess.remove_absolute(directory.path_join(name))
	DirAccess.remove_absolute(directory)
	print("AUTO SLEEP RESULTS: %d passed, %d failed" % [passed, failed])
	quit(1 if failed else 0)

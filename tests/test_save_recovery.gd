extends SceneTree
var failed := 0
var passed := 0
func check(ok: bool, label: String) -> void:
	if ok: passed += 1
	else:
		failed += 1
		push_error(label)
func write(path: String, data: Dictionary, version: int) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify({"schema_version": version, "pet": data}))
	file.close()
func _initialize() -> void:
	var dir := "/tmp/yuf-recovery-%s" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(dir)
	var pet := PetState.create(42)
	PracticeSystem.sync(pet, 100 * 86400)
	pet.practice.streak = 7
	var original := pet.to_dict()
	for field in ["practice", "photos", "decor", "rhythm"]:
		var path := dir.path_join(field + ".json")
		var damaged := original.duplicate(true)
		damaged.erase(field)
		write(path, damaged, 9)
		write(path + ".bak", original, 9)
		var store := SaveSystem.new(path)
		var loaded := store.load_pet()
		check(loaded.status == "recovered" and loaded.pet.practice.streak == 7, "recover missing required " + field)
		check(store.save_pet(loaded.pet), "save recovered " + field)
		var backup: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path + ".bak"))
		check(backup.pet.has(field) and backup.pet.practice.streak == 7, "retain valid backup " + field)
	var path := dir.path_join("rollback.json")
	var older := original.duplicate(true)
	older.skills.sit.mastery = 20
	original.skills.sit.mastery = 80
	write(path, original, 9)
	write(path + ".v9", older, 9)
	var hash_value := FileAccess.get_sha256(path)
	var store := SaveSystem.new(path)
	var loaded := store.load_pet()
	check(loaded.writable and loaded.pet.skills.sit.mastery == 80, "load newer rollback state")
	check(store.save_pet(loaded.pet) and store.save_pet(loaded.pet), "two autosaves")
	check(FileAccess.file_exists(path + ".v9." + hash_value), "retain fresh versioned source")
	check(FileAccess.get_sha256(path + ".v9." + hash_value) == hash_value, "archive is byte identical")
	print("SAVE RECOVERY RESULTS: %d passed, %d failed" % [passed, failed])
	quit(1 if failed else 0)

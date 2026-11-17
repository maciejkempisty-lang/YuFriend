extends SceneTree
var failed := 0
func check(ok: bool, label: String) -> void:
	if not ok:
		failed += 1
		push_error(label)
	else: print("PASS KEEPSAKES " + label)
func _initialize() -> void:
	var pet := PetState.create(11, 1000)
	pet.skills.sit.mastery = 100
	pet.skills.paw.mastery = 57
	pet.remember("yard_find_0", "Kamyk", "Znalezisko")
	pet.remember("first_bath", "Kąpiel", "Wspomnienie")
	var legacy := pet.to_dict()
	legacy.erase("photos")
	legacy.erase("decor")
	legacy.skills.erase("spin")
	legacy.skills.erase("roll")
	var copy: Dictionary = legacy.duplicate(true)
	var path := "/tmp/yuf-keepsakes-%s/pet.json" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify({"schema_version": 7, "pet": legacy}))
	file.close()
	var store := SaveSystem.new(path)
	var loaded := store.load_pet()
	check(loaded.pet != null and loaded.pet.pet_id == pet.pet_id and loaded.pet.skills.paw.mastery == 57 and loaded.pet.milestones.has("first_bath"), "v7 file preserves identity skills and memories")
	check(loaded.pet.photos.is_empty() and loaded.pet.decor.is_empty() and loaded.pet.skills.spin.mastery == 0, "migration adds empty extras")
	check(FileAccess.file_exists(path + ".v7") and legacy == copy, "migration backs up original and does not mutate input")
	check(not TrainingSystem.unlock_reason(loaded.pet, "spin").is_empty(), "spin requires mastered bow")
	loaded.pet.skills.bow.mastery = 100
	check(TrainingSystem.unlock_reason(loaded.pet, "spin").is_empty(), "mastered bow unlocks spin")
	var game := GameSession.new()
	game.pet = loaded.pet
	game.storage = store
	check(KeepsakeSystem.toggle_decor(game, "flower") and game.pet.decor.has("flower"), "find unlocks persistent flower")
	var fresh := PetState.create(22, 1000)
	check(not KeepsakeSystem.unlock_reason(fresh, "shelf").is_empty(), "trophy shelf requires mastery")
	var picture := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	picture.fill(Color.CORAL)
	check(KeepsakeSystem.save_photo(game, picture, "Pamiątka"), "photo writes image and metadata")
	var photo: Dictionary = game.pet.photos[0]
	check(FileAccess.file_exists(KeepsakeSystem.photo_path(path, photo.id)), "saved photo exists beside pet data")
	var roundtrip: PetState = store.load_pet().pet
	check(roundtrip.photos.size() == 1 and roundtrip.decor.has("flower") and roundtrip.skills.paw.mastery == 57, "reload keeps photos decorations and progress together")
	var malformed: Dictionary = game.pet.to_dict()
	malformed.photos[0].id = "../../other"
	check(PetState.from_dict(malformed) == null and KeepsakeSystem.photo_path(path, "../bad").is_empty(), "unsafe photo paths rejected")
	var count := game.pet.photos.size()
	game.writable = false
	check(not KeepsakeSystem.save_photo(game, picture, "Blocked") and game.pet.photos.size() == count, "read-only save cannot add photo")
	check(not KeepsakeSystem.toggle_decor(game, "rug"), "read-only save cannot alter decoration")
	game.writable = true
	var protected := FileAccess.open(path, FileAccess.WRITE)
	protected.store_string(JSON.stringify({"schema_version": 99, "pet": game.pet.to_dict()}))
	protected.close()
	var originals := DirAccess.get_files_at(path.get_base_dir().path_join("photos"))
	check(not KeepsakeSystem.save_photo(game, picture, "Failed") and game.pet.photos.size() == count, "failed save rolls back new photo metadata")
	check(DirAccess.get_files_at(path.get_base_dir().path_join("photos")) == originals, "failed save removes only its new image")
	var old_decor := game.pet.decor.duplicate()
	check(not KeepsakeSystem.toggle_decor(game, "rug") and game.pet.decor == old_decor, "failed save restores prior decorations")
	for i in 23: game.pet.photos.append({"id": "%x" % i, "at": 1000, "caption": "Test"})
	check(not KeepsakeSystem.save_photo(game, picture, "Full") and game.pet.photos.size() == 24, "full album never replaces existing photo")
	game.free()
	print("KEEPSAKES FAILURES: ", failed)
	quit(1 if failed else 0)

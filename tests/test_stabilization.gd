extends SceneTree
var failed := 0
var passed := 0
func check(ok: bool, label: String) -> void:
	if ok: passed += 1
	else:
		failed += 1
		push_error(label)
func _initialize() -> void:
	var game := GameSession.new()
	game.pet = PetState.create(42)
	game.local_clock = func(): return 100 * 86400.0 + 12 * 3600
	game.active = true
	game._brain_left = INF
	game.change_yard(true)
	game.pet.needs.energy = 15
	game._process(0.1)
	check(not game.in_yard and game.activity == "approach", "tired dog returns home and approaches bed")
	game.arrive_at(game._approach_token)
	check(game.is_sleeping(), "arrival starts real rest")
	game.free()
	game = GameSession.new()
	game.pet = PetState.create(42)
	game.pet.needs.hygiene = 40
	game.pet.needs.energy = 15
	check(not game.start_bath(), "exhausted dog cannot start bath")
	game.pet.needs.energy = 60
	game.pet.needs.fullness = 15
	check(not game.start_bath(), "hungry dog cannot start bath")
	game.pet.needs.fullness = 60
	check(game.start_bath(), "ready dirty dog can bathe")
	game.cancel_bath()
	check(game.pet.needs.energy == 60 and game.pet.needs.hygiene == 40, "cancelled bath has no cost or gain")
	game.start_bath()
	game.bath.stage = 3
	check(game.finish_bath() and game.pet.needs.hygiene == 85 and game.pet.needs.energy == 55 and game.pet.needs.fullness == 58, "completed bath applies bounded cleanliness and costs")
	check(not game.finish_bath() and game.pet.needs.energy == 55, "duplicate completion cannot charge twice")
	game.cancel_bath()
	check(not game.start_bath(), "clean dog is directed to brushing instead of repeated baths")
	var path := "/tmp/yuf-stabilization-%s/pet.json" % Time.get_ticks_usec()
	game.storage = SaveSystem.new(path)
	game.pet.skills.sit.mastery = 100
	game.pet.yard_record = 4.5
	var picture := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	picture.fill(Color.CORAL)
	KeepsakeSystem.save_photo(game, picture, "Pierwsze")
	KeepsakeSystem.save_photo(game, picture, "Drugie")
	var id: String = game.pet.photos[0].id
	var other: String = game.pet.photos[1].id
	check(KeepsakeSystem.remove_photo(game, id), "photo can be removed")
	check(game.pet.photos.size() == 1 and game.pet.photos[0].id == other, "only selected photo leaves album")
	check(FileAccess.file_exists(KeepsakeSystem.photo_path(path, id)), "image remains available to recovery backups")
	var loaded := game.storage.load_pet()
	check(loaded.pet.photos.size() == 1 and loaded.pet.skills.sit.mastery == 100 and loaded.pet.yard_record == 4.5, "deletion persists without affecting progress")
	check(not KeepsakeSystem.remove_photo(game, id), "duplicate deletion rejected")
	check(not KeepsakeSystem.remove_photo(game, "../escape"), "unsafe id rejected")
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify({"schema_version": 99, "pet": game.pet.to_dict()}))
	f.close()
	check(not KeepsakeSystem.remove_photo(game, other) and game.pet.photos.size() == 1, "failed save restores photo metadata")
	check(FileAccess.file_exists(KeepsakeSystem.photo_path(path, other)), "failed removal never loses file")
	game.free()
	print("STABILIZATION RESULTS: %d passed, %d failed" % [passed, failed])
	quit(1 if failed else 0)

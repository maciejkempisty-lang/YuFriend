extends SceneTree
var failed := 0
var passed := 0
func check(ok: bool, label: String) -> void:
	if ok: passed += 1
	else:
		failed += 1
		push_error(label)
func _initialize() -> void:
	var s := YardRoutines.initial()
	s.plant = "daisy"
	s.checked_at = 100
	s.water_until = 86500
	YardRoutines.update(s, 100 + 10 * 86400)
	check(s.growth == 86400, "absence grants only watered growth")
	YardRoutines.update(s, 200)
	check(s.growth == 86400, "rollback never adds growth")
	check(YardRoutines.valid(s), "state validates")
	s.flowers = ["daisy", "daisy"]
	check(not YardRoutines.valid(s), "duplicate flowers rejected")
	var game := GameSession.new()
	game.pet = PetState.create(42)
	game.storage = SaveSystem.new("/tmp/yuf-routines-%s/pet.json" % Time.get_ticks_usec())
	game.local_clock = func(): return 100 * 86400.0 + 12 * 3600
	game.active = true
	game._brain_left = INF
	game.change_yard(true)
	check(YardRoutines.garden(game, "daisy"), "plant seed")
	check(not YardRoutines.garden(game, "poppy"), "cannot overwrite planted bed")
	check(YardRoutines.garden(game, "water"), "water plant")
	check(not YardRoutines.garden(game, "water"), "cannot stack water")
	game.pet.yard_routines.growth = YardRoutines.GROW_TIME
	check(YardRoutines.garden(game, "harvest"), "collect mature flower")
	check(game.pet.yard_routines.flowers == ["daisy"] and KeepsakeSystem.unlock_reason(game.pet, "flower") == "", "collection unlocks decor")
	check(not YardRoutines.garden(game, "harvest"), "harvest cannot repeat")
	check(YardRoutines.start_outing(game), "outing starts")
	check(not YardRoutines.praise(game), "cannot praise before arrival")
	game.destination_reached()
	game._process(4.1)
	check(game.activity == "outing_praise", "private pause ends at praise")
	var bond := game.pet.bond
	check(YardRoutines.praise(game) and game.pet.bond == bond + 0.5, "daily praise reward")
	check(not YardRoutines.start_outing(game), "daily repeat blocked")
	game.local_clock = func(): return 99 * 86400.0 + 12 * 3600
	check(not YardRoutines.due(game), "clock rollback cannot renew reward")
	var loaded := game.storage.load_pet()
	check(loaded.pet.yard_routines.flowers == ["daisy"] and loaded.pet.yard_routines.outday == 100, "garden and outing survive restart")
	game.local_clock = func(): return 101 * 86400.0 + 12 * 3600
	check(YardRoutines.start_outing(game), "next day offers outing")
	game.change_yard(false)
	game.destination_reached()
	check(not YardRoutines.praise(game) and game.pet.yard_routines.outday == 100, "cancelled outing grants nothing")
	game.change_yard(true)
	var preserved := game.pet.to_dict()
	var file := FileAccess.open(game.storage.path, FileAccess.WRITE)
	file.store_string(JSON.stringify({"schema_version": 99, "pet": preserved}))
	file.close()
	check(not YardRoutines.garden(game, "poppy") and game.pet.to_dict() == preserved, "failed save restores garden and all progress")
	var old := game.pet.to_dict()
	old.erase("yard_routines")
	var migrated := SaveSystem.migrate(old, 11)
	for key in old: check(migrated[key] == old[key], "migration preserves " + key)
	check(PetState.from_dict(migrated) != null, "v11 migrates")
	check(PetState.from_dict(old) == null, "v12 missing routines rejected")
	game.free()
	print("ROUTINES RESULTS: %d passed, %d failed" % [passed, failed])
	quit(1 if failed else 0)

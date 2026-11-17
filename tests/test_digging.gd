extends SceneTree
var passed := 0
var failed := 0
func check(ok: bool, label: String) -> void:
	if ok: passed += 1
	else:
		failed += 1
		push_error(label)
func _initialize() -> void:
	var s := GameSession.new()
	s.pet = PetState.create(42)
	s.storage = SaveSystem.new("/tmp/yuf-dig-%s/pet.json" % Time.get_ticks_usec())
	s.local_clock = func(): return 100 * 86400.0 + 12 * 3600
	s.active = true
	s._brain_left = INF
	s.change_yard(true)
	var before := s.pet.to_dict()
	check(DiggingSystem.start(s), "dig starts")
	s.change_yard(false)
	s.destination_reached()
	check(not DiggingSystem.finish(s) and s.pet.to_dict() == before, "cancel before arrival preserves state")
	s.change_yard(true)
	for i in 3:
		check(DiggingSystem.start(s), "daily attempt starts")
		s.destination_reached()
		check(s.activity == "digging", "arrive starts digging")
		s._process(4.1)
		check(s.pet.exploration.rounds == i + 1, "completion consumes one attempt")
		check(not DiggingSystem.finish(s), "duplicate completion ignored")
	check(not DiggingSystem.start(s), "fourth attempt blocked")
	check(s.pet.exploration.items.size() > 0 and s.pet.bond == before.bond, "dig grants collection not bond farming")
	check(s.storage.load_pet().pet.exploration == s.pet.exploration, "collection and limits persist")
	s.local_clock = func(): return 99 * 86400.0 + 12 * 3600
	check(not DiggingSystem.start(s), "rollback cannot renew attempts")
	s.pet.exploration.tokens = 3
	var missing := ""
	for id in DiggingSystem.ITEMS:
		if not s.pet.exploration.items.has(id): missing = id; break
	check(DiggingSystem.exchange(s, missing), "three duplicates buy selected missing item")
	check(s.pet.exploration.tokens == 0 and s.pet.exploration.items.has(missing), "exchange spends once")
	check(not DiggingSystem.exchange(s, missing), "cannot buy owned item again")
	for value in [0, 24, 25, 49, 50, 74, 75, 99, 100]:
		s.pet.bond = value
		check(BondLevels.level(s.pet) == mini(4, int(value / 25)), "bond threshold %d" % value)
	s.pet.bond = 12
	check(not KeepsakeSystem.unlock_reason(s.pet, "cushion").is_empty(), "new decor locked below threshold")
	check(KeepsakeSystem.unlock_reason(s.pet, "rug").is_empty(), "old decoration remains available")
	s.pet.bond = 75
	check(KeepsakeSystem.unlock_reason(s.pet, "cushion").is_empty() and KeepsakeSystem.unlock_reason(s.pet, "flags").is_empty(), "existing high bond unlocks both")
	check(BondLevels.ritual(s), "bond ritual works")
	check(not BondLevels.ritual(s), "ritual limited daily")
	var original := s.pet.to_dict()
	original.erase("exploration")
	var migrated := SaveSystem.migrate(original, 12)
	for key in original: check(original[key] == migrated[key], "v12 preserves " + key)
	check(PetState.from_dict(migrated) != null, "v12 migration valid")
	check(PetState.from_dict(original) == null, "v13 missing collection rejected")
	s.free()
	print("DIG RESULTS: %d passed, %d failed" % [passed, failed])
	quit(1 if failed else 0)

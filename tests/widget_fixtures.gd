extends SceneTree

# The real Godot rules are the oracle for the native offline projection.
func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 1:
		quit(1)
		return
	var fixtures: Array = []
	for sociability in [0.0, 0.5, 1.0]:
		for energy in [0.0, 15.0, 55.0, 84.9995, 85.0, 100.0]:
			for sleeping in [false, true]:
				for elapsed in [-100.0, 0.0, 1.0, 1800.0, 7200.0, 28800.0, 604800.0]:
					var pet := PetState.create(42, 1000000)
					pet.pet_name = "Łapek"
					pet.needs = {"fullness": 26.0, "energy": energy, "hygiene": 100.0, "play": 0.0, "contact": 55.0}
					pet.traits.sociability = sociability
					pet.resting = sleeping
					var save := {"schema_version": 16, "pet": pet.to_dict()}
					NeedsSystem.catch_up(pet, 1000000 + elapsed)
					fixtures.append({"save": save, "at": 1000000 + elapsed, "needs": pet.needs.duplicate(), "resting": pet.resting})
	for offset in [-30, 0, 90, 180]:
		for hour in [0, 6, 7, 9, 12, 13, 21, 22]:
			for elapsed in [-100, 0, 1, 1800, 7200, 28800, 604800]:
				for override in [false, true]:
					var start: float = 100 * 86400.0 + hour * 3600
					var pet := PetState.create(42, start)
					pet.rhythm.offset_minutes = offset
					pet.rhythm.awake_until = start + 600 if override else 0.0
					pet.needs.energy = 55
					var save := {"schema_version": SaveSystem.VERSION, "pet": pet.to_dict()}
					NeedsSystem.catch_up_rhythm(pet, start + elapsed, start + elapsed)
					fixtures.append({"save": save, "at": start + elapsed, "needs": pet.needs.duplicate(), "resting": pet.resting, "utc": true})
	var output := FileAccess.open(args[0], FileAccess.WRITE)
	if output == null:
		quit(1)
		return
	output.store_string(JSON.stringify(fixtures))
	output.close()
	print("Exported %d widget parity fixtures" % fixtures.size())
	quit(0)

class_name BondLevels
extends RefCounted

const THRESHOLDS := [0, 25, 50, 75, 100]
const NAMES := ["Poznajecie się", "Zaufanie", "Przyjaźń", "Bliskość", "Nierozłączni"]
static func level(pet: PetState) -> int:
	var result := 0
	for i in THRESHOLDS.size():
		if pet.bond >= THRESHOLDS[i]: result = i
	return result
static func summary(pet: PetState) -> String:
	var current := level(pet)
	return "%s · %d%%" % [NAMES[current], roundi(pet.bond)]
# Existing daily history persists the budget without a save migration.
# Touch keeps responding after the bond budget is spent.
static func petting_gain(pet: PetState, now: float) -> float:
	var count := 0
	var day := PersonalitySystem.day_of(now)
	if not pet.history.is_empty():
		var bucket: Dictionary = pet.history[-1]
		if int(bucket.day) >= day: count = int(bucket.events.get("pet", 0))
	return 0.6 if count < 5 else (0.1 if count < 10 else 0.0)

static func ritual(s: GameSession) -> bool:
	var day := PersonalitySystem.day_of(s._local_now())
	if not s.writable or s.suspended or s.busy(false) or s.is_sleeping() or s.pet.bond < 75 or day <= int(s.pet.exploration.ritual_day): return false
	var before := s.pet.to_dict()
	s.pet.exploration.ritual_day = day
	NeedsSystem.change(s.pet, {"contact": 8})
	if not s.flush():
		s.pet = PetState.from_dict(before)
		return false
	if s.visitors.active(): s.visitors.finish(s, "Gość rusza dalej. Teraz czas dla Was.")
	s.clip_requested.emit("petted_stand")
	s.say("Nasza spokojna chwila. Dobrze być razem.")
	s.changed.emit()
	return true

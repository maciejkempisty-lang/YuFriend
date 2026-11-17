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
static func ritual(s: GameSession) -> bool:
	var day := PersonalitySystem.day_of(s._local_now())
	if not s.writable or s.suspended or s.busy() or s.is_sleeping() or s.pet.bond < 75 or day <= int(s.pet.exploration.ritual_day): return false
	var before := s.pet.to_dict()
	s.pet.exploration.ritual_day = day
	NeedsSystem.change(s.pet, {"contact": 8})
	if not s.flush():
		s.pet = PetState.from_dict(before)
		return false
	s.clip_requested.emit("petted_stand")
	s.say("Nasza spokojna chwila. +8 bliskości, raz dziennie.")
	s.changed.emit()
	return true

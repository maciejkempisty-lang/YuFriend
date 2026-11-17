class_name VisitorMemory
extends RefCounted

# Bounded, existing milestone records keep old v14 saves compatible.
# Local day is in the key; journal timestamps remain real UTC timestamps.
const LIMIT := 3

static func known(pet: PetState, guest: String) -> bool:
	return pet.milestones.has("visitor_%s_met" % guest)

static func days(pet: PetState, guest: String) -> Array[int]:
	var result: Array[int] = []
	var prefix := "visitor_%s_calm_" % guest
	for key in pet.milestones:
		if not str(key).begins_with(prefix): continue
		var suffix := str(key).trim_prefix(prefix)
		if suffix.is_valid_int() and int(suffix) >= 0 and int(suffix) not in result:
			result.append(int(suffix))
	return result

static func level(pet: PetState, guest: String) -> int:
	return mini(LIMIT, days(pet, guest).size())

static func describe(pet: PetState, guest: String) -> String:
	if not known(pet, guest): return "Jeszcze się nie poznali"
	return ["Znajomy widok", "Pierwsze spokojne spotkanie", "Coraz swobodniej", "Dobrze znany gość"][level(pet, guest)]

static func record(s: GameSession, guest: String, peaceful: bool) -> bool:
	if guest not in YardVisitors.KINDS or not s.writable or s.suspended: return false
	var before := s.pet.to_dict()
	var changed := s.pet.remember("visitor_%s_met" % guest, YardVisitors.LABELS[guest], "Pierwsze spotkanie przy płocie. Każda znajomość zaczyna się od ciekawości.")
	if peaceful:
		var completed := days(s.pet, guest)
		var day := int(floor(s._local_now() / 86400.0))
		var latest := -1
		for previous in completed: latest = maxi(latest, previous)
		if completed.size() < LIMIT and day > latest:
			changed = s.pet.remember("visitor_%s_calm_%d" % [guest, day], "%s · spokojne spotkanie" % YardVisitors.LABELS[guest], "Wspólne uspokojenie lub powrót do opiekuna pomogły oswoić znajomego gościa.") or changed
	if not changed: return false
	if not s.flush():
		s.pet = PetState.from_dict(before)
		return false
	return true

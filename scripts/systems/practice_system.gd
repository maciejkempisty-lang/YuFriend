class_name PracticeSystem
extends RefCounted

const LOSS_PER_MISSED_DAY := 10.0
const MIN_FORM := 50.0
const PRACTICE_GAIN := 25.0

static func initial() -> Dictionary:
	var forms := {}
	for key in PetState.TRICK_KEYS: forms[key] = {"value": 100.0, "practiced_day": -1}
	return {"day": -1, "forms": forms, "targets": [], "done": [], "rewarded": false,
		"streak": 0, "total_days": 0, "last_completed": -1}

static func valid(value: Variant) -> bool:
	if not value is Dictionary or not value.get("forms") is Dictionary: return false
	for key in ["day", "streak", "total_days", "last_completed"]:
		if not PetState.valid_number(value.get(key)) or value[key] != floor(value[key]) or value[key] < (-1 if key in ["day", "last_completed"] else 0): return false
	if not value.get("rewarded") is bool: return false
	for key in PetState.TRICK_KEYS:
		var form: Variant = value.forms.get(key)
		if not form is Dictionary or not PetState.valid_number(form.get("value")) or form.value < MIN_FORM or form.value > 100: return false
		if not PetState.valid_number(form.get("practiced_day")) or form.practiced_day < -1 or form.practiced_day != floor(form.practiced_day): return false
	for key in ["targets", "done"]:
		if not value.get(key) is Array or value[key].size() > 3: return false
		var seen := {}
		for trick in value[key]:
			if not trick is String or not PetState.TRICK_KEYS.has(trick) or seen.has(trick): return false
			seen[trick] = true
	for trick in value.done:
		if not value.targets.has(trick): return false
	return true

static func sync(pet: PetState, local_seconds: float) -> bool:
	var day := PersonalitySystem.day_of(local_seconds)
	var state: Dictionary = pet.practice
	if day <= int(state.day): return false # A clock rollback cannot repeat a day or its reward.
	for key in PetState.TRICK_KEYS:
		var form: Dictionary = state.forms[key]
		if float(pet.skills[key].mastery) < 100:
			form.value = 100.0
			form.practiced_day = day
		elif int(state.day) < 0:
			form.practiced_day = day # No retroactive penalty on upgrade.
		else:
			var missed := maxi(0, day - maxi(int(state.day), int(form.practiced_day) + 1))
			form.value = maxf(MIN_FORM, float(form.value) - missed * LOSS_PER_MISSED_DAY)
	state.day = day
	state.done = []
	state.rewarded = false
	if day > int(state.last_completed) + 1: state.streak = 0
	var available: Array = []
	for key in PetState.TRICK_KEYS:
		if TrainingSystem.unlock_reason(pet, key).is_empty(): available.append(key)
	available.sort_custom(func(a, b):
		var left: Dictionary = state.forms[a]
		var right: Dictionary = state.forms[b]
		if left.value != right.value: return left.value < right.value
		if left.practiced_day != right.practiced_day: return left.practiced_day < right.practiced_day
		return posmod(PetState.TRICK_KEYS.find(a) - day, PetState.TRICK_KEYS.size()) < posmod(PetState.TRICK_KEYS.find(b) - day, PetState.TRICK_KEYS.size()))
	state.targets = available.slice(0, mini(3, available.size()))
	return true

static func record(pet: PetState, key: String, local_seconds: float) -> bool:
	sync(pet, local_seconds)
	var state: Dictionary = pet.practice
	var form: Dictionary = state.forms[key]
	form.value = minf(100, float(form.value) + PRACTICE_GAIN)
	form.practiced_day = int(state.day)
	if state.targets.has(key) and not state.done.has(key): state.done.append(key)
	if state.rewarded or state.targets.is_empty() or state.done.size() != state.targets.size(): return false
	state.rewarded = true
	state.streak = int(state.streak) + 1 if int(state.last_completed) == int(state.day) - 1 else 1
	state.last_completed = int(state.day)
	state.total_days = int(state.total_days) + 1
	pet.bond = minf(100, pet.bond + 2.0)
	return true

static func form(pet: PetState, key: String) -> float:
	return float(pet.practice.forms[key].value) if float(pet.skills[key].mastery) >= 100 else 100.0

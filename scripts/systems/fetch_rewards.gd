class_name FetchRewards
extends RefCounted

const DAILY_LIMIT := 3
static func initial() -> Dictionary:
	return {"day": -1, "base": 0, "precise": 0}
static func valid(value: Variant) -> bool:
	if not value is Dictionary: return false
	for key in ["day", "base", "precise"]:
		if not PetState.valid_number(value.get(key)) or value[key] != floor(value[key]): return false
		if value[key] < (-1 if key == "day" else 0): return false
		if key != "day" and value[key] > DAILY_LIMIT: return false
	return true
static func award(pet: PetState, precise: bool, local_seconds: float) -> Dictionary:
	var day := PersonalitySystem.day_of(local_seconds)
	var state := pet.fetch_rewards
	if day < int(state.day): return {"bond": 0.0, "bonus": false}
	if day > int(state.day):
		state.day = day
		state.base = 0
		state.precise = 0
	var bond := 0.0
	if int(state.base) < DAILY_LIMIT:
		state.base = int(state.base) + 1
		bond += 0.35
	var bonus := precise and int(state.precise) < DAILY_LIMIT
	if bonus:
		state.precise = int(state.precise) + 1
		bond += 1.0
	return {"bond": bond, "bonus": bonus}

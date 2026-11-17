class_name DailyAdventure
extends RefCounted

const TASKS := {"garden": "Zadbaj o ogródek", "trick": "Wykonaj i nagródź dowolną sztuczkę", "treasure": "Ukończ węszenie lub kopanie"}
const PLANS := [["garden", "trick"], ["trick", "treasure"], ["garden", "treasure"]]
const TITLES := ["Ogród pełen sztuczek", "Tropem łapek", "Skarby wśród kwiatów"]
const HINTS := {"garden": "Posadź, podlej, zbierz kwiat lub obejrzyj grządkę.", "trick": "Dowolna dostępna sztuczka z nagrodą — w Treningu lub zabawie na podwórku.", "treasure": "Znajomy skarb też się liczy. Wybierz krzaki lub piaskownicę."}

static func initial() -> Dictionary:
	return {"day": -1, "done": [], "rewarded": false}

static func valid(value: Variant) -> bool:
	if not value is Dictionary or not PetState.valid_number(value.get("day")): return false
	if value.day < -1 or value.day != floor(value.day): return false
	if not value.get("rewarded") is bool or not value.get("done") is Array or value.done.size() > 2: return false
	if value.day == -1: return value.done.is_empty() and not value.rewarded
	var plan: Array = PLANS[int(value.day) % PLANS.size()]
	var seen := []
	for task in value.done:
		if task not in plan or task in seen: return false
		seen.append(task)
	return value.rewarded == (value.done.size() == 2)

static func view(pet: PetState, local_seconds: float) -> Dictionary:
	var state := pet.adventure.duplicate(true)
	var day := PersonalitySystem.day_of(local_seconds)
	if day > int(state.day): state = {"day": day, "done": [], "rewarded": false}
	return state

# Called only by successful activity commits, before their shared save/rollback.
static func record(pet: PetState, task: String, local_seconds: float) -> bool:
	if task not in TASKS: return false
	var day := PersonalitySystem.day_of(local_seconds)
	if day < int(pet.adventure.day): return false
	pet.adventure = view(pet, local_seconds)
	var state := pet.adventure
	var index := day % PLANS.size()
	if task not in PLANS[index] or task in state.done or state.rewarded: return false
	state.done.append(task)
	if state.done.size() < 2: return false
	state.rewarded = true
	var key := "adventure_%d" % index
	var detail := "Wspólna przygoda: %s i %s. Bez pośpiechu, we własnym rytmie." % [TASKS[PLANS[index][0]].to_lower(), TASKS[PLANS[index][1]].to_lower()]
	if not pet.remember(key, TITLES[index], detail):
		pet.add_journal_entry("adventure_recent", "Kolejna przygoda: " + TITLES[index], detail, Time.get_unix_time_from_system())
	return true

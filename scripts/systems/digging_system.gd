class_name DiggingSystem
extends RefCounted

# Stable IDs, weights and labels; old collections remain valid when labels change.
const ITEMS := {
	"bone": ["Mała kość", 6], "cap": ["Kolorowy kapsel", 6], "button": ["Drewniany guzik", 6],
	"stone": ["Kamyk w paski", 6], "acorn": ["Żołądź", 6], "shell": ["Muszelka", 6],
	"key": ["Stary klucz", 3], "marble": ["Szklana kulka", 3], "bell": ["Dzwoneczek", 3],
	"tile": ["Kawałek mozaiki", 3], "coin": ["Moneta z łapką", 1], "heart": ["Kamienne serce", 1]}
const DAILY_LIMIT := 3
static func initial() -> Dictionary:
	return {"items": {}, "tokens": 0, "day": -1, "rounds": 0, "total": 0, "ritual_day": -1}
static func valid(value: Variant) -> bool:
	if not value is Dictionary or not value.get("items") is Dictionary or value.items.size() > ITEMS.size(): return false
	for key in ["tokens", "day", "rounds", "total", "ritual_day"]:
		if not PetState.valid_number(value.get(key)) or value[key] != floor(value[key]) or value[key] < (-1 if key in ["day", "ritual_day"] else 0): return false
	if value.rounds > DAILY_LIMIT or value.total > 1000000 or value.tokens > 1000000: return false
	for id in value.items:
		if not ITEMS.has(id) or not PetState.valid_count(value.items[id]) or value.items[id] < 1: return false
	return true
static func readiness(s: GameSession) -> String:
	if not YardRoutines.available(s): return "Najpierw zakończmy obecną czynność."
	if float(s.pet.needs.energy) < 35: return "Najpierw odpoczynek — kopanie kosztuje 4 energii."
	var day := PersonalitySystem.day_of(s._local_now())
	if day < int(s.pet.exploration.day) or (day == int(s.pet.exploration.day) and int(s.pet.exploration.rounds) >= DAILY_LIMIT): return "Piaskownica odpoczywa. Możecie wrócić do niej jutro."
	if int(s.pet.exploration.total) >= 1000000: return "Kolekcja jest już pełna przygód."
	return ""
static func start(s: GameSession) -> bool:
	var reason := readiness(s)
	if not reason.is_empty():
		s.say(reason)
		return false
	s.move_to(Vector2(650, 315))
	s.activity = "dig_walk"
	s.say("Sprawdźmy, co kryje piaskownica!")
	return true
static func draw_item(pet: PetState) -> String:
	var rng := RandomNumberGenerator.new()
	rng.seed = pet.personality_seed + int(pet.exploration.total) * 7919
	var roll := rng.randi_range(1, 50)
	for id in ITEMS:
		roll -= int(ITEMS[id][1])
		if roll <= 0: return id
	return "bone"
static func finish(s: GameSession) -> bool:
	if not s.writable or s.suspended or not s.in_yard or s.activity != "digging": return false
	var before := s.pet.to_dict()
	var state := s.pet.exploration
	var day := PersonalitySystem.day_of(s._local_now())
	s.activity = "idle"
	s.activity_left = 0
	s.clip_requested.emit("idle")
	if day < int(state.day) or (day == int(state.day) and state.rounds >= DAILY_LIMIT): return false
	if day > int(state.day):
		state.day = day
		state.rounds = 0
	var id := draw_item(s.pet)
	var duplicate: bool = state.items.has(id)
	state.items[id] = mini(100000, int(state.items.get(id, 0)) + 1)
	state.total = int(state.total) + 1
	state.rounds = int(state.rounds) + 1
	if duplicate: state.tokens = int(state.tokens) + 1
	NeedsSystem.change(s.pet, {"energy": -4, "hygiene": -10, "play": 8})
	s.pet.remember("dig_" + id, "Odkopane: " + ITEMS[id][0], "Znalezisko z naszej piaskownicy.")
	var adventure_completed := DailyAdventure.record(s.pet, "treasure", s._local_now())
	if not s.flush():
		s.pet = PetState.from_dict(before)
		s.changed.emit()
		return false
	s.sound_requested.emit("success")
	s.say("Odkopane: %s! %s" % [ITEMS[id][0], "Duplikat: +1 wymiana. Za 3 wybierzesz brakujący skarb." if duplicate else "Nowy skarb w Albumie."])
	if adventure_completed: s.say("Przygoda ukończona! Pamiątka czeka w Albumie.")
	s.changed.emit()
	return true
static func exchange(s: GameSession, id: String) -> bool:
	if not s.writable or s.suspended or not ITEMS.has(id) or s.pet.exploration.items.has(id) or s.pet.exploration.tokens < 3: return false
	var before := s.pet.to_dict()
	s.pet.exploration.tokens -= 3
	s.pet.exploration.items[id] = 1
	s.pet.remember("dig_" + id, "Wymienione: " + ITEMS[id][0], "Trzy duplikaty zamienione na brakujący skarb.")
	if not s.flush():
		s.pet = PetState.from_dict(before)
		return false
	s.changed.emit()
	return true

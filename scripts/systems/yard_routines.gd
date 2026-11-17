class_name YardRoutines
extends RefCounted

const PLANTS := {"daisy": "Stokrotka", "poppy": "Mak", "lavender": "Lawenda"}
const GROW_TIME := 3.0 * 86400
static func initial() -> Dictionary:
	return {"plant": "", "growth": 0.0, "checked_at": 0.0, "water_until": 0.0, "outday": -1, "flowers": []}

static func valid(value: Variant) -> bool:
	if not value is Dictionary: return false
	if not value.get("plant") is String or (value.plant != "" and not PLANTS.has(value.plant)): return false
	for key in ["growth", "checked_at", "water_until", "outday"]:
		if not PetState.valid_number(value.get(key)): return false
	if value.growth < 0 or value.growth > GROW_TIME or value.checked_at < 0 or value.water_until < 0: return false
	if value.outday < -1 or value.outday != floor(value.outday): return false
	if not value.get("flowers") is Array or value.flowers.size() > 3: return false
	var seen := []
	for flower in value.flowers:
		if not PLANTS.has(flower) or seen.has(flower): return false
		seen.append(flower)
	return true

static func update(state: Dictionary, now: float) -> void:
	# A high-water mark prevents repeated growth after clock rollback.
	if now <= float(state.checked_at): return
	if state.plant != "":
		state.growth = minf(GROW_TIME, float(state.growth) + maxf(0, minf(now, float(state.water_until)) - float(state.checked_at)))
	state.checked_at = now

static func describe(state: Dictionary, now: float) -> String:
	var view := state.duplicate(true)
	update(view, now)
	if view.plant == "": return "Pusta grządka. Wybierz nasiona."
	if view.growth >= GROW_TIME: return "%s kwitnie! Zbierz kwiat do kolekcji." % PLANTS[view.plant]
	return "%s · %d%%\n%s" % [PLANTS[view.plant], int(100 * view.growth / GROW_TIME), "Podlana — rośnie." if now < view.water_until else "Czeka na wodę. Nie zwiędnie."]

static func garden(session: GameSession, action: String) -> bool:
	if not available(session): return false
	var before := session.pet.to_dict()
	var state := session.pet.yard_routines
	var now := Time.get_unix_time_from_system()
	update(state, now)
	var message := ""
	if PLANTS.has(action) and state.plant == "":
		state.plant = action
		state.growth = 0.0
		state.water_until = 0.0
		message = "Nasiona posadzone. Teraz podlej grządkę."
	elif action == "water" and state.plant != "" and state.growth < GROW_TIME and now >= state.water_until and now >= state.checked_at:
		state.water_until = now + 86400
		message = "Podlane! Wody wystarczy na dobę wzrostu."
	elif action == "harvest" and state.plant != "" and state.growth >= GROW_TIME:
		var plant: String = state.plant
		if not state.flowers.has(plant): state.flowers.append(plant)
		session.pet.remember("garden_" + plant, "Pierwszy kwiat: " + PLANTS[plant], "Wspólnie zadbaliście o ogródek.", now)
		state.plant = ""
		state.growth = 0.0
		state.water_until = 0.0
		message = "Kwiat w kolekcji! Odblokowano: %s. Ustaw dekorację w Albumie." % KeepsakeSystem.DECOR[plant]
	elif action == "observe" and state.plant != "" and now < state.water_until:
		message = "Grządka podlana, roślina spokojnie rośnie."
	else: return false
	if DailyAdventure.record(session.pet, "garden", session._local_now()): message += " Przygoda ukończona! Pamiątka w Albumie."
	if not session.flush():
		session.pet = PetState.from_dict(before)
		session.changed.emit()
		return false
	session.player_activity()
	session.say(message)
	session.changed.emit()
	return true

static func available(session: GameSession) -> bool:
	return session.writable and not session.suspended and session.in_yard and not session.busy() and not session.is_sleeping() and DailyRhythm.phase(session.pet, session._local_now()) != "night"

static func due(session: GameSession) -> bool:
	return PersonalitySystem.day_of(session._local_now()) > int(session.pet.yard_routines.outday)

static func start_outing(session: GameSession) -> bool:
	if not available(session) or not due(session): return false
	session.move_to(Vector2(1220, 560))
	session.activity = "outing_walk"
	session.say("Idziemy w spokojne miejsce przy płocie.")
	return true

static func praise(session: GameSession) -> bool:
	if not session.writable or session.suspended or not session.in_yard or session.activity != "outing_praise" or not due(session): return false
	var before := session.pet.to_dict()
	session.pet.yard_routines.outday = PersonalitySystem.day_of(session._local_now())
	session.pet.bond = minf(100, session.pet.bond + 0.5)
	if not session.flush():
		session.pet = PetState.from_dict(before)
		return false
	session.activity = "idle"
	session.activity_left = 0
	session.clip_requested.emit("idle")
	session.say("Dobry piesek! Spokojne wyjście razem · +0,5 więzi.")
	session.changed.emit()
	return true

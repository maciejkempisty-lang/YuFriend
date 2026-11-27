class_name YardRoutines
extends RefCounted

const PLANTS := {"daisy": "Stokrotka", "poppy": "Mak", "lavender": "Lawenda"}
const GROW_TIME := 3.0 * 86400
static func initial() -> Dictionary:
	return {"plant": "", "growth": 0.0, "checked_at": 0.0, "water_until": 0.0, "watered_day": -1, "outday": -1, "flowers": []}

static func has_mess(session: GameSession) -> bool:
	return session.pet.yard_routines.get("mess", false)

static func valid(value: Variant) -> bool:
	if not value is Dictionary: return false
	if value.has("mess") and not value.mess is bool: return false
	if value.has("visitor_next") and (not PetState.valid_number(value.visitor_next) or value.visitor_next != floor(value.visitor_next) or value.visitor_next < 0 or value.visitor_next >= 3): return false
	if not value.get("plant") is String or (value.plant != "" and not PLANTS.has(value.plant)): return false
	for key in ["growth", "checked_at", "water_until", "outday"]:
		if not PetState.valid_number(value.get(key)): return false
	if value.growth < 0 or value.growth > GROW_TIME or value.checked_at < 0 or value.water_until < 0: return false
	if value.has("watered_day") and (not PetState.valid_number(value.watered_day) or value.watered_day < -1 or value.watered_day != floor(value.watered_day)): return false
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

# Legacy saves encode the last watering instant as water_until - one day.
# The explicit local day makes subsequent waterings independent of DST and hour.
static func watering_day(state: Dictionary, local_seconds: float, now: float) -> int:
	if state.has("watered_day"): return int(state.watered_day)
	if float(state.water_until) <= 0: return -1
	return PersonalitySystem.day_of(float(state.water_until) - 86400 + local_seconds - now)

static func can_water(session: GameSession, now: float = -1) -> bool:
	if now < 0: now = Time.get_unix_time_from_system()
	var state := session.pet.yard_routines
	return state.plant != "" and state.growth < GROW_TIME and now >= float(state.checked_at) and PersonalitySystem.day_of(session._local_now()) > watering_day(state, session._local_now(), now)

static func garden(session: GameSession, action: String, now: float = -1) -> bool:
	if not RoomLayoutLoader.allows("garden", "yard"): return false
	if not available(session): return false
	var before := session.pet.to_dict()
	var state := session.pet.yard_routines
	if now < 0: now = Time.get_unix_time_from_system()
	if not state.has("watered_day"): state.watered_day = watering_day(state, session._local_now(), now)
	update(state, now)
	var message := ""
	if PLANTS.has(action) and state.plant == "":
		state.plant = action
		state.growth = 0.0
		state.water_until = 0.0
		message = "Nasiona posadzone. Teraz podlej grządkę."
	elif action == "water" and can_water(session, now):
		state.watered_day = PersonalitySystem.day_of(session._local_now())
		state.water_until = now + 86400
		message = "Podlane! Następne podlewanie od jutra, o dowolnej porze dnia."
	elif action == "harvest" and state.plant != "" and state.growth >= GROW_TIME:
		var plant: String = state.plant
		if not state.flowers.has(plant): state.flowers.append(plant)
		session.pet.remember("garden_" + plant, "Pierwszy kwiat: " + PLANTS[plant], "Wspólnie zadbaliście o ogródek.", now)
		state.plant = ""
		state.growth = 0.0
		state.water_until = 0.0
		message = "Kwiat w kolekcji! Odblokowano: %s. Ustaw dekorację w Albumie." % KeepsakeSystem.DECOR[plant]
	elif action == "observe" and state.plant != "":
		message = describe(state, now)
	else:
		session.pet = PetState.from_dict(before)
		return false
	if DailyAdventure.record(session.pet, "garden", session._local_now()): message += " Przygoda ukończona! Pamiątka w Albumie."
	if not session.flush():
		session.pet = PetState.from_dict(before)
		session.changed.emit()
		return false
	if session.visitors.active(): session.visitors.finish(session, "Gość rusza dalej. Teraz czas dla Was.")
	if PLANTS.has(action) and session.weather.water_garden(session, now): message = "Nasiona posadzone. Deszcz podlał grządkę — teraz rośnie."
	session.player_activity()
	session.say(message)
	session.changed.emit()
	return true

static func available(session: GameSession) -> bool:
	return session.writable and not session.suspended and session.in_yard and not session.busy(false) and not session.is_sleeping() and DailyRhythm.phase(session.pet, session._local_now()) != "night"

static func due(session: GameSession) -> bool:
	return not has_mess(session) and PersonalitySystem.day_of(session._local_now()) > int(session.pet.yard_routines.outday)

static func start_outing(session: GameSession) -> bool:
	if not RoomLayoutLoader.allows("potty", "yard"): return false
	if not available(session) or not due(session): return false
	session.move_to(RoomLayout.yard_stand("outing"))
	session.activity = "outing_walk"
	session.say("Chcę się załatwić. Idziemy w spokojne miejsce przy płocie.")
	return true

static func finish_outing(session: GameSession) -> bool:
	if not session.writable or session.suspended or not session.in_yard or session.activity != "outing_pause" or not due(session): return false
	var before := session.pet.to_dict()
	session.pet.yard_routines.outday = PersonalitySystem.day_of(session._local_now())
	session.pet.yard_routines["mess"] = true
	if not session.flush():
		session.pet = PetState.from_dict(before)
		session.activity = "idle"
		session.activity_left = 0
		session.clip_requested.emit("idle")
		session.say("Nie udało się zapisać wyjścia. Spróbuj ponownie po odzyskaniu zapisu.")
		session.changed.emit()
		return false
	session.activity = "outing_praise"
	session.activity_left = 0
	session.clip_requested.emit("idle")
	session.say("Uff, gotowe! Teraz zbierz kupę do woreczka — dotknij Sprzątnij.")
	session.changed.emit()
	return true

# The legacy entry point remains for station callers; the reward now requires cleanup.
static func praise(session: GameSession) -> bool:
	return clean_up(session)

static func clean_up(session: GameSession) -> bool:
	if not RoomLayoutLoader.allows("potty", "yard"): return false
	if not session.writable or session.suspended or not session.in_yard or not has_mess(session): return false
	if session.activity != "outing_praise" and session.busy(false): return false
	var before := session.pet.to_dict()
	session.pet.yard_routines["mess"] = false
	BondLevels.add(session.pet, 0.5, session._local_now())
	if not session.flush():
		session.pet = PetState.from_dict(before)
		session.changed.emit()
		return false
	session.player_activity()
	if session.activity == "outing_praise":
		session.activity = "idle"
		session.activity_left = 0
		session.clip_requested.emit("idle")
	session.say("Posprzątane! Dziękuję za wspólne wyjście · +0,5 więzi.")
	session.changed.emit()
	return true

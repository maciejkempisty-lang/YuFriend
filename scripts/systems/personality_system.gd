class_name PersonalitySystem
extends RefCounted

# Osobowość powstaje w trzech krokach:
#   1. record()  — gra zapisuje fakty w dziennych koszykach `pet.history`,
#   2. propose() — z zamkniętych dni powstaje propozycja zmian (tu: lokalne reguły),
#   3. apply()   — gra sprawdza propozycję, ogranicza ją i dopiero wtedy zmienia psa.
# Planowane AI zastąpi wyłącznie krok 2: dostanie summary() i zwróci słownik
# o tym samym kształcie co propose(). Krok 3 pozostaje jedyną drogą do danych.

const WINDOW_DAYS := 7
const DAILY_STEP := 0.03
const MAX_STEP := 0.06
const MAX_DRIFT := 0.25
const MAX_NOTES := 4
# Zdarzenia, które nie są świadomym działaniem gracza o danej porze dnia.
const PASSIVE_EVENTS := ["miss", "reward_missed", "train_tired"]

const HABITS := {
	"time_morning": {"label": "Ranny ptaszek", "detail": "Najczęściej jesteście razem rano, więc wtedy chętniej szuka wspólnych zajęć."},
	"time_afternoon": {"label": "Popołudniowy towarzysz", "detail": "Najczęściej jesteście razem po południu, więc wtedy jest najżywszy."},
	"time_evening": {"label": "Wieczorny towarzysz", "detail": "Najczęściej jesteście razem wieczorem, więc wtedy czeka na Ciebie najbardziej."},
	"time_night": {"label": "Nocny marek", "detail": "Najczęściej jesteście razem późnym wieczorem, więc wtedy się ożywia."},
	"cuddler": {"label": "Przytulas", "detail": "Często go głaszczesz, więc sam zaczął przychodzić po pieszczoty."},
	"playful": {"label": "Łobuziak", "detail": "Dużo się bawicie, więc sam zaprasza do zabawy."},
	"student": {"label": "Pilny uczeń", "detail": "Regularne ćwiczenia sprawiły, że sam siada i czeka na komendę."},
}

const TRAIT_NOTES := {
	"curiosity_up": ["Coraz ciekawszy świata", "Zabawa i samodzielne próby zachęcają go do odkrywania."],
	"curiosity_down": ["Trochę ostrożniejszy", "Spokojne dni bez zabawy sprawiają, że rzadziej rusza na zwiady."],
	"patience_up": ["Coraz cierpliwszy", "Nagrody w dobrym momencie uczą go spokojnie czekać."],
	"patience_down": ["Bardziej niecierpliwy", "Spóźnione nagrody sprawiają, że trudniej mu czekać."],
	"sociability_up": ["Coraz bardziej przytulny", "Częsty kontakt sprawia, że mocniej szuka Twojej bliskości."],
	"sociability_down": ["Bardziej samodzielny", "Dni bez głaskania uczą go radzić sobie samemu."],
	"sensitivity_up": ["Łatwiej się rozprasza", "Ćwiczenia mimo zmęczenia sprawiają, że trudniej mu się skupić."],
	"sensitivity_down": ["Spokojniejszy przy nauce", "Odpoczynek we właściwym czasie pomaga mu się skupić."],
}

static func local_now() -> float:
	return Time.get_unix_time_from_system() + float(Time.get_time_zone_from_system().bias) * 60.0

static func day_of(local_seconds: float) -> int:
	return int(floor(local_seconds / 86400.0))

static func part_of(local_seconds: float) -> String:
	var hour := int(fposmod(local_seconds, 86400.0) / 3600.0)
	if hour >= 5 and hour < 11: return "morning"
	if hour >= 11 and hour < 17: return "afternoon"
	if hour >= 17 and hour < 22: return "evening"
	return "night"

static func record(pet: PetState, event: String, local_seconds: float) -> void:
	if not PetState.EVENT_KEYS.has(event) or not is_finite(local_seconds) or local_seconds < 0:
		return
	var bucket := _bucket(pet, day_of(local_seconds))
	bucket.events[event] = mini(int(bucket.events.get(event, 0)) + 1, PetState.MAX_EVENT_COUNT)
	if not PASSIVE_EVENTS.has(event):
		var part := part_of(local_seconds)
		bucket.parts[part] = mini(int(bucket.parts.get(part, 0)) + 1, PetState.MAX_EVENT_COUNT)

static func _bucket(pet: PetState, day: int) -> Dictionary:
	if not pet.history.is_empty():
		var last: Dictionary = pet.history[-1]
		# Cofnięty zegar dopisuje do ostatniego dnia zamiast tworzyć starszy.
		if day <= int(last.day):
			return last
	var bucket := {"day": day, "events": {}, "parts": {}}
	pet.history.append(bucket)
	while pet.history.size() > PetState.MAX_HISTORY_DAYS:
		pet.history.pop_front()
	return bucket

static func _count(events: Dictionary, key: String) -> int:
	return int(events.get(key, 0))

static func daily_drift(events: Dictionary) -> Dictionary:
	var drift := {"curiosity": 0.0, "patience": 0.0, "sociability": 0.0, "sensitivity": 0.0}
	var trained := _count(events, "train_guided") + _count(events, "train_free")
	var rewards := _count(events, "reward_treat") + _count(events, "reward_praise") + _count(events, "reward_play")
	var missed := _count(events, "reward_missed")
	var contact := _count(events, "pet") + _count(events, "reward_praise")
	var play := _count(events, "play")
	if _count(events, "feed") + _count(events, "clean") + contact + play + trained == 0:
		return drift
	if contact >= 3: drift.sociability = 0.02
	elif contact == 0: drift.sociability = -0.01
	if rewards + missed >= 2:
		var ratio := float(rewards) / float(rewards + missed)
		if ratio >= 0.8: drift.patience = 0.02
		elif ratio < 0.5: drift.patience = -0.02
	if play + _count(events, "train_free") >= 3: drift.curiosity = 0.02
	elif play + trained == 0: drift.curiosity = -0.01
	if _count(events, "train_tired") >= 2: drift.sensitivity = 0.02
	elif _count(events, "rest") >= 1 and _count(events, "train_tired") == 0: drift.sensitivity = -0.01
	return drift

static func _window(pet: PetState, today: int) -> Array:
	var result: Array = []
	for bucket in pet.history:
		if int(bucket.day) < today and int(bucket.day) >= today - WINDOW_DAYS:
			result.append(bucket)
	return result

static func _habits(pet: PetState, today: int) -> Array:
	var days := _window(pet, today)
	# Za mało danych (np. po długiej nieobecności) niczego nie odbiera.
	if days.size() < 2:
		return pet.habits.duplicate()
	var result: Array = []
	var parts := {}
	var total := 0
	for key in PetState.PART_KEYS:
		parts[key] = 0
		for bucket in days:
			parts[key] += int(bucket.parts.get(key, 0))
		total += parts[key]
	var top: String = PetState.PART_KEYS[0]
	for key in PetState.PART_KEYS:
		if parts[key] > parts[top]: top = key
	var kept := ""
	for id in pet.habits:
		if str(id).begins_with("time_"): kept = str(id).trim_prefix("time_")
	var matching_days := 0
	for bucket in days:
		if int(bucket.parts.get(top, 0)) > 0: matching_days += 1
	if total >= 16 and float(parts[top]) / total >= 0.6 and matching_days >= 2:
		result.append("time_" + top)
	elif not kept.is_empty() and total >= 8 and float(parts[kept]) / total >= 0.4:
		result.append("time_" + kept)
	for rule in [["cuddler", ["pet"], 8], ["playful", ["play"], 6], ["student", ["train_guided", "train_free"], 10]]:
		var count := 0
		var active_days := 0
		for bucket in days:
			var in_day := 0
			for key in rule[1]: in_day += _count(bucket.events, key)
			count += in_day
			if in_day > 0: active_days += 1
		if (count >= rule[2] and active_days >= 2) or (pet.habits.has(rule[0]) and count * 2 >= rule[2]):
			result.append(rule[0])
	return result

static func propose(pet: PetState, today: int) -> Dictionary:
	var deltas := {}
	var latest_activity := -1
	for key in PetState.TRAIT_KEYS: deltas[key] = 0.0
	for bucket in pet.history:
		if int(bucket.day) <= pet.reflected_day or int(bucket.day) >= today:
			continue
		latest_activity = maxi(latest_activity, int(bucket.day))
		var drift := daily_drift(bucket.events)
		for key in PetState.TRAIT_KEYS:
			deltas[key] += clampf(drift[key], -DAILY_STEP, DAILY_STEP)
	# Nie przesuwamy okna nawyków samym upływem czasu podczas nieobecności.
	# Oczekujące dni oceniamy tak, jak następnego dnia po ostatniej aktywności.
	var habits := _habits(pet, latest_activity + 1) if latest_activity >= 0 else pet.habits.duplicate()
	var notes: Array = []
	for id in habits:
		if not pet.habits.has(id):
			notes.append({"key": "habit_" + id, "title": HABITS[id].label, "detail": HABITS[id].detail})
	for key in PetState.TRAIT_KEYS:
		if absf(deltas[key]) < 0.001: continue
		var note: Array = TRAIT_NOTES["%s_%s" % [key, "up" if deltas[key] > 0 else "down"]]
		notes.append({"key": "trait_%s_%s" % [key, "up" if deltas[key] > 0 else "down"], "title": note[0], "detail": note[1]})
	return {"trait_deltas": deltas, "habits": habits, "notes": notes}

# Jedyna droga zmiany osobowości. Przyjmuje także niezaufaną propozycję (np. z AI):
# nieznane nawyki, zbyt duże zmiany i błędne wpisy są pomijane lub przycinane.
static func apply(pet: PetState, proposal: Dictionary, today: int, at: float = -1.0) -> Array:
	var applied: Array = []
	if today - 1 <= pet.reflected_day: return applied
	var base := PetState.base_traits(pet.personality_seed)
	var deltas: Variant = proposal.get("trait_deltas")
	if deltas is Dictionary:
		for key in PetState.TRAIT_KEYS:
			var delta: Variant = deltas.get(key, 0.0)
			if not PetState.valid_number(delta) or absf(delta) < 0.001: continue
			var low := maxf(0.05, float(base[key]) - MAX_DRIFT)
			var high := minf(0.95, float(base[key]) + MAX_DRIFT)
			pet.traits[key] = clampf(float(pet.traits[key]) + clampf(delta, -MAX_STEP, MAX_STEP), low, high)
	var habits: Variant = proposal.get("habits")
	if habits is Array:
		var accepted: Array = []
		var has_time := false
		for id in habits:
			if not id is String or not PetState.HABIT_KEYS.has(id) or accepted.has(id): continue
			if id.begins_with("time_"):
				if has_time: continue
				has_time = true
			accepted.append(id)
		pet.habits = accepted
	var notes: Variant = proposal.get("notes")
	if notes is Array:
		for note in notes:
			if applied.size() >= MAX_NOTES or pet.milestones.size() >= PetState.MAX_MILESTONES: break
			if not note is Dictionary: continue
			var valid := true
			for field in ["key", "title", "detail"]:
				if not note.get(field) is String or note[field].is_empty() or note[field].length() > 200: valid = false
			if not valid or note.key.length() > 100: continue
			if pet.remember(note.key, note.title, note.detail, at):
				applied.append({"title": note.title, "detail": note.detail})
	pet.reflected_day = maxi(pet.reflected_day, today - 1)
	return applied

# Raz na dobę: przetwarza zamknięte dni. Zwraca wpisy dodane do wspomnień.
static func reflect(pet: PetState, local_seconds: float, at: float = -1.0) -> Array:
	var today := day_of(local_seconds)
	if today - 1 <= pet.reflected_day:
		return []
	return apply(pet, propose(pet, today), today, at)

# Zwięzły kontekst dla przyszłego backendu AI. Bez imienia i identyfikatora psa.
static func summary(pet: PetState, today: int) -> Dictionary:
	var skills := {}
	for key in PetState.TRICK_KEYS: skills[key] = roundi(float(pet.skills[key].mastery))
	return {"traits": pet.traits.duplicate(), "base_traits": PetState.base_traits(pet.personality_seed),
		"habits": pet.habits.duplicate(), "favorite_reward": pet.favorite_reward,
		"bond": roundi(pet.bond), "skills": skills, "days": _window(pet, today).duplicate(true),
		"allowed_habits": PetState.HABIT_KEYS.duplicate(), "max_step": MAX_STEP}

static func habit_labels(pet: PetState) -> Array:
	var labels: Array = []
	for id in pet.habits:
		if HABITS.has(id): labels.append(HABITS[id].label)
	return labels

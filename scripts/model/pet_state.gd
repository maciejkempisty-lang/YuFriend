class_name PetState
extends RefCounted

const NEED_KEYS := ["fullness", "energy", "hygiene", "play", "contact"]
const TRICK_KEYS := ["come", "sit", "paw", "lie", "bow", "bark", "stay", "spin", "roll"]
const TRAIT_KEYS := ["curiosity", "patience", "sociability", "sensitivity"]
const EVENT_KEYS := ["visit", "feed", "pet", "play", "clean", "rest", "train_guided", "train_free",
	"train_tired", "reward_treat", "reward_praise", "reward_play", "reward_missed", "miss"]
const PART_KEYS := ["morning", "afternoon", "evening", "night"]
const HABIT_KEYS := ["time_morning", "time_afternoon", "time_evening", "time_night", "cuddler", "playful", "student"]
const MAX_HISTORY_DAYS := 14
const MAX_MILESTONES := 200
const MAX_RECENT_ENTRIES := 10
const MAX_LOADED_JOURNAL := MAX_MILESTONES + 40 # Accept existing v4 albums before trimming.
const MAX_EVENT_COUNT := 100000
const QUIRK_KEYS := ["sock_collector", "ball_guard", "window_watch", "door_listener", "toy_sorter", "bed_circles",
	"happy_wiggle", "brush_lean", "meal_sniff", "sun_napper", "head_tilter", "dream_runner"]
const MOOD_KEYS := ["calm", "playful", "cuddly", "sleepy", "curious"]
const INITIATIVE_KEYS := ["ball", "tug", "cups", "cuddle"]
const RESPONSE_KEYS := ["accepted", "declined", "ignored"]
const PLAY_KEYS := ["ball", "tug", "cups"]
var pet_id: String = ""
var pet_name: String = "Biszkopt"
var life_stage: String = "puppy"
## Legacy save field: retained for v1/v2 round trips. Runtime uses pixel art only.
var skin: String = "pixel"
var personality_seed: int = 0
var traits: Dictionary = {}
var favorite_reward: String = "praise"
var needs: Dictionary = {"fullness": 78.0, "energy": 76.0, "hygiene": 85.0, "play": 58.0, "contact": 65.0}
var skills: Dictionary = {}
var fetch_rewards: Dictionary = FetchRewards.initial()
var adventure: Dictionary = DailyAdventure.initial()
var exploration: Dictionary = DiggingSystem.initial()
var yard_routines: Dictionary = YardRoutines.initial()
var yard_record := 0.0
var practice: Dictionary = PracticeSystem.initial()
var photos: Array = []
var decor: Array = []
var bond: float = 12.0
var fatigue: float = 0.0
var resting: bool = false
var last_seen_at: float = 0.0
var journal: Array = []
var milestones: Array = []
# Dzienne koszyki zdarzeń (najstarszy pierwszy), nawyki i ostatni przetworzony dzień.
var history: Array = []
var habits: Array = []
var reflected_day: int = 0
var life: Dictionary = {}
var social: Dictionary = {}
var rhythm: Dictionary = DailyRhythm.initial()

static func create(seed_value: int = 0, now: float = -1.0) -> PetState:
	var pet := PetState.new()
	var rng := RandomNumberGenerator.new()
	if seed_value == 0:
		rng.randomize()
		seed_value = rng.randi_range(1, 2147483646)
	pet.personality_seed = seed_value
	pet.life = initial_life(seed_value)
	pet.social = initial_social()
	rng.seed = seed_value
	pet.last_seen_at = Time.get_unix_time_from_system() if now < 0 else now
	pet.pet_id = "%s-%s" % [int(pet.last_seen_at), seed_value]
	for key in TRAIT_KEYS:
		pet.traits[key] = rng.randf_range(0.25, 0.85)
	pet.favorite_reward = ["treat", "praise", "play"][rng.randi_range(0, 2)]
	for key in TRICK_KEYS:
		pet.skills[key] = {"mastery": 0.0, "attempts": 0, "successes": 0}
	pet.remember("welcome", "Pierwszy dzień razem", "Zaczyna się Wasza wspólna historia.", pet.last_seen_at)
	return pet

# Cechy „urodzeniowe” wynikają z ziarna; dryf jest ograniczany względem nich.
static func base_traits(seed_value: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var result := {}
	for key in TRAIT_KEYS:
		result[key] = rng.randf_range(0.25, 0.85)
	return result

# A separate random stream keeps the original traits and reward unchanged.
static func initial_life(seed_value: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value + 104729
	var pool := QUIRK_KEYS.duplicate()
	var quirks: Array = []
	for index in rng.randi_range(2, 3):
		var pick := rng.randi_range(0, pool.size() - 1)
		quirks.append(pool.pop_at(pick))
	return {"quirks": quirks, "discovered": [], "observations": {},
		"mood": "calm", "mood_day": -1, "mood_reason": "Dopiero się poznajecie.", "away_report": {}}

static func initial_social() -> Dictionary:
	var responses := {}
	for key in INITIATIVE_KEYS:
		responses[key] = {"accepted": 0, "declined": 0, "ignored": 0, "interest": 0.5}
	return {"responses": responses, "recent": [], "games": {"ball": 0, "tug": 0, "cups": 0},
		"last_offer_at": 0.0, "last_reward_at": 0.0}

static func valid_social(value: Variant) -> bool:
	if not value is Dictionary: return false
	for field in ["responses", "games"]:
		if not value.get(field) is Dictionary: return false
	for kind in INITIATIVE_KEYS:
		var response: Variant = value.responses.get(kind)
		if not response is Dictionary: return false
		for key in RESPONSE_KEYS:
			if not valid_count(response.get(key)): return false
		if not valid_number(response.get("interest")) or response.interest < 0.15 or response.interest > 0.95: return false
	for kind in PLAY_KEYS:
		if not valid_count(value.games.get(kind)): return false
	for field in ["last_offer_at", "last_reward_at"]:
		if not valid_number(value.get(field)) or value[field] < 0: return false
	if not value.get("recent") is Array or value.recent.size() > 12: return false
	for entry in value.recent:
		if not entry is Dictionary or not INITIATIVE_KEYS.has(entry.get("kind")) or not RESPONSE_KEYS.has(entry.get("response")): return false
		if not valid_number(entry.get("at")) or entry.at < 0: return false
	return true

static func valid_count(value: Variant) -> bool:
	return valid_number(value) and value >= 0 and value <= MAX_EVENT_COUNT and float(value) == floor(float(value))

static func valid_life(value: Variant) -> bool:
	if not value is Dictionary: return false
	for field in ["quirks", "discovered"]:
		if not value.get(field) is Array: return false
		var seen: Array = []
		for id in value[field]:
			if not id is String or not QUIRK_KEYS.has(id) or seen.has(id): return false
			seen.append(id)
	if value.quirks.size() < 2 or value.quirks.size() > 3: return false
	for id in value.discovered:
		if not value.quirks.has(id): return false
	if not value.get("observations") is Dictionary: return false
	for id in value.observations:
		var count: Variant = value.observations[id]
		if not value.quirks.has(id) or not valid_number(count): return false
		if count < 0 or count > 3 or float(count) != floor(float(count)): return false
	if not value.get("mood") is String or not MOOD_KEYS.has(value.mood): return false
	if not valid_number(value.get("mood_day")) or value.mood_day < -1 or float(value.mood_day) != floor(float(value.mood_day)): return false
	if not value.get("mood_reason") is String or value.mood_reason.length() > 200: return false
	var report: Variant = value.get("away_report")
	if not report is Dictionary: return false
	if not report.is_empty():
		for field in ["from", "until"]:
			if not valid_number(report.get(field)) or report[field] < 0: return false
		if report.until <= report.from or not report.get("events") is Array: return false
		if report.events.size() < 2 or report.events.size() > 3: return false
		for entry in report.events:
			if not entry is String or entry.is_empty() or entry.length() > 140: return false
	return true

func remember(key: String, title: String, detail: String, now: float = -1.0) -> bool:
	if milestones.has(key):
		return false
	if milestones.size() >= MAX_MILESTONES: return false
	milestones.append(key)
	add_journal_entry(key, title, detail, now)
	return true

# Keep every milestone and only the latest 10 recurring entries.
# Both groups remain in chronological order in the same album.
func add_journal_entry(key: String, title: String, detail: String, now: float) -> void:
	journal.push_front({"key": key, "title": title, "detail": detail,
		"at": Time.get_unix_time_from_system() if now < 0 else now})
	trim_journal()

func trim_journal() -> void:
	var recent := 0
	var seen: Array = []
	var kept: Array = []
	for entry in journal:
		if seen.has(entry.key): continue
		seen.append(entry.key)
		if not milestones.has(entry.key):
			recent += 1
			if recent > MAX_RECENT_ENTRIES: continue
		kept.append(entry)
	journal = kept

func to_dict() -> Dictionary:
	return {"adventure": adventure.duplicate(true), "exploration": exploration.duplicate(true), "yard_routines": yard_routines.duplicate(true), "fetch_rewards": fetch_rewards.duplicate(true), "yard_record": yard_record, "practice": practice.duplicate(true), "photos": photos.duplicate(true), "decor": decor.duplicate(), "pet_id": pet_id, "pet_name": pet_name, "life_stage": life_stage,
		"skin": skin, "personality_seed": personality_seed, "traits": traits.duplicate(true),
		"favorite_reward": favorite_reward, "needs": needs.duplicate(true),
		"skills": skills.duplicate(true), "bond": bond, "fatigue": fatigue,
		"resting": resting, "last_seen_at": last_seen_at,
		"journal": journal.duplicate(true), "milestones": milestones.duplicate(),
		"history": history.duplicate(true), "habits": habits.duplicate(), "reflected_day": reflected_day,
		"life": life.duplicate(true), "social": social.duplicate(true), "rhythm": rhythm.duplicate(true)}

static func valid_number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))

static func from_dict(data: Dictionary) -> PetState:
	if not DailyAdventure.valid(data.get("adventure")): return null
	if not DiggingSystem.valid(data.get("exploration")): return null
	if not YardRoutines.valid(data.get("yard_routines")): return null
	if not FetchRewards.valid(data.get("fetch_rewards")): return null
	if not valid_number(data.get("yard_record")) or data.yard_record < 0 or data.yard_record > 13: return null
	if not KeepsakeSystem.valid(data) or not PracticeSystem.valid(data.get("practice")): return null
	# Required state is checked before any defaults are applied. A broken save is
	# never silently replaced with a new animal.
	if not valid_life(data.get("life")): return null
	if not valid_social(data.get("social")): return null
	if not DailyRhythm.valid(data.get("rhythm")): return null
	for key in ["pet_id", "pet_name", "life_stage", "skin", "favorite_reward"]:
		if not data.get(key) is String:
			return null
	if data.pet_id.is_empty() or data.pet_id.length() > 100 or data.pet_name.strip_edges().is_empty() or data.pet_name.length() > 24:
		return null
	if not ["puppy", "young", "adult", "senior"].has(data.life_stage) or not ["simple", "pixel"].has(data.skin):
		return null
	if not ["treat", "praise", "play"].has(data.favorite_reward):
		return null
	for key in ["bond", "fatigue", "last_seen_at", "personality_seed"]:
		if not valid_number(data.get(key)):
			return null
	if data.last_seen_at < 0 or data.personality_seed < 1 or data.personality_seed > 2147483646:
		return null
	if not data.get("resting") is bool:
		return null
	for group in ["needs", "traits", "skills"]:
		if not data.get(group) is Dictionary:
			return null
	for key in NEED_KEYS:
		if not valid_number(data.needs.get(key)):
			return null
	for key in TRAIT_KEYS:
		if not valid_number(data.traits.get(key)):
			return null
	for key in TRICK_KEYS:
		var entry: Variant = data.skills.get(key)
		if not entry is Dictionary:
			return null
		for field in ["mastery", "attempts", "successes"]:
			if not valid_number(entry.get(field)) or entry[field] < 0:
				return null
	if not data.get("journal") is Array or not data.get("milestones") is Array:
		return null
	if data.journal.size() > MAX_LOADED_JOURNAL or data.milestones.size() > MAX_MILESTONES:
		return null
	for entry in data.journal:
		if not entry is Dictionary or not valid_number(entry.get("at")):
			return null
		for field in ["key", "title", "detail"]:
			if not entry.get(field) is String or entry[field].length() > 500:
				return null
	for key in data.milestones:
		if not key is String or key.length() > 100:
			return null
	if not data.get("history") is Array or not data.get("habits") is Array or not valid_number(data.get("reflected_day")):
		return null
	if data.history.size() > MAX_HISTORY_DAYS or data.habits.size() > HABIT_KEYS.size() or data.reflected_day < 0:
		return null
	for id in data.habits:
		if not id is String or not HABIT_KEYS.has(id):
			return null
	var clean_history: Array = []
	for bucket in data.history:
		if not bucket is Dictionary or not valid_number(bucket.get("day")) or bucket.day < 0:
			return null
		var clean := {"day": int(bucket.day), "events": {}, "parts": {}}
		for group in [["events", EVENT_KEYS], ["parts", PART_KEYS]]:
			var counts: Variant = bucket.get(group[0])
			if not counts is Dictionary:
				return null
			for key in group[1]:
				if not counts.has(key): continue
				if not valid_number(counts[key]) or counts[key] < 0:
					return null
				clean[group[0]][key] = mini(int(counts[key]), MAX_EVENT_COUNT)
		clean_history.append(clean)
	var pet := PetState.new()
	pet.life = data.life.duplicate(true)
	pet.social = data.social.duplicate(true)
	pet.rhythm = data.rhythm.duplicate(true)
	for key in ["offset_minutes", "updated_day", "nap_day"]: pet.rhythm[key] = int(pet.rhythm[key])
	pet.rhythm.nap_at = float(pet.rhythm.nap_at)
	for kind in INITIATIVE_KEYS:
		for key in RESPONSE_KEYS: pet.social.responses[kind][key] = int(pet.social.responses[kind][key])
		pet.social.responses[kind].interest = float(pet.social.responses[kind].interest)
	for kind in PLAY_KEYS: pet.social.games[kind] = int(pet.social.games[kind])
	pet.history = clean_history
	pet.habits = data.habits.duplicate()
	pet.reflected_day = int(data.reflected_day)
	pet.pet_id = data.pet_id
	pet.adventure = data.adventure.duplicate(true)
	pet.adventure.day = int(pet.adventure.day)
	pet.exploration = data.exploration.duplicate(true)
	for key in ["tokens", "day", "rounds", "total", "ritual_day"]: pet.exploration[key] = int(pet.exploration[key])
	for key in pet.exploration.items: pet.exploration.items[key] = int(pet.exploration.items[key])
	pet.yard_routines = data.yard_routines.duplicate(true)
	pet.fetch_rewards = data.fetch_rewards.duplicate(true)
	pet.yard_record = float(data.yard_record)
	pet.practice = data.practice.duplicate(true)
	pet.photos = data.photos.duplicate(true)
	pet.decor = data.decor.duplicate()
	pet.pet_name = data.pet_name
	pet.life_stage = data.life_stage
	pet.skin = data.skin
	pet.favorite_reward = data.favorite_reward
	pet.personality_seed = int(data.personality_seed)
	pet.resting = data.resting
	pet.last_seen_at = float(data.last_seen_at)
	pet.bond = clampf(data.bond, 0, 100)
	pet.fatigue = clampf(data.fatigue, 0, 100)
	for key in NEED_KEYS:
		pet.needs[key] = clampf(data.needs[key], 0, 100)
	for key in TRAIT_KEYS:
		pet.traits[key] = clampf(data.traits[key], 0, 1)
	for key in TRICK_KEYS:
		pet.skills[key] = {"mastery": clampf(data.skills[key].mastery, 0, 100),
			"attempts": mini(int(data.skills[key].attempts), 1000000),
			"successes": mini(int(data.skills[key].successes), 1000000)}
	pet.journal = data.journal.duplicate(true)
	pet.milestones = data.milestones.duplicate()
	pet.trim_journal()
	return pet

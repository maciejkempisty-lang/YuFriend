class_name PetState
extends RefCounted

const NEED_KEYS := ["fullness", "energy", "hygiene", "play", "contact"]
const TRICK_KEYS := ["come", "sit", "paw"]
const TRAIT_KEYS := ["curiosity", "patience", "sociability", "sensitivity"]
const EVENT_KEYS := ["visit", "feed", "pet", "play", "clean", "rest", "train_guided", "train_free",
	"train_tired", "reward_treat", "reward_praise", "reward_play", "reward_missed", "miss"]
const PART_KEYS := ["morning", "afternoon", "evening", "night"]
const HABIT_KEYS := ["time_morning", "time_afternoon", "time_evening", "time_night", "cuddler", "playful", "student"]
const MAX_HISTORY_DAYS := 14
const MAX_MILESTONES := 200
const MAX_EVENT_COUNT := 100000
var pet_id: String = ""
var pet_name: String = "Biszkopt"
var life_stage: String = "puppy"
var skin: String = "simple"
var personality_seed: int = 0
var traits: Dictionary = {}
var favorite_reward: String = "praise"
var needs: Dictionary = {"fullness": 78.0, "energy": 76.0, "hygiene": 85.0, "play": 58.0, "contact": 65.0}
var skills: Dictionary = {}
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

static func create(seed_value: int = 0, now: float = -1.0) -> PetState:
	var pet := PetState.new()
	var rng := RandomNumberGenerator.new()
	if seed_value == 0:
		rng.randomize()
		seed_value = rng.randi_range(1, 2147483646)
	pet.personality_seed = seed_value
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

func remember(key: String, title: String, detail: String, now: float = -1.0) -> bool:
	if milestones.has(key):
		return false
	milestones.append(key)
	journal.push_front({"key": key, "title": title, "detail": detail,
		"at": Time.get_unix_time_from_system() if now < 0 else now})
	if journal.size() > 40:
		journal.resize(40)
	return true

func to_dict() -> Dictionary:
	return {"pet_id": pet_id, "pet_name": pet_name, "life_stage": life_stage,
		"skin": skin, "personality_seed": personality_seed, "traits": traits.duplicate(true),
		"favorite_reward": favorite_reward, "needs": needs.duplicate(true),
		"skills": skills.duplicate(true), "bond": bond, "fatigue": fatigue,
		"resting": resting, "last_seen_at": last_seen_at,
		"journal": journal.duplicate(true), "milestones": milestones.duplicate(),
		"history": history.duplicate(true), "habits": habits.duplicate(), "reflected_day": reflected_day}

static func valid_number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))

static func from_dict(data: Dictionary) -> PetState:
	# Required state is checked before any defaults are applied. A broken save is
	# never silently replaced with a new animal.
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
	if data.journal.size() > 40 or data.milestones.size() > MAX_MILESTONES:
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
	pet.history = clean_history
	pet.habits = data.habits.duplicate()
	pet.reflected_day = int(data.reflected_day)
	pet.pet_id = data.pet_id
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
	return pet

class_name DailyRhythm
extends RefCounted

# Local wall time selects the phase; session delta measures inactivity.
const PHASES := {
	"morning": [0.60, 0.35, 0.05], "day": [0.70, 0.25, 0.05],
	"siesta": [0.15, 0.35, 0.50], "afternoon": [0.60, 0.35, 0.05],
	"evening": [0.15, 0.60, 0.25], "night": [0.0, 1.0, 0.0]
}

static func initial() -> Dictionary:
	return {"offset_minutes": 0, "updated_day": -1, "nap_day": -1, "nap_at": 0.0}

static func valid(value: Variant) -> bool:
	if not value is Dictionary: return false
	for key in ["offset_minutes", "updated_day", "nap_day", "nap_at"]:
		if not PetState.valid_number(value.get(key)): return false
	if value.offset_minutes != floor(value.offset_minutes) or value.offset_minutes < -30 or value.offset_minutes > 180: return false
	for key in ["updated_day", "nap_day"]:
		if value[key] < -1 or value[key] != floor(value[key]): return false
	return value.nap_at >= 0

static func adapt(pet: PetState, local_seconds: float) -> bool:
	var day := PersonalitySystem.day_of(local_seconds)
	if day <= int(pet.rhythm.updated_day): return false
	var target := 0
	if pet.habits.has("time_night"): target = 180
	elif pet.habits.has("time_evening"): target = 90
	elif pet.habits.has("time_morning"): target = -30
	# One step on a new observed day, never a jump after a long absence.
	pet.rhythm.offset_minutes = int(move_toward(float(pet.rhythm.offset_minutes), target, 30))
	pet.rhythm.updated_day = day
	return true

static func phase(pet: PetState, local_seconds: float) -> String:
	var hour := fposmod(local_seconds / 3600.0 - float(pet.rhythm.offset_minutes) / 60.0, 24.0)
	if hour < 6 or hour >= 22: return "night"
	if hour < 9: return "morning"
	if hour < 13: return "day"
	if hour < 15: return "siesta"
	if hour < 19: return "afternoon"
	return "evening"

static func quiet(pet: PetState, local_seconds: float) -> bool:
	return phase(pet, local_seconds) in ["evening", "night"]

static func nap_allowed(pet: PetState, local_seconds: float) -> bool:
	if local_seconds - float(pet.rhythm.nap_at) < 1800: return false
	var part := phase(pet, local_seconds)
	if part == "night": return false
	return part != "siesta" or int(pet.rhythm.nap_day) != PersonalitySystem.day_of(local_seconds)

static func note_nap(pet: PetState, local_seconds: float) -> void:
	pet.rhythm.nap_at = maxf(float(pet.rhythm.nap_at), local_seconds)
	if phase(pet, local_seconds) == "siesta": pet.rhythm.nap_day = PersonalitySystem.day_of(local_seconds)

static func proportions(pet: PetState, local_seconds: float) -> Array:
	var part := phase(pet, local_seconds)
	var weights: Array = PHASES[part].duplicate()
	if part == "night": return weights # Night sleep is scheduled, never rolled.
	if pet.life.mood == "playful":
		weights[0] += 0.12
		weights[1] -= 0.07
		weights[2] -= 0.05
	elif pet.life.mood == "sleepy":
		weights[0] -= 0.12
		weights[2] += 0.12
	elif pet.life.mood in ["calm", "cuddly"]:
		weights[0] -= 0.08
		weights[1] += 0.08
	if part == "evening":
		var hour := fposmod(local_seconds / 3600.0 - float(pet.rhythm.offset_minutes) / 60.0, 24.0)
		var extra := (hour - 19.0) / 3.0 * 0.15
		weights[1] -= extra
		weights[2] += extra
	for index in weights.size(): weights[index] = maxf(0, weights[index])
	return weights

static func schedule_label(pet: PetState) -> String:
	var offset := int(pet.rhythm.offset_minutes)
	return "Zwykły sen: %s–%s" % [_time_label(22 * 60 + offset), _time_label(6 * 60 + offset)]

static func _time_label(minutes: int) -> String:
	minutes = posmod(minutes, 1440)
	return "%02d:%02d" % [minutes / 60, minutes % 60]

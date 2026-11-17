class_name YardWeather
extends RefCounted

const LABELS := {"sun": "Słonecznie", "rain": "Lekki deszcz", "after_rain": "Po deszczu"}
# A repeatable local calendar, not a real-world weather forecast.
var override_kind := "" # Deterministic test seam; never persisted.
var check_left := 0.0

func kind(s: GameSession) -> String:
	if LABELS.has(override_kind): return override_kind
	var day := PersonalitySystem.day_of(s._local_now())
	return ["sun", "sun", "rain", "after_rain"][posmod(day + s.pet.personality_seed, 4)]

func water_reason(s: GameSession, spot: String) -> String:
	if spot == "puddle" and kind(s) == "sun": return "Kałuża wyschła. Dziś można pobawić się przy zraszaczu."
	if spot == "sprinkler" and kind(s) == "rain": return "Deszcz już podlewa podwórko. Zraszacz odpoczywa — spróbuj kałuży."
	return ""

func advance(s: GameSession, delta: float) -> void:
	check_left -= delta
	if check_left > 0: return
	check_left = 10
	water_garden(s)
	if str(s.invitation.get("kind", "")).begins_with("yard_"):
		var offer: String = s.invitation.kind
		if not YardInvitations.options(s).has(offer): s._cancel_invitation()

func water_garden(s: GameSession, now: float = -1) -> bool:
	if not s.writable or s.suspended or kind(s) != "rain": return false
	if now < 0: now = Time.get_unix_time_from_system()
	if not YardRoutines.can_water(s, now): return false
	var before := s.pet.to_dict()
	var garden := s.pet.yard_routines
	YardRoutines.update(garden, now)
	garden.watered_day = PersonalitySystem.day_of(s._local_now())
	garden.water_until = maxf(float(garden.water_until), now + 86400)
	if not s.flush():
		s.pet = PetState.from_dict(before)
		return false
	s.changed.emit()
	return true

class_name BathCare
extends RefCounted

static func bath_readiness(s: GameSession) -> String:
	if not s.writable or s.suspended or s.is_sleeping() or s.busy(false): return "Kąpiel poczeka, aż piesek będzie gotowy."
	if float(s.pet.needs.energy) < 35: return "Najpierw odpoczynek. Kąpiel kosztuje 5 energii."
	if float(s.pet.needs.fullness) < 30: return "Najpierw posiłek, potem kąpiel."
	if float(s.pet.needs.hygiene) >= 80: return "Sierść jest dość czysta. Wystarczy delikatne czesanie."
	return ""


static func start_bath(s: GameSession) -> bool:
	var reason := s.bath_readiness()
	if not reason.is_empty():
		s.say(reason)
		return false
	s._cancel_motion()
	s.invitation.clear()
	s.in_yard = false
	s.in_bath = true
	s.activity = "bath"
	s.activity_left = 0
	s.bath.start()
	s.changed.emit()
	return true


static func finish_bath(s: GameSession) -> bool:
	if not s.in_bath or not s.bath.active or s.bath.stage != 3 or s.bath.settled or not s.writable or s.suspended: return false
	s.bath.settled = true
	NeedsSystem.change(s.pet, {"hygiene": 45, "energy": -5, "fullness": -2})
	s._note("clean", false)
	s.pet.remember("first_bath", "Pierwsza kąpiel", "Piana, woda, miękki ręcznik i radosne otrzepywanie.")
	s.sound_requested.emit("success")
	s.say("Kąpiel skończona: +45 czystości, −5 energii, −2 sytości.")
	s.flush()
	s.changed.emit()
	return true


static func cancel_bath(s: GameSession) -> void:
	s.bath.cancel()
	s.in_bath = false
	s.activity = "idle"
	s.activity_left = 0
	s.clip_requested.emit("idle")
	s.changed.emit()

class_name YardInvitations
extends RefCounted

const WORDS := {
	"yard_ball": ["Piłka czeka na trawie. Rzucisz mi?", "Rzuć piłkę"],
	"yard_hide": ["W krzakach tyle zapachów! Schowasz smakołyk?", "Schowaj"],
	"yard_puddle": ["Tu jest kałuża! Popluskamy razem?", "Do kałuży"],
	"yard_sprinkler": ["Woda tak śmiesznie pryska! Pobiegamy?", "Do wody"]
}
const POINTS := {"yard_ball": Vector2(760, 330), "yard_hide": Vector2(350, 302), "yard_puddle": Vector2(396, 315), "yard_sprinkler": Vector2(1206, 315)}

static func options(s: GameSession) -> Dictionary:
	if not s.in_yard or s.is_sleeping() or s.pet.needs.energy < 45 or s.pet.needs.fullness < 30 or s.pet.fatigue >= 75 or DailyRhythm.quiet(s.pet, s._local_now()): return {}
	var memory := InitiativeSystem.weights(s.pet)
	var result := {"yard_ball": float(memory.ball), "yard_hide": float(memory.cups)}
	if s.water.cooldown <= 0:
		var water_weight := 0.4 + float(s.pet.traits.curiosity) * 2 + (1 - float(s.pet.traits.sensitivity))
		for spot in ["puddle", "sprinkler"]:
			if s.weather.water_reason(s, spot).is_empty():
				result["yard_" + spot] = water_weight + (0.5 if s.pet.milestones.has("water_" + spot) else 0)
	return result

static func offer(s: GameSession, requested: String = "", now: float = -1, roll: float = -1) -> bool:
	if not s.active or not s.writable or s.suspended or not s.initiatives_enabled or not s.attention_available or s.busy() or not s.invitation.is_empty() or not s.outdoor_commands.phase.is_empty(): return false
	if now < 0: now = Time.get_unix_time_from_system()
	if not is_finite(now) or now - float(s.pet.social.last_offer_at) < InitiativeSystem.OFFER_INTERVAL: return false
	var choices := options(s)
	if choices.is_empty(): return false
	var chosen := requested
	if chosen.is_empty():
		var total := 0.0
		for weight in choices.values(): total += float(weight)
		var cursor := clampf(randf() if roll < 0 else roll, 0, 0.99999) * total
		for key in choices:
			cursor -= float(choices[key])
			if cursor < 0:
				chosen = key
				break
	if not choices.has(chosen): return false
	var previous := s.pet.to_dict()
	s.pet.social.last_offer_at = now
	if not s.flush():
		s.pet = PetState.from_dict(previous)
		return false
	s._cancel_motion()
	s._follow_target = Vector2.INF
	s.activity = "initiative"
	s.activity_left = 0
	s.invitation = {"kind": chosen, "remaining": InitiativeSystem.RESPONSE_SECONDS, "arrived": false}
	s._travel_left = 45
	s.destination_requested.emit(POINTS[chosen])
	s.clip_requested.emit("walk")
	s.say(WORDS[chosen][0])
	s.changed.emit()
	return true

static func accept(s: GameSession) -> bool:
	var key: String = s.invitation.get("kind", "")
	if not options(s).has(key) or not s.play_readiness().is_empty(): return false
	if key in ["yard_puddle", "yard_sprinkler"] and not s.water.readiness(s).is_empty(): return false
	s._finish_invitation("accepted")
	s.player_activity()
	match key:
		"yard_ball":
			s.ball_aim_requested.emit()
			return true
		"yard_hide": return s.start_hide("treat")
		_: return s.water.start(s, key.trim_prefix("yard_"))

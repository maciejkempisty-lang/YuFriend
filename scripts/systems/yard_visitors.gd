class_name YardVisitors
extends RefCounted

# Runtime encounters are temporary; VisitorMemory stores bounded album milestones.
const SESSION_LIMIT := 2
const FIRST_WAIT := 60.0
const BETWEEN_VISITS := 240.0
const KINDS := ["bird", "butterfly", "cat"]
const LABELS := {"bird": "Ptak przy płocie", "butterfly": "Motyl przy płocie", "cat": "Kot sąsiada"}
const FENCE := Vector2(1010, 205)
const SAFE_SPOT := Vector2(810, 310)
var kind := ""
var phase := ""
var reaction := ""
var familiar := false
var remaining := 0.0
var response_left := 0.0
var wait_left := FIRST_WAIT
var visits := 0
var next_guest := 0

func begin_visit() -> void:
	visits = 0
	wait_left = FIRST_WAIT

func active() -> bool:
	return not kind.is_empty()

static func reaction_for(traits: Dictionary, guest: String, familiarity: int = 0) -> String:
	var comfort := clampi(familiarity, 0, VisitorMemory.LIMIT)
	var stimulus: float = {"bird": 0.8, "butterfly": 0.55, "cat": 1.0}.get(guest, 0.8)
	if float(traits.sensitivity) * stimulus - float(traits.sociability) * 0.2 - comfort * 0.11 > 0.52:
		return "wary" if comfort > 0 else "shy"
	if float(traits.curiosity) * 0.7 + float(traits.sociability) * 0.3 - float(traits.patience) * 0.25 > 0.55 + comfort * 0.04: return "bark"
	return "curious" if float(traits.curiosity) >= 0.5 else "calm"

func available(s: GameSession) -> bool:
	return s.activity == "idle" and s.in_yard and s.writable and not s.suspended and not s.is_sleeping() and not s.busy() and not s.training_view_active and s.outdoor_commands.phase.is_empty() and float(s.pet.needs.energy) >= 35 and DailyRhythm.phase(s.pet, s._local_now()) != "night"

func start(s: GameSession, guest: String) -> bool:
	if guest not in KINDS or visits >= SESSION_LIMIT or not available(s): return false
	s._cancel_motion()
	s.invitation.clear()
	s._follow_target = Vector2.INF
	visits += 1
	kind = guest
	phase = "watch"
	familiar = VisitorMemory.known(s.pet, guest)
	reaction = reaction_for(s.pet.traits, guest, VisitorMemory.level(s.pet, guest))
	VisitorMemory.record(s, guest, false)
	remaining = 30
	s.activity = "visitor"
	s.activity_left = 0
	s.pose = "stand"
	if reaction in ["shy", "curious"]:
		phase = "approach"
		s.destination_requested.emit(SAFE_SPOT if reaction == "shy" else Vector2(980, 310))
		s.clip_requested.emit("walk")
	else:
		s.clip_requested.emit("bark_stand" if reaction == "bark" else ("head_tilt_stand" if reaction == "wary" else "tail_wag_stand"))
	s.say(hint())
	s.visitor_appeared.emit()
	s.changed.emit()
	return true

func hint() -> String:
	if not active(): return ""
	if phase == "recall": return "Wraca do Ciebie… spokojnie czekamy."
	if phase == "soothe": return "Spokojnie, jestem przy Tobie…"
	var text: String = {"wary": "Zna ten zapach, obserwuje ostrożnie", "shy": "Cofa się niepewnie", "bark": "Szczeka z emocji", "curious": "Podchodzi zaciekawiona", "calm": "Spokojnie obserwuje"}[reaction]
	return "%s · %s%s" % [LABELS[kind], "Znowu razem! " if familiar else "", text]

func respond(s: GameSession, choice: String) -> bool:
	if not active() or phase in ["soothe", "recall"] or choice not in ["soothe", "recall"] or s.suspended or not s.writable: return false
	# Cancel only presentation movement: the encounter remains alive until arrival.
	s.activity_cancelled.emit()
	phase = choice
	if choice == "recall":
		remaining = 30
		s.destination_requested.emit(SAFE_SPOT)
		s.clip_requested.emit("walk")
	else:
		response_left = 2.5
		s.clip_requested.emit("tail_wag_stand")
	s.say(hint())
	s.changed.emit()
	return true

func arrived(s: GameSession) -> void:
	if phase == "recall":
		finish(s, "Już przy Tobie. Gość rusza dalej.", true)
	elif phase == "approach":
		phase = "watch"
		s.clip_requested.emit("head_tilt_stand" if reaction == "shy" else "sniff")

func advance(s: GameSession, delta: float) -> void:
	if active():
		if not s.in_yard or s.suspended or not s.writable or s.is_sleeping() or float(s.pet.needs.energy) < 28 or DailyRhythm.phase(s.pet, s._local_now()) == "night":
			finish(s, "Gość rusza dalej. Czas odpocząć.")
			return
		remaining -= delta
		if phase == "soothe":
			response_left -= delta
			if response_left <= 0:
				finish(s, "Spokojniej. Gość rusza dalej.", true)
				return
		if remaining <= 0: finish(s, "Gość rusza dalej. Znowu spokojne podwórko.")
		return
	# Only time spent watching the yard counts; games and panels pause the wait.
	if visits >= SESSION_LIMIT or not s.attention_available or not available(s): return
	wait_left = maxf(0, wait_left - delta)
	if wait_left == 0 and start(s, KINDS[next_guest]):
		next_guest = (next_guest + 1) % KINDS.size()

func cancel() -> void:
	if not active(): return
	kind = ""
	phase = ""
	reaction = ""
	remaining = 0
	response_left = 0
	wait_left = BETWEEN_VISITS

func finish(s: GameSession, message: String, peaceful: bool = false) -> void:
	if peaceful and active() and s.in_yard and not s.suspended and float(s.pet.needs.energy) >= 28 and DailyRhythm.phase(s.pet, s._local_now()) != "night":
		if VisitorMemory.record(s, kind, true): message += " Pamiątka czeka w Albumie."
		elif not s.save_ok: message += " Nie udało się zapisać pamiątki."
	cancel()
	s._cancel_motion()
	s.activity = "idle"
	s.activity_left = 0
	s.clip_requested.emit("idle")
	s.say(message)
	s.changed.emit()

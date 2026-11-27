class_name HomeDrink
extends RefCounted

static func bowl() -> Vector2: return RoomLayout.STATIONS.drink.position
static func stand() -> Vector2: return RoomLayout.STATIONS.drink.stand
var phase := ""
var elapsed := 0.0
var stage := 0
func active() -> bool: return not phase.is_empty()
func start(s: GameSession) -> bool:
	if not RoomLayoutLoader.allows("drink", "home"): return false
	if not s.active or s.suspended: return false
	if active():
		finish(s, "Miska z wodą poczeka.")
		return true
	if not s.active or s.in_yard or not s.writable or s.suspended or s.is_sleeping() or s.busy():
		s.say("Napijemy się, gdy skończymy tę czynność i będziemy na jawie.")
		return false
	s._cancel_invitation()
	s._cancel_motion()
	s._follow_target = Vector2.INF
	phase = "walk"
	elapsed = 0
	stage = 0
	s.activity = "home_drink"
	s.activity_left = 0
	s.destination_requested.emit(stand())
	s.clip_requested.emit("walk")
	s.say("Idę do miski z wodą. Dotknij jej ponownie, żeby przerwać.")
	s.changed.emit()
	return true
func arrived(s: GameSession) -> void:
	if phase != "walk": return
	phase = "drink"
	elapsed = 0
	s.home_drink_started.emit()
	s.clip_requested.emit("eat_enter")
	s.say("Kilka spokojnych łyków świeżej wody.")
	s.changed.emit()
func advance(s: GameSession, delta: float) -> void:
	if not active() or not is_finite(delta) or delta <= 0: return
	if s.in_yard or s.suspended or not s.writable or s.is_sleeping():
		finish(s, "Miska z wodą poczeka.")
		return
	elapsed += delta
	if phase == "walk":
		if elapsed >= 60: finish(s, "Nie udało się dojść do miski. Spróbuj ponownie.")
		return
	var next := 2 if elapsed >= 3.4 else (1 if elapsed >= 0.8 else 0)
	if next != stage:
		stage = next
		s.clip_requested.emit("eat_exit" if stage == 2 else "eat_loop")
	if elapsed >= 4.2:
		var before := s.pet.to_dict()
		var added := s.pet.remember("home_drink", "Świeża woda w domu", "Pierwsza spokojna przerwa przy misce z wodą.")
		if added and not s.flush():
			s.pet = PetState.from_dict(before)
			finish(s, "Woda wypita, ale nie udało się zapisać wspomnienia.")
			return
		finish(s, "Woda wypita. Miła chwila przerwy.")
func cancel() -> void:
	phase = ""
	elapsed = 0
func finish(s: GameSession, message: String) -> void:
	cancel()
	s._cancel_motion()
	s.activity = "sleep" if s.is_sleeping() else "idle"
	s.activity_left = 0
	s._brain_left = 12
	s.clip_requested.emit("sleep" if s.is_sleeping() else "idle")
	s.say(message)
	s.changed.emit()

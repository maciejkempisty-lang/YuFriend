class_name GameSession
extends Node

signal changed
signal feedback(text: String)
signal clip_requested(clip: String)
signal destination_requested(world_position: Vector2)
signal performance_requested(clip: String, trial_id: int)
signal save_status(ok: bool)
signal approach_requested(action: String, token: int)
signal place_requested(action: String)
signal activity_cancelled
signal attention_requested(close_up: bool)
signal sound_requested(effect: String)
signal away_report_ready
signal care_completed(action: String, gains: Dictionary)
signal initiative_requested(kind: String)
signal ball_aim_requested
signal ball_throw_requested(target: Vector2, token: int)
signal touch_game_opened(kind: String)
signal touch_game_closed

var pet: PetState
var training := TrainingSystem.new()
var storage: SaveSystem
var writable: bool = true
var save_ok: bool = true
var suspended: bool = false
var active: bool = false
var pose: String = "stand"
var activity: String = "idle"
var activity_left: float = 0.0
var cooldowns: Dictionary = {}
var last_message: String = "Dotknij, by pogłaskać. Przycisk „Cały pokój” pokaże miskę i legowisko."
var _refresh_left: float = 0.0
var _save_left: float = 25.0
var _brain_left: float = 8.0
var performance_done: bool = true
var _approach_token: int = 0
var _pending_action: String = ""
var _pending_by_player: bool = false
var _sleep_elapsed: float = 0.0
var _discovery_message: String = ""
var invitation: Dictionary = {}
var attention_available := true
var initiatives_enabled := true
var _initiative_wait := 90.0
var play := TouchPlaySystem.new()

const SATISFIED_NEED := 95.0
const CARE_COOLDOWNS := {"feed": 10.0, "play": 8.0, "clean": 12.0, "pet": 4.0}

func _apply_care_effects(action: String, changes: Dictionary) -> void:
	var before := pet.needs.duplicate()
	NeedsSystem.change(pet, changes)
	var gains := {}
	for key in changes:
		var gain := float(pet.needs[key]) - float(before[key])
		if gain > 0: gains[key] = gain
	care_completed.emit(action, gains)

func start(save_path: String = "user://pet.json") -> void:
	storage = SaveSystem.new(save_path)
	var loaded := storage.load_pet()
	pet = loaded.pet
	# Seed only a new mobile playtest pet; existing saves keep their name.
	if loaded.status == "new" and OS.has_feature("gloria_playtest"):
		pet.pet_name = "Gloria"
	writable = loaded.writable
	var now := Time.get_unix_time_from_system()
	var seen := pet.last_seen_at
	var was_resting := pet.resting
	var away := maxf(0, now - seen)
	NeedsSystem.catch_up(pet, now)
	var news := _reflect()
	var report := _update_life(seen, now, was_resting)
	if writable and (loaded.status == "new" or away > 300): _note("visit")
	if loaded.status == "migration_failed":
		last_message = storage.last_error
	elif not writable:
		last_message = "Nie udało się odczytać postępu. Dotychczasowy zapis pozostaje zachowany."
	elif loaded.status == "recovered":
		last_message = "Postęp został odzyskany z kopii. Możecie grać dalej."
	elif away > 300:
		last_message = _greeting(away)
	elif not news.is_empty():
		last_message = news
	active = true
	if pet.resting and float(pet.needs.energy) >= NeedsSystem.WAKE_ENERGY:
		pet.resting = false
	if pet.resting:
		activity = "sleep"
		place_requested.emit("rest")
		clip_requested.emit("sleep")
	elif away > 300:
		clip_requested.emit(LifeSystem.greeting(pet, away).clip)
	flush()
	changed.emit()
	if report: away_report_ready.emit()

func _process(delta: float) -> void:
	if not active or suspended: return
	if attention_available and not pet.resting and not busy():
		_initiative_wait = maxf(0, _initiative_wait - delta)
		if not invitation.is_empty():
			invitation.remaining -= delta
			if float(invitation.remaining) <= 0: _finish_invitation("ignored")
	if play.running():
		play.advance(delta)
		_settle_touch_game()
	NeedsSystem.advance(pet, delta)
	if pet.resting:
		_sleep_elapsed += delta
		if _sleep_elapsed >= 6 and float(pet.needs.energy) >= NeedsSystem.WAKE_ENERGY:
			_wake()
	for key in cooldowns:
		cooldowns[key] = maxf(0, float(cooldowns[key]) - delta)
	var result := training.advance(delta, performance_done)
	if not result.is_empty():
		say(result.message)
		if result.event == "miss": _note("miss")
		elif result.event == "expired": _note("reward_missed")
		if result.event == "ready":
			clip_requested.emit("sit_idle" if pose == "sit" else "idle")
		elif result.event in ["miss", "expired"]:
			clip_requested.emit("sit_idle" if pose == "sit" else "head_tilt_stand")
		changed.emit()
	if activity_left > 0:
		activity_left -= delta
		if activity_left <= 0:
			activity = "idle"
			clip_requested.emit("sit_idle" if pose == "sit" else "idle")
	if training.phase == "idle" and activity == "idle" and not pet.resting and play.kind.is_empty() and invitation.is_empty():
		_brain_left -= delta
		if _brain_left <= 0:
			_brain_left = randf_range(9, 15)
			_spontaneous()
	if not _discovery_message.is_empty() and not busy():
		say(_discovery_message)
		_discovery_message = ""
		_brain_left = maxf(_brain_left, 8.0)
	_refresh_left -= delta
	if _refresh_left <= 0:
		_refresh_left = 0.15
		if writable and LifeSystem.refresh_mood(pet, _local_now()): flush()
		changed.emit()
	_save_left -= delta
	if _save_left <= 0:
		# Gra otwarta przez północ też zamyka poprzedni dzień.
		var news := _reflect()
		if not news.is_empty() and not busy(): say(news)
		flush()

func _local_now() -> float:
	return PersonalitySystem.local_now()

func _note(event: String) -> void:
	if writable:
		PersonalitySystem.record(pet, event, _local_now())
		_observe(event)

func _observe(event: String) -> void:
	if not writable: return
	var found := LifeSystem.observe(pet, event, Time.get_unix_time_from_system())
	if not found.is_empty():
		_discovery_message = "Poznajesz małe dziwactwo: %s. Zajrzyj do Albumu." % ", ".join(PackedStringArray(found))

func _update_life(seen: float, now: float, was_resting: bool) -> bool:
	if not writable: return false
	LifeSystem.refresh_mood(pet, now + float(Time.get_time_zone_from_system().bias) * 60.0)
	return LifeSystem.report_away(pet, seen, now, was_resting)

func _reflect() -> String:
	if not writable: return ""
	var notes := PersonalitySystem.reflect(pet, _local_now())
	return "" if notes.is_empty() else "%s: %s" % [notes[0].title, notes[0].detail]

func _lively() -> bool:
	return pet.habits.has("time_" + PersonalitySystem.part_of(_local_now()))

func _greeting(away: float = 3600) -> String:
	return LifeSystem.greeting(pet, away).text

# Samodzielna decyzja psa: odpoczynek, zachowanie wynikające z nawyku albo spacer.
func _spontaneous(roll: float = -1.0) -> void:
	if float(pet.needs.energy) < 28:
		act("rest", false)
		return
	for need in [["fullness", "hungry"], ["play", "bored"]]:
		if float(pet.needs[need[0]]) < 30 and float(cooldowns.get(need[1], 0)) <= 0:
			cooldowns[need[1]] = 60.0
			_approach(need[1], false)
			return
	if _initiative_wait <= 0 and offer_initiative(): return
	var lively := _lively()
	var options: Array = []
	if pet.habits.has("cuddler") and float(pet.needs.contact) < 80: options.append("cuddler")
	if pet.habits.has("playful") and float(pet.needs.play) < 80: options.append("playful")
	if pet.habits.has("student") and pose != "sit" and training.readiness(pet, "sit").is_empty(): options.append("student")
	if options.is_empty():
		match pet.life.mood:
			"cuddly": options.append("cuddler")
			"playful": options.append("playful")
			"curious": options.append("explorer")
			"sleepy", "calm": options.append("quiet")
	var chance := randf() if roll < 0 else roll
	if not options.is_empty() and chance < (0.6 if lively else 0.35):
		show_habit(options[randi() % options.size()])
	elif randf() < float(pet.traits.curiosity) + (0.15 if lively else 0.0):
		if randf() < 0.55:
			_approach("window" if randf() < float(pet.traits.curiosity) else "door", false)
		else:
			move_to(RoomLayout.random_walk_point(), false)

func show_habit(id: String) -> void:
	activity = "habit"
	activity_left = 1.5
	match id:
		"cuddler":
			pose = "stand"
			clip_requested.emit("tail_wag_stand")
			say("%s macha ogonem i czeka na głaskanie." % pet.pet_name)
		"playful":
			_approach("toys", false)
			return
		"student":
			pose = "sit"
			clip_requested.emit("sit_down")
			say("%s siada z własnej inicjatywy i czeka na komendę." % pet.pet_name)
		"explorer":
			_approach("window", false)
			return
		"quiet":
			pose = "sit"
			clip_requested.emit("sit_down")
			say("%s przysiada na chwilę. Dziś dobrze jest zwolnić." % pet.pet_name)
		_:
			activity = "idle"
			activity_left = 0
			return
	changed.emit()

func say(text: String) -> void:
	last_message = text
	feedback.emit(text)

func _inviting() -> bool:
	return activity in ["habit", "need", "initiative"] or (activity == "approach" and not _pending_by_player)

func busy() -> bool:
	# A floor walk or an autonomous invitation can always yield to the player.
	# A care approach, care animation and a training trial must finish or be cancelled.
	return play.running() or training.phase != "idle" or (not _inviting() and ((activity_left > 0 and activity != "pet") or activity == "approach"))

func can_pet() -> bool:
	return writable and not suspended and not pet.resting and not play.running() and training.phase == "idle" and (activity in ["idle", "pet", "habit", "need", "walk"] or _inviting())

func _cancel_motion() -> void:
	_approach_token += 1
	_pending_action = ""
	_pending_by_player = false
	activity_cancelled.emit()

func _approach(action: String, by_player: bool) -> void:
	_cancel_motion()
	_pending_action = action
	_pending_by_player = by_player
	activity = "approach"
	activity_left = 0
	pose = "stand"
	var messages := {
		"feed": "Już idzie do miski. Za chwilę mały posiłek.",
		"rest": "Czas na drzemkę. Drepcze do swojego legowiska.",
		"play": "Piłka w ruch! Małe łapki ruszają za nią.",
		"hungry": "%s zerka na miskę i podchodzi bliżej." % pet.pet_name,
		"bored": "%s szuka piłki. Ma ochotę na wspólną zabawę." % pet.pet_name,
		"toys": "%s zagląda do swojego kosza z zabawkami." % pet.pet_name,
		"window": "%s idzie sprawdzić, co słychać za oknem." % pet.pet_name,
		"door": "%s nasłuchuje przy drzwiach." % pet.pet_name
	}
	say(messages[action])
	if by_player: attention_requested.emit(false)
	approach_requested.emit(action, _approach_token)
	changed.emit()

# Only the current arrival may grant care effects; pause or a new action invalidates it.
func arrive_at(token: int) -> void:
	if suspended or not writable or activity != "approach" or token != _approach_token or _pending_action.is_empty(): return
	var action := _pending_action
	var by_player := _pending_by_player
	_pending_action = ""
	_pending_by_player = false
	activity = action
	activity_left = 2.0
	match action:
		"touch_ball":
			play.finish_ball()
			_settle_touch_game()
			return
		"rest":
			pet.resting = true
			_sleep_elapsed = 0
			activity = "sleep"
			activity_left = 0
			clip_requested.emit("sleep")
			say("Miękkie legowisko i spokojny odpoczynek. Po drzemce przyjdzie czas na nowe zajęcia.")
			pet.remember("rest", "Własne miejsce", "Pierwsza spokojna drzemka w nowym domu.")
		"feed":
			_apply_care_effects("feed", RoomLayout.station("feed").effects)
			cooldowns.feed = CARE_COOLDOWNS.feed
			clip_requested.emit("eat_loop")
			sound_requested.emit("eat")
			say("Mała porcja. %s zajada z apetytem." % pet.pet_name)
			pet.remember("feed", "Pierwsza wspólna miska", "Małe rytuały budują poczucie bezpieczeństwa.")
		"play":
			_apply_care_effects("play", RoomLayout.station("play").effects)
			cooldowns.play = CARE_COOLDOWNS.play
			clip_requested.emit("play_bow")
			say("Piłka złapana! Ukłon i zaproszenie do kolejnej rundy.")
			pet.remember("play", "Zabawa we dwoje", "Pierwszy wspólny czas na zabawę.")
		"hungry", "bored":
			activity = "need"
			clip_requested.emit("bark_stand" if action == "hungry" else "play_bow")
			say("%s szczeka przy misce. Ma ochotę na jedzenie." % pet.pet_name if action == "hungry" else "%s trąca piłkę i zaprasza Cię do zabawy." % pet.pet_name)
		"toys", "window", "door":
			activity = "need"
			activity_left = 3.0
			var station := RoomLayout.station(action)
			clip_requested.emit(station.clip)
			if by_player:
				_apply_care_effects(action, station.effects)
				cooldowns[action] = 30.0
			say({"toys": "%s wybiera zabawkę i zaprasza Cię do zabawy.", "window": "%s z ciekawością patrzy na świat za oknem.", "door": "%s nadstawia uszu. Kto tam idzie?"}[action] % pet.pet_name)
	if by_player and action in ["feed", "rest", "play", "toys"]: _note("play" if action == "toys" else action)
	if action in ["window", "door"]: _observe(action)
	elif not by_player and action in ["rest", "toys"]: _observe("play" if action == "toys" else action)
	flush()
	changed.emit()

func _wake() -> void:
	pet.resting = false
	_sleep_elapsed = 0
	activity = "idle"
	activity_left = 0
	pose = "stand"
	clip_requested.emit("idle")
	say("Koniec drzemki. Czas na Wasz dzień.")
	flush()
	changed.emit()

func _pet() -> bool:
	if not can_pet():
		if activity == "feed":
			say("Teraz zajada. Za chwilę znów będzie czas na głaskanie.")
		elif training.phase != "idle":
			say("Skupia się na komendzie. Po ćwiczeniu będzie czas na głaskanie.")
		elif pet.resting:
			say("Śpi spokojnie. Dotknij legowiska, aby zakończyć drzemkę.")
		else:
			say("Kończy swoją czynność. Zaraz będzie czas na głaskanie.")
		return false
	_answer_action("cuddle")
	_cancel_motion()
	pose = "stand"
	activity = "pet"
	activity_left = 0.7
	# Touch always gets a response; only stat gains have a cooldown.
	if float(cooldowns.get("pet", 0)) <= 0:
		_apply_care_effects("pet", {"contact": 18, "play": 3})
		pet.bond = minf(100, pet.bond + 0.6)
		cooldowns.pet = CARE_COOLDOWNS.pet
		pet.remember("pet", "Coraz bliżej", "Pierwsze głaskanie i odrobina zaufania.")
		_note("pet")
		flush()
	attention_requested.emit(true)
	clip_requested.emit("petted_stand")
	sound_requested.emit("pet")
	sound_requested.emit("pet_happy")
	say("Przymyka oczy. Lubi być blisko Ciebie.")
	changed.emit()
	return true

func act(action: String, by_player: bool = true) -> bool:
	if not writable or suspended: return false
	if action == "pet": return _pet()
	if busy() and not (training.phase == "idle" and _inviting()):
		say("Jeszcze chwilka — kończymy tę czynność.")
		return false
	if action == "rest" and pet.resting:
		_wake()
		return true
	if pet.resting:
		say("Najpierw delikatnie obudź pieska.")
		return false
	var satisfied := _satisfied_message(action)
	if not satisfied.is_empty():
		say(satisfied)
		return false
	if float(cooldowns.get(action, 0)) > 0:
		say("Jeszcze chwila radości z tej czynności.")
		return false
	if action not in ["feed", "rest", "play", "toys", "window", "door", "clean"]: return false
	if by_player: _answer_action("ball" if action in ["play", "toys"] else action)
	if action in ["feed", "rest", "play", "toys", "window", "door"]:
		_approach(action, by_player)
		return true
	if action != "clean": return false
	_cancel_motion()
	pose = "stand"
	activity = "clean"
	activity_left = 2.0
	_apply_care_effects("clean", {"hygiene": 25, "contact": 5})
	cooldowns.clean = CARE_COOLDOWNS.clean
	clip_requested.emit("petted_stand")
	sound_requested.emit("brush")
	say("Kilka ruchów szczotką i sierść znów jest miękka.")
	pet.remember("clean", "Mały rytuał pielęgnacji", "Spokojne czesanie i chwila bliskości.")
	if by_player: _note(action)
	flush()
	changed.emit()
	return true

func _satisfied_message(action: String) -> String:
	var need: String = {"feed": "fullness", "play": "play", "toys": "play", "clean": "hygiene"}.get(action, "")
	if need.is_empty() or float(pet.needs[need]) < SATISFIED_NEED: return ""
	return {
		"fullness": "Brzuszek jest pełny. Miska poczeka na później.",
		"play": "Na razie wystarczy zabawy. Ma ochotę na spokojną chwilę razem.",
		"hygiene": "Sierść jest już czysta. Może zamiast szczotki trochę głaskania?"
	}[need]

func move_to(world_position: Vector2, announce: bool = true) -> void:
	if not writable or busy() or pet.resting or suspended: return
	if announce: _answer_action("walk")
	_cancel_motion()
	pose = "stand"
	activity = "walk"
	activity_left = 0
	destination_requested.emit(RoomLayout.clamp_walk(world_position))
	if announce: attention_requested.emit(false)
	clip_requested.emit("walk")
	if announce: say("Już idę! Małe łapki odkrywają pokój.")
	changed.emit()

func destination_reached() -> void:
	if activity != "walk": return
	activity = "idle"
	clip_requested.emit("idle")
	changed.emit()

func performance_finished(trial_id: int) -> void:
	if trial_id == training.trial_id and training.phase == "attempt" and not suspended:
		performance_done = true

func begin_training(key: String, guided: bool) -> bool:
	if not writable or suspended: return false
	if busy() and not (training.phase == "idle" and _inviting()):
		say("Poczekaj, aż piesek skończy tę czynność.")
		return false
	var tired := pet.fatigue >= 50
	var result := training.begin(pet, key, guided)
	if not result.ok:
		say(result.message)
		return false
	_answer_action("training")
	_cancel_motion()
	activity_left = 0
	_note("train_guided" if guided else "train_free")
	if tired: _note("train_tired")
	activity = "idle"
	performance_done = false
	pose = "sit" if key in ["sit", "paw"] and training.will_succeed else "stand"
	var clip: String = {"come": "walk", "sit": "sit_down", "paw": "give_paw"}[key] if training.will_succeed else "head_tilt_stand"
	attention_requested.emit(true)
	performance_requested.emit(clip, training.trial_id)
	say(result.message)
	flush()
	changed.emit()
	return true

func give_reward(kind: String) -> bool:
	if suspended or not writable: return false
	var result := training.reward(pet, kind)
	if not result.ok:
		say(result.message)
		return false
	_note("reward_" + kind)
	sound_requested.emit("success")
	if kind == "treat": sound_requested.emit("treat")
	activity = "happy"
	activity_left = 1.4
	if pose == "sit":
		clip_requested.emit("tail_wag_sit")
	else:
		clip_requested.emit("treat_take_stand" if kind == "treat" else "tail_wag_stand")
	say(result.message)
	flush()
	changed.emit()
	return true

func rename_pet(value: String) -> bool:
	var clean := value.strip_edges().replace("\n", " ").replace("\t", " ")
	if not writable or clean.is_empty(): return false
	pet.pet_name = clean.left(24)
	flush()
	changed.emit()
	return true

func flush() -> bool:
	if pet == null or storage == null: return false
	_save_left = 25.0
	if not writable:
		save_ok = false
		return false
	pet.last_seen_at = maxf(pet.last_seen_at, Time.get_unix_time_from_system())
	save_ok = storage.save_pet(pet)
	save_status.emit(save_ok)
	return save_ok

func suspend_session() -> void:
	if not active or suspended: return
	_cancel_invitation()
	cancel_touch_game()
	training.cancel()
	_cancel_motion()
	activity_left = 0
	activity = "sleep" if pet.resting else "idle"
	suspended = true
	flush()

func resume_session() -> void:
	if not active or not suspended: return
	var now := Time.get_unix_time_from_system()
	var seen := pet.last_seen_at
	var was_resting := pet.resting
	var away := maxf(0, now - seen)
	NeedsSystem.catch_up(pet, now)
	suspended = false
	activity = "sleep" if pet.resting else "idle"
	if pet.resting: place_requested.emit("rest")
	clip_requested.emit("sleep" if pet.resting else "idle")
	pose = "stand"
	var news := _reflect()
	var report := _update_life(seen, now, was_resting)
	if away > 300:
		_note("visit")
		say(_greeting(away))
		clip_requested.emit(LifeSystem.greeting(pet, away).clip)
	elif not news.is_empty():
		say(news)
	flush()
	changed.emit()
	if report: away_report_ready.emit()

func offer_initiative(kind: String = "", now: float = -1.0) -> bool:
	if not active or not writable or suspended or not initiatives_enabled or not attention_available or busy() or pet.resting or not invitation.is_empty() or not play.kind.is_empty(): return false
	if now < 0: now = Time.get_unix_time_from_system()
	if not is_finite(now) or now - float(pet.social.last_offer_at) < InitiativeSystem.OFFER_INTERVAL: return false
	if kind.is_empty(): kind = InitiativeSystem.choose(pet)
	if not PetState.INITIATIVE_KEYS.has(kind) or float(InitiativeSystem.weights(pet)[kind]) <= 0: return false
	_cancel_motion()
	activity = "initiative"
	activity_left = 0
	pose = "sit" if kind == "cuddle" else "stand"
	invitation = {"kind": kind, "remaining": InitiativeSystem.RESPONSE_SECONDS}
	pet.social.last_offer_at = maxf(float(pet.social.last_offer_at), now)
	if kind == "cuddle":
		clip_requested.emit("give_paw")
	else:
		_approach("bored" if kind == "ball" else "toys", false)
	initiative_requested.emit(kind)
	say(InitiativeSystem.invitation_text(pet, kind))
	flush()
	changed.emit()
	return true

func _cancel_invitation() -> void:
	var was_inviting := not invitation.is_empty() and _inviting()
	invitation.clear()
	_initiative_wait = InitiativeSystem.OFFER_INTERVAL
	if was_inviting:
		_cancel_motion()
		activity = "idle"
		activity_left = 0
		clip_requested.emit("sit_idle" if pose == "sit" else "idle")

func _finish_invitation(response: String) -> void:
	if invitation.is_empty() or not writable: return
	var kind: String = invitation.kind
	_cancel_invitation()
	InitiativeSystem.record(pet, kind, response, Time.get_unix_time_from_system())
	flush()
	changed.emit()

func _answer_action(kind: String) -> void:
	if invitation.is_empty(): return
	if kind == invitation.kind:
		_finish_invitation("accepted")
	else:
		# Caring in another way is not a rejection of the dog.
		_cancel_invitation()

func decline_invitation() -> void:
	if suspended or invitation.is_empty(): return
	_finish_invitation("declined")
	say("Dobrze, może później. Teraz chwila własnych spraw.")

func accept_invitation() -> bool:
	if suspended or invitation.is_empty(): return false
	var kind: String = invitation.kind
	if kind == "cuddle": return act("pet")
	if kind == "ball":
		if not play_readiness().is_empty():
			say(play_readiness())
			return false
		_finish_invitation("accepted")
		ball_aim_requested.emit()
		return true
	return start_touch_game(kind)

func play_readiness() -> String:
	if not writable: return "Najpierw trzeba odzyskać poprawny zapis."
	if suspended: return "Wróć do gry, żeby się pobawić."
	if busy(): return "Dokończmy najpierw tę czynność."
	if pet.resting: return "Najpierw spokojnie obudź pieska."
	if float(pet.needs.energy) < 28 or pet.fatigue >= 85: return "Najpierw chwila odpoczynku, potem zabawa."
	return ""

func start_touch_game(kind: String) -> bool:
	if kind not in ["tug", "cups"]: return false
	return _begin_touch_game(kind)

func _begin_touch_game(kind: String) -> bool:
	if not PetState.PLAY_KEYS.has(kind): return false
	var reason := play_readiness()
	if not reason.is_empty():
		say(reason)
		return false
	_answer_action(kind)
	_cancel_motion()
	play.start(kind)
	activity = "touch_play"
	activity_left = 0
	pose = "stand"
	clip_requested.emit("play_bow")
	attention_requested.emit(false)
	if kind != "ball": touch_game_opened.emit(kind)
	changed.emit()
	return true

func throw_ball(target: Vector2) -> bool:
	if not target.is_finite() or not _begin_touch_game("ball"): return false
	activity = "approach"
	_pending_action = "touch_ball"
	_pending_by_player = true
	say("Piłka w ruch! Łapiemy razem.")
	ball_throw_requested.emit(RoomLayout.clamp_walk(target), _approach_token)
	changed.emit()
	return true

func play_press(point: Vector2) -> void:
	if writable and not suspended: play.press(point)

func play_move(point: Vector2) -> void:
	if not writable or suspended: return
	play.move(point)
	_settle_touch_game()

func play_release(point: Vector2, cancelled: bool = false) -> void:
	if not writable or suspended: return
	play.release(point, cancelled)
	_settle_touch_game()

func _settle_touch_game() -> void:
	if play.phase != "result" or play.settled or suspended or not writable: return
	play.settled = true
	var kind := play.kind
	pet.social.games[kind] = mini(PetState.MAX_EVENT_COUNT, int(pet.social.games[kind]) + 1)
	var now := Time.get_unix_time_from_system()
	if play.success and now - float(pet.social.last_reward_at) >= TouchPlaySystem.REWARD_INTERVAL:
		pet.social.last_reward_at = maxf(float(pet.social.last_reward_at), now)
		_apply_care_effects("play", {"play": 18, "contact": 6, "energy": -3, "hygiene": -1})
		pet.bond = minf(100, pet.bond + 0.35)
		_note("play")
	pet.remember("touch_play_" + kind, "Wspólna zabawa: " + InitiativeSystem.LABELS[kind], "Pierwsza runda zabawy sterowanej dotykiem.", now)
	activity = "happy"
	activity_left = 1.4
	clip_requested.emit("tail_wag_stand" if play.success else "head_tilt_stand")
	if play.success: sound_requested.emit("success")
	say(play.hint())
	if kind == "ball": play.reset()
	flush()
	changed.emit()

func cancel_touch_game() -> void:
	if play.kind.is_empty(): return
	play.reset()
	_cancel_motion()
	activity = "idle"
	activity_left = 0
	pose = "stand"
	clip_requested.emit("idle")
	touch_game_closed.emit()
	changed.emit()

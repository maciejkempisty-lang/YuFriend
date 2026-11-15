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
var last_message: String = "Dotknij pieska, żeby go pogłaskać. Miska i legowisko też czekają."
var _refresh_left: float = 0.0
var _save_left: float = 25.0
var _brain_left: float = 8.0
var performance_done: bool = true
var _approach_token: int = 0
var _pending_action: String = ""
var _pending_by_player: bool = false
var _sleep_elapsed: float = 0.0

const SATISFIED_NEED := 95.0

func start(save_path: String = "user://pet.json") -> void:
	storage = SaveSystem.new(save_path)
	var loaded := storage.load_pet()
	pet = loaded.pet
	writable = loaded.writable
	var away := NeedsSystem.catch_up(pet, Time.get_unix_time_from_system())
	var news := _reflect()
	if writable and (loaded.status == "new" or away > 300): _note("visit")
	if loaded.status == "migration_failed":
		last_message = storage.last_error
	elif not writable:
		last_message = "Nie udało się odczytać postępu. Dotychczasowy zapis pozostaje zachowany."
	elif loaded.status == "recovered":
		last_message = "Postęp został odzyskany z kopii. Możecie grać dalej."
	elif not news.is_empty():
		last_message = news
	elif away > 300:
		last_message = _greeting()
	active = true
	if pet.resting and float(pet.needs.energy) >= NeedsSystem.WAKE_ENERGY:
		pet.resting = false
	if pet.resting:
		activity = "sleep"
		place_requested.emit("rest")
		clip_requested.emit("sleep")
	elif away > 300:
		clip_requested.emit("bark_stand")
	flush()
	changed.emit()

func _process(delta: float) -> void:
	if not active or suspended: return
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
	if training.phase == "idle" and activity == "idle" and not pet.resting:
		_brain_left -= delta
		if _brain_left <= 0:
			_brain_left = randf_range(9, 15)
			_spontaneous()
	_refresh_left -= delta
	if _refresh_left <= 0:
		_refresh_left = 0.15
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
	if writable: PersonalitySystem.record(pet, event, _local_now())

func _reflect() -> String:
	if not writable: return ""
	var notes := PersonalitySystem.reflect(pet, _local_now())
	return "" if notes.is_empty() else "%s: %s" % [notes[0].title, notes[0].detail]

func _lively() -> bool:
	return pet.habits.has("time_" + PersonalitySystem.part_of(_local_now()))

func _greeting() -> String:
	if pet.resting: return "%s odpoczywa w swoim legowisku. Wstanie, gdy odzyska siły." % pet.pet_name
	if float(pet.needs.energy) < 28: return "%s cieszy się, że jesteś. Przyda mu się krótka drzemka." % pet.pet_name
	if float(pet.needs.fullness) < 30: return "%s wita Cię i zerka w stronę miski." % pet.pet_name
	if float(pet.needs.play) < 30: return "%s czeka na Ciebie i wspólną zabawę piłką." % pet.pet_name
	if _lively(): return "%s czekał na Ciebie o swojej ulubionej porze!" % pet.pet_name
	return "Dobrze, że jesteś. %s czeka na wspólną chwilę." % pet.pet_name

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
	var lively := _lively()
	var options: Array = []
	if pet.habits.has("cuddler") and float(pet.needs.contact) < 80: options.append("cuddler")
	if pet.habits.has("playful") and float(pet.needs.play) < 80: options.append("playful")
	if pet.habits.has("student") and pose != "sit" and training.readiness(pet, "sit").is_empty(): options.append("student")
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
			say("%s siada sam z siebie i czeka na komendę." % pet.pet_name)
		_:
			activity = "idle"
			activity_left = 0
			return
	changed.emit()

func say(text: String) -> void:
	last_message = text
	feedback.emit(text)

func _inviting() -> bool:
	return activity in ["habit", "need"] or (activity == "approach" and not _pending_by_player)

func busy() -> bool:
	# A floor walk or an autonomous invitation can always yield to the player.
	# A care approach, care animation and a training trial must finish or be cancelled.
	return training.phase != "idle" or (not _inviting() and ((activity_left > 0 and activity != "pet") or activity == "approach"))

func can_pet() -> bool:
	return writable and not suspended and not pet.resting and training.phase == "idle" and (activity in ["idle", "pet", "habit", "need", "walk"] or _inviting())

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
		"rest":
			pet.resting = true
			_sleep_elapsed = 0
			activity = "sleep"
			activity_left = 0
			clip_requested.emit("sleep")
			say("Miękkie legowisko i spokojny odpoczynek. Sam wstanie, gdy się wyśpi.")
			pet.remember("rest", "Własne miejsce", "Pierwsza spokojna drzemka w nowym domu.")
		"feed":
			NeedsSystem.change(pet, RoomLayout.station("feed").effects)
			cooldowns.feed = 10.0
			clip_requested.emit("eat_loop")
			say("Mała porcja. %s zajada z apetytem." % pet.pet_name)
			pet.remember("feed", "Pierwsza wspólna miska", "Małe rytuały budują poczucie bezpieczeństwa.")
		"play":
			NeedsSystem.change(pet, RoomLayout.station("play").effects)
			cooldowns.play = 8.0
			clip_requested.emit("play_bow")
			say("Dopadł piłkę! Ukłon i zaproszenie do kolejnej rundy.")
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
				NeedsSystem.change(pet, station.effects)
				cooldowns[action] = 30.0
			say({"toys": "%s wybiera zabawkę i zaprasza Cię do zabawy.", "window": "%s patrzy za okno, zaciekawiony małym światem.", "door": "%s nadstawia uszu. Kto tam idzie?"}[action] % pet.pet_name)
	if by_player and action in ["feed", "rest", "play", "toys"]: _note("play" if action == "toys" else action)
	flush()
	changed.emit()

func _wake() -> void:
	pet.resting = false
	_sleep_elapsed = 0
	activity = "idle"
	activity_left = 0
	pose = "stand"
	clip_requested.emit("idle")
	say("Wyspany i gotowy na Wasz dzień.")
	flush()
	changed.emit()

func _pet() -> bool:
	if not can_pet():
		if activity == "feed":
			say("Teraz zajada. Za chwilę znów będzie czas na głaskanie.")
		elif training.phase != "idle":
			say("Skupia się na komendzie. Pogłaszcz go po ćwiczeniu.")
		elif pet.resting:
			say("Śpi spokojnie. Dotknij legowiska, jeśli chcesz go obudzić.")
		else:
			say("Kończy swoją czynność. Zaraz będzie czas na głaskanie.")
		return false
	_cancel_motion()
	pose = "stand"
	activity = "pet"
	activity_left = 0.7
	# Touch always gets a response; only stat gains have a cooldown.
	if float(cooldowns.get("pet", 0)) <= 0:
		NeedsSystem.change(pet, {"contact": 18, "play": 3})
		pet.bond = minf(100, pet.bond + 0.6)
		cooldowns.pet = 4.0
		pet.remember("pet", "Coraz bliżej", "Pierwsze głaskanie i odrobina zaufania.")
		_note("pet")
		flush()
	attention_requested.emit(true)
	clip_requested.emit("petted_stand")
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
		say("Daj mu chwilę nacieszyć się tą chwilą.")
		return false
	if action in ["feed", "rest", "play", "toys", "window", "door"]:
		_approach(action, by_player)
		return true
	if action != "clean": return false
	_cancel_motion()
	pose = "stand"
	activity = "clean"
	activity_left = 2.0
	NeedsSystem.change(pet, {"hygiene": 25, "contact": 5})
	cooldowns.clean = 12.0
	clip_requested.emit("petted_stand")
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
	training.cancel()
	_cancel_motion()
	activity_left = 0
	activity = "sleep" if pet.resting else "idle"
	suspended = true
	flush()

func resume_session() -> void:
	if not active or not suspended: return
	var away := NeedsSystem.catch_up(pet, Time.get_unix_time_from_system())
	suspended = false
	activity = "sleep" if pet.resting else "idle"
	if pet.resting: place_requested.emit("rest")
	clip_requested.emit("sleep" if pet.resting else "idle")
	pose = "stand"
	var news := _reflect()
	if away > 300:
		_note("visit")
		say(news if not news.is_empty() else _greeting())
	elif not news.is_empty():
		say(news)
	flush()
	changed.emit()

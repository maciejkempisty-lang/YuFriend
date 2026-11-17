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
signal hide_revealed(spot: int)
var hide_game := YardHide.new()
var fetch := YardFetch.new()
var in_yard := false
var _yard_dark_idle := 0.0
var in_bath := false
var bath := BathSystem.new()
var sniff_spot := -1
const YARD_FINDS := ["Gładki kamyk", "Złoty liść", "Ulubiony patyk"]
var performance_done: bool = true
var _approach_token: int = 0
var _pending_action: String = ""
var _pending_by_player: bool = false
var _sleep_elapsed: float = 0.0
var _discovery_message: String = ""
var invitation: Dictionary = {}
var attention_available := true
# The top bubble may temporarily show a more urgent need instead of this offer.
var invitation_presented := true
var initiatives_enabled := true
var _initiative_wait := 90.0
var play := TouchPlaySystem.new()
# Injectable local clock; inactivity uses elapsed foreground time, not wall time.
var local_clock: Callable = PersonalitySystem.local_now
var training_view_active := false
var _reward_from_training := false
var night_sleep := false
var automatic_nap := false
var groggy_left := 0.0
var sleep_warning := false
var _idle_seconds := 0.0
var _woken_at_night := false
var _attention_shown := false
var _recent_behaviors: Array = []
var _last_behavior_place := ""
var _sequence: Array = []
var _sequence_id := ""
var _travel_left := 0.0
var _follow_target := Vector2.INF
var _follow_left := 0.0

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
	PracticeSystem.sync(pet, _local_now())
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
	_sync_rhythm_on_return()
	flush()
	changed.emit()
	if report: away_report_ready.emit()

func _process(delta: float) -> void:
	if not active or suspended: return
	var was_idle := activity == "idle"
	_tick_travel(delta)
	if in_yard: _tick_yard(delta)
	if not in_yard and not in_bath: _tick_rhythm(delta)
	if attention_available and not is_sleeping() and not busy():
		_initiative_wait = maxf(0, _initiative_wait - delta)
		if invitation_presented and not invitation.is_empty():
			invitation.remaining -= delta
			if float(invitation.remaining) <= 0: _finish_invitation("ignored")
	_tick_hide(delta)
	if fetch.advance(delta):
		play.finish_ball()
		_settle_touch_game()
	if play.running():
		play.advance(delta)
		_settle_touch_game()
	NeedsSystem.advance(pet, delta)
	if is_sleeping():
		_sleep_elapsed += delta
		if night_sleep:
			# Regeneration ends at the existing threshold; the visible night continues.
			if float(pet.needs.energy) >= NeedsSystem.WAKE_ENERGY: pet.resting = false
		elif automatic_nap:
			if _sleep_elapsed >= 180 or (_sleep_elapsed >= 60 and float(pet.needs.energy) >= NeedsSystem.WAKE_ENERGY): _wake(false)
		elif _sleep_elapsed >= 6 and float(pet.needs.energy) >= NeedsSystem.WAKE_ENERGY:
			_wake(false)
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
			if activity == "outing_pause":
				activity = "outing_praise"
				activity_left = 20
				say("Gotowe! Możesz pochwalić pieska przy płocie.")
			elif activity == "sniff":
				_finish_sniff()
			elif not _sequence_id.is_empty():
				_advance_behavior()
			elif activity in ["feed", "play", "happy"] and not _reward_from_training and not training_view_active and not in_yard and play.kind.is_empty():
				_start_behavior("carpet")
			else:
				activity = "idle"
				clip_requested.emit(PetAnimator.BASE.get(pose, "idle"))
	if was_idle and not training_view_active and training.phase == "idle" and activity == "idle" and not is_sleeping() and play.kind.is_empty() and invitation.is_empty():
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
		if writable:
			var practice_changed := PracticeSystem.sync(pet, _local_now())
			if LifeSystem.refresh_mood(pet, _local_now()) or practice_changed: flush()
		changed.emit()
	_save_left -= delta
	if _save_left <= 0:
		# Gra otwarta przez północ też zamyka poprzedni dzień.
		var news := _reflect()
		if not news.is_empty() and not busy(): say(news)
		flush()

func _local_now() -> float:
	return float(local_clock.call())

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
	DailyRhythm.adapt(pet, _local_now())
	return "" if notes.is_empty() else "%s: %s" % [notes[0].title, notes[0].detail]

func _greeting(away: float = 3600) -> String:
	return LifeSystem.greeting(pet, away).text

# Samodzielna decyzja psa: odpoczynek, zachowanie wynikające z nawyku albo spacer.
func _spontaneous(roll: float = -1.0) -> void:
	if not writable or suspended or training_view_active or is_sleeping(): return
	if in_yard:
		if not _return_tired(): move_to(RoomLayout.random_walk_point(), false)
		return
	if float(pet.needs.energy) < 28:
		act("rest", false)
		return
	if DailyRhythm.phase(pet, _local_now()) == "morning" and YardRoutines.due(self) and float(cooldowns.get("outing", 0)) <= 0:
		cooldowns["outing"] = 3600
		move_to(RoomLayout.STATIONS.door.stand, false)
		say("Może wyjdziemy na chwilę? Czekam przy drzwiach.")
		return
	for need in [["fullness", "hungry"], ["play", "bored"]]:
		# At night boredom asks for quiet company instead of a ball.
		if need[0] == "play" and DailyRhythm.quiet(pet, _local_now()): continue
		if float(pet.needs[need[0]]) < 30 and float(cooldowns.get(need[1], 0)) <= 0:
			cooldowns[need[1]] = 60.0
			_approach(need[1], false)
			return
	if _initiative_wait <= 0 and offer_initiative(): return
	var options := BehaviorSystem.weights(pet, _local_now(), _recent_behaviors, _last_behavior_place)
	_start_behavior(BehaviorSystem.choose(options, randf() if roll < 0 else roll))

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
	return activity in ["habit", "need", "initiative", "behavior"] or (activity == "approach" and not _pending_by_player)

func busy() -> bool:
	# A floor walk or an autonomous invitation can always yield to the player.
	# A care approach, care animation and a training trial must finish or be cancelled.
	return activity in ["outing_walk", "outing_pause", "outing_praise"] or hide_game.active() or in_bath or activity == "sniff_walk" or play.running() or training.phase != "idle" or (not _inviting() and ((activity_left > 0 and activity != "pet") or activity == "approach"))

func can_pet() -> bool:
	return writable and not suspended and not is_sleeping() and not play.running() and training.phase == "idle" and (activity in ["idle", "pet", "habit", "need", "walk"] or _inviting())

func _cancel_motion() -> void:
	sniff_spot = -1
	_reward_from_training = false
	_sequence.clear()
	_sequence_id = ""
	_travel_left = 0
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
			_travel_left = 0
			if fetch.active:
				fetch.arrive()
				activity = "catch"
				activity_left = 0
				clip_requested.emit("play_bow")
				say("Teraz! Dotknij pieska przy złapaniu piłki.")
				changed.emit()
				return
			play.finish_ball()
			_settle_touch_game()
			return
		"rest":
			night_sleep = DailyRhythm.phase(pet, _local_now()) == "night"
			DailyRhythm.note_nap(pet, _local_now())
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

func _wake(by_player: bool = true) -> void:
	var was_night := night_sleep
	night_sleep = false
	automatic_nap = false
	if by_player: player_activity()
	_woken_at_night = was_night and DailyRhythm.phase(pet, _local_now()) == "night"
	if _woken_at_night: groggy_left = 180.0
	_brain_left = 12.0
	pet.resting = false
	_sleep_elapsed = 0
	activity = "idle"
	activity_left = 0
	pose = "stand"
	clip_requested.emit("idle")
	say("Jeszcze chwila na rozbudzenie. Dobrze, że jesteś. Możecie pobyć razem." if _woken_at_night else "Koniec odpoczynku. Czas na Wasz dzień.")
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
	if by_player and action in ["pet", "feed", "rest", "play", "toys", "window", "door", "clean"]:
		player_activity()
		if action == "pet" and is_sleeping():
			_wake()
			return true
	if in_yard and action in ["feed", "rest", "toys", "window", "door", "clean"]:
		say("Wróćmy do domu, żeby się tym zająć.")
		return false
	if action == "pet": return _pet()
	if busy() and not (training.phase == "idle" and _inviting()):
		say("Jeszcze chwilka — kończymy tę czynność.")
		return false
	if action == "rest" and is_sleeping():
		_wake()
		return true
	if is_sleeping():
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
	if not writable or busy() or is_sleeping() or suspended: return
	if announce: _answer_action("walk")
	_cancel_motion()
	pose = "stand"
	activity = "walk"
	activity_left = 0
	destination_requested.emit(RoomLayout.clamp_walk(world_position))
	if announce: attention_requested.emit(false)
	clip_requested.emit("walk")
	_travel_left = 90.0
	if announce: say("Już idę! Małe łapki odkrywają podwórko." if in_yard else "Już idę! Małe łapki odkrywają pokój.")
	changed.emit()

func destination_reached() -> void:
	if suspended or not writable: return
	if in_yard and activity == "outing_walk":
		_travel_left = 0
		activity = "outing_pause"
		activity_left = 4
		clip_requested.emit("sniff")
		say("Chwila prywatności w trawie…")
		return
	if in_yard and activity == "hide_walk" and hide_game.arrive():
		_travel_left = 0
		activity = "hide_sniff"
		clip_requested.emit("sniff")
		say(hide_game.hint())
		changed.emit()
		return
	if in_yard and activity == "sniff_walk" and sniff_spot >= 0:
		_travel_left = 0
		activity = "sniff"
		activity_left = 3.0
		clip_requested.emit("sniff")
		say("Ciekawe, co kryje ten zapach…")
		changed.emit()
		return
	if activity != "walk": return
	_travel_left = 0
	if not _sequence_id.is_empty():
		_advance_behavior()
		return
	activity = "idle"
	clip_requested.emit("idle")
	changed.emit()

func performance_finished(trial_id: int) -> void:
	if trial_id == training.trial_id and training.phase == "attempt" and not suspended:
		performance_done = true

func begin_training(key: String, guided: bool) -> bool:
	if not writable or suspended: return false
	player_activity()
	if is_sleeping():
		say("Najpierw spokojnie obudź pieska.")
		return false
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
	pose = "sit" if key in ["sit", "paw", "stay"] and training.will_succeed else "stand"
	var clip: String = {"come": "walk", "sit": "sit_down", "paw": "give_paw", "lie": "lie_down", "bow": "play_bow", "bark": "bark_stand", "stay": "sit_down", "spin": "spin", "roll": "roll"}[key] if training.will_succeed else "head_tilt_stand"
	attention_requested.emit(true)
	performance_requested.emit(clip, training.trial_id)
	say(result.message)
	flush()
	changed.emit()
	return true

func give_reward(kind: String) -> bool:
	if suspended or not writable: return false
	player_activity()
	var result := training.reward(pet, kind)
	if not result.ok:
		say(result.message)
		return false
	var daily_bonus := PracticeSystem.record(pet, training.trick, _local_now())
	if daily_bonus: result.message = "Trening dnia ukończony! +2 więzi · seria %d dni." % int(pet.practice.streak)
	_note("reward_" + kind)
	sound_requested.emit("success")
	if kind == "treat": sound_requested.emit("treat")
	_reward_from_training = true
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
	if in_bath: cancel_bath()
	if not active or suspended: return
	_cancel_invitation()
	cancel_touch_game()
	training.cancel()
	if in_yard: change_yard(false)
	_cancel_motion()
	activity_left = 0
	activity = "sleep" if is_sleeping() else "idle"
	suspended = true
	flush()

func resume_session() -> void:
	if not active or not suspended: return
	var now := Time.get_unix_time_from_system()
	var seen := pet.last_seen_at
	var was_resting := pet.resting
	var away := maxf(0, now - seen)
	NeedsSystem.catch_up(pet, now)
	PracticeSystem.sync(pet, _local_now())
	suspended = false
	activity = "sleep" if is_sleeping() else "idle"
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
	if not in_yard and not in_bath: _sync_rhythm_on_return(away >= 60)
	flush()
	changed.emit()
	if report: away_report_ready.emit()

func offer_initiative(kind: String = "", now: float = -1.0) -> bool:
	if in_yard or in_bath: return false
	if not active or not writable or suspended or not initiatives_enabled or not attention_available or busy() or is_sleeping() or not invitation.is_empty() or not play.kind.is_empty(): return false
	if now < 0: now = Time.get_unix_time_from_system()
	if not is_finite(now) or now - float(pet.social.last_offer_at) < InitiativeSystem.OFFER_INTERVAL: return false
	if kind.is_empty(): kind = "cuddle" if DailyRhythm.quiet(pet, _local_now()) else InitiativeSystem.choose(pet)
	if DailyRhythm.quiet(pet, _local_now()) and kind != "cuddle": return false
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
	player_activity()
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
	if is_sleeping(): return "Najpierw spokojnie obudź pieska."
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

func throw_ball(target: Vector2, origin: Vector2 = RoomLayout.STATIONS.ball.position) -> bool:
	if not target.is_finite() or not origin.is_finite(): return false
	origin = RoomLayout.clamp_walk(origin)
	target = RoomLayout.clamp_walk(origin + (target - origin).limit_length(YardFetch.MAX_DISTANCE)) if in_yard else RoomLayout.clamp_walk(target)
	if in_yard and origin.distance_to(target) < 40: return false
	if not _begin_touch_game("ball"): return false
	if in_yard: fetch.start(origin, target)
	_travel_left = 90.0
	activity = "approach"
	_pending_action = "touch_ball"
	_pending_by_player = true
	say("Piłka w ruch! %s biegnie ją złapać." % pet.pet_name)
	ball_throw_requested.emit(RoomLayout.clamp_walk(target), _approach_token)
	changed.emit()
	return true

func catch_ball() -> bool:
	if not writable or suspended or not in_yard or not fetch.tap(): return false
	player_activity()
	play.finish_ball()
	_settle_touch_game()
	return true

func play_cue() -> void:
	if not writable or suspended: return
	play.cue()
	_settle_touch_game()
	changed.emit()

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
	var bonus := false
	var fetch_distance := fetch.distance
	var fetch_precise := fetch.precise
	var fetch_round := fetch.active and kind == "ball"
	var record := fetch_round and fetch_distance > pet.yard_record
	if record: pet.yard_record = fetch_distance
	if play.success and now - float(pet.social.last_reward_at) >= TouchPlaySystem.REWARD_INTERVAL:
		if in_yard: NeedsSystem.change(pet, {"hygiene": -9})
		pet.social.last_reward_at = maxf(float(pet.social.last_reward_at), now)
		_apply_care_effects("play", {"play": 18, "contact": 6, "energy": -3, "hygiene": -1})
		if fetch_round:
			var award := FetchRewards.award(pet, fetch_precise, _local_now())
			pet.bond = minf(100, pet.bond + float(award.bond))
			bonus = award.bonus
		else: pet.bond = minf(100, pet.bond + 0.35)
		_note("play")
	pet.remember("touch_play_" + kind, "Wspólna zabawa: " + InitiativeSystem.LABELS[kind], "Pierwsza runda zabawy sterowanej dotykiem.", now)
	_reward_from_training = false
	activity = "happy"
	activity_left = 1.4
	clip_requested.emit("tail_wag_stand" if play.success else "head_tilt_stand")
	if play.success: sound_requested.emit("success")
	say(play.hint())
	if fetch_round:
		say("Aport %.1f m! %s%s" % [fetch_distance, "Nowy rekord! " if record else "", ("Celnie! +1 więzi." if bonus else ("Celnie! Dzisiejsze premie wykorzystane." if int(pet.fetch_rewards.precise) >= FetchRewards.DAILY_LIMIT else "Celnie! Premia odpoczywa 30 s.") if fetch_precise else "Następnym razem dotknij pieska przy złapaniu.")])
	fetch.reset()
	if kind == "ball": play.reset()
	flush()
	changed.emit()

func cancel_touch_game() -> void:
	if hide_game.active(): cancel_hide()
	fetch.reset()
	if play.kind.is_empty(): return
	play.reset()
	_cancel_motion()
	activity = "idle"
	activity_left = 0
	pose = "stand"
	clip_requested.emit("idle")
	touch_game_closed.emit()
	changed.emit()

func is_sleeping() -> bool:
	return night_sleep or pet.resting

func walk_speed() -> float:
	return LifeSystem.walk_speed(pet) * (0.75 if groggy_left > 0 else (0.85 if DailyRhythm.quiet(pet, _local_now()) else 1.0))

func set_training_view(value: bool) -> void:
	if training_view_active == value: return
	training_view_active = value
	if not value: return
	player_activity()
	if not _sequence_id.is_empty():
		_cancel_motion()
		activity = "idle"
		activity_left = 0
		clip_requested.emit(PetAnimator.BASE.get(pose, "idle"))

func player_activity() -> void:
	_yard_dark_idle = 0
	_idle_seconds = 0
	sleep_warning = false
	_attention_shown = false
	_follow_target = Vector2.INF

func follow_room(point: Vector2) -> void:
	if not writable or suspended: return
	player_activity()
	_follow_target = RoomLayout.clamp_walk(point)
	_follow_left = 3.0

func _sync_rhythm_on_return(reset: bool = true) -> void:
	if not writable: return
	DailyRhythm.adapt(pet, _local_now())
	if DailyRhythm.phase(pet, _local_now()) == "night":
		if reset:
			# Opening the game is an invitation to meet, even before habits form.
			if is_sleeping(): _wake(false)
			_cancel_motion()
			activity = "idle"
			activity_left = 0
			pose = "stand"
			clip_requested.emit("tail_wag_stand")
			say("Dobrze, że jesteś! Chwila razem, zanim przyjdzie czas na sen.")
		elif night_sleep:
			clip_requested.emit("sleep")
	elif night_sleep:
		_wake(false)
	if reset:
		_idle_seconds = 0
		_woken_at_night = false
		sleep_warning = false

func _tick_rhythm(delta: float) -> void:
	groggy_left = maxf(0, groggy_left - delta)
	if not writable: return
	if night_sleep and DailyRhythm.phase(pet, _local_now()) != "night": _wake(false)
	if is_sleeping(): return
	# A round/result panel, training or continuous stroking keeps the dog awake.
	if training_view_active or not play.kind.is_empty() or training.phase != "idle" or activity in ["pet", "feed", "clean", "happy"] or (busy() and _sequence_id.is_empty()):
		_idle_seconds = 0
		sleep_warning = false
		return
	if not attention_available: return
	_idle_seconds += delta
	var night := DailyRhythm.phase(pet, _local_now()) == "night"
	if night:
		var limit := 120.0 if _woken_at_night else 180.0
		if _idle_seconds >= limit - 20 and not sleep_warning:
			sleep_warning = true
			say("Chce mi się spać. Za chwilę pójdę do legowiska. Dotknij mnie, jeśli chcesz jeszcze pobyć razem.")
		if _idle_seconds >= limit and _sequence_id != "night": _start_behavior("night")
	elif _idle_seconds >= 60 and _idle_seconds < 180 and not _attention_shown and not busy() and invitation.is_empty() and _sequence_id.is_empty():
		_attention_shown = true
		_start_behavior("wait")

func _start_behavior(id: String) -> void:
	if not invitation.is_empty(): _cancel_invitation()
	_cancel_motion()
	_sequence_id = id
	_sequence = BehaviorSystem.steps(id, pet, DailyRhythm.quiet(pet, _local_now()))
	if BehaviorSystem.BEHAVIORS.has(id):
		_recent_behaviors.push_front(id)
		if _recent_behaviors.size() > 3: _recent_behaviors.resize(3)
		_last_behavior_place = BehaviorSystem.BEHAVIORS[id][1]
	_advance_behavior()

func _advance_behavior() -> void:
	if _sequence.is_empty():
		var event: String = {"window": "window", "door": "door", "toys": "play"}.get(_sequence_id, "")
		_sequence_id = ""
		activity = "idle"
		activity_left = 0
		_brain_left = randf_range(9, 15)
		if not event.is_empty(): _observe(event)
		clip_requested.emit(PetAnimator.BASE.get(pose, "idle"))
		return
	var step: Dictionary = _sequence.pop_front()
	if step.has("point"):
		activity = "walk"
		activity_left = 0
		pose = "stand"
		_travel_left = 90.0
		destination_requested.emit(step.point)
		clip_requested.emit("walk")
	elif step.has("sleep"):
		if step.sleep == "night" and DailyRhythm.phase(pet, _local_now()) != "night":
			_cancel_motion()
			activity = "idle"
			clip_requested.emit("idle")
		else:
			_enter_sleep(step.sleep)
	else:
		activity = "behavior"
		activity_left = float(step.seconds)
		pose = PetAnimator.CLIPS[step.clip][1]
		clip_requested.emit(step.clip)
	changed.emit()

func _enter_sleep(kind: String, observe: bool = true) -> void:
	_cancel_invitation()
	_cancel_motion()
	night_sleep = kind == "night"
	automatic_nap = kind == "nap"
	pet.resting = not night_sleep or float(pet.needs.energy) < NeedsSystem.WAKE_ENERGY
	_sleep_elapsed = 0
	activity = "sleep"
	activity_left = 0
	pose = "sleep"
	if automatic_nap: DailyRhythm.note_nap(pet, _local_now())
	clip_requested.emit("sleep")
	say("Ciii… pora na nocny sen. Dotknij pieska, aby łagodnie go obudzić." if night_sleep else "Chwila drzemki. Dotknij pieska, kiedy chcesz pobyć razem.")
	if observe: _observe("rest")
	flush()
	changed.emit()

func change_yard(enabled: bool) -> bool:
	if enabled and DailyRhythm.phase(pet, _local_now()) == "night":
		say("Za ciemno, pora spać.")
		return false
	if in_bath: return false
	if not writable or suspended or is_sleeping() or training.phase != "idle": return false
	if enabled and busy(): return false
	cancel_touch_game()
	_cancel_motion()
	invitation.clear()
	_yard_dark_idle = 0
	_follow_target = Vector2.INF
	in_yard = enabled
	activity = "idle"
	activity_left = 0
	pose = "stand"
	clip_requested.emit("idle")
	say("Podwórko! Rzuć piłkę albo poszukaj zapachu." if enabled else "Znów w domu.")
	changed.emit()
	return true

func start_sniff(spot: int = -1) -> bool:
	if not in_yard or not writable or suspended or busy() or is_sleeping() or spot < -1 or spot >= YARD_FINDS.size(): return false
	if float(pet.needs.energy) < 25:
		say("Najpierw wróćmy do domu odpocząć.")
		return false
	_cancel_motion()
	sniff_spot = 0
	for index in YARD_FINDS.size():
		if not pet.milestones.has("yard_find_%d" % index):
			sniff_spot = index
			break
	if spot >= 0: sniff_spot = spot
	_travel_left = 90.0
	activity = "sniff_walk"
	activity_left = 0
	destination_requested.emit(Vector2(350 + sniff_spot * 400, 302))
	clip_requested.emit("walk")
	say("Prowadzi mnie ciekawy zapach…")
	changed.emit()
	return true

func _finish_sniff() -> void:
	if not in_yard or sniff_spot < 0 or suspended or not writable: return
	NeedsSystem.change(pet, {"hygiene": -8})
	var key := "yard_find_%d" % sniff_spot
	var label: String = YARD_FINDS[sniff_spot]
	var fresh := not pet.milestones.has(key)
	if fresh:
		pet.remember(key, "Znalezisko: " + label, "Pierwszy skarb odkryty podczas węszenia na podwórku.")
		NeedsSystem.change(pet, {"play": 5, "energy": -2})
		sound_requested.emit("success")
	sniff_spot = -1
	activity = "idle"
	activity_left = 0
	clip_requested.emit("tail_wag_stand")
	say("Znalezione: %s! Pamiątka czeka w Albumie." % label if fresh else "Znajomy zapach. Ten skarb jest już w Albumie — sprawdź też pozostałe krzaki.")
	flush()
	changed.emit()

func bath_readiness() -> String:
	if not writable or suspended or is_sleeping() or busy(): return "Kąpiel poczeka, aż piesek będzie gotowy."
	if float(pet.needs.energy) < 35: return "Najpierw odpoczynek. Kąpiel kosztuje 5 energii."
	if float(pet.needs.fullness) < 30: return "Najpierw posiłek, potem kąpiel."
	if float(pet.needs.hygiene) >= 80: return "Sierść jest dość czysta. Wystarczy delikatne czesanie."
	return ""

func start_bath() -> bool:
	var reason := bath_readiness()
	if not reason.is_empty():
		say(reason)
		return false
	_cancel_motion()
	invitation.clear()
	in_yard = false
	in_bath = true
	activity = "bath"
	activity_left = 0
	bath.start()
	changed.emit()
	return true

func finish_bath() -> bool:
	if not in_bath or not bath.active or bath.stage != 3 or bath.settled or not writable or suspended: return false
	bath.settled = true
	NeedsSystem.change(pet, {"hygiene": 45, "energy": -5, "fullness": -2})
	pet.remember("first_bath", "Pierwsza kąpiel", "Piana, woda, miękki ręcznik i radosne otrzepywanie.")
	sound_requested.emit("success")
	say("Kąpiel skończona: +45 czystości, −5 energii, −2 sytości.")
	flush()
	changed.emit()
	return true

func cancel_bath() -> void:
	bath.cancel()
	in_bath = false
	activity = "idle"
	activity_left = 0
	clip_requested.emit("idle")
	changed.emit()

func _tick_travel(delta: float) -> void:
	if not writable or suspended: return
	if _travel_left > 0:
		_travel_left -= delta
		if _travel_left <= 0:
			if hide_game.active(): cancel_hide()
			if play.kind == "ball": cancel_touch_game()
			_cancel_motion()
			activity = "idle"
			clip_requested.emit("idle")
	if _follow_target.is_finite() and not busy():
		_follow_left -= delta
		if _follow_left <= 0:
			var target := _follow_target
			_follow_target = Vector2.INF
			move_to(target, false)

func _tick_yard(delta: float) -> void:
	if not writable or suspended: return
	if _return_tired(): return
	if DailyRhythm.phase(pet, _local_now()) != "night" or busy():
		_yard_dark_idle = 0
		return
	_yard_dark_idle += delta
	if _yard_dark_idle < 30: return
	if change_yard(false):
		_start_behavior("night")
		say("Za ciemno. Wracamy do domu, pora spać.")

func start_hide(kind: String, seed_value: int = 0) -> bool:
	if not in_yard: return false
	var reason := play_readiness()
	if not reason.is_empty():
		say(reason)
		return false
	if DailyRhythm.phase(pet, _local_now()) == "night":
		say("Za ciemno na chowanego, pora spać.")
		return false
	if not hide_game.start(kind, seed_value): return false
	player_activity()
	_cancel_invitation()
	_cancel_motion()
	_follow_target = Vector2.INF
	activity = "hide"
	activity_left = 0
	pose = "stand"
	clip_requested.emit("idle")
	say(hide_game.hint())
	changed.emit()
	return true

func choose_hide_bush(spot: int) -> bool:
	if not writable or suspended or not in_yard or not hide_game.active(): return false
	var event := hide_game.select(spot)
	if event.is_empty(): return false
	player_activity()
	_handle_hide_event(event)
	return true

func _tick_hide(delta: float) -> void:
	if not writable or suspended or not hide_game.active(): return
	_handle_hide_event(hide_game.advance(delta))

func _handle_hide_event(event: String) -> void:
	if event.is_empty(): return
	match event:
		"timeout":
			cancel_hide()
			say("Chowany poczeka. Piesek wrócił — możecie zacząć jeszcze raz.")
		"walk":
			_cancel_motion()
			activity = "hide_walk"
			activity_left = 0
			_travel_left = 90
			destination_requested.emit(Vector2(350 + hide_game.search_spot() * 400, 302))
			clip_requested.emit("walk")
			say(hide_game.hint())
		"guess": say(hide_game.hint())
		"wrong": say("Tutaj go nie ma. Rozejrzyj się za machającym ogonem!")
		"found": _finish_hide()
	changed.emit()

func _finish_hide() -> void:
	if hide_game.phase != "found" or not writable or suspended: return
	var mode := hide_game.kind
	var spot := hide_game.hiding_spot
	hide_game.reset() # Consume the result before emitting any signals or granting rewards.
	_cancel_motion()
	_follow_target = Vector2.INF
	if mode == "dog": hide_revealed.emit(spot)
	var now := Time.get_unix_time_from_system()
	var rewarded := now - float(pet.social.last_reward_at) >= TouchPlaySystem.REWARD_INTERVAL
	if rewarded:
		pet.social.last_reward_at = maxf(float(pet.social.last_reward_at), now)
		_apply_care_effects("play", {"play": 12, "contact": 6, "energy": -2})
		pet.bond = minf(100, pet.bond + 0.5)
		_note("play")
	pet.remember("yard_hide_" + mode, "Smakołyk w krzakach" if mode == "treat" else "Ogon zdradził kryjówkę", "Pierwsza ukończona runda chowanego na podwórku.", now)
	activity = "happy"
	activity_left = 1.4
	clip_requested.emit("tail_wag_stand")
	sound_requested.emit("success")
	say(("Smakołyk znaleziony!" if mode == "treat" else "Jest piesek! Ogon go zdradził!") + (" +0,5 więzi." if rewarded else " Brawo! Nagrody odpoczywają 30 s."))
	flush()
	changed.emit()

func cancel_hide() -> void:
	if not hide_game.active(): return
	hide_game.reset()
	_cancel_motion()
	_follow_target = Vector2.INF
	activity = "idle"
	activity_left = 0
	clip_requested.emit("idle")
	changed.emit()

func _return_tired() -> bool:
	if not in_yard or busy() or float(pet.needs.energy) >= 28: return false
	if not change_yard(false): return false
	act("rest", false)
	say("Łapki potrzebują odpoczynku. Wracamy do legowiska.")
	return true

class_name CompanionVoice
extends RefCounted

# A presentation of real game state: no new needs, rewards or invented events.
const QUIET_SECONDS := 45.0
const NEED_LIMIT := 40.0
const NEEDS := {
	"fullness": ["Burczy mi w brzuchu. Zjemy coś?", "feed", "Nakarm"],
	"energy": ["Oczka mi się kleją. Czas na drzemkę.", "rest", "Drzemka"],
	"hygiene": ["Przydałoby się trochę czesania…", "clean", "Wyczesz"],
	"play": ["Mam ochotę na wspólną zabawę!", "play", "Pobaw się"],
	"contact": ["Chodź bliżej. Masz chwilę na głaski?", "pet", "Pogłaszcz"]
}
const INVITATIONS := {
	"ball": ["Rzucisz mi piłkę? Już czekam!", "Rzuć piłkę"],
	"tug": ["Chwycisz drugi koniec liny?", "Chwyć linę"],
	"cups": ["Schowaj smakołyk. Spróbuję go znaleźć!", "Schowaj"],
	"cuddle": ["Najbardziej mam ochotę na głaski.", "Pogłaszcz"]
}
const THOUGHTS := {
	"calm": ["Lubię te nasze spokojne chwile.", "pet", "Pogłaszcz"],
	"playful": ["A gdyby tak jeszcze chwilę się pobawić?", "play", "Pobaw się"],
	"cuddly": ["Najlepsze miejsce? Blisko Ciebie.", "pet", "Pogłaszcz"],
	"sleepy": ["Może we śnie dogonię tę piłkę…", "rest", "Drzemka"],
	"curious": ["Ciekawe, co słychać za oknem…", "window", "Do okna"]
}
const QUIRKS := {
	"sock_collector": "Skarpetki pachną prawie jak przytulanie.",
	"ball_guard": "Moja piłka. Pilnuję jej nawet jednym okiem.",
	"window_watch": "Za oknem zawsze jest coś do wypatrzenia.",
	"door_listener": "Każdy szelest za drzwiami ma swoją historię.",
	"toy_sorter": "Każda zabawka powinna mieć swoje miejsce.",
	"bed_circles": "Jeszcze kółeczko i legowisko będzie idealne.",
	"happy_wiggle": "Czasem radość nie mieści się w samym ogonie.",
	"brush_lean": "Szczotka za uszkiem… to jest przyjemne.",
	"meal_sniff": "Najpierw powąchać. To ważna część posiłku.",
	"sun_napper": "Plamka słońca to prawie drugie legowisko.",
	"head_tilter": "A jeśli przechylę głowę, lepiej zrozumiem?",
	"dream_runner": "We śnie mam chyba jeszcze szybsze łapki."
}
const MEMORIES := {
	"feed": "Pamiętam naszą pierwszą wspólną miskę.",
	"rest": "Pamiętam pierwszą drzemkę w tym domu.",
	"pet": "Nasze pierwsze głaski… od tego się zaczęło.",
	"clean": "Pamiętam nasze pierwsze spokojne czesanie.",
	"play": "Nasza pierwsza zabawa trafiła do albumu!",
	"first_come": "Pamiętasz pierwsze udane „przyjdź”?",
	"first_sit": "Pamiętasz nasze pierwsze udane „siad”?",
	"first_paw": "Pamiętasz pierwszą łapkę podaną na komendę?",
	"learned_come": "Tyle ćwiczeń „przyjdź”. Znamy się coraz lepiej.",
	"learned_sit": "Nasze ćwiczenia „siad” przyniosły efekty!",
	"learned_paw": "Podawanie łapki idzie nam coraz pewniej.",
	"touch_play_ball": "Pamiętasz naszą pierwszą zabawę piłką?",
	"touch_play_tug": "Pierwsze przeciąganie liny jest w albumie.",
	"touch_play_cups": "Pamiętasz naszą pierwszą zabawę w szukanie?"
}

var _context := ""
var _quiet_left := QUIET_SECONDS
var _quiet_index := 0

func describe(game: GameSession, visible_delta: float = 0.0) -> Dictionary:
	if game.pet == null: return {}
	var pet := game.pet
	if pet.resting:
		return _line("activity", "Ciii… zbieram siły na kolejne przygody.", "rest", "Obudź", game)
	if game.busy():
		var text: String = {
			"feed": "Mniam! Teraz pora na jedzenie.",
			"clean": "O tak… jeszcze trochę za uszkiem.",
			"happy": "Ale było miło! Jeszcze chwilka…"
		}.get(game.activity, "Jeszcze chwilka…")
		if game.activity == "approach":
			text = {"feed": "Już idę do miski!", "rest": "Już idę do legowiska.",
				"touch_ball": "Biegnę po piłkę!"}.get(game._pending_action, "Już biegnę!")
		return _line("activity", text, "", "", game)
	# Exhaustion prevents play even when the play meter is the lowest one.
	var need := "energy" if float(pet.needs.energy) < 28 or pet.fatigue >= 75 else ""
	var lowest := NEED_LIMIT
	if need.is_empty():
		for key in PetState.NEED_KEYS:
			if float(pet.needs[key]) < lowest:
				need = key
				lowest = float(pet.needs[key])
	if not need.is_empty():
		var words: Array = NEEDS[need]
		return _line("need", words[0], words[1], words[2], game)
	if not game.invitation.is_empty():
		var words: Array = INVITATIONS[game.invitation.kind]
		return _line("invitation", words[0], "invite:" + str(game.invitation.kind), words[1], game)
	var memories: Array = []
	for entry in pet.journal:
		if MEMORIES.has(entry.key):
			memories.append({"kind": "memory", "text": MEMORIES[entry.key], "action": "album", "label": "Zobacz album"})
			if memories.size() == 3: break
	var mood: String = pet.life.get("mood", "calm")
	var context := str([pet.pet_id, mood, pet.life.discovered, memories])
	if context != _context:
		_context = context
		_quiet_index = 0
		_quiet_left = QUIET_SECONDS
	var words: Array = THOUGHTS.get(mood, THOUGHTS.calm)
	var quiet: Array = memories.slice(0, 1)
	quiet.append({"kind": "thought", "text": words[0], "action": words[1], "label": words[2]})
	for quirk in pet.life.discovered:
		quiet.append({"kind": "thought", "text": QUIRKS[quirk], "action": "", "label": ""})
	quiet.append_array(memories.slice(1))
	_quiet_left -= maxf(0, visible_delta)
	if _quiet_left <= 0:
		_quiet_index = (_quiet_index + 1) % quiet.size()
		_quiet_left = QUIET_SECONDS
	var selected: Dictionary = quiet[_quiet_index % quiet.size()]
	return _line(selected.kind, selected.text, selected.action, selected.label, game)

func _line(kind: String, text: String, action: String, label: String, game: GameSession) -> Dictionary:
	var enabled := game.writable and not game.suspended
	if action == "album": enabled = not game.suspended
	elif action == "play": enabled = enabled and game.play_readiness().is_empty()
	elif action != "pet" and float(game.cooldowns.get(action, 0)) > 0: enabled = false
	return {"kind": kind, "text": text, "action": action, "label": label, "enabled": enabled}

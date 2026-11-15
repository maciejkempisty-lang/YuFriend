class_name LifeSystem
extends RefCounted

const REPORT_AFTER := 1800.0
const MORNING_HOUR := 5
const QUIRKS := {
	"sock_collector": {"label": "Kolekcja skarpetek", "event": "play", "detail": "Skarpetki to najlepszy skarb. Zagląda za nimi do kosza z zabawkami.", "away": "Do kolekcji przy legowisku dołączyła zagubiona skarpetka."},
	"ball_guard": {"label": "Piłka pod łapą", "event": "play", "detail": "Po zabawie przytrzymuje piłkę łapą, jak przy pilnowaniu skarbu.", "away": "Piłka spędziła dłuższą chwilę pod czujną łapą."},
	"window_watch": {"label": "Patrol przy oknie", "event": "window", "detail": "Ruch za oknem zawsze przyciąga uwagę. Każdy ptak wymaga sprawdzenia.", "away": "Za oknem przemknął ptak. Czujne oczy od razu go wypatrzyły."},
	"door_listener": {"label": "Czujne uszy", "event": "door", "detail": "Przy drzwiach nasłuchuje odgłosów korytarza z przekrzywioną głową.", "away": "Kroki za drzwiami wywołały krótkie nasłuchiwanie."},
	"toy_sorter": {"label": "Zabawki po swojemu", "event": "play", "detail": "Lubi zaglądać do kosza i urządzać zabawki po swojemu.", "away": "W koszu z zabawkami odbyły się małe porządki nosem."},
	"bed_circles": {"label": "Kółko przed snem", "event": "rest", "detail": "Przed drzemką trzeba obejść legowisko. Dopiero wtedy jest wygodnie.", "away": "Przed drzemką było małe kółko wokół legowiska."},
	"happy_wiggle": {"label": "Radość całym ciałem", "event": "pet", "detail": "Przy głaskaniu sam ogon nie wystarcza — cieszy się całym ciałem.", "away": "Znajomy zapach na kocyku wystarczył do krótkiego merdania ogonem."},
	"brush_lean": {"label": "Jeszcze jeden ruch", "event": "clean", "detail": "Przy czesaniu nadstawia bok, prosząc o jeszcze jeden ruch szczotki.", "away": "Szczotka doczekała się dokładnych oględzin i trącenia nosem."},
	"meal_sniff": {"label": "Najpierw obwąchać", "event": "feed", "detail": "Każdy posiłek zaczyna się od starannego obwąchania miski.", "away": "Miska przeszła dokładną kontrolę małego nosa."},
	"sun_napper": {"label": "W poszukiwaniu ciepła", "event": "rest", "detail": "Na drzemkę zawsze szuka najcieplejszego zakątka legowiska.", "away": "Najcieplejszy zakątek legowiska okazał się idealny na odpoczynek."},
	"head_tilter": {"label": "Głowa na bok", "event": "train_guided", "detail": "Nowemu gestowi przygląda się z charakterystycznie przekrzywioną głową.", "away": "Cichy szelest skłonił do przechylenia głowy raz w jedną, raz w drugą stronę."},
	"dream_runner": {"label": "Bieg przez sen", "event": "rest", "detail": "Podczas drzemki łapki czasem drgają, jakby we śnie trwał pościg.", "away": "Podczas drzemki łapki drgały. Może to sen o wielkiej gonitwie?"},
}
const MOODS := {
	"calm": {"label": "Spokojny dzień", "speed": 0.95},
	"playful": {"label": "Ochota na psoty", "speed": 1.12},
	"cuddly": {"label": "Blisko Ciebie", "speed": 1.0},
	"sleepy": {"label": "Senny dzień", "speed": 0.85},
	"curious": {"label": "Czas na odkrycia", "speed": 1.06},
}

static func mood_label(pet: PetState) -> String:
	return MOODS[pet.life.mood].label

static func walk_speed(pet: PetState) -> float:
	return MOODS[pet.life.mood].speed

# One new mood at the first session/tick after 05:00 local time. A clock rollback
# never recomputes a day. Only yesterday's recorded activity enters the scores.
static func refresh_mood(pet: PetState, local_seconds: float) -> bool:
	if not is_finite(local_seconds) or local_seconds < 0: return false
	var day := PersonalitySystem.day_of(maxf(0, local_seconds - MORNING_HOUR * 3600))
	if day <= int(pet.life.mood_day): return false
	var events: Dictionary = {}
	for bucket in pet.history:
		if int(bucket.day) == day - 1: events = bucket.events
	var play := minf(float(events.get("play", 0)), 5)
	var contact := minf(float(events.get("pet", 0)) + float(events.get("reward_praise", 0)), 6)
	var training := minf(float(events.get("train_guided", 0)) + float(events.get("train_free", 0)), 6)
	var scores := {
		"calm": float(pet.traits.patience) * 2 + minf(float(events.get("rest", 0)), 3) * 0.6,
		"playful": float(pet.traits.curiosity) * 2 + play * 0.7,
		"cuddly": float(pet.traits.sociability) * 2 + contact * 0.5,
		"sleepy": float(pet.traits.sensitivity) * 2 + minf(float(events.get("train_tired", 0)), 3) * 1.5 + training * 0.25,
		"curious": float(pet.traits.curiosity) * 2 + minf(float(events.get("train_free", 0)), 5) * 0.6,
	}
	var rng := RandomNumberGenerator.new()
	rng.seed = pet.personality_seed + day * 31
	var mood := "calm"
	var best := -1.0
	for id in PetState.MOOD_KEYS:
		var score: float = scores[id] + rng.randf_range(0, 0.4)
		if score > best:
			best = score
			mood = id
	pet.life.mood = mood
	pet.life.mood_day = day
	pet.life.mood_reason = "Dziś o nastroju decyduje głównie temperament."
	if not events.is_empty():
		pet.life.mood_reason = {
			"calm": "Wczorajszy odpoczynek sprzyja spokojnej chwili." if float(events.get("rest", 0)) > 0 else "Spokojny temperament zachęca do odpoczynku razem.",
			"playful": "Wczorajsza zabawa zachęca do kolejnych psot." if play > 0 else "Ciekawość podpowiada, że dziś jest dobry dzień na psoty.",
			"cuddly": "Wczorajsze pieszczoty zachęcają do bliskości." if contact > 0 else "Towarzyski temperament zachęca do bliskości.",
			"sleepy": "Po wczorajszych ćwiczeniach dziś chętniej wybiera spokojniejsze tempo." if training > 0 else "Wrażliwy temperament podpowiada dziś spokojniejsze tempo.",
			"curious": "Wczorajsze samodzielne próby zachęcają do kolejnych odkryć." if float(events.get("train_free", 0)) > 0 else "Ciekawski temperament zachęca do rozglądania się po pokoju.",
		}[mood]
	return true

static func _observe_quirk(pet: PetState, id: String, now: float) -> String:
	if pet.life.discovered.has(id): return ""
	var count := mini(3, int(pet.life.observations.get(id, 0)) + 1)
	pet.life.observations[id] = count
	if count < 3: return ""
	pet.life.discovered.append(id)
	var key := "quirk_" + id
	var title: String = "Małe dziwactwo: " + QUIRKS[id].label
	if not pet.remember(key, title, QUIRKS[id].detail, now) and not pet.milestones.has(key):
		# The discovered list already prevents duplicates in a legacy save whose
		# permanent milestone budget is full; the bounded album can still show it.
		pet.add_journal_entry(key, title, QUIRKS[id].detail, now)
	return QUIRKS[id].label

static func observe(pet: PetState, event: String, now: float) -> Array:
	var found: Array = []
	for id in pet.life.quirks:
		if QUIRKS[id].event != event: continue
		var label := _observe_quirk(pet, id, now)
		if not label.is_empty(): found.append(label)
	return found

static func quirk_lines(pet: PetState) -> Array:
	var lines: Array = []
	for id in pet.life.quirks:
		lines.append(QUIRKS[id].label if pet.life.discovered.has(id) else "Jeszcze nieznane")
	return lines

# Local simulation: no player actions, rewards, learned skills or trait changes
# are fabricated. The report is bounded and deduplicated by the elapsed interval.
static func report_away(pet: PetState, from: float, now: float, was_resting: bool) -> bool:
	if not is_finite(from) or not is_finite(now) or from < 0 or now - from < REPORT_AFTER: return false
	var previous: Dictionary = pet.life.away_report
	if not previous.is_empty() and from < float(previous.until): return false
	var rng := RandomNumberGenerator.new()
	rng.seed = pet.personality_seed + int(from)
	var id: String = pet.life.quirks[rng.randi_range(0, pet.life.quirks.size() - 1)]
	var events: Array = []
	# A sleeping puppy's account must not describe an awake activity during a nap.
	if was_resting:
		events.append("Początek nieobecności upłynął na spokojnej drzemce w legowisku.")
	else:
		events.append(QUIRKS[id].away)
	events.append("Nowy zapach przy oknie przyciągnął ciekawski nos." if float(pet.traits.curiosity) >= 0.55 and not pet.resting and id != "window_watch" else "Miękki kocyk okazał się dobrym miejscem na spokojną chwilę.")
	if now - from >= 4 * 3600:
		events.append("Ciszę pokoju przerwało przeciągłe, zadowolone westchnienie.")
	pet.life.away_report = {"from": from, "until": now, "events": events}
	pet.add_journal_entry("away_%d" % int(now), "Kiedy Cię nie było", "\n".join(PackedStringArray(events)), now)
	return true

static func greeting(pet: PetState, away: float) -> Dictionary:
	if pet.resting:
		return {"text": "%s odpoczywa w legowisku. Możecie przywitać się po drzemce." % pet.pet_name, "clip": "sleep"}
	if away >= 3 * 86400:
		return {"text": "%s najpierw spokojnie Cię obwąchuje. Za chwilę znów znajdziecie wspólny rytm." % pet.pet_name, "clip": "head_tilt_stand"}
	if away >= 3600:
		return {"text": "%s macha ogonem na Twój widok. Jest czas na wspólną chwilę." % pet.pet_name, "clip": "tail_wag_stand"}
	return {"text": "%s podnosi głowę. O, znów jesteś blisko!" % pet.pet_name, "clip": "head_tilt_stand"}

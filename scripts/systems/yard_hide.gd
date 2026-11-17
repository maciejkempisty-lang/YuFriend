class_name YardHide
extends RefCounted

const ROUND_SECONDS := 120.0
var kind := ""
var phase := ""
var hiding_spot := -1
var search_order: Array[int] = []
var search_index := 0
var elapsed := 0.0
var remaining := 0.0
var checked: Array[int] = []

func active() -> bool:
	return not kind.is_empty()

func start(mode: String, seed_value: int = 0) -> bool:
	if mode not in ["treat", "dog"] or active(): return false
	var rng := RandomNumberGenerator.new()
	if seed_value == 0: rng.randomize()
	else: rng.seed = seed_value
	kind = mode
	phase = "choose" if mode == "treat" else "hiding"
	remaining = ROUND_SECONDS
	elapsed = 0
	checked.clear()
	search_order.assign([0, 1, 2])
	for i in range(2, 0, -1):
		var other := rng.randi_range(0, i)
		var previous := search_order[i]
		search_order[i] = search_order[other]
		search_order[other] = previous
	search_index = 0
	hiding_spot = -1 if mode == "treat" else rng.randi_range(0, 2)
	return true

func select(spot: int) -> String:
	if spot < 0 or spot > 2: return ""
	if phase == "choose":
		hiding_spot = spot
		phase = "walk"
		return "walk"
	if phase == "guess":
		if spot == hiding_spot:
			phase = "found"
			return "found"
		if not checked.has(spot): checked.append(spot)
		return "wrong"
	return ""

func search_spot() -> int:
	return search_order[search_index] if phase in ["walk", "sniff"] else -1

func arrive() -> bool:
	if phase != "walk": return false
	phase = "sniff"
	elapsed = 0
	return true

func advance(delta: float) -> String:
	if not active() or not is_finite(delta) or delta <= 0: return ""
	remaining -= delta
	if remaining <= 0: return "timeout"
	if phase not in ["hiding", "sniff"]: return ""
	elapsed += delta
	if phase == "hiding" and elapsed >= 1.2:
		phase = "guess"
		return "guess"
	if phase == "sniff" and elapsed >= 2:
		if search_spot() == hiding_spot:
			phase = "found"
			return "found"
		checked.append(search_spot())
		search_index += 1
		phase = "walk"
		return "walk"
	return ""

func reset() -> void:
	kind = ""
	phase = ""
	hiding_spot = -1
	search_order.clear()
	checked.clear()
	search_index = 0
	elapsed = 0
	remaining = 0

func hint() -> String:
	match phase:
		"choose": return "Smakołyk: wybierz krzak 1–3."
		"hiding": return "Piesek się chowa…"
		"guess": return "Szukaj ogona. Przesuwaj podwórko."
		"walk": return "Szukaj! Piesek podąża za zapachem."
		"sniff": return "Węszy przy krzaku %d…" % (search_spot() + 1)
	return ""

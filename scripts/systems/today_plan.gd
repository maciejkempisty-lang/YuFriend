class_name TodayPlan
extends RefCounted

# A read-only view over existing progress, never another daily checklist or save.
static func suggestions(pet: PetState, local_seconds: float) -> Array[Dictionary]:
	if DailyRhythm.phase(pet, local_seconds) == "night":
		return [
			{"id": "rest", "title": "Spokojny wieczór", "detail": "Pora odpocząć. Wspólne zabawy mogą poczekać.", "button": "Czas odpocząć"},
			{"id": "album", "title": "Wasze wspomnienia", "detail": "Możesz zajrzeć do Albumu, gdy piesek śpi.", "button": "Otwórz Album"},
		]
	var state := DailyAdventure.view(pet, local_seconds)
	var result: Array[Dictionary] = []
	for task in DailyAdventure.PLANS[int(state.day) % DailyAdventure.PLANS.size()]:
		result.append({"id": task, "title": {"garden": "Zajrzyjcie do ogródka", "trick": "Chwila ze sztuczką", "treasure": "Zapachy i skarby"}[task],
			"detail": "Miła chwila już za Wami. Powtórka? Tylko jeśli chcecie." if task in state.done else {"garden": "Posadź, podlej lub obejrzyj roślinę.", "trick": "Wybierz dowolną sztuczkę i nagródź pieska.", "treasure": "Powęszcie przy krzakach lub zajrzyjcie do piaskownicy."}[task],
			"button": "Do treningu" if task == "trick" else ("Do ogródka" if task == "garden" else "Poszukajmy")})
	result.append({"id": "together", "title": "Po prostu razem", "detail": "Pogłaszcz pieska lub popatrz, jak odpoczywa. Bez zadań.", "button": "Do pieska"})
	return result

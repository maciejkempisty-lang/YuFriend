class_name LevelActions
extends RefCounted
## The common gameplay dispatcher used by both scene shells and UI shortcuts.
## UI may supply gesture/round inputs; availability always comes from the project.
static func run(s: GameSession, script_id: String, input: Dictionary = {}) -> bool:
	var level := "yard" if s.in_yard else "home"
	if script_id == "bath": level = "home"
	var filter := {}
	if script_id == "water" and input.has("spot"): filter["spot"] = input.spot
	if script_id in ["touch_play", "skill_play"] and input.has("kind"): filter["kind"] = input.kind
	if not RoomLayoutLoader.allows(script_id, level, filter): return false
	var element := RoomLayoutLoader.element_for_script(script_id, level, filter)
	var params := LevelProject.default_params(script_id)
	params.merge(element.get("params", {}), true)
	params.merge(input, true)
	match script_id:
		"feed", "pet", "clean": return s.act(script_id)
		"rest": return s.yard_rest.start(s, "bed") if s.in_yard else s.act("rest")
		"ball":
			if params.has("target"): return s.throw_ball(params.target, params.get("origin", RoomLayout.STATIONS.ball.position))
			return s.act("play")
		"bath": return s.start_bath()
		"cuddle": return s.start_cuddle()
		"drink": return s.yard_rest.start(s, "drink") if s.in_yard else s.home_drink.start(s)
		"sniff": return s.start_sniff(int(params.get("spot", -1)))
		"course": return s.course.start(s)
		"timed_course": return s.timed_course.start(s)
		"water": return s.water.start(s, str(params.get("spot", "puddle")))
		"hide": return s.start_hide(str(params.get("kind", "treat")), int(params.get("seed", 0)))
		"visitor": return s.visitors.start(s, str(params.get("guest", "bird")))
		"training": return s.begin_training(str(params.get("trick", "sit")), bool(params.get("guided", true)), bool(params.get("marker", false)), bool(params.get("gentle", false)))
		"touch_play", "skill_play": return s.start_touch_game(str(params.get("kind", "tug")))
		"bubble_play": return s.start_touch_game("bubbles")
		"outdoor_commands":
			if s.outdoor_commands.phase == "praise": return s.outdoor_commands.praise(s)
			return s.outdoor_commands.start(s, bool(params.get("guided", true)))
		"potty": return YardRoutines.clean_up(s) if YardRoutines.has_mess(s) else YardRoutines.start_outing(s)
		"initiative": return s.offer_initiative(str(params.get("kind", "")))
		"dig": return DiggingSystem.start(s)
		"garden": return YardRoutines.garden(s, str(params.get("action", "observe")))
		"decor": return KeepsakeSystem.toggle_decor(s, str(params.get("key", "")))
		"yard_weather":
			var mode := str(params.get("mode", "auto"))
			if mode != "auto" and not YardWeather.LABELS.has(mode): return false
			s.weather.override_kind = "" if mode == "auto" else mode
			s.changed.emit()
			return true
	return false

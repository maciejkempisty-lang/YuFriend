class_name RoomLayoutLoader
extends RefCounted
## Validated scene data is authoritative for visible actions and station geometry.
## Missing files or textures leave the last complete project untouched. Reapplying
## a project resets station defaults before patching, so approach offsets never drift.

const DEFAULT_PATH := "res://level-editor/projects/ver1.json"

# Project data available to RoomView after apply() runs. RoomView reads these
# to swap the procedural RoomArtwork for the editor's sprite set.
static var active_project: Dictionary = {}
static var active_textures: Dictionary = {}
static var active_hd_asset_ids: Dictionary = {}
static var active_hd_art := false
static var _home_defaults: Dictionary = {}
static var _yard_defaults: Dictionary = {}

static func element_for_script(script_id: String, level_id: String = "", params: Dictionary = {}) -> Dictionary:
	for level in active_project.get("levels", []):
		if not level_id.is_empty() and level.id != level_id: continue
		for element in level.elements:
			if not element.get("visible", true) or element.get("script", "none") != script_id: continue
			var matches := true
			for key in params:
				var value: Variant = element.get("params", {}).get(key)
				if value != params[key] and value != "all": matches = false
			if matches: return element
	return {}

static func has_script(script_id: String, level_id: String = "", params: Dictionary = {}) -> bool:
	return not element_for_script(script_id, level_id, params).is_empty()

# Standalone subsystem tests and the legacy scene have no loaded project.
# A loaded project, including a level with zero elements, is authoritative.
static func allows(script_id: String, level_id: String = "", params: Dictionary = {}) -> bool:
	return active_project.is_empty() or has_script(script_id, level_id, params)

static func element_by_id(id: String, level_id: String) -> Dictionary:
	for level in active_project.get("levels", []):
		if level.id != level_id: continue
		for element in level.elements:
			if element.id == id and element.get("visible", true): return element
	return {}

static func walk_area(level_id: String) -> Rect2:
	for level in active_project.get("levels", []):
		if level.id == level_id:
			var w: Dictionary = level.walk
			return Rect2(w.x, w.y, w.width, w.height)
	return Rect2(95, 466, 1250, 42)

static func select_level(level_id: String) -> void:
	RoomLayout.WALK_AREA = walk_area(level_id)

static func clamp_to_level(point: Vector2, level_id: String) -> Vector2:
	var area := walk_area(level_id)
	return point.clamp(area.position, area.end)

static func play_script(kind: String) -> String:
	if kind == "ball": return "ball"
	if kind == "agility": return "timed_course"
	if kind == "bubbles": return "bubble_play"
	return "skill_play" if kind in SkillPlaySystem.EXTRA else "touch_play"

static func allows_play(kind: String, level_id: String) -> bool:
	var script := play_script(kind)
	return allows(script, level_id, {"kind": kind} if script in ["skill_play", "touch_play"] else {})

static func allows_action(action: String, level_id: String) -> bool:
	match action:
		"hungry": action = "feed"
		"play", "bored", "catch": action = "ball"
		"train": action = "training"
		"toys": return allows("touch_play", level_id) or allows("skill_play", level_id)
		"door", "yard_gate": return allows("portal", level_id)
		"window": return active_project.is_empty() or not element_by_id("window", level_id).is_empty()
		"yard_shade": action = "rest"
		"yard_course": action = "course"
		"yard_dig": action = "dig"
		"yard_garden": action = "garden"
		"yard_outing", "outing": action = "potty"
		"yard_fetch": action = "ball"
		"yard_puddle", "yard_sprinkler": return allows("water", level_id, {"spot": action.trim_prefix("yard_")})
	if action.begins_with("yard_bush_"): return allows("sniff", level_id) or allows("hide", level_id)
	return allows(action, level_id)


func apply(path: String = DEFAULT_PATH) -> Dictionary:
	if _home_defaults.is_empty():
		_home_defaults = RoomLayout.STATIONS.duplicate(true)
		_yard_defaults = RoomLayout.YARD_STATIONS.duplicate(true)
	var result := LevelProject.read_project(path)
	if not result.ok:
		return {"ok": false, "errors": result.errors}
	var project: Dictionary = result.project
	var assets_by_id := {}
	for a in project.assets: assets_by_id[a.id] = a
	# Load textures exactly as the editor saved them.
	var textures := {}
	var hd_ids := {}
	for a in project.assets:
		var tex: Texture2D = LevelProject.texture(a)
		if tex == null: return {"ok": false, "errors": ["Nie można wczytać grafiki: " + str(a.id)]}
		textures[a.id] = tex
		if str(a.source).ends_with("-hd.png"): hd_ids[a.id] = true
	RoomLayout.STATIONS = _home_defaults.duplicate(true)
	RoomLayout.YARD_STATIONS = _yard_defaults.duplicate(true)
	active_project = project
	active_textures = textures
	active_hd_asset_ids = hd_ids
	active_hd_art = not hd_ids.is_empty()
	var home: Variant = _find_level(project, "home")
	var yard: Variant = _find_level(project, "yard")
	if home != null: _patch(RoomLayout.STATIONS, home, assets_by_id, "position", "bounds", "stand")
	if yard != null:
		_patch(RoomLayout.YARD_STATIONS, yard, assets_by_id, "point", "bounds", "stand")
		# Course sub-points move with the course unless individually authored.
		var shift: Vector2 = RoomLayout.YARD_STATIONS.course.point - _yard_defaults.course.point
		for key in ["landing", "podium"]:
			if element_by_id(key, "yard").is_empty():
				RoomLayout.YARD_STATIONS[key].point = _yard_defaults[key].point + shift
				RoomLayout.YARD_STATIONS[key].stand = clamp_to_level(RoomLayout.YARD_STATIONS[key].point, "yard")
		if element_by_id("safe_spot", "yard").is_empty():
			var fence_shift: Vector2 = RoomLayout.YARD_STATIONS.fence.point - _yard_defaults.fence.point
			RoomLayout.YARD_STATIONS.safe_spot.point = _yard_defaults.safe_spot.point + fence_shift
			RoomLayout.YARD_STATIONS.safe_spot.stand = clamp_to_level(RoomLayout.YARD_STATIONS.safe_spot.point, "yard")
	select_level("home")
	return {"ok": true, "home_elements": (home as Dictionary).elements.size() if home != null else 0, "yard_elements": (yard as Dictionary).elements.size() if yard != null else 0}

func _find_level(project: Dictionary, id: String) -> Variant:
	for l in project.levels:
		if l.id == id: return l
	return null

func _patch(table: Dictionary, level: Dictionary, assets: Dictionary, position_key: String, bounds_key: String, stand_key: String) -> void:
	var exact_ids := {}
	for e in level.elements:
		if table.has(e.id) and e.visible: exact_ids[e.id] = true
	var aliases := {}
	for e in level.elements:
		if not e.visible: continue
		var sid: String = e.id
		if not table.has(sid):
			sid = _station_for_script(e, str(level.id))
			if not table.has(sid) or exact_ids.has(sid) or aliases.has(sid): continue
			aliases[sid] = true
		var entry: Dictionary = table[sid]
		var pos := Vector2(float(e.x), float(e.y))
		# Compute stand delta BEFORE overwriting so the approach point
		# keeps its historic offset relative to the station.
		var stand_delta := Vector2.ZERO
		if stand_key != "" and entry.has(stand_key):
			stand_delta = entry[stand_key] - entry.get(position_key, pos)
		entry[position_key] = pos
		if stand_key != "": entry[stand_key] = clamp_to_level(pos + stand_delta, str(level.id))
		if assets.has(e.asset):
			var world_rect: Rect2 = LevelProject.element_rect(e, assets[e.asset])
			if position_key == "position":
				entry[bounds_key] = Rect2(world_rect.position - pos, world_rect.size)
			else:
				entry[bounds_key] = world_rect
		if e.script == "feed":
			entry["effects"] = {"fullness": float(e.get("params", {}).get("fullness", 22))}
		elif e.script == "ball":
			var effects: Dictionary = entry.get("effects", {}).duplicate()
			effects["play"] = float(e.get("params", {}).get("play", 15))
			effects["contact"] = float(e.get("params", {}).get("contact", 5))
			entry["effects"] = effects

func _station_for_script(element: Dictionary, level_id: String) -> String:
	match str(element.get("script", "none")):
		"feed": return "food"
		"rest": return "bed"
		"ball": return "ball" if level_id == "home" else "fetch"
		"drink": return "drink"
		"course", "timed_course": return "course"
		"visitor": return "fence"
		"water": return str(element.get("params", {}).get("spot", "puddle"))
		"sniff": return "bush_%d" % maxi(0, int(element.get("params", {}).get("spot", 0)))
		"dig", "garden": return str(element.script)
		"potty": return "outing"
		"touch_play", "skill_play": return "toys"
		"portal":
			if level_id == "yard": return "gate"
			if str(element.get("params", {}).get("target", "")) == "yard": return "door"
	return ""

static func bush_spots() -> Array[int]:
	var result: Array[int] = []
	for index in 3:
		var element := element_by_id("bush_%d" % index, "yard")
		if active_project.is_empty() or element.get("script", "none") in ["sniff", "hide"] or has_script("sniff", "yard", {"spot": index}): result.append(index)
	return result

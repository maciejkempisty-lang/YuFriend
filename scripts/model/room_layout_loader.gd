class_name RoomLayoutLoader
extends RefCounted
## Bridge from a LevelProject (edited in level-editor/index.html, saved as
## level-editor/projects/*.json) to RoomLayout. For every editor element whose
## id matches a station id we copy its {x,y} and derived bounds into the
## corresponding STATIONS / YARD_STATIONS entry. The game's handcrafted UI,
## procedural RoomArtwork, session actions and animations stay as they are
## — only the where-things-sit comes from the editor.

const DEFAULT_PATH := "res://level-editor/projects/ver1.json"

# Project data available to RoomView after apply() runs. RoomView reads these
# to swap the procedural RoomArtwork for the editor's sprite set.
static var active_project: Dictionary = {}
static var active_textures: Dictionary = {}
static var active_hd_asset_ids: Dictionary = {}
static var active_hd_art := false

func apply(path: String = DEFAULT_PATH) -> Dictionary:
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
		if tex != null:
			textures[a.id] = tex
			if str(a.source).ends_with("-hd.png"): hd_ids[a.id] = true
	active_project = project
	active_textures = textures
	active_hd_asset_ids = hd_ids
	active_hd_art = not hd_ids.is_empty()
	var home: Variant = _find_level(project, "home")
	var yard: Variant = _find_level(project, "yard")
	if home != null: _patch(RoomLayout.STATIONS, home, assets_by_id, "position", "bounds", "stand")
	# Yard: only the hitbox (bounds) is editor-driven for now. The approach
	# point is a walk-area location, not the element's art position, so moving
	# the sprite without re-authoring the path semantics would break yard logic.
	if yard != null: _patch_bounds_only(RoomLayout.YARD_STATIONS, yard, assets_by_id)
	return {"ok": true, "home_elements": (home as Dictionary).elements.size() if home != null else 0, "yard_elements": (yard as Dictionary).elements.size() if yard != null else 0}

func _find_level(project: Dictionary, id: String) -> Variant:
	for l in project.levels:
		if l.id == id: return l
	return null

func _patch_bounds_only(table: Dictionary, level: Dictionary, assets: Dictionary) -> void:
	for e in level.elements:
		if not table.has(e.id): continue
		if not assets.has(e.asset): continue
		table[e.id]["bounds"] = LevelProject.element_rect(e, assets[e.asset])

func _patch(table: Dictionary, level: Dictionary, assets: Dictionary, position_key: String, bounds_key: String, stand_key: String) -> void:
	var exact_ids := {}
	for e in level.elements:
		if table.has(e.id): exact_ids[e.id] = true
	var aliases := {}
	for e in level.elements:
		var sid: String = e.id
		if not table.has(sid):
			sid = _station_for_script(e)
			if sid.is_empty() or exact_ids.has(sid) or aliases.has(sid): continue
			aliases[sid] = true
		var entry: Dictionary = table[sid]
		var pos := Vector2(float(e.x), float(e.y))
		# Compute stand delta BEFORE overwriting so the approach point
		# keeps its historic offset relative to the station.
		var stand_delta := Vector2.ZERO
		var had_stand := false
		if stand_key != "" and entry.has(stand_key):
			stand_delta = entry[stand_key] - entry.get(position_key, pos)
			had_stand = true
		entry[position_key] = pos
		if had_stand: entry[stand_key] = pos + stand_delta
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

func _station_for_script(element: Dictionary) -> String:
	match str(element.get("script", "none")):
		"feed": return "food"
		"rest": return "bed"
		"ball": return "ball"
		"portal":
			if str(element.get("params", {}).get("target", "")) == "yard": return "door"
	return ""

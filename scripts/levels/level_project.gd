class_name LevelProject
extends RefCounted
## Versioned, data-only contract shared with level-editor/model.mjs and scripts.json.
const FORMAT := "yufriend-levels"
const LAYERS := ["background", "middle", "foreground"]
const MAX_BYTES := 20 * 1024 * 1024
const REGISTRY_PATH := "res://level-editor/scripts.json"

static var _registry: Dictionary = {}

static func registry() -> Dictionary:
	if _registry.is_empty():
		var text := ""
		if FileAccess.file_exists(REGISTRY_PATH): text = FileAccess.get_file_as_string(REGISTRY_PATH)
		if text.is_empty(): return {"scripts": [], "clips": []}
		var data = JSON.parse_string(text)
		if typeof(data) != TYPE_DICTIONARY or not data.has("scripts"): return {"scripts": [], "clips": []}
		var by_id := {}
		for s in data.scripts: by_id[s.id] = s
		_registry = {"scripts": data.scripts, "by_id": by_id, "clips": data.get("clips", [])}
	return _registry

static func scripts() -> Dictionary: return registry().get("by_id", {})
static func clip_names() -> Array: return registry().get("clips", [])

static func read_project(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null: return {"ok": false, "errors": ["Nie można otworzyć projektu: " + path]}
	if file.get_length() > MAX_BYTES: return {"ok": false, "errors": ["Projekt przekracza 20 MB."]}
	var parser := JSON.new()
	if parser.parse(file.get_as_text()) != OK: return {"ok": false, "errors": ["Nieprawidłowy JSON: " + parser.get_error_message()]}
	var project = migrate(parser.data)
	var errors := validate(project)
	return {"ok": errors.is_empty(), "errors": errors, "project": project}

static func number(v: Variant, low: float, high: float) -> bool:
	return (v is float or v is int) and is_finite(float(v)) and float(v) >= low and float(v) <= high

static func text(v: Variant, limit: int = 100) -> bool:
	return v is String and v.length() <= limit

static func identifier(v: Variant) -> bool:
	if not text(v, 64) or v.is_empty(): return false
	var regex := RegEx.new()
	regex.compile("^[a-zA-Z][a-zA-Z0-9_-]*$")
	return regex.search(v) != null

static func source_allowed(value: Variant) -> bool:
	if not text(value, 4000000): return false
	var regex := RegEx.new()
	regex.compile("^res://(assets|level-editor/assets)/[a-zA-Z0-9_./-]+\\.png$")
	if regex.search(value) != null and not value.contains(".."): return true
	regex.compile("^data:image/png;base64,[A-Za-z0-9+/=]+$")
	return regex.search(value) != null

static func migrate(data: Variant) -> Variant:
	if typeof(data) != TYPE_DICTIONARY: return data
	var out: Dictionary = data.duplicate(true)
	if not out.get("levels") is Array: return out
	for l in out.levels:
		if typeof(l) != TYPE_DICTIONARY: continue
		if not l.has("walkSpeed"): l["walkSpeed"] = 70
		if not l.has("runSpeed"): l["runSpeed"] = 160
		if not l.get("elements") is Array: continue
		var migrated := []
		for e in l.elements:
			migrated.append(migrate_element(e))
		l.elements = migrated
	return out

static func migrate_element(e: Variant) -> Variant:
	if typeof(e) != TYPE_DICTIONARY: return e
	if e.has("script") and e.has("params") and not e.has("behavior"): return e
	var legacy: String = e.get("behavior", "none")
	var interactive: bool = e.get("interactive", false) == true
	var script_id := "none"
	var params := {}
	if not interactive or legacy == "none":
		script_id = "none"
	elif legacy == "script":
		script_id = "bark" if e.get("script", "") == "bark" else "greet"
		if script_id == "greet": params = {"text": e.get("text", "Cześć, przyjacielu!")}
		else: params = {"message": e.get("text", "Hau!"), "clip": "bark_stand"}
	elif legacy == "portal":
		script_id = "portal"; params = {"target": e.get("target", ""), "message": e.get("text", "")}
	elif legacy == "message":
		script_id = "message"; params = {"text": e.get("text", e.get("name", "")), "duration": 4}
	elif scripts().has(legacy):
		script_id = legacy
		params = default_params(legacy)
		if not e.get("text", "").is_empty(): params["message"] = e.text
	var out: Dictionary = e.duplicate()
	out.erase("behavior"); out.erase("target"); out.erase("text"); out.erase("interactive")
	out["script"] = script_id
	out["params"] = params
	return out

static func default_params(script_id: String) -> Dictionary:
	var def: Variant = scripts().get(script_id, {})
	var out := {}
	if typeof(def) != TYPE_DICTIONARY: return out
	var schema: Dictionary = def.get("params", {})
	for key in schema:
		var pdef: Dictionary = schema[key]
		if pdef.has("default"): out[key] = pdef.default
		elif pdef.get("type") == "number": out[key] = 0
		elif pdef.get("type") == "bool": out[key] = false
		else: out[key] = ""
	return out

static func is_interactive(e: Dictionary) -> bool: return e.get("script", "none") != "none"

static func param_ok(pdef: Dictionary, value: Variant, levels: Dictionary) -> bool:
	match pdef.get("type", "string"):
		"number": return (value is float or value is int) and is_finite(float(value)) and float(value) >= float(pdef.get("min", -1e18)) and float(value) <= float(pdef.get("max", 1e18))
		"bool": return typeof(value) == TYPE_BOOL
		"level": return value is String and levels.has(value)
		"clip": return value is String and value.length() > 0 and value.length() <= 64
		"string": return value is String and value.length() <= int(pdef.get("max", 200))
		"text": return value is String and value.length() <= int(pdef.get("max", 500))
	return true

static func validate(data: Variant) -> Array[String]:
	var errors: Array[String] = []
	if not data is Dictionary: return ["To nie jest projekt."]
	if data.get("format") != FORMAT or data.get("version") != 1: errors.append("Nieobsługiwana wersja projektu.")
	if not text(data.get("name")) or str(data.get("name", "")).strip_edges().is_empty(): errors.append("Brak nazwy projektu.")
	if not data.get("assets") is Array or not data.get("levels") is Array: return ["Brak biblioteki lub poziomów."]
	if data.assets.size() > 128 or data.levels.is_empty() or data.levels.size() > 64: return ["Przekroczony limit grafik lub poziomów."]
	var assets := {}
	var levels := {}
	for a in data.assets:
		if not a is Dictionary: errors.append("Nieprawidłowa grafika."); continue
		if not identifier(a.get("id")) or assets.has(a.get("id")): errors.append("Nieprawidłowe ID grafiki.")
		assets[a.get("id", "")] = a
		if not text(a.get("name")) or not number(a.get("width"), 1, 4096) or not number(a.get("height"), 1, 4096) or not source_allowed(a.get("source")): errors.append("Nieprawidłowe źródło lub rozmiar grafiki.")
	for l in data.levels:
		if not l is Dictionary: errors.append("Nieprawidłowy poziom."); continue
		if not identifier(l.get("id")) or levels.has(l.get("id")): errors.append("Nieprawidłowe ID poziomu.")
		levels[l.get("id", "")] = true
	if not levels.has(data.get("startLevel")): errors.append("Nie znaleziono poziomu startowego.")
	var script_defs: Dictionary = scripts()
	for l in data.levels:
		if not l is Dictionary: continue
		if not text(l.get("name")) or str(l.get("name", "")).strip_edges().is_empty(): errors.append("Brak nazwy poziomu.")
		if not number(l.get("width"), 240, 8192) or not number(l.get("height"), 120, 4096): errors.append("Nieprawidłowy rozmiar poziomu."); continue
		if not number(l.get("walkSpeed"), 1, 2000): errors.append("Nieprawidłowa prędkość chodu.")
		if not number(l.get("runSpeed"), 1, 4000): errors.append("Nieprawidłowa prędkość biegu.")
		var w: Variant = l.get("walk")
		var spawn: Variant = l.get("spawn")
		if not w is Dictionary or not spawn is Dictionary: errors.append("Brak pasa ruchu lub startu psa."); continue
		var walk_ok := number(w.get("x"), 0, l.width) and number(w.get("y"), 0, l.height) and number(w.get("width"), 1, l.width) and number(w.get("height"), 1, l.height)
		if walk_ok: walk_ok = w.x + w.width <= l.width and w.y + w.height <= l.height
		if not walk_ok: errors.append("Pas ruchu poza poziomem.")
		elif not number(spawn.get("x"), w.x, w.x + w.width) or not number(spawn.get("y"), w.y, w.y + w.height): errors.append("Start psa poza pasem ruchu.")
		if not l.get("elements") is Array or l.elements.size() > 500: errors.append("Nieprawidłowa lista elementów."); continue
		var ids := {}
		for e in l.elements:
			if not e is Dictionary: errors.append("Nieprawidłowy element."); continue
			if not identifier(e.get("id")) or ids.has(e.get("id")): errors.append("Nieprawidłowe ID elementu.")
			ids[e.get("id", "")] = true
			if not text(e.get("name")) or not assets.has(e.get("asset")) or not e.get("layer") in LAYERS: errors.append("Brak grafiki lub warstwy elementu."); continue
			if not number(e.get("x"), -8192, 16384) or not number(e.get("y"), -8192, 16384) or not number(e.get("width"), 1, 16384) or not number(e.get("height"), 1, 16384): errors.append("Nieprawidłowa geometria elementu.")
			var a: Dictionary = assets[e.asset]
			if not e.get("pivot") is Dictionary or not number(e.pivot.get("x"), 0, float(a.get("width", 0))) or not number(e.pivot.get("y"), 0, float(a.get("height", 0))): errors.append("Nieprawidłowa podstawa elementu.")
			for key in ["visible", "locked", "static"]:
				if not e.get(key) is bool: errors.append("Nieprawidłowe właściwości elementu.")
			var script_id: String = e.get("script", "")
			if not script_defs.has(script_id): errors.append("Nieznany skrypt: " + script_id); continue
			var def: Dictionary = script_defs[script_id]
			if def.has("static") and typeof(def.static) == TYPE_BOOL and e.get("static") != def.static:
				errors.append("Skrypt %s wymaga static=%s." % [script_id, str(def.static)])
			if not e.get("params") is Dictionary: errors.append("Element bez parametrów."); continue
			var schema: Dictionary = def.get("params", {})
			for key in schema:
				var pdef: Dictionary = schema[key]
				if not param_ok(pdef, e.params.get(key), levels):
					errors.append("%s: parametr %s (%s) jest nieprawidłowy." % [e.get("name", ""), key, pdef.get("type", "?")])
	return errors

static func texture(asset: Dictionary) -> Texture2D:
	if not source_allowed(asset.get("source")): return null
	var bytes: PackedByteArray
	if asset.source.begins_with("data:"):
		bytes = Marshalls.base64_to_raw(asset.source.trim_prefix("data:image/png;base64,"))
	else:
		bytes = FileAccess.get_file_as_bytes(asset.source)
	if bytes.size() < 24 or bytes.slice(0, 8) != PackedByteArray([137,80,78,71,13,10,26,10]): return null
	var width := (int(bytes[16]) << 24) | (int(bytes[17]) << 16) | (int(bytes[18]) << 8) | int(bytes[19])
	var height := (int(bytes[20]) << 24) | (int(bytes[21]) << 16) | (int(bytes[22]) << 8) | int(bytes[23])
	if width != asset.width or height != asset.height or width > 4096 or height > 4096: return null
	var image := Image.new()
	if image.load_png_from_buffer(bytes) != OK: return null
	return ImageTexture.create_from_image(image)

static func element_rect(e: Dictionary, a: Dictionary) -> Rect2:
	var size := Vector2(e.width, e.height)
	return Rect2(Vector2(e.x, e.y) - Vector2(e.pivot.x, e.pivot.y) * size / Vector2(a.width, a.height), size)

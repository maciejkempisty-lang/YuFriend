class_name KeepsakeSystem
extends RefCounted

const MAX_PHOTOS := 24
const DECOR := {"rug": "Dywan z łapką", "flower": "Słonecznik", "shelf": "Półka z trofeum"}

static func valid(data: Dictionary) -> bool:
	if not data.get("decor") is Array or data.decor.size() > 3: return false
	var seen := {}
	for key in data.decor:
		if not key is String or not DECOR.has(key) or seen.has(key): return false
		seen[key] = true
	if not data.get("photos") is Array or data.photos.size() > MAX_PHOTOS: return false
	seen.clear()
	for photo in data.photos:
		if not photo is Dictionary or not photo.get("id") is String: return false
		if not valid_id(photo.id) or seen.has(photo.id): return false
		if not PetState.valid_number(photo.get("at")) or photo.at < 0: return false
		if not photo.get("caption") is String or photo.caption.length() > 100: return false
		seen[photo.id] = true
	return true

static func valid_id(id: String) -> bool:
	if id.is_empty() or id.length() > 64: return false
	for character in id:
		if not "0123456789abcdef_".contains(character): return false
	return true

static func unlock_reason(pet: PetState, key: String) -> String:
	if key == "flower" and not (pet.milestones.has("yard_find_0") or pet.milestones.has("yard_find_1") or pet.milestones.has("yard_find_2")): return "Znajdź pierwszy skarb na podwórku."
	if key == "shelf":
		for skill in pet.skills.values():
			if float(skill.mastery) >= 100: return ""
		return "Opanuj dowolną sztuczkę na 100%."
	return ""

static func photo_path(save_path: String, id: String) -> String:
	return save_path.get_base_dir().path_join("photos").path_join(id + ".png") if valid_id(id) else ""

static func save_photo(session: GameSession, picture: Image, caption: String) -> bool:
	if not session.writable or session.suspended or picture == null or picture.is_empty(): return false
	if session.pet.photos.size() >= MAX_PHOTOS:
		session.say("Album jest pełny. Usuń wybrane zdjęcie z Albumu, aby dodać nowe.")
		return false
	var id := Crypto.new().generate_random_bytes(12).hex_encode()
	var path := photo_path(session.storage.path, id)
	if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir())) != OK or picture.save_png(path) != OK:
		session.say("Nie udało się zapisać zdjęcia. Spróbuj ponownie.")
		return false
	session.pet.photos.push_front({"id": id, "at": Time.get_unix_time_from_system(), "caption": caption.left(100)})
	if not session.flush():
		session.pet.photos.pop_front()
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
		session.changed.emit()
		return false
	session.say("Zdjęcie czeka w Albumie!")
	session.changed.emit()
	return true

static func toggle_decor(session: GameSession, key: String) -> bool:
	if not session.writable or session.suspended or not DECOR.has(key): return false
	if not unlock_reason(session.pet, key).is_empty(): return false
	var before := session.pet.decor.duplicate()
	if session.pet.decor.has(key): session.pet.decor.erase(key)
	else: session.pet.decor.append(key)
	if not session.flush():
		session.pet.decor = before
		session.changed.emit()
		return false
	session.changed.emit()
	return true

static func remove_photo(session: GameSession, id: String) -> bool:
	if not session.writable or session.suspended or not valid_id(id): return false
	var index := -1
	for i in session.pet.photos.size():
		if session.pet.photos[i].id == id: index = i
	if index < 0: return false
	var before := session.pet.photos.duplicate(true)
	session.pet.photos.remove_at(index)
	if not session.flush():
		session.pet.photos = before
		session.changed.emit()
		return false
	# Keep the PNG: versioned saves and .bak may still refer to it.
	# Removal frees an album slot, without invalidating recoverable older snapshots.
	session.say("Zdjęcie usunięte z Albumu. Możesz dodać nowe.")
	session.changed.emit()
	return true

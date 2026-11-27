class_name KeepsakeSystem
extends RefCounted

const MAX_PHOTOS := 24
const DECOR := {"heart": "Serce przyjaźni", "rug": "Dywan z łapką", "flower": "Słonecznik", "shelf": "Półka z trofeum", "cushion": "Poduszka przyjaźni", "flags": "Girlanda łapek", "daisy": "Wazon ze stokrotkami", "poppy": "Wazon z makami", "lavender": "Doniczka lawendy"}

static func valid(data: Dictionary) -> bool:
	if not data.get("decor") is Array or data.decor.size() > DECOR.size(): return false
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
	if key == "heart" and BondLevels.heart(pet) < 5: return "Więź: Nierozłączni ♥5."
	if YardRoutines.PLANTS.has(key) and not pet.yard_routines.flowers.has(key): return "Wyhoduj i zbierz: " + YardRoutines.PLANTS[key] + "."
	if key == "cushion" and pet.bond < 25: return "Więź 25: Zaufanie."
	if key == "flags" and pet.bond < 50: return "Więź 50: Przyjaźń."
	if key == "flower" and pet.yard_routines.flowers.is_empty() and not (pet.milestones.has("yard_find_0") or pet.milestones.has("yard_find_1") or pet.milestones.has("yard_find_2")): return "Znajdź pierwszy skarb na podwórku."
	if key == "shelf":
		for skill in pet.skills.values():
			if float(skill.mastery) >= 100: return ""
		return "Opanuj dowolną sztuczkę na 100%."
	return ""

static func photo_path(save_path: String, id: String) -> String:
	return save_path.get_base_dir().path_join("photos").path_join(id + ".png") if valid_id(id) else ""

static func save_photo(session: GameSession, picture: Image, caption: String, heart_frame: bool = false) -> bool:
	if not session.writable or session.suspended or picture == null or picture.is_empty(): return false
	if session.pet.photos.size() >= MAX_PHOTOS:
		session.say("Album jest pełny. Usuń wybrane zdjęcie z Albumu, aby dodać nowe.")
		return false
	if heart_frame:
		if BondLevels.heart(session.pet) < 4: return false
		picture = framed_photo(picture)
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
	if not RoomLayoutLoader.allows("decor", "yard" if session.in_yard else "home", {"key": key}): return false
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

static func framed_photo(source: Image) -> Image:
	var picture := source.duplicate() as Image
	var border := maxi(2, mini(picture.get_width(), picture.get_height()) / 40)
	var size := picture.get_size()
	var cream := Color("f6e6c8")
	picture.fill_rect(Rect2i(0, 0, size.x, border), cream)
	picture.fill_rect(Rect2i(0, size.y - border, size.x, border), cream)
	picture.fill_rect(Rect2i(0, 0, border, size.y), cream)
	picture.fill_rect(Rect2i(size.x - border, 0, border, size.y), cream)
	var unit := maxi(1, border / 4)
	for center in [Vector2i(border, border), Vector2i(size.x - border - 7 * unit, size.y - border - 6 * unit)]:
		var rows := ["0110110", "1111111", "1111111", "0111110", "0011100", "0001000"]
		for y in rows.size():
			for x in rows[y].length():
				if rows[y][x] == "1": picture.fill_rect(Rect2i(center + Vector2i(x, y) * unit, Vector2i.ONE * unit), Color("c87879"))
	return picture

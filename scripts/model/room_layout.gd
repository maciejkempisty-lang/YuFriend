class_name RoomLayout
extends RefCounted

# World units never depend on viewport size. The side sprite uses only shallow depth.
const PIXEL_SIZE := 3.0 # One logical art pixel in legacy world coordinates.
const SIZE := Vector2(1440, 540)
const FLOOR_Y := 440.0
static var WALK_AREA := Rect2(95, 466, 1250, 42)
const PUPPY_SCALE := 0.64
const START := Vector2(670, 502)
# STATIONS and YARD_STATIONS are mutable so a LevelProject can override
# positions/bounds at startup without touching the handcrafted UI chrome.
# RoomLayoutLoader.apply() patches the entries whose ids match editor elements.
static var YARD_STATIONS := {
	"bed": {"label": "Legowisko", "icon": "moon", "point": Vector2(220, 495), "stand": Vector2(220, 495), "bounds": Rect2(165, 480, 111, 24)},
	"drink": {"label": "Woda", "icon": "water", "point": Vector2(330, 505), "stand": Vector2(276, 499), "bounds": Rect2(306, 490, 48, 24)},
	"landing": {"label": "Lądowanie", "icon": "paw", "point": Vector2(1160, 495), "stand": Vector2(1160, 495), "bounds": Rect2(1130, 480, 60, 24)},
	"podium": {"label": "Podest", "icon": "paw", "point": Vector2(1270, 486), "stand": Vector2(1270, 486), "bounds": Rect2(1231, 480, 78, 24)},
	"fence": {"label": "Gość", "icon": "paw", "point": Vector2(1010, 385), "stand": Vector2(980, 490), "bounds": Rect2(975, 290, 80, 95)},
	"safe_spot": {"label": "Spokojne miejsce", "icon": "paw", "point": Vector2(810, 490), "stand": Vector2(810, 490), "bounds": Rect2(780, 475, 60, 24)},
	"shade": {"label": "Cień", "icon": "moon", "point": Vector2(240, 495), "bounds": Rect2(195, 365, 110, 115)},
	"course": {"label": "Tor", "icon": "paw", "point": Vector2(1010, 495), "bounds": Rect2(976, 410, 60, 66)},
	"puddle": {"label": "Kałuża", "icon": "water", "point": Vector2(420, 495), "bounds": Rect2(357, 478, 126, 40)},
	"sprinkler": {"label": "Zraszacz", "icon": "sprinkler", "point": Vector2(1230, 495), "bounds": Rect2(1228, 476, 84, 32)},
	"gate": {"label": "Do domu", "icon": "home", "point": Vector2(150, 495), "bounds": Rect2(105, 365, 90, 95)},
	"bush_0": {"label": "Krzak 1", "icon": "search", "point": Vector2(350, 495), "bounds": Rect2(278, 385, 144, 92)},
	"bush_1": {"label": "Krzak 2", "icon": "search", "point": Vector2(750, 495), "bounds": Rect2(678, 385, 144, 92)},
	"fetch": {"label": "Aport", "icon": "ball", "point": Vector2(940, 495), "bounds": Rect2(832, 448, 36, 46)},
	"dig": {"label": "Kopanie", "icon": "search", "point": Vector2(650, 495), "bounds": Rect2(625, 458, 90, 48)},
	"garden": {"label": "Ogródek", "icon": "flower", "point": Vector2(550, 495), "bounds": Rect2(485, 442, 138, 63)},
	"outing": {"label": "Na potrzebę", "icon": "paw", "point": Vector2(1300, 495), "bounds": Rect2(1272, 438, 45, 42)},
	"bush_2": {"label": "Krzak 3", "icon": "search", "point": Vector2(1150, 495), "bounds": Rect2(1078, 385, 144, 92)}
}
static var STATIONS := {
	"drink": {"label": "Woda", "action": "drink", "position": Vector2(536, 483), "stand": Vector2(588, 499), "bounds": Rect2(-24, -15, 48, 24), "clip": "eat_loop", "need": "contact", "effects": {}, "facing_left": true},
	"bed": {"label": "Legowisko", "action": "rest", "position": Vector2(205, 502), "stand": Vector2(205, 486), "bounds": Rect2(-88, -52, 176, 68), "clip": "sleep", "need": "energy", "effects": {}, "facing_left": false},
	"food": {"label": "Miska", "action": "feed", "position": Vector2(485, 505), "stand": Vector2(431, 499), "bounds": Rect2(-28, -28, 56, 28), "clip": "eat_loop", "need": "fullness", "effects": {"fullness": 22}, "facing_left": false},
	"ball": {"label": "Piłka", "action": "play", "position": Vector2(890, 497), "stand": Vector2(845, 507), "bounds": Rect2(-14, -14, 28, 28), "clip": "play_bow", "need": "play", "effects": {"play": 24, "contact": 8, "energy": -5, "hygiene": -3}, "facing_left": false},
	"toys": {"label": "Kosz z zabawkami", "action": "toys", "position": Vector2(1090, 496), "stand": Vector2(1020, 488), "bounds": Rect2(-48, -72, 96, 72), "clip": "play_bow", "need": "play", "effects": {"play": 6, "contact": 2}, "facing_left": false},
	"window": {"label": "Okno", "action": "window", "position": Vector2(740, 440), "stand": Vector2(738, 471), "bounds": Rect2(-78, -190, 156, 168), "clip": "head_tilt_stand", "need": "play", "effects": {"play": 3}, "facing_left": false},
	"door": {"label": "Drzwi", "action": "door", "position": Vector2(1300, 440), "stand": Vector2(1230, 480), "bounds": Rect2(-60, -186, 120, 186), "clip": "bark_stand", "need": "contact", "effects": {"contact": 3}, "facing_left": false}
}

static func station_id(action: String) -> String:
	match action:
		"rest": return "bed"
		"feed", "hungry": return "food"
		"play", "bored": return "ball"
	return action if STATIONS.has(action) else ""

static func station(action: String) -> Dictionary:
	return STATIONS.get(station_id(action), {})

static func clamp_walk(point: Vector2) -> Vector2:
	return Vector2(clampf(point.x, WALK_AREA.position.x, WALK_AREA.end.x), clampf(point.y, WALK_AREA.position.y, WALK_AREA.end.y))

static func random_walk_point() -> Vector2:
	return Vector2(randf_range(WALK_AREA.position.x, WALK_AREA.end.x), randf_range(WALK_AREA.position.y, WALK_AREA.end.y))

static func come_target(from: Vector2) -> Vector2:
	return clamp_walk(from + Vector2(150 if from.x < SIZE.x * 0.5 else -150, 10))

static func yard_point(key: String) -> Vector2:
	return YARD_STATIONS[key].point

static func yard_stand(key: String) -> Vector2:
	return RoomLayoutLoader.clamp_to_level(YARD_STATIONS[key].get("stand", YARD_STATIONS[key].point), "yard")

class_name RoomLayout
extends RefCounted

# World units never depend on viewport size. The side sprite uses only shallow depth.
const PIXEL_SIZE := 3.0 # One logical art pixel in legacy world coordinates.
const SIZE := Vector2(1440, 360)
const FLOOR_Y := 260.0
const WALK_AREA := Rect2(95, 286, 1250, 42)
const PUPPY_SCALE := 0.64
const START := Vector2(670, 322)
const YARD_STATIONS := {
	"shade": {"label": "Cień", "icon": "moon", "point": Vector2(240, 205), "bounds": Rect2(195, 185, 110, 115)},
	"course": {"label": "Tor", "icon": "paw", "point": Vector2(1010, 205), "bounds": Rect2(976, 230, 60, 66)},
	"puddle": {"label": "Kałuża", "icon": "water", "point": Vector2(420, 205), "bounds": Rect2(357, 298, 126, 40)},
	"sprinkler": {"label": "Zraszacz", "icon": "sprinkler", "point": Vector2(1230, 205), "bounds": Rect2(1228, 296, 84, 32)},
	"gate": {"label": "Do domu", "icon": "home", "point": Vector2(150, 205), "bounds": Rect2(105, 185, 90, 95)},
	"bush_0": {"label": "Krzak 1", "icon": "search", "point": Vector2(350, 205), "bounds": Rect2(278, 205, 144, 92)},
	"bush_1": {"label": "Krzak 2", "icon": "search", "point": Vector2(750, 205), "bounds": Rect2(678, 205, 144, 92)},
	"fetch": {"label": "Aport", "icon": "ball", "point": Vector2(940, 205), "bounds": Rect2(832, 268, 36, 46)},
	"dig": {"label": "Kopanie", "icon": "search", "point": Vector2(650, 205), "bounds": Rect2(625, 278, 90, 48)},
	"garden": {"label": "Ogródek", "icon": "flower", "point": Vector2(550, 205), "bounds": Rect2(485, 262, 138, 63)},
	"outing": {"label": "Na potrzebę", "icon": "paw", "point": Vector2(1300, 205), "bounds": Rect2(1272, 258, 45, 42)},
	"bush_2": {"label": "Krzak 3", "icon": "search", "point": Vector2(1150, 205), "bounds": Rect2(1078, 205, 144, 92)}
}
const STATIONS := {
	"bed": {"label": "Legowisko", "action": "rest", "position": Vector2(205, 322), "stand": Vector2(205, 306), "bounds": Rect2(-88, -52, 176, 68), "clip": "sleep", "need": "energy", "effects": {}, "facing_left": false},
	"food": {"label": "Miska", "action": "feed", "position": Vector2(485, 325), "stand": Vector2(431, 319), "bounds": Rect2(-28, -28, 56, 28), "clip": "eat_loop", "need": "fullness", "effects": {"fullness": 22}, "facing_left": false},
	"ball": {"label": "Piłka", "action": "play", "position": Vector2(890, 317), "stand": Vector2(845, 327), "bounds": Rect2(-14, -14, 28, 28), "clip": "play_bow", "need": "play", "effects": {"play": 24, "contact": 8, "energy": -5, "hygiene": -3}, "facing_left": false},
	"toys": {"label": "Kosz z zabawkami", "action": "toys", "position": Vector2(1090, 316), "stand": Vector2(1020, 308), "bounds": Rect2(-48, -72, 96, 72), "clip": "play_bow", "need": "play", "effects": {"play": 6, "contact": 2}, "facing_left": false},
	"window": {"label": "Okno", "action": "window", "position": Vector2(740, 260), "stand": Vector2(738, 291), "bounds": Rect2(-78, -190, 156, 168), "clip": "head_tilt_stand", "need": "play", "effects": {"play": 3}, "facing_left": false},
	"door": {"label": "Drzwi", "action": "door", "position": Vector2(1300, 260), "stand": Vector2(1230, 300), "bounds": Rect2(-60, -186, 120, 186), "clip": "bark_stand", "need": "contact", "effects": {"contact": 3}, "facing_left": false}
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

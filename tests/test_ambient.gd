extends SceneTree
var passed := 0
var failed := 0
const ALL: Array[String] = ["butterfly", "sparrow", "snail", "squirrel", "window_bird"]
func check(ok: bool, label: String) -> void:
	if ok: passed += 1
	else:
		failed += 1
		push_error(label)
func setup(place: String = "yard", plant: bool = true) -> AmbientLife:
	var life := AmbientLife.new(42)
	life.configure(place, true, true, plant, 270, Vector2(300, 320), ALL)
	return life
func _initialize() -> void:
	var life := setup()
	check(life.start("butterfly") and life.start("sparrow"), "two yard animals can share the scene")
	check(not life.start("window_bird") and not life.start("unknown") and not life.start("sparrow"), "no duplicates, wrong location or unknown species")
	var initial: Vector2 = life.actors.butterfly.position
	life.advance(1)
	check(life.actors.butterfly.position != initial, "butterfly travels instead of staying pinned")
	life.advance(7.1)
	check(life.actors.butterfly.position.is_equal_approx(Vector2(553, 270)), "butterfly lands at the growing plant height")
	check(life.actors.butterfly.frame == 1 and life.actors.sparrow.position.y == 338, "perching wings and grounded sparrow")
	life.configure("yard", true, false, true, 270, Vector2(300, 320), ALL)
	check(life.actors.values().all(func(a): return a.leaving), "player activity sends both animals away immediately")
	life.advance(0.8)
	check(life.actors.is_empty(), "departure finishes promptly without waiting for the game")
	var waits := life.waits.duplicate()
	life.advance(1000)
	check(life.actors.is_empty() and life.waits == waits, "no spawns or countdown while player is busy")
	life = setup("yard", false)
	life.start("butterfly")
	life.advance(8)
	initial = life.actors.butterfly.position
	life.advance(1)
	check(life.actors.butterfly.position != initial, "empty bed gets a flyby, not landing on imaginary flowers")
	life = setup()
	life.start("sparrow")
	life.advance(4)
	check(life.actors.sparrow.position == Vector2(865, 338), "sparrow lands and hops along the grass")
	life.configure("yard", true, true, true, 270, Vector2(860, 325), ALL)
	check(life.actors.sparrow.leaving, "nearby dog makes sparrow fly away")
	life.advance(0.8)
	check(life.actors.is_empty() and not life.start("sparrow"), "sparrow never spawns under the dog")
	life = setup("room")
	check(life.start("window_bird") and not life.start("butterfly"), "only window bird appears indoors")
	life.advance(2)
	check(life.actors.window_bird.position == Vector2(771, 213), "window bird lands inside its pane")
	life.configure("yard", true, true, true, 270, Vector2.ZERO, ALL)
	check(life.actors.is_empty(), "scene change clears old characters")
	waits = life.waits.duplicate()
	life.configure("yard", false, true, true, 270, Vector2.ZERO, ALL)
	life.advance(3600)
	check(life.waits == waits and life.actors.is_empty(), "hidden scene never advances time")
	life = setup()
	life.start("butterfly")
	life.configure("yard", false, true, true, 270, Vector2.ZERO, ALL)
	life.configure("yard", true, true, true, 270, Vector2.ZERO, ALL)
	check(life.waits.butterfly >= 40 and life.actors.is_empty(), "closing a panel does not immediately repeat an interrupted flyby")
	life = setup()
	life.configure("yard", true, true, true, 270, Vector2.ZERO, [])
	life.advance(100)
	check(life.actors.is_empty(), "off-camera animals do not start invisible events")
	life = setup()
	for i in 1000:
		life.advance(0.5)
		if life.actors.size() > 2: check(false, "population exceeded two"); break
	check(life.actors.size() <= 2, "bounded population throughout a long visit")
	var state := life.actors.duplicate(true)
	life.advance(NAN)
	life.advance(-1)
	check(life.actors == state, "invalid time cannot corrupt trajectories")
	life = setup()
	check(life.start("snail") and life.start("squirrel"), "both new background species can appear")
	check(not life.start("butterfly") and not life.start("sparrow"), "four species still share a two-animal cap")
	initial = life.actors.snail.position
	life.advance(4)
	check(life.actors.snail.position.x > initial.x and life.actors.snail.position.x - initial.x < 15 and life.actors.snail.position.y == initial.y, "snail crawls slowly along the grass edge")
	check(life.actors.squirrel.position == Vector2(585, 252) and life.actors.squirrel.frame == 2, "squirrel pauses with feet on the visible fence rail")
	life.advance(2)
	check(life.actors.squirrel.position.x > 585, "squirrel resumes its crossing after the pause")
	initial = life.actors.snail.position
	var squirrel_before: Vector2 = life.actors.squirrel.position
	life.configure("yard", true, false, true, 270, Vector2(300, 320), ALL)
	life.advance(0.4)
	check(life.actors.snail.position == initial and life.actors.snail.frame == 2 and life.actors.snail.opacity < 1, "snail withdraws in place on player activity")
	check(life.actors.squirrel.position.x > squirrel_before.x and absf(life.actors.squirrel.position.y - squirrel_before.y) <= 6, "squirrel escapes along the fence rather than flying")
	life.advance(0.41)
	check(life.actors.is_empty(), "ground animals also give way in under a second")
	life = setup()
	life.start("snail")
	life.advance(0.1)
	var opacity: float = life.actors.snail.opacity
	life.configure("yard", true, false, true, 270, Vector2.ZERO, ALL)
	life.advance(0.1)
	check(life.actors.snail.opacity < opacity, "early cancellation never flashes a fading-in animal")
	life = setup()
	var seen: Dictionary = {}
	for i in 1200:
		life.advance(0.5)
		for kind in life.actors: seen[kind] = true
	check(["butterfly", "sparrow", "snail", "squirrel"].all(func(kind): return seen.has(kind)), "automatic scheduling eventually shows all four yard species")
	life.configure("room", true, true, false, 270, Vector2.ZERO, ALL)
	check(not life.start("snail") and not life.start("squirrel"), "ground animals never enter the room")
	for rows in AmbientSpriteArt.BIRD + AmbientSpriteArt.BUTTERFLY + AmbientSpriteArt.SNAIL + AmbientSpriteArt.SQUIRREL:
		check(rows.size() == 16 and rows.all(func(row): return row.length() == 16), "sprite frame is a complete 16x16 grid")
	print("AMBIENT RESULTS: %d passed, %d failed" % [passed, failed])
	quit(1 if failed else 0)

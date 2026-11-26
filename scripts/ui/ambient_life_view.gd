class_name AmbientLifeView
extends Node2D

var life := AmbientLife.new()
var sprites: Dictionary = {}
var bird_frames: Array[Texture2D] = []
var butterfly_frames: Array[Texture2D] = []
var snail_frames: Array[Texture2D] = []
var squirrel_frames: Array[Texture2D] = []
var pane := Control.new()

func _ready() -> void:
	# Share each outdoor animal's foot position with the middle-ground sort.
	y_sort_enabled = true
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	bird_frames = AmbientSpriteArt.frames(false)
	butterfly_frames = AmbientSpriteArt.frames(true)
	snail_frames = AmbientSpriteArt.make_frames(AmbientSpriteArt.SNAIL)
	squirrel_frames = AmbientSpriteArt.make_frames(AmbientSpriteArt.SQUIRREL)
	# The bird is outside the lower-right pane, never over the frame or curtains.
	pane.position = Vector2(744, 168)
	pane.size = Vector2(54, 51)
	pane.clip_contents = true
	pane.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(pane)
	for kind in AmbientLife.KINDS:
		var sprite := Sprite2D.new()
		sprite.centered = false
		sprite.offset = Vector2(-8, -16 if kind == "snail" else (-15 if kind == "squirrel" else -14))
		sprite.scale = Vector2.ONE * RoomLayout.PIXEL_SIZE
		(pane if kind == "window_bird" else self).add_child(sprite)
		sprites[kind] = sprite
		sprite.hide()
	hide()
	set_process(false)

func sync(room: RoomView, session: GameSession, watching: bool) -> void:
	var active := watching and not session.suspended and not session.portal_active and not session.in_bath and not session.visitors.active() and DailyRhythm.phase(session.pet, session._local_now()) != "night"
	# Ordinary strolling and looking around are not a reason for the whole
	# garden to vanish. Fetch, training and other busy actions still take priority.
	var calm := not session.busy() and session.activity in ["idle", "sleep", "walk", "pet", "habit", "need", "initiative", "behavior"] and not room._drag_ball
	var visible_kinds: Array[String] = []
	for kind in AmbientLife.KINDS:
		if session.in_yard != (kind != "window_bird"): continue
		var point := room.world_to_screen(AmbientLife.ANCHORS[kind])
		if room.render_rect.has_point(point) and point.y > room.hud_bottom and point.y < room.content_bottom:
			visible_kinds.append(kind)
	var garden := room.backdrop.garden_state if not room.backdrop.garden_state.is_empty() else session.pet.yard_routines
	var flower_y := 300 - (9 + 36 * float(garden.growth) / YardRoutines.GROW_TIME)
	if session.in_yard and session.weather.kind(session) == "rain": visible_kinds.clear()
	life.configure("yard" if session.in_yard else "room", active, calm, garden.plant != "", flower_y, room.pet_world, visible_kinds)
	visible = active and not visible_kinds.is_empty()
	set_process(visible and (calm or not life.actors.is_empty()))
	_present()

func _process(delta: float) -> void:
	life.advance(delta)
	_present()
	if not life.calm and life.actors.is_empty(): set_process(false)

func _present() -> void:
	for kind in sprites:
		var sprite: Sprite2D = sprites[kind]
		sprite.visible = life.actors.has(kind)
		if not sprite.visible: continue
		var actor: Dictionary = life.actors[kind]
		var frames: Array[Texture2D] = bird_frames
		match kind:
			"butterfly": frames = butterfly_frames
			"snail": frames = snail_frames
			"squirrel": frames = squirrel_frames
		sprite.texture = frames[int(actor.frame)]
		sprite.modulate.a = float(actor.opacity)
		var point: Vector2 = (actor.position / RoomLayout.PIXEL_SIZE).round() * RoomLayout.PIXEL_SIZE
		sprite.position = point - pane.position if kind == "window_bird" else point
		sprite.flip_h = kind == "sparrow" and actor.age > 5.5 and not actor.leaving

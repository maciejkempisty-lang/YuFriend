class_name YardFetch
extends RefCounted

const MAX_DISTANCE := 600.0
const CATCH_SECONDS := 0.85
const PLAY_SECONDS := 2.044
var origin := Vector2.ZERO
var distance := 0.0
var remaining := 0.0
var active := false
var catching := false
var precise := false
var play_remaining := 0.0
var returning := false

static func target(origin: Vector2, drag: Vector2) -> Vector2:
	# Fixed world scale: zooming does not change the strength of the same gesture.
	return RoomLayout.clamp_walk(origin + (drag * 3.0).limit_length(MAX_DISTANCE))

func start(from: Vector2, destination: Vector2) -> void:
	reset()
	active = true
	origin = from
	distance = from.distance_to(destination) / 100.0

func arrive() -> void:
	if not active or catching: return
	catching = true
	remaining = CATCH_SECONDS
	play_remaining = PLAY_SECONDS

func tap() -> bool:
	if not active or not catching or remaining <= 0 or precise: return false
	precise = true
	return true

func advance(delta: float) -> bool:
	if not active or not catching or returning: return false
	remaining = maxf(0, remaining - delta)
	play_remaining = maxf(0, play_remaining - delta)
	if play_remaining > 0: return false
	returning = true
	catching = false
	return true

func reset() -> void:
	active = false
	catching = false
	precise = false
	distance = 0
	remaining = 0
	play_remaining = 0
	returning = false

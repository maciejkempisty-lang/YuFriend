class_name BallMotion
extends RefCounted

const GRAVITY := 520.0
const RESTITUTION := 0.55
const BOUNCES := 3
var origin := Vector2.ZERO
var target := Vector2.ZERO
var elapsed := 0.0
var first_flight := 0.5
var duration := 0.0
var running := false
var drop_height := 0.0

func start(from: Vector2, to: Vector2) -> void:
	origin = from
	target = to
	elapsed = 0
	drop_height = 0
	first_flight = clampf(from.distance_to(to) / 350.0, 0.3, 1.0)
	duration = 0
	for index in BOUNCES + 1: duration += first_flight * pow(RESTITUTION, index)
	running = true

func advance(delta: float) -> Dictionary:
	if running and is_finite(delta) and delta > 0:
		elapsed = minf(duration, elapsed + delta)
		running = elapsed < duration
	return sample()

func sample() -> Dictionary:
	if duration <= 0: return {"point": target, "lift": 0.0, "bounce": BOUNCES}
	var t := clampf(elapsed / duration, 0, 1)
	# Ground friction gradually removes horizontal speed; endpoint stays fixed.
	var progress := (1.0 - exp(-3.0 * t)) / (1.0 - exp(-3.0))
	var remaining := elapsed
	var lift := 0.0
	var bounce := 0
	for index in BOUNCES + 1:
		var leg := first_flight * pow(RESTITUTION, index) * (2.0 if drop_height > 0 and index > 0 else 1.0)
		if remaining <= leg:
			lift = maxf(0, drop_height - 0.5 * GRAVITY * remaining * remaining) if drop_height > 0 and index == 0 else maxf(0, GRAVITY * 0.5 * remaining * (leg - remaining))
			bounce = index
			break
		remaining -= leg
	return {"point": origin.lerp(target, progress), "lift": lift if running else 0.0, "bounce": bounce}

func cancel() -> void:
	running = false
	duration = 0

func drop(from: Vector2, to: Vector2, height: float) -> void:
	start(from, to)
	drop_height = clampf(height, 1, 180)
	first_flight = sqrt(2 * drop_height / GRAVITY)
	duration = first_flight
	for index in range(1, BOUNCES + 1): duration += 2 * first_flight * pow(RESTITUTION, index)

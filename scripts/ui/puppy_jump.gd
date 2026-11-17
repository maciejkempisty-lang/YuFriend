class_name PuppyJump
extends RefCounted

# Authored motion: anticipation, flight, landing. Reuses Gloria's exact artwork.
const DURATION := 1.4
var elapsed := -1.0
var origin := Vector2.ZERO
var target := Vector2.ZERO
func active() -> bool: return elapsed >= 0
func start(from: Vector2, to: Vector2) -> void:
	origin = from
	target = to
	elapsed = 0
func sample() -> Dictionary:
	var t := clampf((elapsed - 0.25) / 0.9, 0, 1)
	return {"point": origin.lerp(target, t), "lift": sin(t * PI) * 60,
		"clip": "play_bow" if elapsed < 0.25 or elapsed >= 1.15 else "run"}
func advance(delta: float) -> bool:
	if not active(): return false
	elapsed = minf(DURATION, elapsed + maxf(0, delta))
	return elapsed >= DURATION
func cancel() -> void: elapsed = -1

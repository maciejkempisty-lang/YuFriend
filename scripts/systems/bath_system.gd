class_name BathSystem
extends RefCounted

const LABELS := ["1. Namydl", "2. Spłucz", "3. Wytrzyj"]
var stage := 0
var coverage := [0.0, 0.0, 0.0]
var pointer := -2
var previous := Vector2.ZERO
var settled := false
var active := false

func start() -> void:
	stage = 0
	coverage = [0.0, 0.0, 0.0]
	pointer = -2
	settled = false
	active = true

func press(point: Vector2, id: int) -> void:
	if not active or stage >= 3 or pointer != -2: return
	pointer = id
	previous = point

func move(point: Vector2, id: int, zone: int) -> void:
	if not active or stage >= 3 or id != pointer: return
	var distance := point.distance_to(previous)
	previous = point
	# Long jumps and stationary holds do not wash an area.
	if zone < 0 or zone > 2 or distance < 3 or distance > 70: return
	coverage[zone] = minf(60, coverage[zone] + minf(distance, 16))

func release(id: int, canceled: bool = false) -> bool:
	if pointer != id: return false
	pointer = -2
	if canceled or not active or stage >= 3: return false
	if coverage.min() < 60: return false
	stage += 1
	coverage = [0.0, 0.0, 0.0]
	return true

func cancel() -> void:
	active = false
	pointer = -2

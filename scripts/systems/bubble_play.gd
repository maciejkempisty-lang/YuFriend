class_name BubblePlay
extends RefCounted

const WORLD := Vector2(640, 400)
const STEP := 1.0 / 120.0
var items: Array[Dictionary] = []
var pops: Array[Dictionary] = []
var elapsed := 0.0
var remainder := 0.0
var score := 0
var launched := 0
var wind := 0.0
var dog_x := 320.0
var facing := 1.0
var jump_left := 0.0
var cooldown := 0.0
var moving := false
var holding := false
var hold_time := 0.0
var hold_point := Vector2.ZERO
var pointer := Vector2.ZERO
var finished := false

func start(breeze: float) -> void:
	items.clear()
	pops.clear()
	elapsed = 0
	remainder = 0
	score = 0
	launched = 0
	wind = clampf(breeze, -1, 1)
	dog_x = 320
	facing = 1
	jump_left = 0
	cooldown = 0
	moving = false
	holding = false
	hold_time = 0
	finished = false

func press(point: Vector2) -> void:
	if finished or holding or launched >= 10 or items.size() >= 3 or not point.is_finite(): return
	holding = true
	hold_time = 0
	hold_point = (point * WORLD).clamp(Vector2(40, 145), Vector2(600, 330))
	pointer = point * WORLD

func move(point: Vector2) -> void:
	if holding and point.is_finite(): pointer = point * WORLD

func radius() -> float: return lerpf(28, 64, clampf((hold_time - 0.2) / 1.0, 0, 1))
func release(point: Vector2, cancelled := false) -> void:
	if not holding: return
	holding = false
	if cancelled or finished or not point.is_finite() or hold_time < 0.2 or items.size() >= 3: return
	var r := radius()
	var drag := (point * WORLD - hold_point).limit_length(180)
	launched += 1
	items.append({"point": hold_point, "radius": r, "velocity": Vector2(drag.x * 0.45 + wind * 16, -lerpf(65, 28, (r - 28) / 36) + minf(0, drag.y) * 0.12), "gold": launched % 5 == 0, "age": 0.0})

func mouth() -> Vector2:
	var lift := sin((1.0 - jump_left / 0.8) * PI) * 90 if jump_left > 0 else 0.0
	return Vector2(dog_x + facing * 35, 280 - lift)

func advance(delta: float) -> void:
	if not is_finite(delta) or delta <= 0 or finished: return
	remainder += minf(delta, 31)
	while remainder + 0.00000001 >= STEP and not finished:
		remainder -= STEP
		_tick()

func _tick() -> void:
	elapsed = minf(30, elapsed + STEP)
	if holding: hold_time = minf(1.2, hold_time + STEP)
	cooldown = maxf(0, cooldown - STEP)
	jump_left = maxf(0, jump_left - STEP)
	for item in items:
		item.point += item.velocity * STEP
		item.age += STEP
	var target := Vector2.INF
	var closest := INF
	for item in items:
		if item.point.y < 110: continue
		var distance: float = mouth().distance_squared_to(item.point)
		if distance < closest:
			closest = distance
			target = item.point
	moving = false
	if target != Vector2.INF:
		var dx := target.x - mouth().x
		if jump_left <= 0 and absf(dx) > 65: facing = 1 if target.x > dog_x else -1
		var goal := clampf(target.x - facing * 35, 55, 585)
		moving = absf(dog_x - goal) > 2
		dog_x = move_toward(dog_x, goal, STEP * 250)
		if jump_left <= 0 and cooldown <= 0 and absf(target.x - mouth().x) < 65:
			jump_left = 0.8
			cooldown = 1.0
	for i in range(items.size() - 1, -1, -1):
		var item := items[i]
		if jump_left > 0 and mouth().distance_to(item.point) <= float(item.radius) + 8:
			score += 2 if item.gold else 1
			pops.append({"point": item.point, "left": 0.25, "gold": item.gold})
			items.remove_at(i)
		elif item.age > 10 or item.point.y < -item.radius or item.point.x < -item.radius or item.point.x > WORLD.x + item.radius:
			items.remove_at(i)
	for i in range(pops.size() - 1, -1, -1):
		pops[i].left -= STEP
		if pops[i].left <= 0: pops.remove_at(i)
	if elapsed >= 30 or (launched >= 10 and items.is_empty()):
		finished = true
		holding = false
		items.clear()
		jump_left = 0
		moving = false

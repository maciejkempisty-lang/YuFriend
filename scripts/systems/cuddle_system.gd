class_name CuddleSystem
extends RefCounted

const BACK := Rect2(0.23, 0.53, 0.40, 0.20)
const SPOTS := [Vector2(0.57, 0.50), Vector2(0.71, 0.59)]
const SPOT_RADIUS := 0.12
var phase := "idle"
var calm := 0.0
var favorite_time := 0.0
var favorite := 0
var shortened := false
var settled := false
var held := false
var point := Vector2.ZERO
var elapsed := 0.0
var last_move := 0.0
var last_speed := 0.0
var feedback := "Powoli głaszcz grzbiet w obie strony."
var reaction := "idle_lie"
var _reaction_left := 0.0

func start(spot: int, reunion: bool) -> void:
	phase = "stroke"
	calm = 0
	favorite_time = 0
	favorite = clampi(spot, 0, 1)
	shortened = reunion
	settled = false
	held = false
	elapsed = 0
	last_speed = 0
	feedback = "Miło Cię widzieć! Powoli pogłaszcz mój grzbiet." if reunion else "Powoli głaszcz grzbiet w obie strony."
	reaction = "idle_lie"

func running() -> bool:
	return phase in ["stroke", "find"]

func advance(seconds: float) -> void:
	if not running() or not is_finite(seconds) or seconds <= 0: return
	elapsed += seconds
	_reaction_left = maxf(0, _reaction_left - seconds)
	if _reaction_left <= 0: reaction = "idle_lie"

func press(at: Vector2) -> void:
	if not running() or not at.is_finite() or held: return
	held = true
	point = at
	last_move = elapsed
	last_speed = 0

func move(at: Vector2) -> void:
	if not held or not running() or not at.is_finite(): return
	var seconds := elapsed - last_move
	var distance := at.distance_to(point)
	var previous := point
	point = at
	last_move = elapsed
	# No hold-to-win, teleport, delayed event or event-count rewards.
	if seconds <= 0 or seconds > 0.2 or distance < 0.0001: return
	var speed := distance / seconds
	var smooth := last_speed == 0 or absf(speed - last_speed) < 0.45
	last_speed = speed
	if speed > 0.9 or not smooth:
		feedback = "Troszkę wolniej i równiej. Nic się nie stało."
		reaction = "head_tilt_stand"
		_reaction_left = 0.7
		return
	if speed < 0.04: return
	if phase == "stroke":
		if not BACK.has_point(at) or not BACK.has_point(previous): return
		calm = minf(target_seconds(), calm + seconds)
		feedback = "Właśnie tak… spokojnie, w obie strony."
		if calm >= target_seconds():
			phase = "find"
			feedback = "A gdzie lubię najbardziej? Sprawdź uszko i brodę."
	elif at.distance_to(SPOTS[favorite]) <= SPOT_RADIUS and previous.distance_to(SPOTS[favorite]) <= SPOT_RADIUS:
		favorite_time += seconds
		feedback = "O tak, właśnie tutaj! Jeszcze kilka delikatnych ruchów."
		reaction = "petted_stand"
		_reaction_left = 0.7
		if favorite_time >= 2:
			phase = "result"
			held = false
			reaction = "tail_wag_stand"
			feedback = "Ale mi dobrze! Lubię głaski " + ["za uszkiem.", "pod brodą."][favorite]
	else:
		feedback = "Spróbuj drugiego miejsca, spokojnym ruchem."

func release(_at: Vector2 = Vector2.ZERO, cancelled: bool = false) -> void:
	held = false
	last_speed = 0
	if cancelled and running(): feedback = "Możesz wrócić do głaskania w swoim tempie."

func target_seconds() -> float:
	return 8.0 if shortened else 16.0

func cancel() -> void:
	phase = "idle"
	held = false

class_name SitLure
extends Control
signal completed
var short_signal := false
var pointer := -2
var progress := 0.0
var elapsed := 0.0
var last_move := 0.0
var finished := false
var message := "Prowadź smakołyk spokojnie w górę i za głowę."
var preview: Texture2D

func _ready() -> void:
	custom_minimum_size = Vector2(240, 230)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var pack: PetAnimationSet = load("res://data/animations/puppy_pixel.res")
	preview = pack.frames.get_frame_texture("idle", 0)
	queue_redraw()

func point(t: float) -> Vector2:
	return Vector2(size.x * 0.72 - (45.0 if short_signal else 90.0) * t * t, 125.0 - (45.0 if short_signal else 85.0) * t)

func reset(note: String = "Spróbuj ponownie. Opanowanie pozostaje bez zmian.") -> void:
	pointer = -2
	progress = 0
	elapsed = 0
	last_move = 0
	message = note
	queue_redraw()

func press(at: Vector2, id: int) -> void:
	if finished or pointer != -2 or at.distance_to(point(0)) > 28: return
	reset("Spokojnie w górę i za głowę…")
	pointer = id

func move(at: Vector2, id: int) -> void:
	if finished or pointer != id: return
	var t := clampf((125.0 - at.y) / (45.0 if short_signal else 85.0), 0, 1)
	if at.distance_to(point(t)) > 30 or t < progress - 0.12:
		reset("Ręka uciekła ze ścieżki. Poprowadź ją płynnie.")
		return
	var advance := t - progress
	if advance > 0.35 or advance / maxf(0.016, elapsed - last_move) > (5.0 if short_signal else 2.6):
		reset("Za szybko — piesek podskoczyłby za ręką.")
		return
	progress = maxf(progress, t)
	last_move = elapsed
	queue_redraw()

func release(at: Vector2, id: int, canceled: bool = false) -> void:
	if finished or pointer != id: return
	if not canceled and progress >= 0.9 and at.distance_to(point(1)) <= 28 and elapsed >= (0.25 if short_signal else 0.7):
		finished = true
		pointer = -2
		completed.emit()
	else: reset()

func _process(delta: float) -> void:
	if pointer == -2 or finished: return
	elapsed += delta
	if elapsed > (1.5 if short_signal else 3.0): reset("Za wolno — piesek stracił uwagę. Spróbuj płynniej.")

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed: press(event.position, event.index)
		else: release(event.position, event.index, event.canceled)
	elif event is InputEventScreenDrag: move(event.position, event.index)
	elif event is InputEventMouseButton and event.device != -1 and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed: press(event.position, -1)
		else: release(event.position, -1)
	elif event is InputEventMouseMotion and event.device != -1: move(event.position, -1)
	accept_event()

func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT]: reset()

func _draw() -> void:
	if preview != null: draw_texture_rect(preview, Rect2(size.x / 2 - 78, 62, 156, 156), false)
	for i in 20: draw_line(point(i / 20.0), point((i+1) / 20.0), Color("c8cba9"), 5)
	draw_circle(point(1), 13, Color("789a67"))
	draw_circle(point(progress), 19, Color("b98247"))
	draw_string(ThemeDB.fallback_font, Vector2(0, 226), "Krótki sygnał ręką" if short_signal else "Pełne naprowadzenie", HORIZONTAL_ALIGNMENT_CENTER, size.x, 13, Color("294b40"))

extends RoomArtwork

# Separate draw list: ticking never rebuilds the static room artwork.
var _time: Dictionary = {}
var _poll_left := 0.0
var radius := 36.0

func _ready() -> void:
	_sync_system_time()

func _process(delta: float) -> void:
	_poll_left -= delta
	if _poll_left <= 0.0:
		_poll_left = 0.25
		_sync_system_time()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_RESUMED:
		_sync_system_time()

func _sync_system_time() -> void:
	# Read local wall time afresh, including timezone and manual clock changes.
	var current := Time.get_time_dict_from_system(false)
	if current == _time: return
	_time = current
	queue_redraw()

func _draw() -> void:
	draw_count += 1
	_pixel_ellipse(Vector2(3, 6), Vector2.ONE * radius, Color(0.36, 0.29, 0.19, 0.18))
	_pixel_ellipse(Vector2.ZERO, Vector2.ONE * radius, Color("684d35"))
	_pixel_ellipse(Vector2(-3, -3), Vector2.ONE * (radius - 3), Color("d8ac71"))
	_pixel_ellipse(Vector2.ZERO, Vector2.ONE * (radius - 3), Color("bc8a53"))
	_pixel_ellipse(Vector2.ZERO, Vector2.ONE * (radius - 6), Color("815a3d"))
	_pixel_ellipse(Vector2.ZERO, Vector2.ONE * (radius - 9), Color("fbefca"))
	var tick_radius := radius - 12
	for hour in 12:
		var direction := Vector2.UP.rotated(hour * TAU / 12.0)
		_pixel_hand(direction * (tick_radius - 3 if hour % 3 == 0 else tick_radius), direction * tick_radius, Color("967048"))
	if _time.is_empty(): return
	var seconds := float(_time.second)
	var minutes := float(_time.minute) + seconds / 60.0
	var hours := float(int(_time.hour) % 12) + minutes / 60.0
	_pixel_hand(Vector2.ZERO, Vector2.UP.rotated(hours * TAU / 12.0) * (radius - 21), Color("684d35"))
	_pixel_hand(Vector2.ZERO, Vector2.UP.rotated(minutes * TAU / 60.0) * (radius - 15), Color("536d59"))
	var second_direction := Vector2.UP.rotated(seconds * TAU / 60.0)
	_pixel_hand(-second_direction * 6, second_direction * (radius - 15), Color("b9745b"))
	_pixel_rect(Rect2(-3, -3, 6, 6), Color("684d35"))
	_pixel_rect(Rect2(-3, -3, 3, 3), Color("e7c58d"))

func _pixel_hand(start: Vector2, end: Vector2, color: Color) -> void:
	# Rasterize directly on the same three-unit grid as every room decoration.
	var steps := maxi(1, ceili(start.distance_to(end) / PIXEL * 2.0))
	for step in steps + 1:
		var point := start.lerp(end, float(step) / steps).snapped(Vector2.ONE * PIXEL)
		draw_rect(Rect2(point, Vector2.ONE * PIXEL), color)

extends SceneTree
var passed := 0
var failed := 0
func check(ok: bool, label: String) -> void:
 if ok: passed += 1
 else:
  failed += 1
  push_error(label)
func _initialize() -> void:
 var b := BallMotion.new()
 b.start(Vector2(200, 310), Vector2(800, 310))
 var leg := b.first_flight
 var previous_peak := INF
 var time := 0.0
 for i in 4:
  b.elapsed = time + leg * 0.5
  var sample := b.sample()
  check(sample.lift > 0 and sample.lift < previous_peak, 'successive bounce peaks lose energy')
  previous_peak = sample.lift
  b.elapsed = time + leg
  check(absf(b.sample().lift) < 0.001, 'contact returns to ground')
  time += leg
  leg *= BallMotion.RESTITUTION
 b.start(Vector2(200, 310), Vector2(800, 310))
 var c := BallMotion.new()
 c.start(b.origin, b.target)
 for i in 90: b.advance(1.0 / 60)
 c.advance(1.5)
 check(b.sample().point.distance_to(c.sample().point) < 0.01 and absf(b.sample().lift - c.sample().lift) < 0.01, 'trajectory independent of frame rate')
 b.advance(100)
 check(not b.running and b.sample().point == b.target and b.sample().lift == 0, 'settles exactly at selected endpoint')
 b.drop(Vector2(400, 310), Vector2(425, 310), 65)
 check(is_equal_approx(b.sample().lift, 65), 'release starts at mouth height')
 b.advance(b.first_flight + 0.1)
 check(b.sample().lift > 0, 'released ball rebounds')
 b.cancel()
 check(not b.running, 'cancel clears physics')
 print('BALL MOTION: %d passed, %d failed' % [passed, failed])
 quit(1 if failed else 0)

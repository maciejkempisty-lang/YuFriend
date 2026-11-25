extends SceneTree
var app: GameUI
var passed := 0
var failed := 0
func _initialize() -> void:
 create_timer(70).timeout.connect(func(): quit(1))
 call_deferred('run')
func check(ok: bool, label: String) -> void:
 if ok: passed += 1
 else:
  failed += 1
  push_error(label)
func frames() -> void:
 for i in 4: await process_frame
func capture(name: String) -> void:
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png('/tmp/yuf-catch-' + name + '.png')
func run() -> void:
 root.size = Vector2i(390, 844)
 root.content_scale_size = root.size
 app = load('res://scenes/Main.tscn').instantiate()
 app.save_path_override = '/tmp/yuf-catch-ui-%s/pet.json' % Time.get_ticks_usec()
 app.session.local_clock = func(): return 100 * 86400.0 + 12 * 3600
 root.add_child(app)
 app.session.set_process(false)
 app.room.set_process(false)
 app.session.pet.resting = false
 app.session.pet.needs.energy = 95
 app._toggle_yard(false)
 await frames()
 var room := app.room
 room.pet_world = Vector2(750, 315)
 room.look_at_world(room.pet_world)
 for left in [false, true]:
  room.animator.facing_left = left
  room.animate_ball_catch(true)
  room._process(0.3)
  await frames()
  room._sync_layers()
  var expected := room.puppy.position + room.animator.transform * room.animator.ball_grip_point()
  check(room.ball_world.distance_to(expected) < 0.01, 'ball follows current mirrored mouth')
  check(room.animator.position.y < 0 and room.ball_art.z_index < 0 and room.ball_art.ball_held, 'catch hops and muzzle overlaps held ball')
  await capture('ball-left' if left else 'ball-right')
  room._process(0.7)
  check(room.ball_hold_left > 2 and not room.ball_motion.running, 'catch enters distinct holding phase')
  room._process(1.2)
  await frames()
  room._sync_layers()
  expected = room.puppy.position + room.animator.transform * room.animator.ball_grip_point()
  check(room.ball_world.distance_to(expected) < 0.01 and room.animator.position.y == 0, 'held ball follows mouth after landing')
  await capture('hold-left' if left else 'hold-right')
  room._process(1.2)
  check(room.ball_motion.running and room._ball_lift > 0, 'release starts falling from mouth')
  room._process(3)
  check(room._ball_lift == 0 and not room.ball_motion.running, 'released ball settles')
 room.animate_ball_catch(true)
 room._process(1.0)
 room.cancel_activity()
 check(room.ball_hold_left == 0 and room.ball_catch_left == 0 and room.animator.rotation == 0 and RoomLayout.WALK_AREA.has_point(room.ball_world), 'cancel restores pose and puts ball on ground')
 room.throw_ball(Vector2(1100, 315), 1)
 room._process(room.ball_motion.first_flight + 0.12)
 check(room._ball_lift > 0 and room.ball_motion.sample().bounce == 1, 'thrown ball rebounds in room')
 await capture('bounce')
 room.cancel_activity()
 app.session.activity = 'idle'
 app.session.activity_left = 0
 app.session.start_touch_game('frisbee')
 var g := app.session.play
 g.wind = 0.5
 app.session.play_press(Vector2(0.2, 0.6))
 app.session.play_release(Vector2(0.7, 0.4))
 g.advance(g.flight_duration() * g.catch_progress() - 0.3)
 app.session.play_cue()
 g.advance(0.42)
 await frames()
 app.play_view._process(0)
 check(g.disk_attached() and app.play_view.puppy.pending == 'treat_take_stand' or g.disk_attached() and app.play_view.puppy.current == 'treat_take_stand', 'frisbee catch requests mouth animation')
 await capture('frisbee')
 app.session.suspend_session()
 check(not app.play_dialog.visible and g.kind.is_empty(), 'background clears disc and round')
 app.music.stop()
 app.effects.stop_all()
 app.queue_free()
 await frames()
 print('CATCH UI: %d passed, %d failed' % [passed, failed])
 quit(1 if failed else 0)

extends SceneTree
var app: GameUI
var passed := 0
var failed := 0
func _initialize() -> void:
 create_timer(90).timeout.connect(func(): quit(1))
 call_deferred('run')
func check(ok: bool, label: String) -> void:
 if ok: passed += 1
 else:
  failed += 1
  push_error(label)
func tick() -> void:
 app.room.animator._process(0.05)
 app.room._process(0.05)
 app.session._process(0.05)
func until(phase: String) -> void:
 for i in 1200:
  if app.session.timed_course.phase == phase: return
  tick()
 check(false, 'route reaches ' + phase)
func frames() -> void:
 app._refresh()
 app._fit_room()
 for i in 4: await process_frame
func press_command() -> void:
 while app.session.timed_course.phase == 'cue' and app.session.timed_course.phase_time < 1.5: tick()
 app._refresh()
 app.course_action.pressed.emit()
func run() -> void:
 for width in [320, 390]:
  root.size = Vector2i(width, 640 if width == 320 else 844)
  root.content_scale_size = root.size
  app = load('res://scenes/Main.tscn').instantiate()
  app.save_path_override = '/tmp/yuf-timed-ui-%s/pet.json' % Time.get_ticks_usec()
  app.session.local_clock = func(): return 100 * 86400.0 + 12 * 3600
  root.add_child(app)
  app.session.set_process(false)
  app.room.set_process(false)
  app.room.animator.set_process(false)
  app.session.pet.resting = false
  app.session.pet.skills.sit.mastery = 100
  app.session.pet.needs.energy = 95
  app.session.pet.needs.fullness = 95
  app.session.weather.override_kind = 'sun'
  app.session._brain_left = INF
  app.session.visitors.wait_left = INF
  app._toggle_yard(false)
  await frames()
  app.app_foreground = true
  app.room.overview = false
  check(app.yard_menu.offer('course'), 'course offers two modes')
  check(app.yard_menu.primary.text == 'Spokojny tor' and app.yard_menu.secondary.text == 'Na czas', 'both modes labelled')
  app.yard_menu.secondary.pressed.emit()
  check(app.session.timed_course.active() and not app.session.course.active(), 'menu starts separate timed mode')
  until('cue')
  await frames()
  check(app.course_meter.visible and not app.course_action.disabled, 'timing marker and command appear')
  check(app.course_action.size.y >= 44 and app.course_stop.get_global_rect().end.x <= width, 'buttons fit and are touchable')
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png('/tmp/yuf-timed-cue-%d.png' % width)
  press_command()
  until('slalom')
  until('cue')
  check(app.session.timed_course.segment == 1 and app.room.pet_world.distance_to(YardCourse.path()[-1]) < 1, 'real slalom reaches hurdle')
  press_command()
  until('jump')
  for i in 13: tick()
  check(app.room.jump_lift > 40, 'real jump animation')
  await frames()
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png('/tmp/yuf-timed-jump-%d.png' % width)
  until('cue')
  check(app.session.timed_course.segment == 2 and app.room.pet_world.distance_to(YardCourse.podium()) < 1, 'lands and reaches podium')
  press_command()
  until('')
  await frames()
  check(app.session.timed_course.stars == 3 and app.session.pet.skills.stay.attempts == 0, 'clean finish without training attempt')
  var result: AcceptDialog
  for child in app.get_children():
   if child is AcceptDialog and child.title == 'Agility na czas': result = child
  check(result != null and result.visible and app.safe_rect.encloses(Rect2(Vector2(result.position), Vector2(result.size))), 'result dialog fits')
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png('/tmp/yuf-timed-result-%d.png' % width)
  if result != null: result.queue_free()
  await frames()
  app.session.pet.needs.energy = 95
  app.session.pet.fatigue = 0
  app.session.timed_course.start(app.session)
  until('cue')
  press_command()
  until('slalom')
  until('cue')
  press_command()
  until('jump')
  for i in 10: tick()
  app.session.suspend_session()
  await frames()
  check(not app.session.timed_course.active() and not app.room.jump_motion.active() and app.room.animator.position.y == 0, 'background cancels midair safely')
  app.music.stop()
  app.effects.stop_all()
  app.queue_free()
  for i in 4: await process_frame
 print('TIMED COURSE UI: %d passed, %d failed' % [passed, failed])
 quit(1 if failed else 0)

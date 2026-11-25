extends SceneTree
var app: GameUI
var passed := 0
var failed := 0
func _initialize() -> void:
 create_timer(80).timeout.connect(func(): quit(1))
 call_deferred('run')
func check(ok: bool, label: String) -> void:
 if ok: passed += 1
 else:
  failed += 1
  push_error(label)
func frames() -> void:
 for i in 4: await process_frame
 app.app_foreground = true
 app._refresh()
 for i in 4: await process_frame
func run() -> void:
 for width in [320, 390]:
  root.size = Vector2i(width, 640 if width == 320 else 844)
  root.content_scale_size = root.size
  app = load('res://scenes/Main.tscn').instantiate()
  app.save_path_override = '/tmp/yuf-dance-ui-%s/pet.json' % Time.get_ticks_usec()
  app.session.local_clock = func(): return 100 * 86400.0 + 12 * 3600
  root.add_child(app)
  app.session.set_process(false)
  app.session.pet.resting = false
  app.session.pet.needs.energy = 95
  app.session.pet.skills.sit.mastery = 100
  app.session.pet.skills.paw.mastery = 100
  app.session._brain_left = INF
  await frames()
  app._show_play_menu()
  await frames()
  check(app.safe_rect.encloses(Rect2(Vector2(app.play_menu.position), Vector2(app.play_menu.size))), 'seven-game menu fits')
  app._choose_play('freestyle')
  await frames()
  check(app.play_dialog.visible and app.session.play.phase == 'ready', 'freestyle opens instructions')
  check(app.safe_rect.encloses(Rect2(Vector2(app.play_dialog.position), Vector2(app.play_dialog.size))), 'dance dialog fits')
  check(app.play_cue.visible and app.play_cue.size.y >= 44, 'start/timing button has touch height')
  check(app.play_dialog.get_ok_button().size.y >= 44, 'exit touch height')
  app.play_cue.pressed.emit()
  await frames()
  check(app.session.play.phase == 'dance' and app.play_cue.text == 'W rytm!', 'button starts clock')
  app.session.play.advance(3)
  app.play_cue.pressed.emit()
  await frames()
  check(app.session.play.score == 2 and app.play_view.puppy.visible, 'timing button performs known trick')
  app.session.play.advance(5)
  app.play_cue.pressed.emit()
  await frames()
  check(app.session.play.score == 4 and app.session.play.dance_last_clip == 'give_paw', 'next command is learned paw')
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png('/tmp/yuf-freestyle-%d.png' % width)
  app.music.set_enabled(false)
  await frames()
  check(not app.play_view.rhythm_enabled and not app.play_view.rhythm_player.playing, 'music setting silences rhythm')
  app.session.suspend_session()
  await frames()
  check(app.session.play.kind.is_empty() and not app.play_dialog.visible, 'background closes routine')
  app.session.suspended = false
  app.session.activity = 'idle'
  app.session.activity_left = 0
  app.session.start_touch_game('cups')
  app.session.play.phase = 'ready'
  await frames()
  check(not app.play_cue.disabled, 'legacy game cue remains enabled after dance')
  app.music.stop()
  app.effects.stop_all()
  app.queue_free()
  for i in 4: await process_frame
 print('FREESTYLE UI: %d passed, %d failed' % [passed, failed])
 quit(1 if failed else 0)

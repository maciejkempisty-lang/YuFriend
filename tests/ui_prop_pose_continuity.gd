extends SceneTree
var passed := 0
var failed := 0
func _initialize() -> void:
 call_deferred('run')
func check(ok: bool, label: String) -> void:
 if ok: passed += 1
 else:
  failed += 1
  push_error(label)
func pose(p: PetAnimator, clip: String, frame: int) -> void:
 p._start(clip)
 p.sprite.pause()
 p.sprite.frame = frame
 p._apply_transform()
func run() -> void:
 root.size = Vector2i(1100, 520)
 var bg := ColorRect.new()
 bg.color = Color('e7ecd9')
 bg.size = root.size
 root.add_child(bg)
 var p := PetAnimator.new()
 root.add_child(p)
 p.set_skin(load('res://data/skins/puppy_pixel.tres'))
 p.set_process(false)
 for left in [false, true]:
  p.facing_left = left
  pose(p, 'eat_enter', 5)
  var transform := p.sprite.transform
  var region: Rect2 = p.sprite.sprite_frames.get_frame_texture('eat_enter', 5).region
  for spec in [['eat_loop', 0], ['eat_loop', 2], ['eat_exit', 0]]:
   pose(p, spec[0], spec[1])
   check(p.sprite.transform == transform, 'feeding boundary preserves scale and planted feet')
   check(p.sprite.sprite_frames.get_frame_texture(spec[0], spec[1]).region == region, 'feeding boundary preserves silhouette')
  for clip in PetAnimator.BALL_GRIPS:
   for frame in p.sprite.sprite_frames.get_frame_count(clip):
    pose(p, clip, frame)
    var point := p.ball_grip_point()
    check(point.is_finite() and absf(point.x) < 150 and point.y < 0, 'grip stays on head for every carried frame')
 p.queue_free()
 var stages := [['idle', 0], ['eat_enter', 0], ['eat_enter', 5], ['eat_loop', 0], ['eat_exit', 0], ['eat_exit', 5]]
 for i in stages.size():
  var dog := PetAnimator.new()
  root.add_child(dog)
  dog.set_skin(load('res://data/skins/puppy_pixel.tres'))
  dog.set_process(false)
  pose(dog, stages[i][0], stages[i][1])
  dog.scale = Vector2.ONE * 0.82
  dog.position = Vector2(92 + i * 180, 290)
  var title := Label.new()
  title.text = '%s / %d' % stages[i]
  title.position = Vector2(i * 180 + 8, 320)
  title.add_theme_color_override('font_color', Color('315d49'))
  root.add_child(title)
 await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png('/tmp/yuf-feeding-continuity.png')
 print('PROP POSE: %d passed, %d failed' % [passed, failed])
 quit(1 if failed else 0)

extends SceneTree
var passed := 0
var failed := 0
func check(ok: bool, label: String) -> void:
 if ok: passed += 1
 else:
  failed += 1
  push_error(label)
func toss(b: BubblePlay, point: Vector2, duration := 0.6) -> void:
 b.press(point)
 b.advance(duration)
 b.release(point)
func _initialize() -> void:
 var b := BubblePlay.new()
 b.start(0)
 b.press(Vector2(0.5, 0.6))
 b.advance(0.1)
 b.release(Vector2(0.5, 0.6))
 check(b.launched == 0, 'quick tap does not launch')
 b.press(Vector2(0.5, 0.6))
 b.advance(1)
 b.release(Vector2(0.5, 0.6), true)
 check(b.launched == 0 and not b.holding, 'cancelled gesture discards bubble')
 toss(b, Vector2(0.55, 0.6))
 check(b.score == 0 and b.items.size() == 1, 'launch alone earns no points')
 b.advance(1)
 check(b.score == 1 and b.items.is_empty(), 'mouth contact during jump pops once')
 b.advance(1)
 check(b.score == 1, 'popped bubble cannot score twice')
 b.start(0)
 for i in 4: toss(b, Vector2(0.95, 0.36), 0.25)
 check(b.items.size() <= 3 and b.launched == 3, 'three-object limit')
 b.advance(31)
 check(b.finished and b.items.is_empty(), 'time limit clears bubbles')
 b.start(0)
 for i in 10:
  toss(b, Vector2(0.55, 0.6))
  b.advance(1.0)
 check(b.launched == 10 and b.score == 12 and b.finished, 'ten catches include two golden bubbles')
 toss(b, Vector2(0.5, 0.5))
 check(b.launched == 10, 'cannot exceed supply')
 var snapshots: Array = []
 for fps in [30, 60, 120]:
  b.start(0.6)
  toss(b, Vector2(0.8, 0.4))
  for i in fps * 2: b.advance(1.0 / fps)
  snapshots.append([b.score, b.dog_x, b.mouth(), b.items.duplicate(true)])
 check(snapshots[0] == snapshots[1] and snapshots[1] == snapshots[2], 'fixed steps give same simulation at 30 60 120 FPS')
 b.start(0.6)
 toss(b, Vector2(0.8, 0.4))
 b.advance(2)
 check([b.score, b.dog_x, b.mouth(), b.items] == snapshots[0], 'large delta matches small steps')
 var g := SkillPlaySystem.new()
 g.start('bubbles', 42)
 g.advance(20)
 check(g.phase == 'ready' and g.bubbles.elapsed == 0, 'instructions wait')
 g.cue()
 g.advance(31)
 check(g.phase == 'result' and g.stars == 0 and not g.success, 'no rewards for idle round')
 var path := '/tmp/yuf-soap-%s/pet.json' % Time.get_ticks_usec()
 DirAccess.make_dir_recursive_absolute(path.get_base_dir())
 var s := GameSession.new()
 s.local_clock = func(): return 100 * 86400.0 + 12 * 3600
 s.pet = PetState.create(42)
 s.active = true
 s.storage = SaveSystem.new(path)
 s.flush()
 check(not s.start_touch_game('bubbles'), 'bubbles require yard')
 s.in_yard = true
 check(s.start_touch_game('bubbles'), 'yard starts bubbles')
 s.play_cue()
 for i in 10:
  s.play_press(Vector2(0.55, 0.6))
  s.play.advance(0.6)
  s.play_release(Vector2(0.55, 0.6))
  s.play.advance(1)
 s._settle_touch_game()
 check(s.play.stars == 3 and s.play.settled, 'successful round settles')
 check(SkillRecords.read(path, 'bubbles').score == 12, 'record supports full twelve points')
 check(str(s.pet.journal).contains('bubbles_three_stars'), 'first three stars add memory')
 var games: int = s.pet.social.games.ball
 var bond := s.pet.bond
 s._settle_touch_game()
 check(s.pet.social.games.ball == games and s.pet.bond == bond, 'no duplicate settlement')
 s.start_touch_game('bubbles')
 s.play_cue()
 s.play_press(Vector2(0.5, 0.6))
 s.suspend_session()
 check(s.play.kind.is_empty() and not s.play.bubbles.holding and s.play.bubbles.items.is_empty(), 'background disposes of all bubble state')
 s.free()
 print('SOAP BUBBLES: %d passed, %d failed' % [passed, failed])
 quit(1 if failed else 0)

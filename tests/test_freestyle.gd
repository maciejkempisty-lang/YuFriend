extends SceneTree
var passed := 0
var failed := 0
func check(ok: bool, label: String) -> void:
 if ok: passed += 1
 else:
  failed += 1
  push_error(label)
func _initialize() -> void:
 var pet := PetState.create(42)
 var g := SkillPlaySystem.new()
 check(not g.start('freestyle'), 'unknown skills cannot start dance')
 pet.skills.sit.mastery = 49
 check(SkillPlaySystem.known_dance_skills(pet).is_empty(), 'threshold excludes unlearned commands')
 pet.skills.sit.mastery = 50
 g.dance_skills = SkillPlaySystem.known_dance_skills(pet)
 check(g.start('freestyle') and g.dance_duration() == 20, 'one known command gives short routine')
 g.advance(100)
 check(g.total == 0 and g.phase == 'ready', 'instructions wait for explicit start')
 g.cue()
 for i in 4:
  g.advance(g.dance_note_time(i) - g.total)
  g.cue()
 check(g.score == 8 and g.dance_best_combo == 4, 'precise inputs score four commands')
 g.advance(2)
 check(g.phase == 'result' and g.stars == 3, 'perfect routine gets three stars')
 g.cue()
 check(g.score == 8, 'finished routine cannot score again')
 g.start('freestyle')
 g.cue()
 g.cue()
 check(g.dance_grades[0] == 0 and g.score == 0, 'early input consumes command without points')
 g.advance(21)
 check(g.stars == 0 and g.dance_index == 4, 'timeout consumes missed commands and finishes')
 for key in ['paw', 'lie', 'bow', 'spin', 'roll']: pet.skills[key].mastery = 100
 g.dance_skills = SkillPlaySystem.known_dance_skills(pet)
 g.start('freestyle')
 check(g.dance_duration() == 60 and g.dance_notes.size() == 12, 'six skills give long routine')
 g.cue()
 for i in 12:
  g.advance(g.dance_note_time(i) + 0.3 - g.total)
  g.cue()
 g.advance(2)
 check(g.score == 12 and g.stars == 2, 'good timing earns two stars')
 var path := '/tmp/yuf-freestyle-%s/pet.json' % Time.get_ticks_usec()
 DirAccess.make_dir_recursive_absolute(path.get_base_dir())
 check(not SkillRecords.write(path, g), 'unsettled result cannot write record')
 g.settled = true
 check(SkillRecords.write(path, g), 'settled result writes record')
 check(SkillRecords.read(path, 'freestyle_60').score == 12, 'long routine scores above ten survive reload')
 check(SkillRecords.read(path, 'freestyle_20').score == 0, 'routine records stay separate')
 var s := GameSession.new()
 s.local_clock = func(): return 100 * 86400.0 + 12 * 3600
 s.pet = pet
 s.active = true
 s.storage = SaveSystem.new(path)
 s.flush()
 var skills := pet.skills.duplicate(true)
 check(s.start_touch_game('freestyle'), 'dance starts indoors through session')
 s.play_cue()
 for i in s.play.dance_notes.size():
  s.play.advance(s.play.dance_note_time(i) - s.play.total)
  s.play_cue()
 s.play.advance(2)
 s._settle_touch_game()
 check(s.play.settled and s.play.stars == 3, 'session settles successful routine')
 var bond := pet.bond
 var games: int = pet.social.games.ball
 s._settle_touch_game()
 check(pet.bond == bond and pet.social.games.ball == games, 'no duplicate reward')
 check(pet.skills == skills, 'dance does not bypass training progression')
 check(str(pet.journal).contains('freestyle_full'), 'full routine adds memory')
 check(s.start_touch_game('freestyle'), 'can replay after result')
 s.suspend_session()
 check(s.play.kind.is_empty() and s.suspended, 'background cancels dance')
 check(SaveSystem.new(path).load_pet() != null, 'save remains readable')
 s.free()
 print('FREESTYLE: %d passed, %d failed' % [passed, failed])
 quit(1 if failed else 0)

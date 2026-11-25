extends SceneTree
var pulses: Array[int] = []
var now := 1000
func _initialize() -> void:
 var h := HapticFeedback.new()
 var path := '/tmp/yuf-haptics-%s.cfg' % Time.get_ticks_usec()
 var config := ConfigFile.new()
 config.set_value('tutorial', 'seen', true)
 config.save(path)
 h.start(path)
 h.supported = true
 h.clock = func(): return now
 h.output = func(ms: int): pulses.append(ms)
 h.play_event('success')
 assert(pulses.is_empty(), 'opt in required')
 h.set_enabled(true)
 h.play_event('pet')
 assert(pulses == [20])
 h.play_event('success')
 assert(pulses.size() == 1, 'rapid events coalesced')
 now += 250
 h.play_event('step')
 h.play_event('bark')
 assert(pulses.size() == 1, 'ambient events silent')
 h.play_event('success')
 assert(pulses == [20, 40])
 now += 250
 h.backgrounded = true
 h.play_event('success')
 assert(pulses.size() == 2)
 h.backgrounded = false
 h.supported = false
 h.play_event('success')
 assert(pulses.size() == 2)
 var restored := HapticFeedback.new()
 restored.start(path)
 assert(restored.enabled, 'preference survives restart')
 config.load(path)
 assert(config.get_value('tutorial', 'seen') == true, 'other preferences preserved')
 restored.set_enabled(false)
 h.start(path)
 assert(not h.enabled)
 DirAccess.remove_absolute(path)
 print('HAPTICS: 10 checks passed')
 quit()

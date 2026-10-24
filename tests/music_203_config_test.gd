extends SceneTree
const Music = preload("res://audio/music_director.gd")
var passed: int = 0
var failed: int = 0
func check(ok: bool, label: String) -> void:
    if ok: passed += 1
    else:
        failed += 1
        push_error("FAIL " + label)
func _initialize() -> void:
    call_deferred("run")
func run() -> void:
    var path: String = "res://.local/music203-test.json"
    var file := FileAccess.open(path,FileAccess.WRITE)
    file.store_string(JSON.stringify({"bpm":203.0,"fixed_beats":8,"random_beats":8,"rest_beats":8,"final_beats":8}))
    file.close()
    var music := Music.new()
    root.add_child(music)
    music.configure(null,path)
    music.set_process(false)
    check(is_equal_approx(music.bpm,203.0),"configured 203 BPM is not silently clipped to 200")
    check(is_equal_approx(music.seconds_per_beat(),60.0/203.0),"one beat retains the reference score period")
    music.start_score()
    music._process(60.0/203.0*1.01)
    check(music.total_beats==1 and music.get_score_time()>60.0/203.0,"the actual sole score clock advances at configured 203 BPM")
    music.stop_score()
    music.free()
    print("Music 203 config: %d passed, %d failed" % [passed,failed])
    quit(1 if failed else 0)

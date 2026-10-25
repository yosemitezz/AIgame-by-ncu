# Exported-content fixture; no input playback, combat tour or user saves.
extends SceneTree
var passed:int=0
var failed:int=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
    if ok:passed+=1;print("PASS ",label)
    else:failed+=1;push_error("FAIL "+label)
func freeze(node:Node)->void:
    node.set_process(false);node.set_physics_process(false)
    for child:Node in node.get_children():freeze(child)
func run()->void:
    check(FileAccess.file_exists("res://data/chapter_story.json"),"packed chapter JSON exists")
    var timeline:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/full_song_timeline.json"))
    check(FileAccess.file_exists(str(timeline.get("chart_path",""))),"packed reference score exists")
    check(FileAccess.file_exists(str(timeline.get("audio_path",""))),"selected recording sidecar exists")
    var game:Node=load("res://main.tscn").instantiate()
    game.chapter_enabled=true;game.chapter_persist=false
    root.add_child(game);current_scene=game
    await process_frame;freeze(game)
    check(is_instance_valid(game.chapter) and game.chapter.blocked(),"packed actual dungeon opens safe chapter")
    check(game.chapter.state.corruption==0.0,"packed new chapter starts clean")
    var status:Dictionary=game.music.get_full_song_status()
    check(bool(status.get("ready",false)),"packed full-song transport finds audio and chart")
    var save:Script=load("res://flow/chapter_save.gd")
    var path:String="res://.local/packed-smoke-fixture.json"
    var result:Error=save.write(path,game.chapter.state.snapshot(),{"room":"dungeon"})
    check(result==OK and not save.read(path).is_empty(),"portable local save writes and reads")
    if result==OK:save.erase(path)
    game.chapter.state.skip();game.chapter.tick(.2);freeze(game)
    game._start_boss(false);freeze(game)
    check(is_instance_valid(game.boss) and game.room_id=="boss","packed main mounts the actual Boss room")
    game.queue_free();await process_frame
    print("Packed scene: %d passed, %d failed"%[passed,failed])
    quit(0 if failed==0 else 1)

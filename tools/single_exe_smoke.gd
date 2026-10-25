extends Node
## Runs against an isolated official release EXE, with all game resources embedded.
var passed:int=0
var failed:int=0
@onready var root:Window=get_tree().root
func _ready()->void:
    if "--verify-embedded-build" not in OS.get_cmdline_user_args():queue_free();return
    if OS.get_environment("BELLKEEP_VERIFY_ISOLATED")!="1":get_tree().quit(2);return
    call_deferred("run")
func check(ok:bool,label:String)->void:
    if ok:passed+=1;print("PASS ",label)
    else:failed+=1;push_error("FAIL "+label)
func freeze(node:Node)->void:
    node.set_process(false);node.set_physics_process(false)
    for child:Node in node.get_children():freeze(child)
func run()->void:
    var base:String=OS.get_executable_path().get_base_dir()
    check(not OS.has_feature("editor") and not OS.has_feature("debug"),"official release template, no editor/debug runner")
    check(not FileAccess.file_exists(base+"/Bellkeep.pck") and not DirAccess.dir_exists_absolute(base+"/boss_attack"),"no adjacent PCK or source-score folder")
    var resource_root:String=ProjectSettings.globalize_path("res://").replace("\\","/")
    check(not resource_root.contains("/.build/") and not FileAccess.file_exists(base+"/project.godot"),"resource root does not fall back to a source project")
    var config:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/full_song_timeline.json"))
    for kind:String in ["audio","chart"]:
        var path:String=str(config[kind+"_path"])
        check(path.begins_with("res://data/runtime_payload/"),kind+" points to embedded payload")
        check(FileAccess.file_exists(path),kind+" reads through embedded virtual filesystem")
        check(FileAccess.get_sha256(path)==str(config["expected_"+kind+"_sha256"]),kind+" embedded bytes preserve source SHA")
    if FileAccess.file_exists(base+"/.local/chapter-save.json"):
        push_error("FAIL isolation directory already has player progress");get_tree().quit(2);return
    await get_tree().process_frame
    var title:Control=get_tree().current_scene
    check(is_instance_valid(title),"normal embedded title entry reached")
    check(is_instance_valid(title.get_node_or_null("%TitleMenu")),"embedded title menu mounts")
    title._open_settings();await get_tree().process_frame
    check(title.get_node("%SettingsMenu").visible,"embedded settings open")
    title.get_node("%SettingsMenu").close_menu();await get_tree().process_frame
    check(not title.get_node("%SettingsMenu").visible,"embedded settings close")
    title.get_node("%TitleMenu").get_node("%PlayButton").pressed.emit()
    await get_tree().process_frame;await get_tree().process_frame
    var game:Node=get_tree().current_scene
    check(is_instance_valid(game) and game.scene_file_path=="res://main.tscn","actual title Play route opens embedded dungeon")
    game.chapter_persist=false;game.chapter.persist=false;freeze(game)
    check(is_instance_valid(game.chapter) and game.chapter.blocked(),"embedded actual dungeon and chapter mount safely")
    var status:Dictionary=game.music.get_full_song_status()
    check(bool(status.get("ready",false)) and float(status.get("duration",0))>400.0,"embedded complete song and chart ready")
    check(is_equal_approx(float(status.get("bpm",0)),203.0) and is_equal_approx(float(status.get("offset_ms",0)),245.0),"music timing unchanged")
    var save:Script=load("res://flow/chapter_save.gd")
    var path:String="res://.local/single-exe-save-fixture.json"
    var result:Error=save.write(path,game.chapter.state.snapshot(),{"room":"dungeon"})
    check(result==OK and not save.read(path).is_empty(),"isolated local save roundtrip")
    if result==OK:save.erase(path)
    game.chapter.state.skip();game.chapter.tick(.2);freeze(game)
    game._start_boss(false);freeze(game)
    check(game.room_id=="boss" and is_instance_valid(game.boss) and game.boss_started,"embedded actual Boss battle begins")
    check(game.music.running,"Boss uses embedded song transport")
    game.queue_free();await get_tree().process_frame
    print("Single EXE: %d passed, %d failed"%[passed,failed])
    get_tree().quit(0 if failed==0 else 1)

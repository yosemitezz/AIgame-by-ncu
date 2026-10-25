extends SceneTree
## Real packed-only audio fixture. No playback, real saves or gameplay traversal.
const Music=preload("res://audio/music_director.gd")
const SOURCE_TIMELINE:String="res://data/full_song_timeline.json"
var passed:int=0
var failed:int=0
class Game extends Node:
    var story_safe:bool=false
    var notices:Array[String]=[]
    func set_story_safe(value:bool)->void:story_safe=value
    func announce(text:String,_seconds:float=3.0)->void:notices.append(text)
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
    if ok:passed+=1;print("PASS ",label)
    else:failed+=1;push_error("FAIL "+label)
func write_json(path:String,value:Dictionary)->void:
    var output:FileAccess=FileAccess.open(path,FileAccess.WRITE)
    output.store_string(JSON.stringify(value))
    output.close()
func score(game:Game,path:String)->Node:
    var music:Node=Music.new()
    game.add_child(music)
    music.set_process(false)
    music.configure(game,path)
    return music
func run()->void:
    create_timer(25.0,true,false,true).timeout.connect(func()->void:push_error("FAIL packed audio watchdog");quit(2))
    var fixture:String="res://.local/tests/packed-audio-%d"%OS.get_process_id()
    var absolute:String=ProjectSettings.globalize_path(fixture)
    DirAccess.make_dir_recursive_absolute(absolute)
    var timeline:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(SOURCE_TIMELINE))
    var source_audio:String=str(timeline["audio_path"])
    var source_chart:String=str(timeline["chart_path"])
    var packed_root:String="res://__packed_audio_only_%d"%OS.get_process_id()
    timeline["audio_path"]=packed_root+"/score.ogg"
    timeline["chart_path"]=packed_root+"/chart.json"
    var source_copy:String=fixture+"/timeline.json"
    write_json(source_copy,timeline)
    var pack_path:String=fixture+"/virtual-audio.pck"
    var packer:=PCKPacker.new()
    var pack_error:Error=packer.pck_start(pack_path)
    if pack_error==OK:pack_error=packer.add_file(str(timeline["audio_path"]),source_audio)
    if pack_error==OK:pack_error=packer.add_file(str(timeline["chart_path"]),source_chart)
    if pack_error==OK:pack_error=packer.add_file(packed_root+"/timeline.json",source_copy)
    if pack_error==OK:pack_error=packer.flush()
    check(pack_error==OK,"controlled PCK fixture includes raw selected OGG, chart and config")
    check(ProjectSettings.load_resource_pack(pack_path,false),"Godot mounts the controlled resource pack")
    check(FileAccess.file_exists(str(timeline["audio_path"])) and not FileAccess.file_exists(ProjectSettings.globalize_path(str(timeline["audio_path"]))),"recording exists only in PCK, not as a host absolute file")
    check(FileAccess.get_sha256(str(timeline["audio_path"]))==str(timeline["expected_audio_sha256"]) and FileAccess.get_sha256(str(timeline["chart_path"]))==str(timeline["expected_chart_sha256"]),"packed bytes retain both original configured hashes")
    var game:=Game.new();root.add_child(game)
    var packed:Node=score(game,packed_root+"/timeline.json")
    var status:Dictionary=packed.get_full_song_status()
    check(packed.is_full_song() and bool(status["ready"]),"production music director configures from virtual-only OGG")
    if not packed.is_full_song():
        game.queue_free();await process_frame
        print("Packed audio loading: %d passed, %d failed"%[passed,failed]);quit(1);return
    var stream:AudioStreamOggVorbis=packed._audio.stream
    check(stream!=null and absf(stream.get_length()-418.516)<0.02 and not stream.loop,"actual packed recording decodes at unchanged duration without looping")
    var source_stream:AudioStreamOggVorbis=AudioStreamOggVorbis.load_from_file(ProjectSettings.globalize_path(source_audio))
    check(source_stream!=null and is_equal_approx(source_stream.get_length(),stream.get_length()),"buffer decoder duration matches the prior disk decoder")
    check(is_equal_approx(packed.bpm,203.0) and is_equal_approx(float(status["offset_ms"]),245.0),"203 BPM and +245ms source offset are unchanged")
    check(int(status["chart_stats"]["timed_notes"])==1702 and packed.get_heavy_groups().size()==121 and int(status["chart_stats"]["action_phrases"])==237,"complete reference chart retains its note, heavy and action counts")
    check(not packed.running and not packed._audio.playing,"configuration does not start song playback")
    packed.start_score();packed._process(0.5)
    check(absf(packed.get_chart_time()-0.5)<0.00001 and absf(packed.get_score_time()-0.5)<0.00001,"the original deterministic clock starts and advances normally")
    packed.set_score_paused(true);packed._process(2.0)
    check(absf(packed.get_score_time()-0.5)<0.00001,"pause keeps the existing transport position")
    packed.stop_score()
    var loose:Node=score(game,SOURCE_TIMELINE)
    check(loose.is_full_song() and absf(loose._audio.stream.get_length()-stream.get_length())<0.00001,"loose-source execution remains compatible")
    var invalid:Dictionary=timeline.duplicate(true)
    invalid["audio_path"]=packed_root+"/absent.ogg"
    write_json(fixture+"/missing.json",invalid)
    var missing:Node=score(game,fixture+"/missing.json")
    check(not missing.is_full_song() and not missing.running and str(missing.get_full_song_status()["error"])=="Audio file is unavailable","missing recording fails closed with the existing error")
    invalid=timeline.duplicate(true);invalid["expected_audio_sha256"]="0".repeat(64)
    write_json(fixture+"/bad-hash.json",invalid)
    var bad_hash:Node=score(game,fixture+"/bad-hash.json")
    check(not bad_hash.is_full_song() and not bad_hash.running and str(bad_hash.get_full_song_status()["error"])=="Audio SHA256 does not match the configured recording","packed recording cannot bypass its expected hash")
    game.queue_free();await process_frame
    print("Packed audio loading: %d passed, %d failed"%[passed,failed])
    quit(0 if failed==0 else 1)

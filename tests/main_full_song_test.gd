extends SceneTree
## Bounded actual-main full-song wiring fixtures. No subproject scene or song playback run.
const Hazard = preload("res://combat/boss_hazard.gd")
const AUDIO_PATH: String = "res://boss_attack/audio/if_infinity.ogg"
var passed: int = 0
var failed: int = 0
var finished: bool = false
var game: Node
var completed_count: int = 0
var saved_placeholder: String = ""

func check(ok: bool,label: String) -> void:
    if ok:
        passed += 1
        print("PASS ",label)
    else:
        failed += 1
        push_error("FULL MAIN FAIL: "+label)

func _initialize() -> void:
    saved_placeholder = OS.get_environment("BELLKEEP_USE_PLACEHOLDER")
    OS.set_environment("BELLKEEP_USE_PLACEHOLDER","")
    call_deferred("run")
    call_deferred("watchdog")

func watchdog() -> void:
    var timer: SceneTreeTimer = create_timer(15.0,true,false,true)
    timer.timeout.connect(func() -> void:
        if not finished:
            push_error("FULL MAIN FAIL: bounded fixture timeout; inspect previous engine errors")
            OS.set_environment("BELLKEEP_USE_PLACEHOLDER",saved_placeholder)
            quit(1))

func freeze_scene() -> void:
    game.set_process(false)
    game.set_physics_process(false)
    for node: Node in game.find_children("*","Node",true,false):
        node.set_process(false)
        node.set_physics_process(false)

func freeze_danger() -> void:
    for node: Node in get_nodes_in_group("boss_hazards")+get_nodes_in_group("projectiles"):
        node.set_process(false)
        node.set_physics_process(false)

func boot() -> bool:
    var scene: PackedScene = load("res://main.tscn")
    if scene == null: return false
    game = scene.instantiate()
    root.add_child(game)
    current_scene = game
    if not game.has_method("_start_boss") or game.get("music") == null: return false
    freeze_scene()
    await physics_frame
    return true

func start_encounter() -> void:
    # Force the supported deterministic seam BEFORE shipping start_encounter/start_score.
    game.music._dummy = true
    game.music.set_process(false)
    game.player.position = Vector2(2900,300)
    game.player.invuln = 999.0
    game._start_boss()
    freeze_scene()
    game._heavy_lane._process(0.0)

func tick(delta: float) -> void:
    game.music._process(delta)
    freeze_danger()
    game._heavy_lane._process(0.0)

func advance_to_chart(target: float) -> void:
    var transport: RefCounted = game.music._transport
    if game.music.current_section == "fixed" and target > float(transport.fixed_end):
        tick(float(transport.fixed_end)-game.music.get_chart_time()+0.0001)
    if game.music.current_section == "random" and target > float(transport.random_end):
        game.music.request_advance()
    tick(maxf(0.0,target-game.music.get_chart_time()))

func danger_probe() -> Node2D:
    var now: float = game.music.get_score_time()
    var records: Array[Dictionary] = [{"origin":Vector2(3000,210),"angle_radians":0.0,"warning_time":now,"damage_time":now+0.5,"active_until":now+2.0,"thickness":9.0}]
    var hazard: Node2D = Hazard.new()
    hazard.configure_lines(game,game.boss,records,game.boss.LASER_ARENA,game.boss.hazard_generation,"full_song_probe")
    game.spawn_boss_hazard(hazard)
    hazard.set_physics_process(false)
    return hazard

func finish() -> void:
    paused = false
    OS.set_environment("BELLKEEP_USE_PLACEHOLDER",saved_placeholder)
    if is_instance_valid(game): game.queue_free()
    await process_frame
    await process_frame
    game = null
    finished = true
    print("Main full song: %d passed, %d failed" % [passed,failed])
    quit(1 if failed else 0)

func run() -> void:
    root.size = Vector2i(800,450)
    check(not FileAccess.file_exists("res://.local/local_score.json"),"shipping fixture has no local audio override")
    var loaded: bool = await boot()
    check(loaded,"actual main scene and its full-song dependencies load")
    if not loaded:
        await finish()
        return
    var music: Node = game.music
    check(music.is_full_song() and music.get_full_song_status().get("ready",false),"shipping main configure selects full-song mode")
    if not music.is_full_song():
        await finish()
        return
    var status: Dictionary = music.get_full_song_status()
    check(is_equal_approx(music.bpm,203.0) and is_equal_approx(float(status["offset_ms"]),245.0),"actual recording uses203 BPM and245ms offset")
    var stats: Dictionary = music._full_chart.get_stats()
    check(int(stats["timed_notes"]) == 1702 and music.get_heavy_groups().size() == 121 and int(stats["action_phrases"]) == 237,"main parsed full1702/121/237 source chart")
    var audio: AudioStreamPlayer = music._audio
    check(str(music.timeline.get("audio_path","")) == AUDIO_PATH and str(status["chart_path"]).begins_with("res://boss_attack/"),"shipping resources use public project paths, not host C paths")
    var recording: FileAccess = FileAccess.open(AUDIO_PATH,FileAccess.READ)
    check(recording != null and recording.get_length() == 12272916 and audio.stream is AudioStreamOggVorbis and absf(audio.stream.get_length()-418.516) < 0.02 and not audio.stream.loop,"actual selected OGG is decoded at418.516 seconds without looping")
    if recording != null: recording.close()
    check(not music.running and is_instance_valid(game._heavy_lane) and game._heavy_lane.game == game,"main owns the pre-battle music and heavy lane")
    start_encounter()
    check(music._dummy and music._device_dummy and not audio.playing and music.running and game.boss.get_authored_status().get("full_song",false) and music.get_transport_generation() > 0,"real Boss start uses configured full chart and deterministic clock")
    tick(0.5)
    check(absf(music.get_score_time()-0.5) < 0.00001 and absf(music.get_chart_time()-0.5) < 0.00001 and absf(game._heavy_lane._chart_now-music.get_chart_time()) < 0.00001,"heavy lane and source runtime read the same sole clock")
    var before_score: float = music.get_score_time()
    var before_chart: float = music.get_chart_time()
    var before_generation: int = music.get_transport_generation()
    game._set_overlay("pause")
    music._process(20.0)
    check(paused and bool(music.get_full_song_status()["paused"]) and music._transport.paused and not audio.playing and is_equal_approx(music.get_score_time(),before_score) and is_equal_approx(music.get_chart_time(),before_chart),"root pause freezes both clocks and preserves stopped Dummy stream")
    game._set_overlay("map")
    music._process(20.0)
    check(game._overlay == "map" and music._transport.paused and not audio.playing and is_equal_approx(music.get_chart_time(),before_chart),"root map overlay preserves frozen transport and Dummy stream state")
    game._set_overlay("")
    tick(0.03)
    check(not paused and not audio.stream_paused and not bool(music.get_full_song_status()["paused"]) and music.get_score_time() > before_score and music.get_transport_generation() == before_generation,"overlay resume continues the existing generation and stream")
    var heavy_time: float = -1.0
    var transport: RefCounted = music._transport
    for group: Dictionary in music.get_heavy_groups():
        var at: float = float(group["time"])
        if at <= music.get_chart_time()+0.2: continue
        if at >= float(transport.random_end)-0.4 and at <= float(transport.rest_end)+0.4: continue
        if absf(at-float(transport.fixed_end)) < 0.4: continue
        heavy_time = at
        break
    check(heavy_time > 0,"real source chart supplies an eligible heavy cue")
    if heavy_time <= 0:
        await finish()
        return
    advance_to_chart(heavy_time)
    check(game._heavy_lane.visible and game._heavy_lane._judge != null and game._heavy_lane._generation == music.get_transport_generation() and is_equal_approx(game._heavy_lane._chart_now,music.get_chart_time()),"main heavy lane is bound to real source groups and transport generation")
    game.player._parry_cooldown = 0.75
    game.player.parry_timer = 0.0
    var defended: bool = game.player._start_parry()
    var raw: InputEventKey = InputEventKey.new()
    raw.pressed = true
    raw.echo = false
    raw.keycode = KEY_SHIFT
    raw.physical_keycode = KEY_SHIFT
    raw.location = KEY_LOCATION_LEFT
    game._heavy_lane._unhandled_input(raw)
    tick(0.13)
    var judged: bool = false
    for result: Dictionary in game._heavy_lane._results:
        if bool(result.get("success",false)) and absf(float(result.get("time",-1))-heavy_time) < 0.00001: judged = true
    check(not defended and game.player.parry_timer == 0.0 and judged and is_equal_approx(game.player._parry_cooldown,0.75),"raw Left Shift judges heavy cue independently of blocked combat cooldown")
    var hazard: Node2D = danger_probe()
    var shot: Node2D = game.spawn_projectile(Vector2(2900,140),Vector2(10,0))
    freeze_danger()
    check(is_instance_valid(hazard) and is_instance_valid(shot) and not get_nodes_in_group("boss_hazards").is_empty(),"retry fixture contains real main danger and judged UI state")
    var old_music: WeakRef = weakref(music)
    var old_lane: WeakRef = weakref(game._heavy_lane)
    game._reload(false)
    await process_frame
    await process_frame
    game = current_scene
    freeze_scene()
    await physics_frame
    check(not is_instance_valid(old_music.get_ref()) and not is_instance_valid(old_lane.get_ref()) and get_nodes_in_group("boss_hazards").is_empty() and get_nodes_in_group("projectiles").is_empty(),"actual main retry destroys old source/UI and all danger")
    music = game.music
    check(music.is_full_song() and not music.running and is_zero_approx(music.get_chart_time()) and is_zero_approx(music.get_score_time()) and game._heavy_lane._results.is_empty() and game._heavy_lane._marks.is_empty(),"retry boots fresh source clock and empty heavy feedback")
    start_encounter()
    check(music.running and is_zero_approx(music.get_chart_time()) and game._heavy_lane._generation == music.get_transport_generation(),"retry Boss starts a new bound transport without stale cue state")
    music.song_completed.connect(func() -> void: completed_count += 1)
    transport = music._transport
    advance_to_chart(float(transport.random_end)+0.01)
    check(game.story_safe and music.current_section == "rest","main transport phrase gate enters real mutual-safety rest")
    advance_to_chart(float(transport.rest_end)+0.01)
    check(not game.story_safe and music.current_section == "final","full song exits rest into real final phase")
    hazard = danger_probe()
    shot = game.spawn_projectile(Vector2(2900,140),Vector2(10,0))
    freeze_danger()
    var boss_hp: int = game.boss.health
    tick(float(transport.duration)-music.get_chart_time()+0.01)
    music._process(1.0)
    check(completed_count == 1 and not music.running and bool(music.get_full_song_status()["ended"]) and game.story_safe,"EOF completes once, stops score and enters safety")
    check(game.outcome == "" and not game.boss.dead and game.boss.health == boss_hp and not bool(get_meta("bellkeep_chapter_complete",false)),"song completion never manufactures Boss victory")
    check(get_nodes_in_group("boss_hazards").is_empty() and get_nodes_in_group("projectiles").is_empty() and not game._heavy_lane.visible and game._heavy_lane._marks.is_empty() and game._announcement_time > 0,"EOF clears real danger and heavy preview while root offers retry notice")
    await finish()

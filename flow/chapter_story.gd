extends RefCounted
## Data-driven chapter state only. The root applies queued commands to game actors/audio.
const DATA_PATH: String = "res://data/chapter_story.json"
const SNAPSHOT_VERSION: int = 1
const RESCUE_POLICIES: Array[String] = ["conditional", "lethal_only"]
var data: Dictionary = {}
var phase: String = "explore"
var blocking: bool = false
var rescue_used: bool = false
var chapter_complete: bool = false
var narrative_dead: bool = false
var ending_seen: bool = false
var ending_dismissed: bool = false
var kill_count: int = 0
var corruption: float = 0.0
var rescue_policy: String = "conditional"
var _seen: Dictionary = {}
var _kills: Dictionary = {}
var _once: Dictionary = {}
var _commands: Array[Dictionary] = []
var _barks: Array[String] = []
var _pending_keys: Dictionary = {}
var _bark: String = ""
var _bark_elapsed: float = 0.0
var _node: String = ""
var _elapsed: float = 0.0
var _scene: String = ""
var _run: int = 0
var _replay: bool = false
var _paused: bool = false
var _transporting: bool = false
var _in_boss: bool = false
var _synchronized: bool = false
var _terminal_elapsed: float = 0.0

func _init() -> void:
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
    if parsed is Dictionary: data = parsed
    rescue_policy = str(data.get("rescue_policy", "conditional"))

func configure(saved: Dictionary = {}, options: Dictionary = {}) -> void:
    if not saved.is_empty(): restore(saved)
    if options.has("rescue_policy"): set_rescue_policy(str(options["rescue_policy"]))

func set_rescue_policy(value: String) -> bool:
    if value not in RESCUE_POLICIES: return false
    rescue_policy = value
    return true

func validate_data() -> Array[String]:
    var errors: Array[String] = []
    var nodes: Dictionary = data.get("nodes", {})
    var lines: Dictionary = data.get("lines", {})
    for name: String in nodes:
        var item: Dictionary = nodes[name]
        if float(item.get("duration", 0.0)) <= 0.0: errors.append(name+": duration")
        var line: String = str(item.get("line", ""))
        if not line.is_empty() and not lines.has(line): errors.append(name+": line")
        var destination: String = str(item.get("next", ""))
        if destination not in ["@explore", "@narrative_dead"] and not nodes.has(destination): errors.append(name+": next")
        var visited: Dictionary = {}
        var cursor: String = name
        for limit: int in nodes.size()+1:
            if cursor.begins_with("@"): break
            if visited.has(cursor): errors.append(name+": cycle"); break
            visited[cursor] = true
            if not nodes.has(cursor): break
            cursor = str(nodes[cursor].get("next", ""))
    for scene: String in data.get("scenes", {}):
        if not nodes.has(data["scenes"][scene]): errors.append(scene+": start")
    for event_id: String in data.get("tutorials", {}):
        if not lines.has(data["tutorials"][event_id]): errors.append(event_id+": tutorial")
    return errors

func begin_chapter() -> bool:
    if blocking or chapter_complete or _transporting or _seen.has("opening"): return false
    _seen["opening"] = true
    return _begin("opening")

func is_blocking() -> bool: return blocking

func event(id: String, context: Dictionary = {}) -> bool:
    id = str({"move":"moved", "jump":"jumped", "attack":"attack_hit", "dodge":"dodged", "parry":"parried", "interact":"door_opened", "boss_enter":"boss_entered"}.get(id,id))
    if id == "room_changed":
        _in_boss = str(context.get("room", "dungeon")) == "boss"
        _barks.clear(); _pending_keys.clear(); _bark = ""; _bark_elapsed = 0.0
        return true
    if _paused or _transporting or blocking or chapter_complete: return false
    if id == "enemy_defeated":
        var spawn: String = str(context.get("id", ""))
        if spawn.is_empty() or _kills.has(spawn): return false
        _kills[spawn] = true
        kill_count = _kills.size()
        corruption = minf(float(data.get("corruption_before_boss_cap", 0.62)), kill_count*float(data.get("corruption_per_unique_kill", 0.045)))
        if kill_count == 1: _bark_once("kill_first", "T_FIRST_KILL")
        elif kill_count == 5: _bark_once("kill_growth", "T_GROWTH")
        if str(context.get("kind", "")) == "elite":
            _bark_once("elite", "T_ELITE")
            _bark_once("foreshadow_elite", "F_ELITE")
        return true
    if id == "boss_entered": _in_boss = true
    var tutorial: String = str(data.get("tutorials", {}).get(id, ""))
    var accepted: bool = false
    if not tutorial.is_empty():
        # Jump/air-jump share one actual-operation tutorial, not two repeated lines.
        accepted = _bark_once("tutorial:"+tutorial, tutorial)
    if id == "boss_entered": accepted = _bark_once("foreshadow_boss", "F_BOSS") or accepted
    return accepted

func _bark_once(key: String, line: String) -> bool:
    if _seen.has(key) or _pending_keys.has(line) or _bark == line or not data.get("lines", {}).has(line): return false
    var limit: int = clampi(int(data.get("bark_queue_limit", 4)), 1, 8)
    if _bark.is_empty():
        _seen[key] = true
        _bark = line
        _bark_elapsed = 0.0
        return true
    if _barks.size() >= limit: return false
    _barks.append(line)
    _pending_keys[line] = key
    return true

func can_rescue(in_boss: bool, lethal: bool) -> bool:
    return in_boss and lethal and not rescue_used and not chapter_complete and not blocking and not _paused and not _transporting

func request_rescue(context: Dictionary = {}) -> bool:
    if not can_rescue(bool(context.get("in_boss", _in_boss)), bool(context.get("lethal", false))): return false
    rescue_used = true
    return _begin("rescue")

func boss_defeated() -> bool:
    if chapter_complete: return false
    chapter_complete = true
    corruption = 1.0
    _emit_once("chapter_complete")
    # High-skill players keep their victory: no compulsory defeat or boss health reset.
    var scene: String = "ending_assisted" if not rescue_used and rescue_policy == "conditional" else "ending"
    return _begin(scene)

func _begin(scene: String) -> bool:
    var start: String = str(data.get("scenes", {}).get(scene, ""))
    if not data.get("nodes", {}).has(start): return false
    _run += 1
    _scene = scene
    if scene.begins_with("ending"): ending_dismissed = false
    _replay = false
    blocking = true
    narrative_dead = false
    _terminal_elapsed = 0.0
    _synchronized = true
    _barks.clear(); _pending_keys.clear(); _bark = ""; _bark_elapsed = 0.0
    _emit("narrative_lock", {"scene":scene, "pause_music":true, "clear_attacks":true})
    _enter(start)
    return true

func _enter(id: String) -> void:
    _node = id
    _elapsed = 0.0
    var item: Dictionary = data["nodes"][id]
    phase = str(item.get("phase", "explore"))
    for command: String in item.get("commands", []): _emit_once(command)

func tick(delta: float, paused: bool = false, transition: bool = false) -> void:
    _paused = paused
    _transporting = transition
    if paused or transition: return
    var remaining: float = maxf(0.0, delta)
    if not blocking:
        if narrative_dead:
            _terminal_elapsed += remaining
            return
        if not _bark.is_empty():
            _bark_elapsed += remaining
            if _bark_elapsed >= float(data.get("bark_seconds", 3.6)):
                _bark = _barks.pop_front() if not _barks.is_empty() else ""
                if not _bark.is_empty():
                    _seen[str(_pending_keys.get(_bark,"tutorial:"+_bark))] = true
                    _pending_keys.erase(_bark)
                _bark_elapsed = 0.0
        return
    # Catch up finite scenes after a dropped frame without repeating one-shot commands.
    for limit: int in data.get("nodes", {}).size()+1:
        if remaining <= 0.000001 or not blocking: break
        var duration: float = _duration()
        var consumed: float = minf(remaining, maxf(0.0, duration-_elapsed))
        _elapsed += consumed
        remaining -= consumed
        if _elapsed >= duration-0.000001: _next()

func _duration() -> float:
    return maxf(0.01, float(data.get("nodes", {}).get(_node, {}).get("duration", 1.0)))

func advance() -> bool:
    if not blocking or _paused or _transporting or _elapsed < float(data.get("advance_min_seconds", 0.12)): return false
    _next()
    return true

func _next() -> void:
    if not blocking: return
    var next_id: String = str(data["nodes"][_node].get("next", "@explore"))
    if next_id == "@explore": _finish(false)
    elif next_id == "@narrative_dead": _finish(true)
    else: _enter(next_id)

func skip() -> bool:
    if not blocking or _paused or _transporting: return false
    # Skipping presentation cannot skip its required final state or duplicate a heal.
    _finish(_scene.begins_with("ending"))
    return true

func _finish(dead: bool) -> void:
    if _scene == "rescue":
        _emit_once("rescue_restore")
        _emit_once("boss_shock")
    blocking = false
    _node = ""
    _elapsed = 0.0
    if dead:
        chapter_complete = true
        ending_seen = true
        narrative_dead = true
        _terminal_elapsed = 0.0
        corruption = 1.0
        phase = "narrative_dead"
        _emit("narrative_death", {"chapter_complete":true, "replay":_replay})
        # Keep the completed chapter safe. No unlock back into an already won fight.
    else:
        phase = "explore"
        _emit("narrative_unlock", {"scene":_scene})

func replay_ending() -> bool:
    if not chapter_complete or blocking or _paused or _transporting: return false
    var scene: String = "ending_assisted" if not rescue_used and rescue_policy == "conditional" else "ending"
    if not _begin(scene): return false
    _replay = true
    return true

func dismiss_completed() -> bool:
    if not chapter_complete or not ending_seen or blocking or ending_dismissed or _paused or _transporting: return false
    ending_dismissed = true
    narrative_dead = false
    blocking = false
    _node = ""
    _scene = ""
    _elapsed = 0.0
    _terminal_elapsed = 0.0
    _barks.clear(); _pending_keys.clear(); _bark = ""; _bark_elapsed = 0.0
    phase = "explore"
    _emit("narrative_unlock", {"scene":"completed"})
    return true

func presentation() -> Dictionary:
    var item: Dictionary = data.get("nodes", {}).get(_node, {})
    var progress: float = clampf(_elapsed/_duration(), 0.0, 1.0) if blocking else 0.0
    var line_id: String = str(item.get("line", "")) if blocking else _bark
    if narrative_dead: line_id = "DEATH_NARRATIVE"
    var line: Dictionary = data.get("lines", {}).get(line_id, {})
    var black: Array = item.get("blackout", [0.0,0.0])
    var dizzy: Array = item.get("dizzy", [0.0,0.0])
    var faint: Array = item.get("faint", [0.0,0.0])
    return {"phase":phase, "scene_id":_scene, "progress":progress, "node_id":_node, "node_elapsed":_terminal_elapsed if narrative_dead else _elapsed, "death_elapsed":_terminal_elapsed,
        "blocking":blocking, "line_id":line_id, "line":str(line.get("text", "")), "speaker":str(line.get("speaker", "")),
        "eye_mood":"cold" if narrative_dead or ending_dismissed else str(item.get("eye_mood", "friendly")),
        "corruption":corruption, "blackout":1.0 if narrative_dead else lerpf(float(black[0]),float(black[1]),progress),
        "faint":1.0 if narrative_dead else lerpf(float(faint[0]),float(faint[1]),progress),
        "dizzy":lerpf(float(dizzy[0]),float(dizzy[1]),progress), "eye_closeup":bool(item.get("eye_closeup",false)),
        "bloodred":narrative_dead, "narrative_dead":narrative_dead, "chapter_complete":chapter_complete,
        "death_title":str(data.get("lines",{}).get("DEATH_NARRATIVE",{}).get("text","你死亡")),
        "thread_pull":false, "thread_pull_progress":0.0,
        "rescue_flare":bool(item.get("rescue_flare",false)), "rescue_flare_progress":sin(progress*PI) if bool(item.get("rescue_flare",false)) else 0.0,
        "body_controlled":false, "body_controlled_progress":0.0,
        "fusion_progress":0.0,
        "vessel_complete":false, "completion_label":"",
        "memory_fragment":"",
        "can_skip":blocking and not _paused and not _transporting, "replay":_replay, "ending_dismissed":ending_dismissed,
        "hint":str(data.get("controls",{}).get("continue_hint","")) if blocking else (str(data.get("controls",{}).get("replay_hint","")) if narrative_dead else ""),
        "kill_count":kill_count, "rescue_used":rescue_used}

func take_commands() -> Array[Dictionary]:
    var commands: Array[Dictionary] = _commands.duplicate(true)
    _commands.clear()
    return commands

func _emit(command: String, payload: Dictionary = {}) -> void:
    _commands.append({"command":command, "id":"%d:%s:%d" % [_run,command,_commands.size()], "data":payload.duplicate(true)})

func _emit_once(command: String) -> bool:
    if _once.has(command): return false
    _once[command] = true
    _emit(command)
    return true

func snapshot() -> Dictionary:
    return {"version":SNAPSHOT_VERSION, "chapter_id":str(data.get("chapter_id","")), "seen":_seen.duplicate(true),
        "kills":_kills.duplicate(true), "once_commands":_once.duplicate(true), "rescue_used":rescue_used,
        "chapter_complete":chapter_complete, "ending_seen":ending_seen, "ending_dismissed":ending_dismissed, "narrative_dead":narrative_dead,
        "rescue_policy":rescue_policy, "corruption":corruption, "in_boss":_in_boss, "death_elapsed":_terminal_elapsed,
        "cursor":{"node":_node, "elapsed":_elapsed, "scene":_scene, "run":_run, "blocking":blocking, "replay":_replay}}

func restore(saved: Dictionary) -> bool:
    if int(saved.get("version", -1)) != SNAPSHOT_VERSION or str(saved.get("chapter_id", "")) != str(data.get("chapter_id", "")): return false
    _commands.clear(); _barks.clear(); _pending_keys.clear(); _bark = ""; _bark_elapsed = 0.0
    _seen = _flags(saved.get("seen", {}))
    _kills = _flags(saved.get("kills", {}))
    _once = _flags(saved.get("once_commands", {}))
    kill_count = _kills.size()
    rescue_used = bool(saved.get("rescue_used", false))
    chapter_complete = bool(saved.get("chapter_complete", false))
    ending_seen = chapter_complete and bool(saved.get("ending_seen", false))
    ending_dismissed = chapter_complete and bool(saved.get("ending_dismissed", false))
    narrative_dead = chapter_complete and not ending_dismissed and bool(saved.get("narrative_dead", false))
    set_rescue_policy(str(saved.get("rescue_policy", data.get("rescue_policy", "conditional"))))
    corruption = 1.0 if chapter_complete else clampf(float(saved.get("corruption", kill_count*0.045)),0.0,float(data.get("corruption_before_boss_cap",0.62)))
    _in_boss = bool(saved.get("in_boss", false))
    _terminal_elapsed = maxf(0.0,float(saved.get("death_elapsed",0.0)))
    var cursor: Dictionary = saved.get("cursor", {}) if saved.get("cursor", {}) is Dictionary else {}
    _node = str(cursor.get("node", ""))
    blocking = bool(cursor.get("blocking", false)) and data.get("nodes", {}).has(_node)
    _elapsed = clampf(float(cursor.get("elapsed", 0.0)),0.0,_duration())
    _scene = str(cursor.get("scene", ""))
    _run = maxi(0,int(cursor.get("run",0)))
    _replay = bool(cursor.get("replay",false))
    phase = str(data["nodes"][_node].get("phase","explore")) if blocking else ("narrative_dead" if narrative_dead else "explore")
    if not blocking: _node = ""
    _paused = false; _transporting = false; _synchronized = false
    return true

func synchronize_commands() -> void:
    # A fresh root restores its own safety lock, not previously consumed reward commands.
    if _synchronized: return
    _synchronized = true
    if blocking or narrative_dead: _emit("narrative_lock", {"scene":_scene, "restored":true, "pause_music":true, "clear_attacks":true})

func prepare_retry() -> Dictionary:
    var saved: Dictionary = snapshot()
    saved["cursor"] = {"node":"", "elapsed":0.0, "scene":"", "run":_run, "blocking":false, "replay":false}
    if chapter_complete:
        saved["narrative_dead"] = not ending_dismissed
        saved["ending_seen"] = true
    return saved

func _flags(value: Variant) -> Dictionary:
    var result: Dictionary = {}
    if value is Dictionary:
        for key: Variant in value:
            if key is String and bool(value[key]): result[key] = true
    return result
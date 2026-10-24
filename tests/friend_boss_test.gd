extends SceneTree
## Source-derived algorithms exercised through the real main Boss. No playthrough.
const Parser = preload("res://combat/friend_rhythm/chart_parser.gd")
const Director = preload("res://combat/friend_rhythm/battle_director.gd")
const Slots = preload("res://combat/friend_rhythm/boss_move_slots.gd")
const Patterns = preload("res://combat/friend_rhythm/projectile_patterns.gd")
const Boss = preload("res://combat/boss.gd")
const Player = preload("res://actors/player.gd")
const Music = preload("res://audio/music_director.gd")

class Shot extends Node2D:
    var friendly: bool = false
    func clear() -> void:
        remove_from_group("projectiles")
        queue_free()

class Game extends Node2D:
    signal warning_issued(kind: String, at: Vector2, duration: float)
    signal animation_event(actor: Node, state: String, frame: int, facing: int)
    var player: Node2D
    var boss: Node2D
    var music: Node
    var story_safe: bool = false
    var _paused: bool = false
    var shots: Array[Dictionary] = []
    var defeats: int = 0
    var parries: int = 0
    func spawn_projectile(at: Vector2, velocity: Vector2, friendly: bool = false) -> Node2D:
        if story_safe:
            return null
        var shot := Shot.new()
        shot.position = at
        shot.friendly = friendly
        add_child(shot)
        shot.add_to_group("projectiles")
        shots.append({"position": at, "velocity": velocity})
        return shot
    func set_story_safe(value: bool) -> void:
        story_safe = value
        if value:
            for shot: Node in get_tree().get_nodes_in_group("projectiles"):
                shot.clear()
    func emit_fx(_kind: String, _at: Vector2, _direction: Vector2 = Vector2.ZERO, _power: float = 1.0) -> void:
        pass
    func announce(_text: String, _seconds: float = 3.0) -> void:
        pass
    func on_boss_phase(_phase: String) -> void:
        pass
    func on_boss_defeated() -> void:
        defeats += 1
    func damage_player(amount: int, at: Vector2) -> void:
        player.receive_hit(amount, at)
    func on_parry_contact(_defender: Node, _source: Node, _at: Vector2, _kind: String) -> void:
        parries += 1

var passed: int = 0
var failed: int = 0
var cancel_director: RefCounted

func _initialize() -> void:
    call_deferred("run")

func check(value: bool, label: String) -> void:
    if value:
        passed += 1
        print("PASS ", label)
    else:
        failed += 1
        push_error("FAIL " + label)

func cancel_on_group(event: Dictionary, _version: int) -> void:
    if event.type == "timing_group":
        cancel_director.invalidate()

func run() -> void:
    var watchdog := Timer.new()
    watchdog.one_shot = true
    watchdog.wait_time = 8.0
    root.add_child(watchdog)
    watchdog.timeout.connect(func() -> void: push_error("Friend Boss test exceeded bounded deadline"); quit(1))
    watchdog.start()
    var document: Dictionary = {"note": [{"beat": [0, 0, 1], "column": 0}, {"beat": [2, 0, 1], "column": 1}, {"beat": [2, 0, 1], "column": 2}, {"beat": [2, 0, 1], "column": 3}, {"beat": [2, 0, 2], "column": 0}, {"beat": [4, 0, 1], "column": 0}]}
    var parser = Parser.new()
    check(parser.parse_text(JSON.stringify(document), 112.0, 0.0, 4.0), "friend-derived parser reads an original synthetic chart")
    check(parser.timing_groups.size() == 4 and parser.heavy_groups.size() == 1, "exact beat triples and simultaneous note grouping retain source behavior")
    check(is_equal_approx(parser.beat_to_seconds(2.0), 120.0 / 112.0), "configured MusicDirector BPM determines cue times")
    var invalid = Parser.new()
    check(not invalid.parse_text('{"note":[{"beat":[1.5,0,1]}]}', 112.0), "nonintegral beat components are rejected instead of aliasing exact keys")
    var slots: Node = Slots.new()
    check(slots.load_config("res://data/boss_moves.json") and slots.slots.size() == 6, "all six actual friend slots load the provisional original mappings")
    var ids: Array[String] = []
    for b: int in [0, 2, 4, 6]:
        var chosen: Dictionary = slots.select_for_timing_group(0, b)
        ids.append(str(chosen.get("move_slot", "")))
    check(ids == ["move_1", "move_2", "move_3", "move_4"], "nonoverlapping beat bounds select all four normal slots")
    check(slots.request_slot("fixed_1", {}) and slots.request_slot("fixed_2", {}) and not slots.request_slot("missing", {}), "source explicit fixed-slot requests retain validity checks")
    slots.free()
    var director = Director.new()
    check(director.load_document(document, 112.0), "pure source-derived director builds its actual schedule")
    var events: Array[Dictionary] = []
    director.dispatched.connect(func(event: Dictionary, _version: int) -> void: events.append(event))
    var version: int = director.restart_at()
    director.advance_to(0.0, version)
    check(events.size() == 2 and events[0].type == "phase_started" and events[1].type == "timing_group", "same-time priority orders phase start before attack group")
    var count: int = events.size()
    director.advance_to(0.0, version)
    check(events.size() == count, "source cursor never dispatches the same cue twice")
    director.invalidate()
    director.advance_to(100.0, version)
    check(events.size() == count, "invalidated generation cannot release future cues")
    var new_version: int = director.restart_at(4.0 * 60.0 / 112.0)
    director.advance_to(4.0 * 60.0 / 112.0, new_version)
    check(events.size() == count + 2 and events[-2].type == "timing_group" and events[-1].type == "phase_ended", "restart skips past attacks and preserves attack-before-end priority")
    cancel_director = Director.new()
    cancel_director.load_document(document, 112.0)
    cancel_director.dispatched.connect(cancel_on_group)
    cancel_director.restart_at()
    cancel_director.advance_to(100.0)
    check(not cancel_director.running and cancel_director.current_chart_time == 100.0, "reentrant cancellation invalidates the in-flight schedule immediately")
    cancel_director = null
    var arena := Rect2(2660, 120, 670, 180)
    for kind: String in ["aimed", "spread", "radial", "rain"]:
        var vectors: Array[Dictionary] = Patterns.vectors(kind, {"count": 5, "speed": 118.0, "spread_degrees": 60.0}, Vector2(3000, 270), Vector2(2850, 286), arena)
        check(vectors.size() == 5 and is_equal_approx(Vector2(vectors[0].velocity).length(), 118.0), "friend %s primitive creates actual bounded vectors" % kind)
    check(Patterns.vectors("spread", {"count": 999}, Vector2.ZERO, Vector2.RIGHT, arena).size() == 48 and Patterns.vectors("unknown", {}, Vector2.ZERO, Vector2.RIGHT, arena).is_empty(), "unknown patterns do not fake attacks and counts have an explicit cap")

    for action: String in ["move_left", "move_right", "jump", "dash", "attack", "parry"]:
        if not InputMap.has_action(action):
            InputMap.add_action(action)
    var game := Game.new()
    game.hide()
    root.add_child(game)
    game.player = Player.new()
    game.player.configure(game)
    game.add_child(game.player)
    game.player.position = Vector2(2850, 300)
    game.player.set_physics_process(false)
    game.music = Music.new()
    game.add_child(game.music)
    game.music.configure(game)
    game.music.set_process(false)
    game.boss = Boss.new()
    game.add_child(game.boss)
    game.boss.configure(game, Vector2(3000, 300))
    game.boss.set_physics_process(false)
    game.boss.start_encounter()
    game.music.stop_score()
    game.boss._recovery_timer = 0.0
    game.boss._on_beat(0)
    check(game.boss.friend_last_slot == "fixed_1" and game.boss._pending_attack == "slash", "main Boss opening is selected by the friend director and fixed slot")
    game.boss._release_attack()
    var pose: Dictionary = game.boss.get_presentation_pose()
    check(pose.state == "cut_a" and pose.progress == 0.0 and pose.strike == 1 and pose.contact_serial == game.boss.contact_token, "first active pose exposes the real already-extended contact frame")
    game.boss.set_impact_freeze(0.06)
    game.boss._physics_process(0.02)
    check(game.boss.get_presentation_pose() == pose, "local impact hold freezes actual pose progress without a new visual clock")
    game.boss.combat_freeze = 0.0
    game.boss._physics_process(0.11)
    check(game.boss.get_presentation_pose().state == "recover", "actual release clock separates the recovery pose from the contact pose")
    game.boss._cancel_all_attacks()
    game.boss._on_beat(2)
    check(game.boss.friend_last_slot == "fixed_2" and game.boss._pending_attack == "spread", "next fixed cue alternates to the second real slot")
    var shots_before: int = game.shots.size()
    game.boss._release_attack()
    check(game.shots.size() == shots_before + 5, "friend spread primitive is used by the real main Boss projectile release")
    check(game.boss.friend_trace.size() >= 2 and game.boss.friend_trace[0].pattern != game.boss.friend_trace[1].pattern, "fixed cue rhythm does not repeat the same attack consecutively")
    game.boss._on_section("random")
    var patterns: Array[String] = []
    for b: int in [0, 2, 4, 6]:
        game.boss._cancel_all_attacks()
        game.boss._recovery_timer = 0.0
        game.boss._on_beat(b)
        patterns.append(game.boss._pending_attack)
        if b >= 4:
            game.boss._release_attack()
    check(patterns == ["armored_slash", "charge", "radial", "rain"], "friend normal-slot selection drives all four actual main Boss actions")
    check(game.shots.size() > shots_before + 10, "main Boss radial and rain releases also flow through friend geometry")
    var old_version: int = game.boss.friend_director.generation
    game.boss._cancel_all_attacks()
    var serial: int = game.boss.attack_serial
    game.boss._on_friend_slot(game.boss._friend_slots.slots["fixed_1"], {"generation": old_version})
    check(game.boss.attack_serial == serial and not game.boss.friend_director.running, "canceled old slot context cannot start an attack")

    game.boss._hurt_timer = 0.0
    game.boss._begin_attack("slash")
    game.boss.receive_hit(1, game.player.position)
    check(game.boss._hurt_timer > 0.0 and game.boss.get_presentation_pose().state == "draw", "ordinary hit cannot hide a mechanically uninterrupted draw behind a hurt pose")
    game.boss._release_attack()
    check(game.boss.get_presentation_pose().state == "cut_a" and game.boss.get_presentation_pose().progress == 0.0, "real release pose remains extended even during ordinary hurt flash")
    game.boss._cancel_all_attacks()
    game.boss._begin_attack("rain", {"count": 9, "speed": 140.0, "safe_lane_half_width": 35.0})
    var warning: Dictionary = game.boss.get_warning_geometry("rain")
    check(not warning.is_empty() and warning.columns.size() == warning.shots.size() and game.boss.get_warning_geometry("spread").is_empty(), "warning getter exposes the actual configured rain columns only")
    var saved_columns: Array = warning.columns.duplicate()
    warning.columns.append(-999.0)
    check(game.boss.get_warning_geometry("rain").columns == saved_columns, "warning geometry snapshots cannot mutate the attack cache")
    game.player.position.x += 200.0
    shots_before = game.shots.size()
    game.boss._release_attack()
    var release_matches: bool = game.shots.size() == shots_before + saved_columns.size()
    var locked: Dictionary = game.boss.get_warning_geometry("rain")
    for i: int in saved_columns.size():
        release_matches = release_matches and game.shots[shots_before + i].position == locked.shots[i].position and game.shots[shots_before + i].velocity == locked.shots[i].velocity
    check(release_matches, "moving player after warning never shifts the actual released rain columns or vectors")
    game.boss._cancel_all_attacks()
    check(game.boss.get_warning_geometry("rain").is_empty(), "cancel invalidates cached warning geometry with the old attack")

    game.boss._on_section("final")
    game.boss._recovery_timer = 0.0
    game.player.revive(Vector2(2960, 300))
    game.player.facing = 1
    game.player.invuln = 0.0
    check(game.player._start_parry(), "existing genuine player contact window opens")
    game.boss._begin_attack("slash")
    game.boss._release_attack()
    check(game.parries == 1 and game.boss.guard_posture == 1 and game.boss.get_presentation_pose().state == "parry_recoil", "existing contact parry and posture survive the friend integration")
    game.boss._clear_reaction()
    game.boss.guard_posture = 0
    game.player.revive(Vector2(2850, 300))
    game.boss.health = game.boss.max_health
    game.boss._phase_requested = false
    game.music.start_score()
    game.music.stop_score()
    for _i: int in 8:
        game.music.advance_beat()
    for _i: int in 16:
        game.music.advance_beat()
    check(game.music.current_section == "random" and not game.music.is_advance_queued(), "existing random section loops a complete phrase without its health threshold")
    game.boss._hurt_timer = 0.0
    game.boss.receive_hit(999, game.player.position)
    check(game.boss.health == 24 and game.music.is_advance_queued() and not game.boss.dead, "existing health seal queues the next phrase instead of bypassing rest")
    game.boss._begin_attack("armored_slash")
    game.boss._release_attack()
    for _i: int in 15:
        game.music.advance_beat()
    check(game.music.current_section == "random", "friend cues do not advance the musical phase early")
    old_version = game.boss.friend_director.generation
    game.music.advance_beat()
    check(game.story_safe and game.music.current_section == "rest" and not game.boss.friend_director.running and not game.boss._combo_pending, "rest atomically invalidates friend cues and armored follow-ups")
    var hp: int = game.player.health
    game.boss._hurt_timer = 0.0
    game.player.invuln = 0.0
    game.boss.receive_hit(2, game.player.position)
    game.player.receive_hit(2, game.boss.position)
    game.boss.friend_director.advance_to(100.0, old_version)
    check(game.player.health == hp and game.boss.health == 24 and get_nodes_in_group("projectiles").is_empty(), "rest keeps both sides safe and clears all old root projectiles")
    for _i: int in 8:
        game.music.advance_beat()
    check(game.music.current_section == "final" and not game.story_safe, "final phase still begins on the rest phrase boundary")
    game.boss._hurt_timer = 0.0
    game.boss.receive_hit(999, game.player.position)
    check(game.boss.dead and game.defeats == 1 and not game.boss.friend_director.running and game.boss.get_presentation_pose().state == "dead", "defeat invalidates future friend cues and exposes the real death pose")
    game.free()
    watchdog.stop()
    watchdog.queue_free()
    await process_frame
    print("Friend Boss: %d passed, %d failed" % [passed, failed])
    quit(1 if failed > 0 else 0)

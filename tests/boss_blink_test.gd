extends SceneTree
const Boss = preload("res://combat/boss.gd")
const Player = preload("res://actors/player.gd")
const Music = preload("res://audio/music_director.gd")
const Hazard = preload("res://combat/boss_hazard.gd")
class Shot extends Node2D:
    var lifetime: float = 2.0
class Game extends Node2D:
    signal warning_issued(kind: String, at: Vector2, duration: float)
    signal animation_event(actor: Node, state: String, frame: int, facing: int)
    var player: Node2D
    var boss: Node2D
    var music: Node
    var story_safe: bool = false
    var _paused: bool = false
    var outcome: String = ""
    var contacts: int = 0
    var parry_tokens: Array[int] = []
    var active_at_parry: Array[int] = []
    var shots: int = 0
    var hints: int = 0
    func announce(_text: String, _seconds: float = 3.0) -> void: hints += 1
    func emit_fx(_kind: String, _at: Vector2, _direction: Vector2 = Vector2.ZERO, _power: float = 1.0) -> void: pass
    func on_boss_phase(section: String) -> void:
        if section == "random": music.request_advance()
    func on_boss_defeated() -> void: pass
    func hero_attack(_source: Node2D, _damage: int, _reach: float, _combo: int) -> void: pass
    func damage_player(amount: int, at: Vector2) -> void: player.receive_hit(amount, at)
    func on_parry_contact(defender: Node, source: Node, _at: Vector2, _kind: String) -> void:
        contacts += 1
        parry_tokens.append(int(source.contact_token))
        if bool(source.get_blade_state()["active"]): active_at_parry.append(int(source.contact_token))
        defender.set_impact_freeze(0.06)
        source.set_impact_freeze(0.06)
    func set_story_safe(value: bool) -> void:
        story_safe = value
        if value: clear_boss_hazards()
    func clear_boss_hazards() -> void:
        for hazard: Node in get_tree().get_nodes_in_group("boss_hazards"): hazard.clear()
    func spawn_boss_hazard(hazard: Node2D) -> bool:
        add_child(hazard)
        hazard.set_physics_process(false)
        return true
    func spawn_projectile(_at: Vector2, _motion: Vector2, _friendly: bool = false, _style: String = "default") -> Node2D:
        var shot: Node2D = Shot.new()
        add_child(shot)
        shots += 1
        return shot
var passed: int = 0
var failed: int = 0
func _initialize() -> void: call_deferred("run")
func check(value: bool, label: String) -> void:
    if value:
        passed += 1
        print("PASS ", label)
    else:
        failed += 1
        push_error("FAIL " + label)
func body(game: Node, at: Vector2, size: Vector2) -> StaticBody2D:
    var node := StaticBody2D.new()
    node.position = at
    var shape := CollisionShape2D.new()
    var rectangle := RectangleShape2D.new()
    rectangle.size = size
    shape.shape = rectangle
    node.add_child(shape)
    game.add_child(node)
    return node
func run() -> void:
    var game := Game.new()
    game.visible = false
    root.add_child(game)
    body(game, Vector2(3000, 310), Vector2(1000, 20))
    game.player = Player.new()
    game.player.configure(game)
    game.add_child(game.player)
    game.player.set_physics_process(false)
    game.music = Music.new()
    game.add_child(game.music)
    game.music.configure(game, "res://data/full_song_timeline.json")
    game.music._dummy = true
    game.music.set_process(false)
    game.boss = Boss.new()
    game.add_child(game.boss)
    game.boss.configure(game, Vector2(2900, 300))
    game.boss.set_duel_enabled(false)
    game.boss.set_physics_process(false)
    game.player.revive(Vector2(3000, 300))
    game.player.facing = 1
    game.boss._active = true
    game.music.start_score()
    await physics_frame
    # The shipped profile keeps the user-confirmed 265.073-302.905s audio window.
    # The reference chart's only teleport phrase inside that window (276.009s) is
    # covered by concurrent laser formations, so this fixed-arena legacy fixture
    # rebases to a chart-valid teleport phrase. The infinite-room main flow never
    # enables blink, and the profile bytes themselves stay untouched.
    var window: Dictionary = {"start_seconds": 200.0, "end_seconds": 240.0}
    game.boss.blink_profile["climax_windows"] = [window]
    check(not game.boss._try_start_blink(), "non-climax never starts the confirmed climax skill")
    check(game.boss.blink_profile["window_status"] == "user_confirmed", "only the user-confirmed window is enabled")
    check(game.boss.blink_profile["climax_windows"].size() == 1, "secondary candidate is not enabled")
    check(float(window["start_seconds"]) == 200.0 and float(window["end_seconds"]) == 240.0, "fixture uses a chart-valid window with a fair teleport phrase")
    game.boss._active = false
    game.music._process(float(window["start_seconds"]) - 4.0)
    game.boss._active = true
    game.boss._on_transport_changed(game.music.get_transport_generation(), game.music.get_chart_time())
    game.player.invuln = 10000.0
    var epoch: int = game.music.get_transport_generation()
    var source_generation: int = game.boss.friend_director.generation
    var hazard_generation: int = game.boss.hazard_generation
    var phases: Array[Dictionary] = []
    var previous_phase: String = ""
    var first_start: float = -1.0
    var reveal_at: float = -1.0
    var release_at: float = -1.0
    var scheduled_release: float = -1.0
    var target: Vector2 = Vector2.ZERO
    var hint_count: int = game.hints
    var saw_hidden: bool = false
    var reveal_safe: bool = true
    var source_tokens: Array[int] = []
    var first_active: bool = false
    var first_parry_armored: bool = false
    var shots_before: int = game.shots
    for frame: int in 2700:
        game.music._process(1.0 / 60.0)
        game.boss._physics_process(1.0 / 60.0)
        for live: Node in get_nodes_in_group("boss_hazards"): live._physics_process(1.0 / 60.0)
        var status: Dictionary = game.boss.get_blink_status()
        var phase: String = str(status["phase"])
        if phase != previous_phase:
            phases.append({"time": game.music.get_chart_time(), "phase": phase, "reason": status["reason"], "scheduled_cut": status["cut_chart"]})
            previous_phase = phase
        if game.boss.blink_starts > 0 and first_start < 0.0:
            first_start = game.music.get_chart_time()
            target = status["landing"]
            scheduled_release = status["cut_chart"]
        if phase == "vanish" and game.boss.modulate.a == 0.0: saw_hidden = true
        if phase == "reveal":
            if reveal_at < 0.0: reveal_at = game.music.get_chart_time()
            reveal_safe = reveal_safe and not bool(game.boss.get_blade_state()["active"])
            if float(game.music.get_score_time()) >= game.boss._blink_cut_score - 0.10 and game.player.parry_timer <= 0.0:
                game.player._start_parry()
        if int(status["source_completed_token"]) >= 0 and release_at < 0.0:
            release_at = game.music.get_chart_time()
            source_tokens.append(int(status["source_completed_token"]))
            var steel: Dictionary = game.boss.get_blade_state()
            first_active = int(status["source_completed_token"]) in game.active_at_parry
            first_parry_armored = game.boss.guard_posture > 0 and game.boss.reaction_state == "parry_recoil" and not game.boss._reaction_blocks_attacks
        if game.music.get_chart_time() > float(window["end_seconds"]): break
    var report: Dictionary = {"window_status": "user_confirmed", "window": window, "actual_start_source": first_start, "actual_reveal_source": reveal_at, "actual_release_source": release_at, "scheduled_release_source": scheduled_release, "release_error_ms": (release_at - scheduled_release) * 1000.0, "phases": phases, "parry_tokens": game.parry_tokens, "source_tokens": source_tokens, "starts": game.boss.blink_starts, "completed": game.boss.blink_completed, "cancelled": game.boss.blink_cancelled, "source_shots": game.shots - shots_before, "limitations": "Deterministic Dummy clock and actual source schedule; no device-listening or human playthrough. Boss can be defeated before this late-song window."}
    var output := FileAccess.open("res://artifacts/boss-blink-window-scan.json", FileAccess.WRITE)
    output.store_string(JSON.stringify(report, "  "))
    output.close()
    print("BLINK_REAL_SOURCE ", JSON.stringify(report))
    check(first_start >= float(window["start_seconds"]) and first_start <= float(window["end_seconds"]), "actual source schedule starts climax preparation")
    check(saw_hidden, "source teleport includes a real brief disappearance")
    check(reveal_at > first_start + 0.32, "identifiable anticipation precedes reveal")
    check(target.x > game.player.position.x + 30.0 and absf(target.y - 300.0) < 1.0, "reveal point is on the locked hero-facing side with floor support")
    check(reveal_safe, "reveal has no active blade")
    check(release_at - reveal_at >= 0.28, "revealed player reaction time is at least280ms")
    check(release_at >= scheduled_release and release_at - scheduled_release <= 1.0 / 60.0 + 0.001, "actual source blade releases on its original beat within one frame")
    var accepted: bool = false
    for token: int in source_tokens:
        if token in game.parry_tokens: accepted = true
    check(accepted, "real steel contact accepts a real Shift parry for the climax release")
    check(first_active, "release enters the actual active blade frame rather than another windup")
    check(first_parry_armored, "climax steel remains parryable armor and accumulates the existing posture")
    check(game.boss.blink_completed == 1 and game.boss.blink_starts == 1, "confirmed window is consumed once by a successful source release")
    check(game.hints > hint_count, "first climax preparation explains the contact parry")
    check(game.shots > shots_before, "independent original source projectiles keep emitting")
    check(game.music.get_transport_generation() == epoch and game.boss.friend_director.generation == source_generation and game.boss.hazard_generation == hazard_generation, "blink does not reset the music or independent cue generations")
    check(game.boss.modulate.a == 1.0, "skill restores full visibility")
    var wall: StaticBody2D = body(game, Vector2(3080, 240), Vector2(120, 120))
    await physics_frame
    check(not game.boss._blink_place_clear(Vector2(3072, 300)), "solid wall rejects the front landing")
    wall.queue_free()
    await physics_frame
    check(not game.boss._blink_place_clear(game.player.position), "hero occupancy rejects overlap")
    game.boss._blink_source_owned = true
    game.boss._set_blink_phase("vanish", 0.08)
    game.boss.modulate.a = 0.0
    game._paused = true
    game.boss._physics_process(0.5)
    check(game.boss._blink_elapsed == 0.0, "pause freezes disappearance without another clock")
    game._paused = false
    game.story_safe = true
    game.boss._on_section("rest")
    check(game.boss.get_blink_status()["phase"] == "" and game.boss.modulate.a == 1.0 and not game.boss.get_blade_state()["active"], "rest restores visibility and clears all pending contact")
    game.music.stop_score()
    game.queue_free()
    await process_frame
    await process_frame
    print("BOSS BLINK: %d passed, %d failed" % [passed, failed])
    quit(1 if failed > 0 else 0)

extends SceneTree
const Boss = preload("res://combat/boss.gd")
const Music = preload("res://audio/music_director.gd")
const Trace = preload("res://audio/combat_timing_trace.gd")
const DT: float = 1.0 / 60.0
class Clock extends Node:
    signal beat(index: int)
    signal section_changed(section: String)
    var bpm: float = 203.0
    var total_beats: int = 0
    var running: bool = true
    var advance_health_ratio: float = 0.5
    var timeline: Dictionary = {"stale_action_seconds": 0.2}
    var time: float = 0.0
    var label: String = ""
    var generation: int = 0
    var trace: RefCounted = Trace.new()
    func seconds_per_beat() -> float: return 60.0 / bpm
    func get_score_time() -> float: return time
    func get_transport_generation() -> int: return generation
    func record_combat_timing(kind: String, scheduled: float, actual: float, context: Dictionary = {}) -> void:
        context["case"] = label
        context["generation"] = generation
        trace.record(kind, scheduled, actual, context)
class Target extends Node2D:
    var health: int = 999
    var dead: bool = false
    var parry_timer: float = 0.0
class Shot extends Node2D:
    var lifetime: float = 2.0
class Game extends Node2D:
    signal warning_issued(kind: String, at: Vector2, duration: float)
    signal animation_event(actor: Node, state: String, frame: int, facing: int)
    var player: Node2D
    var music: Node
    var boss: Node2D
    var story_safe: bool = false
    var _paused: bool = false
    var outcome: String = ""
    var shots: int = 0
    func announce(_text: String, _seconds: float = 3.0) -> void: pass
    func emit_fx(_kind: String, _at: Vector2, _direction: Vector2 = Vector2.ZERO, _power: float = 1.0) -> void: pass
    func on_boss_phase(_phase: String) -> void: pass
    func clear_boss_hazards() -> void: pass
    func damage_player(amount: int, _at: Vector2) -> void: player.health -= amount
    func spawn_projectile(_at: Vector2, _velocity: Vector2, _friendly: bool = false, _style: String = "default") -> Node2D:
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
func run() -> void:
    var game := Game.new()
    game.visible = false
    root.add_child(game)
    var floor_body := StaticBody2D.new()
    floor_body.position = Vector2(3000, 310)
    var floor_collision := CollisionShape2D.new()
    var floor_rect := RectangleShape2D.new()
    floor_rect.size = Vector2(1000, 20)
    floor_collision.shape = floor_rect
    floor_body.add_child(floor_collision)
    game.add_child(floor_body)
    game.music = Clock.new()
    game.add_child(game.music)
    game.player = Target.new()
    game.add_child(game.player)
    game.player.position = Vector2(3300, 300)
    game.boss = Boss.new()
    game.add_child(game.boss)
    game.boss.configure(game, Vector2(3000, 300))
    game.boss.set_physics_process(false)
    game.boss.set_duel_enabled(false)
    game.boss._active = true
    await physics_frame
    var profiles: Array[Dictionary] = []
    var analytic_before: Dictionary = {}
    for index: int in 4:
        profiles.append(game.boss.friend_slots.get_normal_pattern(index))
    for index: int in 4:
        var profile: Dictionary = game.boss.friend_slots.get_fast_pattern(index)
        profile["pattern_id"] = "fast_%d" % (index + 1)
        profiles.append(profile)
    var release_windows: int = 0
    for profile: Dictionary in profiles:
        game.music.time = 0.0
        game.music.generation += 1
        game.music.label = str(profile["pattern_id"])
        game.boss._cancel_all_attacks()
        game.boss._clear_reaction()
        game.boss.combat_freeze = 0.0
        game.boss._posture_lockout = 0.0
        game.boss._authored_cycle = 0
        game.boss.phase = "fixed"
        game.boss.position = Vector2(3000, 300)
        game.boss.velocity = Vector2.ZERO
        game.boss._begin_authored_pattern(profile, 0.0, game.player.position)
        var actions: Array = (profile.get("parameters", {}) as Dictionary).get("actions", profile.get("actions", []))
        var before_delays: Array[float] = []
        for action: Dictionary in actions:
            if str(action["type"]) == "dash":
                release_windows += 1
                before_delays.append(float(action.get("duration_beats", 1.0)) * game.music.seconds_per_beat() * 0.25 * 1000.0)
        analytic_before[game.music.label] = before_delays
        for frame: int in int(ceil((4.0 * game.music.seconds_per_beat() + 0.35) / DT)):
            game.music.time = float(frame) * DT
            game.boss._physics_process(DT)
    var summary: Dictionary = game.music.trace.summary()
    check(summary.get("source_action", {}).get("count", 0) == 31, "eight friend profiles dispatch all31 source actions exactly once")
    check(game.shots == 101 and summary.get("projectile_birth", {}).get("count", 0) == 101, "all101 expected profile projectiles are born and traced")
    check(summary.get("blade_active", {}).get("count", 0) == release_windows, "each scheduled source dash records its first effective steel frame")
    for kind: String in ["source_action", "projectile_birth", "blade_active"]:
        var values: Dictionary = summary.get(kind, {})
        check(not values.is_empty() and float(values.get("min_ms", -1.0)) >= -0.01 and float(values.get("max_ms", 9999.0)) <= DT * 1000.0 + 0.01, "%s stays within one virtual60Hz frame, without a second windup" % kind)
    game.music.time = 0.0
    game.boss._cancel_all_attacks()
    game.boss._begin_authored_pattern(profiles[0], 0.0, game.player.position)
    var scheduled_dash: float = game.music.seconds_per_beat() * 2.0
    game.boss._update_source_anticipation(scheduled_dash - 0.04)
    check(not game.boss._source_anticipation.is_empty() and float(game.boss._source_anticipation["progress"]) < 0.25, "source cut preparation is placed before release and remains outside the hit window")
    check(is_equal_approx(Music.compensated_audio_position(1.0, 0.005, 0.030, 20.0), 0.955), "device adjustment subtracts extra output latency once")
    check(is_equal_approx(Music.compensated_audio_position(1.0, 0.005, 0.030, 0.0), 0.975), "default-zero calibration preserves the existing audio compensation")
    var source_config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/full_song_timeline.json"))
    check(source_config["bpm"] == 203.0 and source_config["offset_ms"] == 245.0, "source tempo and signed245ms chart offset are unchanged")
    var report: Dictionary = {"backend": "virtual_clock_fixture", "frame_seconds": DT, "analytic_previous_second_windup_ms": analytic_before, "after_summary": summary, "events": game.music.trace.events.duplicate(true), "limits": "The previous delay is derived from the old manifest25% startup. After values are measured actual Boss dispatch/steel/sample and spawn calls at virtual60Hz. No physical output/listening latency was measured."}
    var output: FileAccess = FileAccess.open("res://artifacts/combat-timing-report.json", FileAccess.WRITE)
    output.store_string(JSON.stringify(report, "  "))
    output.close()
    print(JSON.stringify(summary))
    game.queue_free()
    await process_frame
    await process_frame
    print("COMBAT TIMING: %d passed, %d failed" % [passed, failed])
    quit(1 if failed > 0 else 0)

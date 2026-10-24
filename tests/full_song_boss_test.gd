extends SceneTree
const Boss = preload("res://combat/boss.gd")
const Player = preload("res://actors/player.gd")
const Music = preload("res://audio/music_director.gd")
const Projectile = preload("res://combat/projectile.gd")
const Hazard = preload("res://combat/boss_hazard.gd")
class Game extends Node2D:
    signal warning_issued(kind: String, at: Vector2, duration: float)
    signal animation_event(actor: Node, state: String, frame: int, facing: int)
    var music: Node
    var boss: Node2D
    var player: Node2D
    var story_safe: bool = false
    var _paused: bool = false
    var outcome: String = ""
    var defeats: int = 0
    var shots: int = 0
    func announce(_text: String, _seconds: float = 3.0) -> void: pass
    func emit_fx(_kind: String, _at: Vector2, _direction: Vector2 = Vector2.ZERO, _power: float = 1.0) -> void: pass
    func on_boss_phase(_phase: String) -> void: pass
    func hero_attack(_source: Node2D, _damage: int, _reach: float, _combo: int) -> void: pass
    func on_boss_defeated() -> void: defeats += 1
    func damage_player(amount: int, at: Vector2) -> void: player.receive_hit(amount, at)
    func spawn_projectile(at: Vector2, velocity: Vector2, friendly: bool = false, style: String = "default") -> Node2D:
        if story_safe or get_tree().get_nodes_in_group("projectiles").size() >= 180:
            return null
        var shot: Node2D = Projectile.new()
        shot.configure(self, at, velocity, friendly, style)
        add_child(shot)
        shot.set_physics_process(false)
        shots += 1
        return shot
    func spawn_boss_hazard(hazard: Node2D) -> bool:
        if story_safe or get_tree().get_nodes_in_group("boss_hazards").size() >= 24:
            hazard.queue_free()
            return false
        add_child(hazard)
        hazard.set_physics_process(false)
        return true
    func clear_boss_hazards() -> void:
        for hazard: Node in get_tree().get_nodes_in_group("boss_hazards"):
            hazard.clear()
    func set_story_safe(value: bool) -> void:
        story_safe = value
        if value:
            clear_boss_hazards()
            for shot: Node in get_tree().get_nodes_in_group("projectiles"):
                shot.clear()
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
func step(game: Game, seconds: float) -> void:
    game.music._process(seconds)
    game.boss._physics_process(0.0)
func run() -> void:
    var game := Game.new()
    game.visible = false
    root.add_child(game)
    game.player = Player.new()
    game.player.configure(game)
    game.add_child(game.player)
    game.player.revive(Vector2(3270, 300))
    game.player.invuln = 10000.0
    game.player.set_physics_process(false)
    game.music = Music.new()
    game.add_child(game.music)
    game.music.configure(game, "res://data/full_song_timeline.json")
    game.music._dummy = true
    game.music.set_process(false)
    game.boss = Boss.new()
    game.add_child(game.boss)
    game.boss.configure(game, Vector2(2900, 300))
    game.boss.set_physics_process(false)
    game.boss.start_encounter()
    check(game.music.is_full_song() and game.boss.friend_director.chart.action_phrases.size() == 228, "actual main Boss loads complete source director")
    check(game.boss.get_authored_status()["full_song"] and game.boss.authored_pattern_count == 0, "audio start does not dispatch an invented beat0 attack")
    var first: Dictionary = game.boss.friend_director.chart.action_phrases[0]
    var first_time: float = float(first["start_time"])
    step(game, first_time - 0.001)
    check(game.boss.authored_pattern_count == 0, "complete first source phrase waits until its actual offset timestamp")
    step(game, 0.002)
    check(game.boss.authored_pattern_count == 1 and is_equal_approx(game.boss._loop_origin_score, 0.0), "first source phrase dispatches once with245ms applied exactly once")
    check(game.boss.authored_last_pattern == str(game.boss.friend_slots.get_normal_pattern(int(first["sequence_index"]))["pattern_id"]), "source basic phrase chooses normal pool even in full fixed macro")
    var count: int = game.boss.authored_pattern_count
    game.boss._dispatch_full_chart()
    game.boss._dispatch_full_chart()
    check(game.boss.authored_pattern_count == count, "same source sample cannot dispatch duplicate cue")
    var fast: Dictionary = {}
    for phrase: Dictionary in game.boss.friend_director.chart.action_phrases:
        if str(phrase["mode"]) == "fast":
            fast = phrase
            break
    step(game, float(fast["start_time"]) - game.music.get_chart_time() + 0.001)
    check(game.boss.authored_last_pattern.begins_with("fast_"), "source fast phrase selects fast pool before final macro")
    check(game.boss.authored_skipped_actions > 0 and game.boss._authored_actions.size() < 96, "long frames record old logical cue skips without filling the current queue")
    check(game.shots < 80, "long-frame catch-up cannot unleash all previous physical barrages")
    # A future-danger line with an already-started warning must survive a frame
    # gap; expired lines must not appear without their warning.
    var now: float = game.music.get_chart_time()
    var sample: Dictionary = {"index": 999, "pattern": "grid", "occurrence": 0, "start_time": now - 0.3, "active_until": now + 1.7, "lasers": []}
    for i: int in 4:
        sample["lasers"].append({"time": now - 0.3, "damage_time": now + 1.0, "source_index": i})
    game.boss._spawn_authored_formation(sample)
    check(not get_nodes_in_group("boss_hazards").is_empty(), "stale warning with future damage keeps its live hazard geometry")
    var count_before_short: int = get_nodes_in_group("boss_hazards").size()
    var short_warning: Dictionary = {"index": 1000, "pattern": "rotating", "occurrence": 0, "start_time": now - 0.004179, "active_until": now + 0.843604, "lasers": [{"time": now - 0.004179, "damage_time": now + 0.143604, "source_index": 0}]}
    game.boss._spawn_authored_formation(short_warning)
    check(get_nodes_in_group("boss_hazards").size() == count_before_short + 1, "normal cadence preserves a source147ms laser warning instead of applying stale150ms minimum")
    var old: Node2D = get_nodes_in_group("boss_hazards")[-1]
    # Full-song parry is local to melee. Independent song hazards and queued
    # projectiles must continue, even through the actor's reaction/freeze.
    var director_before_contact: int = game.boss.friend_director.generation
    var hazard_before_contact: int = game.boss.hazard_generation
    var live_before_contact: int = get_nodes_in_group("boss_hazards").size()
    var contact_serial: int = game.boss.attack_serial
    game.boss.contact_token = contact_serial * 8 + 1
    var queued_ring: Dictionary = {"type": "ring", "time": game.music.get_score_time(), "source_serial": contact_serial, "source_pattern": "fast_4", "source_index": 99, "source_locked_target": game.player.global_position, "generation": hazard_before_contact, "count": 3, "speed": 100.0, "ttl_seconds": 1.0}
    var queued_dash: Dictionary = queued_ring.duplicate(true)
    queued_dash["type"] = "dash"
    queued_dash["source_index"] = 98
    game.boss._authored_actions.append(queued_ring)
    game.boss._authored_actions.append(queued_dash)
    game.boss._cancel_contact_sequence()
    check(game.boss.friend_director.generation == director_before_contact and game.boss.hazard_generation == hazard_before_contact, "full-song contact cancel preserves director and independent-hazard generations")
    check(not old._cleared and get_nodes_in_group("boss_hazards").size() == live_before_contact, "ordinary contact cancel cannot clear an existing independent source laser")
    var kept_ring: bool = false
    var kept_dash: bool = false
    for action: Dictionary in game.boss._authored_actions:
        kept_ring = kept_ring or int(action["source_index"]) == 99
        kept_dash = kept_dash or int(action["source_index"]) == 98
    check(kept_ring and not kept_dash, "same-serial ring survives while the canceled melee dash is removed")
    # Place the due ring first; the usual source queue uses time/serial sorting.
    game.boss._authored_actions.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["time"]) < float(b["time"]))
    var shots_before_hold: int = game.shots
    game.boss._start_reaction("parry_recoil", 0.12, true)
    game.boss.combat_freeze = 0.06
    game.boss._physics_process(0.0)
    game.boss._on_authored_event({"type": "laser_formation", "payload": short_warning}, game.boss.friend_director.generation)
    check(game.shots == shots_before_hold + 3 and get_nodes_in_group("boss_hazards").size() == live_before_contact + 1, "reaction and local hold still dispatch the independent ring and source laser")
    game.boss.combat_freeze = 0.0
    game.boss._clear_reaction()
    var old_version: int = game.boss.friend_director.generation
    var before_score: float = game.music.get_score_time()
    var initial_generation: int = game.music.get_transport_generation()
    step(game, game.music._transport.random_end - game.music.get_chart_time() + 0.01)
    check(game.music.get_transport_generation() == initial_generation + 1 and old._cleared, "random replay creates an epoch and clears old hazard immediately")
    check(game.music.get_score_time() > before_score and game.music.get_chart_time() < game.music._transport.random_end, "Boss runtime remains monotonic while source jumps backward")
    check(is_equal_approx(game.boss._loop_origin_score, game.music.get_score_time() - game.music.get_chart_time()), "new source epoch uses exact score-minus-chart anchor")
    count = game.boss.authored_pattern_count
    game.boss.friend_director.advance_to(400.0, old_version)
    check(game.boss.authored_pattern_count == count, "old director generation cannot spawn a source plan after seek")
    var loop_length: float = game.music._transport.random_end - game.music._transport.random_start
    for i: int in 2:
        before_score = game.music.get_score_time()
        step(game, loop_length)
        check(game.music.get_score_time() > before_score and is_equal_approx(game.boss._loop_origin_score, game.music.get_score_time() - game.music.get_chart_time()), "repeat epoch%d keeps every Boss plan anchor unwrapped" % i)
    game.boss.health = 24
    game.boss._request_phase_if_ready()
    check(game.music.is_advance_queued(), "actual sealed HP threshold queues full-song gate")
    step(game, game.music._transport.random_end - game.music.get_chart_time() + 0.01)
    check(game.story_safe and game.boss.phase == "rest" and game.boss._authored_actions.is_empty(), "source quiet rest disables battle and clears pending real plans")
    var hp: int = game.boss.health
    game.boss._hurt_timer = 0.0
    game.boss.receive_hit(9, game.player.global_position)
    game.player.invuln = 0.0
    var player_hp: int = game.player.health
    game.player.receive_hit(3, game.boss.global_position)
    check(game.boss.health == hp and game.player.health == player_hp, "full-song narrative rest rejects both directions of actual damage")
    step(game, game.music._transport.rest_end - game.music.get_chart_time() + 0.01)
    check(not game.story_safe and game.boss.phase == "final", "rest returns to combat at sourcebeat296")
    step(game, game.music._transport.duration - game.music.get_chart_time() + 0.01)
    check(game.story_safe and not game.music.running and not game.boss.dead and game.defeats == 0, "source EOF makes a living Boss safe without false victory")
    check(get_nodes_in_group("boss_hazards").is_empty() and game.boss._authored_actions.is_empty(), "EOF cannot retain old active geometry or queued attacks")
    check(is_equal_approx(Engine.time_scale, 1.0), "full-song source transport never changes global time scale")
    game.queue_free()
    await process_frame
    await process_frame
    print("FULL SONG BOSS: %d passed, %d failed" % [passed, failed])
    quit(1 if failed > 0 else 0)

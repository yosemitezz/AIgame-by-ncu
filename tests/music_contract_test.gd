extends SceneTree
## Deterministic contract checks. No input playback, renderer, or listening session.

const Music = preload("res://audio/music_director.gd")
const Boss = preload("res://combat/boss.gd")
const Player = preload("res://actors/player.gd")
const Projectile = preload("res://combat/projectile.gd")

class ContractGame extends Node2D:
    signal warning_issued(kind: String, at: Vector2, duration: float)
    signal animation_event(actor: Node, state: String, frame: int, facing: int)
    var player: Node2D
    var boss: Node2D
    var music: Node
    var story_safe: bool = false
    var cleared_projectiles: int = 0
    var defeat_callbacks: int = 0
    var phase_history: Array[String] = []
    var announcements: Array[String] = []
    func set_story_safe(value: bool) -> void:
        story_safe = value
        if value:
            for projectile in get_tree().get_nodes_in_group("projectiles"):
                projectile.clear()
                cleared_projectiles += 1
    func damage_player(amount: int, origin: Vector2) -> void:
        player.receive_hit(amount, origin)
    func emit_fx(_kind: String, _at: Vector2, _direction: Vector2 = Vector2.ZERO, _power: float = 1.0) -> void:
        pass
    func announce(text: String, _seconds: float = 3.0) -> void:
        announcements.append(text)
    func on_boss_phase(section: String) -> void:
        phase_history.append(section)
    func on_boss_defeated() -> void:
        defeat_callbacks += 1
    func hero_attack(_source: Node2D, _damage: int, _reach: float, _combo: int) -> void:
        pass
    func spawn_projectile(at: Vector2, motion: Vector2, friendly: bool = false) -> Node2D:
        var projectile: Node2D = Projectile.new()
        add_child(projectile)
        projectile.configure(self, at, motion, friendly)
        projectile.set_physics_process(false)
        return projectile

var passed: int = 0
var failed: int = 0

func _initialize() -> void:
    call_deferred("_run")

func _check(condition: bool, label: String) -> void:
    if condition:
        passed += 1
        print("PASS ", label)
    else:
        failed += 1
        push_error("FAIL " + label)

func _beats(music: Node, count: int) -> void:
    for _i: int in count:
        music.advance_beat()

func _run() -> void:
    _check(is_equal_approx(Music.compensated_clock(0.0, 0, 8.0, -0.035), 0.0), "initial negative compensated clock stays at zero")
    _check(is_equal_approx(Music.compensated_clock(0.0, 1, 8.0, -0.035), 7.965), "wrapped negative raw preserves prior audible phrase tail")
    _check(is_equal_approx(Music.compensated_clock(0.0, 1, 8.0, 0.015), 8.015), "wrapped positive raw advances beyond loop duration")
    _check(is_equal_approx(Music.compensated_clock(16.0, 1, 8.0, -0.035), 23.965), "compensated unwrapped clock adds section origin")
    for action: String in ["move_left", "move_right", "jump", "dash", "attack", "parry"]:
        if not InputMap.has_action(action):
            InputMap.add_action(action)
    var game := ContractGame.new()
    game.visible = false
    root.add_child(game)
    game.player = Player.new()
    game.player.configure(game)
    game.add_child(game.player)
    game.player.position = Vector2(3020, 300)
    game.player.set_physics_process(false)
    game.music = Music.new()
    game.add_child(game.music)
    game.music.configure(game)
    game.music.set_process(false)
    game.boss = Boss.new()
    game.add_child(game.boss)
    game.boss.configure(game, Vector2(2970, 300))
    game.boss.set_physics_process(false)
    game.boss.start_encounter()
    game.music.stop_score()

    _check(game.music.current_section == "fixed", "initial fixed section")
    _check(not game.story_safe, "combat enabled at score start")
    var fixed_stream: AudioStreamWAV = game.music._streams["fixed"]
    _check(fixed_stream.data.size() > 1000 and fixed_stream.loop_mode == AudioStreamWAV.LOOP_FORWARD, "original PCM score has loopable sample data")
    _beats(game.music, 7)
    _check(game.music.current_section == "fixed", "fixed section does not end early")
    var threshold: int = maxi(1, int(floor(float(game.boss.max_health) * game.music.advance_health_ratio)))
    game.boss.receive_hit(999, game.player.global_position)
    _check(game.boss.health == threshold and not game.boss.dead and game.defeat_callbacks == 0, "fixed overkill stops at phrase seal and cannot defeat boss")
    _check(not game.music.is_advance_queued(), "fixed threshold cannot prematurely queue random phase exit")
    var seal_cues: int = game.announcements.size()
    game.boss._hurt_timer = 0.0
    game.boss.receive_hit(999, game.player.global_position)
    _check(game.announcements.size() == seal_cues, "repeated sealed hits do not spam narration")
    # Restore health to separately exercise the random loop with no threshold reached.
    game.boss.health = game.boss.max_health
    game.boss._hurt_timer = 0.0
    _beats(game.music, 1)
    _check(game.music.current_section == "random", "fixed advances on eighth beat")
    _beats(game.music, 16)
    _check(game.music.current_section == "random" and game.music.get_section_beat() == 0, "random loops entire phrase without health threshold")
    _beats(game.music, 3)
    _check(game.player.health == game.player.max_health, "unmatched beats never damage player")
    game.boss.health = threshold + 1
    game.boss.receive_hit(1, game.player.global_position)
    _check(game.boss.health == threshold and game.music.is_advance_queued(), "actual boss health threshold queues phase advance")
    game.boss._hurt_timer = 0.0
    game.boss.receive_hit(999, game.player.global_position)
    _check(game.boss.health == threshold and not game.boss.dead and game.defeat_callbacks == 0, "random overkill cannot bypass rest or final section")
    _check(game.music.is_advance_queued(), "random overkill preserves queued phrase-boundary transition")
    _check(game.music.current_section == "random", "threshold does not cut phrase immediately")
    _beats(game.music, 12)
    _check(game.music.current_section == "random" and game.music.get_section_beat() == 15, "queued random phase remains through beat fifteen")

    # Old real actor/projectile state must be made harmless at the shared rest boundary.
    game.boss._begin_attack("charge")
    game.boss._charge_timer = 0.3
    game.player.attack_timer = 0.3
    game.player.parry_timer = 0.16
    game.player.combo = 2
    var hostile: Node2D = game.spawn_projectile(Vector2(3000, 250), Vector2.LEFT * 100.0)
    var friendly: Node2D = game.spawn_projectile(Vector2(3000, 250), Vector2.RIGHT * 100.0, true)
    _beats(game.music, 1)
    _check(game.music.current_section == "rest" and game.story_safe, "rest begins only on complete queued phrase boundary")
    _check(game.cleared_projectiles == 2 and hostile._cleared and friendly._cleared, "rest boundary requests safe cleanup of both old projectile factions")
    _check(game.boss._pending_attack.is_empty() and game.boss._windup_timer == 0.0 and game.boss._charge_timer == 0.0, "rest cancels boss pending attack and active charge")
    game.player._physics_process(0.0)
    _check(game.player.attack_timer == 0.0 and game.player.parry_timer == 0.0 and game.player.combo == 0, "rest cancels player attack and parry state")
    var player_hp: int = game.player.health
    var boss_hp: int = game.boss.health
    game.player.invuln = 0.0
    game.boss._hurt_timer = 0.0
    var took_damage: bool = game.player.receive_hit(3, game.boss.global_position)
    game.boss.receive_hit(3, game.player.global_position)
    _check(not took_damage and game.player.health == player_hp, "real player rejects damage during rest without relying on invulnerability")
    _check(game.boss.health == boss_hp, "real boss rejects damage during rest without relying on hit cooldown")
    _beats(game.music, 7)
    _check(game.music.current_section == "rest" and game.story_safe, "rest protection spans entire configured phrase")
    _beats(game.music, 1)
    _check(game.music.current_section == "final" and not game.story_safe, "final combat resumes at rest phrase boundary")
    game.boss.receive_hit(1, game.player.global_position)
    took_damage = game.player.receive_hit(1, game.boss.global_position)
    _check(took_damage and game.player.health == player_hp - 1 and game.boss.health == boss_hp - 1, "both real actors can receive damage after rest")
    _check(game.phase_history == ["fixed", "random", "rest", "final"], "phase signal ordering matches score contract")
    game.boss._hurt_timer = 0.0
    game.boss.receive_hit(999, game.player.global_position)
    game.boss.receive_hit(999, game.player.global_position)
    _check(game.boss.dead and game.defeat_callbacks == 1, "boss defeat callback fires exactly once")
    game.queue_free()
    await process_frame
    print("Music contract: %d passed, %d failed" % [passed, failed])
    quit(1 if failed > 0 else 0)

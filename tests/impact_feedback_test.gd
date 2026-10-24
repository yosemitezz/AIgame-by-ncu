extends SceneTree
## Contact/feedback integration seams, not an automated playthrough.
const Renderer = preload("res://presentation/actor_renderer.gd")
var passed: int = 0
var failed: int = 0

func check(value: bool, label: String) -> void:
    if value:
        passed += 1
        print("PASS ", label)
    else:
        failed += 1
        push_error("FAIL " + label)

func _initialize() -> void:
    call_deferred("run")

func run() -> void:
    var game: Node = load("res://main.tscn").instantiate()
    root.add_child(game)
    await process_frame
    game.set_physics_process(false)
    game.player.set_physics_process(false)
    game.music.set_process(false)
    for actor: Node in get_nodes_in_group("enemies"):
        actor.set_physics_process(false)
    var target: Node
    for actor: Node in get_nodes_in_group("enemies"):
        if actor.kind == "elite":
            target = actor
    game.player.position = Vector2(2200, 300)
    game.player.facing = 1
    target.position = Vector2(2232, 300)
    game.player._start_attack()
    game.player._enter_attack_phase("active")
    game.player.attack_sweep_from = 0.25
    game.player.attack_sweep_to = 1.0
    game.player.attack_serial = 100
    var before: int = target.health
    var impacts_before: int = game.impact.impact_count
    for _i: int in 6:
        game.hero_attack(game.player, 2, 55, 3)
    check(target.health == before - 2, "active window damages each target once")
    check(game.impact.impact_count == impacts_before + 1, "one hit produces one impact bundle")
    check(game.player._hit_confirmed, "accepted hit enables cancellation confirmation")
    check(game.player.combat_freeze > 0 and target.combat_freeze > 0, "both contacting actors receive local hold")
    check(is_equal_approx(Engine.time_scale, 1.0) and not paused, "impact never changes global time or tree pause")
    game._start_boss()
    game.boss.set_physics_process(false)
    game.boss.position = Vector2(2236, 300)
    game.boss.facing = -1
    game.boss._contact_resolved = false
    game.player.parry_timer = 0.16
    impacts_before = game.impact.impact_count
    game.boss._begin_attack("slash")
    game.boss._release_attack()
    check(game.impact.impact_count == impacts_before + 1, "one Boss parry produces exactly one impact bundle")
    check(game.boss.combat_freeze > 0 and game.player.combat_freeze > 0, "Boss parry holds both actors through one contact event")
    game.boss.position = Vector2(3100, 300)
    game.music.start_score()
    game.music._process(game.music.seconds_per_beat() * 1.1)
    check(game.music.total_beats == 1, "music clock advances while actors are held")
    var projectile: Node = game.spawn_projectile(Vector2(2200, 100), Vector2(100, 0))
    projectile.set_physics_process(false)
    var at: Vector2 = projectile.position
    projectile._physics_process(0.05)
    check(projectile.position.x > at.x, "projectiles keep moving during actor-local hit-stop")
    projectile.clear()
    target._hurt_flash = 0
    game.player.combat_freeze = 0.0
    game.player._clear_parry()
    game.player._cancel_attack()
    game.player._start_attack()
    game.player._enter_attack_phase("active")
    game.player.attack_sweep_from = 0.25
    game.player.attack_sweep_to = 1.0
    game.hero_attack(game.player, 1, 55, 1)
    check(target.health == before - 3, "next attack serial can hit same target again")
    var bounded: bool = true
    var offset := Vector2.ZERO
    for _i: int in 120:
        offset = game.impact.sample_camera(1.0 / 60.0)
        bounded = bounded and offset.length() <= game.impact.MAX_OFFSET + 0.001
    check(bounded and offset.length() < 0.001, "camera impulse is bounded and settles completely")
    game.impact.add_kick(Vector2.RIGHT, 2)
    game.impact.reduced_motion = true
    check(game.impact.sample_camera(0.01) == Vector2.ZERO, "reduced camera feedback disables displacement")
    check(Renderer.hero_region("windup", 2, 1) != Renderer.hero_region("attack", 2, 1), "windup and active map to different authored poses")
    check(Renderer.hero_region("attack", 2, 1) != Renderer.hero_region("attack", 2, 3), "finisher has a distinct authored active pose")
    var gradient: Node = game.get_node("FxLayer")
    game.player.dash_timer = 0.12
    for i: int in 12:
        game.player.position.x += 8
        game.emit_fx("dash", game.player.position - Vector2(0, 13), Vector2.LEFT, 0.5)
        gradient._process(0.04)
    var counts: Dictionary = gradient.counts()
    check(int(counts.get("ghosts", 0)) > 0 and int(counts.get("ghosts", 0)) <= gradient.MAX_OWNER_GHOSTS, "moving dash produces bounded real owner ghosts")
    game.warning_issued.emit("fan", Vector2(2240, 240), 0.5)
    game.emit_fx("enemy_slash", Vector2(2220, 280), Vector2.LEFT, 1)
    check(not gradient.draw_warnings and int(gradient.counts().get("warnings",0)) == 0 and int(game.effects.counts().get("warnings",0)) > 0, "one warning authority holds the issued warning without a duplicate gradient overlay")
    game.set_story_safe(true)
    var impact_count: int = game.impact.impact_count
    game.request_impact(game.player, target, true, true)
    check(game.player.combat_freeze == 0 and game.impact.impact_count == impact_count, "rest clears actor hold and rejects new impact requests")
    counts = game.effects.counts()
    check(int(counts.get("warnings", 0)) == 0 and int(gradient.counts().get("warnings",0)) == 0, "rest clears both hostile warning layers")
    game.music.stop_score()
    print("Impact integration: %d passed, %d failed" % [passed, failed])
    quit(1 if failed else 0)

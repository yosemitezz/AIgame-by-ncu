extends SceneTree
## Bounded logic checks. No automated playthrough or game-balance judgement.
var passed: int = 0
var failed: int = 0

func check(value: bool, label: String) -> void:
    if value:
        passed += 1
        print("PASS ", label)
    else:
        failed += 1
        push_error("FAIL " + label)

func freeze(game: Node) -> void:
    game.set_physics_process(false)
    game.player.set_physics_process(false)
    game.music.stop_score()
    game.music.set_process(false)
    for enemy: Node in get_nodes_in_group("enemies"):
        enemy.set_physics_process(false)

func _initialize() -> void:
    call_deferred("run")

func run() -> void:
    var game: Node = load("res://main.tscn").instantiate()
    root.add_child(game)
    current_scene = game
    await process_frame
    freeze(game)
    check(game.player.health == 8, "scene starts with full health")
    check(get_nodes_in_group("enemies").size() == 6, "complete authored enemy roster loaded")
    check(game.level.get_child_count() == 16, "all 16 platform bodies built")
    check(InputMap.has_action("parry") and InputMap.has_action("dash"), "input mappings installed")
    var floors: Array[Rect2] = []
    for rectangle: Rect2 in game.level.PLATFORMS:
        if rectangle.size.y > 16:
            floors.append(rectangle)
    var safe_gap: float = 180.0 * (2.0 * 340.0 / 900.0) * 0.7
    for i: int in range(floors.size() - 1):
        var gap: float = floors[i + 1].position.x - floors[i].end.x
        check(gap <= safe_gap and floors[i].position.y == floors[i + 1].position.y, "main-route gap %d is within 70 percent jump reach" % (i + 1))
    var enemy: Node = get_nodes_in_group("enemies")[0]
    var old_health: int = enemy.health
    game.set_story_safe(true)
    game.player.invuln = 0
    game.player.receive_hit(2, Vector2.ZERO)
    enemy.receive_hit(2, Vector2.ZERO)
    check(game.player.health == 8 and enemy.health == old_health, "rest blocks damage on both sides")
    game.set_story_safe(false)
    game.player.parry_timer = 0.07
    game.player.parry_success()
    check(is_equal_approx(game.player.parry_timer, 0.07), "successful parry does not extend input window")
    game.player.position = Vector2(2800, 280)
    game.player.facing = 1
    game.player.invuln = 0
    game.player.parry_timer = 0.16
    var front: Node = game.spawn_projectile(Vector2(2845, 264), Vector2(-400, 0))
    front.set_physics_process(false)
    front._physics_process(0.18)
    check(front.friendly and game.player.health == 8, "front contact reflects before hitting body")
    front.clear()
    game.player.invuln = 0
    game.player.parry_timer = 0.16
    var back: Node = game.spawn_projectile(Vector2(2760, 267), Vector2(400, 0))
    back.set_physics_process(false)
    back._physics_process(0.18)
    check(not back.friendly and game.player.health == 7, "back contact hits body before front shield")
    game.player.revive(Vector2(1800, 280))
    check(game.player.health == 8 and not game.player.dead and game.player.velocity == Vector2.ZERO and game.player.attack_timer == 0 and game.player.dash_timer == 0 and game.player.parry_timer == 0, "revive resets combat and motion state")
    game.player.position = Vector2(1862, 280)
    game._physics_process(0)
    check(game.checkpoint_active and game.checkpoint == game.level.CHECKPOINT, "crossing shrine saves checkpoint")
    var elite: Node
    for item: Node in get_nodes_in_group("enemies"):
        if item.kind == "elite":
            elite = item
    elite.receive_hit(999, game.player.position)
    check(game.elite_defeated and game.checkpoint.x == 2500, "elite unlocks gate and boss retry checkpoint")
    game._start_boss()
    freeze(game)
    game.boss.set_physics_process(false)
    check(game.boss_started and game.boss.health == 48, "boss encounter and score initialize")
    var p: Node = game.spawn_projectile(Vector2(2900, 150), Vector2(20, 0))
    p.set_physics_process(false)
    game.boss._begin_attack("fan")
    game.music._set_section("rest")
    check(game.story_safe and get_nodes_in_group("projectiles").is_empty(), "rest safely clears existing projectiles")
    check(game.boss._pending_attack == "" and game.boss._windup_timer == 0 and game.boss._charge_timer == 0, "rest cancels boss windups and charges")
    old_health = game.boss.health
    game.hero_attack(game.player, 999, 9999, 1)
    game.boss.receive_hit(999, game.player.position)
    check(game.boss.health == old_health, "rest blocks direct and hero melee damage to boss")
    game.music._set_section("final")
    game.music.stop_score()
    game.boss._hurt_timer = 0
    game.boss.health = 1
    game.boss.receive_hit(1, game.player.position)
    check(game.outcome == "victory" and game.story_safe and not game.music.running, "boss defeat completes chapter safely")
    game._reload(false)
    await process_frame
    await process_frame
    game = current_scene
    freeze(game)
    check(game.checkpoint_active and game.elite_defeated and game.player.position.x >= 2490, "retry reload retains unlocked checkpoint")
    game._reload(true)
    await process_frame
    await process_frame
    game = current_scene
    freeze(game)
    check(not game.checkpoint_active and not game.elite_defeated and game.score == 0, "new journey clears runtime progress")
    print("Integration: %d passed, %d failed" % [passed, failed])
    quit(1 if failed else 0)


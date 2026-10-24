extends SceneTree
## Genuine contact through actual player/Boss/projectile nodes, not a playthrough.
var passed: int = 0
var failed: int = 0

func check(value: bool, label: String) -> void:
    if value:
        passed += 1
        print("PASS ", label)
    else:
        failed += 1
        push_error("FAIL " + label)

func freeze_world(game: Node) -> void:
    game.set_physics_process(false)
    game.player.set_physics_process(false)
    game.music.stop_score()
    game.music.set_process(false)
    for actor: Node in get_nodes_in_group("enemies"):
        actor.set_physics_process(false)

func recover_boss(game: Node) -> void:
    for _i: int in 45:
        game.boss._physics_process(0.04)
    game.player.revive(Vector2(2800, 300))
    game.player.invuln = 0
    game.player.facing = 1
    game.boss.position = Vector2(2838, 300)
    game.boss.facing = -1

func _initialize() -> void:
    call_deferred("run")

func run() -> void:
    var game: Node = load("res://main.tscn").instantiate()
    root.add_child(game)
    current_scene = game
    await process_frame
    freeze_world(game)
    game.elite_defeated = true
    game._start_boss()
    freeze_world(game)
    recover_boss(game)
    var before: int = game.parry_feedback_count
    game.player._start_parry()
    game.boss._begin_attack("slash")
    game.boss._release_attack()
    check(game.parry_feedback_count == before + 1, "actual melee contact dispatches one parry event")
    check(game.boss.guard_posture == 1, "melee parry consumes Boss posture once")
    check(game.player.animation_state == "parry_recoil", "contact immediately selects authored recoil pose")
    check(game.boss.reaction_state == "parry_recoil", "ordinary Boss slash is interrupted into rebound")
    var shield: Vector2 = game.player.position + Vector2(18, -16)
    check(game.last_parry_contact.distance_to(shield) < 25, "feedback is placed at blade contact near the shield")
    check(game.player.combat_freeze > 0 and game.boss.combat_freeze > 0, "local contact hold affects both combatants")
    var health: int = game.player.health
    game.player.parry_timer = 0
    game.player.invuln = 0
    for _i: int in 12:
        game.boss._physics_process(0.04)
    check(game.player.health == health, "interrupted slash has no residual contact damage")
    recover_boss(game)
    await physics_frame
    game.player._start_parry()
    before = game.parry_feedback_count
    var posture_before: int = game.boss.guard_posture
    var shot: Node = game.spawn_projectile(game.player.position + Vector2(46, -16), Vector2(-300, 0))
    shot.set_physics_process(false)
    shot._physics_process(0.2)
    check(shot.friendly and game.last_parry_kind == "projectile", "actual shot contact uses reflection feedback")
    check(game.parry_feedback_count == before + 1 and game.boss.guard_posture == posture_before, "reflection rewards once without farming Boss posture")
    check(not shot.reflect() and game.parry_feedback_count == before + 1, "already reflected shot cannot reward again")
    shot.clear()
    recover_boss(game)
    await physics_frame
    game.boss.guard_posture = game.boss.guard_max - 1
    game.player._start_parry()
    game.boss._begin_attack("slash")
    game.boss._release_attack()
    check(game.boss.reaction_state == "guard_break" and game.last_parry_kind == "guard_break", "threshold contact triggers distinct guard break feedback")
    var beats: int = game.music.total_beats
    game.music.advance_beat()
    check(game.music.total_beats == beats + 1 and is_equal_approx(Engine.time_scale, 1.0), "music clock advances during guard-break hold")
    var guard: int = game.boss.guard_posture
    before = game.parry_feedback_count
    game.boss._release_attack()
    check(game.boss.guard_posture == guard and game.parry_feedback_count == before, "cancelled release cannot repeat rewards")
    paused = true
    game.player.parry_timer = 0.16
    check(not game.player.parry_success(game.boss, shield, "melee", 99999), "paused scene rejects contact rewards")
    paused = false
    game.music._set_section("rest")
    game.player._physics_process(0)
    check(game.story_safe and game.boss.guard_posture == 0 and game.boss.reaction_state == "none", "rest clears posture and Boss reaction")
    check(game.player.parry_phase == "none" and game.player.combat_freeze == 0, "rest clears player parry reaction")
    before = game.parry_feedback_count
    game.on_parry_contact(game.player, game.boss, shield, "guard_break")
    check(game.parry_feedback_count == before and get_nodes_in_group("projectiles").is_empty(), "rest rejects feedback and clears attacks")
    game.music.stop_score()
    game._reload(true)
    await process_frame
    await process_frame
    game = current_scene
    freeze_world(game)
    check(game.parry_feedback_count == 0 and game.player.parry_phase == "none", "retry constructs a clean contact ledger and pose")
    print("Parry integration: %d passed, %d failed" % [passed, failed])
    quit(1 if failed else 0)

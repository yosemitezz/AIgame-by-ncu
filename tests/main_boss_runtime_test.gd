extends SceneTree
## Bounded real-main runtime fixtures. No input playback or foreign audio/subproject execution.
const Hazard = preload("res://combat/boss_hazard.gd")
var passed: int = 0
var failed: int = 0
var game: Node
var observed_hazards: Dictionary = {}
var observed_shots: Dictionary = {}
var observed_patterns: Dictionary = {}
var observed_geometry_ok: bool = true
var observed_cap_ok: bool = true
var first_cube_geometry: Dictionary = {}
var finished: bool = false

func check(ok: bool, label: String) -> void:
    if ok:
        passed += 1
        print("PASS ", label)
    else:
        failed += 1
        push_error("FAIL " + label)

func _initialize() -> void:
    call_deferred("install_watchdog")
    call_deferred("run")

func install_watchdog() -> void:
    var timer: SceneTreeTimer = create_timer(15.0)
    timer.timeout.connect(func() -> void:
        if not finished:
            push_error("FAIL bounded main Boss runtime timeout; inspect preceding engine errors")
            quit(1))

func freeze_scene() -> void:
    game.set_process(false)
    game.set_physics_process(false)
    for node: Node in game.find_children("*", "Node", true, false):
        node.set_process(false)
        node.set_physics_process(false)

func boot() -> void:
    game = load("res://main.tscn").instantiate()
    root.add_child(game)
    current_scene = game
    if not game.has_method("_start_boss"):
        check(false, "main scene script and dependencies load before runtime verification")
        game.queue_free()
        game = null
        return
    freeze_scene()
    await physics_frame
    game.player.position = Vector2(2900.0, 300.0)
    game.player.invuln = 999.0
    game._start_boss()
    freeze_scene()
    harvest(0.0)

func reload_main() -> void:
    game._reload(true)
    await process_frame
    await process_frame
    game = current_scene
    freeze_scene()
    await physics_frame

func harvest(delta: float) -> void:
    var status: Dictionary = game.boss.get_authored_status()
    for event: Dictionary in status["trace"]:
        observed_patterns[str(event["pattern"])] = true
    for hazard: Node in get_nodes_in_group("boss_hazards"):
        hazard.set_physics_process(false)
        hazard._physics_process(delta)
        if not is_instance_valid(hazard) or hazard._cleared:
            continue
        var geometry: Dictionary = hazard.get_geometry_snapshot()
        var kind: String = str(geometry["kind"])
        observed_hazards[kind] = true
        var lines: Array = geometry["lines"]
        if kind.begins_with("cube_") and first_cube_geometry.is_empty():
            first_cube_geometry = geometry.duplicate(true)
        if kind in ["cube_x", "cube_plus"]:
            observed_geometry_ok = observed_geometry_ok and lines.size() == 2
            var horizontal: int = 0
            var vertical: int = 0
            for cube_line: Dictionary in lines:
                var segment: Vector2 = (cube_line["b"] as Vector2) - (cube_line["a"] as Vector2)
                if kind == "cube_x":
                    observed_geometry_ok = observed_geometry_ok and absf(segment.x) > 10.0 and absf(segment.y) > 10.0
                else:
                    horizontal += 1 if absf(segment.y) < 1.0 else 0
                    vertical += 1 if absf(segment.x) < 1.0 else 0
            if kind == "cube_plus":
                observed_geometry_ok = observed_geometry_ok and horizontal == 1 and vertical == 1
        if kind in ["diamond", "parallel", "grid", "rotating"]:
            observed_geometry_ok = observed_geometry_ok and lines.size() == 4
        for line: Dictionary in lines:
            observed_geometry_ok = observed_geometry_ok and float(line["warning_time"]) < float(line["damage_time"]) and float(line["damage_time"]) < float(line["active_until"]) and (line["a"] as Vector2).distance_to(line["b"]) > 80.0
    for shot: Node in get_nodes_in_group("projectiles"):
        shot.set_physics_process(false)
        if shot.has_meta("boss_source"):
            observed_shots[shot.get_instance_id()] = true
        shot._physics_process(delta)
    observed_cap_ok = observed_cap_ok and get_nodes_in_group("boss_hazards").size() <= 24 and get_nodes_in_group("projectiles").size() <= 96

func advance_to(target: float, protect: bool = true) -> void:
    var steps: int = 0
    while game.music.get_score_time() < target - 0.000001 and steps < 4096:
        var delta: float = minf(game.music.seconds_per_beat() / 8.0, target - game.music.get_score_time())
        if protect:
            game.player.invuln = 999.0
        game.music._process(delta)
        game.boss._physics_process(delta)
        harvest(delta)
        steps += 1
    check(steps < 4096, "bounded sole-score advance reaches %.3f" % target)

func cleanup_probe() -> Node2D:
    var records: Array[Dictionary] = []
    var now: float = game.music.get_score_time()
    records.append({"origin": game.player.global_position + Vector2(0.0, -13.0), "angle_radians": 0.0, "warning_time": now - 0.1, "damage_time": now + 0.01, "active_until": now + 2.0, "thickness": 9.0})
    var hazard: Node2D = Hazard.new()
    hazard.configure_lines(game, game.boss, records, game.boss.LASER_ARENA, game.boss.hazard_generation, "cleanup_probe")
    game.spawn_boss_hazard(hazard)
    hazard.set_physics_process(false)
    return hazard

func contact_fixture() -> void:
    game.boss._cancel_all_attacks()
    game.boss.combat_freeze = 0.0
    game.boss._advance_reaction(2.0)
    game.boss._posture_lockout = 0.0
    game.boss._recovery_timer = 0.0
    game.boss.position = Vector2(3000.0, 300.0)
    game.boss.velocity = Vector2.ZERO
    game.player.revive(Vector2(2960.0, 300.0))
    game.player.invuln = 0.0
    game.player.facing = 1
    game.impact.clear()

func drive_source_blade_contact(pattern: Dictionary, dash_offset_beats: float, label: String) -> void:
    # Prepare before the absolute source release. The new protocol previews the
    # raised pose before the beat and enters real steel contact on the beat.
    var locked_target: Vector2 = game.player.global_position
    game.player.global_position = Vector2(3270.0, 300.0)
    var release: float = game.music.get_score_time() + 0.05
    var start: float = release - dash_offset_beats * game.music.seconds_per_beat()
    check(game.boss._begin_authored_pattern(pattern, start, locked_target), label + " queues the real source plan")
    game.boss._physics_process(0.0)
    check(game.music.get_score_time() < release and not game.boss.get_blade_state()["active"], label + " pre-release preparation remains harmless")
    var frames: int = 0
    while game.music.get_score_time() < release - 0.000001 and frames < 10:
        await physics_frame
        var delta: float = minf(1.0 / 60.0, release - game.music.get_score_time())
        game.music._process(delta)
        game.player._physics_process(delta)
        game.boss._physics_process(delta)
        for shot: Node in get_nodes_in_group("projectiles"):
            shot.set_physics_process(false)
        for hazard: Node in get_nodes_in_group("boss_hazards"):
            hazard.set_physics_process(false)
        frames += 1
    var blade: Dictionary = game.boss.get_blade_state()
    check(absf(game.music.get_score_time() - release) < 0.00001 and blade["active"] and int(blade["frame"]) in [1, 2], label + " absolute release enters its actual effective pixel blade without a second delay")
    if not blade["active"]:
        return
    var steel: Vector2 = game.boss.global_position + (blade["from"] as Vector2).lerp(blade["to"], 0.45)
    game.player.global_position = steel + Vector2(0.0, 13.0)
    game.player.velocity = Vector2.ZERO
    game.player.facing = 1 if game.boss.global_position.x >= game.player.global_position.x else -1
    check(game.player._start_parry(), label + " opens a fresh left Shift contact window at real steel")
    await physics_frame
    game.music._process(1.0 / 60.0)
    game.player._physics_process(1.0 / 60.0)
    game.boss._physics_process(1.0 / 60.0)

func run() -> void:
    root.size = Vector2i(800, 450)
    await boot()
    if not is_instance_valid(game):
        finished = true
        quit(1)
        return
    check(game.music._dummy and game.boss._authored_ready and game.boss._active, "real main encounter loads authored runtime on generated Dummy score")
    var spb: float = game.music.seconds_per_beat()
    advance_to(spb * 0.5)
    check(get_nodes_in_group("boss_hazards").size() == 1, "same-time fixed notes aggregate into one real carrier")
    var cube: Node2D = null
    for candidate: Node in get_nodes_in_group("boss_hazards"):
        if candidate.kind in ["cube_x", "cube_plus"]:
            cube = candidate
            break
    if not is_instance_valid(cube):
        check(false, "required cube carrier exists for contact-window test")
        game.queue_free()
        quit(1)
        return
    var original: Dictionary = cube.get_geometry_snapshot()
    check(str(original["kind"]) in ["cube_x", "cube_plus"], "fixed downbeat creates an actual X or plus cube")
    cube._physics_process(0.0)
    check(cube.get_geometry_snapshot()["kind"] == original["kind"] and cube.get_geometry_snapshot()["lines"] == original["lines"], "random cube orientation is locked for its whole carrier")
    var line: Dictionary = original["lines"][0]
    game.player.position = (line["a"] as Vector2).lerp(line["b"], 0.3) + Vector2(0.0, 13.0)
    game.player.invuln = 0.0
    var hp: int = game.player.health
    advance_to(float(line["warning_time"]) + 0.01, false)
    check(game.player.health == hp and cube.get_geometry_snapshot()["clock"] >= float(line["warning_time"]), "visible cube warning is harmless at the actual line contact")
    advance_to(float(line["damage_time"]) - 0.01, false)
    check(game.player.health == hp, "entire cube windup remains harmless")
    advance_to(float(line["damage_time"]) + 0.02, false)
    check(game.player.health == hp - 1, "same real cube line deals exactly main damage one at its music boundary")
    game.player.position = Vector2(2900.0, 300.0)
    game.player.invuln = 999.0
    var clock_before: float = game.music.get_score_time()
    game.player.set_impact_freeze(0.08)
    game.boss.set_impact_freeze(0.07)
    game.music._process(0.03)
    game.boss._physics_process(0.03)
    harvest(0.0)
    check(game.music.get_score_time() > clock_before + 0.029 and game.boss.combat_freeze > 0.0, "actor local hold does not stall the sole score clock")
    check(is_equal_approx(float(cube.get_geometry_snapshot()["clock"]), game.music.get_score_time()), "existing hazard continues on music while its owner holds")
    advance_to(24.0 * spb - 0.01)
    check(game.music.current_section == "random" and game.music.get_section_beat() == 15, "actual fixed score advances and random completes one source cycle")
    check(observed_hazards.has("cube_x") or observed_hazards.has("cube_plus"), "fixed section executes source cube geometry")
    for pattern: String in ["charge_dash_ring", "side_sweep_spray", "fan_then_dash", "dash_double_ring"]:
        check(observed_patterns.has(pattern), "real main executes normal pattern " + pattern)
    check(observed_shots.size() >= 16, "normal source actions create actual main projectile nodes")
    check(cube._cleared, "leaving fixed invalidates its old carrier immediately")
    var rest_probe: Node2D = cleanup_probe()
    var old_shots: Array = get_nodes_in_group("projectiles")
    game.boss.health = int(floor(float(game.boss.max_health) * game.music.advance_health_ratio)) + 1
    game.boss._hurt_timer = 0.0
    game.boss.receive_hit(1, game.player.position)
    check(game.music.is_advance_queued() and game.music.current_section == "random", "real health threshold queues, rather than cuts, the source phrase")
    advance_to(24.0 * spb + 0.02)
    check(game.story_safe and game.music.current_section == "rest" and rest_probe._cleared, "phrase boundary enters rest and clears real line fixture")
    check(get_nodes_in_group("boss_hazards").is_empty() and get_nodes_in_group("projectiles").is_empty(), "rest contains zero live hostile carriers or shots")
    var safe_hp: int = game.player.health
    game.player.invuln = 0.0
    rest_probe._physics_process(1.0)
    for old_shot: Node in old_shots:
        if is_instance_valid(old_shot):
            old_shot._physics_process(1.0)
    check(game.player.health == safe_hp and game.boss.get_authored_status()["queued_actions"] == 0, "old references cannot damage or release queued actions during rest")
    advance_to(48.0 * spb - 0.01)
    check(game.music.current_section == "final" and not game.story_safe, "actual rest returns to final combat")
    for pattern: String in ["fast_1", "fast_2", "fast_3", "fast_4"]:
        check(observed_patterns.has(pattern), "real main executes fast source pattern " + pattern)
    for formation: String in ["diamond", "parallel", "grid", "rotating"]:
        check(observed_hazards.has(formation), "real main instantiates laser formation " + formation)
    check(observed_geometry_ok and observed_cap_ok, "real carrier geometry has ordered warning/damage windows and obeys main caps")
    # The source chooses a random orientation per cue, not a forced alternating sequence.
    for seed_value: int in range(16):
        game.boss._cube_rng.seed = seed_value
        game.music.start_score()
        harvest(0.0)
        if observed_hazards.has("cube_x") and observed_hazards.has("cube_plus"):
            break
    check(observed_hazards.has("cube_x") and observed_hazards.has("cube_plus"), "real seeded fixed cues cover both locked random orientations")
    # Actual death callback + actual main reload, with live danger still present.
    var death_probe: Node2D = cleanup_probe()
    game.player.invuln = 0.0
    game.player.health = 1
    game.damage_player(1, game.boss.position)
    check(game.player.dead and game.outcome == "defeat" and game.story_safe and death_probe._cleared, "actual player death clears danger and enters defeat")
    check(get_nodes_in_group("boss_hazards").is_empty() and get_nodes_in_group("projectiles").is_empty() and not game.music.running, "defeat stops source score and all live danger")
    var old_boss: WeakRef = weakref(game.boss)
    var old_hazard: WeakRef = weakref(death_probe)
    await reload_main()
    check(old_boss.get_ref() == null and old_hazard.get_ref() == null and get_nodes_in_group("boss_hazards").is_empty(), "actual retry destroys old boss generations and line references")
    check(game.outcome.is_empty() and not game.boss_started and game.player.health == game.player.max_health, "retry creates a fresh playable main scene")
    game._start_boss()
    freeze_scene()
    # Unblockable, ordinary and armored strikes all traverse the real action executor and contact endpoint.
    contact_fixture()
    var base_feedback: int = game.parry_feedback_count
    var base_hp: int = game.player.health
    await drive_source_blade_contact(game.boss.friend_slots.get_normal_pattern(0), 2.0, "unblockable source charge")
    check(game.player.health == base_hp - 1 and game.parry_feedback_count == base_feedback and game.boss.guard_posture == 0, "source charge stays unblockable and never grants false parry")
    await physics_frame
    contact_fixture()
    base_feedback = game.parry_feedback_count
    await drive_source_blade_contact(game.boss.friend_slots.get_normal_pattern(2), 2.0, "ordinary source dash")
    var ordinary: Dictionary = game.boss.get_authored_status()
    check(game.parry_feedback_count == base_feedback + 1 and game.boss.guard_posture == 1 and game.boss.reaction_state == "parry_recoil", "ordinary authored contact dispatches one real parry and recoil")
    check(ordinary["queued_actions"] == 0 and not ordinary["dash_active"], "ordinary parry cancels the real source queue and movement")
    game.boss.guard_posture = 0
    for strike: int in range(3):
        await physics_frame
        contact_fixture()
        base_feedback = game.parry_feedback_count
        var pattern: Dictionary = game.boss.friend_slots.get_normal_pattern(3)
        await drive_source_blade_contact(pattern, 0.0, "armored source contact %d" % strike)
        var status: Dictionary = game.boss.get_authored_status()
        check(game.parry_feedback_count == base_feedback + 1, "armored contact %d dispatches one shared feedback" % strike)
        if strike == 0:
            check(game.boss.guard_posture == 1 and status["queued_actions"] > 0 and status["dash_active"], "armored parry keeps scheduled attacks while raising posture")
        if strike == 2:
            check(game.boss.guard_posture == 3 and game.boss.reaction_state == "guard_break" and game.last_parry_kind == "guard_break", "third armored contact opens actual guard break")
            check(status["queued_actions"] == 0 and not status["dash_active"], "guard break invalidates all remaining source danger")
    # Boss death uses its existing final receive_hit path, never direct HP callbacks.
    game.boss._advance_reaction(2.0)
    game.boss.combat_freeze = 0.0
    game.boss._posture_lockout = 0.0
    game.music._set_section("final")
    var victory_probe: Node2D = cleanup_probe()
    game.boss.health = 1
    game.boss._hurt_timer = 0.0
    game.boss.receive_hit(1, game.player.position)
    check(game.boss.dead and game.outcome == "victory" and game.story_safe and victory_probe._cleared, "real boss final hit reaches victory and clears delayed beams")
    var victory_hp: int = game.player.health
    victory_probe._physics_process(1.0)
    game.damage_player(1, game.boss.position)
    check(game.player.health == victory_hp and get_nodes_in_group("boss_hazards").is_empty() and not game.music.running, "victory cannot retain residual damage or a running score")
    game.boss._physics_process(0.2)
    var death_pose: Dictionary = game.boss.get_presentation_pose()
    check(death_pose["state"] == "dead" and float(death_pose["progress"]) > 0.0, "actual victory keeps advancing the boss death pose")
    var dead_status: Dictionary = game.boss.get_authored_status()
    check(game.player.health == victory_hp and dead_status["queued_actions"] == 0 and not dead_status["dash_active"] and get_nodes_in_group("boss_hazards").is_empty() and get_nodes_in_group("projectiles").is_empty(), "advancing death pose cannot restore attacks or residual danger")
    check(is_equal_approx(Engine.time_scale, 1.0), "authored main integration never changes global time")
    game.queue_free()
    await process_frame
    finished = true
    print("MAIN_BOSS_RUNTIME_TEST: %d passed, %d failed" % [passed, failed])
    quit(1 if failed > 0 else 0)

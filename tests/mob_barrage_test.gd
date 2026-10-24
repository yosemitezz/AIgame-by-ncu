extends SceneTree
## Finite mob-pattern geometry/contact tests, not an automated playthrough.
const Enemy = preload("res://actors/enemy.gd")
const Player = preload("res://actors/player.gd")
const Projectile = preload("res://combat/projectile.gd")

class BarrageGame extends Node2D:
    signal warning_issued(kind: String, at: Vector2, duration: float)
    signal animation_event(actor: Node, state: String, frame: int, facing: int)
    var player: Node2D
    var boss: Node2D
    var story_safe: bool = false
    var _paused: bool = false
    var records: Array[Dictionary] = []
    var attempts: int = 0
    var reject_spawns: bool = false
    var contacts: int = 0
    var damage_calls: int = 0
    func spawn_projectile(at: Vector2, motion: Vector2, friendly: bool = false, style: String = "default") -> Node2D:
        attempts += 1
        if reject_spawns:
            return null
        var shot: Node2D = Projectile.new()
        shot.configure(self, at, motion, friendly)
        if shot.get("style") != null:
            shot.set("style", style)
        add_child(shot)
        shot.set_physics_process(false)
        records.append({"at": at, "velocity": motion, "style": style, "node": weakref(shot)})
        return shot
    func emit_fx(_kind: String, _at: Vector2, _direction: Vector2 = Vector2.ZERO, _power: float = 1.0) -> void:
        pass
    func on_enemy_defeated(_enemy: Node2D) -> void:
        pass
    func damage_player(amount: int, origin: Vector2) -> void:
        damage_calls += 1
        player.receive_hit(amount, origin)
    func hero_attack(_source: Node2D, _damage: int, _reach: float, _combo: int) -> void:
        pass
    func on_parry_contact(_defender: Node, _source: Node, _at: Vector2, _kind: String) -> void:
        contacts += 1
    func enemy_out_of_bounds(at: Vector2) -> bool:
        return at.y > 720.0

var passed: int = 0
var failed: int = 0
var game: BarrageGame
var viewport: SubViewport
var camera: Camera2D
var floor_body: StaticBody2D
var enemies: Array[Node2D] = []

func _initialize() -> void:
    call_deferred("start_watchdog")
    call_deferred("run")

func start_watchdog() -> void:
    var watchdog := Timer.new()
    watchdog.one_shot = true
    watchdog.wait_time = 8.0
    root.add_child(watchdog)
    watchdog.timeout.connect(func() -> void: push_error("Mob barrage test exceeded bounded 8-second deadline"); quit(1))
    watchdog.start()

func check(value: bool, label: String) -> void:
    if value:
        passed += 1
        print("PASS ", label)
    else:
        failed += 1
        push_error("FAIL " + label)

func make_enemy(kind: String, at: Vector2 = Vector2(250, 300)) -> CharacterBody2D:
    var enemy: CharacterBody2D = Enemy.new()
    enemy.configure(game, kind, at)
    enemy.facing = 1
    game.add_child(enemy)
    enemy.set_physics_process(false)
    enemy.hide()
    enemy._cooldown = 0.0
    enemies.append(enemy)
    return enemy

func reset_fixture() -> void:
    for enemy: Node2D in enemies:
        if is_instance_valid(enemy):
            enemy.free()
    enemies.clear()
    for shot: Node in get_nodes_in_group("projectiles"):
        if shot.get("game") == game:
            shot.clear()
    game.records.clear()
    game.attempts = 0
    game.reject_spawns = false
    game.story_safe = false
    game.player.revive(Vector2(450, 300))
    game.player.invuln = 0.0
    game.player.facing = -1

func open_barrage(enemy: Node) -> void:
    enemy._update_visibility(0.25)
    enemy._begin_attack(true)
    enemy._execute_attack()

func safe_ray_lane(pattern: String, layer: int, minimum_distance: float, gap_degrees: float) -> bool:
    for angle: float in Enemy.barrage_angles(pattern, layer):
        if absf(rad_to_deg(angle)) < gap_degrees - 0.001:
            return false
        if cos(angle) > 0.0 and minimum_distance * absf(sin(angle)) < 22.0:
            return false
    return true

func run() -> void:
    for action: String in ["move_left", "move_right", "jump", "dash", "attack", "parry"]:
        if not InputMap.has_action(action):
            InputMap.add_action(action)
    viewport = SubViewport.new()
    viewport.size = Vector2i(800, 450)
    viewport.world_2d = World2D.new()
    viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
    root.add_child(viewport)
    game = BarrageGame.new()
    game.hide()
    viewport.add_child(game)
    camera = Camera2D.new()
    camera.position = Vector2(400, 225)
    game.add_child(camera)
    camera.make_current()
    camera.force_update_scroll()
    game.player = Player.new()
    game.player.configure(game)
    game.add_child(game.player)
    game.player.set_physics_process(false)
    floor_body = StaticBody2D.new()
    floor_body.position = Vector2(700, 310)
    var floor_shape := CollisionShape2D.new()
    var rectangle := RectangleShape2D.new()
    rectangle.size = Vector2(1600, 20)
    floor_shape.shape = rectangle
    floor_body.add_child(floor_shape)
    game.add_child(floor_body)
    await physics_frame

    check(Enemy.barrage_angles("sentry_fork").size() == 4 and safe_ray_lane("sentry_fork", 0, 112.0, 12.0), "sentry has four rays and a collider-sized central safe lane")
    check(Enemy.barrage_angles("wisp_crown", 0).size() == 6 and Enemy.barrage_angles("wisp_crown", 1).size() == 6 and safe_ray_lane("wisp_crown", 0, 120.0, 15.0) and safe_ray_lane("wisp_crown", 1, 120.0, 15.0), "both six-ray wisp layers preserve a shared central corridor")
    check(Enemy.barrage_angles("elite_fan").size() == 8 and safe_ray_lane("elite_fan", 0, 144.0, 10.0), "elite fan has eight rays and an explicit approach lane")
    check(Enemy.barrage_angles("elite_wheel", 0).size() + Enemy.barrage_angles("elite_wheel", 1).size() <= 20 and safe_ray_lane("elite_wheel", 0, 144.0, 30.0) and safe_ray_lane("elite_wheel", 1, 144.0, 30.0), "open elite wheel stays within twenty rays and preserves its sixty-degree corridor")

    reset_fixture()
    var enemy: CharacterBody2D = make_enemy("sentry")
    enemy._begin_attack(true)
    check(enemy.attack_serial == 0 and game.attempts == 0, "newly seen enemy cannot skip screen acquisition warmup")
    enemy._update_visibility(0.24)
    enemy._begin_attack(true)
    check(enemy.attack_serial == 0, "warmup cannot finish one physics step early")
    enemy._update_visibility(0.01)
    enemy._begin_attack(true)
    check(enemy.attack_serial == 1 and is_equal_approx(enemy._windup, 0.62) and game.attempts == 0, "warmup is followed by a full visible sentry windup")
    var aim: Vector2 = enemy.barrage_aim
    game.player.position.y -= 40.0
    enemy._execute_attack()
    check(game.records.size() == 4 and enemy.barrage_aim == aim and enemy.get_pending_barrage_layers() == 0, "sentry emits four shots along the original aim instead of tracking the dodge")
    var styles_ok: bool = true
    for record: Dictionary in game.records:
        styles_ok = styles_ok and record.style == "sentry_shard" and is_equal_approx(Vector2(record.velocity).length(), 115.0)
    check(styles_ok, "sentry style and speed use the optional root projectile interface")

    reset_fixture()
    enemy = make_enemy("wisp", Vector2(250, 238))
    open_barrage(enemy)
    check(game.records.size() == 6 and enemy.get_pending_barrage_layers() == 1, "wisp emits one six-shot layer and schedules only one follow-up")
    enemy._advance_barrage(0.23)
    check(game.records.size() == 6, "wisp second layer waits for its explicit 240ms interval")
    enemy._advance_barrage(0.01)
    check(game.records.size() == 12 and enemy.get_pending_barrage_layers() == 0, "wisp completes exactly two layers and twelve shots")
    for _i: int in 60:
        enemy._advance_barrage(0.016)
    check(game.records.size() == 12 and enemy._cooldown >= 1.7, "completed barrage never turns into per-frame spawning")

    reset_fixture()
    enemy = make_enemy("elite")
    open_barrage(enemy)
    check(enemy.barrage_pattern == "elite_fan" and game.records.size() == 8, "elite starts with the distinct crown fan geometry")
    enemy._advance_barrage(1.0)
    check(game.records.size() == 16, "elite fan consumes only two layers even across a large frame")
    for shot: Node in get_nodes_in_group("projectiles"):
        if shot.get("game") == game:
            shot.clear()
    enemy._owned_shots.clear()
    game.records.clear()
    enemy._begin_attack(true)
    enemy._execute_attack()
    enemy._advance_barrage(1.0)
    check(enemy.barrage_pattern == "elite_wheel" and game.records.size() == 19, "next elite barrage alternates to nineteen-ray open wheels")

    reset_fixture()
    enemy = make_enemy("wisp", Vector2(250, 238))
    game.reject_spawns = true
    open_barrage(enemy)
    enemy._advance_barrage(5.0)
    for _i: int in 60:
        enemy._advance_barrage(1.0)
    check(game.attempts == 12 and enemy.get_pending_barrage_layers() == 0, "root cap rejection consumes finite attempts without retry flooding")

    for kind: String in ["sentry", "wisp", "elite"]:
        reset_fixture()
        enemy = make_enemy(kind, Vector2(250, 238 if kind == "wisp" else 300))
        for _i: int in 5:
            open_barrage(enemy)
            enemy._advance_barrage(1.0)
        var cap: int = 8 if kind == "sentry" else (18 if kind == "wisp" else 28)
        check(game.records.size() == cap and enemy._live_hostiles() == cap, "%s enforces its own %d-shot cap" % [kind, cap])

    reset_fixture()
    enemy = make_enemy("wisp", Vector2(250, 238))
    open_barrage(enemy)
    enemy.receive_hit(1, game.player.position)
    enemy._advance_barrage(1.0)
    check(game.records.size() == 6 and enemy.get_pending_barrage_layers() == 0 and enemy._windup == 0.0, "melee damage interrupts all queued later layers")

    reset_fixture()
    enemy = make_enemy("wisp", Vector2(250, 238))
    open_barrage(enemy)
    enemy.position.x = -100
    enemy._update_visibility(0.01)
    enemy._advance_barrage(1.0)
    check(game.records.size() == 6 and enemy.get_pending_barrage_layers() == 0 and enemy._visible_time == 0.0, "leaving the screen cancels unspawned layers and reacquisition progress")
    enemy.position = Vector2(25, 238)
    enemy._update_visibility(0.5)
    check(not enemy._emitter_visible() and enemy._visible_time == 0.0, "partially offscreen actor bounds cannot hide an edge ambush")

    reset_fixture()
    enemy = make_enemy("wisp", Vector2(250, 238))
    var wall := StaticBody2D.new()
    wall.position = Vector2(350, 250)
    var wall_collider := CollisionShape2D.new()
    var wall_rectangle := RectangleShape2D.new()
    wall_rectangle.size = Vector2(12, 150)
    wall_collider.shape = wall_rectangle
    wall.add_child(wall_collider)
    game.add_child(wall)
    await physics_frame
    enemy._update_visibility(0.25)
    enemy._begin_attack(true)
    check(enemy.attack_serial == 0 and game.attempts == 0, "solid wall visibility query blocks a barrage before windup")
    wall.free()
    await physics_frame
    open_barrage(enemy)
    var late_wall := StaticBody2D.new()
    late_wall.position = Vector2(350, 250)
    var late_collider := CollisionShape2D.new()
    late_collider.shape = wall_rectangle
    late_wall.add_child(late_collider)
    game.add_child(late_wall)
    await physics_frame
    enemy._advance_barrage(1.0)
    check(game.records.size() == 6 and enemy.get_pending_barrage_layers() == 0, "newly occluded locked corridor cancels the remaining layer")
    late_wall.free()
    await physics_frame

    reset_fixture()
    enemy = make_enemy("wisp", Vector2(250, 238))
    open_barrage(enemy)
    var reflected: Node2D = game.records[0].node.get_ref()
    reflected.position = game.player.position + Vector2(-18, -18)
    check(game.player._start_parry() and reflected.reflect(), "real mob projectile accepts a genuine front reflection")
    var source_id: int = enemy.get_instance_id()
    check(reflected.friendly and enemy._live_hostiles() == 5 and int(reflected.get_meta("mob_source_id")) == source_id, "reflection leaves source metadata while releasing the hostile source cap")
    enemy.receive_hit(99, game.player.position)
    check(enemy.dead and enemy.get_pending_barrage_layers() == 0 and reflected.friendly and not reflected._cleared, "enemy death clears its hostile barrage but preserves reflected friendly shots")

    reset_fixture()
    enemy = make_enemy("elite")
    game.player.revive(Vector2(285, 300))
    game.player.invuln = 0.0
    game.player.facing = -1
    check(game.player._start_parry(), "real player guard opens for retained melee attack")
    var contacts_before: int = game.contacts
    enemy._begin_attack()
    enemy._execute_attack()
    check(game.contacts == contacts_before + 1 and game.player.health == 8 and enemy._stagger >= 0.5 and game.records.is_empty(), "elite keeps interruptible contact-based melee parry instead of point-blank ranged fire")

    reset_fixture()
    enemy = make_enemy("wisp", Vector2(250, 238))
    open_barrage(enemy)
    enemy.set_impact_freeze(0.1)
    game.story_safe = true
    enemy._physics_process(0.01)
    enemy._advance_barrage(1.0)
    check(enemy.combat_freeze == 0.0 and enemy.get_pending_barrage_layers() == 0 and enemy._live_hostiles() == 0 and game.records.size() == 6, "rest overrides local hold and clears all old hostile layers safely")

    reset_fixture()
    enemy = make_enemy("sentry")
    enemy.patrol_bounds = Rect2(200, 180, 300, 144)
    game.player.position = Vector2(450, 90)
    enemy._update_visibility(0.25)
    enemy._begin_attack(true)
    check(enemy.attack_serial == 0, "walker refuses ranged attacks against a different patrol layer")
    enemy.position.x = 490
    game.player.position = Vector2(550, 300)
    enemy._update_walker(game.player.position - enemy.position, 0.05)
    check(enemy.velocity.x <= 0.0, "walker returns home rather than chasing beyond its room")
    enemy.position.x = 520
    enemy.velocity.x = 80.0
    enemy._keep_in_patrol()
    check(enemy.position.x <= 492.0 and enemy.velocity.x == 0.0, "walker clamps horizontal room overshoot without cross-floor navigation")
    reset_fixture()
    enemy = make_enemy("wisp", Vector2(250, 238))
    enemy.patrol_bounds = Rect2(200, 140, 300, 170)
    enemy.position = Vector2(510, 330)
    enemy.velocity = Vector2(80, 35)
    enemy._keep_in_patrol()
    check(enemy.position.x <= 492.0 and enemy.position.y <= 302.0 and enemy.velocity == Vector2.ZERO, "wisp patrol constrains both axes within its assigned layer")

    reset_fixture()
    camera.position = Vector2(400, 600)
    camera.force_update_scroll()
    floor_body.position.y = 610
    game.player.position = Vector2(450, 600)
    enemy = make_enemy("sentry", Vector2(250, 600))
    await physics_frame
    open_barrage(enemy)
    check(enemy._emitter_visible() and game.records.size() == 4 and not enemy.dead, "full actor bounds and barrage acquisition follow an 800x450 camera into lower rooms")
    enemy._physics_process(0.0)
    check(not enemy.dead, "lower room mobs remain alive below the old ground-plane height")
    enemy.position.y = 730
    enemy._physics_process(0.0)
    check(enemy.dead, "root fall-limit contract still removes truly fallen mobs")
    reset_fixture()
    viewport.free()
    await process_frame
    print("Mob barrage: %d passed, %d failed" % [passed, failed])
    quit(1 if failed > 0 else 0)

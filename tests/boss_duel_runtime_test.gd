extends SceneTree
const Boss = preload("res://combat/boss.gd")
const Player = preload("res://actors/player.gd")
const Music = preload("res://audio/music_director.gd")
const Planner = preload("res://combat/friend_rhythm/boss_attack_planner.gd")
const Hazard = preload("res://combat/boss_hazard.gd")
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
    var damage_calls: int = 0
    func announce(_message: String, _seconds: float = 3.0) -> void: pass
    func emit_fx(_kind: String, _at: Vector2, _direction: Vector2 = Vector2.ZERO, _power: float = 1.0) -> void: pass
    func on_boss_phase(_section: String) -> void: pass
    func on_boss_defeated() -> void: pass
    func hero_attack(_source: Node2D, _damage: int, _reach: float, _combo: int) -> void: pass
    func damage_player(amount: int, origin: Vector2) -> void:
        damage_calls += 1
        player.receive_hit(amount, origin)
    func on_parry_contact(defender: Node, source: Node, _at: Vector2, _kind: String) -> void:
        contacts += 1
        defender.set_impact_freeze(0.06)
        source.set_impact_freeze(0.06)
    func spawn_projectile(_at: Vector2, _velocity: Vector2, _friendly: bool = false, _style: String = "default") -> Node2D: return null
    func spawn_boss_hazard(hazard: Node2D) -> bool:
        if story_safe: hazard.queue_free(); return false
        add_child(hazard)
        hazard.set_physics_process(false)
        return true
    func clear_boss_hazards() -> void:
        for hazard: Node in get_tree().get_nodes_in_group("boss_hazards"): hazard.clear()
    func set_story_safe(value: bool) -> void:
        story_safe = value
        if value: clear_boss_hazards()
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
    var wall := StaticBody2D.new()
    wall.position = at
    var shape := CollisionShape2D.new()
    var rectangle := RectangleShape2D.new()
    rectangle.size = size
    shape.shape = rectangle
    wall.add_child(shape)
    game.add_child(wall)
    return wall
func reset(game: Game) -> void:
    game.story_safe = false
    game.outcome = ""
    game.boss._cancel_all_attacks()
    game.boss._clear_reaction()
    game.boss.combat_freeze = 0.0
    game.boss._posture_lockout = 0.0
    game.boss.guard_posture = 0
    game.boss.dead = false
    game.boss._active = true
    game.boss.position = Vector2(3000, 300)
    game.boss.velocity = Vector2.ZERO
    game.boss.facing = 1
    game.player.revive(Vector2(3060, 300))
    game.player.facing = -1
    game.player.invuln = 0.0
func blade(game: Game, clip: String, p: float, token: int, armored: bool = false) -> void:
    game.boss._clear_reaction()
    game.boss.combat_freeze = 0.0
    game.boss._contact_resolved = false
    game.boss.contact_token = token
    game.boss._start_blade(clip, 0.22, token, true, armored)
    game.boss._blade_elapsed = 0.22 * p
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
    game.music.set_process(false)
    game.music._dummy = true
    game.boss = Boss.new()
    game.add_child(game.boss)
    game.boss.configure(game, Vector2(3000, 300))
    game.boss.set_physics_process(false)
    game.boss.set_duel_enabled(false)
    game.music.start_score()
    await physics_frame
    reset(game)
    blade(game, "cut_a", 0.05, 800)
    game.boss._sample_blade(1.0 / 60.0)
    check(game.player.health == 8 and not game.boss.get_blade_state()["active"], "visible preparation frame has no hidden contact damage")
    blade(game, "cut_a", 0.35, 801)
    var state: Dictionary = game.boss.get_blade_state()
    check(state["active"] and int(state["frame"]) == 1 and (state["to"] as Vector2).x > 60, "active blade matches actual mirrored pixel frame landmarks")
    game.boss._sample_blade(1.0 / 60.0)
    check(game.player.health == 7, "real visible steel intersects actual player collider and deals one damage")
    game.boss._sample_blade(1.0 / 60.0)
    check(game.player.health == 7, "same blade token cannot repeatedly damage")
    reset(game)
    blade(game, "cut_b", 0.65, 802)
    game.boss._sample_blade(1.0 / 60.0)
    check(game.player.health == 8, "old78px box overlap is harmless when the actual upstroke misses")
    reset(game)
    check(game.player._start_parry(), "real defender opens physical parry window")
    blade(game, "cut_a", 0.35, 803)
    var before: int = game.contacts
    game.boss._sample_blade(1.0 / 60.0)
    check(game.contacts == before + 1 and game.player.health == 8 and game.boss.reaction_state == "parry_recoil", "pixel steel contact accepts front parry and ordinary recoil")
    check(game.boss._blade_clip.is_empty() and game.boss._duel_state.is_empty(), "ordinary accepted contact cancels current extra melee and blade history")
    reset(game)
    for i: int in 3:
        game.player.revive(Vector2(3060, 300))
        game.player.facing = -1
        game.player._start_parry()
        blade(game, "cut_a", 0.35, 810 + i, true)
        game.boss._sample_blade(1.0 / 60.0)
    check(game.boss.guard_posture == 3 and game.boss.reaction_state == "guard_break", "three genuine armored steel contacts open guard break")
    reset(game)
    var wall: StaticBody2D = body(game, Vector2(3050, 220), Vector2(20, 160))
    await physics_frame
    var dash_action: Dictionary = {"type": "dash", "time": 0.0, "duration_beats": 1.0, "source_pattern": "fan_then_dash", "source_serial": 20, "source_index": 1, "resolved_target": Vector2(3140, 300), "source_locked_target": Vector2(3140, 300)}
    game.boss._execute_authored_action(dash_action, 0.0)
    game.boss._advance_authored_dash(game.music.seconds_per_beat())
    check(game.boss.position.x <= 3027.1 and game.boss.position.x >= 3000, "source dash stops at real internal wall rather than lerping through")
    game.player.position = Vector2(3100, 300)
    blade(game, "cut_a", 0.35, 850)
    game.boss._sample_blade(1.0 / 60.0)
    check(game.player.health == 8, "steel cannot damage a target beyond a wall even if tip extends through")
    wall.queue_free()
    await physics_frame
    reset(game)
    var pattern: Dictionary = game.boss.friend_slots.get_normal_pattern(0)
    var old_target: Vector2 = Vector2(3100, 300)
    var preview: Dictionary = Planner.build_plan(pattern, 0.0, game.music.seconds_per_beat(), game.boss.position, old_target, Boss.PLAN_ARENA)
    game.player.position = Vector2(3180, 300)
    game.boss._begin_authored_pattern(pattern, 0.0, Vector2.INF, preview)
    check(game.boss._locked_target.x == 3180, "normal source locks at phrase start rather than prepared preview")
    var first_aim: Dictionary = game.boss._authored_actions[0]
    game.player.position.x = 3240
    game.boss._execute_authored_action(first_aim, 0.0)
    check(game.boss._warning_geometry["locked_target"].x == 3180, "ordinary aim does not track player after phrase lock")
    reset(game)
    pattern = game.boss.friend_slots.get_fast_pattern(2)
    pattern["pattern_id"] = "fast_3"
    game.player.position.x = 3100
    game.boss._begin_authored_pattern(pattern, 0.0)
    var second_aim: Dictionary = game.boss._authored_actions[2]
    game.player.position.x = 3160
    game.boss._execute_authored_action(second_aim, game.music.seconds_per_beat() * 2.0)
    var second_dash: Dictionary = game.boss._authored_actions[3]
    check(second_dash["resolved_target"].x == 3160 and game.boss._warning_geometry["locked_target"].x == 3160, "fast3 second aim alone relocks its next dash and shared warning")
    game.player.position.x = 3260
    game.boss._execute_authored_action(second_dash, game.music.seconds_per_beat() * 3.0)
    check(game.boss._authored_dash["to"].x == 3160, "fast3 target stays fixed again after its second aim")
    reset(game)
    var shift_action: Dictionary = {"type": "teleport", "time": 0.0, "source_pattern": "side_sweep_spray", "source_serial": 30, "source_index": 0, "resolved_target": Vector2(2690, 300)}
    game.boss._execute_authored_action(shift_action, 0.0)
    check(game.boss.position == Vector2(3000, 300) and not game.boss._authored_shift.is_empty(), "source teleport now begins readable motion without an instant position snap")
    game.boss._advance_authored_shift(0.01)
    check(game.boss.position.x < 3000 and game.boss.position.x > 2690, "short source shift advances through collision-aware movement")
    reset(game)
    var source_count: int = game.boss.authored_pattern_count
    game.boss.set_duel_enabled(true)
    game.boss._duel_cooldown = 0.0
    game.boss._try_duel_on_beat()
    check(game.boss._duel_state == "draw" and game.boss.extra_attacks > 0 and game.boss.authored_pattern_count == source_count, "gap-only extra double slash has an independent counter and a visible windup")
    game.story_safe = true
    game.boss._on_section("rest")
    check(not game.boss.get_navigation_status()["pending"] and not game.boss.get_blade_state()["active"], "rest cancels extra movement, blade and source displacement")
    reset(game)
    game.player.position = Vector2(3120, 300)
    check(game.boss.try_navigation_jump(game.player.position, true), "damaging leap starts from a real supported floor and locks landing")
    for i: int in 70:
        game.boss._physics_process(1.0 / 60.0)
        await physics_frame
    check(game.player.health < 8, "actual airborne slam steel reaches the stationary locked target before landing")
    game.queue_free()
    await process_frame
    await process_frame
    print("BOSS DUEL RUNTIME: %d passed, %d failed" % [passed, failed])
    quit(1 if failed > 0 else 0)

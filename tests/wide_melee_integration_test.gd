extends SceneTree
var passed: int = 0
var failed: int = 0
class Target extends CharacterBody2D:
    var health: int = 20
    var dead: bool = false
    var combat_freeze: float = 0.0
    func _ready() -> void:
        collision_layer=4
        collision_mask=0
        add_to_group("enemies")
        var collider := CollisionShape2D.new()
        var shape := RectangleShape2D.new()
        shape.size=Vector2(14,26)
        collider.shape=shape
        collider.position=Vector2(0,-13)
        add_child(collider)
    func receive_hit(damage: int,_origin: Vector2) -> void:
        health-=damage
    func set_impact_freeze(seconds: float) -> void:
        combat_freeze=maxf(combat_freeze,seconds)
func check(ok: bool,label: String) -> void:
    if ok: passed+=1
    else:
        failed+=1
        push_error("FAIL "+label)
func _initialize() -> void:
    call_deferred("run")
func run() -> void:
    var game: Node=load("res://main.tscn").instantiate()
    root.add_child(game)
    current_scene=game
    await process_frame
    game.set_physics_process(false)
    game.set_process(false)
    game.player.set_physics_process(false)
    game.music.stop_score()
    game.music.set_process(false)
    for enemy: Node in get_nodes_in_group("enemies"): enemy.set_physics_process(false)
    var target := Target.new()
    target.position=Vector2(2950,300)
    game.add_child(target)
    var behind := Target.new()
    behind.position=Vector2(2760,300)
    game.add_child(behind)
    var beyond := Target.new()
    beyond.position=Vector2(3060,300)
    game.add_child(beyond)
    await physics_frame
    var player: Node=game.player
    player.position=Vector2(2800,300)
    player.facing=1
    player.combo=1
    player.attack_phase="active"
    player.attack_sweep_from=0.45
    player.attack_sweep_to=0.55
    player.attack_serial=501
    game.hero_attack(player,1,42,1)
    check(target.health==19,"main gameplay really hits at 150px beyond the old 42px reach")
    check(behind.health==20 and beyond.health==20,"main scene rejects rear and outside-range targets")
    player.combat_freeze=0
    game.hero_attack(player,1,42,1)
    game.hero_attack(player,1,42,1)
    check(target.health==19,"root serial ledger prevents repeated sweep rewards")
    var wall := StaticBody2D.new()
    wall.collision_layer=1
    var collider := CollisionShape2D.new()
    var rect := RectangleShape2D.new()
    rect.size=Vector2(12,100)
    collider.shape=rect
    wall.add_child(collider)
    wall.position=Vector2(2870,270)
    game.add_child(wall)
    await physics_frame
    player.attack_serial+=1
    player.combat_freeze=0
    game.hero_attack(player,1,9999,1)
    check(target.health==19,"large sweep does not penetrate a real scene wall")
    wall.queue_free()
    await physics_frame
    player.attack_phase="recover"
    player.attack_serial+=1
    game.hero_attack(player,1,9999,1)
    check(target.health==19,"recover does not query stale attack geometry")
    player.attack_phase="active"
    game.set_story_safe(true)
    game.hero_attack(player,1,9999,1)
    check(target.health==19,"story rest rejects enlarged melee damage")
    game.set_story_safe(false)
    game._set_overlay("pause")
    var mode: int=game.speed_effects_level
    var key := InputEventKey.new()
    key.pressed=true
    key.physical_keycode=KEY_F3
    game._unhandled_input(key)
    check(game.speed_effects_level==(mode+1)%3 and game._hud.state["speed_effects_level"]==game.speed_effects_level,"speed-feedback setting changes and refreshes while paused")
    game._set_overlay("")
    game._start_boss()
    game.music.stop_score()
    game.music.set_process(false)
    game.boss.set_physics_process(false)
    game.boss._begin_attack("slash")
    game.boss.receive_hit(1,Vector2(2800,300))
    check(game.boss.get_presentation_pose()["state"]=="draw","a hit does not hide a still-live Boss windup")
    var before: Dictionary=game.boss.get_presentation_pose()
    game.boss.set_impact_freeze(0.06)
    game.boss._physics_process(0.03)
    var after: Dictionary=game.boss.get_presentation_pose()
    check(before["state"]==after["state"] and is_equal_approx(float(before["progress"]),float(after["progress"])),"Boss authored pose stays on its actual local freeze")
    game.set_story_safe(true)
    game.music.stop_score()
    game.free()
    print("Wide melee integration: %d passed, %d failed" % [passed,failed])
    quit(1 if failed else 0)

extends SceneTree
## Bounded interface/cleanup/performance probes. Never navigates or plays the level.
var passed: int = 0
var failed: int = 0
var game: Node
var finished: bool = false

func check(ok: bool, label: String) -> void:
    if ok:
        passed += 1
    else:
        failed += 1
        push_error("FAIL " + label)

func _initialize() -> void:
    call_deferred("run")
    create_timer(20.0,true,false,true).timeout.connect(func() -> void:
        if not finished:
            push_error("FAIL bounded main scene migration timeout")
            quit(1))

func freeze() -> void:
    game.set_physics_process(false)
    game.set_process(false)
    game.player.set_physics_process(false)
    game.music.stop_score()
    # Full-song stop intentionally enters safety; reopen only this static combat fixture.
    game.set_story_safe(false)
    game.music.set_process(false)
    game.effects.set_process(false)
    game.level.set_process(false)
    for enemy: Node in get_nodes_in_group("enemies"):
        enemy.set_physics_process(false)

func reload(full: bool) -> void:
    game._reload(full)
    await process_frame
    await process_frame
    game = current_scene
    freeze()

func run() -> void:
    root.size = Vector2i(800, 450)
    game = load("res://main.tscn").instantiate()
    root.add_child(game)
    current_scene = game
    await process_frame
    freeze()
    check(ProjectSettings.get_setting("display/window/size/viewport_width") == 800 and ProjectSettings.get_setting("display/window/size/viewport_height") == 450, "logical viewport truly increases to 800x450")
    check(ProjectSettings.get_setting("display/window/stretch/scale_mode") == "integer", "integer presentation retained")
    check(get_nodes_in_group("enemies").size() == 11, "main scene loads all eleven authored encounters")
    var jump_keys: Array = InputMap.action_get_events("jump")
    check(jump_keys.size() == 1 and jump_keys[0].physical_keycode == KEY_SPACE, "jump and climb cannot share a W/up input edge")
    check(InputMap.has_action("climb_up") and InputMap.has_action("climb_down") and InputMap.has_action("interact"), "traversal/door bindings installed")
    var high: Vector2 = game.camera_target(Vector2(1300, 48))
    var low: Vector2 = game.camera_target(Vector2(1300, 500))
    check(low.y - high.y > 250, "camera follows actual upper and lower rooms")
    for at: Vector2 in [Vector2(-1000,-1000),Vector2(5000,5000),Vector2(1300,500)]:
        var camera: Vector2 = game.camera_target(at)
        check(camera.x >= 400 and camera.x <= game.room_spec["bounds"].end.x-400 and camera.y >= game.room_spec["bounds"].position.y+225 and camera.y <= game.room_spec["bounds"].end.y-225, "camera retains native viewport bounds")
    game.player.position = Vector2(1862, 500)
    game._physics_process(0)
    check(not game.checkpoint_active, "same x in another layer cannot activate shrine")
    game.player.position = Vector2(676, 500)
    Input.action_press("interact")
    game._physics_process(0)
    Input.action_release("interact")
    check(game.level.door_states.get("crypt_door", false), "root E input opens nearby physical crypt door")
    check(get_meta_or_default("bellkeep_doors", []).has("crypt_door"), "accepted interaction persists stable door id")
    await reload(false)
    check(game.level.door_states.get("crypt_door", false), "retry restores opened door")
    await reload(true)
    check(not game.level.door_states.get("crypt_door", false) and not has_meta("bellkeep_doors"), "new journey clears door progress")
    game.player.position = Vector2(800,500)
    game._refresh_hud()
    check(game._hud.state["zone"] == "淤水墓廊", "HUD resolves room by two-dimensional location")
    var serial: int = game.player.attack_serial
    game._set_overlay("map")
    Input.action_press("attack")
    await process_frame
    await process_frame
    Input.action_release("attack")
    check(paused and game._paused and game._hud.state["overlay"] == "map" and game.player.attack_serial == serial, "map owns pause and does not leak an attack into the world")
    var previous_motion: bool = game.impact.reduced_motion
    var toggle := InputEventKey.new()
    toggle.pressed = true
    toggle.physical_keycode = KEY_F2
    game._unhandled_input(toggle)
    check(game._hud.state["reduced_motion"] != previous_motion, "F2 refreshes its displayed state while map is paused")
    game._set_overlay("")
    check(not paused and not game._paused, "closing map restores the single pause state")
    for canvas: Vector2 in [Vector2(800,450),Vector2(960,540),Vector2(640,360)]:
        var boxes: Dictionary = game._hud.panel_layout(canvas)
        for label: String in boxes:
            check(Rect2(Vector2.ZERO,canvas).encloses(boxes[label]), "HUD panel %s remains inside %s" % [label,canvas])
    for style: String in ["sentry_shard","wisp_seed","elite_rune"]:
        var shot: Node2D = game.spawn_projectile(Vector2(20,-100),Vector2.RIGHT*80,false,style)
        shot.set_physics_process(false)
        check(shot.style == style, "styled mob core retained: "+style)
        shot.friendly = true
        check(shot.core_color() == Color("73f6df"), "reflected core always cyan: "+style)
        shot.clear()
    var friendly: Node2D = game.spawn_projectile(Vector2(20,-100),Vector2.RIGHT*80,true)
    friendly.set_physics_process(false)
    for index: int in 179:
        var shot: Node2D = game.spawn_projectile(Vector2(20,-100),Vector2.RIGHT*80,false,"sentry_shard")
        shot.set_physics_process(false)
    check(get_nodes_in_group("projectiles").size() == 180 and game.spawn_projectile(Vector2.ZERO,Vector2.ONE) == null, "global cap rejects the 181st shot")
    check(is_instance_valid(friendly) and not friendly._cleared, "capacity never evicts a friendly reflection")
    var start_usec: int = Time.get_ticks_usec()
    for tick: int in 60:
        for shot: Node in get_nodes_in_group("projectiles"):
            shot._physics_process(1.0/60.0)
    print("Projectile probe: 180 shots x 60 ticks, ", (Time.get_ticks_usec()-start_usec)/1000.0, " ms CPU")
    check(get_nodes_in_group("projectiles").size() <= 180, "bounded 180-shot probe retains cap")
    game.set_story_safe(true)
    check(get_nodes_in_group("projectiles").is_empty() and game.spawn_projectile(Vector2.ZERO,Vector2.ONE) == null, "rest clears both factions and rejects new hostile generation")
    game.set_story_safe(false)
    game.elite_defeated = true
    game.player.position = Vector2(2650,-40)
    game._physics_process(0)
    check(not game.boss_started, "another layer does not start Boss by x alone")
    game.player.position = Vector2(2650,300)
    game._physics_process(0)
    check(not game.boss_started and game.room_id == "dungeon", "former floor/x threshold no longer auto-starts the Boss")
    var retired_level: Node = game.level
    game._start_boss()
    check(game.room_id == "boss", "explicit integration hook enters the independent Boss room")
    check(game.level.get_script().resource_path == "res://levels/boss_chamber.gd", "main mounts the real Boss chamber script")
    check(game.level != retired_level and retired_level.get_parent() == null, "Boss hook removes the former dungeon tree")
    game.music.stop_score()
    # Full-song stop intentionally enters safety; reopen only this static combat fixture.
    game.set_story_safe(false)
    game.music.set_process(false)
    if is_instance_valid(game.boss): game.boss.set_physics_process(false)
    check(game.boss_started and is_instance_valid(game.boss), "explicit Boss entry activates in its own actual court")
    for screen: String in ["pause","map",""]:
        game._set_overlay(screen)
        game._hud.queue_redraw()
        await process_frame
    game._set_overlay("")
    game.set_story_safe(true)
    game.free()
    finished = true
    print("Dungeon integration: %d passed, %d failed" % [passed,failed])
    quit(1 if failed else 0)

func get_meta_or_default(key: String, fallback: Variant) -> Variant:
    return get_meta(key, fallback)

extends SceneTree
## Short real-room lifecycle fixtures; no level traversal/input playback.
var passed: int = 0
var failed: int = 0
var game: Node
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
    if ok: passed += 1
    else: failed += 1; push_error("FAIL " + label)
func freeze() -> void:
    game.set_process(false)
    game.set_physics_process(false)
    game.player.set_physics_process(false)
    game.music.set_process(false)
    for enemy: Node in get_nodes_in_group("enemies"): enemy.set_physics_process(false)
func flow_step(dt: float) -> void:
    game._process(dt)
    game.player.set_physics_process(false)
    if is_instance_valid(game.boss): game.boss.set_physics_process(false)
    await process_frame
func _all_platforms_are_one_way(room: Node) -> bool:
    var found: bool = false
    for body: Node in room.get_children():
        if body is StaticBody2D:
            found = true
            if body.collision_layer != 1 or body.collision_mask != 0:
                return false
            for child: Node in body.get_children():
                if child is CollisionShape2D and not child.one_way_collision:
                    return false
    return found
func reload_scene(full: bool) -> void:
    game._reload(full)
    await process_frame
    await process_frame
    game = current_scene
    freeze()
func run() -> void:
    root.size = Vector2i(800,450)
    for key: String in ["bellkeep_room","bellkeep_checkpoint","bellkeep_elite","bellkeep_doors","bellkeep_shards","bellkeep_chapter_complete"]:
        if has_meta(key): remove_meta(key)
    game = load("res://main.tscn").instantiate()
    root.add_child(game)
    current_scene = game
    await process_frame
    freeze()
    check(game.room_id == "dungeon" and not is_instance_valid(game.boss), "starts in dungeon with no hidden Boss")
    check(get_nodes_in_group("enemies").size() == 11, "existing authored mobs remain in dungeon")
    game.player.position = Vector2(2560,300)
    check(not game.interact_portal() and game.room_id == "dungeon", "elite seal prevents early portal")
    game.elite_defeated = true
    set_meta("bellkeep_elite",true)
    game.checkpoint_active = true
    set_meta("bellkeep_checkpoint",true)
    check(game.interact_portal() and not game.room_flow.active, "first E only requests explicit confirmation")
    check(game.interact_portal() and not game.room_flow.active, "same physics edge cannot also confirm")
    game._process(3.10)
    check(game._portal_confirm_room.is_empty() and not game.room_flow.active, "confirmation expires without changing rooms")
    await physics_frame
    check(game.interact_portal() and not game.room_flow.active, "E after expiry only requests confirmation again")
    await physics_frame
    check(game.interact_portal() and game.room_flow.active, "second independent E starts transition")
    var old_level: WeakRef = weakref(game.level)
    var old_enemy: WeakRef = weakref(get_nodes_in_group("enemies")[0])
    var old_shot: Node = game.spawn_projectile(Vector2(2500,270),Vector2.RIGHT)
    check(old_shot == null, "transition refuses new hostile or friendly projectiles")
    var before: int = game.player.health
    game.damage_player(1,game.player.position)
    check(game.player.health == before and not game.music.running and not game.player.is_physics_processing(), "transition locks movement, damage and score")
    check(not game.begin_room_transition("boss"), "transition cannot be reentered")
    await flow_step(0.20)
    check(game.room_id == "dungeon" and not game.music.running, "old room retained through fade-out")
    game._set_overlay("pause")
    var progress: float = game.room_flow.progress
    game._process(1.0)
    check(game.room_flow.progress == progress and not game.music.running, "pause freezes transition without starting score")
    game._set_overlay("")
    await flow_step(0.16)
    await process_frame
    check(game.room_id == "boss" and game.level.get_script().resource_path.ends_with("boss_room.gd"), "black interval mounts actual independent Boss scene")
    check(old_level.get_ref() == null and old_enemy.get_ref() == null and get_nodes_in_group("enemies").is_empty(), "old dungeon tree and all mobs are freed before Boss spawn")
    check(game.room_spec["shard_indices"] == [11] and not game.music.running and not is_instance_valid(game.boss), "Boss shard and preparation are room-specific; song still stopped")
    check(game.player.position.distance_to(Vector2(2706,300)) < 1.0 and not game.player.climbing and game.player.dash_timer == 0.0 and game.player.attack_phase == "none", "entry spawn resets traversal, dash and combat state")
    await flow_step(0.48)
    check(not game.room_flow.active and game.boss_started and is_instance_valid(game.boss) and game.music.running, "only prepared room finish starts Boss and the sole score")
    check(get_nodes_in_group("enemies").size() == 1 and get_nodes_in_group("enemies")[0] == game.boss, "Boss room contains exactly its own Boss")
    check(game._hud.state["room_id"] == "boss" and game._hud.state["room_bounds"] == game.level.get_map_bounds(game.player.position), "HUD receives the moving Boss-room bounds")
    check(game.player.get("flight_enabled") == true and game.boss.get("infinite_room") == true, "prepared Boss room enables sustained flight for hero and Boss")
    check(_all_platforms_are_one_way(game.level), "infinite Boss room exposes only layer-1 one-way platforms")
    var camera: Vector2 = game.camera_target(Vector2(5000,-2000))
    check(camera == Vector2(5045,-2090), "Boss camera follows infinitely beyond the old room bounds")
    check(not game.interact_portal(), "combat prevents accidental return portal")
    var old_boss: WeakRef = weakref(game.boss)
    game.player.health = 1
    game.player.invuln = 0.0
    game.damage_player(1,game.boss.position)
    check(game.outcome == "defeat" and not game.music.running, "Boss defeat stops score")
    await reload_scene(false)
    check(old_boss.get_ref() == null and game.room_id == "boss" and game.player.health == game.player.max_health, "R retries in Boss room, preserving completed dungeon")
    check(game.player.get("flight_enabled") == true, "Boss retry restores sustained flight during direct scene initialization")
    check(_all_platforms_are_one_way(game.level), "Boss retry keeps the one-way platform contract")
    await flow_step(0.30)
    check(game.boss_started and game.music.running and game.boss.get("infinite_room") == true, "Boss retry gets a fresh infinite-flight encounter after preparation")
    game.on_boss_defeated()
    check(get_meta("bellkeep_chapter_complete",false) and game.outcome == "victory", "victory records chapter completion")
    game._portal_press_frame = -1
    check(game.interact_portal() and not game.room_flow.active, "victory E requests return from anywhere")
    await physics_frame
    check(game.interact_portal() and game.room_flow.active, "victory second E confirms return")
    await flow_step(0.36)
    await flow_step(0.48)
    check(game.room_id == "dungeon" and not is_instance_valid(game.boss) and not game.music.running and game.elite_defeated, "return restores dungeon threshold without losing elite record or retaining Boss")
    check(game.player.get("flight_enabled") == false, "returning to the dungeon restores grounded movement")
    check(game.begin_room_transition("boss"), "return threshold can begin a new portal transition")
    await flow_step(0.10)
    await reload_scene(false)
    check(game.room_id == "dungeon" and not game.room_flow.active and not game.music.running, "R before mount cancels transition and reloads the stable dungeon room")
    await reload_scene(true)
    check(game.room_id == "dungeon" and not game.elite_defeated and not has_meta("bellkeep_room"), "F5 starts fresh dungeon and clears room checkpoint")
    game.queue_free()
    await process_frame
    await process_frame
    print("Room lifecycle: %d passed, %d failed" % [passed,failed])
    quit(1 if failed else 0)

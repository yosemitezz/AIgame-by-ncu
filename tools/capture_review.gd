extends SceneTree
## Deterministic visual contact sheets: fixed poses, no automated playthrough.
var game: Node
var output: String = "res://artifacts/"

func _initialize() -> void:
    call_deferred("run")

func settle() -> void:
    await process_frame
    await process_frame
    await RenderingServer.frame_post_draw

func capture(name: String) -> void:
    game._refresh_hud()
    await settle()
    var result: int = root.get_texture().get_image().save_png(output + name + ".png")
    print("CAPTURE ", name, " ", result)

func freeze_actors() -> void:
    game.set_physics_process(false)
    game.player.set_physics_process(false)
    for actor: Node in get_nodes_in_group("enemies"):
        actor.set_physics_process(false)

func place_player(at: Vector2, state: String = "idle", frame: int = 0) -> void:
    game.player.position = at
    game.player.animation_state = state
    game.player.frame = frame
    game.player.invuln = 0
    game.player.queue_redraw()
    game._camera.position.x = clampf(at.x, 320, 3060)
    for i: int in game.level.ZONES.size():
        if at.x >= game.level.ZONES[i]["x"]:
            game._zone = i

func run() -> void:
    root.size = Vector2i(640, 360)
    game = load("res://main.tscn").instantiate()
    root.add_child(game)
    await process_frame
    freeze_actors()
    place_player(Vector2(220, 300), "attack", 2)
    game.emit_fx("slash", Vector2(244, 281), Vector2.RIGHT, 2)
    await capture("01-teaching-nave")
    game._announcement_time = 0
    place_player(Vector2(648, 168), "jump", 1)
    await capture("02-platform-exploration")
    place_player(Vector2(1940, 300))
    game.checkpoint_active = true
    game.emit_fx("checkpoint", Vector2(1860, 275), Vector2.UP, 2)
    await capture("03-checkpoint-elite")
    game.elite_defeated = true
    if is_instance_valid(game._elite_gate):
        game._elite_gate.queue_free()
        game._elite_gate = null
    game._start_boss()
    game.music.stop_score()
    game.music.set_process(false)
    game.boss.set_physics_process(false)
    game.boss.position = Vector2(3030, 300)
    game.boss.phase = "random"
    game.music.current_section = "random"
    game._announcement_time = 0
    place_player(Vector2(2840, 300), "parry", 1)
    game.boss.animation_state = "windup"
    game.boss.queue_redraw()
    for i: int in 10:
        var angle: float = -2.7 + float(i) * 0.25
        var p: Node = game.spawn_projectile(Vector2(3030, 274) + Vector2.from_angle(angle) * 95, Vector2.from_angle(angle) * 100)
        p.set_physics_process(false)
    game.emit_fx("parry", Vector2(2860, 280), Vector2.RIGHT, 1.4)
    await capture("04-boss-golden-starfall")
    game.music._set_section("rest")
    await capture("05-story-rest-safety")
    game.on_boss_defeated()
    game._ending_clock = 5
    await capture("06-chapter-end")
    quit()


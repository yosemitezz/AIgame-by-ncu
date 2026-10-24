extends SceneTree
## Fixed visual studies only; every actor is frozen, no route is played.
var game: Node
func _initialize() -> void:
    call_deferred("run")
func settle() -> void:
    await process_frame
    await process_frame
    await RenderingServer.frame_post_draw
func shot(label: String) -> void:
    game._refresh_hud()
    game._hud.queue_redraw()
    await settle()
    var error: int = root.get_texture().get_image().save_png("res://artifacts/"+label+".png")
    print("CAPTURE ",label," ",error)
func pose(at: Vector2,state: String,frame: int=0) -> void:
    game.player.position=at
    game.player.animation_state=state
    game.player.frame=frame
    game.player.invuln=0
    game.player.velocity=Vector2.ZERO
    game.player.parry_phase="none"
    game.player.attack_phase="none"
    game.player.climbing=false
    game._camera.position=game.camera_target(at,1)
    game.player.queue_redraw()
func run() -> void:
    root.size=Vector2i(800,450)
    game=load("res://main.tscn").instantiate()
    root.add_child(game)
    current_scene=game
    await process_frame
    game.set_process(false)
    game.set_physics_process(false)
    game.player.set_physics_process(false)
    game.music.stop_score()
    game.music.set_process(false)
    game.level.set_process(false)
    game.effects.set_process(false)
    for enemy: Node in get_nodes_in_group("enemies"):
        enemy.set_physics_process(false)
    game._announcement_time=0
    pose(Vector2(820,500),"run",2)
    game.emit_fx("water_splash",Vector2(820,499),Vector2.RIGHT,0.8)
    game.effects._process(0.04)
    for index: int in 6:
        var p: Node=game.spawn_projectile(Vector2(910+index*13,424+index*8),Vector2.LEFT*90,false,"wisp_seed")
        p.set_physics_process(false)
    game.effects._track_projectiles()
    await shot("dungeon-01-water-crypt")
    for p: Node in get_nodes_in_group("projectiles"):
        p.clear()
    game.effects.clear_hostile()
    pose(Vector2(1176,200),"climb",2)
    game.player.climbing=true
    game.player.climb_kind="chain"
    game.player.queue_redraw()
    await shot("dungeon-02-chain")
    pose(Vector2(1435,48),"attack",2)
    game.player.combo=2
    game.player.attack_serial=37
    game.player.attack_phase="active"
    game.player._phase_elapsed=0.05
    game.player.queue_redraw()
    game.emit_fx("slash",game.player.position+Vector2(22,-18),Vector2.RIGHT,2)
    game.effects._process(0.012)
    await shot("dungeon-03-archive-cut")
    game._set_overlay("map")
    await shot("dungeon-04-route-map")
    game._set_overlay("pause")
    await shot("dungeon-05-pause")
    game._set_overlay("")
    game.outcome="defeat"
    await shot("dungeon-06-combat-death")
    game.free()
    quit()

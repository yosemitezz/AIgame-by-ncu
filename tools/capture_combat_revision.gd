extends SceneTree
## Four frozen visual studies, no navigation, demo recording or playthrough.
const Profile = preload("res://combat/attack_profile.gd")
var game: Node
func _initialize() -> void:
    call_deferred("run")
func settle() -> void:
    await process_frame
    await process_frame
    await RenderingServer.frame_post_draw
func capture(name: String) -> void:
    game._refresh_hud()
    game.player.queue_redraw()
    game.boss.queue_redraw()
    game.effects.queue_redraw()
    await settle()
    var result: int=root.get_texture().get_image().save_png("res://artifacts/"+name+".png")
    print("CAPTURE ",name," ",result)
func place_player(at: Vector2) -> void:
    game.player.position=at
    game.player.velocity=Vector2.ZERO
    game.player.facing=1
    game.player.combat_freeze=0
    game.player._cancel_attack()
    game.player._clear_parry()
    game.player.parry_timer=0
    game.player.dash_timer=0
    game._camera.position=game.camera_target(at,1)
    for index: int in game.level.ZONES.size():
        if at.x>=float(game.level.ZONES[index]["x"]): game._zone=index
func run() -> void:
    root.size=Vector2i(800,450)
    game=load("res://main.tscn").instantiate()
    root.add_child(game)
    current_scene=game
    await process_frame
    game.set_process(false)
    game.set_physics_process(false)
    game.player.set_physics_process(false)
    for enemy: Node in get_nodes_in_group("enemies"): enemy.set_physics_process(false)
    game._start_boss()
    game.boss.set_physics_process(false)
    game.music.stop_score()
    game.music.set_process(false)
    game.effects.set_process(false)
    game.speed_feedback.set_process(false)
    game.level.set_process(false)
    game.boss._cancel_all_attacks()
    game.boss.position=Vector2(3100,300)
    game.boss.facing=-1
    game._announcement_time=0
    place_player(Vector2(2820,300))
    game.player.combo=1
    game.player.attack_serial=9001
    game.player.attack_phase="active"
    game.player._phase_elapsed=Profile.duration(1,"active")*0.45
    game.player.attack_sweep_from=0.3
    game.player.attack_sweep_to=0.45
    game.player.animation_state="attack"
    game.player.frame=1
    game.emit_fx("slash",game.player.position+Vector2(22,-18),Vector2.RIGHT,1)
    game.effects._process(0.01)
    await capture("combat-01-wide-sword-and-katana-boss")
    game.effects.clear_hostile()
    place_player(Vector2(2920,300))
    game.boss.position=Vector2(2984,300)
    game.boss._stagger_timer=0
    game.boss._posture_lockout=0
    game.boss.reaction_state="none"
    game.boss._reaction_blocks_attacks=false
    game.player._start_parry()
    game.boss._begin_attack("slash")
    game.boss._release_attack()
    game.effects._process(0.055)
    await capture("combat-02-real-blade-parry")
    game.effects.clear_hostile()
    game.boss._cancel_all_attacks()
    game.boss._start_reaction("guard_break",0.9,true)
    game.boss.guard_posture=3
    game.boss._reaction_elapsed=0.35
    game.boss.reaction_progress=0.35/0.9
    game.last_parry_kind="guard_break"
    game._parry_notice_time=0.7
    game.player.animation_state="idle"
    game.player.parry_phase="none"
    game.player.parry_timer=0
    await capture("combat-03-katana-guard-break")
    game.effects.clear_hostile()
    place_player(Vector2(2780,300))
    game._parry_notice_time=0
    game.player.animation_state="dash"
    game.player.frame=1
    game.player.dash_timer=0.14
    game.player.velocity=Vector2(420,0)
    for step: int in 5:
        game.player.position.x+=14
        game.effects._process(0.035)
        game.speed_feedback._process(0.035)
        game.speed_feedback.sample_camera_lead(0.035)
    await capture("combat-04-crisp-speed-feedback")
    game.set_story_safe(true)
    game.free()
    quit()

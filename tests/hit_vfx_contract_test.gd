extends SceneTree
## True game damage -> one contact bundle, never a synthetic swing impact.
const Profile=preload("res://combat/attack_profile.gd")
const Query=preload("res://combat/melee_query.gd")
var passed:int=0
var failed:int=0
var game:Node
var events:Array[Dictionary]=[]
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
    if ok:passed+=1;print("PASS ",label)
    else:failed+=1;push_error("FAIL "+label)
func prepare(wid:String,combo:int,origin:Vector2)->void:
    game.player._cancel_attack();game.player.combat_freeze=0.0
    game.player.set_weapon(wid);game.player.position=origin;game.player.facing=1
    game.player.combo=combo;game.player.attack_phase="active";game.player.attack_serial+=1
    game.player.attack_previous_position=origin
    game.player.attack_sweep_from=Profile.contact_start();game.player.attack_sweep_to=1.0
    events.clear()
func run()->void:
    game=load("res://main.tscn").instantiate();root.add_child(game);current_scene=game
    await process_frame
    game.set_process(false);game.set_physics_process(false);game.player.set_physics_process(false);game.music.set_process(false)
    for actor:Node in get_nodes_in_group("enemies"):actor.set_physics_process(false)
    game.vfx_requested.connect(func(kind:String,at:Vector2,dir:Vector2,power:float)->void:events.append({"kind":kind,"at":at,"dir":dir,"power":power}))
    var origin:=Vector2(5000,200)
    var foe:Node2D=game.spawn_enemy("elite",origin+Vector2(60,0))
    foe.set_physics_process(false);foe.health=100;foe.max_health=100
    for wid:String in ["light","heavy","great"]:
        foe.position=origin+Vector2(-60 if wid=="great" else 60,0);foe._hurt_flash=0.0
        prepare(wid,1,origin)
        var before:int=foe.health
        var impact_before:int=game.impact.impact_count
        for i:int in 6:game.hero_attack(game.player,Profile.damage(1),Profile.radii(1).x,1)
        var contacts:Array[Dictionary]=[];var legacy:int=0
        for event:Dictionary in events:
            if event["kind"]=="weapon_hit_"+wid:contacts.append(event)
            if event["kind"]=="hit":legacy+=1
        check(foe.health==before-Profile.damage(1),wid+" confirmed actual enemy damage once")
        check(contacts.size()==1 and legacy==0,wid+" one real-contact burst replaces synchronous old center flash")
        check(game.impact.impact_count==impact_before+1,wid+" retains one central impact service")
        if not contacts.is_empty():
            var bounds:=Rect2(foe.position+Vector2(-10,-31),Vector2(20,32)).grow(1)
            check(bounds.has_point(contacts[0]["at"]),wid+" burst is on contacted hurt boundary")
            check(contacts[0]["dir"].x<0 if wid=="great" else contacts[0]["dir"].x>0,wid+" burst follows actual contact direction")
        check(not game._weapon_hit_context,wid+" damage context never leaks beyond callback")
    foe.position=origin+Vector2(520,0);foe._hurt_flash=0
    prepare("light",1,origin)
    var count:int=game.impact.impact_count
    game.hero_attack(game.player,1,180,1)
    check(events.is_empty() and game.impact.impact_count==count,"whiff cannot manufacture impact burst/rumble")
    game.emit_fx("hit",origin,Vector2.RIGHT,1)
    check(events.size()==1 and events[0]["kind"]=="hit","unrelated legacy impact stays available")
    foe.position=origin+Vector2(65,0);foe._hurt_flash=0
    prepare("heavy",3,origin)
    var wave:Node2D=game.spawn_sword_wave(game.player,game.player.attack_serial);wave.set_physics_process(false)
    game.player._cancel_attack();wave._physics_process(.20)
    var wave_count:int=0;var old_count:int=0
    for event:Dictionary in events:
        if event["kind"]=="weapon_hit_wave":wave_count+=1
        if event["kind"]=="hit":old_count+=1
    check(wave_count==1 and old_count==0,"sword energy uses one exact intersection event")
    check(not game._weapon_hit_context,"wave also restores damage context")
    check(Engine.time_scale==1.0 and not paused,"visual contact preserves global clock")
    game.clear_sword_waves()
    game._start_boss();game.boss.set_physics_process(false);game.player.set_physics_process(false);game.music.set_process(false)
    game.boss.phase="final";game.boss.health=100;game.boss._hurt_timer=0.0
    var boss_at:Vector2=game.boss.position
    prepare("light",1,boss_at-Vector2(48,0))
    var boss_before:int=game.boss.health;var impact_before:int=game.impact.impact_count
    game.hero_attack(game.player,1,180,1)
    var actual:int=0;var legacy:int=0
    for event:Dictionary in events:
        if event["kind"]=="weapon_hit_light":actual+=1
        if event["kind"]=="hit":legacy+=1
    check(game.boss.health==boss_before-1,"Boss accepted contact still damages through original authority")
    check(actual==1 and legacy==0 and game.impact.impact_count==impact_before+1,"Boss accepted contact has one burst and one impact")
    events.clear();game.player.attack_serial+=1;impact_before=game.impact.impact_count;boss_before=game.boss.health
    game.hero_attack(game.player,1,180,1)
    check(game.boss.health==boss_before and events.is_empty() and game.impact.impact_count==impact_before,"Boss rejection generates no false burst or impact")
    check(not game._weapon_hit_context,"Boss rejected callback also restores routing scope")
    game.queue_free();await process_frame
    print("Hit VFX contract: %d passed, %d failed"%[passed,failed]);quit(1 if failed else 0)
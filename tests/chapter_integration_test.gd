extends SceneTree
## Main-scene fixtures; no traversing the level or playing back inputs.
const Controller=preload("res://flow/chapter_controller.gd")
const Story=preload("res://flow/chapter_story.gd")
const Save=preload("res://flow/chapter_save.gd")
var passed:int=0
var failed:int=0
var game:Node
class LoaderProbe extends Node:
    var chapter_enabled:bool=true
    var chapter_persist:bool=true
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
    if ok:passed+=1;print("PASS ",label)
    else:failed+=1;push_error("FAIL "+label)
func freeze()->void:
    game.set_process(false);game.set_physics_process(false)
    game.player.set_physics_process(false);game.music.set_process(false)
    for enemy:Node in get_nodes_in_group("enemies"):enemy.set_physics_process(false)
func key(code:int)->InputEventKey:
    var event:=InputEventKey.new();event.physical_keycode=code;event.pressed=true;return event
func run()->void:
    var old_disabled:String=OS.get_environment("BELLKEEP_DISABLE_STORY")
    OS.set_environment("BELLKEEP_DISABLE_STORY","0")
    for name:String in ["bellkeep_story","bellkeep_room","bellkeep_checkpoint","bellkeep_elite","bellkeep_doors","bellkeep_shards","bellkeep_chapter_complete","bellkeep_weapon"]:
        if has_meta(name):remove_meta(name)
    var probe:Node=LoaderProbe.new();root.add_child(probe)
    var fixture_path:String="res://.local/tests/chapter-invalid-fixture.json"
    var baseline:Dictionary=Story.new().snapshot()
    var wrong:Dictionary=baseline.duplicate(true);wrong["chapter_id"]="unrelated_chapter"
    Save.write(fixture_path,wrong,{"room":"boss","elite":true})
    Controller.restore_run(probe,fixture_path)
    check(not has_meta("bellkeep_story") and not has_meta("bellkeep_room"),"wrong chapter cannot apply story or run progress")
    wrong=baseline.duplicate(true);wrong["version"]=99
    Save.write(fixture_path,wrong,{"room":"boss"})
    Controller.restore_run(probe,fixture_path)
    check(not has_meta("bellkeep_story") and not has_meta("bellkeep_room"),"old story version cannot apply run progress")
    wrong=baseline.duplicate(true);wrong["cursor"]={"blocking":true,"node":"missing_node"}
    Save.write(fixture_path,wrong,{"room":"boss"})
    Controller.restore_run(probe,fixture_path)
    check(not has_meta("bellkeep_story") and not has_meta("bellkeep_room"),"invalid blocking cursor cannot apply run progress")
    var broken:FileAccess=FileAccess.open(fixture_path,FileAccess.WRITE);broken.store_string("{");broken.close()
    Controller.restore_run(probe,fixture_path)
    check(not has_meta("bellkeep_story") and Save.read(fixture_path).is_empty(),"truncated save falls back without adopting progress")
    Save.erase(fixture_path);probe.queue_free()
    game=load("res://main.tscn").instantiate()
    var has_enable:bool=false
    for property:Dictionary in game.get_property_list():
        if str(property["name"])=="chapter_enabled":has_enable=true
    check(has_enable,"main scene exposes the explicit chapter integration hook")
    if not has_enable:
        game.free();OS.set_environment("BELLKEEP_DISABLE_STORY",old_disabled)
        print("Chapter integration: %d passed, %d failed"%[passed,failed]);quit(1);return
    game.chapter_enabled=true;game.chapter_persist=false
    root.add_child(game);current_scene=game
    await process_frame;freeze()
    var chapter:Node=game.chapter
    check(is_instance_valid(chapter) and chapter.enabled,"real main entry creates chapter controller")
    check(chapter.blocked() and game.story_safe and not game.player.is_physics_processing(),"opening is safe and explicitly skippable")
    check(is_instance_valid(chapter.eye) and is_instance_valid(chapter.aura) and is_instance_valid(chapter.overlay),"physical companion, corruption and overlay are integrated")
    check(chapter.state.corruption==0.0 and chapter.aura.wisp_count()==0,"new chapter starts in clean armour")
    check(chapter.handle_input(key(KEY_BACKSPACE)),"opening skip uses the real controller input path")
    check(not chapter.blocked() and not game.story_safe,"skip opening returns control without a reward")
    freeze()
    var foe:Node=get_nodes_in_group("enemies")[0]
    var enemy_id:String=str(foe.get_meta("chapter_spawn_id","fixture-spawn"))
    chapter.event("enemy_defeated",{"id":enemy_id,"kind":"sentry"})
    var corrupt:float=chapter.state.corruption
    chapter.event("enemy_defeated",{"id":enemy_id,"kind":"sentry"})
    check(corrupt>0.0 and chapter.state.corruption==corrupt,"stable enemy id cannot farm corruption on repeated callbacks")
    game._start_boss(false);freeze()
    check(game.room_id=="boss" and is_instance_valid(game.boss),"fixture enters the actual independent Boss room")
    var flight_level:Node=game.level
    var legacy_level:Node=preload("res://levels/boss_chamber.gd").new()
    game.level=legacy_level
    check(chapter._recovery_position(Vector2(5200,-220))==Vector2(3310,300),"legacy chamber keeps its bounded floor recovery")
    game.level=flight_level;legacy_level.free()
    var flight_contact:Vector2=Vector2(5200,-220)
    game.player.position=flight_contact;game.boss.position=flight_contact+Vector2(150,0)
    game.player.health=1;game.player.invuln=0.0;game.outcome="";game.set_story_safe(false)
    check(not chapter.try_rescue(1,game.player.position,false) and not chapter.state.rescue_used,"pit/fall path cannot consume Boss rescue")
    game.player.invuln=0.4
    check(not chapter.try_rescue(1,game.boss.position,true),"invulnerable contact cannot fabricate a rescue")
    game.player.invuln=0.0
    game.music._process(.2)
    var before:float=game.music.get_score_time()
    var shot:Node=game.spawn_projectile(game.player.position+Vector2(120,-30),Vector2.LEFT*100)
    if is_instance_valid(shot):shot.set_physics_process(false)
    var boss_hp:int=game.boss.health
    game.damage_player(1,game.boss.position)
    check(chapter.state.rescue_used and chapter.blocked() and game.player.health==1 and not game.player.dead and game.outcome=="","real lethal damage is intercepted before ordinary defeat")
    check(game.story_safe and get_nodes_in_group("projectiles").is_empty() and get_nodes_in_group("boss_hazards").is_empty(),"rescue clears old dangerous plans and projectiles")
    game.music._process(2.0)
    check(is_equal_approx(before,game.music.get_score_time()),"rescue pauses the existing music position instead of restarting it")
    var node_before:String=chapter.state.presentation()["node_id"]
    chapter.set_paused(true);game._paused=true;chapter.tick(5.0)
    check(chapter.state.presentation()["node_id"]==node_before,"pause freezes the narrative graph")
    game._paused=false;chapter.set_paused(false)
    check(game.music._full_paused,"closing pause cannot resume music through a narrative safety lock")
    chapter.state.skip();chapter.tick(.2);freeze()
    check(not chapter.blocked() and game.player.health>=1 and not game.player.dead,"rescue has a finite recover-and-reengage path")
    check(game.boss.health==boss_hp and is_equal_approx(before,game.music.get_score_time()),"rescue preserves earned Boss health progress and source cursor")
    check(game.player.position.distance_to(flight_contact)<=12.01 and is_equal_approx(game.player.position.y,flight_contact.y),"flight rescue stays near the real airborne contact instead of the old arena")
    check(game.boss.position.distance_to(flight_contact+Vector2(150,0))<0.01,"rescue does not relocate the airborne Boss")
    game.player.invuln=0.0
    check(not chapter.try_rescue(99,game.boss.position,true),"one chapter cannot repeatedly claim the rescue")
    var old_section:String=game.music.current_section
    game.music.current_section="rest"
    chapter._lock("fixture_rest_overlap");chapter._unlock()
    check(game.story_safe and game.player.is_physics_processing() and game.boss.is_physics_processing(),"rest keeps damage safety while alive actor physics resume")
    game.music.current_section=old_section;game.set_story_safe(false);freeze()
    chapter.state.event("room_changed",{"room":"boss"})
    game.player.velocity=Vector2(0,-150);game.player._hurt_lock=.2
    chapter._actual_operations()
    check(str(chapter.presentation().get("line_id",""))!="T_JUMP","upward knockback does not fabricate jump teaching")
    game.player._hurt_lock=0.0
    game.emit_fx("jump",game.player.position,Vector2.UP,.5)
    check(str(chapter.presentation().get("line_id",""))=="T_JUMP","actual player jump effect triggers jump teaching")
    chapter.prepare_reload(false)
    var retry:Dictionary=get_meta("bellkeep_story",{})
    var restored:RefCounted=Story.new();restored.configure(retry)
    check(restored.rescue_used and restored.corruption==corrupt and not restored.begin_chapter(),"retry restores seen opening, rescue and corruption without repeating the introduction")
    game.boss.phase="final";game.boss.health=1;game.boss._hurt_timer=0.0;game.boss._active=true
    game.boss.receive_hit(1,game.player.position)
    check(game.outcome=="victory" and chapter.state.chapter_complete and bool(get_meta("bellkeep_chapter_complete",false)),"actual Boss defeat records earned victory before the ending")
    chapter.handle_input(key(KEY_BACKSPACE));chapter.tick(.2);freeze()
    check(chapter.state.narrative_dead and game.outcome=="victory" and not game.player.dead,"narrative death is separate from ordinary defeat and retains the win")
    var blood:float=float(chapter.state.presentation()["death_elapsed"])
    chapter.tick(.5)
    check(float(chapter.state.presentation()["death_elapsed"])>blood and chapter.overlay.blood_segments().size()>0,"real terminal graph drives red blood growth")
    var restored_hp:int=game.player.health
    chapter.handle_input(key(KEY_V));chapter.handle_input(key(KEY_BACKSPACE));chapter.tick(.2)
    check(game.player.health==restored_hp and chapter.state.chapter_complete,"ending replay cannot heal or award completion again")
    check(chapter.handle_input(key(KEY_ENTER)) and chapter.state.ending_dismissed,"completion page provides a functioning return action")
    check(game.room_flow.active and game.room_flow.target=="dungeon","return targets the dungeon rather than restarting the won Boss")
    check(chapter.consume_interact_guard(),"the close/continue edge cannot also activate a portal")
    game._process(.9);chapter.tick(0.0);freeze()
    check(game.room_id=="dungeon" and not game.room_flow.active and not chapter.blocked() and not game.player.dead,"completed return actually mounts the dungeon and restores control")
    game.player.health=1;game.player.invuln=0.0;game.set_story_safe(false)
    game.damage_player(1,game.player.position+Vector2.RIGHT*20)
    check(game.player.dead and game.outcome=="defeat" and chapter.state.chapter_complete,"ordinary dungeon lethal remains an ordinary defeat after completion")
    check(not chapter.handle_input(key(KEY_R)) and not chapter.handle_input(key(KEY_V)) and not chapter.return_to_dungeon(),"ordinary defeat passes R to root retry and cannot bypass death via replay")
    chapter.prepare_reload(false)
    var completed_retry:Dictionary=get_meta("bellkeep_story",{})
    check(bool(completed_retry.get("chapter_complete",false)) and bool(completed_retry.get("ending_dismissed",false)),"ordinary retry retains the earned completion and dismissed ending")
    chapter.prepare_reload(true)
    check(not has_meta("bellkeep_story"),"explicit new chapter clears narrative metadata")
    var file:String="res://.local/tests/chapter-save-integration.json"
    var stored:Dictionary=chapter.state.snapshot()
    check(Save.write(file,stored,{"room":"dungeon","shards":[0,2]})==OK and bool(Save.read(file).get("story",{}).get("chapter_complete",false))==bool(stored["chapter_complete"]) and Save.read(file).get("story",{}).get("seen",{})==stored["seen"],"local chapter save round-trips data")
    check(Save.erase(file)==OK and Save.read(file).is_empty(),"test-owned save is cleaned without touching the real user save")
    game.set_story_safe(true);game.music.stop_score();game.queue_free();await process_frame
    for name:String in ["bellkeep_story","bellkeep_room","bellkeep_checkpoint","bellkeep_elite","bellkeep_doors","bellkeep_shards","bellkeep_chapter_complete","bellkeep_weapon"]:
        if has_meta(name):remove_meta(name)
    OS.set_environment("BELLKEEP_DISABLE_STORY",old_disabled)
    print("Chapter integration: %d passed, %d failed"%[passed,failed]);quit(1 if failed else 0)
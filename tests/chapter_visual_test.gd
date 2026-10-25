extends SceneTree
## Small presentation-only fixtures. No input replay, gameplay clock or AI.
const Eye=preload("res://presentation/flying_eye.gd")
const Aura=preload("res://presentation/corruption_aura.gd")
const Overlay=preload("res://ui/chapter_overlay.gd")
const Story=preload("res://flow/chapter_story.gd")
var passed: int=0
var failed: int=0
class Hero extends Node2D:
    var facing: int=1
    var dead: bool=false
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
    if ok:passed+=1;print("PASS ",label)
    else:failed+=1;push_error("FAIL "+label)
func run() -> void:
    root.size=Vector2i(800,450)
    var game:=Node2D.new();root.add_child(game)
    var hero:=Hero.new();game.add_child(hero);hero.position=Vector2(400,300)
    var eye:=Eye.new();game.add_child(eye);eye.configure(game,hero);eye.set_process(false)
    var aura:=Aura.new();game.add_child(aura);aura.configure(hero);aura.set_process(false)
    var overlay:=Overlay.new();root.add_child(overlay);overlay.set_process(false)
    await process_frame
    check(eye.process_mode==Node.PROCESS_MODE_PAUSABLE and aura.process_mode==Node.PROCESS_MODE_PAUSABLE and overlay.process_mode==Node.PROCESS_MODE_PAUSABLE,"all narrative visuals follow gameplay pause")
    check(overlay.mouse_filter==Control.MOUSE_FILTER_IGNORE,"story presentation cannot swallow gameplay clicks")
    var hero_before: Vector2=hero.position
    eye.update_story({"phase":"explore","eye_mood":"friendly","corruption":0.0})
    eye.snap_to_hero()
    check(eye.global_position.x<hero.global_position.x and eye.global_position.y<hero.global_position.y-55.0,"physical companion hovers behind and above the hero face")
    hero.position+=Vector2(500,0)
    eye._process(.016)
    check(eye.global_position.distance_to(eye.follow_target())<2.0,"room-distance discontinuity snaps the companion safely")
    check(hero.position==hero_before+Vector2(500,0),"companion never moves the player")
    eye.update_story({"narrative_dead":true,"blackout":1.0,"eye_mood":"cold"})
    check(not eye.visible,"world eye retires when final screen owns the close-up")
    eye.update_story({"ending_dismissed":true,"eye_mood":"cold"})
    check(not eye.visible,"completed free exploration cannot restore a friendly betrayer companion")
    aura.update_story({"corruption":0.0})
    check(aura.wisp_count()==0 and aura.fragments().is_empty() and not aura.visible,"clean opening armor has zero corruption drawing")
    aura.update_story({"corruption":.08})
    check(aura.wisp_count()<=3,"early kill corruption remains a few small wisps")
    check(aura.ribbon_paths().is_empty(),"early corruption has no full-height smoke ribbons")
    var early: int=aura.wisp_count()
    aura.update_story({"corruption":1.0})
    check(aura.wisp_count()>early and aura.wisp_count()<=Aura.MAX_WISPS,"late aura grows with a strict fragment budget")
    check(aura.ribbon_paths().size()==2,"boss-complete aura has exactly two narrow edge ribbons")
    aura._clock=2.3
    var bounded: bool=true
    var edges_only: bool=true
    for piece: Dictionary in aura.fragments():
        bounded=bounded and Aura.BOUNDS.encloses(Rect2(piece["at"],Vector2(piece["width"],piece["height"]))) and float(piece["alpha"])<=.67
        edges_only=edges_only and absf(Vector2(piece["at"]).x)>=8.0
    check(bounded and edges_only,"corruption stays transparent on body edges inside bounded local area")
    aura._process(.016)
    check(aura.global_position==hero.global_position.round(),"aura follows feet without altering hurtboxes")
    aura.update_story({"corruption":1.0,"narrative_dead":true})
    check(not aura.visible,"final broadcast does not leak world aura on top")
    overlay.update_state({"phase":"explore","blocking":false,"line":""})
    check(not overlay.is_blocking() and overlay.blood_segments().is_empty(),"normal exploration has no blocking death layer")
    check(overlay.death_ink()==Overlay.WHITE,"ordinary state keeps the normal light death ink")
    overlay.update_state({"phase":"rescue","blocking":true,"blackout":.7,"dizzy":1.0,"line":"别睡，我在。","speaker":"飞眼","node_elapsed":1.2})
    check(overlay.is_blocking() and overlay.blood_segments().is_empty(),"rescue blackout never shows final red death or blood")
    overlay.update_state({"phase":"narrative_dead","blocking":true,"narrative_dead":true,"bloodred":true,"chapter_complete":true,"blackout":1.0,"node_elapsed":3.0,"death_elapsed":3.0})
    check(overlay.death_ink()==Overlay.RED,"betrayal death uses the distinct red broadcast")
    var blood: Array[Rect2]=overlay.blood_segments()
    check(blood.size()==9,"final title owns a bounded set of nine blood trails")
    var below: bool=true
    for rect: Rect2 in blood:
        below=below and rect.position.y>overlay.size.y*.58 and rect.end.y<overlay.size.y*.76 and rect.size.x<=3
    check(below,"blood flows below letters without covering chapter controls")
    check(bool(overlay.state["chapter_complete"]),"narrative death presentation preserves chapter victory")
    overlay.set_suspended(true)
    check(not overlay.visible,"pause may suspend the cinematic overlay to reveal the pause menu")
    overlay.set_suspended(false)
    check(overlay.visible,"resume restores the same presentation")
    var transition_story:=Story.new()
    transition_story.boss_defeated()
    for i: int in 1000:
        var current: Dictionary=transition_story.presentation()
        if float(current.get("blackout",0))>0.0 and float(current.get("blackout",0))<1.0 and not bool(current.get("eye_closeup",false)):break
        transition_story.tick(.10)
    overlay.update_state(transition_story.presentation())
    check(not overlay.eye_closeup_visible() and float(overlay.state.get("blackout",0))<1.0,"actual betrayal blackout fades before the eye close-up")
    for i: int in 1000:
        if bool(transition_story.presentation().get("eye_closeup",false)):break
        transition_story.tick(.10)
    overlay.update_state(transition_story.presentation())
    check(overlay.eye_closeup_visible() and float(overlay.state.get("blackout",0))==1.0,"actual next node reveals the cold eye only after full blackout")
    for i: int in 1000:
        var beat_view: Dictionary=transition_story.presentation()
        if str(beat_view.get("node_id",""))=="betray_beat" and float(beat_view.get("faint",0))>0.4 and float(beat_view.get("faint",0))<1.0:break
        transition_story.tick(.10)
    overlay.update_state(transition_story.presentation())
    check(str(overlay.state.get("node_id",""))=="betray_beat" and float(overlay.state.get("faint",0))>0.4 and float(overlay.state.get("faint",0))<1.0,"final eye dims out gradually before the death broadcast")
    var actual:=Story.new()
    actual.boss_defeated()
    actual.skip()
    overlay.update_state(actual.presentation())
    check(overlay.blood_segments().is_empty(),"actual skipped ending begins with no pre-grown blood")
    actual.tick(2.0)
    overlay.update_state(actual.presentation())
    check(overlay.blood_segments().size()==9 and overlay.phase_elapsed()>=2.0,"actual finished Story terminal timer grows all blood trails")
    var terminal_time: float=overlay.phase_elapsed()
    actual.tick(1.0,true)
    overlay.update_state(actual.presentation())
    check(is_equal_approx(overlay.phase_elapsed(),terminal_time),"actual terminal blood timing pauses with the story clock")
    var source: Dictionary={"phase":"opening","line":"记忆一片空白。","blocking":true,"node_elapsed":0.0}
    overlay.update_state(source);source["line"]="changed"
    check(str(overlay.state["line"])=="记忆一片空白。","presentation snapshots never mutate the state owner")
    var glyphs: bool=true
    for sentence: String in Overlay.STRINGS:
        for index: int in sentence.length():glyphs=glyphs and overlay.font.has_char(sentence.unicode_at(index))
    check(glyphs,"pixel font covers all new fixed Chinese controls/title glyphs")
    check(overlay.panel_layout(Vector2(800,450))["dialog"].end.x<=800 and overlay.panel_layout(Vector2(800,450))["dialog"].end.y<=450,"chapter panels fit the actual800x450 viewport")
    overlay.queue_free();game.queue_free();await process_frame
    print("Chapter visuals: %d passed, %d failed" % [passed,failed])
    quit(1 if failed else 0)
extends SceneTree
## Bounded HUD-only room/map/transition checks. No gameplay or input is driven.
const HUD = preload("res://ui/hud.gd")
const Level = preload("res://levels/bellkeep.gd")
var passed: int = 0
var failed: int = 0
func check(ok: bool, label: String) -> void:
    if ok: passed += 1
    else:
        failed += 1
        push_error("FAIL " + label)
func base_state() -> Dictionary:
    return {"hp":8,"max_hp":8,"shards":3,"total_shards":25,"zone":"ZONE","hint":"","boss_hp":-1,"outcome":"","overlay":"","paused":false,"safe":false,"player_at":Vector2(2400,300),"progress":0.8}
func _initialize() -> void: call_deferred("run")
func run() -> void:
    var hud: Control = HUD.new()
    root.add_child(hud)
    hud.size = Vector2(800,450)
    hud.set_process(false)
    await process_frame
    var original_time: float = Engine.time_scale
    hud.update_state(base_state())
    check(hud.current_room() == "dungeon" and hud.room_status() == "ZONE", "legacy HUD state keeps dungeon and zone defaults")
    check(hud.map_bounds() == Level.WORLD_BOUNDS, "legacy map uses its original bounds")
    hud._explored_x = 2400.0
    var dungeon: Dictionary = base_state().merged({"room_id":"dungeon","room_title":"DUNGEON","room_bounds":Rect2(-40,-160,2700,860),"room_platforms":[Rect2(0,300,2580,24)],"portal_at":Vector2(2560,300),"portal_hint":"E ENTER","portal_confirm":false},true)
    hud.update_state(dungeon)
    check(hud.room_status() == "DUNGEON" and hud.room_title() == "DUNGEON", "current room title reaches the normal status HUD")
    var initial: Dictionary = hud.portal_feedback()
    check(initial["visible"] and not initial["confirm"] and initial["hint"] == "E ENTER", "nearby portal has a first-press prompt")
    var boss: Dictionary = base_state().merged({"room_id":"boss","room_title":"DUEL ROOM","room_bounds":Rect2(2580,-120,840,620),"room_platforms":[Rect2(2580,300,840,24),Rect2(2740,224,100,16),Rect2(2980,200,100,16),Rect2(3180,236,100,16)],"portal_at":Vector2(2706,300),"player_at":Vector2(3300,300),"boss_hp":40,"boss_max":40,"portal_hint":"E RETURN","portal_confirm":true},true)
    hud.update_state(boss)
    var data: Dictionary = hud.room_map_data()
    check(data["room_id"] == "boss" and data["bounds"] == boss["room_bounds"] and data["platforms"].size() == 4, "Boss map uses its own supplied bounds and four platforms")
    check(data["shards"].is_empty() and data["rooms"].is_empty() and data["climbables"].is_empty() and not data["has_fog"], "Boss map has no dungeon pickups/rooms/ladder/fog")
    check(data["portal_at"] == Vector2(2706,300), "Boss portal marker is in the independent room")
    check(hud._explored_x == 2400.0, "Boss coordinates do not reveal unexplored dungeon")
    var confirmed: Dictionary = hud.portal_feedback()
    check(confirmed["visible"] and confirmed["confirm"] and confirmed["action"] != initial["action"], "second E press has a distinct confirmation label")
    var area: Rect2 = Rect2(30,120,740,190)
    var minimum: Vector2 = hud.map_point(boss["room_bounds"].position,area)
    var maximum: Vector2 = hud.map_point(boss["room_bounds"].end,area)
    check(minimum.x >= area.position.x and minimum.y >= area.position.y and maximum.x <= area.end.x and maximum.y <= area.end.y, "Boss world coordinates fit the current room map")
    hud.update_state(dungeon)
    check(hud._explored_x == 2400.0 and hud.room_map_data()["has_fog"] and not hud.room_map_data()["shards"].is_empty(), "return restores dungeon exploration and pickup map")
    for variant: Dictionary in [{"paused":true},{"overlay":"map"},{"outcome":"defeat"},{"transition":true}]:
        hud.update_state(dungeon.merged(variant,true))
        check(not hud.portal_feedback()["visible"], "portal panel suppressed by " + str(variant))
    hud.update_state(boss.merged({"outcome":"victory"},true))
    check(hud.portal_feedback()["visible"] and hud.portal_feedback()["confirm"], "victory still displays E return confirmation")
    check(hud.transition_alpha(0.0) == 0.0 and hud.transition_alpha(1.0) == 0.0, "transition begins and ends transparent")
    for progress: float in [0.32,0.40,0.5,0.72]:
        check(is_equal_approx(hud.transition_alpha(progress),1.0), "world swap/preparation is fully black at " + str(progress))
    check(hud.transition_alpha(-1) == 0 and hud.transition_alpha(2) == 0 and hud.transition_alpha(NAN) == 1, "transition geometry clamps malformed progress safely")
    hud.update_state(boss.merged({"room_bounds":Rect2(0,0,0,0)},true))
    check(hud.map_bounds() == Rect2(2580,-120,840,620), "invalid room bounds use safe room-specific fallback")
    var glyphs_ok: bool = true
    for line: String in HUD.ROOM_STRINGS:
        for i: int in line.length():
            glyphs_ok = glyphs_ok and (line[i] == " " or hud.font.has_char(line.unicode_at(i)))
    check(glyphs_ok, "pixel font includes every new Chinese room/portal glyph")
    var layout: Dictionary = hud.panel_layout(Vector2(800,450),true)
    check(not layout["portal"].intersects(layout["bottom"]) and not layout["portal"].intersects(layout["dialog"]) and Rect2(Vector2.ZERO,Vector2(800,450)).encloses(layout["portal"]), "portal panel fits between dialogue and bottom UI")
    check(not layout["portal"].intersects(Rect2(12,108,68,192)), "portal panel avoids the heavy beat lane")
    var frames: Array[Dictionary] = [dungeon,boss,dungeon.merged({"overlay":"map"},true),boss.merged({"overlay":"map"},true),boss.merged({"outcome":"defeat"},true)]
    for progress: float in [0.0,0.40,0.72,1.0]: frames.append(boss.merged({"transition":true,"transition_progress":progress},true))
    for frame: Dictionary in frames:
        hud.update_state(frame)
        hud._outcome_clock = 5.0
        await process_frame
    check(hud.RED == Color("ff0000") and hud.WHITE == Color("ffffff") and hud.mouse_filter == Control.MOUSE_FILTER_IGNORE, "existing normal death colors and decorative input behavior are retained")
    check(Engine.time_scale == original_time, "HUD does not change gameplay time")
    hud.free()
    print("Room HUD: %d passed, %d failed" % [passed,failed])
    quit(1 if failed else 0)

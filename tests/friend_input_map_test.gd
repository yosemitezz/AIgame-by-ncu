extends SceneTree
## Real physical key events and main pause/reset wiring, not a playthrough.
const Main = preload("res://main.gd")
const HUD = preload("res://ui/hud.gd")
var passed: int = 0
var failed: int = 0
var game: Node

func check(ok: bool, label: String) -> void:
    if ok:
        passed += 1
    else:
        failed += 1
        push_error("FAIL " + label)

func _initialize() -> void:
    call_deferred("run")

func key(code: Key, down: bool, location: KeyLocation = KEY_LOCATION_UNSPECIFIED, echo: bool = false) -> InputEventKey:
    var event := InputEventKey.new()
    event.physical_keycode = code
    event.location = location
    event.pressed = down
    event.echo = echo
    return event

func send(event: InputEventKey) -> void:
    Input.parse_input_event(event)
    Input.flush_buffered_events()

func run() -> void:
    root.size = Vector2i(800, 450)
    game = load("res://main.tscn").instantiate()
    root.add_child(game)
    current_scene = game
    await process_frame
    game.set_physics_process(false)
    game.set_process(false)
    game.player.set_physics_process(false)
    game.music.stop_score()
    game.music.set_process(false)
    for enemy: Node in get_nodes_in_group("enemies"):
        enemy.set_physics_process(false)
    var left := key(KEY_SHIFT, true, KEY_LOCATION_LEFT)
    var right := key(KEY_SHIFT, true, KEY_LOCATION_RIGHT)
    check(InputMap.event_is_action(left, "parry"), "left physical Shift matches the real parry map")
    check(not InputMap.event_is_action(right, "parry"), "right physical Shift is excluded")
    check(InputMap.action_get_events("dash").is_empty(), "dodge has no leftover Shift/L key binding")
    for old: Key in [KEY_K, KEY_X, KEY_L]:
        check(not InputMap.event_is_action(key(old, true), "parry") and not InputMap.event_is_action(key(old, true), "dash"), "old key %d does not trigger a second input authority" % old)
    send(right)
    check(not Input.is_action_pressed("parry"), "real right Shift press does not hold parry")
    send(key(KEY_SHIFT, false, KEY_LOCATION_RIGHT))
    send(left)
    check(Input.is_action_pressed("parry") and not Input.is_action_pressed("dash"), "real left Shift triggers only parry")
    game.player._capture_input()
    check(game.player._parry_buffer > 0.0, "left Shift reaches the player input buffer")
    game.player._start_parry()
    check(game.player.parry_timer > 0.0 and game.player.dash_timer == 0.0, "left Shift opens contact window without dodge")
    await process_frame
    await process_frame
    await physics_frame
    send(key(KEY_SHIFT, true, KEY_LOCATION_LEFT, true))
    check(not Input.is_action_just_pressed("parry"), "keyboard echo does not reopen a guard edge")
    send(key(KEY_SHIFT, false, KEY_LOCATION_LEFT))
    check(not Input.is_action_pressed("parry"), "left Shift release clears held state")
    game.player.revive(Vector2(100,300))
    for code: Key in [KEY_A, KEY_D, KEY_W, KEY_S, KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN]:
        send(key(code, true))
        var action: String = {KEY_A:"move_left",KEY_D:"move_right",KEY_W:"climb_up",KEY_S:"climb_down",KEY_LEFT:"move_left",KEY_RIGHT:"move_right",KEY_UP:"climb_up",KEY_DOWN:"climb_down"}[code]
        check(Input.is_action_pressed(action), "physical direction %d feeds its real action" % code)
        send(key(code, false))
    game.player.reset_direction_taps()
    game.player._direction_taps.register_press(&"move_left", 0.0)
    game.player._dash_buffer = 0.1
    game._set_overlay("pause")
    check(paused and game.player._dash_buffer == 0.0, "pause clears pending dodge")
    check(not game.player._direction_taps.register_press(&"move_left",0.01), "pause invalidates previous tap")
    game.player._dash_buffer = 0.1
    game._set_overlay("")
    check(not paused and game.player._dash_buffer == 0.0, "resume resets tap intent again")
    game.player._direction_taps.register_press(&"move_right",0.0)
    game._set_overlay("map")
    game._set_overlay("")
    check(not game.player._direction_taps.register_press(&"move_right",0.01), "map round trip cannot join old taps")
    for label: String in ["攻击 J", "格挡 左SHIFT", "闪避 双击WASD", "地图 TAB"]:
        check(HUD.STRINGS.has(label), "new HUD label is part of glyph validation: " + label)
        check(game._hud.font.get_string_size(label,HORIZONTAL_ALIGNMENT_LEFT,-1,12).x <= 100, "command label fits button after icon: " + label)
    check(not HUD.STRINGS.has("LV 01"), "HUD does not imply an unimplemented level system")
    game.set_story_safe(true)
    game.free()
    print("Friend physical input: %d passed, %d failed" % [passed,failed])
    quit(1 if failed else 0)
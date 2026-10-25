extends SceneTree

func _initialize() -> void:
    call_deferred("run")

func run() -> void:
    create_timer(10.0).timeout.connect(func() -> void:
        push_error("TITLE QUIT FAIL: quit action did not close the application")
        quit(2)
    )
    var screen: Control = load("res://ui/menus/title_screen.tscn").instantiate()
    root.add_child(screen)
    current_scene = screen
    await process_frame
    await process_frame
    var quit_button: Button = screen.get_node("%TitleMenu/%QuitButton")
    var at: Vector2 = quit_button.get_global_rect().get_center()
    var event := InputEventMouseButton.new()
    event.button_index = MOUSE_BUTTON_LEFT
    event.position = at
    event.global_position = at
    event.pressed = true
    Input.parse_input_event(event)
    Input.flush_buffered_events()
    await process_frame
    event = InputEventMouseButton.new()
    event.button_index = MOUSE_BUTTON_LEFT
    event.position = at
    event.global_position = at
    event.pressed = false
    print("Title quit: 1 passed, 0 failed")
    Input.parse_input_event(event)
    Input.flush_buffered_events()

extends SceneTree

var passed: int = 0
var failed: int = 0

func _initialize() -> void:
    call_deferred("run")

func check(ok: bool, label: String) -> void:
    if ok:
        passed += 1
        print("PASS ", label)
    else:
        failed += 1
        push_error("TITLE FAIL: " + label)

func key(code: Key) -> void:
    var event := InputEventKey.new()
    event.physical_keycode = code
    event.keycode = code
    event.pressed = true
    Input.parse_input_event(event)
    Input.flush_buffered_events()
    await process_frame
    event = InputEventKey.new()
    event.physical_keycode = code
    event.keycode = code
    event.pressed = false
    Input.parse_input_event(event)
    Input.flush_buffered_events()
    await process_frame

func click(control: Control) -> void:
    var at: Vector2 = control.get_global_rect().get_center()
    var event := InputEventMouseButton.new()
    event.button_index = MOUSE_BUTTON_LEFT
    event.button_mask = MOUSE_BUTTON_MASK_LEFT
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
    Input.parse_input_event(event)
    Input.flush_buffered_events()
    await process_frame

func capture(file_name: String) -> void:
    if DisplayServer.get_name() == "headless":
        return
    await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png("res://artifacts/title-screen/" + file_name)

func check_font(node: Node, font: FontFile) -> void:
    var texts: Array[String] = []
    if node is Label or node is Button:
        texts.append(node.text)
    if node is OptionButton:
        for index in range(node.item_count):
            texts.append(node.get_item_text(index))
    for text: String in texts:
        for index in range(text.length()):
            var code: int = text.unicode_at(index)
            if code >= 32:
                check(font.has_char(code), "native pixel font contains U+%04X from %s" % [code, text])
    for child: Node in node.get_children():
        check_font(child, font)

func run() -> void:
    create_timer(20.0).timeout.connect(func() -> void:
        push_error("TITLE FAIL: watchdog timeout")
        quit(2)
    )
    root.size = Vector2i(800,450)
    DirAccess.make_dir_recursive_absolute("res://artifacts/title-screen")
    var startup_scene: String = str(ProjectSettings.get_setting("application/run/main_scene"))
    check(startup_scene == "res://ui/menus/title_screen.tscn", "project opens the independent title screen")
    if failed:
        print("Title screen: %d passed, %d failed" % [passed,failed])
        quit(1)
        return
    var packed: PackedScene = load(startup_scene)
    check(packed != null, "title screen scene loads")
    if packed == null:
        print("Title screen: %d passed, %d failed" % [passed,failed])
        quit(1)
        return
    var screen: Control = packed.instantiate()
    root.add_child(screen)
    current_scene = screen
    await process_frame
    await process_frame
    var title: Control = screen.get_node("%TitleMenu")
    var settings: Control = screen.get_node("%SettingsMenu")
    var play: Button = title.get_node("%PlayButton")
    var settings_button: Button = title.get_node("%SettingsButton")
    check(current_scene == screen and root.find_child("Bellkeep",true,false) == null, "title does not create gameplay story music or combat")
    check(title.visible and not settings.visible, "title is visible with settings closed")
    await capture("title.png")
    check(title.get_node("%Brand").text == "钟 堡" and title.get_node("%Tag").text == "B E L L K E E P", "title uses the Bellkeep identity")
    check(play.text == "开始游戏" and settings_button.text == "设置" and title.get_node("%QuitButton").text == "退出", "menu exposes three real Chinese actions")
    check(title.get_node_or_null("Center/Panel") == null, "title removes the old heavy central panel")
    check(root.gui_get_focus_owner() == play, "start button receives initial keyboard focus")
    await key(KEY_DOWN)
    check(root.gui_get_focus_owner() == settings_button, "down key moves focus to settings")
    await key(KEY_ENTER)
    check(settings.visible, "Enter opens settings")
    check(play.disabled and settings_button.disabled and title.get_node("%QuitButton").disabled, "title actions cannot activate behind settings")
    var focus_contained: bool = true
    for index in range(12):
        await key(KEY_TAB)
        var focused: Control = root.gui_get_focus_owner()
        if focused == null or not settings.is_ancestor_of(focused):
            focus_contained = false
    check(focus_contained, "keyboard focus remains inside the settings modal")
    await capture("settings.png")
    var master: HSlider = settings.get_node("%MasterSlider")
    var music: HSlider = settings.get_node("%MusicSlider")
    var sfx: HSlider = settings.get_node("%SfxSlider")
    var master_index: int = AudioServer.get_bus_index("Master")
    var music_index: int = AudioServer.get_bus_index("Music")
    var sfx_index: int = AudioServer.get_bus_index("SFX")
    check(music_index >= 0 and sfx_index >= 0, "settings creates the audio buses before gameplay")
    master.value = 35.0
    music.value = 45.0
    sfx.value = 55.0
    check(is_equal_approx(AudioServer.get_bus_volume_db(master_index),linear_to_db(0.35)), "master slider changes the real Master bus")
    check(is_equal_approx(AudioServer.get_bus_volume_db(music_index),linear_to_db(0.45)), "music slider changes the real Music bus")
    check(is_equal_approx(AudioServer.get_bus_volume_db(sfx_index),linear_to_db(0.55)), "SFX slider changes the real SFX bus")
    var window_option: OptionButton = settings.get_node("%WindowOption")
    if DisplayServer.get_name() != "headless":
        window_option.item_selected.emit(1)
        check(root.mode == Window.MODE_FULLSCREEN, "display option enters fullscreen")
        window_option.item_selected.emit(0)
        check(root.mode == Window.MODE_WINDOWED, "display option restores windowed mode")
    await click(settings.get_node("%BackButton"))
    check(not settings.visible and root.gui_get_focus_owner() == settings_button and not play.disabled, "mouse Back closes settings and restores menu focus")
    await click(settings_button)
    check(settings.visible, "mouse opens settings")
    await key(KEY_ESCAPE)
    check(not settings.visible and root.gui_get_focus_owner() == settings_button, "Escape also closes settings and restores focus")
    check_font(screen,preload("res://presentation/pixel_font.gd").create())
    var title_font: FontFile = title.theme.default_font as FontFile
    var settings_font: FontFile = settings.theme.default_font as FontFile
    check(title_font != null and not title_font.allow_system_fallback and title_font.fallbacks.is_empty() and play.get_theme_font("font") == title_font, "title controls resolve the bundled native font without fallback")
    check(settings_font != null and not settings_font.allow_system_fallback and settings_font.fallbacks.is_empty() and settings.get_node("%BackButton").get_theme_font("font") == settings_font and window_option.get_theme_font("font") == settings_font, "settings controls resolve the bundled native font without fallback")
    await click(play)
    for frame in range(5):
        await process_frame
    check(is_instance_valid(current_scene) and current_scene.name == "Bellkeep", "start loads the actual main gameplay scene")
    if is_instance_valid(current_scene) and current_scene.name == "Bellkeep":
        current_scene.set_process(false)
        current_scene.set_physics_process(false)
        current_scene.player.set_physics_process(false)
        current_scene.music.set_process(false)
    print("Title screen: %d passed, %d failed" % [passed,failed])
    quit(1 if failed else 0)

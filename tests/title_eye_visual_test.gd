extends SceneTree

var passed: int = 0
var failed: int = 0
var title: Control

func _initialize() -> void:
    call_deferred("run")

func check(ok: bool, label: String) -> void:
    if ok:
        passed += 1
        print("PASS ", label)
    else:
        failed += 1
        push_error("TITLE EYE FAIL: " + label)

func capture(file_name: String) -> Image:
    title.propagate_call("queue_redraw")
    await process_frame
    await RenderingServer.frame_post_draw
    var image: Image = root.get_texture().get_image()
    image.save_png("res://artifacts/title-screen/" + file_name)
    return image

func run() -> void:
    create_timer(20.0).timeout.connect(func() -> void:
        push_error("TITLE EYE FAIL: watchdog timeout")
        quit(2)
    )
    DirAccess.make_dir_recursive_absolute("res://artifacts/title-screen")
    root.size = Vector2i(800,450)
    title = load("res://ui/menus/title_menu.tscn").instantiate()
    root.add_child(title)
    current_scene = title
    await process_frame
    await process_frame
    title.set_process(false)
    var backdrop: Control = title.get_node("Backdrop")
    backdrop.set_process(false)
    backdrop.set("_clock", 2.0)
    var open: Image = await capture("eye-open.png")
    var iris: Color = open.get_pixel(350,220)
    check(iris.r > 0.25 and iris.r > iris.g * 1.8 and iris.r > iris.b * 1.25, "large eye has the reference crimson iris")
    var sclera: Color = open.get_pixel(180,220)
    check(sclera.r > 0.45 and sclera.g > 0.40 and sclera.b > 0.35, "large eye has a pale sculpted sclera")
    backdrop.set("_clock", 0.22)
    var blink: Image = await capture("eye-blink.png")
    var lid: Color = blink.get_pixel(400,220)
    check(absf(lid.r - 0.173) < 0.035 and absf(lid.g - 0.110) < 0.035 and absf(lid.b - 0.188) < 0.035, "eyelid closes over the pupil during a blink")
    backdrop.set("_clock", 2.0)
    var motion := InputEventMouseMotion.new()
    motion.position = Vector2(600,220)
    Input.parse_input_event(motion)
    Input.flush_buffered_events()
    await process_frame
    var gaze: Image = await capture("eye-gaze.png")
    check(open.get_pixel(392,202).r > 0.7 and gaze.get_pixel(392,202).r < 0.2, "pupil catchlight follows the pointer to a new position")
    print("Title eye: %d passed, %d failed" % [passed,failed])
    quit(1 if failed else 0)

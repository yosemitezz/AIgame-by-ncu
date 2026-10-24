extends SceneTree
## Bounded native-image/real-stage contracts; no game input or playthrough.
const Katana = preload("res://presentation/katana_visual.gd")
const Blade = preload("res://combat/boss_blade_geometry.gd")
var passed: int = 0
var failed: int = 0

class PoseProbe extends Node2D:
    var boss_pose_snapshot: Dictionary = {}
    var reaction_state: String = "none"
    var reaction_progress: float = 0.0
    var pose: Dictionary = {"state":"idle", "progress":0.0, "strike":0, "armored":false, "contact_serial":17}
    var blade: Dictionary = {}
    func get_presentation_pose() -> Dictionary: return pose.duplicate(true)
    func get_blade_state() -> Dictionary: return blade.duplicate(true)

func check(ok: bool, label: String) -> void:
    if ok: passed += 1
    else:
        failed += 1
        push_error("FAIL " + label)

func point(value: Array) -> Vector2:
    return Vector2(float(value[0]), float(value[1]))

func _initialize() -> void:
    var manifest: Dictionary = Katana.data()
    var states: Dictionary = Katana.states()
    var image: Image = Image.new()
    image.load_png_from_buffer(FileAccess.get_file_as_bytes("res://presentation/katana_frames/boss_atlas.png"))
    var report: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://presentation/katana_frames/family-report.json"))
    check(states.size() == 19 and manifest["total_frames"] == 78, "nineteen authored clips / seventy-eight cells")
    check(image.get_size() == Vector2i(1024,1280) and point(manifest["canvas"]) == Vector2(128,128) and point(manifest["anchor"]) == Vector2(48,116), "native canvas/feet anchor, no visual scaling")
    var names: Array[String] = ["idle","approach","shift","draw","cut_a","cut_b","recover","cast","parry_recoil","parry_recover","armored_recoil","guard_break","guard_recover","hurt","dead","retreat","jump","slam","land"]
    var starts: Array[int] = [0,4,10,14,18,22,26,30,34,38,42,46,50,54,58,62,66,70,74]
    var indices_ok: bool = true
    for i: int in names.size(): indices_ok = indices_ok and states[names[i]]["start"] == starts[i]
    check(indices_ok, "old fifteen clip indices retained; movement clips appended")
    check(report["preserved_reaction_and_dead"], "reaction and death pixel drawings retain prior hashes")
    check(report["all_alpha_binary"] and report["max_frame_colors"] <= 32 and report["all_frames_no_clipping"], "binary alpha / limited native palette / no frame-edge clipping")
    check(report["unique_frames"] >= 70, "family contains independent pixel poses")
    var colors: Array[Color] = [Color("9eb7c7"),Color("dcebf0"),Color("f6efdb"),Color("b89159"),Color("e3c286")]
    var total_samples: int = 0
    var matched_samples: int = 0
    for clip: String in ["cut_a","cut_b","slam"]:
        var angles: Array[float] = []
        var body_relative: Array[Vector2] = []
        for i: int in 4:
            var record: Dictionary = states[clip]["frames"][i]
            var guard: Vector2 = point(record["guard"])
            var tip: Vector2 = point(record["weapon_tip"])
            var expected_hint: bool = i in [1,2] if clip != "slam" else i >= 2
            check(record["hit_window"] == expected_hint, clip + " active hint " + str(i))
            angles.append(rad_to_deg((tip-guard).angle()))
            body_relative.append(point(record["joints"]["head"]) - point(record["joints"]["near_foot"]))
            var cell: Vector2i = Vector2i(Katana.region(clip,i).position)
            for sample: int in 25:
                var pixel: Vector2i = Vector2i((guard.lerp(tip,float(sample)/24.0) + Vector2(48,116)).round())
                var found: bool = false
                for ox: int in range(-3,4):
                    for oy: int in range(-3,4):
                        var at: Vector2i = pixel + Vector2i(ox,oy)
                        if at.x < 0 or at.y < 0 or at.x >= 128 or at.y >= 128: continue
                        var color: Color = image.get_pixelv(cell+at)
                        if color.a == 1.0 and colors.has(color): found = true
                total_samples += 1
                if found: matched_samples += 1
        check(angles.max()-angles.min() > 100.0, clip + " has an angular blade sweep")
        check(body_relative[0] != body_relative[1] and body_relative[1] != body_relative[2], clip + " changes anatomy/support instead of translating an image")
    check(total_samples == 300 and matched_samples == 300, "all 300 shared guard-to-tip raster samples touch drawn steel")
    for clip: String in ["retreat","jump","land"]:
        check(not states[clip]["frames"].any(func(frame: Dictionary) -> bool: return frame["hit_window"]), clip + " movement frames do not claim blade contact")
    var jump: Dictionary = states["jump"]["frames"][2]["joints"]
    var idle: Dictionary = states["idle"]["frames"][0]["joints"]
    check(point(jump["near_foot"]).y < point(idle["near_foot"]).y-10 and point(jump["far_knee"]).y < point(idle["far_knee"]).y-8, "jump has lifted feet and tucked knees")
    var probe := PoseProbe.new()
    var all_stages_match: bool = true
    for clip: String in names:
        var count: int = states[clip]["count"]
        for i: int in count:
            var progress: float = (float(i)+0.1)/count
            if clip == "guard_break": progress /= 4.0
            probe.pose = {"state":clip,"progress":progress,"strike":1,"armored":false,"contact_serial":17}
            var pose: Dictionary = Katana.describe(probe)
            var geometry: Dictionary = Blade.blade_pose(clip,progress,-1)
            all_stages_match = all_stages_match and pose["state"] == clip and pose["frame"] == i and pose["frame"] == geometry["frame"]
    check(all_stages_match, "all seventy-eight controller frames match shared blade geometry")
    probe.pose = {"state":"cut_b","progress":0.55,"strike":1,"armored":false,"contact_serial":77}
    var frozen: Dictionary = Katana.describe(probe)
    check(Katana.describe(probe) == frozen and Katana.describe(probe,"idle",3) == frozen, "unchanged stage progress holds the complete pose through local freeze")
    probe.boss_pose_snapshot = frozen.duplicate(true)
    probe.pose["state"] = "dead"
    check(Katana.describe(probe) == frozen, "ghost pose snapshot ignores later live state")
    probe.boss_pose_snapshot.clear()
    for alias: String in ["leap","landing"]:
        probe.pose = {"state":alias,"progress":0.5}
        check(Katana.describe(probe)["state"] == ("jump" if alias == "leap" else "land"), alias + " presentation alias resolves")
    var geometry: Dictionary = Blade.blade_pose("cut_a",0.3,-1)
    probe.blade = {"clip":"cut_a","progress":0.3,"from":geometry["root"],"to":geometry["tip"],"active":true,"parryable":true,"armored":false,"token":88}
    var edge: Dictionary = Katana.blade_segment(probe)
    check(edge["from"] == geometry["root"] and edge["to"] == geometry["tip"] and edge["to"].x < 0, "fine blade uses already-mirrored feet-local endpoints exactly once")
    edge["token"] = -1
    check(probe.blade["token"] == 88, "presentation does not mutate controller blade state")
    probe.blade["active"] = false
    check(Katana.blade_segment(probe).is_empty(), "cancel/rest inactive blade has no cached trace")
    probe.blade["active"] = true
    probe.blade["to"] = Vector2.INF
    check(Katana.blade_segment(probe).is_empty(), "invalid geometry cannot draw a stray line")
    probe.free()
    print("Boss duel visuals: %d passed, %d failed" % [passed,failed])
    quit(1 if failed else 0)

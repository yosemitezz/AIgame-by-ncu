extends SceneTree
## Pure actual-manifest/analytic sweep checks. Boss remains the active/occlusion authority.
const Blade = preload("res://combat/boss_blade_geometry.gd")
var passed: int = 0
var failed: int = 0

func check(ok: bool, label: String) -> void:
    if ok:
        passed += 1
        print("PASS ", label)
    else:
        failed += 1
        push_error("FAIL " + label)

func near(a: Vector2, b: Vector2) -> bool:
    return a.distance_to(b) < 0.0001

func _initialize() -> void:
    check(Blade.reload_manifest(), "actual katana manifest loads")
    var manifest: Dictionary = Blade.data()
    var all_landmarks_match: bool = true
    var all_mirrors_match: bool = true
    var frame_count: int = 0
    for clip: String in manifest["states"]:
        var row: Dictionary = manifest["states"][clip]
        var frames: Array = row["frames"]
        for index: int in frames.size():
            var progress: float = (float(index) + 0.1) / frames.size()
            if clip == "guard_break": progress /= 4.0
            var pose: Dictionary = Blade.blade_pose(clip, progress, 1)
            var flipped: Dictionary = Blade.blade_pose(clip, progress, -1)
            var root: Vector2 = Vector2(frames[index]["guard"][0], frames[index]["guard"][1])
            var tip: Vector2 = Vector2(frames[index]["weapon_tip"][0], frames[index]["weapon_tip"][1])
            all_landmarks_match = all_landmarks_match and pose["valid"] and pose["frame"] == index and near(pose["root"], root) and near(pose["tip"], tip)
            all_mirrors_match = all_mirrors_match and near(flipped["root"], Vector2(-root.x, root.y)) and near(flipped["tip"], Vector2(-tip.x, tip.y))
            frame_count += 1
    check(frame_count >= 62 and all_landmarks_match, "every actual frame uses exact guard/tip without subtracting anchor twice")
    check(all_mirrors_match, "every facing mirrors local X exactly once")
    var first: Dictionary = Blade.blade_pose("cut_a", 0.25, 1)
    var steel_center_active: Vector2 = (first["root"] as Vector2).lerp(first["tip"], 0.5)
    var front_box: Rect2 = Rect2(steel_center_active - Vector2(2, 2), Vector2(4, 4))
    check(first["frame"] == 1 and first["valid"] and first["hit_window"] and first["anchor"] == Vector2(48.0, 116.0), "actual active cut frame and stable feet anchor come from the manifest")
    check(Blade.frame_index("cut_a", 0.249) == 0 and Blade.frame_index("cut_a", 0.25) == 1 and Blade.frame_index("cut_a", 1.0) == 3, "frame selection agrees with floor(progress*count), clamped at end")
    check(Blade.frame_index("guard_break", 0.24) == 3, "guard break matches existing early-collapse visual hold")
    check(Blade.blade_pose("cut_a", -8.0, 0)["frame"] == 0 and Blade.blade_pose("cut_a", 8.0, 1)["frame"] == 3, "progress and zero facing are deterministic")
    var unknown: Dictionary = Blade.blade_pose("missing_clip", 0.5, 1)
    check(unknown["fallback"] and not unknown["valid"] and unknown["clip"] == "idle" and not unknown["hit_window"], "unknown clip safely displays idle landmarks and cannot become a valid collision pose")
    check(Blade.active_window("cut_a") == Vector2(0.25, 0.75) and Blade.active_window("cut_b") == Vector2(0.25, 0.75), "only cut frames one and two carry manifest active hints")
    check(Blade.active_window("draw") == Vector2(-1.0, -1.0), "anticipation has no manifest active hint")
    if manifest["states"].has("slam"):
        check(Blade.active_window("slam") == Vector2(0.5, 1.0), "new slam hint begins only at true downward frame two")
        check(not Blade.blade_pose("slam", 0.49, 1)["hit_window"] and Blade.blade_pose("slam", 0.5, 1)["hit_window"], "slam anticipation and downward blade share exact frame boundary")
        check(not Blade.blade_pose("jump", 0.6, 1)["hit_window"] and not Blade.blade_pose("retreat", 0.6, 1)["hit_window"] and not Blade.blade_pose("land", 0.6, 1)["hit_window"], "jump, retreat and landing remain non-damaging hints")
    # Static true blade, inclusive square-pixel thickness and forward/facing geometry.
    check(Blade.swept_touch(first["root"], first["tip"], first["root"], first["tip"], front_box), "actual active-frame steel intersects its true pixel blade hurt box")
    check(not Blade.swept_touch(first["root"], first["tip"], first["root"], first["tip"], Rect2(100.0, -30.0, 14.0, 26.0)), "blade cannot hit the old distant reach rectangle")
    check(not Blade.swept_touch(first["root"], first["tip"], first["root"], first["tip"], Rect2(-40.0, -30.0, 14.0, 26.0)), "right-facing steel cannot damage a target behind")
    var mirrored: Dictionary = Blade.blade_pose("cut_a", 0.25, -1)
    var mirrored_box: Rect2 = Rect2(Vector2(-front_box.end.x, front_box.position.y), front_box.size)
    check(Blade.swept_touch(mirrored["root"], mirrored["tip"], mirrored["root"], mirrored["tip"], mirrored_box) and not Blade.swept_touch(mirrored["root"], mirrored["tip"], mirrored["root"], mirrored["tip"], front_box), "left-facing steel swaps only the real forward side")
    check(Blade.swept_touch(Vector2.ZERO, Vector2(10, 0), Vector2.ZERO, Vector2(10, 0), Rect2(4, 1.5, 1, 1), 3.0), "pixel blade thickness includes its exact boundary")
    check(not Blade.swept_touch(Vector2.ZERO, Vector2(10, 0), Vector2.ZERO, Vector2(10, 0), Rect2(4, 1.51, 1, 1), 3.0), "outside pixel blade thickness does not hit")
    check(Blade.swept_touch(Vector2.ZERO, Vector2(10, 0), Vector2.ZERO, Vector2(10, 0), Rect2(11.5, 0, 1, 1), 3.0) and not Blade.swept_touch(Vector2.ZERO, Vector2(10, 0), Vector2.ZERO, Vector2(10, 0), Rect2(11.51, 0, 1, 1), 3.0), "tip cap has a finite exact pixel boundary")
    check(not Blade.swept_touch(Vector2.ZERO, Vector2(50, 50), Vector2.ZERO, Vector2(50, 50), Rect2(0, 40, 3, 3), 0.0), "empty corner inside a blade bounding rectangle stays harmless")
    # Target lies between both endpoint samples and is caught without a sampling timestep.
    check(Blade.swept_touch(Vector2(0, -20), Vector2(0, 20), Vector2(100, -20), Vector2(100, 20), Rect2(49, -1, 2, 2), 0.0), "fast translated blade catches an intermediate target")
    check(Blade.swept_touch(Vector2(0, -20), Vector2(0, 20), Vector2(1000000, -20), Vector2(1000000, 20), Rect2(543210, -1, 1, 2), 0.0), "analytic sweep is independent of render FPS or arbitrary sample cap")
    check(Blade.swept_touch(Vector2.ZERO, Vector2(100, 0), Vector2.ZERO, Vector2(0, 100), Rect2(48, 48, 2, 2), 0.0), "rotating endpoints cover the actual intermediate blade interior")
    check(not Blade.swept_touch(Vector2.ZERO, Vector2(100, 0), Vector2.ZERO, Vector2(0, 100), Rect2(74, 74, 2, 2), 0.0), "rotating blade does not fill the distant AABB corner")
    check(Blade.swept_touch(Vector2(0, 0), Vector2(0, 100), Vector2(100, 100), Vector2(100, 0), Rect2(24, 40, 1, 1), 0.0), "crossed endpoint paths still cover their real swept region")
    check(not Blade.swept_touch(Vector2(0, 0), Vector2(0, 100), Vector2(100, 100), Vector2(100, 0), Rect2(24, 89, 1, 1), 0.0), "crossed paths do not become an incorrect convex-hull hit")
    check(not Blade.swept_touch(Vector2(0, 0), Vector2(0, 100), Vector2(100, 100), Vector2(100, 0), Rect2(49, 9, 2, 2), 0.0), "collapsed intermediate zero blade cannot hit an arbitrary collinear root")
    check(Blade.swept_touch(Vector2.ZERO, Vector2.ZERO, Vector2(100, 0), Vector2(100, 0), Rect2(49, -1, 2, 2), 0.0), "moving zero-length point has a finite swept path")
    check(Blade.swept_touch(Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Rect2(-1, -1, 2, 2), 0.0) and not Blade.swept_touch(Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Rect2(9, 9, 2, 2), 3.0), "static zero vectors only touch their own finite location")
    check(not Blade.swept_touch(Vector2.INF, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Rect2(0, 0, 1, 1)), "non-finite blade input is rejected")
    check(not Blade.swept_touch(Vector2.ZERO, Vector2.ONE, Vector2.ZERO, Vector2.ONE, Rect2(Vector2.INF, Vector2.ONE)), "non-finite target input is rejected")
    check(not Blade.swept_touch(Vector2.ZERO, Vector2.ONE, Vector2.ZERO, Vector2.ONE, Rect2(0, 0, 1, 1), NAN), "non-finite thickness is rejected")
    check(Blade.swept_touch(Vector2.ZERO, Vector2(10, 0), Vector2.ZERO, Vector2(10, 0), Rect2(5, 1, -2, -2), 0.0), "negative-size target rectangles normalize safely")
    var origin: Vector2 = Vector2(3000, 300)
    check(Blade.swept_pose_touch(first, first, origin, origin, Rect2(front_box.position + origin, front_box.size)), "pose wrapper applies actual Boss origin exactly once")
    check(not Blade.swept_pose_touch(unknown, first, origin, origin, Rect2(front_box.position + origin, front_box.size)), "fallback pose cannot create wrapper damage")
    var draw: Dictionary = Blade.blade_pose("draw", 0.0, 1)
    var steel_center: Vector2 = (draw["root"] as Vector2).lerp(draw["tip"], 0.5)
    check(not draw["active_hint"] and Blade.swept_pose_touch(draw, draw, Vector2.ZERO, Vector2.ZERO, Rect2(steel_center - Vector2.ONE, Vector2(2, 2))), "geometry is pure: actual active authority remains with Boss")
    check(Engine.time_scale == 1.0, "pure geometry never changes world time")
    print("BOSS_BLADE_GEOMETRY_TEST: %d passed, %d failed; %d actual landmark frames" % [passed, failed, frame_count])
    quit(1 if failed > 0 else 0)

extends SceneTree
## Presentation-only replacement: exact original combat geometry and whole-family art QA.
const Katana = preload("res://presentation/katana_visual.gd")
const Blade = preload("res://combat/boss_blade_geometry.gd")
const CONTRACT: String = "res://tests/fixtures/boss_blade_contract_7c536d1.json"
var passed: int = 0
var failed: int = 0
func check(ok: bool, label: String) -> void:
    if ok: passed += 1; print("PASS ",label)
    else: failed += 1; push_error("FAIL " + label)
func vector(point: Array) -> Vector2: return Vector2(float(point[0]),float(point[1]))
func digest(bytes: PackedByteArray) -> String:
    var context: HashingContext = HashingContext.new()
    context.start(HashingContext.HASH_SHA256)
    context.update(bytes)
    return context.finish().hex_encode()
func _initialize() -> void:
    var before: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CONTRACT))
    var now: Dictionary = Katana.data()
    var image: Image = Image.new()
    image.load_png_from_buffer(FileAccess.get_file_as_bytes("res://presentation/katana_frames/boss_atlas.png"))
    var flash: Image = Image.new()
    flash.load_png_from_buffer(FileAccess.get_file_as_bytes("res://presentation/katana_frames/boss_flash.png"))
    var shadow: Image = Image.new()
    shadow.load_png_from_buffer(FileAccess.get_file_as_bytes("res://presentation/katana_frames/boss_silhouette.png"))
    check(now["canvas"] == before["canvas"] and now["anchor"] == before["anchor"] and now["columns"] == before["columns"], "native canvas and original feet anchor are unchanged")
    check(now["total_frames"] == 78 and now["states"].size() == 19, "all nineteen runtime clips / seventy-eight cells remain mapped")
    check(image.get_size() == Vector2i(1024,1280) and flash.get_size() == image.get_size() and shadow.get_size() == image.get_size(), "all three presentation atlases retain the original native grid")
    var changed: int = 0
    var bright_hair_frames: int = 0
    var all_alpha: bool = true
    var all_masks: bool = true
    var all_bounds: bool = true
    var max_colors: int = 0
    var palette: Array[Color] = [Color("341521"),Color("6e2330"),Color("ae3d3e"),Color("e66c4e"),Color("ffc382")]
    for clip: String in before["states"]:
        var old: Dictionary = before["states"][clip]
        var current: Dictionary = now["states"].get(clip,{})
        check(current.get("start",-1) == old["start"] and current.get("count",0) == old["count"], clip+" preserves clip indices and frame count")
        var geometry_ok: bool = true
        var mapping_ok: bool = true
        var feet_ok: bool = true
        var steel_ok: bool = true
        for index: int in old["count"]:
            var reference: Dictionary = old["frames"][index]
            var frame: Dictionary = current["frames"][index]
            for key: String in ["hand","support_hand","guard","weapon_tip","guard_point","hit_window"]:
                geometry_ok = geometry_ok and frame.get(key) == reference[key]
            for key: String in ["name","state","frame","progress"]:
                mapping_ok = mapping_ok and frame.get(key) == reference[key]
            for key: String in ["near_foot","far_foot"]:
                feet_ok = feet_ok and frame["joints"][key] == reference["baseline_joints"][key]
            var progress: float = (index+0.1)/float(old["count"])
            if clip == "guard_break": progress /= 4.0
            for facing: int in [-1,1]:
                var blade: Dictionary = Blade.blade_pose(clip,progress,facing)
                var root: Vector2 = vector(reference["guard"])
                var tip: Vector2 = vector(reference["weapon_tip"])
                root.x *= facing; tip.x *= facing
                steel_ok = steel_ok and blade["root"] == root and blade["tip"] == tip and blade["hit_window"] == reference["hit_window"]
            var rect: Rect2i = Rect2i(Katana.region(clip,index))
            var cell: Image = image.get_region(rect)
            if digest(cell.get_data()) != reference["baseline_raster_sha256"]: changed += 1
            var colors: Dictionary = {}
            var hair: Dictionary = {}
            var hair_count: int = 0
            var bounds: Rect2i = cell.get_used_rect()
            all_bounds = all_bounds and bounds.position.x > 0 and bounds.position.y > 0 and bounds.end.x < 128 and bounds.end.y < 128
            for y: int in range(bounds.position.y,bounds.end.y):
                for x: int in range(bounds.position.x,bounds.end.x):
                    var color: Color = cell.get_pixel(x,y)
                    all_alpha = all_alpha and color.a in [0.0,1.0]
                    all_masks = all_masks and flash.get_pixelv(rect.position+Vector2i(x,y)).a == color.a and shadow.get_pixelv(rect.position+Vector2i(x,y)).a == color.a
                    if color.a > 0.0:
                        colors[color.to_rgba32()] = true
                        if palette.has(color): hair[color.to_rgba32()] = true; hair_count += 1
            max_colors = maxi(max_colors,colors.size())
            if hair.size() >= 3 and hair_count >= 10: bright_hair_frames += 1
        check(geometry_ok and steel_ok,clip+" preserves original hands and true blade contacts on both facings")
        check(mapping_ok and feet_ok,clip+" preserves phase mapping and grounded/airborne foot landmarks")
    check(changed == 78,"all seventy-eight frame drawings updated, including reactions and death")
    check(bright_hair_frames == 78,"every runtime pose has layered auburn/red/copper hair")
    check(all_alpha and all_masks,"binary pixel edges and matching flash/ghost masks")
    check(all_bounds and max_colors <= 32,"all frames stay inside their cell and within32colors")
    var old_idle: Dictionary = before["states"]["idle"]["frames"][0]["baseline_joints"]
    var idle: Dictionary = now["states"]["idle"]["frames"][0]["joints"]
    var head_shift: float = vector(old_idle["head"]).y-vector(idle["head"]).y
    var shoulder_shift: float = vector(old_idle["shoulder"]).y-vector(idle["shoulder"]).y
    var hip_shift: float = vector(old_idle["hip"]).y-vector(idle["hip"]).y
    check(head_shift >= 10.0 and shoulder_shift >= 10.0 and hip_shift >= 3.0,"tall stature comes from higher head/shoulders/hips, not just hair")
    check(absf(head_shift-hip_shift) >= 5.0,"joint changes are unequal, preserving feet rather than stretching a sprite")
    var old_torso: float = vector(old_idle["hip"]).y-vector(old_idle["shoulder"]).y
    var torso: float = vector(idle["hip"]).y-vector(idle["shoulder"]).y
    var old_legs: float = vector(old_idle["near_foot"]).y-vector(old_idle["hip"]).y
    var legs: float = vector(idle["near_foot"]).y-vector(idle["hip"]).y
    check(torso >= old_torso+4 and legs >= old_legs+3,"longer torso and legs have separately authored proportions")
    print("Boss redhair visual: %d passed, %d failed" % [passed,failed])
    quit(1 if failed else 0)
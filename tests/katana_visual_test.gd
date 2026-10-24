extends SceneTree
const Visual = preload("res://presentation/katana_visual.gd")
const HeroVisual = preload("res://presentation/hero_attack_visual.gd")
var passed: int = 0
var failed: int = 0
class PoseActor extends Node2D:
    var pose: Dictionary = {}
    var boss_pose_snapshot: Dictionary = {}
    func get_presentation_pose() -> Dictionary:
        return pose
func check(ok: bool,label: String) -> void:
    if ok: passed += 1
    else:
        failed += 1
        push_error("FAIL "+label)
func _initialize() -> void:
    call_deferred("run")
func run() -> void:
    var actor := PoseActor.new()
    root.add_child(actor)
    var clips: Dictionary = Visual.states()
    check(clips.size()==15 and Visual.data()["total_frames"]==62,"fifteen complete Boss action clips are mapped")
    var texture: Image = Image.load_from_file("res://presentation/katana_frames/boss_atlas.png")
    check(texture.get_size()==Vector2i(1024,1024),"native Boss atlas dimensions match runtime slicing")
    for name: String in clips:
        for progress: float in [0.0,0.25,0.75,1.0]:
            actor.pose={"state":name,"progress":progress,"strike":1,"armored":false,"contact_serial":7}
            var pose: Dictionary = Visual.describe(actor)
            var region: Rect2 = Visual.region(str(pose["state"]),int(pose["frame"]))
            check(Rect2(Vector2.ZERO,Vector2(1024,1024)).encloses(region),"Boss clip slices valid: "+name)
            for point: String in ["hand","guard","weapon_tip"]:
                var local: Vector2 = Visual.landmark(name,int(pose["frame"]),point)+Vector2(48,116)
                check(local.x>=0 and local.y>=0 and local.x<128 and local.y<128,"Boss landmark inside cell: "+name+point)
    for name: String in ["cut_a","cut_b"]:
        var region: Rect2 = Visual.region(name,0)
        var covered: int = 0
        for x: int in range(14,61):
            var blade: bool = false
            for y: int in range(-26,-17):
                var pixel: Color = texture.get_pixel(int(region.position.x)+48+x,int(region.position.y)+116+y)
                blade = blade or (pixel.a>0.99 and pixel.r+pixel.g+pixel.b>1.5)
            if blade: covered += 1
        check(covered==47,"first-contact blade is raster-present along actual parry band: "+name)
    actor.pose={"state":"guard_break","progress":0.3}
    check(Visual.describe(actor)["frame"]==3,"guard collapse is visible early and holds through the real counter window")
    actor.pose={"state":"armored_recoil","progress":0.5,"armored":true,"contact_serial":8}
    var saved: Dictionary = Visual.describe(actor)
    actor.boss_pose_snapshot=saved.duplicate(true)
    actor.pose={"state":"dead","progress":1.0}
    check(Visual.describe(actor)==saved,"Boss ghost uses captured pose rather than changing live state")
    check(HeroVisual.states().size()==12,"full-body hero ground and airborne attack clips available")
    for combo: int in [1,2,3]:
        for frame: int in 4:
            check(HeroVisual.weapon_tip(combo,frame).is_finite() and HeroVisual.weapon_tip(combo,frame).length()>0,"real authored steel tip exposed")
    check(not FileAccess.file_exists("res://boss_attack/audio/if_infinity.ogg"),"private PR music is not in the playable branch")
    actor.free()
    print("Katana visuals: %d passed, %d failed" % [passed,failed])
    quit(1 if failed else 0)

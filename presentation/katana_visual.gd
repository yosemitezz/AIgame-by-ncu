extends RefCounted
## Presentation only. The Boss/director owns every clock, attack, hit and reaction.
const ROOT := "res://presentation/katana_frames/"
static var _manifest: Dictionary = {}
static var _textures: Dictionary = {}

static func data() -> Dictionary:
    if _manifest.is_empty():
        var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(ROOT+"manifest.json"))
        if parsed is Dictionary:
            _manifest = parsed
    return _manifest

static func states() -> Dictionary:
    return data().get("states", {})

static func describe(actor: Object, state: String = "idle", frame: int = 0) -> Dictionary:
    var snapshot: Variant = actor.get("boss_pose_snapshot")
    if snapshot is Dictionary and not snapshot.is_empty():
        return snapshot.duplicate(true)
    var pose: Dictionary = {}
    if actor.has_method("get_presentation_pose"):
        var requested: Variant = actor.call("get_presentation_pose")
        if requested is Dictionary:
            pose = requested.duplicate(true)
    if pose.is_empty():
        var reaction: Variant = actor.get("reaction_state")
        if reaction != null and str(reaction) not in ["", "none"]:
            var reaction_progress: Variant = actor.get("reaction_progress")
            pose = {"state": str(reaction), "progress": float(reaction_progress) if reaction_progress != null else 0.0, "strike": 0, "armored": false, "contact_serial": -1}
    if pose.is_empty():
        var aliases: Dictionary = {"run":"approach","dash":"shift","windup":"draw","attack":"cut_a","parry":"draw","parry_recover":"parry_recover","retreat":"recover"}
        pose = {"state": aliases.get(state,state), "progress": float(posmod(frame,4))/3.0, "strike":0, "armored":false, "contact_serial":-1}
    var clip: String = str(pose.get("state", "idle"))
    if not states().has(clip):
        clip = "idle"
    var progress: float = clampf(float(pose.get("progress",0.0)),0.0,1.0)
    var count: int = int(states().get(clip,{}).get("count",4))
    pose["state"] = clip
    pose["progress"] = progress
    var visual_progress: float = minf(1.0,progress*4.0) if clip=="guard_break" else progress
    pose["frame"] = clampi(int(visual_progress*count),0,count-1)
    return pose

static func region(clip: String, frame: int) -> Rect2:
    var descriptor: Dictionary = states().get(clip, states().get("idle",{}))
    var index: int = int(descriptor.get("start",0)) + clampi(frame,0,maxi(0,int(descriptor.get("count",4))-1))
    var size: Vector2 = Vector2(float(data()["canvas"][0]),float(data()["canvas"][1]))
    return Rect2(Vector2(index%int(data()["columns"]),index/int(data()["columns"]))*size,size)

static func landmark(clip: String, frame: int, key: String) -> Vector2:
    var descriptor: Dictionary = states().get(clip,states().get("idle",{}))
    var frames: Array = descriptor.get("frames",[])
    if frames.is_empty():
        return Vector2.ZERO
    var item: Dictionary = frames[clampi(frame,0,frames.size()-1)]
    var point: Array = item.get(key,[0,0])
    return Vector2(float(point[0]),float(point[1]))

static func _texture(name: String) -> Texture2D:
    if not _textures.has(name):
        _textures[name] = load(ROOT+name)
    return _textures[name]

static func paint(canvas: Node2D, state: String, frame: int, facing: int) -> void:
    var pose: Dictionary = describe(canvas,state,frame)
    var flashing: Variant = canvas.get("impact_flash")
    if flashing == null:
        flashing = canvas.get("hurt_flash")
    var flash: bool = flashing != null and float(flashing)>0.055 and str(pose["state"]) not in ["parry_recoil","armored_recoil","guard_break","guard_recover"]
    var texture: Texture2D = _texture("boss_flash.png" if flash else "boss_atlas.png")
    if texture == null:
        return
    var anchor: Vector2 = Vector2(float(data()["anchor"][0]),float(data()["anchor"][1]))
    canvas.draw_set_transform(Vector2.ZERO,0,Vector2(float(facing),1))
    canvas.draw_texture_rect_region(texture,Rect2(-anchor,region(str(pose["state"]),int(pose["frame"])).size),region(str(pose["state"]),int(pose["frame"])))
    canvas.draw_set_transform(Vector2.ZERO)

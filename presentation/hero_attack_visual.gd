extends RefCounted
## New full-body poses only; damage and energy boundaries come from AttackProfile.
const ROOT := "res://presentation/hero_attack_frames/"
static var _data: Dictionary = {}
static var _textures: Dictionary = {}
static func data() -> Dictionary:
    if _data.is_empty():
        var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(ROOT+"manifest.json"))
        if parsed is Dictionary:
            _data = parsed
    return _data
static func states() -> Dictionary:
    return data().get("states",data().get("hero",{}).get("states",{}))
static func key(combo: int, state: String, airborne: bool=false) -> String:
    var value: String = "cut_%d_%s" % [clampi(combo,1,3),"air_attack" if airborne and state=="attack" else state]
    return value if states().has(value) else "cut_1_attack"
static func region(clip: String, frame: int) -> Rect2:
    var entry: Dictionary = states()[clip]
    var index: int = int(entry["start"])+clampi(frame,0,int(entry["count"])-1)
    return Rect2(Vector2(index%8,index/8)*Vector2(128,96),Vector2(128,96))
static func weapon_tip(combo: int, frame: int, airborne: bool=false) -> Vector2:
    var name: String = key(combo,"attack",airborne)
    var table: Dictionary = data().get("hero",{}).get("weapon_tips",{})
    var points: Array = table.get(name,[])
    if points.is_empty():
        return Vector2.ZERO
    var at: Array = points[clampi(frame,0,points.size()-1)]
    return Vector2(float(at[0]),float(at[1]))
static func paint(canvas: Node2D, state: String, frame: int, facing: int, combo: int) -> void:
    var airborne: bool = canvas.has_method("is_on_floor") and not bool(canvas.call("is_on_floor"))
    var clip: String = key(combo,state,airborne)
    var flash: Variant = canvas.get("impact_flash")
    var filename: String = "hero_flash.png" if flash != null and float(flash)>0.055 else "hero_atlas.png"
    if not _textures.has(filename):
        _textures[filename] = load(ROOT+filename)
    var texture: Texture2D = _textures[filename]
    if texture == null:
        return
    canvas.draw_set_transform(Vector2.ZERO,0,Vector2(float(facing),1))
    canvas.draw_texture_rect_region(texture,Rect2(Vector2(-48,-88),Vector2(128,96)),region(clip,frame))
    canvas.draw_set_transform(Vector2.ZERO)

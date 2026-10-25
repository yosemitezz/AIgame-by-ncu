extends Node2D
## Original pixel companion. Reads story and hero pose; never writes gameplay.
var game: Node
var hero: Node2D
var story: Dictionary = {}
var _clock: float = 0.0
var _snapped: bool = false
const MAX_FOLLOW_DISTANCE: float = 150.0

func configure(owner_game: Node, owner_hero: Node2D) -> void:
    game = owner_game
    hero = owner_hero
    process_mode = Node.PROCESS_MODE_PAUSABLE
    texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    z_index = 4
    snap_to_hero()

func update_story(value: Dictionary) -> void:
    story = value.duplicate(true)
    visible = not bool(story.get("narrative_dead", false)) and not bool(story.get("ending_dismissed",false)) and float(story.get("blackout", 0.0)) < 0.98
    queue_redraw()

func follow_target() -> Vector2:
    if not is_instance_valid(hero): return global_position
    var face: Variant = hero.get("facing")
    var sign_x: float = -1.0 if face != null and int(face) < 0 else 1.0
    return hero.global_position + Vector2(-sign_x * 31.0, -67.0) + Vector2(sin(_clock * 1.6) * 3.0, sin(_clock * 3.3) * 3.0)

func snap_to_hero() -> void:
    if is_instance_valid(hero):
        global_position = follow_target().round()
        _snapped = true

func _process(delta: float) -> void:
    _clock = fmod(_clock + maxf(delta, 0.0), 1000.0)
    if not is_instance_valid(hero):
        visible = false
        return
    var target: Vector2 = follow_target()
    if not _snapped or global_position.distance_to(target) > MAX_FOLLOW_DISTANCE:
        global_position = target.round()
        _snapped = true
    else:
        global_position = global_position.lerp(target, 1.0-exp(-maxf(delta,0.0)*9.0))
    queue_redraw()

func _draw() -> void:
    if not is_instance_valid(hero): return
    var mood: String = str(story.get("eye_mood", "friendly"))
    var offset: Vector2 = hero.global_position + Vector2(0,-40) - global_position
    var look: Vector2 = offset.normalized() * 2.0 if offset.length_squared() > 1.0 else Vector2.ZERO
    var blink: float = maxf(0.0, 1.0-absf(fmod(_clock,4.4)-4.25)/0.08) if mood != "cold" else 0.0
    if bool(story.get("rescue_flare",false)) and bool(story.get("blocking",false)):
        var flare: float=sin(clampf(float(story.get("progress",0.0)),0.0,1.0)*PI)
        for i: int in 6:
            var angle: float=float(i)*TAU/6.0
            var at: Vector2=(Vector2.from_angle(angle)*(19.0+flare*5.0)).round()
            draw_rect(Rect2(at,Vector2(2,2)),Color(.94,.90,.68,.55*flare))
    draw_eye(self, Vector2.ZERO, 1, mood, look, sin(_clock*13.0), blink)

static func draw_eye(canvas: CanvasItem, at: Vector2, pixel_scale: int = 1, mood: String = "friendly", look: Vector2 = Vector2.ZERO, flutter: float = 0.0, blink: float = 0.0) -> void:
    var k: int = clampi(pixel_scale,1,5)
    var center: Vector2 = at.round()
    var ink := Color("111320")
    var shell := Color("705776")
    var pale := Color("ede6cd")
    var violet := Color("9b7baf")
    var cold: bool = mood == "cold"
    # Two articulated eyelid fins. Integer vertices, no glow/texture filtering.
    for sign_x: int in [-1,1]:
        var rise: int = roundi(flutter*3.0)
        var fin:=PackedVector2Array([Vector2(sign_x*9,-2),Vector2(sign_x*16,-9-rise),Vector2(sign_x*22,-7-rise),Vector2(sign_x*18,1),Vector2(sign_x*12,4)])
        for i: int in fin.size(): fin[i]=center+fin[i]*k
        canvas.draw_colored_polygon(fin,ink)
        var inner:=PackedVector2Array([Vector2(sign_x*12,-2),Vector2(sign_x*17,-6-rise),Vector2(sign_x*19,-6-rise),Vector2(sign_x*16,0)])
        for i: int in inner.size(): inner[i]=center+inner[i]*k
        canvas.draw_colored_polygon(inner,shell if cold else violet)
    var outer:=PackedVector2Array([Vector2(-12,0),Vector2(-8,-6),Vector2(-2,-8),Vector2(6,-6),Vector2(12,0),Vector2(8,6),Vector2(0,8),Vector2(-8,6)])
    var inner:=PackedVector2Array([Vector2(-10,0),Vector2(-6,-4),Vector2(0,-6),Vector2(6,-4),Vector2(10,0),Vector2(6,4),Vector2(0,6),Vector2(-6,4)])
    for i: int in outer.size(): outer[i]=center+outer[i]*k
    for i: int in inner.size(): inner[i]=center+inner[i]*k
    canvas.draw_colored_polygon(outer,ink)
    canvas.draw_colored_polygon(inner,pale if not cold else Color("c3bda9"))
    var gaze: Vector2 = Vector2(clampf(look.x,-2,2),clampf(look.y,-2,2)).round()*k
    var iris: Color = Color("c06251") if cold else Color("62c6ba")
    canvas.draw_rect(Rect2(center+gaze+Vector2(-4,-5)*k,Vector2(8,10)*k),shell)
    canvas.draw_rect(Rect2(center+gaze+Vector2(-3,-4)*k,Vector2(6,8)*k),iris)
    canvas.draw_rect(Rect2(center+gaze+Vector2(-1,-4)*k,Vector2(2,8)*k),ink)
    if not cold: canvas.draw_rect(Rect2(center+gaze+Vector2(-2,-3)*k,Vector2(k,k)),Color("ffffff"))
    # Eyelid, not rapid flashing. Cold gaze is a stable narrowed eye.
    var lid: int = 3 if cold else roundi(clampf(blink,0,1)*7.0)
    if lid > 0:
        canvas.draw_rect(Rect2(center+Vector2(-11,-7)*k,Vector2(22,lid)*k),ink)
        canvas.draw_rect(Rect2(center+Vector2(-10,7-lid)*k,Vector2(20,lid)*k),ink)
    var brow_y: int = -6 if cold else -9
    canvas.draw_line(center+Vector2(-9,brow_y)*k,center+Vector2(-2,brow_y+(2 if cold else -1))*k,Color("b193bc"),k,false)
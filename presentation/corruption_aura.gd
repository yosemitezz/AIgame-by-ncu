extends Node2D
## Bounded edge wisps. Reads narrative corruption only; zero means clean armour.
var hero: Node2D
var story: Dictionary = {}
var amount: float = 0.0
var _clock: float = 0.0
const MAX_WISPS: int = 14
const BOUNDS := Rect2(-31,-70,62,76)

func configure(owner_hero: Node2D) -> void:
    hero=owner_hero
    process_mode=Node.PROCESS_MODE_PAUSABLE
    texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
    z_as_relative=false
    z_index=2
    visible=false

func update_story(value: Dictionary) -> void:
    story=value.duplicate(true)
    amount=clampf(float(story.get("corruption",0.0)),0.0,1.0)
    visible=amount>0.001 and not bool(story.get("narrative_dead",false))
    queue_redraw()

func _process(delta: float) -> void:
    _clock=fmod(_clock+maxf(delta,0),1000.0)
    if not is_instance_valid(hero):
        visible=false
        return
    global_position=hero.global_position.round()
    queue_redraw()

func wisp_count() -> int:
    return 0 if amount<=0.001 else clampi(1+int(ceil(amount*13.0)),1,MAX_WISPS)

func fragments() -> Array[Dictionary]:
    var pieces: Array[Dictionary]=[]
    var count: int=wisp_count()
    for i: int in count:
        var side: float=-1.0 if i%2==0 else 1.0
        var life: float=fposmod(_clock*(0.30+float(i%3)*0.035)+float(i)*0.161,1.0)
        var lift: float=life*(29.0+amount*23.0)
        var x: float=side*(12.0+sin(life*4.0+i)*4.0+amount*float(i%3)*2.0)
        var y: float=-8.0-lift
        var strength: float=(0.04+amount*0.62)*sin(life*PI)
        pieces.append({"at":Vector2(roundf(x),roundf(y)),"alpha":strength,"width":2.0 if amount<0.55 else 3.0,"height":3.0+floorf(amount*3.0)})
    return pieces

func ribbon_paths() -> Array[PackedVector2Array]:
    var paths: Array[PackedVector2Array]=[]
    if amount<0.95: return paths
    for side: int in [-1,1]:
        var path:=PackedVector2Array()
        for index: int in 10:
            var t: float=float(index)/9.0
            path.append(Vector2(roundf(side*(16.0+sin(t*5.0+_clock*1.2+side)*4.0+t*3.0)),roundf(-3.0-t*59.0)))
        paths.append(path)
    return paths

func _draw() -> void:
    if amount<=0.001 or not is_instance_valid(hero): return
    # Only the boss-complete intensity gets two narrow rising smoke ribbons.
    # Their middle stays open: armour, face and surrounding shots remain readable.
    for path: PackedVector2Array in ribbon_paths():
        draw_polyline(path,Color(0.04,0.025,0.07,0.48),4.0,false)
        draw_polyline(path,Color(0.52,0.29,0.45,0.46),1.0,false)
    for item: Dictionary in fragments():
        var at: Vector2=item["at"]
        var ink:=Color("100d18");ink.a=float(item["alpha"])
        var rim:=Color("8a6aab") if amount<0.80 else Color("bd7997")
        rim.a=float(item["alpha"])*0.85
        draw_rect(Rect2(at,Vector2(item["width"],item["height"])),ink)
        draw_rect(Rect2(at+Vector2(-1,-2),Vector2(1,3)),rim)
    if amount>0.78:
        # Small broken floor halo remains behind the feet; never a filled screen mask.
        var ink:=Color(0.32,0.12,0.31,0.35*amount)
        for i: int in 8:
            var angle: float=float(i)*TAU/8.0+_clock*0.13
            var at:=Vector2(roundf(cos(angle)*22.0),roundf(sin(angle)*5.0)-1.0)
            draw_rect(Rect2(at,Vector2(3,1)),ink)
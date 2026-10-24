extends Node2D
## Standalone Boss room. This node never instantiates the dungeon or its actors.
const ROOM_ID: String = "boss"
const SPAWN: Vector2 = Vector2(2706, 300)
const CHECKPOINT: Vector2 = SPAWN
const BOSS_POSITION: Vector2 = Vector2(2990, 250)
const BOSS_TRIGGER_X: float = 2660.0
const LEVEL_END: float = 3380.0
const WORLD_BOUNDS: Rect2 = Rect2(2580, -120, 840, 620)
const FALL_LIMIT: float = 720.0
const CHECKPOINT_RECT: Rect2 = Rect2(2688, 256, 36, 52)
const CEILING_RECT: Rect2 = Rect2(2619, -132, 752, 12)
const PLATFORMS: Array[Rect2] = [
    Rect2(2580, 300, 840, 120),
    Rect2(2690, 252, 94, 12),
    Rect2(2834, 210, 104, 12),
    Rect2(3124, 252, 100, 12),
    Rect2(2619, -120, 12, 420),
    Rect2(3359, -120, 12, 420),
    CEILING_RECT, # Append-only: original platform/body indices 0..5 are stable.
]
const ENEMIES: Array[Dictionary] = []
const CLIMBABLES: Array[Dictionary] = []
const WATER_REGIONS: Array[Rect2] = []
const DOORS: Array[Dictionary] = []
const SHARDS: Array[Vector2] = [Vector2(2914,186)]
const ZONES: Array[Dictionary] = [{"x": 2580.0, "title": "THE HOLLOW BELFRY", "hint": "Close the distance / Parry the golden rain"}]
const ROOMS: Array[Dictionary] = [{"id": ROOM_ID, "rect": WORLD_BOUNDS, "title": "THE HOLLOW BELFRY", "hint": "Close the distance / Parry the golden rain"}]
const LIGHTS: Array[Dictionary] = [
    {"at":Vector2(2648,264),"r":70,"tint":Color("ff9a4a"),"a":0.24},
    {"at":Vector2(3328,264),"r":70,"tint":Color("ff9a4a"),"a":0.24},
    {"at":Vector2(2990,120),"r":150,"tint":Color("d03a48"),"a":0.20},
]
const DARK: Color = Color("0f0b16")
const FAR: Color = Color("1a1524")
const MID: Color = Color("241d30")
const MASON: Color = Color("322b3c")
const STONE: Color = Color("41394b")
const LIP: Color = Color("786b7e")
const GOLD_LOW: Color = Color("7d5a3c")
const GOLD: Color = Color("c08a4a")
var game: Node
var _built: bool = false
var _clock: float = 0.0
var _draw_clock: float = 0.0

func get_room_spec() -> Dictionary:
    return {"id":ROOM_ID,"title":"THE HOLLOW BELFRY","bounds":WORLD_BOUNDS,"spawn":SPAWN,"checkpoint":CHECKPOINT,"boss_spawn":BOSS_POSITION,"portal_at":SPAWN,"fall_limit":FALL_LIMIT,"platforms":PLATFORMS.duplicate(),"shard_indices":[11]}

func setup(p_game: Node) -> void:
    game = p_game
    z_index = -20
    texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    if _built: return
    _built = true
    for index in range(PLATFORMS.size()):
        var area: Rect2 = PLATFORMS[index]
        var body := StaticBody2D.new()
        body.name = "ChamberMasonry_%02d" % index
        body.collision_layer = 1
        body.collision_mask = 0
        body.position = area.get_center()
        var collider := CollisionShape2D.new()
        var shape := RectangleShape2D.new()
        shape.size = area.size
        collider.shape = shape
        collider.one_way_collision = area.size.y <= 16.0 and area != CEILING_RECT
        collider.one_way_collision_margin = 4.0
        body.add_child(collider)
        add_child(body)
    queue_redraw()

func climb_at(_feet: Vector2) -> Dictionary: return {}
func water_at(_feet: Vector2) -> bool: return false
func portal_at(_feet: Vector2) -> Dictionary: return {}
func interaction_hint(_feet: Vector2) -> String: return ""
func try_interact(_feet: Vector2) -> bool: return false
func get_opened_ids() -> Array[String]: return []
func restore_opened_ids(_ids: Array) -> void: pass
func reset_interactions() -> void: pass
func room_at(feet: Vector2) -> Dictionary:
    return ROOMS[0].duplicate() if WORLD_BOUNDS.has_point(feet) else {}

func _process(delta: float) -> void:
    _clock += delta
    _draw_clock += delta
    if _draw_clock >= 0.125:
        _draw_clock = 0.0
        queue_redraw()

func _draw() -> void:
    draw_rect(WORLD_BOUNDS, DARK)
    # Flat brick courses and stepped lancets keep the scene in a pixel plane.
    for row in range(22):
        var y: int = -112 + row * 20
        draw_rect(Rect2(2628,y,732,1),FAR)
        for col in range(19):
            var x: int = 2630 + col * 40 + (20 if row % 2 else 0)
            draw_rect(Rect2(x,y+1,1,19),FAR)
    for x in [2672,2792,3100,3240]:
        _draw_arch(x,-40,96,252,FAR)
        draw_rect(Rect2(x+16,8,64,124),Color("211526"))
        for pane in range(5):
            draw_rect(Rect2(x+22+pane*11,20,5,96),Color("422336") if pane % 2 else Color("32213d"))
        draw_rect(Rect2(x+44,-2,8,150),MASON)
        draw_rect(Rect2(x+12,78,72,5),MASON)
    _draw_arch(2750,14,470,286,FAR)
    _draw_bell()
    for x in [2640,2780,3100,3332]:
        draw_rect(Rect2(x,-120,12,410),MID)
        draw_rect(Rect2(x-4,284,20,16),STONE)
        draw_rect(Rect2(x-2,60,16,8),MASON)
    for area: Rect2 in PLATFORMS:
        _draw_platform(area)
    for x in [2648,3328]:
        _draw_torch(x,278)
    # Entry has a shut door silhouette, clearly separated from the dungeon tree.
    draw_rect(Rect2(2632,194,28,106),DARK)
    for x in range(2634,2660,6):
        draw_rect(Rect2(x,200,2,98),GOLD_LOW)

func _draw_platform(area: Rect2) -> void:
    draw_rect(area,DARK)
    draw_rect(Rect2(area.position.x,area.position.y,area.size.x,4),LIP)
    draw_rect(Rect2(area.position.x,area.position.y+4,area.size.x,4),STONE)
    var row_count: int = maxi(1,int((area.size.y-8)/18))
    for row in range(row_count):
        var y: float = area.position.y+9+row*18
        var offset: int = 18 if row % 2 else 0
        for col in range(int(area.size.x/36)+1):
            var left: float = maxf(area.position.x+2,area.position.x+col*36-offset+2)
            var right: float = minf(area.end.x-2,area.position.x+col*36-offset+34)
            if right > left:
                draw_rect(Rect2(left,y,right-left,minf(14,area.end.y-y)),MASON if row < 2 else MID)
    if area.size.y <= 16:
        for x in range(int(area.position.x)+8,int(area.end.x)-8,24):
            draw_rect(Rect2(x,area.position.y+4,1,8),DARK)

func _draw_arch(x: int,top: int,width: int,height: int,tint: Color) -> void:
    draw_rect(Rect2(x,top+32,12,height-32),tint)
    draw_rect(Rect2(x+width-12,top+32,12,height-32),tint)
    for step in range(4):
        var inset: int = 8+step*8
        draw_rect(Rect2(x+inset,top+24-step*8,width-inset*2,8),tint)
    draw_rect(Rect2(x-4,top+height-10,20,10),tint)
    draw_rect(Rect2(x+width-16,top+height-10,20,10),tint)

func _draw_bell() -> void:
    draw_rect(Rect2(2978,-60,16,120),MID)
    for band: Rect2 in [Rect2(2956,38,60,12),Rect2(2936,50,100,12),Rect2(2924,62,124,48),Rect2(2912,106,148,12),Rect2(2902,118,168,12)]:
        draw_rect(band,MASON)
    draw_rect(Rect2(2944,62,4,32),STONE)
    draw_rect(Rect2(2996,54,6,20),DARK)
    draw_rect(Rect2(2988,70,8,16),DARK)
    draw_rect(Rect2(2994,82,6,24),DARK)
    draw_rect(Rect2(2978,130,16,22),GOLD_LOW)
    draw_rect(Rect2(2966,148,40,8),GOLD_LOW)

func _draw_torch(x: int,y: int) -> void:
    draw_rect(Rect2(x-4,y-10,8,10),MASON)
    draw_rect(Rect2(x-2,y-14,4,6),GOLD_LOW)
    var flicker: int = 2 if int(_clock*8+x)%3 == 0 else 0
    draw_rect(Rect2(x-2,y-19-flicker,4,6+flicker),GOLD)
    draw_rect(Rect2(x,y-18-flicker,2,4),Color("d7c898"))

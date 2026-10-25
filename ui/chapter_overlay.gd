extends Control
## Read-only chapter presentation. Root owns input, safety, persistence and transitions.
const PixelFont = preload("res://presentation/pixel_font.gd")
const Eye = preload("res://presentation/flying_eye.gd")
const WHITE := Color("eee9d8")
const RED := Color("bf243c")
const DARK_RED := Color("6e152d")
const INK := Color("10121c")
const STRINGS: Array[String] = ["第一章","飞眼","你死亡","章节完成","E / Enter 继续    Backspace 跳过","章节已完成 · Enter 返回地牢 · V 重看结局","暂停","重看"]
var state: Dictionary = {}
var font: Font
var _clock: float = 0.0
var _suspended: bool = false

func _ready() -> void:
    process_mode=Node.PROCESS_MODE_PAUSABLE
    mouse_filter=Control.MOUSE_FILTER_IGNORE
    texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
    font=PixelFont.create()
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    resized.connect(queue_redraw)

func update_state(value: Dictionary) -> void:
    var old_scene: String=str(state.get("scene_id",""))
    var old_node: String=str(state.get("line_id",""))
    var old_phase: String=str(state.get("phase",""))
    state=value.duplicate(true)
    if old_scene!=str(state.get("scene_id","")) or old_node!=str(state.get("line_id","")) or old_phase!=str(state.get("phase","")):
        _clock=0.0
    queue_redraw()

func set_suspended(value: bool) -> void:
    _suspended=value
    visible=not value
    queue_redraw()

func _process(delta: float) -> void:
    _clock=minf(60.0,_clock+maxf(0.0,delta))
    if is_blocking() or str(state.get("line","")).length()>0: queue_redraw()

func is_blocking() -> bool:
    return bool(state.get("blocking",false)) or bool(state.get("narrative_dead",false))

func phase_elapsed() -> float:
    if bool(state.get("narrative_dead",false)):
        return maxf(0.0,float(state.get("death_elapsed",_clock)))
    return maxf(0.0,float(state.get("node_elapsed",_clock)))

func panel_layout(canvas: Vector2) -> Dictionary:
    return {"dialog":Rect2(48,canvas.y-142,canvas.x-96,100),"bark":Rect2(16,56,canvas.x-32,52),"eye":Vector2(canvas.x*.5,canvas.y*.34),"death_baseline":canvas.y*.58,"hints":canvas.y-24}

func eye_closeup_visible() -> bool:
    return bool(state.get("eye_closeup",false)) and not bool(state.get("narrative_dead",false))

func death_title() -> String:
    var supplied: String=str(state.get("death_title",""))
    if not supplied.is_empty():return supplied
    var line: String=str(state.get("line",""))
    return line if str(state.get("line_id",""))=="DEATH_NARRATIVE" and not line.is_empty() else "你死亡"

func death_ink() -> Color:
    # Existing ordinary defeat HUD keeps its normal colour; this is narrative-only.
    return RED if bool(state.get("narrative_dead",false)) and bool(state.get("bloodred",false)) else WHITE

func blood_segments() -> Array[Rect2]:
    var pieces: Array[Rect2]=[]
    if not bool(state.get("narrative_dead",false)) or not bool(state.get("bloodred",false)) or font==null: return pieces
    var title: String=death_title()
    var width: float=font.get_string_size(title,HORIZONTAL_ALIGNMENT_LEFT,-1,48).x
    var left: float=roundf((size.x-width)*.5)
    var baseline: float=roundf(size.y*.58)
    var elapsed: float=phase_elapsed()
    for i: int in 9:
        var delay: float=.10+float(i%4)*.11
        var growth: float=clampf((elapsed-delay)/1.8,0.0,1.0)
        if growth<=0.0: continue
        var x: float=left+roundf(width*(.08+.102*float(i)))
        var length: float=roundf((12.0+float((i*7)%31))*growth)
        pieces.append(Rect2(x,baseline+5,2.0 if i%3 else 3.0,length))
    return pieces

func _text(at: Vector2,value: String,point_size: int=12,ink: Color=WHITE,width: float=-1.0) -> void:
    draw_string(font,at.round(),value,HORIZONTAL_ALIGNMENT_LEFT,width,point_size,ink)

func _center(y: float,value: String,point_size: int=12,ink: Color=WHITE) -> void:
    var width: float=font.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,point_size).x
    _text(Vector2((size.x-width)*.5,y),value,point_size,ink)

func _frame(rect: Rect2,ink: Color=WHITE) -> void:
    draw_rect(rect,ink)
    draw_rect(rect.grow(-2),Color(0.035,0.04,0.07,.96))

func _vignette(strength: float) -> void:
    var value: float=clampf(strength,0.0,1.0)
    for i: int in 9:
        var alpha: float=value*(.13-.011*float(i))
        var edge: float=8.0
        var inset: float=float(i)*edge
        draw_rect(Rect2(inset,inset,size.x-inset*2,edge),Color(0,0,0,alpha))
        draw_rect(Rect2(inset,size.y-inset-edge,size.x-inset*2,edge),Color(0,0,0,alpha))
        draw_rect(Rect2(inset,inset,edge,size.y-inset*2),Color(0,0,0,alpha))
        draw_rect(Rect2(size.x-inset-edge,inset,edge,size.y-inset*2),Color(0,0,0,alpha))

func _vision_close(strength: float) -> void:
    # Fainting vision: nested edge bands tighten toward the centre as darkness rises.
    var value: float=clampf(strength,0.0,1.0)
    if value<=0.0:return
    var bands: int=16
    var reach: float=minf(size.x,size.y)*.5*value
    var band: float=maxf(1.0,reach/float(bands))
    for i: int in bands:
        var inset: float=float(i)*band
        var alpha: float=value*(.10+.50*(1.0-float(i)/float(bands)))
        draw_rect(Rect2(inset,inset,size.x-inset*2,band),Color(0,0,0,alpha))
        draw_rect(Rect2(inset,size.y-inset-band,size.x-inset*2,band),Color(0,0,0,alpha))
        draw_rect(Rect2(inset,inset,band,size.y-inset*2),Color(0,0,0,alpha))
        draw_rect(Rect2(size.x-inset-band,inset,band,size.y-inset*2),Color(0,0,0,alpha))

func _draw() -> void:
    if _suspended or state.is_empty() or font==null: return
    var phase: String=str(state.get("phase","explore"))
    var blocking: bool=is_blocking()
    var line: String=str(state.get("line",state.get("text","")))
    var elapsed: float=phase_elapsed()
    var layout: Dictionary=panel_layout(size)
    var blackout: float=clampf(float(state.get("blackout",0.0)),0.0,1.0)
    if blocking:
        draw_rect(Rect2(Vector2.ZERO,size),Color(0,0,0,blackout))
        _vignette(.35 if phase=="opening" else .70)
        if phase in ["aftermath","betrayal"] and blackout>0.0 and blackout<1.0:
            _vision_close(smoothstep(0.0,1.0,blackout))
        draw_rect(Rect2(0,0,size.x,26),Color(0,0,0,.86))
        draw_rect(Rect2(0,size.y-26,size.x,26),Color(0,0,0,.86))
    if phase=="rescue":
        var dizzy: float=clampf(float(state.get("dizzy",1.0)),0.0,1.0)
        # One slow arc of six dull stars; no full-screen flash or rapid strobe.
        for i: int in 6:
            var angle: float=float(i)*TAU/6.0+minf(elapsed,2.0)*.55
            var point: Vector2=Vector2(size.x*.5+cos(angle)*55.0,size.y*.41+sin(angle)*13.0)
            draw_rect(Rect2(point.round(),Vector2(2,2)),Color(.81,.72,.44,.5*dizzy))
    if eye_closeup_visible() or bool(state.get("narrative_dead",false)):
        draw_rect(Rect2(Vector2.ZERO,size),Color(0,0,0,1))
        if eye_closeup_visible():
            Eye.draw_eye(self,layout["eye"],3,"cold",Vector2.ZERO,0,0)
            # The last sight of the eye dims out before the death broadcast.
            var faint: float=clampf(float(state.get("faint",0.0)),0.0,1.0)
            if faint>0.0:
                draw_rect(Rect2(Vector2.ZERO,size),Color(0,0,0,smoothstep(0.0,1.0,faint)))
    if bool(state.get("narrative_dead",false)):
        var color: Color=death_ink()
        _center(size.y*.58,death_title(),48,color)
        for rect: Rect2 in blood_segments():
            draw_rect(rect,DARK_RED)
            draw_rect(Rect2(rect.position+Vector2(0,maxf(0,rect.size.y-3)),Vector2(rect.size.x,3)),color)
        _center(size.y*.76,str(state.get("completion_label","")),12,WHITE)
        _center(float(layout["hints"]),str(state.get("hint","章节已完成 · Enter 返回地牢 · V 重看结局")),12,Color("a99cad"))
        return
    if not line.is_empty():
        var box: Rect2=layout["dialog"] if blocking else layout["bark"]
        _frame(box,Color("b89fbe") if phase=="betrayal" else WHITE)
        var speaker: String=str(state.get("speaker",""))
        var content: String=(speaker+"：" if not speaker.is_empty() else "")+line
        draw_multiline_string(font,(box.position+Vector2(14,22)).round(),content,HORIZONTAL_ALIGNMENT_LEFT,box.size.x-28,12,3,WHITE)
        if blocking:
            _text(box.position+Vector2(14,box.size.y-13),str(state.get("hint","E / Enter 继续    Backspace 跳过")),12,Color("a99cad"),box.size.x-28)
    if phase=="opening": _center(19,"第一章",12,Color("cbb98b"))
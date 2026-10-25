extends Node
## One moving-hero presentation owner. Every afterimage is an actual past pose/location.
## Only historical sprite pixels are softened; gameplay, enemies and HUD are never sampled.
const Renderer = preload("res://presentation/actor_renderer.gd")
const CONFIG: String = "res://data/motion_effects.json"
var game: Node
var service: Node
var canvas: Node2D
var settings: Dictionary = {}
var _samples: Array[Dictionary] = []
var _anchor: Dictionary = {}
var _last_observed: Vector2 = Vector2.INF
var _last_room: String = ""
var _clock: float = 0.0
var _sample_time: float = 0.0
var _textures: Dictionary = {}
var emitted_total: int = 0

func configure(owner_game: Node, motion_service: Node) -> void:
    game = owner_game
    service = motion_service
    process_mode = Node.PROCESS_MODE_PAUSABLE
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CONFIG))
    settings = parsed if parsed is Dictionary else {}
    canvas = Node2D.new()
    canvas.name = "WorldMovementTrail"
    canvas.z_as_relative = false
    canvas.z_index = 1
    canvas.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    game.add_child(canvas)
    canvas.draw.connect(_draw_history)

func strength() -> float:
    return clampf(float(settings.get("strength",1.0)),0.0,1.5)

func _blocked() -> bool:
    if not is_instance_valid(game) or not is_instance_valid(service) or not bool(service.get("enabled_by_user")) or strength() <= 0.0:
        return true
    if not is_instance_valid(game.get("player")) or get_tree().paused or game.get("_paused") == true or game.get("story_safe") == true:
        return true
    var level: Variant = game.get("speed_effects_level")
    if level != null and int(level) <= 0: return true
    var overlay: Variant = game.get("_overlay")
    if overlay != null and str(overlay) != "": return true
    var outcome: Variant = game.get("outcome")
    if outcome != null and str(outcome) != "": return true
    return game.get("player").get("dead") == true

func clear() -> void:
    _samples.clear()
    _anchor.clear()
    _last_observed = Vector2.INF
    _last_room = ""
    _sample_time = _clock
    if is_instance_valid(canvas): canvas.queue_redraw()

func _notification(what: int) -> void:
    if what == NOTIFICATION_PAUSED: clear()

func _tier(actor: Node2D) -> String:
    var state: String = str(actor.get("animation_state"))
    var phase: Variant = actor.get("attack_phase")
    if phase != null and str(phase) != "none": return ""
    if state in ["parry","parry_ready","parry_recoil","parry_recover","hurt","dead","climb","climb_idle"]: return ""
    var velocity: Variant = actor.get("velocity")
    var speed: float = velocity.length() if velocity is Vector2 else 0.0
    var dash: Variant = actor.get("dash_timer")
    if dash != null and float(dash) > 0.0: return "dash"
    if Renderer.is_airborne(actor) and speed >= float(settings.get("air",{}).get("min_speed",70.0)): return "air"
    return "run" if speed >= float(settings.get("run",{}).get("min_speed",95.0)) else ""

func _capture(actor: Node2D, direction: Vector2, tier: String) -> Dictionary:
    var weapon: String = Renderer.weapon_of(actor)
    var texture: Texture2D
    if not _textures.has(weapon): _textures[weapon] = Renderer.silhouette_texture_for(weapon)
    texture = _textures[weapon]
    var facing: int = -1 if int(actor.get("facing")) < 0 else 1
    var config: Dictionary = settings.get(tier,{})
    return {"at":actor.global_position.round(),"region":Renderer.hero_region_for(actor,str(actor.get("animation_state")),int(actor.get("frame"))),"facing":facing,"weapon":weapon,"direction":direction.normalized(),"texture":texture,"age":0.0,"life":clampf(float(config.get("life",.1)),.05,.22),"alpha":clampf(float(config.get("alpha",.15)),.02,.30),"tier":tier,"captured_at":_clock}

func _process(delta: float) -> void:
    if _blocked():
        clear()
        return
    var dt: float = maxf(0.0,delta)
    _clock += dt
    var actor: Node2D = game.get("player")
    var room_value: Variant = game.get("room_id")
    var room: String = str(room_value) if room_value != null else ""
    var current: Vector2 = actor.global_position
    var velocity_value: Variant = actor.get("velocity")
    var velocity: Vector2 = velocity_value if velocity_value is Vector2 else Vector2.ZERO
    var step: Vector2 = current-_last_observed if _last_observed.is_finite() else Vector2.ZERO
    var jump_limit: float = maxf(float(settings.get("teleport_distance",96.0)),velocity.length()*minf(dt,.1)*2.0+24.0)
    if (_last_room != "" and room != _last_room) or (_last_observed.is_finite() and step.length()>jump_limit):
        clear()
        step = Vector2.ZERO
    _last_room = room
    var tier: String = _tier(actor)
    var stopped: bool = velocity.length()<25.0 or tier == ""
    var decay: float = float(settings.get("stop_decay_multiplier",4.0)) if stopped else 1.0
    for index: int in range(_samples.size()-1,-1,-1):
        _samples[index]["age"] = float(_samples[index]["age"])+dt*decay
        if float(_samples[index]["age"])>=float(_samples[index]["life"]): _samples.remove_at(index)
    if tier == "":
        _anchor.clear()
        _sample_time = _clock
    else:
        var direction: Vector2 = step.normalized() if step.length_squared()>.01 else velocity.normalized()
        if direction.is_zero_approx(): direction=Vector2(float(int(actor.get("facing"))),0)
        var config: Dictionary = settings.get(tier,{})
        if _anchor.is_empty():
            _anchor = _capture(actor,direction,tier)
            _sample_time = _clock
        elif step.length_squared()>.01 and _clock-_sample_time >= float(config.get("interval",.03)) and current.distance_to(Vector2(_anchor["at"]))>=float(config.get("min_distance",7.0)):
            # Add the prior observation, never another copy at the live body's position.
            var sample: Dictionary = _anchor.duplicate()
            sample["direction"] = direction
            sample["age"] = maxf(0.0,_clock-float(sample.get("captured_at",_sample_time)))
            if float(sample["age"]) < float(sample["life"]):
                _samples.append(sample)
                emitted_total += 1
                while _samples.size()>clampi(int(settings.get("max_snapshots",8)),1,10): _samples.pop_front()
            _anchor = _capture(actor,direction,tier)
            _sample_time = _clock
    _last_observed = current
    if is_instance_valid(canvas): canvas.queue_redraw()

func is_active() -> bool: return not _samples.is_empty()
func counts() -> Dictionary:
    return {"snapshots":_samples.size(),"max_snapshots":clampi(int(settings.get("max_snapshots",8)),1,10),"emitted":emitted_total,"strength":strength()}

func _rear_crop(direction: Vector2, facing: int) -> Rect2:
    var local_direction := Vector2(direction.x*facing,direction.y)
    if absf(local_direction.x)>=absf(local_direction.y):
        return Rect2(0,0,72,128) if local_direction.x>=0.0 else Rect2(60,0,84,128)
    return Rect2(0,60,144,68) if local_direction.y<0.0 else Rect2(0,0,144,70)

func _draw_history() -> void:
    if not is_instance_valid(canvas) or not is_instance_valid(game) or not is_instance_valid(game.get("player")): return
    var current: Vector2 = game.get("player").global_position
    for sample: Dictionary in _samples:
        var at: Vector2 = sample["at"]
        if at.distance_squared_to(current)<36.0: continue
        var t: float = clampf(float(sample["age"])/float(sample["life"]),0.0,1.0)
        var alpha: float = float(sample["alpha"])*pow(1.0-t,1.7)*strength()
        var texture: Texture2D = sample["texture"]
        if texture == null: continue
        var facing: int = int(sample["facing"])
        canvas.draw_set_transform(at,0.0,Vector2(facing,1))
        canvas.draw_texture_rect_region(texture,Rect2(-Renderer.HERO_ANCHOR,Renderer.HERO_SIZE),sample["region"],Color(.70,.83,1.0,alpha))
        # Only the back portion of an old silhouette has two tiny displaced samples.
        var direction: Vector2 = sample["direction"]
        var crop: Rect2 = _rear_crop(direction,facing)
        var region: Rect2 = sample["region"]
        var count: int = clampi(int(settings.get("rear_blur_passes",2)),0,3)
        for index: int in count:
            var shift: Vector2 = Vector2(-direction.x*facing,-direction.y)*float(index+1)*clampf(float(settings.get("rear_blur_step",2.0)),1.0,3.0)
            canvas.draw_texture_rect_region(texture,Rect2(-Renderer.HERO_ANCHOR+crop.position+shift.round(),crop.size),Rect2(region.position+crop.position,crop.size),Color(.54,.72,1.0,alpha*.25/float(index+1)))
    canvas.draw_set_transform(Vector2.ZERO)

func _exit_tree() -> void:
    if is_instance_valid(canvas): canvas.queue_free()